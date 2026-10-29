extends SceneTree
## Screenshot runner (A0.5).
## xvfb-run -a godot --rendering-driver opengl3 --resolution 1080x1920 --script tools/shoot.gd
## Reads tests/shots.json (B owns): [{name, scene, setup_calls:[{node?,method,args?}|{autoload,method,args}], wait_frames}]
## Writes docs/screens/<name>_<W>x<H>.png and merges docs/screens/index.json.

const SHOTS_PATH: String = "res://tests/shots.json"
const OUT_DIR: String = "res://docs/screens"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var size: Vector2i = DisplayServer.window_get_size()
	var shots: Array = _load_shots()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var index: Array = _load_index()
	var commit: String = OS.get_environment("GITHUB_SHA").left(7)
	var ok: int = 0
	for shot in shots:
		var name: String = str(shot.get("name", "shot"))
		var ps: Resource = load(str(shot.get("scene", "")))
		if ps == null or not (ps is PackedScene):
			printerr("SHOT FAIL %s: scene missing %s" % [name, str(shot.get("scene", ""))])
			continue
		var inst: Node = (ps as PackedScene).instantiate()
		root.add_child(inst)
		for call in shot.get("setup_calls", []):
			var target: Object = inst
			if call.has("autoload"):
				target = root.get_node_or_null(str(call["autoload"]))
			elif call.has("node"):
				target = inst.get_node_or_null(str(call["node"]))
			if target != null and target.has_method(str(call.get("method", ""))):
				target.callv(str(call["method"]), call.get("args", []))
			else:
				printerr("SHOT WARN %s: setup call target/method missing %s" % [name, str(call)])
		for i in range(int(shot.get("wait_frames", 30))):
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var fname: String = "%s_%dx%d.png" % [name, size.x, size.y]
		var err: int = img.save_png(ProjectSettings.globalize_path(OUT_DIR + "/" + fname))
		if err == OK:
			ok += 1
			_upsert(index, {"name": name, "size": "%dx%d" % [size.x, size.y], "file": fname, "commit": commit})
		else:
			printerr("SHOT FAIL %s: save error %d" % [name, err])
		inst.queue_free()
		await process_frame
	var f: FileAccess = FileAccess.open(OUT_DIR + "/index.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(index, " "))
	print("shoot: %d/%d shots at %dx%d" % [ok, shots.size(), size.x, size.y])
	quit(0 if ok == shots.size() else 1)


func _load_shots() -> Array:
	if not FileAccess.file_exists(SHOTS_PATH):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHOTS_PATH))
	return data if typeof(data) == TYPE_ARRAY else []


func _load_index() -> Array:
	var p: String = OUT_DIR + "/index.json"
	if not FileAccess.file_exists(p):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return data if typeof(data) == TYPE_ARRAY else []


func _upsert(index: Array, entry: Dictionary) -> void:
	for i in range(index.size()):
		if index[i].get("file", "") == entry["file"]:
			index[i] = entry
			return
	index.append(entry)
