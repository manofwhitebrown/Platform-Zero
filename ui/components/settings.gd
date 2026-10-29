class_name Settings
extends RefCounted
## B-side UI prefs (reduced motion, sound, haptics, intro seen). Stored separately from A's save file.
const PATH := "user://ui_settings.cfg"
static var _cfg: ConfigFile

static func _load() -> void:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)

static func get_bool(key: String, default: bool) -> bool:
	_load()
	return bool(_cfg.get_value("ui", key, default))

static func set_bool(key: String, v: bool) -> void:
	_load()
	_cfg.set_value("ui", key, v)
	_cfg.save(PATH)
	if key == "reduced_motion":
		ProjectSettings.set_setting("unclaimed/reduced_motion", v)

static func apply_all() -> void:
	ProjectSettings.set_setting("unclaimed/reduced_motion", get_bool("reduced_motion", false))
