extends SceneTree
## Screenshot runner (A0.5). Schema is owned by B: tests/shots.json
##   xvfb-run -a godot --rendering-driver opengl3 --script tools/shoot.gd
## Each shot {id, milestone, title, scene, orientation, setup:[{call,args}], frames}.
## setup call forms: "Autoload.method" (args), "wait" (seconds), or a bare method name
## called on the loaded scene (e.g. "tool", "page"). Output: docs/screens/<id>.png + index.json.
## Scenes that do not exist yet are skipped (not failures): B's world arrives later.

const SHOTS_PATH: String = "res://tests/shots.json"
const OUT_DIR: String = "res://docs/screens"
const MAX_WAIT_SEC: float = 12.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var cheats: Node = root.get_node_or_null("Cheats")
	if cheats != null:
		cheats.screenshot_mode = true
	var cfg: Dictionary = _load_cfg()
	var sizes: Dictionary = cfg.get("sizes", {"portrait": [1080, 1920], "landscape": [1920, 1080]})
	var shots: Array = cfg.get("shots", [])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var commit: String = OS.get_environment("GITHUB_SHA").left(7)
	var index: Array = []
	var ok: int = 0
	var skipped: int = 0
	var failed: int = 0
	for shot in shots:
		var id: String = str(shot.get("id", "shot"))
		var scene_path: String = str(shot.get("scene", ""))
		if not ResourceLoader.exists(scene_path):
			print("shoot: SKIP %s (scene not present yet: %s)" % [id, scene_path])
			skipped += 1
			continue
		var ps: Resource = load(scene_path)
		if ps == null or not (ps is PackedScene):
			printerr("SHOT FAIL %s: scene does not load" % id)
			failed += 1
			continue
		var orient: String = str(shot.get("orientation", "portrait"))
		var wh: Array = sizes.get(orient, [1080, 1920])
		root.size = Vector2i(int(wh[0]), int(wh[1]))
		var inst: Node = (ps as PackedScene).instantiate()
		root.add_child(inst)
		await process_frame
		for call in shot.get("setup", []):
			await _do_call(inst, call, id)
		for i in range(int(shot.get("frames", 30))):
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var fname: String = id + ".png"
		if img.save_png(ProjectSettings.globalize_path(OUT_DIR + "/" + fname)) == OK:
			ok += 1
			index.append({"id": id, "file": fname, "title": shot.get("title", id), "milestone": shot.get("milestone", ""), "orientation": orient, "size": "%dx%d" % [wh[0], wh[1]], "commit": commit})
		else:
			printerr("SHOT FAIL %s: could not save png" % id)
			failed += 1
		inst.queue_free()
		await process_frame
	var f: FileAccess = FileAccess.open(OUT_DIR + "/index.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(index, " "))
		f.close()
	print("shoot: %d ok, %d skipped, %d failed" % [ok, skipped, failed])
	quit(1 if failed > 0 else 0)


func _do_call(inst: Node, call: Dictionary, id: String) -> void:
	var name: String = str(call.get("call", ""))
	var args: Array = call.get("args", [])
	if name == "wait":
		var secs: float = minf(float(args[0]) if args.size() > 0 else 1.0, MAX_WAIT_SEC)
		await create_timer(secs).timeout
		return
	var target: Object = inst
	var method: String = name
	if name.contains("."):
		var parts: PackedStringArray = name.split(".", false, 1)
		target = root.get_node_or_null(parts[0])
		method = parts[1]
	if target != null and target.has_method(method):
		target.callv(method, args)
	else:
		printerr("SHOT WARN %s: cannot call %s" % [id, name])


func _load_cfg() -> Dictionary:
	if not FileAccess.file_exists(SHOTS_PATH):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHOTS_PATH))
	return data if typeof(data) == TYPE_DICTIONARY else {}
