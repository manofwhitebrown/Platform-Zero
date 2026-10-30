extends Node
## Content loader: reads objects.json + owners.json, indexes by id,
## and collects a list of warnings for bad references.

const DEFAULT_OBJECTS_PATH: String = "res://content/objects.json"
const DEFAULT_OWNERS_PATH: String = "res://content/owners.json"
const DEFAULT_DIALOGUE_PATH: String = "res://content/dialogue.json"
const DEFAULT_BARKS_PATH: String = "res://content/barks.json"
const DEFAULT_NAMES_PATH: String = "res://content/names.json"
const GENERATED_PATH: String = "res://content/generated.json"

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

## Writing (A3.5): interview templates, one-liners, name pools. See each file's _doc.
var dialogue: Dictionary = {}
var barks: Dictionary = {}
var shop: Dictionary = {}
var economy: Dictionary = {}
var arcs: Dictionary = {}
var names: Dictionary = {}

## Procedural items/owners (A3.1, content/generated.json). Indexed for lookups but kept out of
## `objects`/`owners` so handwritten content stays the primary pool.
var generated_objects: Array = []
var generated_owners: Array = []
var objects: Array = []
var owners: Array = []
## Human-readable problems found while loading (also sent to push_warning).
var warnings: Array = []
var lore: Array = []

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
	dialogue = _load_dict(DEFAULT_DIALOGUE_PATH)
	barks = _load_dict(DEFAULT_BARKS_PATH)
	shop = _load_dict("res://content/shop.json")
	economy = _load_dict("res://content/economy.json")
	arcs = (_load_dict("res://content/arcs.json").get("arcs", {}) as Dictionary)
	names = _load_dict(DEFAULT_NAMES_PATH)
	lore = (_load_dict("res://content/lore.json").get("lore", []) as Array)
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
	_load_generated()
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


func _load_generated() -> void:
	generated_objects = []
	generated_owners = []
	if objects_path != DEFAULT_OBJECTS_PATH:
		return  # test fixtures: no generated content
	var d: Dictionary = _load_dict(GENERATED_PATH)
	for o in d.get("objects", []):
		if typeof(o) == TYPE_DICTIONARY and o.has("id") and not _object_index.has(o["id"]):
			generated_objects.append(o)
			_object_index[o["id"]] = o
	for w in d.get("owners", []):
		if typeof(w) == TYPE_DICTIONARY and w.has("id") and not _owner_index.has(w["id"]):
			generated_owners.append(w)
			_owner_index[w["id"]] = w


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


func _load_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json: JSON = JSON.new()
	var data: Variant = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	if typeof(data) != TYPE_DICTIONARY:
		_warn("%s is not a valid JSON object" % path)
		return {}
	return data


## Walk nested dictionaries: Content.lines(["barks","thanks","calm"]) style helper.
## root is "dialogue" or "barks"; returns [] when the path does not exist.
func lines(root: String, path: Array) -> Array:
	var node: Variant = dialogue if root == "dialogue" else (barks if root == "barks" else names)
	for key in path:
		if typeof(node) != TYPE_DICTIONARY or not (node as Dictionary).has(key):
			return []
		node = node[key]
	return node if typeof(node) == TYPE_ARRAY else []


func _warn(msg: String) -> void:
	warnings.append(msg)
	if log_warnings:
		push_warning("[Content] " + msg)


## Minimal objects used only until content/objects.json exists.


## Arc beat for an owner's nth delivery, or {}.
func arc_beat(owner_id: String, nth: int) -> Dictionary:
	for b in arcs.get(owner_id, []):
		if int(b.get("at", 0)) == nth:
			return b
	return {}
