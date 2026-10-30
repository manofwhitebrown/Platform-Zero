extends Node
## Audio autoload (AI-C). Reads res://audio/manifest.json (made by tools/gen_audio.py).
## API:  Audio.play(id, vol_db=0, pitch=1)  Audio.loop(id)  Audio.stop_loop(id)  Audio.blip(mood)
##       Audio.tool_sound(name)  Audio.footstep()  Audio.set_ambience(car_kind, weather, in_tunnel, speed)
##       Audio.music(state: "cozy"|"travel"|"suspense"|"")  Audio.duck_for(sec)  Audio.apply_settings()
## Everything reacts to Events on its own. By default ambience follows the player's car, the weather and
## the train; calling set_ambience() by hand switches auto_ambience off. Safe when files are missing.
## Settings keys (bool, via Settings): "sound" (master), "music", "ambience" (the last two default true).

const MANIFEST_PATH := "res://audio/manifest.json"
const BUS_NAMES: PackedStringArray = ["sfx", "ambience", "music", "ui"]
const CAR_KINDS: PackedStringArray = ["obs", "sleep", "lp", "pass", "dine", "lug"]
const CAR_W := 1800.0
const POOL_SIZE := 14
const OFF_DB := -80.0
const MUSIC_IDS := {"cozy": "music_cozy", "travel": "music_travel", "suspense": "music_suspense"}

var auto_ambience: bool = true
var auto_music: bool = true
var imposter_music: bool = true

var _man: Dictionary = {}
var _cache: Dictionary = {}
var _pool: Array = []
var _pool_i: int = 0
var _loops: Dictionary = {}
var _targets: Dictionary = {}
var _kill: Dictionary = {}
var _gates: Dictionary = {}
var _music_players: Array = []
var _music_idx: int = 0
var _music_id: String = ""
var _duck: float = 0.0
var _duck_target: float = 0.0
var _duck_token: int = 0
var _sound_on: bool = true
var _tunnel: bool = false
var _weather: String = "clear"
var _car_kind: String = "lp"
var _speed: float = 1.0
var _tick_t: float = 0.2
var _step_t: float = 0.0
var _last_x: float = -1.0
var _last_tokens: int = -1
var _tier: int = -1
var _thunder_t: float = 20.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_manifest()
	_make_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "music"
		m.volume_db = OFF_DB
		add_child(m)
		_music_players.append(m)
	apply_settings()
	_connect_events()


# ---------- setup ----------
func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_man = d


func _make_buses() -> void:
	for b in BUS_NAMES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")


func apply_settings() -> void:
	_sound_on = Settings.get_bool("sound", true)
	AudioServer.set_bus_mute(0, not _sound_on)
	var mi: int = AudioServer.get_bus_index("music")
	if mi >= 0:
		AudioServer.set_bus_mute(mi, not Settings.get_bool("music", true))
	var ai: int = AudioServer.get_bus_index("ambience")
	if ai >= 0:
		AudioServer.set_bus_mute(ai, not Settings.get_bool("ambience", true))


func has_sound(id: String) -> bool:
	return _man.has(id)


# ---------- one shots ----------
func _stream(path: String, loop: bool) -> AudioStream:
	var key: String = path + ("#l" if loop else "")
	if _cache.has(key):
		return _cache[key]
	if path == "" or not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if s != null and loop:
		if s is AudioStreamWAV:
			var w: AudioStreamWAV = s
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * float(w.mix_rate))
		else:
			s.set("loop", true)
	_cache[key] = s
	return s


func _pick(id: String) -> String:
	var e: Dictionary = _man[id]
	var v: Array = e.get("variants", [])
	if v.is_empty():
		return String(e.get("file", ""))
	return String(v[randi() % v.size()])


func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not (p as AudioStreamPlayer).playing:
			return p
	_pool_i = (_pool_i + 1) % _pool.size()
	return _pool[_pool_i]


func _gate(key: String, ms: int) -> bool:
	var now: int = Time.get_ticks_msec()
	if now - int(_gates.get(key, -100000)) < ms:
		return false
	_gates[key] = now
	return true


func play(id: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _sound_on or not _man.has(id):
		return
	var e: Dictionary = _man[id]
	var s: AudioStream = _stream(_pick(id), false)
	if s == null:
		return
	var p: AudioStreamPlayer = _free_player()
	p.stream = s
	p.bus = String(e.get("bus", "sfx"))
	p.volume_db = float(e.get("volume_db", 0.0)) + vol_db
	p.pitch_scale = pitch
	p.play()


func blip(mood: String, vol_db: float = 0.0) -> void:
	var id: String = "blip_" + mood
	if not _man.has(id):
		id = "blip_calm"
	play(id, vol_db, randf_range(0.97, 1.03))


func tool_sound(tool_name: String) -> void:
	play("tool_" + tool_name)


func footstep() -> void:
	play("footstep", randf_range(-3.0, 0.0), randf_range(0.92, 1.08))


func _later(sec: float, f: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(f)


func _speak(mood: String, n: int, vol_db: float) -> void:
	for i in n:
		blip(mood, vol_db)
		await get_tree().create_timer(randf_range(0.075, 0.105)).timeout


# ---------- loops and ambience layers ----------
func _ensure_loop(id: String) -> AudioStreamPlayer:
	if _loops.has(id):
		return _loops[id]
	var e: Dictionary = _man[id]
	var s: AudioStream = _stream(String(e.get("file", "")), true)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = String(e.get("bus", "ambience"))
	p.volume_db = OFF_DB
	add_child(p)
	p.play()
	_loops[id] = p
	return p


func _set_target(id: String, db: float, kill_when_off: bool = false) -> void:
	if not _man.has(id):
		return
	if db <= OFF_DB + 1.0 and not _loops.has(id):
		return
	if _ensure_loop(id) == null:
		return
	_targets[id] = maxf(OFF_DB, db)
	if kill_when_off:
		_kill[id] = true
	else:
		_kill.erase(id)


func loop(id: String, vol_db: float = 0.0) -> void:
	if _man.has(id):
		_set_target(id, float((_man[id] as Dictionary).get("volume_db", 0.0)) + vol_db)


func stop_loop(id: String) -> void:
	if _loops.has(id):
		_targets[id] = OFF_DB
		_kill[id] = true


func _lay(id: String, x: float) -> void:
	if not _man.has(id):
		return
	var base: float = float((_man[id] as Dictionary).get("volume_db", 0.0))
	_set_target(id, base + (linear_to_db(x) if x > 0.01 else OFF_DB))


func _norm_car(k: String) -> String:
	k = k.to_lower().replace("car_", "")
	if k.begins_with("obs"):
		return "obs"
	if k.begins_with("sle"):
		return "sleep"
	if k.begins_with("din"):
		return "dine"
	if k.begins_with("pas"):
		return "pass"
	if k.begins_with("lug"):
		return "lug"
	if k.begins_with("lp") or k.begins_with("lost"):
		return "lp"
	return k


func set_ambience(car_kind: String = "lp", weather: String = "clear", in_tunnel: bool = false, speed: float = 1.0) -> void:
	auto_ambience = false
	_apply(car_kind, weather, in_tunnel, speed)


func _apply(car_kind: String, weather: String, tunnel: bool, spd: float) -> void:
	var kind: String = _norm_car(car_kind)
	var entered_tunnel: bool = tunnel and not _tunnel
	_car_kind = kind
	_weather = weather
	_tunnel = tunnel
	_speed = clampf(spd, 0.0, 1.0)
	if entered_tunnel:
		play("tunnel_whoosh")
	var out_g: float = 0.3
	if kind == "obs":
		out_g = 1.0
	elif kind == "lug":
		out_g = 0.5
	if tunnel:
		out_g = 0.0
	var boost: float = 1.3 if tunnel else 1.0
	_lay("train_rumble_slow", clampf(1.0 - absf(_speed - 0.35) / 0.65, 0.0, 1.0) * boost)
	_lay("train_rumble_fast", clampf((_speed - 0.45) / 0.55, 0.0, 1.0) * boost)
	_lay("rail_clack_slow", 0.0 if tunnel else clampf(1.0 - absf(_speed - 0.35) / 0.5, 0.0, 1.0))
	_lay("rail_clack_fast", clampf((_speed - 0.5) / 0.5, 0.0, 1.0))
	_lay("lamp_hum_loop", 1.0 if kind == "lp" else 0.2)
	var crowd: float = 0.0
	if kind == "dine":
		crowd = 1.0
	elif kind == "pass":
		crowd = 0.25
	elif kind == "lp":
		crowd = 0.15
	_lay("dining_murmur", crowd)
	var rain: float = 0.0
	var wind: float = 0.05 * _speed
	match weather:
		"rain":
			rain = 0.9
			wind = 0.3
		"snow":
			wind = 0.8
		"fog":
			wind = 0.15
	_lay("rain_loop", rain * out_g)
	_lay("wind_loop", wind * out_g)


# ---------- music ----------
func music(state: String) -> void:
	var id: String = String(MUSIC_IDS.get(state, ""))
	if id == _music_id:
		return
	_music_id = id
	var old: AudioStreamPlayer = _music_players[_music_idx]
	_music_idx = 1 - _music_idx
	var fresh: AudioStreamPlayer = _music_players[_music_idx]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", OFF_DB, 2.5)
	if id != "" and _man.has(id):
		var s: AudioStream = _stream(String((_man[id] as Dictionary).get("file", "")), true)
		if s != null:
			fresh.stream = s
			fresh.volume_db = OFF_DB
			fresh.play()
			tw.tween_property(fresh, "volume_db", float((_man[id] as Dictionary).get("volume_db", 0.0)), 3.0)
	_later(3.0, func() -> void:
		if old != _music_players[_music_idx]:
			old.stop())


func duck_for(sec: float, db: float = 9.0) -> void:
	_duck_target = db
	_duck_token += 1
	var tok: int = _duck_token
	_later(sec, func() -> void:
		if tok == _duck_token:
			_duck_target = 0.0)


# ---------- per-frame ----------
func _process(dt: float) -> void:
	for id in _targets.keys():
		var p: AudioStreamPlayer = _loops.get(id)
		if p == null:
			_targets.erase(id)
			continue
		p.volume_db = move_toward(p.volume_db, float(_targets[id]), 50.0 * dt)
		if _kill.has(id) and p.volume_db <= OFF_DB + 0.5 and float(_targets[id]) <= OFF_DB + 0.5:
			p.queue_free()
			_loops.erase(id)
			_targets.erase(id)
			_kill.erase(id)
	var mi: int = AudioServer.get_bus_index("music")
	_duck = move_toward(_duck, _duck_target, 20.0 * dt)
	if mi >= 0:
		AudioServer.set_bus_volume_db(mi, -_duck)
	_step_t -= dt
	if _step_t <= 0.0:
		_step_t = 0.27
		_check_steps()
	_tick_t -= dt
	if _tick_t <= 0.0:
		_tick_t = 0.4
		_tick()


func _check_steps() -> void:
	var x: float = float(Sim.get_player().get("x", 0.0))
	if _last_x >= 0.0 and absf(x - _last_x) > 4.0:
		footstep()
	_last_x = x


func _tick() -> void:
	var tr: Dictionary = Sim.get_train()
	var st: String = String(tr.get("state", "moving"))
	var ph: float = float(tr.get("phase_t", 0.0))
	var spd: float = 1.0
	match st:
		"arriving":
			spd = lerpf(1.0, 0.12, ph)
		"stopped":
			spd = 0.0
		"departing":
			spd = lerpf(0.12, 1.0, ph)
	var pl: Dictionary = Sim.get_player()
	if auto_ambience:
		var idx: int = clampi(int(float(pl.get("x", 4500.0)) / CAR_W), 0, CAR_KINDS.size() - 1)
		_apply(String(CAR_KINDS[idx]), String(tr.get("weather", "clear")), _tunnel, spd)
	if _weather == "rain" and not _tunnel:
		_thunder_t -= 0.4
		if _thunder_t <= 0.0:
			_thunder_t = randf_range(20.0, 45.0)
			play("thunder", -3.0 if _car_kind == "obs" else -9.0)
	var tier: int = int(pl.get("tier", 0))
	if _tier >= 0 and tier > _tier:
		_later(1.2, func() -> void: play("tier_up"))
	_tier = tier
	if auto_music:
		music(_pick_music(st))


func _pick_music(st: String) -> String:
	if imposter_music:
		for p in Sim.get_passengers():
			if String(p.get("kind", "")) == "imposter" and String(p.get("state", "")) in ["at_counter", "asking"]:
				return "suspense"
	return "travel" if st == "moving" else "cozy"


# ---------- events ----------
func _connect_events() -> void:
	Events.train_state_changed.connect(_on_train)
	Events.passenger_state_changed.connect(_on_pstate)
	Events.passenger_said.connect(_on_said)
	Events.handover_result.connect(_on_handover)
	Events.tokens_changed.connect(_on_tokens)
	Events.toast.connect(_on_toast)
	Events.car_unlocked.connect(_on_car_unlocked)
	Events.clue_revealed_v2.connect(_on_clue)
	Events.item_moved.connect(_on_item_moved)


func _pax(pid: String) -> Dictionary:
	for p in Sim.get_passengers():
		if String(p.get("pid", "")) == pid:
			return p
	return {}


func _on_train(state: String, _stop: Dictionary) -> void:
	match state:
		"arriving":
			play("brake_squeal")
		"stopped":
			play("steam_hiss")
			_later(1.0, func() -> void: play("door_slide"))
		"departing":
			play("whistle_depart")
			_later(1.2, func() -> void: play("chuff"))


func _on_pstate(pid: String, state: String) -> void:
	var p: Dictionary = _pax(pid)
	if p.is_empty() or String(p.get("kind", "")) == "ambient":
		return
	var mood: String = String(p.get("mood", "calm"))
	match state:
		"queued":
			if mood == "grumpy":
				play("knock_grumpy")
			elif mood == "shy":
				play("knock_shy")
			else:
				play("door_slide", -4.0)
		"at_counter":
			play("counter_bell")
		"leaving":
			var lm: String = String(p.get("leave_mood", ""))
			if lm == "annoyed" or lm == "sad":
				play("refuse")
			_later(0.5, func() -> void: play("door_slide", -6.0))


func _on_said(pid: String, line: String) -> void:
	var p: Dictionary = _pax(pid)
	var ambient: bool = String(p.get("kind", "ambient")) == "ambient"
	if ambient and not _gate("amb_said", 600):
		return
	_speak(String(p.get("mood", "calm")), clampi(line.length() / 9, 2, 7), -9.0 if ambient else -2.0)


func _on_handover(_iid: String, _pid: String, result: Dictionary) -> void:
	if bool(result.get("correct", false)):
		play("handover_success")
		duck_for(2.5, 5.0)
	else:
		play("refuse")


func _on_tokens(v: int) -> void:
	if _last_tokens >= 0 and v > _last_tokens and _gate("clink", 120):
		play("token_clink", 0.0, randf_range(0.95, 1.08))
	_last_tokens = v


func _on_toast(_text: String, kind: String) -> void:
	if kind == "story":
		play("page_flip")
		duck_for(4.0)
	elif kind == "good":
		play("toast")
	else:
		play("toast", -4.0)


func _on_car_unlocked(_car_id: String) -> void:
	play("car_unlocked")


func _on_clue(_iid: String, _clue: Dictionary) -> void:
	play("clue_found")


func _on_item_moved(_iid: String, loc: String) -> void:
	if (loc == "bench" or loc == "shelf") and _gate("rustle", 200):
		play("paper_rustle", -4.0)
