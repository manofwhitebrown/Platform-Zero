extends SceneTree
## C2: every id in audio/manifest.json must point at files that exist and load.
## Run: godot --headless --script tests/audio_tests.gd   (A: wire into CI when convenient)

func _init() -> void:
	var fails := 0
	var f := FileAccess.open("res://audio/manifest.json", FileAccess.READ)
	if f == null:
		printerr("TEST FAIL: audio/manifest.json missing")
		quit(1)
		return
	var man: Variant = JSON.parse_string(f.get_as_text())
	if not (man is Dictionary):
		printerr("TEST FAIL: manifest is not a dictionary")
		quit(1)
		return
	for id in (man as Dictionary).keys():
		var e: Dictionary = man[id]
		for k in ["file", "bus", "volume_db", "loop", "variants"]:
			if not e.has(k):
				printerr("TEST FAIL: %s lacks key %s" % [id, k])
				fails += 1
		for path in e.get("variants", []):
			if not ResourceLoader.exists(String(path)) or load(String(path)) == null:
				printerr("TEST FAIL: %s file does not load: %s" % [id, path])
				fails += 1
	print("audio ids: %d, failures: %d" % [(man as Dictionary).size(), fails])
	quit(1 if fails > 0 else 0)
