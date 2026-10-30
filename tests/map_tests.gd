extends SceneTree
## C14: MapData.build() view-model. Run: godot --headless --script tests/map_tests.gd
## (TO A: add this line to CI next to audio_tests.gd.)

var fails := 0


func _check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("TEST FAIL: " + msg)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var sim: Node = root.get_node("Sim")
	sim.save_path = "user://test_map_save.json"
	sim.autosave = false
	sim.new_game(3)
	sim.skip_tutorial()
	var rows: Array = MapData.build(sim)
	_check(rows.size() == 6, "map has 6 cars")
	_check(String(rows[2]["car_id"]) == "car_lp" and bool(rows[2]["is_player_car"]), "player starts in lost property")
	var here := 0
	for r in rows:
		if bool(r["is_player_car"]):
			here += 1
		_check(String(r["name"]) != "", "car %s has a name" % r["car_id"])
	_check(here == 1, "exactly one car is flagged as the player's")
	var locked: Array = rows.filter(func(r): return not bool(r["unlocked"])).map(func(r): return String(r["car_id"]))
	_check(locked.has("car_sleep") and locked.has("car_obs") and locked.has("car_lug") and locked.size() == 3, "sleeper/obs/luggage locked at rep 0")
	for r in rows:
		if not bool(r["unlocked"]):
			_check(String(r["lock_hint"]) != "" and int(r["tier_rep"]) > 0, "locked car %s has a hint and rep" % r["car_id"])
	sim._add_rep(15)
	rows = MapData.build(sim)
	_check(bool(rows[1]["unlocked"]) and not bool(rows[0]["unlocked"]), "tier 1 opens the sleeper only")
	sim._add_rep(300)
	rows = MapData.build(sim)
	_check(rows.all(func(r): return bool(r["unlocked"])), "high reputation opens every car")
	print("map tests, failures: %d" % fails)
	quit(1 if fails > 0 else 0)
