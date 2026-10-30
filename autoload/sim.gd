extends Node
## Sim v2 (A1.1-A1.5): the brain. World is 1D: x in px from the rear of the train.
## Public API = CONTRACT v2 (queries + commands return Dictionaries with {ok,...}).
## All randomness goes through `rng` (seed = seed_base + stop_index * 7919) so a run is
## deterministic. `tick(dt)` is the only thing that advances time; _process just feeds it.

const SAVE_VERSION: int = 3
const AUTOSAVE_S: float = 20.0
const ROUTES_PATH: String = "res://content/routes.json"
const CAR_W: float = 1800.0
const CAR_IDS: Array = ["car_obs", "car_sleep", "car_lp", "car_pass", "car_dine", "car_lug"]
const CAR_KINDS: Array = ["obs", "sleep", "lp", "pass", "dine", "lug"]
const CAR_UNLOCK_TIER: Dictionary = {"car_lp": 0, "car_pass": 0, "car_dine": 0, "car_sleep": 1, "car_obs": 2, "car_lug": 3}
const SPOT_KINDS: Array = ["seat", "rack", "floor", "bin", "sill", "curtain", "table", "seat"]
## Spot layout per car kind (8 spots each; index 0 and 7 stay seats). lp/pass keep the tutorial layout.
const SPOT_LAYOUT: Dictionary = {
	"lp": ["seat", "rack", "floor", "bin", "sill", "curtain", "table", "seat"],
	"pass": ["seat", "rack", "floor", "bin", "sill", "curtain", "table", "seat"],
	"dine": ["seat", "table", "table", "floor", "sill", "bin", "table", "seat"],
	"sleep": ["seat", "curtain", "floor", "rack", "curtain", "sill", "bin", "seat"],
	"obs": ["seat", "sill", "sill", "floor", "rack", "bin", "curtain", "seat"],
	"lug": ["seat", "rack", "rack", "floor", "rack", "floor", "bin", "seat"],
}
const TIER_THRESHOLDS: Array = [0, 15, 60, 250, 950]
const TOKEN_BY_RARITY: Dictionary = {"common": 5, "odd": 8, "rare": 15}
const REP_BY_RARITY: Dictionary = {"common": 1, "odd": 2, "rare": 3}
const TOOL_ATTRS: Dictionary = {
	"magnifier": ["initials", "station_stamp"],
	"lamp": ["color", "material"],
	"ear": ["sound"],
	"nose": ["smell"],
	"brush": ["wear"],
}
const MOOD_SPEED: Dictionary = {"hurried": 1.4, "calm": 1.0, "worried": 1.0, "shy": 0.6, "grumpy": 0.9}
const MOODS: Array = ["calm", "hurried", "worried", "shy", "grumpy"]
const BASE_WALK: float = 140.0
const PLAYER_SPEED: float = 300.0
const QUEUE_SPACING: float = 90.0
const MAX_CLAIMANTS: int = 6
const BENCH_CAP: int = 3
const SHIMMER_IDLE_S: float = 6.0
const SUBSTEP: float = 0.5
const BRAM_ENTERS_AT: float = 5.0
const ATTR_PHRASE: Dictionary = {
	"color": "It's sort of %s?", "smell": "It smells of %s, I think.", "initials": "It has initials: %s.",
	"station_stamp": "There's a station stamp: %s.", "wear": "It's rather %s.", "sound": "It makes a %s sound.",
	"material": "It's made of %s, I'd say.",
}

var save_path: String = "user://save_v2.json"
var v1_save_path: String = "user://save.json"
var autosave: bool = true
var time_scale: float = 1.0
var frozen: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var seed_base: int = 1
var stop_index: int = 0
var clock_s: float = 0.0
var cheated: bool = false
var _upgrades: Dictionary = {}  # upgrade id -> level
var _daily: Dictionary = {}  # {date, def_id, iid, wrong, started, done, share}
var _daily_log: Dictionary = {}  # date -> {wrong, clues, done}
var tokens: int = 0
var rep: int = 0
var first_delivery_done: bool = false
var tutorial_done: bool = false
var bram_spawned: bool = false
var skip_lock: bool = false

const SimAmbient = preload("res://autoload/sim_ambient.gd")
var _amb: RefCounted = null
var _routes: Dictionary = {}
var _cars: Array = []
var _spots: Array = []
var _items: Dictionary = {}
var _passengers: Dictionary = {}
var _queue: Array = []
var _train: Dictionary = {}
var _player: Dictionary = {}
var _state_t: float = 0.0
var _state_len: float = 75.0
var _target_x: float = -1.0
var _next_iid: int = 100
var _next_pid: int = 0
var _idle_t: float = 0.0
var _autosave_t: float = 0.0
var _recover: Array = []
var _delivered_defs: Array = []
var _owner_deliveries: Dictionary = {}
var _claims_log: Array = []
var _pending_stop_spawn: bool = false
var _last_seen: int = 0  # unix seconds of the last save/pause (A6.1)
var _paused_at: int = 0
var _saves_n: int = 0
var _load_notice: String = ""
var last_offline_report: Dictionary = {}  # set by apply_offline(); GameRoot reads it on cold start
var _lore_found: Array = []
var _stats: Dictionary = {}
var _play_days: Array = []


func _ready() -> void:
	_load_routes()
	if load_game():
		apply_offline(float(int(Time.get_unix_time_from_system()) - _last_seen))
	else:
		new_game(int(Time.get_unix_time_from_system()) % 1000000)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if autosave:
			save_game()
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_paused_at = int(Time.get_unix_time_from_system())
		save_game()
	elif what == NOTIFICATION_APPLICATION_RESUMED and _paused_at > 0:
		var gone: float = float(int(Time.get_unix_time_from_system()) - _paused_at)
		_paused_at = 0
		apply_offline(gone)


func _process(delta: float) -> void:
	if frozen:
		return
	tick(minf(delta, 0.25) * time_scale)
	_autosave_t += delta
	if autosave and _autosave_t > AUTOSAVE_S:
		save_game()


# ======================= setup =======================
func _parse(text: String) -> Variant:
	var j: JSON = JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data


func _load_routes() -> void:
	var data: Variant = _parse(FileAccess.get_file_as_string(ROUTES_PATH)) if FileAccess.file_exists(ROUTES_PATH) else null
	if typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("stops"):
		_routes = data
	else:
		_routes = {"timing": {"arriving": 15, "departing": 10, "stopped_min": 60, "stopped_max": 90, "moving_min": 60, "moving_max": 90},
			"stops": [{"name": "Platform Zero", "biome": "plains", "weather": {}}]}


func _build_cars() -> void:
	_cars.clear()
	_spots.clear()
	for i in range(CAR_IDS.size()):
		var cid: String = String(CAR_IDS[i])
		_cars.append({"id": cid, "kind": CAR_KINDS[i], "index": i, "x": i * CAR_W, "width": CAR_W, "unlocked": int(CAR_UNLOCK_TIER[cid]) <= 0})
		for s in range(8):
			_spots.append({"id": "%s_s%d" % [cid, s], "car_id": cid, "x": i * CAR_W + 150.0 + s * 200.0, "kind": (SPOT_LAYOUT.get(String(CAR_KINDS[i]), SPOT_KINDS) as Array)[s], "item_iid": ""})


func new_game(seed_value: int) -> void:
	if _routes.is_empty():
		_load_routes()
	seed_base = seed_value
	stop_index = 0
	clock_s = 0.0
	cheated = false
	_upgrades = {}
	_daily = {}
	tokens = 0
	rep = 0
	first_delivery_done = false
	tutorial_done = false
	bram_spawned = false
	_items.clear()
	_passengers.clear()
	_queue.clear()
	_recover.clear()
	_delivered_defs.clear()
	_owner_deliveries.clear()
	_claims_log.clear()
	_next_iid = 100
	_next_pid = 0
	_idle_t = 0.0
	_pending_stop_spawn = false
	_lore_found = []
	_stats = {}
	_play_days = []
	_note_day()
	_build_cars()
	_reseed()
	_train = {"state": "moving", "stop": _stop_info(0), "phase_t": 0.0, "speed": 1.0, "time_of_day": 0.78, "weather": "clear"}
	_state_t = 0.0
	_state_len = 75.0
	_player = {"x": _lp_x() + 900.0, "car_id": "car_lp", "carrying": "", "tokens": 0, "rep": 0, "tier": 0}
	_target_x = -1.0
	_spawn_item("obj_001", "car_lp_s3")
	_amb_ref().reset()
	_amb_ref().populate_initial()


func _reseed() -> void:
	rng.seed = seed_base + stop_index * 7919


func _stop_info(idx: int) -> Dictionary:
	var stops: Array = _routes["stops"]
	var s: Dictionary = stops[idx % stops.size()]
	return {"name": s.get("name", "?"), "biome": s.get("biome", "plains"), "index": idx}


func _lp_x() -> float:
	return 2.0 * CAR_W


func _door_x() -> float:
	return _lp_x() + CAR_W - 60.0


func _counter_x() -> float:
	return _lp_x() + 1200.0


func _bench_x() -> float:
	return _lp_x() + 485.0


func _new_pid(prefix: String) -> String:
	_next_pid += 1
	return "%s_%d" % [prefix, _next_pid]


func _amb_ref() -> RefCounted:
	if _amb == null:
		_amb = SimAmbient.new(self)
	return _amb


func _make_passenger(pid: String, kind: String, owner_id: String, pname: String, x: float, mood: String, car_id: String, state: String) -> Dictionary:
	return {"pid": pid, "kind": kind, "owner_id": owner_id, "name": pname, "look": {}, "x": x, "facing": -1, "state": state, "mood": mood,
		"car_id": car_id, "seat_spot": "", "line": "", "wants_item_def": "", "patience": 1.0, "t": 0.0, "leave_mood": "", "asked": []}


# ======================= time =======================
func tick(dt: float) -> void:
	var left: float = dt
	while left > 0.0:
		var step: float = minf(left, SUBSTEP)
		left -= step
		_step(step)


func _step(dt: float) -> void:
	clock_s += dt
	_idle_t += dt
	_move_player(dt)
	_tick_train(dt)
	_tick_script()
	_amb_ref().tick_global(dt)
	for pid in _passengers.keys():
		_tick_passenger(_passengers[pid], dt)
	_train["time_of_day"] = 0.78 if not first_delivery_done else _real_time_of_day()


func _real_time_of_day() -> float:
	var t: Dictionary = Time.get_time_dict_from_system()
	return (float(t["hour"]) + float(t["minute"]) / 60.0) / 24.0


func _timing(key: String) -> float:
	return float((_routes["timing"] as Dictionary).get(key, 60))


func _phase_len(state: String) -> float:
	match state:
		"arriving": return _timing("arriving")
		"departing": return _timing("departing")
		"stopped":
			var stops: Array = _routes["stops"]
			var s: Dictionary = stops[stop_index % stops.size()]
			if s.has("dwell_s"):
				return float(s["dwell_s"])
			return rng.randf_range(_timing("stopped_min"), _timing("stopped_max"))
		_:
			return rng.randf_range(_timing("moving_min"), _timing("moving_max"))


func _tick_train(dt: float) -> void:
	_state_t += dt
	_train["phase_t"] = clampf(_state_t / maxf(_state_len, 0.001), 0.0, 1.0)
	if _state_t >= _state_len:
		_advance_train()


func _advance_train() -> void:
	var order: Array = ["moving", "arriving", "stopped", "departing"]
	var nxt: String = String(order[(order.find(_train["state"]) + 1) % order.size()])
	if nxt == "arriving":
		stop_index += 1
		_reseed()
		_train["stop"] = _stop_info(stop_index)
		_train["weather"] = _roll_weather()
	_train["state"] = nxt
	_state_t = 0.0
	_state_len = _phase_len(nxt)
	_train["speed"] = 0.0 if nxt == "stopped" else 1.0
	Events.train_state_changed.emit(nxt, _train["stop"])
	if nxt == "stopped":
		_on_stopped()
	elif nxt == "departing" and autosave:
		save_game()


func _roll_weather() -> String:
	var stops: Array = _routes["stops"]
	var w: Dictionary = (stops[stop_index % stops.size()] as Dictionary).get("weather", {})
	var r: float = rng.randf()
	var acc: float = 0.0
	for k in ["rain", "snow", "fog"]:
		acc += float(w.get(k, 0.0))
		if r < acc:
			return k
	return "clear"


# ======================= stops: items + claimants =======================
func _on_stopped(offline: bool = false) -> void:
	# conductor returns items that were wrongly given to imposters
	for iid in _recover:
		if _items.has(iid):
			var sp: String = _free_spot_id()
			if sp != "":
				_place_item_at_spot(iid, sp)
	_recover.clear()
	_stat_add("stops")
	_maybe_spawn_lore()
	var spawned: Array = _amb_ref().take_dropped()
	var n_items: int = rng.randi_range(1, 4)
	for i in range(n_items):
		var def_id: String = _pick_def()
		var sp: String = _free_spot_id()
		if def_id == "" or sp == "":
			break
		spawned.append(_spawn_item(def_id, sp))
	var want: int = rng.randi_range(1, 3)
	var made: int = 0
	var used_owners: Dictionary = {}
	for it in spawned:
		if made >= want or _active_claimants() >= MAX_CLAIMANTS:
			break
		var oid: String = String(Content.object_by_id(String(it["def_id"])).get("owner_id", ""))
		if oid == "" or used_owners.has(oid) or _owner_has_claimant(oid):
			continue
		used_owners[oid] = true
		_spawn_claimant(oid, String(it["def_id"]), false)
		made += 1
	# bring back a claimant for something sitting on the shelf so nothing rots
	if made < want and _active_claimants() < MAX_CLAIMANTS and rng.randf() < 0.5:
		for it in _items.values():
			if it["loc"] == "shelf":
				var oid2: String = String(Content.object_by_id(String(it["def_id"])).get("owner_id", ""))
				if oid2 != "" and not _owner_has_claimant(oid2):
					_spawn_claimant(oid2, String(it["def_id"]), false)
					break
	_maybe_spawn_imposter()
	_off_shelved += _porter_work()
	if offline:
		_amb_ref().offline_stop()
	else:
		_amb_ref().on_stopped()


func _pick_def() -> String:
	var used: Dictionary = {}
	for it in _items.values():
		used[String(it["def_id"])] = true
	for d in _delivered_defs:
		used[String(d)] = true
	var pool: Array = []
	for o in Content.objects:
		var id: String = String((o as Dictionary).get("id", ""))
		if id != "" and not used.has(id):
			pool.append(id)
	if pool.is_empty():
		# handwritten set exhausted: fall back to procedural items (A3.1)
		for o in Content.generated_objects:
			var gid: String = String((o as Dictionary).get("id", ""))
			if gid != "" and not used.has(gid):
				pool.append(gid)
	if pool.is_empty():
		# everything has been delivered once: recycle (the game is endless, nothing runs dry)
		var live: Dictionary = {}
		for it in _items.values():
			if it["loc"] != "delivered":
				live[String(it["def_id"])] = true
		for o in Content.objects + Content.generated_objects:
			var rid: String = String((o as Dictionary).get("id", ""))
			if rid != "" and not live.has(rid):
				pool.append(rid)
	if pool.is_empty():
		return ""
	return String(pool[rng.randi_range(0, pool.size() - 1)])


func _free_spot_id() -> String:
	var open: Array = []
	for sp in _spots:
		if String(sp["item_iid"]) == "" and _car_unlocked(String(sp["car_id"])) and String(sp["kind"]) != "seat":
			open.append(String(sp["id"]))
	if open.is_empty():
		return ""
	return String(open[rng.randi_range(0, open.size() - 1)])


func _car_unlocked(car_id: String) -> bool:
	for c in _cars:
		if c["id"] == car_id:
			return bool(c["unlocked"])
	return false


func _active_claimants() -> int:
	var n: int = 0
	for p in _passengers.values():
		if p["kind"] != "ambient":
			n += 1
	return n


func _owner_has_claimant(owner_id: String) -> bool:
	for p in _passengers.values():
		if p["kind"] != "ambient" and p["owner_id"] == owner_id:
			return true
	return false


func _spawn_item(def_id: String, spot_id: String) -> Dictionary:
	var d: Dictionary = Content.object_by_id(def_id)
	var attrs: Array = []
	for c in d.get("clues", []):
		attrs.append(str(c.get("attr", "")))
	for old_id in _items.keys():  # a recycled def: drop its old delivered copy so saves stay small
		if _items[old_id]["def_id"] == def_id and _items[old_id]["loc"] == "delivered":
			_items.erase(old_id)
	_next_iid += 1
	var iid: String = "i%d" % _next_iid
	var item: Dictionary = {"iid": iid, "def_id": def_id, "name": d.get("name", def_id), "icon": d.get("icon", "key"), "tint": d.get("tint", "#FFFFFF"),
		"rarity": d.get("rarity", "common"), "loc": "spot", "spot_id": spot_id, "clues_known": [], "unknown_attrs": attrs, "tag_note": ""}
	_items[iid] = item
	_set_spot_item(spot_id, iid)
	Events.item_spawned.emit(item, spot_id)
	return item


func _set_spot_item(spot_id: String, iid: String) -> void:
	for sp in _spots:
		if sp["id"] == spot_id:
			sp["item_iid"] = iid
			return


func _place_item_at_spot(iid: String, spot_id: String) -> void:
	var it: Dictionary = _items[iid]
	it["loc"] = "spot"
	it["spot_id"] = spot_id
	_set_spot_item(spot_id, iid)
	Events.item_moved.emit(iid, "spot")


func _spawn_claimant(owner_id: String, def_id: String, at_door: bool, kind: String = "claimant", pname: String = "") -> Dictionary:
	var w: Dictionary = Content.owner_by_id(owner_id)
	var pid: String = _new_pid("clm")
	var mood: String = "calm" if at_door else String(MOODS[rng.randi_range(0, MOODS.size() - 1)])
	var x: float = _door_x()
	var car_id: String = "car_lp"
	var seat: String = ""
	var state: String = "walking"
	if not at_door:
		seat = _free_seat_id()
		var car: Dictionary = _cars[3]
		x = float(car["x"]) + 300.0
		car_id = "car_pass"
		for sp in _spots:
			if sp["id"] == seat:
				x = float(sp["x"])
		state = "seated"
	var shown_name: String = pname if pname != "" else String(w.get("name", "Someone"))
	var p: Dictionary = _make_passenger(pid, kind, owner_id, shown_name, x, mood, car_id, state)
	p["seat_spot"] = seat
	p["wants_item_def"] = def_id
	if kind == "imposter":
		p["look"] = _random_look(pid)
		p["imposter_hints"] = _imposter_hints(pid, def_id)
		p["line"] = _intro_bark(pid, mood, def_id)
	else:
		p["line"] = _claim_line(w, def_id)
	p["t"] = 0.0 if at_door else rng.randf_range(2.0, 7.0) / float(MOOD_SPEED[mood])
	_passengers[pid] = p
	if at_door:
		_queue.append(pid)
	_claims_log.append({"pid": pid, "name": p["name"], "line": p["line"], "def_id": def_id})
	if _claims_log.size() > 30:
		_claims_log.pop_front()
	Events.passenger_spawned.emit(p)
	return p


# ======================= imposters + interview (A2.3) =======================
## Local RNG derived from stable ids, so text/choices never disturb the main sim RNG stream.
func _local_rng(key: String) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = hash(key) + seed_base
	return r


func _pick_line(lines: Array, r: RandomNumberGenerator, fallback: String) -> String:
	if lines.is_empty():
		return fallback
	return String(lines[r.randi_range(0, lines.size() - 1)])


func _item_label(def_id: String) -> String:
	return String(Content.object_by_id(def_id).get("name", "thing")).to_lower()


func _intro_bark(pid: String, mood: String, def_id: String) -> String:
	var r: RandomNumberGenerator = _local_rng("intro|" + pid)
	var line: String = _pick_line(Content.lines("barks", ["claimant_intro", mood]), r, "I think I lost my {item}.")
	return line.replace("{item}", _item_label(def_id))


func _random_look(pid: String) -> Dictionary:
	var r: RandomNumberGenerator = _local_rng("look|" + pid)
	var look: Dictionary = {}
	if not Content.owners.is_empty():
		look = ((Content.owners[r.randi_range(0, Content.owners.size() - 1)] as Dictionary).get("look", {}) as Dictionary).duplicate(true)
	var skins: Array = ["#f1c9a5", "#d9a47a", "#b9805a", "#8d5a3c", "#6b4430"]
	var hairs: Array = ["#2a1d14", "#3b2a20", "#6b4a2b", "#a86b2e", "#c9c3b5", "#1d1d24"]
	var coats: Array = ["#7FA6A3", "#B8893E", "#C8503C", "#5b6f8c", "#6d5a7a", "#4f7a58", "#8a8f99"]
	look["skin"] = skins[r.randi_range(0, skins.size() - 1)]
	look["hair"] = hairs[r.randi_range(0, hairs.size() - 1)]
	look["coat"] = coats[r.randi_range(0, coats.size() - 1)]
	look["hat"] = ["cap", "none", "top", "scarf"][r.randi_range(0, 3)]
	look["accessory"] = ["none", "glasses", "beard", "pipe"][r.randi_range(0, 3)]
	return look


const WRONG_FALLBACK: Dictionary = {
	"color": ["green", "grey", "purple", "orange", "white"], "material": ["tin", "silk", "glass", "bone"],
	"smell": ["lavender", "rain", "peppermint", "tar"], "sound": ["thud", "jingle", "squeak", "tick"],
	"wear": ["pristine", "cracked", "sticky", "faded"], "initials": ["Q.Z.", "X.Y.", "J.J.", "M.W."],
	"station_stamp": ["Nowhere Halt", "Lantern Cross", "Gull Point", "Marrow Gate"],
}


## Two hints, exactly ONE of them wrong (the wrong one can always be caught with a tool).
func _imposter_hints(pid: String, def_id: String) -> Array:
	var r: RandomNumberGenerator = _local_rng("imp|" + pid + "|" + def_id)
	var clues: Array = (Content.object_by_id(def_id).get("clues", []) as Array).duplicate()
	var usable: Array = []
	for c in clues:
		if String((c as Dictionary).get("attr", "")) != "" and String((c as Dictionary).get("value", "")) != "":
			usable.append(c)
	var out: Array = []
	if usable.is_empty():
		return out
	# shuffle (Fisher-Yates with the local rng)
	for i in range(usable.size() - 1, 0, -1):
		var j: int = r.randi_range(0, i)
		var tmp: Variant = usable[i]
		usable[i] = usable[j]
		usable[j] = tmp
	var wrong_idx: int = r.randi_range(0, mini(1, usable.size() - 1))
	for i in range(mini(2, usable.size())):
		var c: Dictionary = usable[i]
		var attr: String = String(c["attr"])
		var val: String = String(c["value"])
		var is_wrong: bool = i == wrong_idx
		out.append({"attr": attr, "value": _wrong_value(attr, val, r) if is_wrong else val, "wrong": is_wrong})
	return out


func _wrong_value(attr: String, real: String, r: RandomNumberGenerator) -> String:
	var pool: Array = []
	for o in Content.objects:
		for c in (o as Dictionary).get("clues", []):
			if String(c.get("attr", "")) == attr:
				var v: String = String(c.get("value", ""))
				if v != "" and v.to_lower() != real.to_lower() and not pool.has(v):
					pool.append(v)
	for v in (WRONG_FALLBACK.get(attr, []) as Array):
		if String(v).to_lower() != real.to_lower() and not pool.has(v):
			pool.append(v)
	if pool.is_empty():
		return real + "?"
	return String(pool[r.randi_range(0, pool.size() - 1)])


## Public so Cheats (spawn imposter) and tests can use it. Claims a real item that exists on the train.
func spawn_imposter(def_id: String = "", at_door: bool = true) -> Dictionary:
	if def_id == "":
		var cands: Array = []
		for it in _items.values():
			if it["loc"] != "delivered" and (Content.object_by_id(String(it["def_id"])).get("clues", []) as Array).size() >= 2:
				cands.append(String(it["def_id"]))
		if cands.is_empty():
			return {}
		def_id = String(cands[_local_rng("imp_def|%d|%d" % [stop_index, _next_pid]).randi_range(0, cands.size() - 1)])
	var full: Array = Content.names.get("full", []) as Array
	var r: RandomNumberGenerator = _local_rng("imp_name|%d|%d" % [stop_index, _next_pid])
	var taken: Dictionary = {}
	for q in _passengers.values():
		taken[String(q["name"])] = true
	var nm: String = "Mr. Nobody"
	for k in range(full.size()):
		var cand: String = String(full[r.randi_range(0, full.size() - 1)])
		if not taken.has(cand):
			nm = cand
			break
	return _spawn_claimant("", def_id, at_door, "imposter", nm)


func _maybe_spawn_imposter() -> void:
	if int(_player["tier"]) < 2 or _active_claimants() >= MAX_CLAIMANTS:
		return
	if rng.randf() >= 0.35:
		return
	var wanted: Dictionary = {}
	for q in _passengers.values():
		if q["kind"] != "ambient":
			wanted[String(q["wants_item_def"])] = true
	var cands: Array = []
	for it in _items.values():
		var d: String = String(it["def_id"])
		if it["loc"] != "delivered" and not wanted.has(d) and (Content.object_by_id(d).get("clues", []) as Array).size() >= 2:
			cands.append(d)
	if cands.is_empty():
		return
	cands.sort()
	spawn_imposter(String(cands[rng.randi_range(0, cands.size() - 1)]), false)


func _free_seat_id() -> String:
	var taken: Dictionary = {}
	for p in _passengers.values():
		if String(p["seat_spot"]) != "":
			taken[String(p["seat_spot"])] = true
	for sp in _spots:
		if sp["car_id"] == "car_pass" and sp["kind"] == "seat" and not taken.has(sp["id"]):
			return String(sp["id"])
	return ""


func _claim_line(owner: Dictionary, def_id: String) -> String:
	var lines: Array = owner.get("claim_lines", [])
	if lines.is_empty():
		return "I think I lost something..."
	var idx: int = (owner.get("lost_item_ids", []) as Array).find(def_id)
	if idx < 0 or idx >= lines.size():
		idx = rng.randi_range(0, lines.size() - 1)
	return String(lines[idx])


# ======================= first-minute script (A1.3) =======================
func _tick_script() -> void:
	if not bram_spawned and not first_delivery_done and clock_s >= BRAM_ENTERS_AT:
		bram_spawned = true
		var bram_def: String = "obj_001"
		if Content.owner_by_id("own_001").is_empty():
			return
		var p: Dictionary = _spawn_claimant("own_001", bram_def, true)
		p["mood"] = "calm"


# ======================= passengers =======================
func _set_pstate(p: Dictionary, state: String) -> void:
	if p["state"] == state:
		return
	p["state"] = state
	p["t"] = 0.0
	Events.passenger_state_changed.emit(p["pid"], state)


func _slot_x(idx: int) -> float:
	return _counter_x() + QUEUE_SPACING * idx


func _tick_passenger(p: Dictionary, dt: float) -> void:
	if p["kind"] == "ambient":
		_amb_ref().tick(p, dt)
		return
	var mood_speed: float = float(MOOD_SPEED.get(p["mood"], 1.0))
	var speed: float = BASE_WALK * mood_speed
	match String(p["state"]):
		"seated":
			p["t"] = float(p["t"]) - dt
			if float(p["t"]) <= 0.0:
				_set_pstate(p, "standing_up")
				p["t"] = 0.8
		"standing_up":
			p["t"] = float(p["t"]) - dt
			if float(p["t"]) <= 0.0:
				_set_pstate(p, "walking")
		"walking":
			p["facing"] = -1
			if not _queue.has(p["pid"]):
				if float(p["x"]) > _door_x():
					_walk_toward(p, _door_x(), speed * dt)
					p["car_id"] = _car_at(float(p["x"]))
					return
				var door_pause: String = _door_pause_state(String(p["mood"])) if float(p["t"]) < 90.0 else ""
				if door_pause != "":
					_set_pstate(p, door_pause)
					return
				_queue.append(p["pid"])
			_head_to_slot(p, speed * dt)
		"hesitating", "knocking":
			p["facing"] = -1
			p["t"] = float(p["t"]) + dt
			if float(p["t"]) >= (2.2 if p["state"] == "hesitating" else 1.0):
				_set_pstate(p, "walking")
				p["t"] = 99.0  # already paused at the door; don't pause again
				_queue.append(p["pid"])
		"queued":
			_head_to_slot(p, BASE_WALK * dt)
		"at_counter":
			_set_pstate(p, "asking")
			Events.passenger_said.emit(p["pid"], p["line"])
		"asking":
			p["t"] = float(p["t"]) + dt
			if float(p["t"]) >= 2.5:
				_set_pstate(p, "waiting")
				Events.claimant_waiting.emit(p["pid"])
		"waiting":
			p["patience"] = maxf(0.0, float(p["patience"]) - dt / 180.0)
		"receiving":
			p["t"] = float(p["t"]) + dt
			if float(p["t"]) >= 1.2:
				_set_pstate(p, "leaving")
		"leaving":
			p["facing"] = 1
			p["x"] = float(p["x"]) + BASE_WALK * dt
			p["car_id"] = _car_at(float(p["x"]))
			if float(p["x"]) > _door_x() + 150.0:
				_remove_passenger(p)


## Shy/worried people hesitate at the door, grumpy/hurried ones knock; calm walk straight in.
func _door_pause_state(mood: String) -> String:
	if mood == "shy" or mood == "worried":
		return "hesitating"
	if mood == "grumpy" or mood == "hurried":
		return "knocking"
	return ""


func _walk_toward(p: Dictionary, tx: float, step: float) -> void:
	var dx: float = tx - float(p["x"])
	if absf(dx) <= step:
		p["x"] = tx
	else:
		p["x"] = float(p["x"]) + signf(dx) * step


func _head_to_slot(p: Dictionary, step: float) -> void:
	var idx: int = _queue.find(p["pid"])
	if idx < 0:
		return
	var tx: float = _slot_x(idx)
	_walk_toward(p, tx, step)
	p["facing"] = -1
	p["car_id"] = _car_at(float(p["x"]))
	if absf(float(p["x"]) - tx) < 1.0:
		if idx == 0:
			if p["state"] != "at_counter" and p["state"] != "asking" and p["state"] != "waiting":
				_set_pstate(p, "at_counter")
		elif p["state"] != "queued":
			_set_pstate(p, "queued")
	elif p["state"] == "queued" or p["state"] == "walking":
		pass


func _remove_passenger(p: Dictionary) -> void:
	var pid: String = String(p["pid"])
	_queue.erase(pid)
	_passengers.erase(pid)
	Events.passenger_left.emit(pid, String(p["leave_mood"]) == "happy")


func _car_at(x: float) -> String:
	var i: int = clampi(int(x / CAR_W), 0, _cars.size() - 1)
	return String(_cars[i]["id"])


func _front_claimant() -> Dictionary:
	for pid in _queue:
		if _passengers.has(pid):
			return _passengers[pid]
	return {}


# ======================= player =======================
func _move_player(dt: float) -> void:
	if _target_x < 0.0:
		return
	var dx: float = _target_x - float(_player["x"])
	var step: float = PLAYER_SPEED * dt
	if absf(dx) <= step:
		_player["x"] = _target_x
		_target_x = -1.0
	else:
		_player["x"] = float(_player["x"]) + signf(dx) * step
	_player["car_id"] = _car_at(float(_player["x"]))


func _walk_bounds() -> Vector2:
	if not first_delivery_done and not skip_lock:
		return Vector2(_lp_x() + 60.0, _lp_x() + CAR_W - 60.0)
	var lo: float = 1.0e9
	var hi: float = -1.0
	for c in _cars:
		if bool(c["unlocked"]):
			lo = minf(lo, float(c["x"]) + 60.0)
			hi = maxf(hi, float(c["x"]) + float(c["width"]) - 60.0)
	return Vector2(lo, hi)


func _touch() -> void:
	_idle_t = 0.0


# ======================= lore, stats, equipped (A6.5) =======================
func _stat_add(k: String, n: int = 1) -> void:
	_stats[k] = int(_stats.get(k, 0)) + n


func _note_day() -> void:
	var day: String = Time.get_date_string_from_system(true)
	if _play_days.has(day):
		return
	_play_days.append(day)
	if _play_days.size() > 400:
		_play_days = _play_days.slice(_play_days.size() - 400)


func get_lore_found() -> Array:
	return _lore_found.duplicate()


func _lore_on_train() -> Array:
	var out: Array = []
	for it in _items.values():
		if String(it.get("lore_id", "")) != "" and String(it["loc"]) == "spot":
			out.append(String(it["lore_id"]))
	return out


## Roughly one scrap every third stop, only in cars the player can reach and tiers already earned.
func _maybe_spawn_lore() -> void:
	var tier: int = tier_for(rep)
	var local: RandomNumberGenerator = _local_rng("lore|%d" % stop_index)
	if not tutorial_done or local.randf() > 0.34 or not _lore_on_train().is_empty():
		return
	var cands: Array = []
	for l in Content.lore:
		var lid: String = String(l.get("id", ""))
		if lid == "" or _lore_found.has(lid) or int(l.get("tier", 0)) > tier:
			continue
		cands.append(l)
	if cands.is_empty():
		return
	var l: Dictionary = cands[local.randi_range(0, cands.size() - 1)]
	var open: Array = []
	for sp in _spots:
		var car: Dictionary = _cars[_car_index(String(sp["car_id"]))]
		if String(car["kind"]) == String(l.get("found_in", "lp")) and bool(car["unlocked"]) and String(sp["item_iid"]) == "" and String(sp["kind"]) != "seat":
			open.append(String(sp["id"]))
	if open.is_empty():
		return
	var spot_id: String = String(open[local.randi_range(0, open.size() - 1)])
	_next_iid += 1
	var iid: String = "i%d" % _next_iid
	var item: Dictionary = {"iid": iid, "def_id": String(l["id"]), "lore_id": String(l["id"]), "name": String(l.get("title", "A scrap of paper")), "icon": "letter", "tint": "#EADFC8",
		"rarity": String(l.get("rarity", "common")), "loc": "spot", "spot_id": spot_id, "clues_known": [], "unknown_attrs": [], "tag_note": ""}
	_items[iid] = item
	_set_spot_item(spot_id, iid)
	Events.item_spawned.emit(item, spot_id)


func _car_index(car_id: String) -> int:
	for i in range(_cars.size()):
		if _cars[i]["id"] == car_id:
			return i
	return 0


func _collect_lore(sp: Dictionary, iid: String) -> Dictionary:
	var lid: String = String(_items[iid]["lore_id"])
	sp["item_iid"] = ""
	_items.erase(iid)
	if not _lore_found.has(lid):
		_lore_found.append(lid)
		_stat_add("lore_found")
		Events.lore_found.emit(lid)
		Events.toast.emit("A scrap for the Ledger: %s" % String(_lore_entry(lid).get("title", "")), "info")
	Events.item_moved.emit(iid, "delivered")
	return {"ok": true, "iid": iid, "lore": true, "lore_id": lid}


func _lore_entry(lid: String) -> Dictionary:
	for l in Content.lore:
		if String(l.get("id", "")) == lid:
			return l
	return {}


func get_lore() -> Array:
	var out: Array = []
	for lid in _lore_found:
		var l: Dictionary = _lore_entry(String(lid))
		if not l.is_empty():
			out.append(l)
	return out


## Owned cosmetic upgrade ids, e.g. ["brass_cap", "lantern_charm"].
func get_equipped() -> Array:
	var out: Array = []
	for u in Content.shop.get("upgrades", []):
		if String(u.get("kind", "")) == "cosmetic" and int(_upgrades.get(String(u["id"]), 0)) > 0:
			out.append(String(u["id"]))
	return out


func get_stop_biome() -> String:
	return String((_train.get("stop", {}) as Dictionary).get("biome", "plains"))


func get_stats() -> Dictionary:
	var streak: int = 0
	var day_s: int = int(Time.get_unix_time_from_system() / 86400.0)
	var have: Dictionary = {}
	for d in _play_days:
		have[int(Time.get_unix_time_from_datetime_string(String(d) + "T00:00:00") / 86400.0)] = true
	while have.has(day_s - streak) or (streak == 0 and have.has(day_s - 1)):
		if streak == 0 and not have.has(day_s):
			day_s -= 1
		streak += 1
	return {"handovers": int(_stats.get("handovers", 0)), "refusals": int(_stats.get("refusals", 0)), "imposters_caught": int(_stats.get("imposters_caught", 0)),
		"items_found": int(_stats.get("items_found", 0)), "stops": int(_stats.get("stops", 0)), "days_played": _play_days.size(), "streak": streak,
		"tokens_total": int(_stats.get("tokens_total", 0)), "lore_found": _lore_found.size()}


# ======================= train map + fast travel (A6.12) =======================
const CAR_TITLES: Dictionary = {"car_obs": "Observation", "car_sleep": "Sleeper", "car_lp": "Lost Property", "car_pass": "Passenger", "car_dine": "Dining", "car_lug": "Luggage"}


## One row per car, front to back: {id,kind,name,index,x,center_x,unlocked,unlock_tier,tier_rep,items,claimants,here,reachable}.
## Locked cars still appear (the map shows them dimmed with the tier that opens them).
func get_map() -> Array:
	var out: Array = []
	var here: String = String(_player.get("car_id", "car_lp"))
	var t_open: bool = first_delivery_done or skip_lock
	for c in _cars:
		var cid: String = String(c["id"])
		var n_items: int = 0
		for sp in _spots:
			if String(sp["car_id"]) == cid and String(sp["item_iid"]) != "" and String(sp["kind"]) != "seat":
				n_items += 1
		var n_clm: int = 0
		if cid == "car_lp":
			n_clm = _active_claimants()
		var tier_need: int = int(CAR_UNLOCK_TIER[cid])
		out.append({"id": cid, "kind": String(c["kind"]), "name": String(CAR_TITLES.get(cid, cid)), "index": int(c["index"]), "x": float(c["x"]), "center_x": float(c["x"]) + float(c["width"]) * 0.5,
			"unlocked": bool(c["unlocked"]), "unlock_tier": tier_need, "tier_rep": int(TIER_THRESHOLDS[tier_need]), "items": n_items, "claimants": n_clm,
			"here": cid == here, "reachable": bool(c["unlocked"]) and (cid == "car_lp" or t_open)})
	return out


## Teleport the attendant to a car (the map's tap target). The world plays the transition when it
## hears Events.fast_travelled(car_id, from_x, to_x). Never fails hard: a locked car just explains.
func fast_travel(car_id: String) -> Dictionary:
	_touch()
	for row in get_map():
		if String(row["id"]) != car_id:
			continue
		if not bool(row["unlocked"]):
			return {"ok": false, "reason": "locked", "unlock_tier": int(row["unlock_tier"]), "tier_rep": int(row["tier_rep"]), "hint": "Earn %d reputation to open the %s car." % [int(row["tier_rep"]), String(row["name"])]}
		if not bool(row["reachable"]):
			return {"ok": false, "reason": "tutorial", "hint": "Hand over your first lost thing, then you can walk the whole train."}
		if bool(row["here"]):
			return {"ok": true, "car_id": car_id, "x": float(_player["x"]), "already_here": true}
		var from_x: float = float(_player["x"])
		var to_x: float = float(row["x"]) + 900.0
		if car_id == "car_lp":
			to_x = _bench_x() + 300.0
		var b: Vector2 = _walk_bounds()
		to_x = clampf(to_x, b.x, b.y)
		_player["x"] = to_x
		_target_x = -1.0
		_player["car_id"] = _car_at(to_x)
		Events.fast_travelled.emit(car_id, from_x, to_x)
		return {"ok": true, "car_id": car_id, "x": to_x, "from_x": from_x}
	return {"ok": false, "reason": "unknown car"}


# ======================= queries =======================
func get_cars() -> Array: return _cars
func get_spots() -> Array: return _spots
func get_item(iid: String) -> Dictionary: return _items.get(iid, {})
func get_passengers() -> Array: return _passengers.values()
func get_train() -> Dictionary: return _train
func get_player() -> Dictionary: return _player
func get_queue() -> Array: return _queue.duplicate()
func get_bench_x() -> float: return _bench_x()
func get_counter_x() -> float: return _counter_x()
func get_door_x() -> float: return _door_x()


func get_items_at(loc: String) -> Array:
	var out: Array = []
	for it in _items.values():
		if it["loc"] == loc:
			out.append(it)
	return out


func get_shop() -> Array:
	var out: Array = []
	for u in Content.shop.get("upgrades", []):
		var costs: Array = u.get("costs", [])
		var lvl: int = int(_upgrades.get(u["id"], 0))
		var maxed: bool = lvl >= costs.size()
		out.append({"id": u["id"], "name": u["name"], "desc": u.get("desc", ""), "kind": u.get("kind", ""), "level": lvl, "max_level": costs.size(),
			"cost": 0 if maxed else int(costs[lvl]), "owned": lvl > 0, "maxed": maxed, "affordable": (not maxed) and tokens >= int(costs[lvl])})
	return out


func get_upgrade_level(id: String) -> int:
	return int(_upgrades.get(id, 0))


func get_bench_cap() -> int:
	return BENCH_CAP + int(_upgrades.get("bench_slot", 0))


func _econ(key: String, fallback: Variant) -> Variant:
	return Content.economy.get(key, fallback)


func _token_for(rarity: String) -> int:
	var tb: Dictionary = _econ("token_by_rarity", TOKEN_BY_RARITY)
	return int(tb.get(rarity, 5))


func _rep_for(rarity: String) -> int:
	var rb: Dictionary = _econ("rep_by_rarity", REP_BY_RARITY)
	return int(rb.get(rarity, 1))


## Apply lamp oil / UV lamp bonuses to a base token reward.
func _boosted(base: int, rarity: String) -> int:
	var n: float = float(base) * (1.0 + float(_upgrades.get("lamp_oil", 0)) * float(_econ("lamp_oil_pct_per_level", 10)) / 100.0)
	if rarity == "rare" and int(_upgrades.get("uv_lamp", 0)) > 0:
		n += float(_econ("uv_rare_bonus", 5))
	return int(round(n))


## Porters shelve freshly found items so the player never has to hunt.
func _porter_work() -> int:
	var n: int = int(_upgrades.get("porter", 0))
	if n <= 0 or not tutorial_done:
		return 0
	var moved: int = 0
	for sp in _spots:
		if n <= 0:
			break
		var iid: String = String(sp["item_iid"])
		if iid != "" and String(sp["kind"]) != "seat" and _items.has(iid) and _items[iid]["loc"] == "spot" and String(_items[iid].get("lore_id", "")) == "":
			sp["item_iid"] = ""
			_items[iid]["loc"] = "shelf"
			_items[iid]["spot_id"] = ""
			Events.item_moved.emit(iid, "shelf")
			n -= 1
			moved += 1
	return moved


func get_ledger() -> Dictionary:
	var items: Array = []
	for it in _items.values():
		if (it["clues_known"] as Array).size() > 0:
			items.append({"iid": it["iid"], "name": it["name"], "clues_known": it["clues_known"]})
	var gallery: Array = []
	for oid in _owner_deliveries.keys():
		gallery.append({"owner_id": oid, "name": Content.owner_by_id(String(oid)).get("name", oid), "deliveries": _owner_deliveries[oid]})
	return {"claims": _claims_log.duplicate(), "items": items, "catalog": _delivered_defs.duplicate(), "gallery": gallery, "daily": {}}


## Tutorial state derived from facts (never desyncs): stage + where to point the arrow.
func get_tutorial() -> Dictionary:
	if tutorial_done:
		return {"stage": "done", "target_x": -1.0, "target_spot": "", "hint": ""}
	if first_delivery_done:
		var sp: String = ""
		for it in _items.values():
			if it["loc"] == "spot" and String(it["spot_id"]).begins_with("car_pass"):
				sp = String(it["spot_id"])
		return {"stage": "sweep", "target_x": _spot_x(sp), "target_spot": sp, "hint": "Sweep the passenger car for lost things."}
	var mitten: Dictionary = _tutorial_item()
	var loc: String = String(mitten.get("loc", ""))
	if loc == "bench":
		if (mitten["clues_known"] as Array).is_empty():
			return {"stage": "examine", "target_x": _bench_x(), "target_spot": "", "hint": "Try a tool on it."}
		return {"stage": "hand_over", "target_x": _counter_x(), "target_spot": "", "hint": "Hand it over."}
	if loc == "carried":
		return {"stage": "to_bench", "target_x": _bench_x(), "target_spot": "", "hint": "Take it to the bench."}
	return {"stage": "find_item", "target_x": _spot_x("car_lp_s3"), "target_spot": "car_lp_s3", "hint": "Something warm is in the bin."}


func _tutorial_item() -> Dictionary:
	for it in _items.values():
		if it["def_id"] == "obj_001" and it["loc"] != "delivered":
			return it
	return {}


func _spot_x(spot_id: String) -> float:
	for sp in _spots:
		if sp["id"] == spot_id:
			return float(sp["x"])
	return -1.0


## What should glow right now. Guarantees something to do (fun check: <= 8 s without).
func get_highlights() -> Array:
	var out: Array = []
	var tut: Dictionary = get_tutorial()
	if String(tut["stage"]) != "done":
		if String(tut["target_spot"]) != "":
			out.append({"kind": "spot", "id": tut["target_spot"]})
		else:
			out.append({"kind": "x", "id": "tutorial", "x": tut["target_x"]})
		return out
	var front: Dictionary = _front_claimant()
	if not front.is_empty() and (front["state"] == "waiting" or front["state"] == "asking"):
		out.append({"kind": "passenger", "id": front["pid"]})
	if not get_items_at("bench").is_empty() or String(_player["carrying"]) != "":
		out.append({"kind": "bench", "id": "bench"})
	if _idle_t >= SHIMMER_IDLE_S or out.is_empty():
		for sp in _spots:
			if String(sp["item_iid"]) != "" and _car_unlocked(String(sp["car_id"])):
				out.append({"kind": "spot", "id": sp["id"]})
	if out.is_empty() and not get_items_at("shelf").is_empty():
		out.append({"kind": "shelf", "id": "shelf"})
	return out


# ======================= commands =======================
func player_move_to(x: float) -> Dictionary:
	_touch()
	var b: Vector2 = _walk_bounds()
	_target_x = clampf(x, b.x, b.y)
	return {"ok": true, "target_x": _target_x}


func pick_up(spot_id: String) -> Dictionary:
	_touch()
	if String(_player["carrying"]) != "":
		return {"ok": false, "reason": "hands full"}
	for sp in _spots:
		if sp["id"] == spot_id and String(sp["item_iid"]) != "":
			var iid: String = String(sp["item_iid"])
			if String(_items[iid].get("lore_id", "")) != "":
				return _collect_lore(sp, iid)
			_stat_add("items_found")
			sp["item_iid"] = ""
			_items[iid]["loc"] = "carried"
			_items[iid]["spot_id"] = ""
			_player["carrying"] = iid
			if first_delivery_done and not tutorial_done and String(spot_id).begins_with("car_pass"):
				tutorial_done = true
				Events.toast.emit("The train is yours to explore.", "info")
			Events.item_moved.emit(iid, "carried")
			return {"ok": true, "iid": iid}
	return {"ok": false, "reason": "nothing there"}


func place_on_bench(iid: String) -> Dictionary:
	_touch()
	if not _items.has(iid) or _items[iid]["loc"] == "spot" or _items[iid]["loc"] == "delivered":
		return {"ok": false, "reason": "can't bench that"}
	if get_items_at("bench").size() >= get_bench_cap():
		return {"ok": false, "reason": "bench is full"}
	_items[iid]["loc"] = "bench"
	if String(_player["carrying"]) == iid:
		_player["carrying"] = ""
	Events.item_moved.emit(iid, "bench")
	return {"ok": true}


func take_from_bench(iid: String) -> Dictionary:
	_touch()
	if not _items.has(iid) or _items[iid]["loc"] != "bench":
		return {"ok": false, "reason": "not on bench"}
	if String(_player["carrying"]) != "":
		return {"ok": false, "reason": "hands full"}
	_items[iid]["loc"] = "carried"
	_player["carrying"] = iid
	Events.item_moved.emit(iid, "carried")
	return {"ok": true}


func put_on_shelf(iid: String) -> Dictionary:
	_touch()
	if not _items.has(iid) or _items[iid]["loc"] == "spot" or _items[iid]["loc"] == "delivered":
		return {"ok": false, "reason": "can't shelve that"}
	_items[iid]["loc"] = "shelf"
	if String(_player["carrying"]) == iid:
		_player["carrying"] = ""
	Events.item_moved.emit(iid, "shelf")
	return {"ok": true}


func reveal(iid: String, tool: String) -> Dictionary:
	_touch()
	if not _items.has(iid) or not TOOL_ATTRS.has(tool):
		return {"ok": false, "reason": "bad item or tool"}
	var item: Dictionary = _items[iid]
	if item["loc"] != "bench":
		return {"ok": false, "reason": "examine it at the bench"}
	var found: Array = []
	for c in Content.object_by_id(String(item["def_id"])).get("clues", []):
		var attr: String = String(c.get("attr", ""))
		if (TOOL_ATTRS[tool] as Array).has(attr) and not (item["clues_known"] as Array).has(c["id"]):
			(item["clues_known"] as Array).append(c["id"])
			(item["unknown_attrs"] as Array).erase(attr)
			found.append(c)
			Events.clue_revealed_v2.emit(iid, c)
	return {"ok": true, "clues": found, "nothing": found.is_empty()}


func ask(pid: String, q: int) -> Dictionary:
	_touch()
	if not _passengers.has(pid) or _passengers[pid]["kind"] == "ambient":
		return {"ok": false, "reason": "nobody to ask"}
	var p: Dictionary = _passengers[pid]
	var qi: int = clampi(q, 0, 2)
	var mood: String = String(p["mood"])
	var asked: Array = p["asked"]
	var r: RandomNumberGenerator = _local_rng("ask|%s|%d|%d" % [pid, qi, asked.size()])
	var res: Dictionary = {"ok": true, "line": "", "attr": "", "value": "", "car_id": ""}
	var def_id: String = String(p["wants_item_def"])
	if qi == 0:
		var where: Dictionary = _where_info(def_id)
		res["car_id"] = String(where["car_id"])
		res["line"] = _pick_line(Content.lines("dialogue", ["where_last", mood]), r, "Somewhere near {car}.").replace("{car}", String(where["label"])).replace("{item}", _item_label(def_id))
	else:
		var pick: Dictionary = {}
		for h in _hints_for(p):
			if not asked.has(String(h["attr"])):
				pick = h
				break
		if pick.is_empty():
			res["line"] = _pick_line(Content.lines("dialogue", ["empty", mood]), r, "That's all I remember.")
		else:
			asked.append(String(pick["attr"]))
			res["attr"] = pick["attr"]
			res["value"] = pick["value"]
			res["line"] = _hint_line(p, pick, r)
			_log_answer(pid, res)
	Events.passenger_said.emit(pid, String(res["line"]))
	return res


func _hint_line(p: Dictionary, h: Dictionary, r: RandomNumberGenerator) -> String:
	var mood: String = String(p["mood"])
	var attr: String = String(h["attr"])
	var lines: Array = []
	if p["kind"] == "imposter" and bool(h.get("wrong", false)):
		lines = Content.lines("dialogue", ["imposter", "slip", mood])
	elif p["kind"] == "imposter" and r.randf() < 0.3:
		lines = Content.lines("dialogue", ["imposter", "too_perfect"])
	if lines.is_empty():
		lines = Content.lines("dialogue", ["attr_lines", attr, mood])
	if lines.is_empty():
		lines = Content.lines("dialogue", ["generic", mood])
	var line: String = _pick_line(lines, r, "It's %s." % String(h["value"]))
	return line.replace("{value}", String(h["value"])).replace("{attr}", attr.replace("_", " "))


func _log_answer(pid: String, res: Dictionary) -> void:
	for e in _claims_log:
		if e["pid"] == pid:
			if not e.has("answers"):
				e["answers"] = []
			(e["answers"] as Array).append({"attr": res["attr"], "value": res["value"], "line": res["line"]})
			return


## Hints a person can give. Regulars: owners.json hints (true), topped up from the object's own clues
## so there are always two questions' worth. Imposters: two hints, exactly one wrong.
func _hints_for(p: Dictionary) -> Array:
	if p["kind"] == "imposter":
		return p.get("imposter_hints", []) as Array
	var w: Dictionary = Content.owner_by_id(String(p["owner_id"]))
	var out: Array = []
	var seen: Dictionary = {}
	for h in (w.get("hints", {}) as Dictionary).get(String(p["wants_item_def"]), []):
		out.append({"attr": h.get("attr", ""), "value": h.get("value", ""), "wrong": false})
		seen[String(h.get("attr", ""))] = true
	for c in Content.object_by_id(String(p["wants_item_def"])).get("clues", []):
		if not seen.has(String(c.get("attr", ""))):
			out.append({"attr": c.get("attr", ""), "value": c.get("value", ""), "wrong": false})
			seen[String(c.get("attr", ""))] = true
	return out


const CAR_LABEL: Dictionary = {
	"lp": "the Lost Property car", "pass": "the Passenger car", "dine": "the Dining car",
	"sleep": "the Sleeper car", "obs": "the Observation car", "lug": "the Luggage car",
}


func _where_info(def_id: String) -> Dictionary:
	for it in _items.values():
		if it["def_id"] == def_id:
			var car_id: String = "car_lp"
			if it["loc"] == "spot":
				car_id = _car_of_spot(String(it["spot_id"]))
			for c in _cars:
				if c["id"] == car_id:
					return {"car_id": car_id, "label": String(CAR_LABEL.get(String(c["kind"]), "the train"))}
	return {"car_id": "", "label": "the middle of the train"}



func _car_of_spot(spot_id: String) -> String:
	for sp in _spots:
		if sp["id"] == spot_id:
			return String(sp["car_id"])
	return ""


func hand_over(iid: String, pid: String) -> Dictionary:
	_touch()
	if not _items.has(iid) or not _passengers.has(pid):
		return {"ok": false, "reason": "bad ids"}
	var item: Dictionary = _items[iid]
	var p: Dictionary = _passengers[pid]
	if item["loc"] == "spot" or item["loc"] == "delivered" or p["kind"] == "ambient":
		return {"ok": false, "reason": "can't hand that over"}
	var w: Dictionary = Content.owner_by_id(String(p["owner_id"]))
	var def: Dictionary = Content.object_by_id(String(item["def_id"]))
	var is_imposter: bool = p["kind"] == "imposter"
	var correct: bool = (not is_imposter) and String(item["def_id"]) == String(p["wants_item_def"])
	var res: Dictionary = {"ok": true, "correct": correct, "was_imposter": is_imposter, "tokens": 0, "rep": 0, "story": "", "line": String(w.get("wrong_line", "Hm, that's not mine."))}
	if not correct and not is_imposter and not _daily.is_empty() and String(item["def_id"]) == String(_daily.get("def_id", "")) and not bool(_daily.get("done", false)):
		_daily["wrong"] = int(_daily.get("wrong", 0)) + 1
	if correct:
		var rarity: String = String(item["rarity"])
		var tip: int = int(_econ("tip_high", 2)) if float(p["patience"]) > 0.66 else (int(_econ("tip_mid", 1)) if float(p["patience"]) > 0.33 else 0)
		res["tokens"] = _boosted(_token_for(rarity) + tip, rarity)
		res["rep"] = _rep_for(rarity)
		res["story"] = String(def.get("story", ""))
		res["line"] = String(w.get("thanks_line", "Thank you!"))
		item["loc"] = "delivered"
		if String(_player["carrying"]) == iid:
			_player["carrying"] = ""
		if not _delivered_defs.has(String(item["def_id"])):
			_delivered_defs.append(String(item["def_id"]))
		_daily_check_done(item)
		_owner_deliveries[String(p["owner_id"])] = int(_owner_deliveries.get(String(p["owner_id"]), 0)) + 1
		var beat: Dictionary = Content.arc_beat(String(p["owner_id"]), int(_owner_deliveries[String(p["owner_id"])]))
		if not beat.is_empty():
			res["arc_line"] = String(beat["line"])
			Events.arc_beat.emit(String(p["owner_id"]), int(_owner_deliveries[String(p["owner_id"])]), String(beat["line"]))
			Events.passenger_said.emit(pid, String(beat["line"]))
			Events.toast.emit("%s: %s" % [String(w.get("name", "")), String(beat["line"])], "story")
		_stat_add("handovers")
		p["leave_mood"] = "happy"
		_set_pstate(p, "receiving")
		_queue.erase(pid)
		_add_tokens(int(res["tokens"]))
		_add_rep(int(res["rep"]))
		if not first_delivery_done:
			first_delivery_done = true
			Events.toast.emit("Walking to other cars is unlocked.", "info")
			if _car_has_free_non_seat("car_pass") and _spot_item("car_pass_s1") == "":
				_spawn_item("obj_004", "car_pass_s1")
	elif is_imposter:
		_recover.append(iid)
		item["loc"] = "shelf"
		if String(_player["carrying"]) == iid:
			_player["carrying"] = ""
		p["leave_mood"] = "happy"
		_set_pstate(p, "receiving")
		_queue.erase(pid)
		res["line"] = "Thanks!"
	else:
		item["loc"] = "shelf"
		if String(_player["carrying"]) == iid:
			_player["carrying"] = ""
		p["patience"] = maxf(0.0, float(p["patience"]) - 0.2)
		Events.passenger_said.emit(pid, String(res["line"]))
	Events.item_moved.emit(iid, String(item["loc"]))
	Events.handover_result.emit(iid, pid, res)
	if autosave and correct:
		save_game()
	return res


func _spot_item(spot_id: String) -> String:
	for sp in _spots:
		if sp["id"] == spot_id:
			return String(sp["item_iid"])
	return ""


func _car_has_free_non_seat(car_id: String) -> bool:
	return _car_unlocked(car_id)


func refuse(pid: String) -> Dictionary:
	_touch()
	if not _passengers.has(pid) or _passengers[pid]["kind"] == "ambient":
		return {"ok": false, "reason": "nobody to refuse"}
	var p: Dictionary = _passengers[pid]
	var was_imp: bool = p["kind"] == "imposter"
	var res: Dictionary = {"ok": true, "was_imposter": was_imp, "tokens": 0, "rep": 0, "line": "Oh. Right. Sorry to bother you."}
	var rl: RandomNumberGenerator = _local_rng("refuse|" + pid)
	res["line"] = _pick_line(Content.lines("barks", ["refused", "imposter" if was_imp else "honest"]), rl, String(res["line"]))
	_stat_add("refusals")
	if was_imp:
		_stat_add("imposters_caught")
		res["tokens"] = 8
		res["rep"] = 1
		_add_tokens(8)
		_add_rep(1)
		p["leave_mood"] = "annoyed"
	else:
		p["leave_mood"] = "sad"
	_queue.erase(pid)
	_set_pstate(p, "leaving")
	return res


func call_next() -> Dictionary:
	_touch()
	var called: String = ""
	if _queue.size() < MAX_CLAIMANTS:
		for p in _passengers.values():
			if p["kind"] != "ambient" and p["state"] == "seated":
				p["t"] = 0.0  # stand up now
				called = String(p["pid"])
				break
	return {"ok": true, "queue": _queue.size(), "called": called}


func buy(upgrade_id: String) -> Dictionary:
	for u in Content.shop.get("upgrades", []):
		if u["id"] != upgrade_id:
			continue
		var costs: Array = u.get("costs", [])
		var lvl: int = int(_upgrades.get(upgrade_id, 0))
		if lvl >= costs.size():
			return {"ok": false, "reason": "already maxed", "id": upgrade_id}
		var cost: int = int(costs[lvl])
		if tokens < cost:
			return {"ok": false, "reason": "not enough tokens", "id": upgrade_id, "cost": cost}
		_add_tokens(-cost)
		_upgrades[upgrade_id] = lvl + 1
		Events.toast.emit("%s bought." % String(u["name"]), "info")
		return {"ok": true, "id": upgrade_id, "level": lvl + 1, "cost": cost}
	return {"ok": false, "reason": "unknown upgrade", "id": upgrade_id}


func set_time_scale(x: float) -> Dictionary:
	time_scale = clampf(x, 0.0, 100.0)
	return {"ok": true, "time_scale": time_scale}


## Fast-forward until the train starts arriving at the next stop (cheat / screenshots).
func skip_to_next_stop() -> Dictionary:
	var guard: int = 0
	var was_arriving: bool = _train["state"] == "arriving"
	while guard < 2000:
		tick(0.5)
		guard += 1
		if _train["state"] == "arriving" and not was_arriving:
			break
		if _train["state"] != "arriving":
			was_arriving = false
	return {"ok": true, "stop": _train["stop"]}


func skip_tutorial() -> Dictionary:
	first_delivery_done = true
	tutorial_done = true
	bram_spawned = true
	return {"ok": true}


# ======================= economy =======================
func tier_for(r: int) -> int:
	var t: int = 0
	for i in range(TIER_THRESHOLDS.size()):
		if r >= int(TIER_THRESHOLDS[i]):
			t = i
	return t


func _add_tokens(n: int) -> void:
	tokens += n
	if n > 0:
		_stat_add("tokens_total", n)
	_player["tokens"] = tokens
	Events.tokens_changed.emit(tokens)


func _add_rep(n: int) -> void:
	rep = maxi(0, rep + n)
	var t: int = tier_for(rep)
	_player["rep"] = rep
	_player["tier"] = t
	for c in _cars:
		if not bool(c["unlocked"]) and int(CAR_UNLOCK_TIER[c["id"]]) <= t:
			c["unlocked"] = true
			Events.car_unlocked.emit(String(c["id"]))
	Events.reputation_changed.emit(rep, t)


# ======================= offline progress (A6.1) =======================
const OFFLINE_MAX_AWAY_S: float = 30.0 * 86400.0
var _off_shelved: int = 0


## Fast-forward `elapsed_s` of real time while the app was closed: 1 stop per offline_stop_s
## (default 360 s), at most offline_stop_cap stops (default 20, ~2 h). Claimants queue but are
## never resolved or lost; ambient churn is aggregated. Unix time only, so time-zone changes do
## not matter; negative, NaN and absurd gaps are handled. Emits Events.offline_report once.
## `force` skips the tutorial gate (cheats). Returns the report ({} fields all >= 0).
func apply_offline(elapsed_s: float, force: bool = false) -> Dictionary:
	var rpt: Dictionary = {"away_s": 0, "stops": 0, "items_found": 0, "items_shelved": 0, "tokens": 0, "rep": 0, "claimants_waiting": _active_claimants(), "lines": [], "capped": false}
	_last_seen = int(Time.get_unix_time_from_system())
	if is_nan(elapsed_s) or is_inf(elapsed_s) or elapsed_s <= 0.0 or _routes.is_empty() or _train.is_empty():
		return rpt
	var away: float = minf(elapsed_s, OFFLINE_MAX_AWAY_S)
	rpt["away_s"] = int(away)
	if not tutorial_done and not force:
		return rpt
	var stop_s: float = maxf(30.0, float(_econ("offline_stop_s", 360.0)))
	var cap: int = maxi(1, int(_econ("offline_stop_cap", 20)))
	var raw_stops: int = int(away / stop_s)
	var stops: int = mini(raw_stops, cap)
	rpt["capped"] = raw_stops > cap
	if stops <= 0:
		return rpt
	var t0: int = tokens
	var r0: int = rep
	var iid0: int = _next_iid
	_off_shelved = 0
	var per_stop: int = int(_econ("offline_tokens_per_stop", 1)) + int(_econ("offline_tokens_per_porter", 2)) * int(_upgrades.get("porter", 0))
	var rep_per: int = int(_econ("offline_rep_per_stop", 0))
	for _i in range(stops):
		stop_index += 1
		_reseed()
		_train["stop"] = _stop_info(stop_index)
		_train["weather"] = _roll_weather()
		_train["state"] = "stopped"
		_on_stopped(true)
		if per_stop > 0:
			_add_tokens(per_stop)
		if rep_per > 0:
			_add_rep(rep_per)
	clock_s += float(stops) * stop_s
	# leave the train rolling towards the next stop; waiting claimants walk in shortly
	_train["state"] = "moving"
	_train["speed"] = 1.0
	_state_len = _phase_len("moving")
	_state_t = rng.randf() * _state_len * 0.5
	_train["phase_t"] = clampf(_state_t / maxf(_state_len, 0.001), 0.0, 1.0)
	_target_x = -1.0
	for p in _passengers.values():
		if p["kind"] != "ambient" and p["state"] == "seated":
			p["t"] = minf(float(p["t"]), rng.randf_range(0.5, 3.0))
	rpt["stops"] = stops
	rpt["items_found"] = maxi(0, _next_iid - iid0)
	rpt["items_shelved"] = maxi(0, _off_shelved)
	rpt["tokens"] = maxi(0, tokens - t0)
	rpt["rep"] = maxi(0, rep - r0)
	rpt["claimants_waiting"] = _active_claimants()
	rpt["lines"] = _offline_lines(rpt)
	Events.train_state_changed.emit("moving", _train["stop"])
	last_offline_report = rpt
	Events.offline_report.emit(rpt)
	if autosave:
		save_game()
	return rpt


func _offline_lines(r: Dictionary) -> Array:
	var out: Array = []
	var m: int = int(r["away_s"]) / 60
	var away_txt: String = "%d min" % m if m < 120 else "%d h %d min" % [m / 60, m % 60]
	out.append("You were away %s. The train made %d stop%s%s." % [away_txt, int(r["stops"]), "" if int(r["stops"]) == 1 else "s", " (that is as far as it goes without you)" if bool(r["capped"]) else ""])
	if int(r["items_found"]) > 0:
		out.append("%d new thing%s turned up." % [int(r["items_found"]), "" if int(r["items_found"]) == 1 else "s"])
	if int(r["items_shelved"]) > 0:
		out.append("The porters shelved %d." % int(r["items_shelved"]))
	if int(r["tokens"]) > 0:
		out.append("Tips in the jar: %d tokens." % int(r["tokens"]))
	if int(r["claimants_waiting"]) > 0:
		out.append("%d %s waiting for you." % [int(r["claimants_waiting"]), "person is" if int(r["claimants_waiting"]) == 1 else "people are"])
	return out


# ======================= save / load (A1.5) =======================
func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "seed_base": seed_base, "stop_index": stop_index, "clock_s": clock_s, "cheated": cheated, "upgrades": _upgrades.duplicate(true), "daily": _daily.duplicate(true), "daily_log": _daily_log.duplicate(true),
		"tokens": tokens, "rep": rep, "first_delivery_done": first_delivery_done, "tutorial_done": tutorial_done, "bram_spawned": bram_spawned,
		"rng_state": str(rng.state), "cars_unlocked": _cars.map(func(c): return bool(c["unlocked"])),
		"spots": _spots.map(func(s): return String(s["item_iid"])), "items": _items.duplicate(true), "passengers": _passengers.duplicate(true), "queue": _queue.duplicate(true),
		"train": _train.duplicate(true), "state_t": _state_t, "state_len": _state_len, "player": _player.duplicate(true), "next_iid": _next_iid, "next_pid": _next_pid,
		"recover": _recover.duplicate(true), "delivered": _delivered_defs.duplicate(true), "owner_deliveries": _owner_deliveries.duplicate(true), "claims": _claims_log.duplicate(true),
		"ambient": _amb_ref().to_dict(), "last_seen": int(Time.get_unix_time_from_system()), "saves_n": _saves_n,
		"lore_found": _lore_found.duplicate(), "stats": _stats.duplicate(), "play_days": _play_days.duplicate(),
	}


## Bring an older save dict up to SAVE_VERSION (v2 -> v3 adds saves_n). Returns {} if unusable.
func migrate_save(d: Dictionary) -> Dictionary:
	var v: int = int(d.get("version", 0))
	if v < 2 or v > SAVE_VERSION or not d.has("items") or not d.has("train"):
		return {}
	var m: Dictionary = d.duplicate(true)
	if v < 3:
		m["saves_n"] = int(m.get("saves_n", 0))
	m["version"] = SAVE_VERSION
	return m


func from_dict(d: Dictionary) -> bool:
	if typeof(d) != TYPE_DICTIONARY:
		return false
	d = migrate_save(d)
	if d.is_empty():
		return false
	_saves_n = int(d.get("saves_n", 0))
	_lore_found = (d.get("lore_found", []) as Array).duplicate()
	_stats = (d.get("stats", {}) as Dictionary).duplicate()
	_play_days = (d.get("play_days", []) as Array).duplicate()
	_note_day()
	_build_cars()
	seed_base = int(d.get("seed_base", 1))
	stop_index = int(d.get("stop_index", 0))
	clock_s = float(d.get("clock_s", 0.0))
	cheated = bool(d.get("cheated", false))
	_upgrades = (d.get("upgrades", {}) as Dictionary).duplicate(true)
	_daily = (d.get("daily", {}) as Dictionary).duplicate(true)
	_daily_log = (d.get("daily_log", {}) as Dictionary).duplicate(true)
	tokens = int(d.get("tokens", 0))
	rep = int(d.get("rep", 0))
	first_delivery_done = bool(d.get("first_delivery_done", false))
	tutorial_done = bool(d.get("tutorial_done", false))
	bram_spawned = bool(d.get("bram_spawned", false))
	rng.seed = seed_base
	rng.state = int(String(d.get("rng_state", "0")))
	var unlocked: Array = d.get("cars_unlocked", [])
	for i in range(mini(unlocked.size(), _cars.size())):
		_cars[i]["unlocked"] = bool(unlocked[i])
	var spot_items: Array = d.get("spots", [])
	for i in range(mini(spot_items.size(), _spots.size())):
		_spots[i]["item_iid"] = String(spot_items[i])
	_items = (d["items"] as Dictionary).duplicate(true)
	_passengers = (d.get("passengers", {}) as Dictionary).duplicate(true)
	_queue = (d.get("queue", []) as Array).duplicate(true)
	_train = (d["train"] as Dictionary).duplicate(true)
	if _train.has("stop") and typeof(_train["stop"]) == TYPE_DICTIONARY:
		_train["stop"]["index"] = int(_train["stop"].get("index", 0))
	_state_t = float(d.get("state_t", 0.0))
	_state_len = float(d.get("state_len", 75.0))
	_player = (d.get("player", {"x": _lp_x() + 900.0, "car_id": "car_lp", "carrying": "", "tokens": tokens, "rep": rep, "tier": tier_for(rep)}) as Dictionary).duplicate(true)
	_player["tokens"] = int(_player.get("tokens", tokens))
	_player["rep"] = int(_player.get("rep", rep))
	_player["tier"] = int(_player.get("tier", tier_for(rep)))
	_next_iid = int(d.get("next_iid", 100))
	_next_pid = int(d.get("next_pid", 0))
	_recover = (d.get("recover", []) as Array).duplicate(true)
	_amb_ref().from_dict(d.get("ambient", {}) as Dictionary)
	_delivered_defs = (d.get("delivered", []) as Array).duplicate(true)
	_owner_deliveries = (d.get("owner_deliveries", {}) as Dictionary).duplicate(true)
	_claims_log = (d.get("claims", []) as Array).duplicate(true)
	_target_x = -1.0
	_last_seen = int(d.get("last_seen", int(Time.get_unix_time_from_system())))
	return true


func _bak_path() -> String:
	return save_path.get_basename() + ".bak"


## Atomic save: write + verify a temp file, copy the current save to .bak, then rename over it.
func save_game() -> bool:
	_autosave_t = 0.0
	_saves_n += 1
	var text: String = JSON.stringify(to_dict())
	var tmp: String = save_path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if _parse(FileAccess.get_file_as_string(tmp)) == null:
		DirAccess.remove_absolute(tmp)
		push_warning("[Sim] save verification failed; kept the old save")
		return false
	var dir: DirAccess = DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return false
	if dir.file_exists(save_path.get_file()):
		dir.copy(save_path, _bak_path())
	if dir.rename(save_path.get_file() + ".tmp", save_path.get_file()) == OK:
		return true
	if dir.file_exists(save_path.get_file()):
		dir.remove(save_path.get_file())
	return dir.rename(save_path.get_file() + ".tmp", save_path.get_file()) == OK


func _try_load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var data: Variant = _parse(FileAccess.get_file_as_string(path))
	return typeof(data) == TYPE_DICTIONARY and from_dict(data)


func get_load_notice() -> String:
	return _load_notice


## Main save, else the backup, else false (caller starts fresh). A bad file is kept as .corrupt.
func load_game() -> bool:
	if _routes.is_empty():
		_load_routes()
	_load_notice = ""
	if FileAccess.file_exists(save_path):
		if _try_load_file(save_path):
			return true
		var dir: DirAccess = DirAccess.open(save_path.get_base_dir())
		if dir != null:
			dir.copy(save_path, save_path + ".corrupt")
		if _try_load_file(_bak_path()):
			_load_notice = "Your last save was damaged, so we restored the one before it."
			Events.toast.emit(_load_notice, "info")
			return true
		_load_notice = "Your save could not be read, so a fresh night begins. (A copy was kept.)"
		push_warning("[Sim] save unreadable or from another version; starting fresh")
		Events.toast.emit(_load_notice, "info")
		return false
	if _try_load_file(_bak_path()):
		_load_notice = "Your save was missing, so we restored the backup."
		Events.toast.emit(_load_notice, "info")
		return true
	return _migrate_v1()


## First launch after updating from v1: carry tokens, reputation and delivered items over.
func _migrate_v1() -> bool:
	if not FileAccess.file_exists(v1_save_path):
		return false
	var data: Variant = _parse(FileAccess.get_file_as_string(v1_save_path))
	if typeof(data) != TYPE_DICTIONARY or int((data as Dictionary).get("version", 0)) != 1:
		return false
	new_game(int(Time.get_unix_time_from_system()) % 1000000)
	tokens = int(data.get("coins", 0))
	rep = int(data.get("reputation", 0))
	for m in data.get("matched", []):
		if typeof(m) == TYPE_STRING and Content.has_object(m):
			_delivered_defs.append(m)
	var om: Variant = data.get("owner_matches", {})
	if typeof(om) == TYPE_DICTIONARY:
		_owner_deliveries = om
	if rep > 0 or not _delivered_defs.is_empty():
		first_delivery_done = true
		tutorial_done = true
		bram_spawned = true
		_items.clear()
		for sp in _spots:
			sp["item_iid"] = ""
	_player["tokens"] = tokens
	_player["rep"] = rep
	_player["tier"] = tier_for(rep)
	for c in _cars:
		c["unlocked"] = int(CAR_UNLOCK_TIER[c["id"]]) <= int(_player["tier"])
	return true


# ======================= daily Night Case (A3.4) =======================
func daily_date() -> String:
	return Time.get_date_string_from_system(true)


func daily_number(date: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(date + "T00:00:00") / 86400.0) - 20453  # #1 = 2026-01-01


## Deterministic pick for a date: same item on every device, independent of the Sim rng.
func daily_def_for(date: String) -> String:
	var ids: Array = []
	for o in Content.objects:
		ids.append(String(o["id"]))
	for o in Content.generated_objects:
		ids.append(String(o["id"]))
	ids.sort()
	if ids.is_empty():
		return ""
	return String(ids[absi(date.hash()) % ids.size()])


func get_daily(date: String = "") -> Dictionary:
	var dt: String = date if date != "" else daily_date()
	var did: String = daily_def_for(dt)
	var log: Dictionary = _daily_log.get(dt, {})
	var def: Dictionary = Content.object_by_id(did)
	return {"date": dt, "number": daily_number(dt), "def_id": did, "title": String(def.get("name", "")), "owner_id": String(def.get("owner_id", "")),
		"started": _daily.get("date", "") == dt, "done": bool(log.get("done", false)), "wrong": int(log.get("wrong", _daily.get("wrong", 0))),
		"available": not cheated, "share": daily_share_text(dt)}


## Puts today's case on the train: the item on a free spot and its owner queued at the door.
func start_daily(date: String = "") -> Dictionary:
	if cheated:
		return {"ok": false, "reason": "cheated runs can't play the Night Case"}
	var dt: String = date if date != "" else daily_date()
	if bool((_daily_log.get(dt, {}) as Dictionary).get("done", false)):
		return {"ok": false, "reason": "already solved today"}
	if _daily.get("date", "") == dt:
		return {"ok": true, "iid": String(_daily.get("iid", "")), "resumed": true}
	var did: String = daily_def_for(dt)
	for it in _items.values():
		if String(it["def_id"]) == did:
			return {"ok": false, "reason": "that item is already on the train"}
	var sp: String = _free_spot_id()
	if did == "" or sp == "":
		return {"ok": false, "reason": "no room right now"}
	var it2: Dictionary = _spawn_item(did, sp)
	var oid: String = String(Content.object_by_id(did).get("owner_id", ""))
	if oid != "" and not _owner_has_claimant(oid) and _active_claimants() < MAX_CLAIMANTS:
		_spawn_claimant(oid, did, false)
	_daily = {"date": dt, "def_id": did, "iid": String(it2["iid"]), "wrong": 0, "done": false}
	Events.toast.emit("Night Case #%d is on the train." % daily_number(dt), "info")
	return {"ok": true, "iid": String(it2["iid"])}


func _daily_check_done(item: Dictionary) -> void:
	if _daily.is_empty() or cheated or bool(_daily.get("done", false)) or String(item["def_id"]) != String(_daily["def_id"]):
		return
	_daily["done"] = true
	var dt: String = String(_daily["date"])
	var res: Dictionary = {"date": dt, "wrong": int(_daily.get("wrong", 0)), "clues": (item["clues_known"] as Array).size(), "done": true}
	_daily_log[dt] = res
	Events.daily_completed.emit(get_daily(dt))


## Spoiler-free emoji share text; "" until solved or if the run was cheated.
func daily_share_text(date: String = "") -> String:
	var dt: String = date if date != "" else daily_date()
	var log: Dictionary = _daily_log.get(dt, {})
	if cheated or not bool(log.get("done", false)):
		return ""
	var w: int = int(log.get("wrong", 0))
	var clues: int = int(log.get("clues", 0))
	var row: String = "\u2753".repeat(0) + "\U0001F50D".repeat(clues) + "\u274C".repeat(w) + "\u2705"
	return "Platform Zero \u00B7 Night Case #%d\n%s\n%s" % [daily_number(dt), row, "Solved clean" if w == 0 else "%d wrong guess%s" % [w, "" if w == 1 else "es"]]
