class_name Bench
extends CanvasLayer
## Bench close-up: item on a leather desk under the lamp + 5 tool gestures (<=3 s each).
## Each gesture ends in Sim.reveal(iid, tool); clues land on the parchment strip via Events.clue_revealed_v2.

signal closed

const TOOLS: Array = ["magnifier", "lamp", "ear", "nose", "brush"]
const LABELS: Dictionary = {"magnifier": "Magnifier", "lamp": "Lamp", "ear": "Ear", "nose": "Nose", "brush": "Brush"}
const RATE: Dictionary = {"magnifier": 0.65, "lamp": 0.75, "ear": 0.85, "nose": 0.7, "brush": 0.0}
const ATTR_LABEL: Dictionary = {"initials": "Initials", "station_stamp": "Stamp", "color": "Colour", "material": "Material", "sound": "Sound", "smell": "Smell", "wear": "Wear"}

var view: BenchView
var is_open: bool = false


class BenchView extends Control:
	var b: Bench
	var t: float = 0.0
	var sel: String = ""
	var tool: String = "magnifier"
	var ptr: Vector2 = Vector2.ZERO
	var down: bool = false
	var prog: float = 0.0
	var last_ptr: Vector2 = Vector2.ZERO
	var bounce: Dictionary = {}
	var done: Dictionary = {}
	var fresh: Dictionary = {}
	var nudge: String = ""
	var nudge_t: float = 0.0
	var pop_t: float = 9.0
	var pop_text: String = ""
	var parts: Array = []
	var emit_acc: float = 0.0
	var flick: float = 1.0
	var tex_cache: Dictionary = {}
	var demo: bool = false
	# layout cache
	var vs: Vector2
	var land: bool
	var stage: Rect2
	var item_c: Vector2
	var item_sz: float
	var strip: Rect2
	var rail: Array = []
	var close_r: Rect2
	var thumbs: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_preset(Control.PRESET_FULL_RECT)
		Events.clue_revealed_v2.connect(_on_clue)

	func _on_clue(iid: String, clue: Dictionary) -> void:
		fresh[String(clue.get("id", ""))] = 0.0
		pop_t = 0.0
		pop_text = String(clue.get("text", ""))
		Sfx.play("clue")
		Sfx.buzz(30)

	func items() -> Array:
		return Sim.get_items_at("bench")

	func ensure_sel() -> void:
		var its: Array = items()
		var ok: bool = false
		for it in its:
			if String(it["iid"]) == sel:
				ok = true
		if not ok:
			sel = "" if its.is_empty() else String((its[0] as Dictionary)["iid"])

	func layout() -> void:
		vs = size
		land = vs.x > vs.y
		var m: float = 36.0
		var rail_d: float = 150.0
		rail.clear()
		if land:
			var sw: float = vs.x - 700.0
			stage = Rect2(m, 150, sw - m, vs.y - 150 - 230)
			strip = Rect2(vs.x - 660, 150, 624, vs.y - 190)
			for i in range(5):
				rail.append(Rect2(m + 30 + i * 175.0, vs.y - 200, rail_d, rail_d))
		else:
			strip = Rect2(m, vs.y - 230 - 560, vs.x - 2 * m, 540)
			stage = Rect2(m, 190, vs.x - 2 * m, strip.position.y - 190 - 10)
			var gap: float = (vs.x - 2 * m - 5 * rail_d) / 4.0
			for i in range(5):
				rail.append(Rect2(m + i * (rail_d + gap), vs.y - 210, rail_d, rail_d))
		item_sz = minf(stage.size.x * 0.62, stage.size.y * 0.72)
		item_c = stage.get_center() + Vector2(0, 20)
		close_r = Rect2(vs.x - 150, 40, 110, 110)
		thumbs.clear()
		var its: Array = items()
		if its.size() > 1:
			var n: int = 0
			for it in its:
				thumbs.append({"iid": String(it["iid"]), "r": Rect2(m + n * 130.0, 50, 112, 112)})
				n += 1

	func icon_of(item: Dictionary) -> Texture2D:
		var nm: String = String(item.get("icon", "key"))
		if not tex_cache.has(nm):
			tex_cache[nm] = load("res://assets/icons/%s.svg" % nm) if ResourceLoader.exists("res://assets/icons/%s.svg" % nm) else null
		return tex_cache[nm]

	func tint_of(item: Dictionary) -> Color:
		return Color(String(item.get("tint", "#C8503C")))

	# ---------- input ----------
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb: InputEventMouseButton = e
			ptr = mb.position
			if mb.pressed:
				_press(mb.position)
			else:
				_release()
			accept_event()
		elif e is InputEventMouseMotion:
			ptr = (e as InputEventMouseMotion).position
			accept_event()

	func _press(p: Vector2) -> void:
		if close_r.has_point(p):
			Sfx.play("tap")
			b.close()
			return
		for th in thumbs:
			if (th["r"] as Rect2).has_point(p):
				sel = String(th["iid"])
				prog = 0.0
				Sfx.play("tap")
				return
		for i in range(rail.size()):
			if (rail[i] as Rect2).grow(10).has_point(p):
				tool = TOOLS[i]
				prog = 0.0
				bounce[tool] = 0.0
				Sfx.play("tap")
				Sfx.buzz(15)
				return
		if sel == "":
			return
		down = true
		last_ptr = p
		if done.get(sel + "|" + tool, false):
			say("You've already checked that with the %s." % LABELS[tool].to_lower())
			down = false

	func _release() -> void:
		down = false
		if prog < 1.0:
			prog = maxf(0.0, prog - 0.15)

	func over_item(p: Vector2) -> bool:
		return p.distance_to(item_c) < item_sz * 0.55

	func say(s: String) -> void:
		nudge = s
		nudge_t = 2.4

	# ---------- sim step ----------
	func _process(delta: float) -> void:
		if not visible:
			return
		t += delta
		layout()
		ensure_sel()
		flick = 0.92 + 0.08 * sin(t * 23.0) * sin(t * 7.3)
		for k in bounce.keys():
			bounce[k] = float(bounce[k]) + delta
		for k in fresh.keys():
			fresh[k] = float(fresh[k]) + delta
		nudge_t = maxf(0.0, nudge_t - delta)
		pop_t += delta
		_gesture(delta)
		_update_parts(delta)
		queue_redraw()

	func _gesture(delta: float) -> void:
		if sel == "" or not down:
			return
		var key: String = sel + "|" + tool
		var active: bool = over_item(ptr) if tool != "magnifier" else over_item(ptr + Vector2(0, -130))
		if tool == "ear" or tool == "nose":
			active = over_item(ptr)
		if not active:
			return
		var moved: float = ptr.distance_to(last_ptr)
		last_ptr = ptr
		match tool:
			"brush":
				prog += moved / 1100.0
				if moved > 3.0:
					_emit(ptr, 2, Color(0.85, 0.78, 0.62, 0.8), Vector2(0, 40))
			"magnifier":
				prog += delta * float(RATE[tool]) * (0.45 + minf(moved / 8.0, 1.0) * 0.55)
			"lamp":
				prog += delta * float(RATE[tool])
				_emit(ptr + Vector2(randf_range(-60, 60), randf_range(-40, 40)), 1, Color(0.7, 0.6, 1.0, 0.8), Vector2(0, -30))
			"ear":
				prog += delta * float(RATE[tool])
				emit_acc += delta
				if emit_acc > 0.28:
					emit_acc = 0.0
					parts.append({"p": item_c, "v": Vector2.ZERO, "life": 0.9, "max": 0.9, "col": Color(Pal.LAMP, 0.7), "kind": "ring", "r": 20.0})
					Sfx.buzz(10)
			"nose":
				prog += delta * float(RATE[tool])
				_emit(item_c + Vector2(randf_range(-item_sz * 0.3, item_sz * 0.3), -item_sz * 0.2), 1, Color(0.8, 0.9, 0.8, 0.55), Vector2(randf_range(-20, 20), -90))
		if prog >= 1.0:
			prog = 0.0
			down = false
			done[key] = true
			var r: Dictionary = Sim.reveal(sel, tool)
			Sfx.buzz(40)
			if bool(r.get("nothing", false)) or not bool(r.get("ok", false)):
				say("Nothing for the %s here. Try another tool." % LABELS[tool].to_lower())
			else:
				for i in range(14):
					_emit(item_c, 1, Color(Pal.LAMP, 0.9), Vector2.from_angle(randf() * TAU) * randf_range(120, 260))

	func _emit(p: Vector2, n: int, col: Color, v: Vector2) -> void:
		for i in range(n):
			if parts.size() > 90:
				return
			parts.append({"p": p, "v": v + Vector2(randf_range(-25, 25), randf_range(-25, 25)), "life": 0.8, "max": 0.8, "col": col, "kind": "dot", "r": randf_range(3, 7)})

	func _update_parts(delta: float) -> void:
		var keep: Array = []
		for pr in parts:
			pr["life"] = float(pr["life"]) - delta
			if float(pr["life"]) > 0.0:
				pr["p"] = (pr["p"] as Vector2) + (pr["v"] as Vector2) * delta
				if pr["kind"] == "ring":
					pr["r"] = float(pr["r"]) + delta * 260.0
				keep.append(pr)
		parts = keep

	# ---------- drawing ----------
	func _font() -> Font:
		return get_theme_default_font()

	func txt(p: Vector2, s: String, sz: int, col: Color, w: float = -1.0, al: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
		_font().draw_string(get_canvas_item(), p, s, al, w, sz, col)

	func _draw() -> void:
		if vs == Vector2.ZERO:
			return
		# desk
		Dr.vgrad(self, Rect2(Vector2.ZERO, vs), Color("#1a1511"), Color("#0e0b09"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in range(60):
			var y: float = rng.randf() * vs.y
			draw_line(Vector2(0, y), Vector2(vs.x, y + rng.randf_range(-8, 8)), Color(1, 0.9, 0.7, 0.025), 2.0)
		# lamp pool
		var pool_c: Vector2 = item_c + Vector2(0, -20)
		for i in range(9):
			var f: float = 1.0 - float(i) / 9.0
			draw_circle(pool_c, item_sz * (0.4 + 0.9 * (1.0 - f)), Color(Pal.LAMP, 0.045 * flick * f + 0.01))
		# stitched leather blotter
		var bl := Rect2(stage.position + Vector2(24, 40), stage.size - Vector2(48, 60))
		Dr.rrect(self, bl, 30, Color("#3a2a1e", 0.55))
		draw_rect(bl.grow(-14), Color(Pal.BRASS, 0.28), false, 2.0)
		# top brass rail
		Dr.vgrad(self, Rect2(0, 0, vs.x, 14), Pal.BRASS, Dr.shade(Pal.BRASS, 0.6))
		txt(Vector2(thumbs.size() * 130 + 60 if thumbs.size() > 1 else 40, 120), "BENCH", 34, Color(Pal.PARCHMENT, 0.8))
		_draw_close()
		_draw_thumbs()
		var item: Dictionary = Sim.get_item(sel) if sel != "" else {}
		if item.is_empty():
			_draw_empty()
		else:
			_draw_item_stage(item)
			_draw_tool_fx(item)
		_draw_particles()
		_draw_rail()
		_draw_strip(item)
		_draw_nudge()

	func _draw_close() -> void:
		Dr.rrect(self, close_r, 30, Color(Pal.NIGHT, 0.9))
		draw_arc(close_r.get_center(), 50, 0, TAU, 32, Pal.BRASS, 3.0)
		var c: Vector2 = close_r.get_center()
		draw_line(c + Vector2(-20, -20), c + Vector2(20, 20), Pal.PARCHMENT, 6.0)
		draw_line(c + Vector2(20, -20), c + Vector2(-20, 20), Pal.PARCHMENT, 6.0)

	func _draw_thumbs() -> void:
		for th in thumbs:
			var r: Rect2 = th["r"]
			var on: bool = String(th["iid"]) == sel
			Dr.rrect(self, r, 20, Color(Pal.NIGHT, 0.9))
			var it: Dictionary = Sim.get_item(String(th["iid"]))
			var tx: Texture2D = icon_of(it)
			if tx != null:
				draw_texture_rect(tx, r.grow(-16), false, tint_of(it))
			draw_arc(r.get_center(), 62, 0, TAU, 32, Pal.LAMP if on else Color(Pal.BRASS, 0.5), 4.0 if on else 2.0)

	func _draw_empty() -> void:
		Dr.rrect(self, Rect2(item_c - Vector2(150, 150), Vector2(300, 300)), 40, Color(1, 1, 1, 0.03))
		draw_arc(item_c, 140, 0, TAU, 48, Color(Pal.BRASS, 0.5), 3.0)
		txt(item_c + Vector2(-vs.x / 2.0 + 0, 200), "The bench is empty.", 44, Pal.PARCHMENT, vs.x if not land else stage.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		txt(item_c + Vector2(-vs.x / 2.0, 260), "Pick something up and bring it here.", 32, Color(Pal.PARCHMENT, 0.7), vs.x if not land else stage.size.x, HORIZONTAL_ALIGNMENT_CENTER)

	func _draw_item_stage(item: Dictionary) -> void:
		var pos: Vector2 = item_c
		var sc: float = 1.0
		var rot: float = -0.05 + (0.0 if Pal.reduced_motion() else sin(t * 1.3) * 0.015)
		if tool == "ear" and down and over_item(ptr):
			pos += Vector2(-item_sz * 0.18, -item_sz * 0.12) + Vector2(sin(t * 40.0) * 2.0, 0)
			sc = 0.92
			rot = -0.25
		var s: float = item_sz
		# shadow
		draw_set_transform(item_c + Vector2(0, s * 0.46), 0.0, Vector2(1, 0.22))
		draw_circle(Vector2.ZERO, s * 0.42, Color(0, 0, 0, 0.5))
		draw_set_transform(pos, rot, Vector2(sc, sc))
		ItemArt.draw(self, item, Rect2(-s * 0.5, -s * 0.5, s, s), {"marks": true})
		# brush wear marks
		if tool == "brush" and prog > 0.0:
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			for i in range(int(prog * 18.0)):
				var a: Vector2 = Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)) * s
				draw_line(a, a + Vector2(rng.randf_range(20, 60), rng.randf_range(-25, 25)), Color(0.1, 0.07, 0.04, 0.5), 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# item name tag
		var nm: String = String(item.get("name", ""))
		if nm != "":
			txt(Vector2(stage.position.x, stage.end.y - 4), nm, 34, Color(Pal.PARCHMENT, 0.75), stage.size.x, HORIZONTAL_ALIGNMENT_CENTER)

	func _draw_tool_fx(item: Dictionary) -> void:
		var tint: Color = tint_of(item)
		match tool:
			"magnifier":
				var c: Vector2 = ptr + Vector2(0, -130) if (down or demo) else item_c + Vector2(item_sz * 0.15, -item_sz * 0.05)
				var r: float = 150.0
				draw_circle(c, r, Color(1, 0.97, 0.88, 0.10 + 0.12 * prog))
				var rng := RandomNumberGenerator.new()
				rng.seed = 5
				for i in range(9):
					var a: Vector2 = c + Vector2(rng.randf_range(-90, 90), rng.randf_range(-70, 70))
					var j: float = (1.0 - prog) * 6.0
					draw_line(a, a + Vector2(rng.randf_range(20, 50), 0), Color(Pal.INK, 0.15 + 0.55 * prog), 2.0 + 3.0 * prog)
					if j > 0.1:
						draw_line(a + Vector2(0, j), a + Vector2(30, j), Color(Pal.INK, 0.12), 2.0)
				draw_arc(c, r, 0, TAU, 48, Pal.BRASS, 12.0)
				draw_arc(c, r - 14, -2.6, -1.6, 16, Color(1, 1, 1, 0.5), 6.0)
				draw_line(c + Vector2(1, 1).normalized() * r, c + Vector2(1, 1).normalized() * (r + 120), Dr.shade(Pal.BRASS, 0.7), 22.0)
				if pop_t < 1.6 and pop_text != "":
					txt(c + Vector2(-r + 20, 8), pop_text.substr(0, 22), 28, Pal.INK, r * 2 - 40, HORIZONTAL_ALIGNMENT_CENTER)
			"lamp":
				var src: Vector2 = Vector2(stage.end.x - 80, stage.position.y + 10)
				var tgt: Vector2 = ptr if (down or demo) else item_c
				var dir: Vector2 = (tgt - src).normalized()
				var nrm: Vector2 = Vector2(-dir.y, dir.x)
				var len: float = src.distance_to(tgt) + 140.0
				var beam := PackedVector2Array([src, src + dir * len + nrm * 170, src + dir * len - nrm * 170])
				draw_polygon(beam, PackedColorArray([Color(0.7, 0.55, 1, 0.5), Color(0.6, 0.5, 1, 0.04), Color(0.6, 0.5, 1, 0.04)]))
				draw_circle(tgt, 150, Color(0.65, 0.5, 1, 0.14 + 0.1 * prog))
				for i in range(int(prog * 9.0) + (2 if demo else 0)):
					var a: float = float(i) * 0.9 + t * 0.4
					draw_circle(tgt + Vector2.from_angle(a) * (30 + i * 11), 18 + 6 * prog, Color(tint, 0.35 * prog + 0.1))
				Dr.rrect(self, Rect2(src - Vector2(34, 34), Vector2(68, 68)), 18, Pal.BRASS)
				draw_circle(src, 16, Color(0.8, 0.7, 1, 0.9))
			"ear":
				var wy: float = stage.end.y - 70
				var amp: float = 6.0 + 50.0 * prog
				var pts := PackedVector2Array()
				for i in range(61):
					var x: float = stage.position.x + 40 + float(i) / 60.0 * (stage.size.x - 80)
					pts.append(Vector2(x, wy + sin(float(i) * 0.7 + t * 9.0) * amp * sin(float(i) / 60.0 * PI)))
				draw_polyline(pts, Color(Pal.LAMP, 0.8), 4.0, true)
			"nose":
				var np: Vector2 = item_c + Vector2(0, -item_sz * 0.6)
				if down and over_item(ptr):
					for i in range(3):
						draw_arc(np + Vector2((i - 1) * 40, 0), 24, PI, TAU, 12, Color(0.85, 0.95, 0.85, 0.15 + 0.5 * prog), 4.0)
			"brush":
				if down or demo:
					var bp: Vector2 = ptr if down else item_c
					draw_line(bp + Vector2(10, -10), bp + Vector2(130, -140), Dr.shade(Pal.BRASS, 0.6), 24.0)
					draw_line(bp + Vector2(-16, 16), bp + Vector2(14, -14), Color(0.85, 0.75, 0.55), 34.0)
		if prog > 0.0:
			var pr := Rect2(item_c.x - 120, item_c.y + item_sz * 0.56, 240, 12)
			Dr.rrect(self, pr, 6, Color(0, 0, 0, 0.5))
			Dr.rrect(self, Rect2(pr.position, Vector2(pr.size.x * clampf(prog, 0.04, 1.0), pr.size.y)), 6, Pal.LAMP)

	func _draw_particles() -> void:
		for pr in parts:
			var a: float = float(pr["life"]) / float(pr["max"])
			var col: Color = pr["col"]
			col.a *= a
			if pr["kind"] == "ring":
				draw_arc(pr["p"], float(pr["r"]), 0, TAU, 40, col, 4.0)
			else:
				draw_circle(pr["p"], float(pr["r"]) * (0.5 + a * 0.5), col)

	func _draw_rail() -> void:
		for i in range(5):
			var r: Rect2 = rail[i]
			var nm: String = TOOLS[i]
			var on: bool = nm == tool
			var bn: float = float(bounce.get(nm, 9.0))
			var s: float = 1.0 + (0.18 * exp(-bn * 7.0) * cos(bn * 18.0) if bn < 1.0 else 0.0)
			var c: Vector2 = r.get_center() - Vector2(0, 14 if on else 0)
			var rad: float = 66.0 * s
			draw_circle(c + Vector2(0, 8), rad, Color(0, 0, 0, 0.4))
			draw_circle(c, rad, Pal.BRASS if on else Pal.NIGHT)
			draw_arc(c, rad, 0, TAU, 40, Pal.LAMP if on else Pal.BRASS, 5.0 if on else 3.0)
			_tool_icon(nm, c, rad * 0.55, Pal.INK if on else Pal.PARCHMENT)
			txt(Vector2(r.position.x - 20, r.end.y + 26), LABELS[nm], 26, Pal.PARCHMENT if on else Color(Pal.PARCHMENT, 0.6), r.size.x + 40, HORIZONTAL_ALIGNMENT_CENTER)
			if sel != "" and done.get(sel + "|" + nm, false):
				draw_circle(c + Vector2(rad * 0.7, -rad * 0.7), 16, Pal.LAMP)
				draw_line(c + Vector2(rad * 0.7 - 7, -rad * 0.7), c + Vector2(rad * 0.7 - 2, -rad * 0.7 + 6), Pal.INK, 4.0)
				draw_line(c + Vector2(rad * 0.7 - 2, -rad * 0.7 + 6), c + Vector2(rad * 0.7 + 8, -rad * 0.7 - 6), Pal.INK, 4.0)

	func _tool_icon(nm: String, c: Vector2, r: float, col: Color) -> void:
		match nm:
			"magnifier":
				draw_arc(c + Vector2(-r * 0.15, -r * 0.15), r * 0.65, 0, TAU, 28, col, 6.0)
				draw_line(c + Vector2(r * 0.35, r * 0.35), c + Vector2(r * 0.95, r * 0.95), col, 9.0)
			"lamp":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, -r * 0.2), c + Vector2(r * 0.5, -r * 0.2), c + Vector2(r * 0.8, r * 0.5), c + Vector2(-r * 0.8, r * 0.5)]), col)
				draw_line(c + Vector2(0, -r * 0.2), c + Vector2(0, -r * 0.9), col, 6.0)
			"ear":
				draw_arc(c, r * 0.8, PI * 0.6, PI * 2.1, 20, col, 7.0)
				draw_arc(c + Vector2(r * 0.05, r * 0.05), r * 0.4, PI * 0.7, PI * 1.9, 14, col, 5.0)
			"nose":
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.2, -r * 0.9), c + Vector2(-r * 0.3, r * 0.3), c + Vector2(-r * 0.8, r * 0.7), c + Vector2(r * 0.2, r * 0.7)]), col, 7.0, true)
				draw_arc(c + Vector2(r * 0.3, r * 0.5), r * 0.25, 0, TAU, 12, col, 4.0)
			"brush":
				draw_line(c + Vector2(-r * 0.7, r * 0.7), c + Vector2(r * 0.2, -r * 0.2), col, 12.0)
				draw_line(c + Vector2(r * 0.1, -r * 0.1), c + Vector2(r * 0.8, -r * 0.8), Pal.SIGNAL, 8.0)

	func _glyph(attr: String, c: Vector2, col: Color) -> void:
		match attr:
			"initials":
				txt(c + Vector2(-26, 14), "Aa", 36, col)
			"station_stamp":
				draw_arc(c, 24, 0, TAU, 20, col, 4.0)
				draw_arc(c, 15, 0, TAU, 16, col, 3.0)
			"color":
				draw_circle(c + Vector2(-14, 6), 11, Pal.SIGNAL)
				draw_circle(c + Vector2(10, 8), 11, Pal.MIST)
				draw_circle(c + Vector2(-2, -12), 11, Pal.LAMP)
			"material":
				draw_rect(Rect2(c - Vector2(22, 22), Vector2(44, 44)), col, false, 3.0)
				for i in range(3):
					draw_line(c + Vector2(-22, -10 + i * 14), c + Vector2(-10 + i * 14, -22), col, 2.0)
			"sound":
				for i in range(3):
					draw_arc(c + Vector2(-14, 0), 12.0 + i * 10.0, -0.7, 0.7, 10, col, 4.0)
			"smell":
				for i in range(3):
					draw_polyline(PackedVector2Array([c + Vector2(-16 + i * 16, 22), c + Vector2(-8 + i * 16, 6), c + Vector2(-20 + i * 16, -8), c + Vector2(-10 + i * 16, -22)]), col, 3.0, true)
			"wear":
				for i in range(3):
					draw_line(c + Vector2(-20, -14 + i * 14), c + Vector2(20, -22 + i * 14), col, 3.0)

	func _draw_strip(item: Dictionary) -> void:
		Dr.rrect(self, strip.grow(4), 22, Color(0, 0, 0, 0.45))
		Dr.rrect(self, strip, 22, Pal.PARCHMENT)
		draw_rect(strip.grow(-10), Color(Pal.BRASS, 0.55), false, 2.0)
		txt(strip.position + Vector2(30, 56), "CLUES", 30, Color(Pal.INK, 0.6))
		if item.is_empty():
			return
		var known: Array = item.get("clues_known", [])
		var unknown: Array = item.get("unknown_attrs", [])
		var def: Dictionary = Content.object_by_id(String(item.get("def_id", "")))
		var y: float = strip.position.y + 80
		var shown: int = 0
		for c in def.get("clues", []):
			if not known.has(c["id"]):
				continue
			var a: float = float(fresh.get(String(c["id"]), 9.0))
			var pop: float = 1.0 + (0.08 * exp(-a * 6.0) * cos(a * 20.0) if a < 1.5 else 0.0)
			var row := Rect2(strip.position.x + 20, y, strip.size.x - 40, 84)
			if a < 1.2:
				Dr.rrect(self, row.grow(4), 16, Color(Pal.LAMP, 0.35 * (1.0 - a / 1.2)))
			_glyph(String(c["attr"]), row.position + Vector2(48, 42), Pal.INK)
			var tw: float = row.size.x - 120
			var sz: int = 30
			var h: Vector2 = _font().get_multiline_string_size(String(c["text"]), HORIZONTAL_ALIGNMENT_LEFT, tw, sz)
			_font().draw_multiline_string(get_canvas_item(), row.position + Vector2(100, 40 - h.y / 2.0 + sz * 0.8), String(c["text"]), HORIZONTAL_ALIGNMENT_LEFT, tw, sz, -1, Pal.INK)
			y += 92 * pop
			shown += 1
		var slots: int = 0
		for u in unknown:
			if y + 70 > strip.end.y - 10:
				break
			draw_rect(Rect2(strip.position.x + 40, y + 12, strip.size.x - 80, 56), Color(Pal.INK, 0.06))
			draw_rect(Rect2(strip.position.x + 40, y + 12, strip.size.x - 80, 56), Color(Pal.INK, 0.2), false, 2.0)
			_glyph(String(u), Vector2(strip.position.x + 72, y + 40), Color(Pal.INK, 0.35))
			txt(Vector2(strip.position.x + 120, y + 52), "%s: ?" % String(ATTR_LABEL.get(String(u), String(u))), 28, Color(Pal.INK, 0.45))
			y += 76
			slots += 1
		if shown == 0 and slots == 0:
			txt(strip.position + Vector2(30, 140), "Nothing more to find on this one.", 30, Color(Pal.INK, 0.6), strip.size.x - 60)

	func _draw_nudge() -> void:
		if nudge_t <= 0.0:
			return
		var a: float = clampf(nudge_t / 0.5, 0.0, 1.0)
		var w: float = minf(vs.x - 80, 760)
		var r := Rect2(vs.x / 2.0 - w / 2.0 if not land else stage.get_center().x - w / 2.0, stage.position.y + 20 + (1.0 - a) * -10, w, 80)
		Dr.rrect(self, r, 24, Color(Pal.NIGHT, 0.92 * a))
		draw_rect(r, Color(Pal.BRASS, a), false, 3.0)
		txt(r.position + Vector2(0, 52), nudge, 30, Color(Pal.PARCHMENT, a), w, HORIZONTAL_ALIGNMENT_CENTER)


func _ready() -> void:
	layer = 20
	view = BenchView.new()
	view.b = self
	add_child(view)
	visible = false
	Events.item_moved.connect(func(_iid: String, _loc: String) -> void:
		if is_open:
			view.ensure_sel())


func open(tool: String = "") -> void:
	if is_open:
		return
	is_open = true
	visible = true
	view.sel = ""
	view.prog = 0.0
	view.down = false
	if tool != "" and TOOLS.has(tool):
		view.tool = tool
	view.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(view, "modulate:a", 1.0, 0.18)
	Sfx.play("drop")


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	view.down = false
	closed.emit()


## Screenshot helper: pretend the pointer is mid-gesture.
func demo(tool: String, prog: float) -> void:
	view.demo = true
	view.tool = tool
	view.layout()
	view.ensure_sel()
	view.ptr = view.item_c + Vector2(40, 30)
	view.prog = prog
	view.down = false
