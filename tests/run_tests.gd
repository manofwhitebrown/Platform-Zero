extends SceneTree
## Headless test runner: godot --headless --script tests/run_tests.gd
## A-C3: loads EVERY script and scene, instantiates every scene, checks every autoload.

const AUTOLOADS: PackedStringArray = ["Events", "Clock", "Content", "GameState", "Mystery", "Sim", "Cheats"]
const SKIP_DIRS: PackedStringArray = [".godot", ".git", "tests", "build", "generated"]

var failures: int = 0


func _init() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	failures += 1
	printerr("TEST FAIL: " + msg)


func _run() -> void:
	await process_frame
	_check_autoloads()
	var scripts: Array = []
	var scenes: Array = []
	_collect("res://", scripts, scenes)
	for path in scripts:
		var s: Resource = load(path)
		if s == null or not (s is GDScript) or not (s as GDScript).can_instantiate():
			_fail("script does not compile: " + str(path))
	for path in scenes:
		var ps: Resource = load(path)
		if ps == null or not (ps is PackedScene):
			_fail("scene does not load: " + str(path))
			continue
		var inst: Node = (ps as PackedScene).instantiate()
		if inst == null:
			_fail("scene does not instantiate: " + str(path))
			continue
		root.add_child(inst)
		await process_frame
		inst.queue_free()
		await process_frame
	print("tests: loaded %d scripts, %d scenes" % [scripts.size(), scenes.size()])
	_check_sim_basics()
	var st: GDScript = load("res://tests/sim_tests.gd")
	if st != null and st.can_instantiate():
		failures += st.new().run(root)
	else:
		_fail("tests/sim_tests.gd does not compile")
	print("tests: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _check_autoloads() -> void:
	for n in AUTOLOADS:
		if not root.has_node(n):
			_fail("autoload missing: " + n)


func _collect(dir_path: String, scripts: Array, scenes: Array) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for sub in d.get_directories():
		if SKIP_DIRS.has(sub):
			continue
		_collect(dir_path.path_join(sub), scripts, scenes)
	for f in d.get_files():
		var full: String = dir_path.path_join(f)
		if f.ends_with(".gd"):
			scripts.append(full)
		elif f.ends_with(".tscn"):
			scenes.append(full)


func _check_sim_basics() -> void:
	if not root.has_node("Sim"):
		return
	var sim: Node = root.get_node("Sim")
	if sim.get_cars().size() != 6:
		_fail("Sim should expose 6 cars")
	if sim.get_passengers().is_empty():
		_fail("Sim should have passengers")
