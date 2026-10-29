extends SceneTree
## Headless test runner: godot --headless --script tests/run_tests.gd

func _init() -> void:
	var failures: int = 0
	# Real tests arrive in A8.
	print("tests: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
