# Unclaimed
Idle narrative-deduction game: run a magical train station's lost-and-found. Godot 4.3, GDScript, Android via GitHub Actions.

- `autoload/` engine singletons (Events, Content, GameState, Mystery, Clock)
- `content/` objects.json (engine) and owners.json (front)
- `tests/run_tests.gd` headless tests: `godot --headless --script tests/run_tests.gd`
- `tools/validate_content.py` content validation
