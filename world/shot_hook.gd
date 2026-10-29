class_name ShotHook
extends Node
## Headless-friendly screenshot helper. Usage (under xvfb):
##   godot --path . --resolution 1080x1920 res://world/train_world.tscn -- --shot-id=m1_car_portrait --out=/tmp/x.png
## Reads tests/shots.json, runs the shot's setup calls, waits `frames`, saves a PNG, quits.
## Scenes may implement shot_setup(call: String, args: Array) -> void for scene-specific calls.

static func wanted() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-id="):
			return true
	return false


func _ready() -> void:
	_run()


func _arg(name: String, fallback: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return fallback


func _run() -> void:
	var id: String = _arg("shot-id")
	var out: String = _arg("out", "user://shot_%s.png" % id)
	var shot: Dictionary = {}
	var f := FileAccess.open("res://tests/shots.json", FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			for s in (parsed as Dictionary).get("shots", []):
				if s["id"] == id:
					shot = s
	if shot.is_empty():
		push_error("ShotHook: unknown shot id %s" % id)
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var root: Node = get_parent()
	for call in shot.get("setup", []):
		var name: String = String(call["call"])
		var args: Array = call.get("args", [])
		if name == "wait":
			await get_tree().create_timer(float(args[0])).timeout
		elif name.contains("."):
			var parts: PackedStringArray = name.split(".")
			var target: Node = get_node_or_null("/root/%s" % parts[0])
			if target and target.has_method(parts[1]):
				target.callv(parts[1], args)
			else:
				push_warning("ShotHook: cannot call %s" % name)
		elif root.has_method("shot_setup"):
			root.call("shot_setup", name, args)
	for i in range(int(shot.get("frames", 60))):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(out)
	print("ShotHook: saved ", out, " err=", err, " size=", img.get_size())
	get_tree().quit()
