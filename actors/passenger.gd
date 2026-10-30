class_name Passenger
extends Node2D
## Layered 2D actor rig drawn procedurally. Origin = feet on the floor, y up is negative.
## Used for the attendant, the 15 regulars and ambient passengers (look from make_look()).
## Angles are radians from "straight down", positive = toward the facing direction.

signal arrived

const SKIN := [Color("#f5dcc0"), Color("#f0c9a4"), Color("#e8b88f"), Color("#e0aa80"), Color("#d9a47a"), Color("#c98f66"), Color("#a8704c"), Color("#8d5a3b")]
const HAIRS := [Color("#1a1210"), Color("#3b2a20"), Color("#5a3a22"), Color("#c8793a"), Color("#7a2e2e"), Color("#8a8a8a"), Color("#d8d8d8"), Color("#4a2a5a"), Color("#d9b46a")]
const COATS := [Color("#7FA6A3"), Color("#C8503C"), Color("#F2B84B"), Color("#12303B"), Color("#B8893E"), Color("#7a5a7a"), Color("#5a4a3a"), Color("#EADFC8"), Color("#3e6a8a"), Color("#6f8a52")]
const HAT_KINDS := ["none", "none", "cap", "top", "scarf"]
const HAIR_STYLES := ["short", "long", "bun", "curly", "bob", "bald"]
const BUILDS := {"slim": 0.88, "avg": 1.0, "broad": 1.18, "round": 1.28, "small": 0.9}
const THIGH := 78.0
const SHIN := 76.0
const TORSO := 118.0
const UPPER := 62.0
const FORE := 56.0

var look: Dictionary = {}
var mood: String = "calm"
var anim: String = "idle"
var face: int = 1
var emote: String = ""
var gait: String = ""   # "", "happy", "sad", "annoyed": colours the walk cycle while leaving
var pid: String = ""
var scale_f: float = 0.92

var _cur: Dictionary = {}
var _tgt: Dictionary = {}
var _t: float = 0.0
var _walk_ph: float = 0.0
var _emote_t: float = 0.0
var _blink: float = 0.0
var _next_blink: float = 2.0
var _speed: float = 0.0
var _walk_target: float = NAN
var _walk_speed: float = 0.0
var held: String = ""        # prop in the front hand: book | cup | trolley | punch
var _hand_f: Vector2 = Vector2.ZERO
var _hid: float = 0.0      # shy peek: how hidden (0..1)

const KEYS := ["hip", "lean", "tf", "tb", "kf", "kb", "sf", "ef", "sb", "eb", "head", "hand_x", "hand_y"]


static func make_look(seed_i: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_i
	var builds: Array = BUILDS.keys()
	var kid: bool = r.randf() < 0.1
	return {
		"skin": "#" + (SKIN[r.randi() % SKIN.size()] as Color).to_html(false),
		"hair": "#" + (HAIRS[r.randi() % HAIRS.size()] as Color).to_html(false),
		"coat": "#" + (COATS[r.randi() % COATS.size()] as Color).to_html(false),
		"hat": HAT_KINDS[r.randi() % HAT_KINDS.size()],
		"accessory": ["none", "none", "glasses", "beard", "pipe"][r.randi() % 5],
		"build": "small" if kid else builds[r.randi() % builds.size()],
		"height": 0.7 if kid else r.randf_range(0.92, 1.08),
		"hair_style": HAIR_STYLES[r.randi() % HAIR_STYLES.size()],
		"pants": "#" + (Color.from_hsv(r.randf(), 0.25, 0.35)).to_html(false),
		"shoes": "#2a1d14",
	}


func setup(p_look: Dictionary, p_mood: String = "calm", p_pid: String = "") -> void:
	look = p_look if not p_look.is_empty() else make_look(hash(p_pid))
	mood = p_mood
	pid = p_pid
	_next_blink = randf_range(1.5, 4.0)
	_t = randf() * 10.0
	play("idle")
	_snap()
	queue_redraw()


func play(a: String) -> void:
	if anim != a:
		anim = a
		_emote_t = 0.0


func do_emote(e: String) -> void:
	emote = e
	_emote_t = 0.0


func walk_to(x: float, speed: float = 280.0) -> void:
	_walk_target = x
	_walk_speed = speed
	face = 1 if x >= position.x else -1
	play("walk")


func is_walking() -> bool:
	return not is_nan(_walk_target)


func speed_for_mood() -> float:
	match mood:
		"hurried": return 1.4
		"shy": return 0.6
		"grumpy": return 0.9
		_: return 1.0


func _snap() -> void:
	_compute(0.0)
	for k in KEYS:
		_cur[k] = _tgt[k]


func _process(dt: float) -> void:
	_t += dt
	_emote_t += dt
	_blink -= dt
	_next_blink -= dt
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(2.0, 5.0)
	if not is_nan(_walk_target):
		var d: float = _walk_target - position.x
		var sp: float = _walk_speed * speed_for_mood()
		if mood == "shy" and fmod(_t, 4.0) < 0.9:
			sp = 0.0   # shy pauses
		var step: float = clampf(d, -sp * dt, sp * dt)
		position.x += step
		_speed = absf(step) / maxf(dt, 0.0001)
		_walk_ph += absf(step) * 0.045
		if absf(_walk_target - position.x) < 1.0:
			_walk_target = NAN
			_speed = 0.0
			play("idle")
			arrived.emit()
	else:
		_speed = 0.0
	_compute(dt)
	var k: float = 1.0 - exp(-14.0 * dt)
	for key in KEYS:
		_cur[key] = lerpf(float(_cur.get(key, 0.0)), float(_tgt[key]), k)
	queue_redraw()


func _sit_base(p: Dictionary) -> void:
	p["hip"] = 70.0
	p["tf"] = 1.5
	p["tb"] = 1.45
	p["kf"] = 1.5
	p["kb"] = 1.45
	p["sf"] = 0.7
	p["ef"] = 0.9
	p["sb"] = 0.5
	p["eb"] = 0.9


func _compute(_dt: float) -> void:
	var t: float = _t
	var br: float = sin(t * 2.2) * 2.0
	var p: Dictionary = {"hip": 0.0, "lean": 0.0, "tf": 0.0, "tb": 0.0, "kf": 0.05, "kb": 0.05, "sf": 0.08, "ef": 0.25, "sb": -0.08, "eb": 0.25, "head": 0.0, "hand_x": 0.0, "hand_y": 0.0}
	p["hip"] = br * 0.4
	match anim:
		"walk":
			var ph: float = _walk_ph
			p["tf"] = sin(ph) * 0.55
			p["tb"] = -sin(ph) * 0.55
			p["kf"] = 0.1 + maxf(0.0, sin(ph + 1.3)) * 0.8
			p["kb"] = 0.1 + maxf(0.0, -sin(ph + 1.3)) * 0.8
			p["sf"] = -sin(ph) * 0.5
			p["sb"] = sin(ph) * 0.5
			p["ef"] = 0.3
			p["eb"] = 0.3
			p["hip"] = -absf(cos(ph)) * 6.0
			p["lean"] = 0.04
			if mood == "grumpy":
				p["hip"] = -absf(cos(ph)) * 10.0
			match gait:
				"happy":
					p["hip"] = -absf(cos(ph)) * 15.0
					p["sf"] = -sin(ph) * 0.7 + 0.5
					p["sb"] = sin(ph) * 0.7 + 0.5
					p["head"] = -0.05
				"sad":
					p["lean"] = 0.2
					p["head"] = 0.25
					p["sf"] = -sin(ph) * 0.15
					p["sb"] = sin(ph) * 0.15
					p["hip"] = -absf(cos(ph)) * 3.0
				"annoyed":
					p["hip"] = -absf(cos(ph)) * 12.0
					p["sf"] = 0.5
					p["ef"] = 2.2
					p["sb"] = 0.4
					p["eb"] = 2.3
					p["lean"] = -0.04
		"sit":
			p["hip"] = 70.0
			p["tf"] = 1.5
			p["tb"] = 1.45
			p["kf"] = 1.5
			p["kb"] = 1.45
			p["sf"] = 0.7
			p["ef"] = 0.9
			p["sb"] = 0.5
			p["eb"] = 0.9
		"sit_read":
			_sit_base(p)
			p["lean"] = 0.04
			p["head"] = 0.32
			p["sf"] = 1.15
			p["ef"] = 1.75
			p["sb"] = 1.0
			p["eb"] = 1.9
		"sit_nap":
			_sit_base(p)
			p["lean"] = 0.2 + sin(t * 1.4) * 0.02
			p["head"] = 0.42
			p["sf"] = 0.3
			p["ef"] = 0.4
			p["hip"] = 70.0 + sin(t * 1.4) * 1.5
		"sit_eat":
			_sit_base(p)
			var cyc: float = (sin(t * 1.6) + 1.0) * 0.5
			p["sf"] = 0.9 + cyc * 0.9
			p["ef"] = 1.5 + cyc * 0.5
			p["head"] = 0.08 + cyc * 0.12
		"sit_stare":
			_sit_base(p)
			p["head"] = -0.1 + sin(t * 0.5) * 0.04
			p["lean"] = -0.02
		"sit_chat":
			_sit_base(p)
			var g: float = sin(t * 3.1)
			p["sf"] = 0.9 + maxf(0.0, g) * 0.9
			p["ef"] = 1.2 + g * 0.4
			p["head"] = sin(t * 2.0) * 0.08
			p["lean"] = 0.04 * sin(t * 1.3)
		"sit_kids":
			_sit_base(p)
			p["kf"] = 1.2 + sin(t * 5.0) * 0.5
			p["kb"] = 1.2 + sin(t * 5.0 + 2.2) * 0.5
			p["tf"] = 1.4 + sin(t * 5.0) * 0.12
			p["head"] = sin(t * 1.7) * 0.1
			p["sf"] = 0.5
			p["sb"] = 0.4
		"punch":
			p["sf"] = 1.3 + maxf(0.0, sin(t * 2.4)) * 0.5
			p["ef"] = 1.3
			p["lean"] = 0.03
		"wave":
			p["sf"] = 2.5 + sin(t * 9.0) * 0.25
			p["ef"] = 0.5 + sin(t * 9.0) * 0.4
		"wring":
			p["sf"] = 0.5
			p["ef"] = 1.8
			p["sb"] = 0.4
			p["eb"] = 1.9
			p["hand_x"] = sin(t * 7.0) * 3.0
			p["lean"] = 0.03
		"tap":
			p["tf"] = maxf(0.0, sin(t * 10.0)) * 0.35
			p["kf"] = p["tf"]
			p["sf"] = 0.1
			p["sb"] = 1.9 if fmod(t, 3.0) < 1.2 else -0.1
			p["eb"] = 2.2 if fmod(t, 3.0) < 1.2 else 0.3
			p["head"] = 0.18 if fmod(t, 3.0) < 1.2 else 0.0
		"peek":
			p["lean"] = 0.1
			p["sf"] = 1.2
			p["ef"] = 1.5
			p["head"] = 0.12
		"cross":
			p["sf"] = 0.7
			p["ef"] = 2.3
			p["sb"] = 0.5
			p["eb"] = 2.4
			p["lean"] = -0.04
			p["head"] = -0.05
		"lean":
			p["lean"] = 0.12
			p["sf"] = 0.9
			p["ef"] = 1.4
			p["tf"] = 0.1
		"hop":
			var hp: float = absf(sin(t * 7.0))
			p["hip"] = -hp * 34.0
			p["tf"] = hp * 0.5
			p["tb"] = -hp * 0.3
			p["kf"] = hp * 0.7
			p["kb"] = hp * 0.7
			p["sf"] = 2.4
			p["sb"] = 2.2
			p["ef"] = 0.4
			p["eb"] = 0.4
		"slump":
			p["lean"] = 0.2
			p["head"] = 0.25
			p["hip"] = 6.0
			p["sf"] = 0.05
			p["sb"] = -0.05
			p["ef"] = 0.1
			p["eb"] = 0.1
		"huff":
			p["sf"] = 0.5
			p["ef"] = 2.2
			p["sb"] = 0.4
			p["eb"] = 2.3
			p["lean"] = -0.05
			p["hip"] = sin(t * 14.0) * 1.5
		"hand":
			p["sf"] = 1.45
			p["ef"] = 0.15
			p["lean"] = 0.05
		_:
			pass
	p["lean"] = float(p["lean"]) + sin(t * 1.1) * 0.01
	_tgt = p


# ---------------------------------------------------------------- drawing
func _dir(a: float) -> Vector2:
	return Vector2(sin(a), cos(a))


func _limb(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	draw_line(a, b, col, w)
	draw_circle(a, w * 0.5, col)
	draw_circle(b, w * 0.5, col)


func _c(key: String, fallback: String = "#888888") -> Color:
	return Color(String(look.get(key, fallback)))


func _draw() -> void:
	if look.is_empty():
		return
	var s: float = scale_f * float(look.get("height", 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face * s, s))
	var bw: float = float(BUILDS.get(String(look.get("build", "avg")), 1.0))
	var skin: Color = _c("skin")
	var coat: Color = _c("coat")
	var pants: Color = _c("pants", "#333344")
	var shoes: Color = _c("shoes", "#2a1d14")
	var hipy: float = -(THIGH + SHIN) + float(_cur.get("hip", 0.0))
	var lean: float = float(_cur.get("lean", 0.0))
	var hip := Vector2(0, hipy)
	var shoulder: Vector2 = hip + Vector2(sin(lean), -cos(lean)) * TORSO
	# soft contact shadow
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face * s, s * 0.22))
	draw_circle(Vector2(0, 0), 60.0 * bw, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face * s, s))

	# back arm + back leg (darker)
	_leg(hip + Vector2(-4, 0), float(_cur["tb"]), float(_cur["kb"]), Dr.shade(pants, 0.72), Dr.shade(shoes, 0.8), bw)
	_arm(shoulder + Vector2(-6, 8), float(_cur["sb"]) + lean, float(_cur["eb"]), Dr.shade(coat, 0.72), skin, bw, true)
	# torso
	_torso(hip, shoulder, lean, coat, bw)
	# front leg
	_leg(hip + Vector2(6, 0), float(_cur["tf"]), float(_cur["kf"]), pants, shoes, bw)
	# head
	var head_c: Vector2 = shoulder + Vector2(sin(lean + float(_cur["head"])), -cos(lean + float(_cur["head"]))) * 52.0
	_head(head_c, skin, bw)
	# front arm
	_arm(shoulder + Vector2(4, 8), float(_cur["sf"]) + lean, float(_cur["ef"]), coat, skin, bw, false)
	_draw_held()
	_draw_emote(head_c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _leg(h: Vector2, th: float, kn: float, pants: Color, shoes: Color, bw: float) -> void:
	var knee: Vector2 = h + _dir(th) * THIGH
	var ankle: Vector2 = knee + _dir(th - kn) * SHIN
	_limb(h, knee, 26.0 * bw, pants)
	_limb(knee, ankle, 22.0 * bw, Dr.shade(pants, 0.92))
	# shoe
	var fdir: Vector2 = Vector2(cos(th - kn - 0.0), 0).normalized() if false else Vector2(1, 0)
	Dr.rrect(self, Rect2(ankle.x - 10, ankle.y - 8, 40, 16), 8.0, shoes)
	draw_rect(Rect2(ankle.x - 10, ankle.y + 5, 40, 3), Color(0, 0, 0, 0.35))
	if fdir.x < 0:
		pass


func _arm(sh: Vector2, a: float, el: float, sleeve: Color, skin: Color, bw: float, back: bool) -> void:
	var elbow: Vector2 = sh + _dir(a) * UPPER
	var hand: Vector2 = elbow + _dir(a + el) * FORE
	_limb(sh, elbow, 20.0 * bw, sleeve)
	_limb(elbow, hand, 18.0 * bw, Dr.shade(sleeve, 0.94))
	draw_circle(hand, 11.0, skin if not back else Dr.shade(skin, 0.85))
	if not back:
		_hand_f = hand
	draw_rect(Rect2(hand.x - 9, hand.y - 12, 18, 6), Color(1, 1, 1, 0.0))


func _torso(hip: Vector2, sh: Vector2, lean: float, coat: Color, bw: float) -> void:
	var half_b: float = 30.0 * bw
	var half_t: float = 24.0 * bw
	var perp: Vector2 = Vector2(cos(lean), sin(lean))
	var pts := PackedVector2Array([
		hip - perp * half_b + Vector2(0, 14), hip + perp * half_b + Vector2(0, 14),
		sh + perp * half_t, sh - perp * half_t])
	var cols := PackedColorArray([Dr.shade(coat, 0.7), Dr.shade(coat, 0.8), Dr.shade(coat, 1.1), Dr.shade(coat, 1.0)])
	draw_polygon(pts, cols)
	# coat flare below the belt
	draw_colored_polygon(PackedVector2Array([hip - perp * (half_b + 4) + Vector2(0, 8), hip + perp * (half_b + 4) + Vector2(0, 8), hip + perp * (half_b + 12) + Vector2(2, 56), hip - perp * (half_b + 12) + Vector2(-2, 56)]), Dr.shade(coat, 0.82))
	# belt + buttons + rim light
	draw_line(hip - perp * half_b + Vector2(0, 8), hip + perp * half_b + Vector2(0, 8), Color("#2a1d12"), 7.0)
	draw_rect(Rect2(hip.x - 6, hip.y + 3, 12, 10), Pal.BRASS)
	for i in range(3):
		var bp: Vector2 = hip.lerp(sh, 0.3 + i * 0.24) + perp * 6.0
		draw_circle(bp, 3.0, Pal.BRASS)
	draw_line(sh + perp * half_t, hip + perp * half_b, Color(1, 0.95, 0.8, 0.2), 3.0)
	# collar
	draw_colored_polygon(PackedVector2Array([sh - perp * 18, sh + perp * 18, sh + Vector2(0, 16)]), Dr.shade(coat, 1.2))
	if String(look.get("hat", "")) == "scarf" or String(look.get("accessory", "")) == "scarfneck":
		pass


func _head(c: Vector2, skin: Color, bw: float) -> void:
	var hair: Color = _c("hair")
	var style: String = String(look.get("hair_style", "short"))
	var hat: String = String(look.get("hat", "none"))
	# neck
	draw_rect(Rect2(c.x - 9, c.y + 16, 18, 24), Dr.shade(skin, 0.85))
	# back hair
	if style == "long" or style == "bob":
		Dr.rrect(self, Rect2(c.x - 44, c.y - 22, 62, 64 if style == "long" else 46), 22.0, Dr.shade(hair, 0.8))
	if style == "bun":
		draw_circle(c + Vector2(-34, -30), 15.0, Dr.shade(hair, 0.85))
	# ear
	draw_circle(c + Vector2(-26, 4), 9.0, Dr.shade(skin, 0.9))
	# head
	draw_circle(c, 40.0, skin)
	draw_circle(c + Vector2(6, 8), 36.0, Dr.shade(skin, 1.05))
	draw_circle(c + Vector2(20, 14), 7.0, Color(0.9, 0.4, 0.4, 0.28 if mood != "shy" else 0.6))
	# nose
	draw_colored_polygon(PackedVector2Array([c + Vector2(34, 0), c + Vector2(48, 14), c + Vector2(32, 16)]), Dr.shade(skin, 0.94))
	# eyes
	var blink: bool = _blink > 0.0 or (anim == "peek" and _hid > 0.5)
	var ey: Vector2 = c + Vector2(18, -6)
	if blink:
		draw_line(ey + Vector2(-8, 0), ey + Vector2(8, 0), Color("#2a2018"), 3.0)
	else:
		draw_circle(ey, 7.0, Color.WHITE)
		var look_off: float = 2.5 if anim != "tap" else 0.0
		draw_circle(ey + Vector2(look_off, 1), 4.2, Color("#2a2018"))
		draw_circle(ey + Vector2(look_off + 1.5, -1), 1.4, Color.WHITE)
	# brows by mood
	var bt: float = -22.0
	match mood:
		"worried":
			draw_line(ey + Vector2(-10, bt + 4), ey + Vector2(10, bt - 3), Color("#2a2018"), 4.0)
		"grumpy":
			draw_line(ey + Vector2(-10, bt - 3), ey + Vector2(10, bt + 5), Color("#2a2018"), 5.0)
		"hurried":
			draw_line(ey + Vector2(-10, bt), ey + Vector2(10, bt - 5), Color("#2a2018"), 4.0)
		_:
			draw_line(ey + Vector2(-10, bt), ey + Vector2(10, bt), Color("#2a2018"), 4.0)
	# mouth
	var m: Vector2 = c + Vector2(22, 26)
	var happy: bool = anim == "hop" or anim == "wave"
	if happy:
		draw_arc(m + Vector2(0, -4), 12.0, 0.2, PI - 0.2, 10, Color("#6b2a2a"), 4.0)
	elif anim == "slump" or mood == "worried":
		draw_arc(m + Vector2(0, 10), 10.0, PI + 0.4, TAU - 0.4, 10, Color("#6b2a2a"), 4.0)
	elif anim == "huff" or mood == "grumpy":
		draw_line(m + Vector2(-8, 3), m + Vector2(10, 0), Color("#6b2a2a"), 4.0)
	else:
		draw_arc(m + Vector2(0, -2), 8.0, 0.3, PI - 0.3, 8, Color("#6b2a2a"), 3.0)
	# accessories
	var acc: String = String(look.get("accessory", "none"))
	if acc == "beard":
		draw_colored_polygon(PackedVector2Array([c + Vector2(-24, 14), c + Vector2(34, 18), c + Vector2(30, 50), c + Vector2(0, 62), c + Vector2(-22, 44)]), Dr.shade(hair, 0.9))
		draw_arc(m + Vector2(0, -2), 8.0, 0.3, PI - 0.3, 8, Color("#4a1a1a"), 2.0)
	elif acc == "glasses":
		draw_arc(ey, 12.0, 0, TAU, 20, Color("#2a2018"), 3.0)
		draw_circle(ey, 11.0, Color(0.7, 0.9, 1.0, 0.18))
		draw_line(ey + Vector2(-12, 0), c + Vector2(-34, -2), Color("#2a2018"), 3.0)
	elif acc == "pipe":
		draw_line(m + Vector2(4, 4), m + Vector2(40, 12), Color("#3a2517"), 6.0)
		draw_circle(m + Vector2(42, 6), 10.0, Color("#3a2517"))
		var sm: float = fmod(_t * 0.7, 1.0)
		draw_circle(m + Vector2(44 + sm * 8, -8 - sm * 40), 5.0 + sm * 8.0, Color(0.85, 0.85, 0.9, 0.35 * (1.0 - sm)))
	# front hair
	match style:
		"short":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-40, -4), c + Vector2(-30, -38), c + Vector2(10, -46), c + Vector2(38, -26), c + Vector2(30, -14), c + Vector2(0, -22), c + Vector2(-26, -6)]), hair)
		"long", "bob":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-40, 6), c + Vector2(-34, -38), c + Vector2(8, -48), c + Vector2(38, -24), c + Vector2(26, -18), c + Vector2(-6, -26), c + Vector2(-24, -4)]), hair)
		"bun":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-38, 0), c + Vector2(-30, -38), c + Vector2(10, -46), c + Vector2(36, -24), c + Vector2(22, -16), c + Vector2(-10, -24), c + Vector2(-26, -6)]), hair)
		"curly":
			for i in range(7):
				var a: float = PI + float(i) * PI / 6.0
				draw_circle(c + Vector2(cos(a) * 34, sin(a) * 34 - 4), 13.0, hair)
		_:
			pass
	# hats
	match hat:
		"cap":
			draw_colored_polygon(_dome(c + Vector2(0, -14), 42.0, 30.0), Color("#3a4a50"))
			draw_rect(Rect2(c.x + 16, c.y - 18, 40, 8), Color("#2a3438"))
			draw_circle(c + Vector2(4, -34), 4.0, Pal.BRASS)
		"top":
			Dr.rrect(self, Rect2(c.x - 54, c.y - 30, 108, 12), 5.0, Color("#15181c"))
			Dr.rrect(self, Rect2(c.x - 30, c.y - 100, 62, 76), 8.0, Color("#1c2126"))
			draw_rect(Rect2(c.x - 30, c.y - 46, 62, 12), Pal.SIGNAL)
			draw_line(c + Vector2(-20, -96), c + Vector2(-20, -34), Color(1, 1, 1, 0.12), 3.0)
		"scarf":
			draw_colored_polygon(_dome(c + Vector2(-2, -8), 44.0, 38.0), Pal.SIGNAL.lerp(_c("coat"), 0.5))
			draw_circle(c + Vector2(-34, 12), 12.0, Pal.SIGNAL.lerp(_c("coat"), 0.5))
			draw_line(c + Vector2(-30, 14), c + Vector2(-38, 50), Pal.SIGNAL.lerp(_c("coat"), 0.5), 12.0)
			for i in range(4):
				draw_circle(c + Vector2(-26 + i * 16, -30 + abs(i - 1.5) * 4), 3.0, Color(1, 1, 1, 0.5))
		_:
			pass


func _dome(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(13):
		var a: float = PI + PI * float(i) / 12.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw_emote(head_c: Vector2) -> void:
	if emote == "":
		return
	var t: float = _emote_t
	match emote:
		"hearts":
			for i in range(3):
				var ph: float = fmod(t * 0.8 + float(i) * 0.33, 1.0)
				_heart(head_c + Vector2(-20 + i * 26, -60 - ph * 90), 9.0, Color(0.95, 0.35, 0.45, 1.0 - ph))
		"sweat":
			var ph2: float = fmod(t * 1.2, 1.0)
			var p: Vector2 = head_c + Vector2(30, -26 + ph2 * 40)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -12), p + Vector2(8, 4), p + Vector2(-8, 4)]), Color(0.6, 0.85, 1.0, 1.0 - ph2 * 0.6))
		"steam":
			for i in range(3):
				var ph3: float = fmod(t * 1.1 + float(i) * 0.33, 1.0)
				draw_circle(head_c + Vector2(-30 + i * 30, -50 - ph3 * 50), 8.0 + ph3 * 10.0, Color(0.9, 0.9, 0.95, 0.5 * (1.0 - ph3)))
		"zzz":
			for i in range(3):
				var ph4: float = fmod(t * 0.5 + float(i) * 0.33, 1.0)
				draw_string(ThemeDB.fallback_font, head_c + Vector2(20 + ph4 * 40, -40 - ph4 * 70), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 26 + i * 6, Color(0.9, 0.95, 1.0, 1.0 - ph4))
		_:
			pass
	if t > 6.0 and emote != "zzz" and emote != "sweat":
		emote = ""


func _heart(p: Vector2, r: float, col: Color) -> void:
	draw_circle(p + Vector2(-r * 0.5, 0), r * 0.6, col)
	draw_circle(p + Vector2(r * 0.5, 0), r * 0.6, col)
	draw_line(p + Vector2(-r * 0.55, r * 0.25), p + Vector2(0, r * 1.25), col, r * 0.95)
	draw_line(p + Vector2(r * 0.55, r * 0.25), p + Vector2(0, r * 1.25), col, r * 0.95)


func _draw_held() -> void:
	var h: Vector2 = _hand_f
	match held:
		"book":
			var flip: float = fmod(_t, 7.0)
			draw_colored_polygon(PackedVector2Array([h + Vector2(-4, -26), h + Vector2(30, -22), h + Vector2(30, 6), h + Vector2(-4, 4)]), Color("#e9dfc8"))
			draw_colored_polygon(PackedVector2Array([h + Vector2(-8, -24), h + Vector2(-4, -26), h + Vector2(-4, 4), h + Vector2(-8, 6)]), Color("#7a3a32"))
			for i in range(3):
				draw_line(h + Vector2(2, -18 + i * 7), h + Vector2(24, -16 + i * 7), Color(0, 0, 0, 0.3), 2.0)
			if flip < 0.5:   # page turn
				var w: float = sin(flip / 0.5 * PI) * 22.0
				draw_colored_polygon(PackedVector2Array([h + Vector2(13, -24), h + Vector2(13 + w, -28), h + Vector2(13 + w, 2), h + Vector2(13, 5)]), Color("#f6efdc"))
		"cup":
			draw_rect(Rect2(h.x - 2, h.y - 22, 20, 18), Color("#efe6d2"))
			draw_rect(Rect2(h.x - 2, h.y - 22, 20, 4), Color("#6a3a2a"))
			draw_arc(h + Vector2(18, -13), 6.0, -PI / 2.0, PI / 2.0, 8, Color("#efe6d2"), 3.0)
			for i in range(2):
				var ph: float = fmod(_t * 0.9 + i * 0.5, 1.0)
				draw_circle(h + Vector2(8 + sin(_t * 3.0 + i) * 3.0, -28 - ph * 26), 4.0 + ph * 3.0, Color(1, 1, 1, 0.35 * (1.0 - ph)))
		"punch":
			draw_line(h, h + Vector2(22, -14), Color("#c9a24a"), 5.0)
			draw_line(h, h + Vector2(24, -2), Color("#c9a24a"), 5.0)
			draw_circle(h + Vector2(24, -8), 5.0, Color("#8a6a2a"))
		"trolley":
			var o := Vector2(78, 0)
			draw_rect(Rect2(o.x, -104, 96, 10), Color("#6a4a2a"))
			draw_rect(Rect2(o.x, -104, 96, 3), Color(1, 0.9, 0.6, 0.5))
			draw_rect(Rect2(o.x + 4, -94, 88, 56), Color("#3a2a1c"))
			draw_rect(Rect2(o.x + 8, -88, 80, 44), Color("#5a3a22"))
			draw_line(Vector2(o.x - 8, -128), Vector2(o.x + 2, -104), Color("#c9a24a"), 4.0)
			draw_line(Vector2(o.x - 8, -128), Vector2(o.x - 22, -126), Color("#c9a24a"), 4.0)
			draw_circle(Vector2(o.x + 22, -22), 14.0, Color("#1b252b"))
			draw_circle(Vector2(o.x + 78, -22), 14.0, Color("#1b252b"))
			draw_circle(Vector2(o.x + 22, -22), 4.0, Color("#c9a24a"))
			draw_circle(Vector2(o.x + 78, -22), 4.0, Color("#c9a24a"))
			draw_rect(Rect2(o.x + 12, -124, 18, 20), Color("#d9d2c0"))
			draw_rect(Rect2(o.x + 44, -118, 12, 14), Color("#c8503c"))
			draw_rect(Rect2(o.x + 66, -120, 16, 16), Color("#efe6d2"))
