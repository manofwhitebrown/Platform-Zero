class_name WorldInput
extends Node2D
## Tap-to-walk + interactables. World-space node drawn above the cars.
## - Tap anywhere: the attendant walks there (Sim.player_move_to).
## - Tap a highlighted hotspot / bench: walks there and auto-interacts on arrival.
## - Always one "guided" interactable pulses (bench when carrying, else nearest item); the rest shimmer after 20 s idle.

signal interacted(kind: String, id: String)
signal brass_clock_tapped
signal lamp_held

const CLOCK_LOCAL: Vector2 = Vector2(870, 300)
const LAMP_LOCAL: Vector2 = Vector2(990, 290)
const LAMP_HOLD_S: float = 2.0

const FLOOR_Y: float = 880.0
const SPOT_Y: Dictionary = {"seat": 770.0, "rack": 380.0, "floor": 862.0, "bin": 838.0, "sill": 470.0, "curtain": 420.0, "table": 735.0}
const BENCH_X_LOCAL: float = 485.0
const LP_ID: String = "car_lp"

var attendant: Passenger
var world: Node2D
var pending: Dictionary = {}
var idle_s: float = 0.0
var _t: float = 0.0
var _last_px: float = 0.0
var _tex: Dictionary = {}
var _ripple: Vector3 = Vector3(-1, 0, 0)  # x, y, age
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _squash: Dictionary = {}
var _fly: Dictionary = {}   # iid -> {from: Vector2, t: float}
var _hold_t: float = 0.0
var _hold_fired: bool = false


func setup(p_world: Node2D, p_att: Passenger) -> void:
	world = p_world
	attendant = p_att
	z_index = 20
	_last_px = float(Sim.get_player().get("x", 0.0))
	Events.item_moved.connect(func(_i: String, _l: String) -> void: idle_s = 0.0)


func _bench_x() -> float:
	for c in Sim.get_cars():
		if String(c["id"]) == LP_ID:
			return float(c["x"]) + BENCH_X_LOCAL
	return 0.0


func _lp_x() -> float:
	for c in Sim.get_cars():
		if String(c["id"]) == LP_ID:
			return float(c["x"])
	return 3600.0


func _unlocked_at(x: float) -> bool:
	for c in Sim.get_cars():
		if x >= float(c["x"]) and x < float(c["x"]) + float(c["width"]):
			return bool(c["unlocked"])
	return false


func interactables() -> Array:
	var out: Array = []
	var carrying: String = String(Sim.get_player().get("carrying", ""))
	out.append({"kind": "bench", "id": "bench", "x": _bench_x(), "y": 740.0, "label": "Examine" if carrying != "" else "Bench", "active": carrying != ""})
	for sp in Sim.get_spots():
		if String(sp["item_iid"]) == "":
			continue
		if not _unlocked_at(float(sp["x"])):
			continue
		out.append({"kind": "spot", "id": String(sp["id"]), "x": float(sp["x"]), "y": float(SPOT_Y.get(String(sp["kind"]), 800.0)), "label": "Pick up", "active": carrying == "", "iid": String(sp["item_iid"])})
	return out


func guided() -> Dictionary:
	var px: float = float(Sim.get_player().get("x", 0.0))
	var best: Dictionary = {}
	var bd: float = 1e9
	for it in interactables():
		if not bool(it["active"]):
			continue
		var d: float = absf(float(it["x"]) - px)
		if d < bd:
			bd = d
			best = it
	return best


func _unhandled_input(e: InputEvent) -> void:
	var pos: Vector2 = Vector2.ZERO
	var down: bool = false
	var up: bool = false
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		down = (e as InputEventMouseButton).pressed
		up = not down
		pos = get_global_mouse_position()
	elif e is InputEventScreenTouch:
		down = (e as InputEventScreenTouch).pressed
		up = not down
		pos = get_canvas_transform().affine_inverse() * (e as InputEventScreenTouch).position
	else:
		return
	if down:
		_press_pos = pos
		_pressing = true
		_hold_t = 0.0
		_hold_fired = false
	elif up and _pressing:
		_pressing = false
		if _hold_fired:
			return
		if pos.distance_to(_press_pos) < 30.0:
			tap_world(pos)


## Public so tests / ShotHook can drive it.
func tap_world(pos: Vector2) -> void:
	idle_s = 0.0
	if pos.distance_to(Vector2(_lp_x(), 0) + CLOCK_LOCAL) < 100.0:
		_ripple = Vector3(pos.x, pos.y, 0.0)
		brass_clock_tapped.emit()
		return
	var hit: Dictionary = {}
	var bd: float = 120.0
	for it in interactables():
		var dx: float = absf(float(it["x"]) - pos.x)
		var dy: float = absf(float(it["y"]) - 40.0 - pos.y)
		if dx < bd and dy < 200.0:
			bd = dx
			hit = it
	_ripple = Vector3(pos.x, clampf(pos.y, 700.0, FLOOR_Y), 0.0)
	if not hit.is_empty():
		pending = hit
		Sim.player_move_to(float(hit["x"]))
	else:
		pending = {}
		Sim.player_move_to(pos.x)


func _process(delta: float) -> void:
	_t += delta
	idle_s += delta
	_ripple.z += delta
	var p: Dictionary = Sim.get_player()
	var px: float = float(p.get("x", 0.0))
	var moving: bool = absf(px - _last_px) > 0.05
	if moving:
		idle_s = 0.0
		attendant.face = 1 if px > _last_px else -1
		attendant._walk_ph += absf(px - _last_px) * 0.045
		if attendant.anim != "walk":
			attendant.play("walk")
	elif attendant.anim == "walk":
		attendant.play("idle")
	attendant.position = Vector2(px, FLOOR_Y)
	_last_px = px
	if not pending.is_empty() and not moving and absf(px - float(pending["x"])) < 18.0:
		_arrive(pending)
		pending = {}
	for k in _squash.keys():
		_squash[k] = float(_squash[k]) + delta
	for k2 in _fly.keys():
		_fly[k2]["t"] = float(_fly[k2]["t"]) + delta
		if float(_fly[k2]["t"]) > 0.45:
			_fly.erase(k2)
	if _pressing and not _hold_fired:
		_hold_t += delta
		if _hold_t >= LAMP_HOLD_S and _press_pos.distance_to(Vector2(_lp_x(), 0) + LAMP_LOCAL) < 110.0:
			_hold_fired = true
			lamp_held.emit()
	queue_redraw()


func _arrive(it: Dictionary) -> void:
	var carrying: String = String(Sim.get_player().get("carrying", ""))
	match String(it["kind"]):
		"spot":
			var r: Dictionary = Sim.pick_up(String(it["id"]))
			if bool(r.get("ok", false)):
				_squash[String(r["iid"])] = 0.0
				_fly[String(r["iid"])] = {"from": Vector2(float(it["x"]), float(it["y"])), "t": 0.0}
				attendant.play("hand")
				get_tree().create_timer(0.7).timeout.connect(func() -> void:
					if attendant.anim == "hand":
						attendant.play("idle"))
				interacted.emit("pick_up", String(r["iid"]))
		"bench":
			if carrying != "":
				var r2: Dictionary = Sim.place_on_bench(carrying)
				if bool(r2.get("ok", false)):
					interacted.emit("bench", carrying)
			else:
				interacted.emit("bench_open", "")


func _icon(item: Dictionary) -> Texture2D:
	var name: String = String(item.get("icon", "key"))
	if not _tex.has(name):
		_tex[name] = load("res://assets/icons/%s.svg" % name)
	return _tex[name]


func _draw_item(item: Dictionary, p: Vector2, sz: float, squash_t: float = -1.0) -> void:
	var sx: float = 1.0
	var sy: float = 1.0
	if squash_t >= 0.0 and squash_t < 0.5:
		var k: float = sin(squash_t / 0.5 * PI)
		sx = 1.0 - 0.25 * k
		sy = 1.0 + 0.35 * k
	var r := Rect2(p.x - sz * sx * 0.5, p.y - sz * sy, sz * sx, sz * sy)
	draw_circle(p + Vector2(0, -sz * 0.45), sz * 0.8, Color(1, 0.85, 0.45, 0.16))
	ItemArt.draw(self, item, r)


func _chip(p: Vector2, text: String, strong: bool) -> void:
	var f: Font = ThemeDB.fallback_font
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 36.0
	var r := Rect2(p.x - w * 0.5, p.y - 24, w, 48)
	Dr.rrect(self, Rect2(r.position + Vector2(0, 4), r.size), 24.0, Color(0, 0, 0, 0.35))
	Dr.rrect(self, r, 24.0, Pal.PARCHMENT if strong else Color(Pal.PARCHMENT.r, Pal.PARCHMENT.g, Pal.PARCHMENT.b, 0.8))
	draw_rect(r, Color(0, 0, 0, 0.0), false)
	draw_string(f, Vector2(r.position.x + 18, r.position.y + 33), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Pal.INK)
	# tail
	draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 24), p + Vector2(9, 24), p + Vector2(0, 38)]), Pal.PARCHMENT if strong else Color(Pal.PARCHMENT.r, Pal.PARCHMENT.g, Pal.PARCHMENT.b, 0.8))


func _draw() -> void:
	var px: float = float(Sim.get_player().get("x", 0.0))
	var g: Dictionary = guided()
	var shimmer_all: bool = idle_s > Sim.SHIMMER_IDLE_S
	var hl: Dictionary = {}
	for h in Sim.get_highlights():
		hl[String(h.get("id", ""))] = true
	# items resting at spots
	for it in interactables():
		if String(it["kind"]) == "spot":
			var item: Dictionary = Sim.get_item(String(it["iid"]))
			var def: Dictionary = Content.object_by_id(String(item.get("def_id", "")))
			if def.is_empty():
				continue
			var base: Vector2 = Vector2(float(it["x"]), float(it["y"]))
			var bob: float = sin(_t * 2.0 + float(it["x"]) * 0.01) * 3.0
			_draw_item(item if item.has("def_id") else def, base + Vector2(0, bob), 60.0)
	# interactable markers
	for it in interactables():
		var is_g: bool = (not g.is_empty() and it["id"] == g["id"]) or (hl.has(String(it["id"])) and String(it["kind"]) == "spot" and bool(it["active"]) and Sim.get_tutorial().get("stage", "done") != "done")
		if not is_g and not (shimmer_all and bool(it["active"])):
			continue
		var c := Vector2(float(it["x"]), float(it["y"]) - 20.0)
		var pulse: float = 0.5 + 0.5 * sin(_t * (4.0 if is_g else 2.5))
		var col := Color(1.0, 0.85, 0.4, (0.35 + 0.45 * pulse) if is_g else (0.18 + 0.25 * pulse))
		draw_arc(c, 54.0 + pulse * 12.0, 0, TAU, 40, col, 4.0)
		draw_arc(c, 36.0 + pulse * 6.0, 0, TAU, 32, Color(col.r, col.g, col.b, col.a * 0.7), 3.0)
		if is_g:
			var bob2: float = sin(_t * 4.0) * 6.0
			_chip(c + Vector2(0, -104 + bob2), String(it["label"]), true)
	# tap ripple
	if _ripple.x >= 0.0 and _ripple.z < 0.6:
		var k: float = _ripple.z / 0.6
		draw_arc(Vector2(_ripple.x, _ripple.y + 10.0), 14.0 + k * 50.0, 0, TAU, 28, Color(1, 0.9, 0.6, 0.7 * (1.0 - k)), 3.0)
	# carried item floats over the attendant's head
	var carrying: String = String(Sim.get_player().get("carrying", ""))
	if carrying != "" and attendant:
		var item2: Dictionary = Sim.get_item(carrying)
		var def2: Dictionary = Content.object_by_id(String(item2.get("def_id", "")))
		if not def2.is_empty():
			var hp: Vector2 = Vector2(px, FLOOR_Y - 330.0 + sin(_t * 3.0) * 4.0)
			if _fly.has(carrying):
				var fk: float = clampf(float(_fly[carrying]["t"]) / 0.45, 0.0, 1.0)
				var fe: float = 1.0 - pow(1.0 - fk, 3.0)
				var from: Vector2 = _fly[carrying]["from"]
				hp = from.lerp(hp, fe) + Vector2(0, -sin(fk * PI) * 90.0)
			_draw_item(item2 if item2.has("def_id") else def2, hp, 68.0, float(_squash.get(carrying, -1.0)))
