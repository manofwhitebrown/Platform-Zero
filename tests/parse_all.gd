extends SceneTree
## Parse-check every .gd in the project (A6.0). A parse error anywhere fails the build.
##   godot --headless --script tests/parse_all.gd
const SKIP_DIRS: Array = [".godot", ".git", "docs", "build", "dashboard"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # autoloads must exist before scripts that name them can compile
	var bad: Array = []
	var n: int = _walk("res://", bad)
	for b in bad:
		printerr("PARSE FAIL: %s" % b)
	print("parse_all: %d scripts, %d failed" % [n, bad.size()])
	quit(1 if bad.size() > 0 else 0)


func _walk(dir: String, bad: Array) -> int:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return 0
	var n: int = 0
	for sub in d.get_directories():
		if sub in SKIP_DIRS:
			continue
		n += _walk(dir.path_join(sub), bad)
	for fn in d.get_files():
		if not fn.ends_with(".gd"):
			continue
		var path: String = dir.path_join(fn)
		n += 1
		var sc: Resource = load(path)
		if sc == null or not (sc is GDScript) or not (sc as GDScript).can_instantiate():
			bad.append(path)
	return n
