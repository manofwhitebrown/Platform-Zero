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
	apply_volumes()
	apply_orientation()
	ProjectSettings.set_setting("unclaimed/reduced_motion", get_bool("reduced_motion", false))

static func get_float(key: String, default: float) -> float:
	_load()
	return float(_cfg.get_value("ui", key, default))

static func set_float(key: String, v: float) -> void:
	_load()
	_cfg.set_value("ui", key, v)
	_cfg.save(PATH)
	if key.begins_with("vol_"):
		apply_volumes()

static func get_str(key: String, default: String) -> String:
	_load()
	return String(_cfg.get_value("ui", key, default))

static func set_str(key: String, v: String) -> void:
	_load()
	_cfg.set_value("ui", key, v)
	_cfg.save(PATH)
	if key == "orientation":
		apply_orientation()

## Sliders (0..1) -> audio buses. Slider 0 also mutes the matching bool keys Audio reads.
static func apply_volumes() -> void:
	var map := {"vol_master": ["Master"], "vol_sfx": ["sfx", "ui"], "vol_ambience": ["ambience"], "vol_music": ["music"]}
	for k in map:
		var v: float = clampf(get_float(String(k), 1.0), 0.0, 1.0)
		for bn in map[k]:
			var bi: int = AudioServer.get_bus_index(String(bn))
			if bi >= 0:
				AudioServer.set_bus_volume_db(bi, linear_to_db(maxf(v, 0.0001)))
	_cfg.set_value("ui", "music", get_float("vol_music", 1.0) > 0.01)
	_cfg.set_value("ui", "ambience", get_float("vol_ambience", 1.0) > 0.01)
	_cfg.set_value("ui", "sound", get_float("vol_master", 1.0) > 0.01)

static func apply_orientation() -> void:
	match get_str("orientation", "auto"):
		"portrait":
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
		"landscape":
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
		_:
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
