extends Node
## Content loader: reads objects.json + owners.json, indexes by id,
## and collects a list of warnings for bad references.

const DEFAULT_OBJECTS_PATH: String = "res://content/objects.json"
const DEFAULT_OWNERS_PATH: String = "res://content/owners.json"

const ICON_KEYS: PackedStringArray = [
	"mitten", "watch", "card", "jar", "umbrella", "key", "glove", "book", "hat", "ring",
	"bag", "scarf", "spectacles", "ticket", "lantern", "doll", "flute", "compass",
	"thermos", "letter", "shoe", "coin", "photo", "music_box",
]
const RARITIES: PackedStringArray = ["common", "odd", "rare"]

## Overridable (tests point these at fixtures, then call reload()).
var objects_path: String = DEFAULT_OBJECTS_PATH
var owners_path: String = DEFAULT_OWNERS_PATH
var log_warnings: bool = true

var objects: Array = []
var owners: Array = []
## Human-readable problems found while loading (also sent to push_warning).
var warnings: Array = []

var _object_index: Dictionary = {}
var _owner_index: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	warnings.clear()
	objects = _load_array(objects_path)
	owners = _load_array(owners_path)
	if objects.is_empty():
		_warn("objects.json missing or empty")
	_rebuild()


## Replace the object list in memory (tests / tools) and reindex.
func set_objects(list: Array) -> void:
	objects = list
	_rebuild()


func _rebuild() -> void:
	_object_index.clear()
	_owner_index.clear()
	for o in objects:
		if typeof(o) != TYPE_DICTIONARY or not o.has("id"):
			_warn("object without id ignored")
			continue
		if _object_index.has(o["id"]):
			_warn("duplicate object id %s" % o["id"])
		_object_index[o["id"]] = o
	for w in owners:
		if typeof(w) != TYPE_DICTIONARY or not w.has("id"):
			_warn("owner without id ignored")
			continue
		if _owner_index.has(w["id"]):
			_warn("duplicate owner id %s" % w["id"])
		_owner_index[w["id"]] = w
	_check_refs()


func object_by_id(id: String) -> Dictionary:
	return _object_index.get(id, {})


func owner_by_id(id: String) -> Dictionary:
	return _owner_index.get(id, {})


## Compatibility alias (front-end currently calls this).
func get_object(id: String) -> Dictionary:
	return object_by_id(id)


func has_object(id: String) -> bool:
	return _object_index.has(id)


func has_owner(id: String) -> bool:
	return _owner_index.has(id)


## Item ids an owner can lose, filtered to ones that really exist.
func lost_items_of(owner_id: String) -> Array:
	var out: Array = []
	var w: Dictionary = owner_by_id(owner_id)
	for iid in w.get("lost_item_ids", []):
		if _object_index.has(iid):
			out.append(iid)
	return out


func _check_refs() -> void:
	for o in objects:
		if typeof(o) != TYPE_DICTIONARY:
			continue
		var oid: String = str(o.get("id", "?"))
		if not _owner_index.has(o.get("owner_id", "")):
			_warn("%s has unknown owner_id %s" % [oid, str(o.get("owner_id", ""))])
		if not ICON_KEYS.has(str(o.get("icon", ""))):
			_warn("%s has invalid icon key %s" % [oid, str(o.get("icon", ""))])
		if not RARITIES.has(str(o.get("rarity", ""))):
			_warn("%s has invalid rarity %s" % [oid, str(o.get("rarity", ""))])
		var n: int = (o.get("clues", []) as Array).size()
		if n < 2 or n > 4:
			_warn("%s has %d clues (expected 2-4)" % [oid, n])
	for w in owners:
		if typeof(w) != TYPE_DICTIONARY:
			continue
		for iid in w.get("lost_item_ids", []):
			if not _object_index.has(iid):
				_warn("owner %s lists missing item %s" % [str(w.get("id", "?")), str(iid)])


func _load_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	var data: Variant = json.data if json.parse(text) == OK else null
	if typeof(data) != TYPE_ARRAY:
		_warn("%s is not a valid JSON array" % path)
		return []
	return data


func _warn(msg: String) -> void:
	warnings.append(msg)
	if log_warnings:
		push_warning("[Content] " + msg)


## Minimal objects used only until content/objects.json exists.
