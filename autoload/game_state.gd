extends Node
## Core game state: persistent save, counter inventory, offline arrivals,
## owner visits, matching, reputation. Emits Events; B calls only the public API.

const SAVE_VERSION: int = 1
const ARRIVAL_INTERVAL: int = 1200       # seconds between arrivals (~20 min)
const ARRIVAL_CAP: int = 12              # max arrivals accrued per catch-up
const MAX_COUNTER: int = 12              # counter never holds more than this
const BOOT_VISIT_DELAY: int = 3          # seconds until first owner after launch
const NEXT_VISIT_DELAY: int = 6          # seconds until next owner after a match
const RETURN_DELAY: int = 90             # seconds until an owner returns after a wrong match
const STARTER_ID: String = "obj_001"
const TIER_THRESHOLDS: Array = [0, 10, 30, 70]
const REWARD_BY_RARITY: Dictionary = {"common": 5, "odd": 10, "rare": 20}
const REPUTATION_BY_RARITY: Dictionary = {"common": 2, "odd": 3, "rare": 5}

## Overridable for tests.
var save_path: String = "user://save.json"
var autosave: bool = true

var _counter: Array = []          # [{id, arrived_at, revealed:[clue ids]}]
var _shelf: Array = []            # [{id, shelved_at, revealed:[clue ids]}]
var _matched: Array = []          # item ids already returned to owners
var _discovered: Dictionary = {}  # item id -> true (seen at least once)
var _met: Dictionary = {}         # owner id -> true
var _owner_matches: Dictionary = {}  # owner id -> int
var _reputation: int = 0
var _coins: int = 0
var _arrival_index: int = 0
var _arrival_anchor: int = 0
var _last_seen: int = 0
var _visit_count: int = 0
var _last_owner: String = ""
var _visit: Dictionary = {}       # {owner_id, wanted_item_id, at, present}
var _dirty: bool = false
var _accum: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 1.0:
		return
	_accum = 0.0
	_tick()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_tick()


# ----------------------------------------------------------------- public API

func get_counter_items() -> Array:
	return _views(_counter)


func get_shelf_items() -> Array:
	return _views(_shelf)


## Reveal the next unrevealed clue of an item on the counter or shelf.
## Returns the clue, or {} if there is nothing left to reveal / unknown item.
func inspect(item_id: String) -> Dictionary:
	var entry: Dictionary = _entry(item_id)
	var obj: Dictionary = Content.object_by_id(item_id)
	if entry.is_empty() or obj.is_empty():
		return {}
	var revealed: Array = entry["revealed"]
	for c in obj.get("clues", []):
		var clue: Dictionary = c
		if not revealed.has(clue["id"]):
			revealed.append(clue["id"])
			_dirty = true
			Events.clue_revealed.emit(item_id, clue.duplicate(true))
			return clue.duplicate(true)
	return {}


## Offer an item to an owner. Correct: reward + story, item leaves for good.
## Wrong: the item goes to the Dusty Shelf and the owner comes back later.
func try_match(item_id: String, owner_id: String) -> Dictionary:
	var obj: Dictionary = Content.object_by_id(item_id)
	var own: Dictionary = Content.owner_by_id(owner_id)
	if obj.is_empty() or own.is_empty() or _entry(item_id).is_empty():
		return {"correct": false, "reward": 0, "story": "", "line": own.get("wrong_line", "")}
	var correct: bool = obj.get("owner_id", "") == owner_id
	var reward: int = 0
	var story: String = ""
	var line: String = ""
	var shelf_dirty: bool = false
	if correct:
		var rarity: String = obj.get("rarity", "common")
		reward = int(REWARD_BY_RARITY.get(rarity, 5))
		_reputation += int(REPUTATION_BY_RARITY.get(rarity, 2))
		_coins += reward
		shelf_dirty = _remove_entry(_shelf, item_id)
		_remove_entry(_counter, item_id)
		if not _matched.has(item_id):
			_matched.append(item_id)
		_owner_matches[owner_id] = int(_owner_matches.get(owner_id, 0)) + 1
		_met[owner_id] = true
		story = obj.get("story", "")
		line = own.get("thanks_line", "")
		_visit = {}
	else:
		var idx: int = _find(_counter, item_id)
		if idx >= 0:
			var moved: Dictionary = _counter[idx]
			_counter.remove_at(idx)
			_shelf.append({"id": item_id, "shelved_at": Clock.now(), "revealed": moved["revealed"]})
			shelf_dirty = true
		line = own.get("wrong_line", "")
		# The owner leaves and comes back later, still wanting the same thing.
		var wanted: String = _visit.get("wanted_item_id", "")
		if wanted != "" and _entry(wanted).is_empty():
			wanted = ""
		_visit = {}
		if wanted != "":
			_visit = {"owner_id": owner_id, "wanted_item_id": wanted,
				"at": Clock.now() + RETURN_DELAY, "present": false}
	_dirty = true
	Events.match_result.emit(item_id, owner_id, correct, reward)
	if shelf_dirty:
		Events.shelf_changed.emit()
	if correct:
		Events.reputation_changed.emit(_reputation, get_tier())
	save()
	return {"correct": correct, "reward": reward, "story": story, "line": line}


## The owner currently at the counter ({} if none). Adds "wanted_item_id".
func get_current_owner() -> Dictionary:
	if not _visit.get("present", false):
		return {}
	var own: Dictionary = Content.owner_by_id(_visit["owner_id"])
	if own.is_empty():
		return {}
	var d: Dictionary = own.duplicate(true)
	d["wanted_item_id"] = _visit["wanted_item_id"]
	return d


func get_reputation() -> int:
	return _reputation


func get_tier() -> int:
	var tier: int = 0
	for i in TIER_THRESHOLDS.size():
		if _reputation >= int(TIER_THRESHOLDS[i]):
			tier = i
	return tier


func get_coins() -> int:
	return _coins


func get_catalog() -> Array:
	var out: Array = []
	for o in Content.objects:
		var obj: Dictionary = o
		var d: Dictionary = obj.duplicate(true)
		d["discovered"] = _discovered.has(obj["id"]) or _matched.has(obj["id"])
		d["matched"] = _matched.has(obj["id"])
		out.append(d)
	return out


func get_gallery() -> Array:
	var out: Array = []
	for w in Content.owners:
		var own: Dictionary = w
		var d: Dictionary = own.duplicate(true)
		d["met"] = _met.has(own["id"])
		d["matches"] = int(_owner_matches.get(own["id"], 0))
		out.append(d)
	return out


## Write the save file (atomic: temp file then rename).
func save() -> void:
	_last_seen = Clock.now()
	var text: String = JSON.stringify(_to_dict())
	var tmp: String = save_path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("[GameState] cannot write save: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(text)
	f.close()
	var dir: DirAccess = DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return
	var target: String = save_path.get_file()
	if dir.rename(tmp.get_file(), target) != OK:
		dir.remove(target)
		dir.rename(tmp.get_file(), target)
	_dirty = false


## Load the save (or start fresh) and apply offline arrivals.
func load_game() -> void:
	_reset_state()
	var loaded: bool = false
	if FileAccess.file_exists(save_path):
		var json: JSON = JSON.new()
		var parsed: bool = json.parse(FileAccess.get_file_as_string(save_path)) == OK
		var data: Variant = json.data if parsed else null
		if typeof(data) == TYPE_DICTIONARY:
			_apply(data)
			loaded = true
		else:
			push_warning("[GameState] save unreadable; keeping a .corrupt copy and starting fresh")
			var bdir: DirAccess = DirAccess.open(save_path.get_base_dir())
			if bdir != null:
				bdir.copy(save_path, save_path + ".corrupt")
	if not loaded:
		_new_game()
	_catch_up()
	_visit = {}
	_plan_visit(BOOT_VISIT_DELAY)
	if autosave:
		save()


## Wipe everything and start a brand-new game (also used by tests).
func start_new_game() -> void:
	_reset_state()
	_new_game()
	_visit = {}
	_plan_visit(BOOT_VISIT_DELAY)


# ------------------------------------------------------------------ internals

func _reset_state() -> void:
	_counter = []
	_shelf = []
	_matched = []
	_discovered = {}
	_met = {}
	_owner_matches = {}
	_reputation = 0
	_coins = 0
	_arrival_index = 0
	_arrival_anchor = Clock.now()
	_last_seen = Clock.now()
	_visit_count = 0
	_last_owner = ""
	_visit = {}
	_dirty = false


func _new_game() -> void:
	_arrival_anchor = Clock.now()
	for i in 3:
		_spawn_arrival(Clock.now())
	_dirty = true


func _tick() -> void:
	_catch_up()
	_update_visit()
	if _dirty and autosave:
		save()


## Offline/online arrivals: 1 per ARRIVAL_INTERVAL, at most ARRIVAL_CAP per catch-up.
@warning_ignore("integer_division")
func _catch_up() -> void:
	var t: int = Clock.now()
	if t < _arrival_anchor:
		_arrival_anchor = t   # device clock went backwards; never go negative
		return
	var due: int = (t - _arrival_anchor) / ARRIVAL_INTERVAL
	if due <= 0:
		return
	var n: int = mini(due, ARRIVAL_CAP)
	var spawned: int = 0
	var stalled: bool = false
	for k in n:
		if not _spawn_arrival(_arrival_anchor + (k + 1) * ARRIVAL_INTERVAL):
			stalled = true   # counter full or nothing left to find
			break
		spawned += 1
	if stalled or due > n:
		_arrival_anchor = t  # leftover time does not accumulate beyond the cap
	else:
		_arrival_anchor += spawned * ARRIVAL_INTERVAL


func _spawn_arrival(at: int) -> bool:
	if _counter.size() >= MAX_COUNTER:
		return false
	var pool: Array = _arrival_pool()
	if pool.is_empty():
		return false
	var pick_id: String = ""
	if _arrival_index == 0 and pool.has(STARTER_ID):
		pick_id = STARTER_ID
	else:
		var h: int = Clock.hash_str("%s:%d" % [Clock.date_string(at), _arrival_index])
		pick_id = pool[h % pool.size()]
	_arrival_index += 1
	_counter.append({"id": pick_id, "arrived_at": at, "revealed": []})
	_discovered[pick_id] = true
	_dirty = true
	Events.object_arrived.emit(_view(_counter[_counter.size() - 1]))
	return true


## Objects that may still arrive: not on the counter, shelf, or already returned.
func _arrival_pool() -> Array:
	var taken: Dictionary = {}
	for e in _counter:
		taken[e["id"]] = true
	for e in _shelf:
		taken[e["id"]] = true
	for m in _matched:
		taken[m] = true
	var pool: Array = []
	for o in Content.objects:
		var obj: Dictionary = o
		if not taken.has(obj["id"]):
			pool.append(obj["id"])
	pool.sort()
	return pool


func _update_visit() -> void:
	if _visit.is_empty():
		_plan_visit(NEXT_VISIT_DELAY)
		return
	if _visit.get("present", false):
		return
	if Clock.now() < int(_visit["at"]):
		return
	var wanted: String = _visit["wanted_item_id"]
	if _entry(wanted).is_empty():
		_visit = {}
		return
	var oid: String = _visit["owner_id"]
	var own: Dictionary = Content.owner_by_id(oid)
	if own.is_empty():
		_visit = {}
		return
	_visit["present"] = true
	_met[oid] = true
	_last_owner = oid
	_dirty = true
	Events.owner_arrived.emit(own.duplicate(true), wanted)


## Choose who comes next from what is on the counter and shelf (deterministic).
func _plan_visit(delay: int) -> void:
	var by_owner: Dictionary = {}
	for arr in [_counter, _shelf]:
		for e in arr:
			var obj: Dictionary = Content.object_by_id(e["id"])
			var oid: String = obj.get("owner_id", "")
			if oid == "" or not Content.has_owner(oid):
				continue
			if not by_owner.has(oid):
				by_owner[oid] = []
			by_owner[oid].append(e["id"])
	if by_owner.is_empty():
		_visit = {}
		return
	var ids: Array = by_owner.keys()
	ids.sort()
	if ids.size() > 1 and ids.has(_last_owner):
		ids.erase(_last_owner)
	var h: int = Clock.hash_str("%s:visit:%d" % [Clock.date_string(), _visit_count])
	var oid_pick: String = ids[h % ids.size()]
	var items: Array = by_owner[oid_pick]
	items.sort()
	var wanted: String = items[(h >> 3) % items.size()]
	# Very first visit of a new game: the owner of the starter item, so the tutorial is gentle.
	if _visit_count == 0 and _matched.is_empty() and _entry(STARTER_ID).size() > 0:
		var starter_owner: String = Content.object_by_id(STARTER_ID).get("owner_id", "")
		if Content.has_owner(starter_owner):
			oid_pick = starter_owner
			wanted = STARTER_ID
	_visit_count += 1
	_visit = {"owner_id": oid_pick, "wanted_item_id": wanted,
		"at": Clock.now() + delay, "present": false}


func _find(arr: Array, item_id: String) -> int:
	for i in arr.size():
		if arr[i]["id"] == item_id:
			return i
	return -1


func _entry(item_id: String) -> Dictionary:
	var i: int = _find(_counter, item_id)
	if i >= 0:
		return _counter[i]
	i = _find(_shelf, item_id)
	if i >= 0:
		return _shelf[i]
	return {}


func _remove_entry(arr: Array, item_id: String) -> bool:
	var i: int = _find(arr, item_id)
	if i < 0:
		return false
	arr.remove_at(i)
	return true


func _view(entry: Dictionary) -> Dictionary:
	var obj: Dictionary = Content.object_by_id(entry["id"])
	if obj.is_empty():
		return {}
	var d: Dictionary = obj.duplicate(true)
	d["revealed"] = (entry.get("revealed", []) as Array).duplicate()
	return d


func _views(arr: Array) -> Array:
	var out: Array = []
	for e in arr:
		var d: Dictionary = _view(e)
		if not d.is_empty():
			out.append(d)
	return out


func _to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": Clock.now(),
		"last_seen": _last_seen,
		"arrival_anchor": _arrival_anchor,
		"arrival_index": _arrival_index,
		"visit_count": _visit_count,
		"last_owner": _last_owner,
		"reputation": _reputation,
		"coins": _coins,
		"counter": _counter,
		"shelf": _shelf,
		"matched": _matched,
		"discovered": _discovered.keys(),
		"met": _met.keys(),
		"owner_matches": _owner_matches,
	}


func _apply(d: Dictionary) -> void:
	var version: int = int(d.get("version", 0))
	if version > SAVE_VERSION:
		push_warning("[GameState] save is from a newer version (%d); loading best effort" % version)
	_arrival_anchor = int(d.get("arrival_anchor", Clock.now()))
	_last_seen = int(d.get("last_seen", Clock.now()))
	_arrival_index = int(d.get("arrival_index", 0))
	_visit_count = int(d.get("visit_count", 0))
	_last_owner = str(d.get("last_owner", ""))
	_reputation = int(d.get("reputation", 0))
	_coins = int(d.get("coins", 0))
	_counter = _clean_entries(d.get("counter", []), "arrived_at")
	_shelf = _clean_entries(d.get("shelf", []), "shelved_at")
	_matched = []
	for m in d.get("matched", []):
		if typeof(m) == TYPE_STRING and Content.has_object(m) and not _matched.has(m):
			_matched.append(m)
	_discovered = {}
	for m in d.get("discovered", []):
		if typeof(m) == TYPE_STRING:
			_discovered[m] = true
	_met = {}
	for m in d.get("met", []):
		if typeof(m) == TYPE_STRING:
			_met[m] = true
	_owner_matches = {}
	var om: Variant = d.get("owner_matches", {})
	if typeof(om) == TYPE_DICTIONARY:
		for k in om:
			_owner_matches[str(k)] = int(om[k])


func _clean_entries(raw: Variant, time_key: String) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	var seen: Dictionary = {}
	for e in raw:
		if typeof(e) != TYPE_DICTIONARY or typeof(e.get("id")) != TYPE_STRING:
			continue
		var id: String = e["id"]
		if not Content.has_object(id) or seen.has(id):
			continue
		seen[id] = true
		var revealed: Array = []
		var raw_rev: Variant = e.get("revealed", [])
		if typeof(raw_rev) == TYPE_ARRAY:
			for c in raw_rev:
				if typeof(c) == TYPE_STRING and not revealed.has(c):
					revealed.append(c)
		out.append({"id": id, time_key: int(e.get(time_key, 0)), "revealed": revealed})
	return out
