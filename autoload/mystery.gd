extends Node
## Daily mystery: derived from the UTC date, so everyone gets the same puzzle.
## 1 item, 3 candidate owners. Fewer clues used = better score. State is persisted
## per day in user://daily.json.

const SAVE_VERSION: int = 1
const EPOCH_DAY: int = 20454   # 2026-01-01 as days since 1970-01-01 -> puzzle #1

## Overridable for tests.
var save_path: String = "user://daily.json"
var autosave: bool = true

var _date: String = ""
var _clues_used: int = 1       # clues the player has seen (the first one is free)
var _guesses: Array = []       # owner ids guessed today, in order
var _solved: bool = false
var _accum: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_sync_day(false)
	call_deferred("_announce")


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 1.0:
		return
	_accum = 0.0
	_sync_day(true)   # midnight (UTC) rollover while the app stays open


# ----------------------------------------------------------------- public API

## {item, owners(3), solved, clues_used, number, date, wrong_guesses, stars}
## `item.clues` holds every clue; show only the first `clues_used` of them.
func get_daily() -> Dictionary:
	_sync_day(false)
	var plan: Dictionary = _plan(_date)
	if plan.is_empty():
		return {"item": {}, "owners": [], "solved": false, "clues_used": 0,
			"number": daily_number(), "date": _date, "wrong_guesses": [], "stars": 0}
	var owners: Array = []
	for oid in plan["owner_ids"]:
		owners.append(Content.owner_by_id(oid).duplicate(true))
	return {
		"item": Content.object_by_id(plan["item_id"]).duplicate(true),
		"owners": owners,
		"solved": _solved,
		"clues_used": _clues_used,
		"number": daily_number(),
		"date": _date,
		"wrong_guesses": _wrong_guesses(plan),
		"stars": _stars(),
	}


## Reveal one more clue (costs score). Returns the new clue, or {} if none left / solved.
func reveal_daily_clue() -> Dictionary:
	_sync_day(false)
	var plan: Dictionary = _plan(_date)
	if plan.is_empty() or _solved:
		return {}
	var clues: Array = Content.object_by_id(plan["item_id"]).get("clues", [])
	if _clues_used >= clues.size():
		return {}
	_clues_used += 1
	_persist()
	return (clues[_clues_used - 1] as Dictionary).duplicate(true)


## Guess the owner. Returns {correct, solved, clues_used, stars, score, share}.
func guess_daily(owner_id: String) -> Dictionary:
	_sync_day(false)
	var plan: Dictionary = _plan(_date)
	if plan.is_empty():
		return {"correct": false, "solved": false, "clues_used": 0, "stars": 0, "score": 0, "share": ""}
	var correct_id: String = Content.object_by_id(plan["item_id"]).get("owner_id", "")
	var valid: bool = (plan["owner_ids"] as Array).has(owner_id)
	if not _solved and valid and not _guesses.has(owner_id):
		_guesses.append(owner_id)
		if owner_id == correct_id:
			_solved = true
			GameState.award_reputation(3 * _stars())
		_persist()
	return {
		"correct": _solved and owner_id == correct_id,
		"solved": _solved,
		"clues_used": _clues_used,
		"stars": _stars(),
		"score": _score(plan),
		"share": share_text(),
	}


## Spoiler-free result line, e.g. "Unclaimed #302 🔎🔎🟥🟩".
func share_text() -> String:
	_sync_day(false)
	var plan: Dictionary = _plan(_date)
	var out: String = "Unclaimed #%d " % daily_number()
	out += "🔎".repeat(_clues_used)
	out += "🟥".repeat(_wrong_guesses(plan).size())
	out += "🟩" if _solved else "❔"
	return out


## Puzzle number: 1 on 2026-01-01, +1 per day.
func daily_number() -> int:
	return Clock.day_number() - EPOCH_DAY + 1


## Forget today's progress (tests / debugging).
func reset() -> void:
	_date = Clock.date_string()
	_clues_used = 1
	_guesses = []
	_solved = false
	_persist()


# ------------------------------------------------------------------ internals

func _announce() -> void:
	Events.daily_ready.emit()


func _sync_day(announce: bool) -> void:
	var today: String = Clock.date_string()
	if today == _date:
		return
	_date = today
	_clues_used = 1
	_guesses = []
	_solved = false
	_persist()
	if announce:
		Events.daily_ready.emit()


## Deterministic plan for a date: the item and its 3 candidate owners (shuffled).
func _plan(date: String) -> Dictionary:
	var item_ids: Array = []
	for o in Content.objects:
		var obj: Dictionary = o
		if obj.has("id") and Content.has_owner(str(obj.get("owner_id", ""))):
			item_ids.append(obj["id"])
	if item_ids.is_empty():
		return {}
	item_ids.sort()
	var item_id: String = item_ids[Clock.hash_str("daily:" + date) % item_ids.size()]
	var correct_id: String = Content.object_by_id(item_id)["owner_id"]
	var others: Array = []
	for w in Content.owners:
		var own: Dictionary = w
		if own["id"] != correct_id:
			others.append(own["id"])
	others.sort()
	var trio: Array = [correct_id]
	for n in 2:
		if others.is_empty():
			break
		var i: int = Clock.hash_str("decoy%d:%s" % [n, date]) % others.size()
		trio.append(others[i])
		others.remove_at(i)
	# Deterministic shuffle so the right answer isn't always in the same slot.
	trio.sort_custom(func(a: String, b: String) -> bool:
		return Clock.hash_str(date + ":" + a) < Clock.hash_str(date + ":" + b))
	return {"item_id": item_id, "owner_ids": trio}


func _wrong_guesses(plan: Dictionary) -> Array:
	var out: Array = []
	if plan.is_empty():
		return out
	var correct_id: String = Content.object_by_id(plan["item_id"]).get("owner_id", "")
	for g in _guesses:
		if g != correct_id:
			out.append(g)
	return out


## 3 stars for solving with 1 clue, 2 with 2, 1 with more. 0 while unsolved.
func _stars() -> int:
	if not _solved:
		return 0
	if _clues_used <= 1:
		return 3
	if _clues_used == 2:
		return 2
	return 1


func _score(plan: Dictionary) -> int:
	if not _solved:
		return 0
	return maxi(10, 100 - 20 * (_clues_used - 1) - 10 * _wrong_guesses(plan).size())


func _persist() -> void:
	if not autosave:
		return
	var text: String = JSON.stringify({
		"version": SAVE_VERSION, "date": _date, "clues_used": _clues_used,
		"guesses": _guesses, "solved": _solved})
	var tmp: String = save_path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("[Mystery] cannot write daily save")
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


func _load() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(save_path)) != OK:
		return
	var d: Variant = json.data
	if typeof(d) != TYPE_DICTIONARY:
		return
	_date = str(d.get("date", ""))
	_clues_used = maxi(1, int(d.get("clues_used", 1)))
	_solved = bool(d.get("solved", false))
	_guesses = []
	var raw: Variant = d.get("guesses", [])
	if typeof(raw) == TYPE_ARRAY:
		for g in raw:
			if typeof(g) == TYPE_STRING and not _guesses.has(g):
				_guesses.append(g)
