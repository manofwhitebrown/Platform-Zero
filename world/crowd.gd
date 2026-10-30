class_name Crowd
extends Node2D
## B1.4: draws every passenger from Sim.get_passengers() with the actor rig.
## - position / facing come straight from Sim; this node only chooses the animation + tells.
## - speech bubbles with typewriter text and per-person voice blips
## - reactions: happy hop + hearts, sad slump, annoyed huff + steam; confetti on correct handover

signal handover_story(iid: String, pid: String, result: Dictionary)

const FLOOR_Y: float = 880.0
const CHARS_PER_S: float = 30.0
const BUBBLE_MAX_W: float = 440.0
const FONT_SIZE: int = 30

var world: Node2D
var actors: Dictionary = {}
var _info: Dictionary = {}
var _bubbles: Dictionary = {}
var _confetti: Array = []
var _fx: DrawProxy
var _t: float = 0.0
var _blip: AudioStreamWAV
var _voices: Array = []
var _voice_i: int = 0
var _drop_pid: String = ""


func setup(p_world: Node2D) -> void:
	world = p_world
	z_index = 5
	_fx = DrawProxy.new()
	_fx.fn = _draw_fx
	_fx.z_index = 30
	add_child(_fx)
	_blip = _make_blip()
	for i in range(3):
		var pl := AudioStreamPlayer.new()
		pl.stream = _blip
		pl.volume_db = -17.0
		add_child(pl)
		_voices.append(pl)
	Events.passenger_state_changed.connect(_on_state)
	Events.passenger_said.connect(_on_said)
	Events.passenger_left.connect(_on_left)
	Events.handover_result.connect(_on_handover)


static func _make_blip() -> AudioStreamWAV:
	var rate: int = 22050
	var n: int = int(float(rate) * 0.055)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t: float = float(i) / float(rate)
		var env: float = 1.0 - float(i) / float(n)
		env = env * env
		var v: float = (sin(TAU * 420.0 * t) * 0.6 + sin(TAU * 840.0 * t) * 0.22 + sin(TAU * 1260.0 * t) * 0.08) * env
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 11000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s


# ------------------------------------------------------------------ actors
func front_pid() -> String:
	var q: Array = Sim.get_queue()
	if q.is_empty():
		return ""
	var pid: String = String(q[0])
	for p in Sim.get_passengers():
		if String(p["pid"]) == pid:
			var st: String = String(p["state"])
			return pid if (st == "asking" or st == "waiting") else ""
	return ""


func actor_of(pid: String) -> Passenger:
	return actors.get(pid) as Passenger


func set_drop_target(pid: String) -> void:
	_drop_pid = pid


## Screen-space-independent world rect of a passenger (for drag-and-drop hit tests).
func world_rect_of(pid: String) -> Rect2:
	var a: Passenger = actor_of(pid)
	if a == null:
		return Rect2()
	return Rect2(a.position.x - 120.0, FLOOR_Y - 400.0, 240.0, 420.0)


func _look_for(p: Dictionary) -> Dictionary:
	var lk: Dictionary = p.get("look", {})
	if not lk.is_empty():
		return lk
	var w: Dictionary = Content.owner_by_id(String(p.get("owner_id", "")))
	var ol: Dictionary = w.get("look", {})
	if not ol.is_empty():
		return ol
	return Passenger.make_look(hash(String(p["pid"])))


func _spawn_actor(p: Dictionary) -> Passenger:
	var pid: String = String(p["pid"])
	var a := Passenger.new()
	a.position = Vector2(float(p["x"]), FLOOR_Y)
	add_child(a)
	a.setup(_look_for(p), String(p.get("mood", "calm")), pid)
	a.face = int(p.get("facing", -1))
	actors[pid] = a
	var fresh: bool = String(p.get("state", "")) == "walking" and float(p.get("t", 0.0)) < 0.5
	_info[pid] = {"still": 0.0, "age": 0.0, "fade": 0.0 if fresh else 1.0, "state_t": 0.0, "pitch": 0.75 + float(hash(pid) % 100) / 100.0 * 0.85}
	a.modulate.a = 0.0 if fresh else 1.0
	return a


func _remove(pid: String) -> void:
	var a: Passenger = actors.get(pid) as Passenger
	if a:
		a.queue_free()
	actors.erase(pid)
	_info.erase(pid)
	_bubbles.erase(pid)


func _process(dt: float) -> void:
	_t += dt
	var seen: Dictionary = {}
	for p in Sim.get_passengers():
		var pid: String = String(p["pid"])
		seen[pid] = true
		var a: Passenger = actors.get(pid) as Passenger
		if a == null:
			a = _spawn_actor(p)
		_update_actor(a, p, dt)
	for pid in actors.keys():
		if not seen.has(String(pid)):
			_remove(String(pid))
	_update_bubbles(dt)
	_update_confetti(dt)
	_fx.queue_redraw()


func _update_actor(a: Passenger, p: Dictionary, dt: float) -> void:
	var pid: String = String(p["pid"])
	var info: Dictionary = _info[pid]
	var x: float = float(p["x"])
	var dx: float = x - a.position.x
	a.position.x = x
	var moving: bool = absf(dx) > 0.02
	if moving:
		a._walk_ph += absf(dx) * 0.045
		info["still"] = 0.0
	else:
		info["still"] = float(info["still"]) + dt
	info["age"] = float(info["age"]) + dt
	info["state_t"] = float(info["state_t"]) + dt
	var state: String = String(p["state"])
	if state == "walking" or state == "queued" or state == "leaving" or state == "at_counter":
		a.face = int(p.get("facing", -1))
	else:
		a.face = int(p.get("facing", a.face))
	if state == "seated" and String(p.get("kind", "")) == "ambient" and String(p.get("role", "")) == "":
		a.face = CarProps.orient(int(p.get("slot", 0)))   # sit the way the drawn seat faces
	var lm: String = String(p.get("leave_mood", ""))
	a.mood = String(p.get("mood", "calm"))
	a.gait = lm if state == "leaving" or state == "receiving" else ""
	if lm == "annoyed" and state == "leaving":
		a.mood = "grumpy"
	var want: String = _anim_for(p, state, moving, float(info["still"]))
	if String(p.get("kind", "")) == "ambient":
		var rt: String = String(p.get("routine", ""))
		var seated: bool = state == "seated"
		if rt == "conductor" and not moving and state != "seated":
			want = "punch" if float(info["still"]) > 0.4 else want
		a.held = "book" if seated and rt == "reading" else ("cup" if seated and rt == "eating" else ("trolley" if rt == "vendor" else ("punch" if rt == "conductor" else "")))
		if seated and rt == "napping" and a.emote == "":
			a.do_emote("zzz")
		elif rt != "napping" and a.emote == "zzz":
			a.emote = ""
	if a.anim != want:
		a.play(want)
	# fade in at the door
	if float(info["fade"]) < 1.0:
		info["fade"] = minf(1.0, float(info["fade"]) + dt * 2.4)
		a.modulate.a = float(info["fade"])
	# imposters sweat while they wait at the counter
	if String(p.get("kind", "")) == "imposter" and (state == "asking" or state == "waiting") and a.emote == "":
		a.do_emote("sweat")
	# door position: slightly in front so the doorway reads as a doorway
	a.z_index = 1 if state == "at_counter" or state == "asking" or state == "waiting" else 0


func _anim_for(p: Dictionary, state: String, moving: bool, still: float) -> String:
	var mood: String = String(p.get("mood", "calm"))
	match state:
		"seated":
			match String(p.get("routine", "")):
				"reading": return "sit_read"
				"napping": return "sit_nap"
				"eating": return "sit_eat"
				"staring": return "sit_stare"
				"chatting": return "sit_chat"
				"kids": return "sit_kids"
			return "sit"
		"standing_up":
			return "idle"
		"walking", "queued":
			if moving:
				return "walk"
			if state == "walking" and mood == "shy" and still > 0.25:
				return "peek"
			if still > 0.6:
				return _tell(mood)
			return "idle"
		"at_counter", "asking", "waiting":
			return _tell(mood)
		"receiving":
			return "hop" if String(p.get("leave_mood", "")) == "happy" else "idle"
		"leaving":
			return "walk" if moving else "idle"
	return "idle"


## Mood tells at the counter (plan section 5).
static func _tell(mood: String) -> String:
	match mood:
		"worried": return "wring"
		"hurried": return "tap"
		"shy": return "peek"
		"grumpy": return "cross"
		_: return "lean"


func _on_state(pid: String, state: String) -> void:
	var a: Passenger = actors.get(pid) as Passenger
	if a == null:
		return
	if _info.has(pid):
		(_info[pid] as Dictionary)["state_t"] = 0.0
	var lm: String = ""
	for p in Sim.get_passengers():
		if String(p["pid"]) == pid:
			lm = String(p.get("leave_mood", ""))
	match state:
		"receiving":
			if lm == "happy":
				a.do_emote("hearts")
				var pos: Vector2 = Vector2(a.position.x, FLOOR_Y - 260.0)
				_burst(pos, 26)
		"leaving":
			if lm == "annoyed":
				a.do_emote("steam")
			elif lm == "happy" and a.emote == "":
				a.do_emote("hearts")
		"standing_up":
			pass


func _on_left(pid: String, _happy: bool) -> void:
	_bubbles.erase(pid)


func _on_handover(iid: String, pid: String, res: Dictionary) -> void:
	if bool(res.get("correct", false)):
		var a: Passenger = actors.get(pid) as Passenger
		if a:
			_burst(Vector2(a.position.x, FLOOR_Y - 300.0), 90)
		_on_said(pid, String(res.get("line", "")))
		handover_story.emit(iid, pid, res)
	elif bool(res.get("was_imposter", false)):
		pass


# ------------------------------------------------------------------ speech
func _on_said(pid: String, line: String) -> void:
	var nm: String = ""
	for p in Sim.get_passengers():
		if String(p["pid"]) == pid:
			nm = String(p.get("name", ""))
	if actors.has(pid) and is_instance_valid(actors[pid]):
		var ap: Variant = actors[pid]
		if ap is Passenger:
			(ap as Passenger).talk(line.length())
	_bubbles[pid] = {"text": line, "shown": 0.0, "age": 0.0, "name": nm, "blip_at": 0}


func _update_bubbles(dt: float) -> void:
	var fp: String = front_pid()
	for pid in _bubbles.keys():
		var b: Dictionary = _bubbles[pid]
		var total: int = String(b["text"]).length()
		var before: float = float(b["shown"])
		b["shown"] = minf(float(total), before + dt * CHARS_PER_S * _speed_mul())
		if int(float(b["shown"])) > int(before) and int(float(b["shown"])) % 2 == 0:
			var ch: String = String(b["text"]).substr(maxi(0, int(float(b["shown"])) - 1), 1)
			if ch != " " and ch != "":
				_play_blip(String(pid))
		if float(b["shown"]) >= float(total):
			b["age"] = float(b["age"]) + dt
		# bubbles of people who are not at the front fade after a while; the front one stays
		var hold: float = 999.0 if String(pid) == fp else 4.5
		if float(b["age"]) > hold + 0.6:
			_bubbles.erase(pid)


func _play_blip(pid: String) -> void:
	if _voices.is_empty() or not _info.has(pid):
		return
	var pl: AudioStreamPlayer = _voices[_voice_i % _voices.size()] as AudioStreamPlayer
	_voice_i += 1
	pl.pitch_scale = float((_info[pid] as Dictionary)["pitch"]) * randf_range(0.94, 1.08)
	pl.play()


func _wrap(text: String, font: Font, max_w: float) -> Array:
	var lines: Array = []
	var cur: String = ""
	for word in text.split(" ", false):
		var trial: String = word if cur == "" else cur + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x > max_w and cur != "":
			lines.append(cur)
			cur = word
		else:
			cur = trial
	if cur != "":
		lines.append(cur)
	return lines


# ------------------------------------------------------------------ confetti
func _burst(pos: Vector2, n: int) -> void:
	if Pal.reduced_motion():
		return
	var cols: Array = [Pal.LAMP, Pal.SIGNAL, Pal.MIST, Pal.PARCHMENT, Color(1.0, 0.72, 0.4)]
	for i in range(n):
		var a: float = randf_range(-PI * 0.95, -PI * 0.05)
		var sp: float = randf_range(260.0, 760.0)
		_confetti.append({"p": pos, "v": Vector2(cos(a), sin(a)) * sp, "c": cols[randi() % cols.size()], "r": randf() * TAU, "rv": randf_range(-9.0, 9.0), "life": randf_range(1.3, 2.2), "age": 0.0, "w": randf_range(12.0, 24.0)})


func _update_confetti(dt: float) -> void:
	for c in _confetti:
		c["age"] = float(c["age"]) + dt
		c["v"] = (c["v"] as Vector2) * (1.0 - dt * 0.9) + Vector2(0, 900.0) * dt
		c["p"] = (c["p"] as Vector2) + (c["v"] as Vector2) * dt
		c["r"] = float(c["r"]) + float(c["rv"]) * dt
	_confetti = _confetti.filter(func(c: Dictionary) -> bool: return float(c["age"]) < float(c["life"]))


# ------------------------------------------------------------------ drawing (above the actors)
func _draw_fx(ci: CanvasItem) -> void:
	# drop-target halo while dragging an item over the front claimant
	if _drop_pid != "" and actors.has(_drop_pid):
		var a: Passenger = actors[_drop_pid] as Passenger
		var pulse: float = 0.5 + 0.5 * sin(_t * 6.0)
		var c: Vector2 = Vector2(a.position.x, FLOOR_Y - 170.0)
		ci.draw_arc(c, 150.0 + pulse * 10.0, 0, TAU, 56, Color(1.0, 0.85, 0.4, 0.45 + 0.4 * pulse), 6.0)
		ci.draw_arc(c, 128.0, 0, TAU, 48, Color(1.0, 0.9, 0.6, 0.25), 3.0)
	for pid in _bubbles.keys():
		_draw_bubble(ci, String(pid), _bubbles[pid] as Dictionary)
	for c in _confetti:
		var k: float = 1.0 - float(c["age"]) / float(c["life"])
		var w: float = float(c["w"])
		var rot: float = float(c["r"])
		var sx: float = absf(cos(rot * 1.7))
		var p: Vector2 = c["p"]
		var d: Vector2 = Vector2(cos(rot), sin(rot)) * w * 0.5
		var col: Color = c["c"]
		col.a = clampf(k * 2.0, 0.0, 1.0)
		ci.draw_line(p - d, p + d, col, maxf(3.0, w * 0.55 * maxf(sx, 0.3)))


func _speed_mul() -> float:
	match Settings.get_str("text_speed", "normal"):
		"slow":
			return 0.6
		"fast":
			return 1.8
		"instant":
			return 50.0
	return 1.0


## Colorblind aid: a shape per mood in the bubble corner (never colour alone).
func _mood_glyph(ci: CanvasItem, c: Vector2, mood: String, fade: float) -> void:
	var col := Color(Pal.INK.r, Pal.INK.g, Pal.INK.b, fade)
	ci.draw_circle(c, 17.0, Color(Pal.BRASS.r, Pal.BRASS.g, Pal.BRASS.b, 0.35 * fade))
	match mood:
		"hurried":
			Dr.poly(ci, PackedVector2Array([c + Vector2(-9, -9), c + Vector2(0, 0), c + Vector2(-9, 9)]), col)
			Dr.poly(ci, PackedVector2Array([c + Vector2(1, -9), c + Vector2(10, 0), c + Vector2(1, 9)]), col)
		"worried":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-10, 2), c + Vector2(-5, -4), c + Vector2(0, 2), c + Vector2(5, -4), c + Vector2(10, 2)]), col, 3.0)
		"grumpy":
			ci.draw_line(c + Vector2(-8, -8), c + Vector2(8, 8), col, 4.0)
			ci.draw_line(c + Vector2(8, -8), c + Vector2(-8, 8), col, 4.0)
		"shy":
			ci.draw_circle(c, 4.0, col)
		_:
			ci.draw_arc(c, 8.0, 0, TAU, 16, col, 3.0)


func _draw_bubble(ci: CanvasItem, pid: String, b: Dictionary) -> void:
	var a: Passenger = actors.get(pid) as Passenger
	if a == null:
		return
	var font: Font = ThemeDB.fallback_font
	var full: String = String(b["text"])
	var shown: String = full.substr(0, int(float(b["shown"])))
	var lines_full: Array = _wrap(full, font, BUBBLE_MAX_W - 44.0)
	var lines_shown: Array = _wrap_shown(lines_full, shown)
	var line_h: float = 40.0
	var nm: String = String(b.get("name", ""))
	var head_h: float = 34.0 if nm != "" else 0.0
	var inner_w: float = 0.0
	for ln in lines_full:
		inner_w = maxf(inner_w, font.get_string_size(String(ln), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	if nm != "":
		inner_w = maxf(inner_w, font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x)
	var w: float = inner_w + 44.0
	var h: float = line_h * float(lines_full.size()) + 28.0 + head_h
	var seated: bool = a.anim == "sit"
	var head_y: float = a.position.y - (250.0 if seated else 345.0) * a.scale_f * float(a.look.get("height", 1.0)) / 0.92
	var fade: float = 1.0
	var hold_over: float = float(b["age"])
	if hold_over > 4.5 and String(pid) != front_pid():
		fade = clampf(1.0 - (hold_over - 4.5) / 0.6, 0.0, 1.0)
	var vis: Vector2 = get_viewport().get_visible_rect().size
	var cam: Camera2D = (world as TrainWorld).cam if world is TrainWorld else null
	var cx: float = cam.get_screen_center_position().x if cam else a.position.x
	var half: float = (vis.x / maxf(cam.zoom.x if cam else 1.0, 0.01)) * 0.5
	var bx: float = clampf(a.position.x - w * 0.5, cx - half + 24.0, cx + half - w - 24.0)
	var by: float = head_y - h - 34.0
	var rect := Rect2(bx, by, w, h)
	var ink: Color = Color(Pal.INK.r, Pal.INK.g, Pal.INK.b, fade)
	Dr.rrect(ci, Rect2(rect.position + Vector2(0, 6), rect.size), 26.0, Color(0, 0, 0, 0.35 * fade))
	Dr.rrect(ci, rect, 26.0, Color(Pal.PARCHMENT.r, Pal.PARCHMENT.g, Pal.PARCHMENT.b, 0.97 * fade))
	ci.draw_arc(rect.position + Vector2(26, 26), 26.0, PI, PI * 1.5, 8, Color(Pal.BRASS.r, Pal.BRASS.g, Pal.BRASS.b, 0.0), 1.0)
	# tail towards the speaker
	var tx: float = clampf(a.position.x, rect.position.x + 40.0, rect.end.x - 40.0)
	var tail := PackedVector2Array([Vector2(tx - 16, rect.end.y - 2), Vector2(tx + 16, rect.end.y - 2), Vector2(a.position.x, head_y - 8.0)])
	Dr.poly(ci, tail, Color(Pal.PARCHMENT.r, Pal.PARCHMENT.g, Pal.PARCHMENT.b, 0.97 * fade))
	var y: float = rect.position.y + 16.0
	if Settings.get_bool("colorblind", false):
		_mood_glyph(ci, Vector2(rect.end.x - 26.0, rect.position.y + 26.0), String(a.mood), fade)
	if nm != "":
		ci.draw_string(font, Vector2(rect.position.x + 22, y + 22), nm.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Pal.BRASS.r * 0.8, Pal.BRASS.g * 0.7, Pal.BRASS.b * 0.5, fade))
		y += head_h
	for i in range(lines_shown.size()):
		ci.draw_string(font, Vector2(rect.position.x + 22, y + 30 + float(i) * line_h), String(lines_shown[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, ink)
	# typing caret
	if float(b["shown"]) < float(full.length()) and fmod(_t, 0.5) < 0.3:
		var li: int = maxi(lines_shown.size() - 1, 0)
		var lw: float = font.get_string_size(String(lines_shown[li]) if lines_shown.size() > 0 else "", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		ci.draw_rect(Rect2(rect.position.x + 24 + lw, y + 8.0 + float(li) * line_h, 3, 28), ink)


## Split the typed-so-far string along the same line breaks as the full text.
func _wrap_shown(lines_full: Array, shown: String) -> Array:
	var out: Array = []
	var used: int = 0
	for ln in lines_full:
		var s: String = String(ln)
		var remain: int = shown.length() - used
		if remain <= 0:
			break
		out.append(s.substr(0, remain))
		used += s.length() + 1
	return out
