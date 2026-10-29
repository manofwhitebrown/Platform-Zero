extends RefCounted
## Sim tests (A0.6 / A1.x). Called from tests/run_tests.gd; returns the failure count.
## Uses its own save path and never autosaves, so it cannot touch a real save.

var fails: int = 0
var _sim: Node
var _said: Array = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("TEST FAIL: " + msg)


func run(root: Node) -> int:
	_sim = root.get_node("Sim")
	_sim.save_path = "user://test_save_v2.json"
	_sim.autosave = false
	var ev: Node = root.get_node("Events")
	ev.passenger_said.connect(func(pid: String, line: String) -> void: _said.append({"pid": pid, "line": line}))
	_test_first_minute()
	_test_determinism()
	_test_claimants_solvable()
	_test_save_roundtrip()
	_test_corrupt_save()
	_test_tutorial_lock()
	_test_v1_migration()
	return fails


# ---- section 12 fun checks: fresh install, scripted player ----
func _test_first_minute() -> void:
	_sim.new_game(777)
	_said.clear()
	var t: float = 0.0
	var t_walk: float = -1.0
	var t_speak: float = -1.0
	var t_hand: float = -1.0
	var t_deliver: float = -1.0
	var gap: float = 0.0
	var max_gap: float = 0.0
	var next_act: float = 0.0
	var iid: String = ""
	var bram: String = ""
	while t < 240.0:
		_sim.tick(0.5)
		t += 0.5
		for p in _sim.get_passengers():
			if p["kind"] == "claimant" and p["owner_id"] == "own_001":
				bram = String(p["pid"])
				if t_walk < 0.0 and p["state"] == "walking":
					t_walk = t
		if t_speak < 0.0 and not _said.is_empty():
			t_speak = t
		if _sim.get_highlights().is_empty():
			gap += 0.5
			max_gap = maxf(max_gap, gap)
		else:
			gap = 0.0
		if t_deliver < 0.0 and t >= next_act and t_speak > 0.0:
			next_act = t + 1.5
			var tut: Dictionary = _sim.get_tutorial()
			match String(tut["stage"]):
				"find_item":
					var r: Dictionary = _sim.pick_up(String(tut["target_spot"]))
					if r["ok"]:
						iid = String(r["iid"])
						t_hand = t
				"to_bench":
					_sim.place_on_bench(iid)
				"examine":
					for tool in ["magnifier", "nose", "lamp", "brush", "ear"]:
						if not (_sim.get_item(iid)["clues_known"] as Array).is_empty():
							break
						_sim.reveal(iid, tool)
				"hand_over":
					var front: Dictionary = {}
					for p in _sim.get_passengers():
						if p["pid"] == bram:
							front = p
					if not front.is_empty() and front["state"] == "waiting":
						var res: Dictionary = _sim.hand_over(iid, bram)
						_check(bool(res["correct"]), "first hand-over should be correct")
						t_deliver = t
	_check(t_walk > 0.0 and t_walk <= 20.0, "claimant walking within 20 s (got %.1f)" % t_walk)
	_check(t_speak > 0.0 and t_speak <= 30.0, "claimant speaking within 30 s (got %.1f)" % t_speak)
	_check(t_hand > 0.0 and t_hand <= 60.0, "item in hand within 60 s (got %.1f)" % t_hand)
	_check(t_deliver > 0.0 and t_deliver <= 180.0, "first correct handover within 3 min (got %.1f)" % t_deliver)
	_check(max_gap <= 8.0, "never more than 8 s with nothing highlighted (max %.1f)" % max_gap)
	_check(_sim.tokens > 0 and _sim.rep > 0, "delivery pays tokens and reputation")
	print("sim first minute: walk %.1fs speak %.1fs hand %.1fs deliver %.1fs maxgap %.1fs" % [t_walk, t_speak, t_hand, t_deliver, max_gap])


func _signature() -> String:
	var ids: Array = []
	for it in _sim.get_items_at("spot"):
		ids.append(String(it["def_id"]) + "@" + String(it["spot_id"]))
	ids.sort()
	return "%d|%s|%d" % [_sim.stop_index, ",".join(ids), _sim.get_passengers().size()]


func _test_determinism() -> void:
	_sim.new_game(4242)
	_sim.tick(1500.0)
	var a: String = _signature()
	_sim.new_game(4242)
	_sim.tick(1500.0)
	var b: String = _signature()
	_check(a == b, "same seed must give the same world (%s vs %s)" % [a, b])
	_sim.new_game(4243)
	_sim.tick(1500.0)
	_check(_signature() != a, "different seed should differ")


func _test_claimants_solvable() -> void:
	_sim.new_game(99)
	var bad: int = 0
	var seen_claimants: int = 0
	for i in range(1200):
		_sim.tick(1.0)
		for p in _sim.get_passengers():
			if p["kind"] == "ambient":
				continue
			seen_claimants += 1
			var found: bool = false
			for it in _sim.get_items_at("spot") + _sim.get_items_at("carried") + _sim.get_items_at("bench") + _sim.get_items_at("shelf"):
				if it["def_id"] == p["wants_item_def"]:
					found = true
			if not found:
				bad += 1
	_check(seen_claimants > 0, "claimants should appear over 20 minutes")
	_check(bad == 0, "every claimant's item must exist somewhere (%d unsolvable ticks)" % bad)
	_check(_sim.get_queue().size() <= 6, "queue stays within 6")


func _test_save_roundtrip() -> void:
	_sim.new_game(31337)
	var guard: int = 0
	while guard < 4000:
		_sim.tick(1.0)
		guard += 1
		if _sim.get_queue().size() >= 1 and _sim.get_train()["state"] == "stopped":
			break
	_check(_sim.get_queue().size() >= 1, "reached a mid-queue state to save")
	_check(_sim.save_game(), "save_game succeeds")
	var before: Dictionary = _sim.to_dict()
	var q_before: Array = _sim.get_queue()
	_sim.new_game(1)
	_check(_sim.load_game(), "load_game succeeds")
	var after: Dictionary = _sim.to_dict()
	for key in ["tokens", "rep", "stop_index", "queue", "next_iid", "next_pid", "first_delivery_done", "rng_state"]:
		_check(JSON.stringify(before[key]) == JSON.stringify(after[key]), "round-trip keeps " + key)
	_check(JSON.stringify(before["items"]) == JSON.stringify(after["items"]), "round-trip keeps items")
	_check(JSON.stringify(before["passengers"]) == JSON.stringify(after["passengers"]), "round-trip keeps passengers")
	_check(JSON.stringify(_sim.get_queue()) == JSON.stringify(q_before), "queue order preserved")
	_sim.tick(30.0)


func _test_corrupt_save() -> void:
	var f: FileAccess = FileAccess.open("user://test_save_v2.json", FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	_check(not _sim.load_game(), "corrupt save is rejected, not crashed")
	f = FileAccess.open("user://test_save_v2.json", FileAccess.WRITE)
	f.store_string("")
	f.close()
	_check(not _sim.load_game(), "empty save is rejected, not crashed")
	_sim.new_game(5)
	_sim.tick(10.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save_v2.json"))


func _test_tutorial_lock() -> void:
	_sim.new_game(8)
	var r: Dictionary = _sim.player_move_to(7000.0)
	_check(float(r["target_x"]) <= _sim.get_door_x() + 1.0, "player is held in the Lost Property car until the first delivery")
	_sim.skip_tutorial()
	r = _sim.player_move_to(7000.0)
	_check(float(r["target_x"]) > _sim.get_door_x(), "player can roam after the tutorial")


func _test_v1_migration() -> void:
	var old_v1: String = _sim.v1_save_path
	var old_v2: String = _sim.save_path
	_sim.v1_save_path = "user://test_v1_save.json"
	_sim.save_path = "user://test_no_v2_save.json"
	var f: FileAccess = FileAccess.open(_sim.v1_save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "coins": 42, "reputation": 12, "matched": ["obj_001", "obj_004"], "owner_matches": {"own_001": 1}}))
	f.close()
	_check(_sim.load_game(), "v1 save migrates")
	_check(_sim.tokens == 42 and _sim.rep == 12, "v1 tokens/rep carried over")
	_check(int(_sim.get_player()["tier"]) == 1, "v1 reputation maps to tier 1")
	_check(_sim.tutorial_done and _sim.first_delivery_done, "migrated players skip the tutorial")
	_check(_sim.get_ledger()["catalog"].has("obj_001"), "v1 delivered items land in the catalog")
	var sleeper_open: bool = false
	for c in _sim.get_cars():
		if c["id"] == "car_sleep":
			sleeper_open = bool(c["unlocked"])
	_check(sleeper_open, "tier 1 unlocks the sleeper car")
	_sim.tick(60.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_sim.v1_save_path))
	_sim.v1_save_path = old_v1
	_sim.save_path = old_v2
