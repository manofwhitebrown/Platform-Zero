extends Node
## Game logic (STUB: mock data in contract shapes).

var _counter: Array = []
var _shelf: Array = []
var _revealed: Dictionary = {}
var _reputation: int = 0

func _ready() -> void:
	for o in Content.objects:
		_counter.append(o.duplicate(true))

func get_counter_items() -> Array:
	var out: Array = []
	for it in _counter:
		var d: Dictionary = it.duplicate(true)
		d["revealed"] = _revealed.get(it["id"], [])
		out.append(d)
	return out

func get_shelf_items() -> Array:
	return _shelf.duplicate(true)

func inspect(item_id: String) -> Dictionary:
	var item: Dictionary = Content.get_object(item_id)
	if item.is_empty():
		return {}
	var rev: Array = _revealed.get(item_id, [])
	for c in item["clues"]:
		if not rev.has(c["id"]):
			rev.append(c["id"])
			_revealed[item_id] = rev
			Events.clue_revealed.emit(item_id, c)
			return c
	return {}

func try_match(item_id: String, owner_id: String) -> Dictionary:
	var item: Dictionary = Content.get_object(item_id)
	var owner: Dictionary = Content.get_owner(owner_id)
	var ok: bool = not item.is_empty() and item["owner_id"] == owner_id
	var reward: int = 10 if ok else 0
	if ok:
		_reputation += 1
	Events.match_result.emit(item_id, owner_id, ok, reward)
	Events.reputation_changed.emit(_reputation, get_tier())
	return {"correct": ok, "reward": reward,
		"story": item.get("story", "") if ok else "",
		"line": owner.get("thanks_line", "") if ok else owner.get("wrong_line", "")}

func get_current_owner() -> Dictionary:
	return Content.owners[0] if not Content.owners.is_empty() else {}

func get_reputation() -> int:
	return _reputation

func get_tier() -> int:
	return 0

func get_catalog() -> Array:
	var out: Array = []
	for o in Content.objects:
		var d: Dictionary = o.duplicate(true)
		d["discovered"] = true
		out.append(d)
	return out

func get_gallery() -> Array:
	var out: Array = []
	for o in Content.owners:
		var d: Dictionary = o.duplicate(true)
		d["met"] = true
		d["matches"] = 0
		out.append(d)
	return out

func save() -> void:
	pass

func load_game() -> void:
	pass
