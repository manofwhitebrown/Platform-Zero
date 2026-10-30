extends SceneTree
## A6.10 end-to-end: boots the real main scene, plays find -> bench -> interview -> hand over,
## refuses an imposter, saves/reloads, runs offline progress and the daily. CI also greps the log
## for SCRIPT ERROR / Parse Error lines after this runs.
## godot --headless --script tests/e2e.gd

var fails: int = 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("E2E FAIL: " + msg)


func _wait(n: int) -> void:
	for i in range(n):
		await process_frame


func _run() -> void:
	await process_frame
	var sim: Node = root.get_node("Sim")
	sim.save_path = "user://e2e_save_v2.json"
	sim.autosave = false
	sim.new_game(7)
	var scene: PackedScene = load("res://ui/game_root.tscn")
	_check(scene != null, "game_root.tscn loads")
	if scene == null:
		quit(1)
		return
	var gr: Node = scene.instantiate()
	root.add_child(gr)
	await _wait(10)
	_check(is_instance_valid(gr) and gr.get_script() != null, "game root boots with its script")
	sim.new_game(7)  # a fresh game under the live UI
	await _wait(5)

	# --- first minute: Bram + the red mitten (skipped quickly, then played by hand)
	var first: Dictionary = sim.pick_up("car_lp_s3")
	_check(bool(first.get("ok", false)), "pick up the first item")
	var iid0: String = String(first.get("iid", ""))
	_check(bool(sim.place_on_bench(iid0).get("ok", false)), "place on bench")
	for tool in ["magnifier", "lamp", "ear", "nose", "brush"]:
		sim.reveal(iid0, tool)
	await _wait(3)
	var bram: Dictionary = {}
	for i in range(400):
		sim.tick(1.0)
		bram = sim._front_claimant()
		if not bram.is_empty() and String(bram["state"]) == "waiting":
			break
	_check(not bram.is_empty() and String(bram["state"]) == "waiting", "a claimant arrives and waits")
	if not bram.is_empty():
		var pid: String = String(bram["pid"])
		for q in [0, 1, 2]:
			var a: Dictionary = sim.ask(pid, q)
			_check(bool(a.get("ok", false)), "ask %d answers" % q)
		sim.take_from_bench(iid0)
		var t0: int = sim.tokens
		var res: Dictionary = sim.hand_over(iid0, pid)
		_check(bool(res.get("ok", false)) and bool(res.get("correct", false)), "hand over the right item")
		_check(sim.tokens > t0, "tokens were paid")
	await _wait(3)

	# --- a regular claimant at tier 0, played from the wanted def
	sim.skip_tutorial()
	var delivered: int = 0
	for i in range(900):
		sim.tick(1.0)
		var front: Dictionary = sim._front_claimant()
		if front.is_empty():
			sim.call_next()
			continue
		if String(front["state"]) != "waiting":
			continue
		var want: String = String(front.get("wants_item_def", ""))
		var found: Dictionary = {}
		for it in sim._items.values():
			if String(it["def_id"]) == want and String(it["loc"]) in ["spot", "shelf", "bench", "carried"]:
				found = it
		if found.is_empty():
			sim.refuse(String(front["pid"]))
			continue
		if String(found["loc"]) == "spot":
			sim.pick_up(String(found["spot_id"]))
		if String(found["loc"]) != "bench":
			sim.place_on_bench(String(found["iid"]))
		for tool in ["magnifier", "lamp"]:
			sim.reveal(String(found["iid"]), tool)
		sim.ask(String(front["pid"]), 1)
		sim.take_from_bench(String(found["iid"]))
		var r2: Dictionary = sim.hand_over(String(found["iid"]), String(front["pid"]))
		if bool(r2.get("correct", false)):
			delivered += 1
			break
	_check(delivered >= 1, "a normal claimant is served end to end")

	# --- imposter refusal
	var imp: Dictionary = sim.spawn_imposter("", true)
	if imp.is_empty():
		_check(false, "an imposter can be spawned")
	else:
		var t1: int = sim.tokens
		var rr: Dictionary = sim.refuse(String(imp["pid"]))
		_check(bool(rr.get("was_imposter", false)) and sim.tokens > t1, "refusing an imposter pays a bonus")
	await _wait(3)

	# --- save / reload
	var tokens_before: int = sim.tokens
	var rep_before: int = sim.rep
	_check(sim.save_game(), "save_game succeeds")
	sim.new_game(99)
	_check(sim.load_game(), "load_game succeeds")
	_check(sim.tokens == tokens_before and sim.rep == rep_before, "save round-trips tokens and rep")
	var stats: Dictionary = sim.get_stats()
	_check(int(stats["handovers"]) >= 2 and int(stats["imposters_caught"]) >= 1, "stats were counted and saved")

	# --- offline progress
	var rpt: Dictionary = sim.apply_offline(3 * 3600)
	_check(int(rpt.get("stops", 0)) > 0, "offline progress advances stops")
	_check(not sim.last_offline_report.is_empty(), "last_offline_report is set")
	await _wait(3)

	# --- daily
	var day: String = sim.daily_date()
	var d: Dictionary = sim.start_daily(day)
	_check(not d.is_empty(), "daily starts")
	await _wait(5)

	gr.queue_free()
	await _wait(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://e2e_save_v2.json"))
	print("e2e: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
