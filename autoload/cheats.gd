extends Node
## Cheat backend (A5.1). Password hash comes from gitignored res://generated/cheat_hash.gd
## (written by CI from the CHEAT_PW_HASH secret). No hash file => panel disabled.
## Check: ("pz1|" + input + "|zero").sha256_text() == HASH

const HASH_PATH: String = "res://generated/cheat_hash.gd"
const LOG_PATH: String = "user://cheats.log"
const MAX_TRIES: int = 3
const LOCKOUT_MS: int = 30000
## tools/shoot.gd sets this so screenshot setups can call a small safe subset without the password.
var screenshot_mode: bool = false
const SCREENSHOT_SAFE: PackedStringArray = ["trigger_first_minute", "skip_next_stop", "skip_stop"]

var _unlocked: bool = false
var _hash: String = ""
var _fails: int = 0
var _locked_until_ms: int = 0
var night_override: int = -1  # -1 auto, 0 day, 1 night (B may read)


func _ready() -> void:
	_load_hash()


func _load_hash() -> void:
	_hash = ""
	if not ResourceLoader.exists(HASH_PATH):
		return
	var s: Resource = load(HASH_PATH)
	if s is GDScript:
		var m: Dictionary = (s as GDScript).get_script_constant_map()
		_hash = String(m.get("HASH", ""))


func is_available() -> bool: return _hash != ""
func is_unlocked() -> bool: return _unlocked


func lockout_left() -> float:
	return maxf(0.0, float(_locked_until_ms - Time.get_ticks_msec()) / 1000.0)


func try_unlock(pw: String) -> bool:
	if _hash == "" or lockout_left() > 0.0:
		return false
	if ("pz1|" + pw + "|zero").sha256_text() == _hash:
		_unlocked = true
		_fails = 0
		_log("unlock")
		return true
	_fails += 1
	_log("unlock_fail")
	if _fails >= MAX_TRIES:
		_fails = 0
		_locked_until_ms = Time.get_ticks_msec() + LOCKOUT_MS
	return false


func lock() -> void:
	_unlocked = false


func _log(line: String) -> void:
	var f: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s %s" % [Time.get_datetime_string_from_system(true), line])
	f.close()


func list() -> Array:
	return [
		{"id": "tokens_100", "label": "+100 tokens", "category": "Economy", "kind": "button", "args": {}},
		{"id": "tokens_1000", "label": "+1000 tokens", "category": "Economy", "kind": "button", "args": {}},
		{"id": "set_rep", "label": "Set reputation", "category": "Economy", "kind": "number", "args": {"min": 0, "max": 500, "default": 10}},
		{"id": "tier_up", "label": "Tier up", "category": "Economy", "kind": "button", "args": {}},
		{"id": "skip_stop", "label": "Skip to next stop", "category": "Time", "kind": "button", "args": {}},
		{"id": "speed", "label": "Speed", "category": "Time", "kind": "choice", "args": {"options": [1, 10, 60]}},
		{"id": "advance_hours", "label": "Advance N hours", "category": "Time", "kind": "number", "args": {"min": 1, "max": 24, "default": 1}},
		{"id": "spawn_item", "label": "Spawn item (def id)", "category": "Spawn", "kind": "text", "args": {"default": "obj_001"}},
		{"id": "spawn_claimant", "label": "Spawn claimant", "category": "Spawn", "kind": "button", "args": {}},
		{"id": "spawn_imposter", "label": "Spawn imposter", "category": "Spawn", "kind": "button", "args": {}},
		{"id": "spawn_regular", "label": "Spawn regular", "category": "Spawn", "kind": "button", "args": {}},
		{"id": "spawn_rare", "label": "Spawn rare item", "category": "Spawn", "kind": "button", "args": {}},
		{"id": "reveal_all", "label": "Reveal all clues on bench", "category": "Solve", "kind": "button", "args": {}},
		{"id": "show_owner", "label": "Show owners of items", "category": "Solve", "kind": "button", "args": {}},
		{"id": "teleport_lp", "label": "Teleport to Lost Property", "category": "Player", "kind": "button", "args": {}},
		{"id": "unlock_cars", "label": "Unlock all cars", "category": "Player", "kind": "button", "args": {}},
		{"id": "show_states", "label": "Show states", "category": "Debug", "kind": "button", "args": {}},
		{"id": "dump_save", "label": "Dump save", "category": "Debug", "kind": "button", "args": {}},
		{"id": "reset_tutorial", "label": "Reset tutorial", "category": "Debug", "kind": "button", "args": {}},
		{"id": "confetti", "label": "Confetti", "category": "Fun", "kind": "button", "args": {}},
		{"id": "night_toggle", "label": "Night/day toggle", "category": "Fun", "kind": "button", "args": {}},
	]


func run(id: String, value: Variant = null) -> Dictionary:
	var shot_ok: bool = screenshot_mode and SCREENSHOT_SAFE.has(id)
	if not (_unlocked or shot_ok):
		return {"ok": false, "reason": "locked"}
	if not shot_ok:
		_log("run %s %s" % [id, str(value)])
		Sim.cheated = true
	return _exec(id, value)


func _exec(id: String, value: Variant) -> Dictionary:
	match id:
		"trigger_first_minute":
			Sim.new_game(Sim.seed_base)
			return {"ok": true}
		"skip_next_stop", "skip_stop":
			return Sim.skip_to_next_stop()
		"tokens_100":
			Sim._add_tokens(100)
			return {"ok": true, "tokens": Sim.tokens}
		"tokens_1000":
			Sim._add_tokens(1000)
			return {"ok": true, "tokens": Sim.tokens}
		"set_rep":
			Sim._add_rep(clampi(int(value if value != null else 10), 0, 500) - Sim.rep)
			return {"ok": true, "rep": Sim.rep, "tier": Sim.tier_for(Sim.rep)}
		"tier_up":
			var t: int = Sim.tier_for(Sim.rep)
			if t >= Sim.TIER_THRESHOLDS.size() - 1:
				return {"ok": false, "reason": "max tier"}
			Sim._add_rep(int(Sim.TIER_THRESHOLDS[t + 1]) - Sim.rep)
			return {"ok": true, "rep": Sim.rep, "tier": Sim.tier_for(Sim.rep)}
		"speed":
			return Sim.set_time_scale(float(value if value != null else 1))
		"advance_hours":
			var secs: float = clampf(float(value if value != null else 1), 1.0, 24.0) * 3600.0
			var left: float = secs
			while left > 0.0:
				Sim.tick(minf(left, 5.0))
				left -= 5.0
			return {"ok": true, "stop": Sim.stop_index}
		"spawn_item":
			var did: String = String(value if value != null else "obj_001")
			if not Content.has_object(did):
				return {"ok": false, "reason": "unknown def"}
			var sp: String = Sim._free_spot_id()
			if sp == "":
				return {"ok": false, "reason": "no free spot"}
			return {"ok": true, "item": Sim._spawn_item(did, sp)}
		"spawn_rare":
			var rares: Array = []
			for o in Content.objects:
				if String(o.get("rarity", "")) == "rare":
					rares.append(String(o["id"]))
			var sp2: String = Sim._free_spot_id()
			if rares.is_empty() or sp2 == "":
				return {"ok": false, "reason": "none available"}
			return {"ok": true, "item": Sim._spawn_item(String(rares[randi() % rares.size()]), sp2)}
		"spawn_claimant", "spawn_regular":
			var pairs: Array = []
			for it in Sim.get_items_at("spot") + Sim.get_items_at("shelf") + Sim.get_items_at("bench"):
				pairs.append(it)
			if pairs.is_empty():
				return {"ok": false, "reason": "no items on train"}
			var item: Dictionary = pairs[randi() % pairs.size()]
			var owner_id: String = ""
			for w in Content.owners:
				if (w.get("lost_item_ids", []) as Array).has(item["def_id"]):
					owner_id = String(w["id"])
			if owner_id == "" and not Content.owners.is_empty():
				owner_id = String(Content.owners[0]["id"])
			return {"ok": true, "passenger": Sim._spawn_claimant(owner_id, String(item["def_id"]), true)}
		"spawn_imposter":
			var p: Dictionary = Sim.spawn_imposter()
			return {"ok": not p.is_empty(), "passenger": p}
		"reveal_all":
			var n: int = 0
			for it in Sim.get_items_at("bench"):
				for tool in Sim.TOOL_ATTRS.keys():
					n += (Sim.reveal(String(it["iid"]), String(tool)).get("clues", []) as Array).size()
			return {"ok": true, "revealed": n}
		"show_owner":
			var out: Array = []
			for it in Sim._items.values():
				if it["loc"] == "delivered":
					continue
				for w in Content.owners:
					if (w.get("lost_item_ids", []) as Array).has(it["def_id"]):
						out.append("%s -> %s" % [it["name"], w.get("name", w["id"])])
			Events.toast.emit("\n".join(out) if not out.is_empty() else "No known owners", "info")
			return {"ok": true, "owners": out}
		"teleport_lp":
			Sim._player["x"] = Sim._lp_x() + 900.0
			Sim._player["car_id"] = "car_lp"
			Sim._target_x = -1.0
			return {"ok": true}
		"unlock_cars":
			for c in Sim._cars:
				if not bool(c["unlocked"]):
					c["unlocked"] = true
					Events.car_unlocked.emit(String(c["id"]))
			return {"ok": true}
		"show_states":
			var s: String = "stop %d  %s  q=%d  pass=%d  items=%d  tok=%d rep=%d" % [Sim.stop_index, Sim.get_train().get("state", ""), Sim.get_queue().size(), Sim.get_passengers().size(), Sim._items.size(), Sim.tokens, Sim.rep]
			Events.toast.emit(s, "info")
			return {"ok": true, "text": s}
		"dump_save":
			return {"ok": true, "save": Sim.to_dict()}
		"reset_tutorial":
			Sim.new_game(Sim.seed_base)
			Sim.cheated = true
			return {"ok": true}
		"confetti":
			Events.toast.emit("Confetti!", "good")
			return {"ok": true}
		"night_toggle":
			night_override = (0 if night_override != 0 else 1)
			Sim._train["time_of_day"] = 0.1 if night_override == 1 else 0.5
			return {"ok": true, "night": night_override == 1}
	return {"ok": false, "reason": "unknown cheat"}
