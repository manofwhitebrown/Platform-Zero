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
	_test_interview()
	_test_imposters()
	_test_ambient()
	_test_state_machine()
	_test_car_unlocks()
	_test_cheat_stub()
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


# ---- A2.3: interview text + imposters ----
func _no_braces(line: String) -> bool:
	return line.strip_edges() != "" and not line.contains("{") and not line.contains("}")


func _test_interview() -> void:
	_sim.new_game(7)
	_sim.tick(12.0)  # Bram arrives at the door and speaks
	var bram: Dictionary = {}
	for p in _sim.get_passengers():
		if p["kind"] == "claimant":
			bram = p
	_check(not bram.is_empty(), "interview test needs a claimant")
	if bram.is_empty():
		return
	var pid: String = String(bram["pid"])
	var q0: Dictionary = _sim.ask(pid, 0)
	_check(bool(q0["ok"]) and _no_braces(String(q0["line"])), "q0 gives a finished line (no placeholders): %s" % q0.get("line", ""))
	var q1: Dictionary = _sim.ask(pid, 1)
	var q2: Dictionary = _sim.ask(pid, 2)
	var def: Dictionary = Content.object_by_id(String(bram["wants_item_def"]))
	var truth: Dictionary = {}
	for c in def["clues"]:
		truth[String(c["attr"])] = String(c["value"])
	for q in [q1, q2]:
		_check(String(q["attr"]) != "" and _no_braces(String(q["line"])), "q1/q2 reveal an attribute: %s" % q.get("line", ""))
		_check(truth.get(String(q["attr"]), "") == String(q["value"]), "an honest claimant never lies about %s" % q.get("attr", ""))
		_check(String(q["line"]).contains(String(q["value"])), "the line states the value: %s" % q.get("line", ""))
	_check(String(q1["attr"]) != String(q2["attr"]), "q1 and q2 reveal different attributes")
	var q3: Dictionary = {}
	for i in range(6):  # a claimant has at most 4 clues to give; after that: a graceful line
		q3 = _sim.ask(pid, 2)
		if String(q3["attr"]) == "":
			break
	_check(String(q3["attr"]) == "" and _no_braces(String(q3["line"])), "nothing left to ask gives a graceful line")
	_check(not bool(_sim.ask("nobody", 0)["ok"]), "asking nobody fails cleanly")


func _test_imposters() -> void:
	var wrong_total: int = 0
	var spawned: int = 0
	for seed_value in range(1, 41):
		_sim.new_game(seed_value)
		_sim.skip_tutorial()
		_sim.tick(400.0)
		var imp: Dictionary = _sim.spawn_imposter("", true)
		if imp.is_empty():
			continue
		spawned += 1
		_check(imp["kind"] == "imposter" and String(imp["name"]) != "", "imposter has a kind and a name")
		_check(_no_braces(String(imp["line"])), "imposter intro is finished text: %s" % imp["line"])
		var hints: Array = imp["imposter_hints"]
		var wrong: int = 0
		for h in hints:
			if bool(h["wrong"]):
				wrong += 1
		_check(hints.size() == 2 and wrong == 1, "imposter has exactly one wrong detail (seed %d: %d of %d)" % [seed_value, wrong, hints.size()])
		wrong_total += wrong
		var def: Dictionary = Content.object_by_id(String(imp["wants_item_def"]))
		var truth: Dictionary = {}
		for c in def["clues"]:
			truth[String(c["attr"])] = String(c["value"])
		var mismatches: int = 0
		for qi in [1, 2]:
			var a: Dictionary = _sim.ask(String(imp["pid"]), qi)
			_check(_no_braces(String(a["line"])), "imposter answer is finished text: %s" % a["line"])
			if truth.get(String(a["attr"]), "") != String(a["value"]):
				mismatches += 1
		_check(mismatches == 1, "asking both questions exposes exactly one lie (seed %d)" % seed_value)
	_check(spawned >= 30, "imposters can be spawned on nearly every seed (%d/40)" % spawned)
	# refuse pays a bonus, a wrong hand-over never pays and the item comes back
	_sim.new_game(11)
	_sim.skip_tutorial()
	_sim.tick(60.0)
	var imp2: Dictionary = _sim.spawn_imposter("", true)
	if not imp2.is_empty():
		var t0: int = _sim.tokens
		var r: Dictionary = _sim.refuse(String(imp2["pid"]))
		_check(bool(r["was_imposter"]) and int(r["tokens"]) > 0 and _sim.tokens > t0, "refusing an imposter earns a bonus")
		_check(_no_braces(String(r["line"])), "refuse line is finished text")
	# tier 2+ games actually produce imposters over time and the queue stays sane
	_sim.new_game(21)
	_sim.skip_tutorial()
	_sim._add_rep(40)
	var saw_imposter: bool = false
	for i in range(3000):
		_sim.tick(1.0)
		for p in _sim.get_passengers():
			if p["kind"] == "imposter":
				saw_imposter = true
			if i % 20 == 0 and p["kind"] != "ambient" and String(p["state"]) != "leaving":
				_sim.refuse(String(p["pid"]))  # keep the claimant cap from filling up
	_check(saw_imposter, "imposters appear in a tier 2+ game within ~50 minutes")
	_check(_sim.get_queue().size() <= 6, "queue stays within 6 with imposters")


# ---- A2.1: ambient passengers ----
func _ambient_list() -> Array:
	var out: Array = []
	for p in _sim.get_passengers():
		if p["kind"] == "ambient":
			out.append(p)
	return out


func _test_ambient() -> void:
	_sim.new_game(31)
	var start: Array = _ambient_list()
	var walkers: int = 0
	for p in start:
		if String(p["role"]) != "":
			walkers += 1
	_check(start.size() - walkers >= 8 and walkers == 2, "fresh train has seated passengers plus conductor and vendor (%d seated, %d walkers)" % [start.size() - walkers, walkers])
	var counters: Dictionary = {"spawned": start.size(), "bad": 0}  # lambdas capture ints by value
	var routines: Dictionary = {}
	var train_ref: Node = _sim
	var on_spawn: Callable = func(p: Dictionary) -> void:
		if p["kind"] == "ambient":
			counters["spawned"] = int(counters["spawned"]) + 1
			if String(train_ref.get_train()["state"]) not in ["stopped", "departing"]:
				counters["bad"] = int(counters["bad"]) + 1
	_sim.get_node("/root/Events").passenger_spawned.connect(on_spawn)
	_sim.get_player()["x"] = float(_sim.get_cars()[3]["x"]) + 800.0
	var dup_slots: int = 0
	var broken_pairs: int = 0
	var cap_breach: int = 0
	var said_before: int = _said.size()
	for i in range(2400):  # 40 minutes
		_sim.tick(1.0)
		if i % 15 == 0:
			var seen_slots: Dictionary = {}
			for p in _ambient_list():
				routines[String(p["routine"])] = true
				if String(p["role"]) == "" and String(p["state"]) == "seated":
					var key: String = String(p["seat_slot"])
					if seen_slots.has(key):
						dup_slots += 1
					seen_slots[key] = true
				var pp: String = String(p.get("partner", ""))
				if pp != "":
					var other: Dictionary = {}
					for q in _ambient_list():
						if q["pid"] == pp:
							other = q
					if other.is_empty() or String(other.get("partner", "")) != String(p["pid"]):
						broken_pairs += 1
			if _ambient_list().size() > 30:
				cap_breach += 1
	_sim.get_node("/root/Events").passenger_spawned.disconnect(on_spawn)
	_check(int(counters["spawned"]) >= 30, "30+ distinct ambient passengers over a run (%d)" % int(counters["spawned"]))
	_check(int(counters["bad"]) == 0, "ambient board only while the doors are open (%d bad)" % int(counters["bad"]))
	_check(dup_slots == 0, "no two seated passengers share a seat (%d)" % dup_slots)
	_check(broken_pairs == 0, "chatting pairs are always mutual (%d)" % broken_pairs)
	_check(cap_breach == 0, "ambient population stays bounded")
	_check(routines.size() >= 4, "at least 4 different routines seen (%s)" % str(routines.keys()))
	var heard: int = 0
	for e in _said.slice(said_before):
		if not String(e["pid"]).begins_with("clm") and not String(e["pid"]).begins_with("imp"):
			heard += 1
			_check(_no_braces(String(e["line"])), "ambient chatter is finished text: %s" % e["line"])
	_check(heard >= 5, "ambient passengers chatter near the player (%d lines)" % heard)
	_check(_sim._amb_ref().drops_total >= 1, "leavers drop items under their seats (%d)" % _sim._amb_ref().drops_total)
	# every seated ambient has distinct look data B can draw
	for p in _ambient_list():
		_check(not (p["look"] as Dictionary).is_empty() and String(p["name"]) != "", "ambient has a name and a look")
	# save round-trip keeps the ambient state
	_sim.save_game()
	var before: String = JSON.stringify(_sim.to_dict()["ambient"])
	_sim.load_game()
	_check(JSON.stringify(_sim.to_dict()["ambient"]) == before, "ambient state survives save/load")
	# perf: 40 passengers
	_sim.new_game(32)
	for c in ["car_pass", "car_dine", "car_sleep", "car_obs"]:
		for i in range(10):
			_sim._amb_ref().spawn_ambient(c)
	var n_amb: int = _ambient_list().size()
	var t0: int = Time.get_ticks_usec()
	for i in range(200):
		_sim.tick(0.5)
	var per_step_us: float = float(Time.get_ticks_usec() - t0) / 200.0
	print("sim perf: %d ambient, %.0f us per 0.5 s step" % [n_amb, per_step_us])
	_check(per_step_us < 1000.0, "sim step under 1 ms at ~40 passengers (%.0f us, %d ambient)" % [per_step_us, n_amb])


# ---- A2.2: claimant state machine, call_next ----
func _walk_states(mood: String) -> Array:
	_sim.new_game(5)
	_sim.skip_tutorial()
	var states: Array = []
	var ev: Node = _sim.get_node("/root/Events")
	var rec: Callable = func(pid: String, st: String) -> void: states.append(st)
	ev.passenger_state_changed.connect(rec)
	var sp: String = _sim._free_spot_id()
	var item: Dictionary = _sim._spawn_item("obj_005", sp)
	item["loc"] = "shelf"
	_sim._set_spot_item(sp, "")
	var p: Dictionary = _sim._spawn_claimant("own_002", "obj_005", false)
	p["mood"] = mood
	var pid: String = String(p["pid"])
	var handed: bool = false
	for i in range(400):
		_sim.tick(0.5)
		if not handed and _sim.get_passengers().any(func(q): return q["pid"] == pid and q["state"] == "waiting"):
			handed = true
			var r: Dictionary = _sim.hand_over(String(item["iid"]), pid)
			_check(bool(r["correct"]), "state-machine claimant takes the right item")
	ev.passenger_state_changed.disconnect(rec)
	_check(not _sim.get_passengers().any(func(q): return q["pid"] == pid), "claimant walks off and is removed (%s)" % mood)
	return states


func _test_state_machine() -> void:
	var calm: Array = _walk_states("calm")
	var shy: Array = _walk_states("shy")
	var grumpy: Array = _walk_states("grumpy")
	for pair in [["calm", calm], ["shy", shy], ["grumpy", grumpy]]:
		var seq: Array = pair[1]
		for must in ["standing_up", "walking", "at_counter", "asking", "waiting", "receiving", "leaving"]:
			_check(seq.has(must), "%s claimant passes through %s (%s)" % [pair[0], must, str(seq)])
	_check(shy.has("hesitating") and not calm.has("hesitating") and not calm.has("knocking"), "shy hesitates at the door, calm walks straight in")
	_check(grumpy.has("knocking"), "grumpy knocks")
	# call_next brings a seated claimant in immediately
	_sim.new_game(6)
	_sim.skip_tutorial()
	var late: Dictionary = _sim._spawn_claimant("own_002", "obj_005", false)
	late["t"] = 500.0
	var r: Dictionary = _sim.call_next()
	_check(String(r["called"]) == String(late["pid"]), "call_next names the claimant it called")
	_sim.tick(2.0)
	_check(String(_sim.get_passengers().filter(func(q): return q["pid"] == late["pid"])[0]["state"]) != "seated", "called claimant stands up")


# ---- A2.4: cars unlock by tier ----
func _test_car_unlocks() -> void:
	_sim.new_game(8)
	_sim.skip_tutorial()
	var got: Array = []
	var ev: Node = _sim.get_node("/root/Events")
	var rec: Callable = func(car_id: String) -> void: got.append(car_id)
	ev.car_unlocked.connect(rec)
	var locked: Array = _sim.get_cars().filter(func(c): return not bool(c["unlocked"])).map(func(c): return c["id"])
	_check(locked.has("car_sleep") and locked.has("car_obs") and locked.has("car_lug"), "sleeper/observation/luggage start locked")
	_sim._add_rep(10)
	_check(got == ["car_sleep"], "tier 1 unlocks the sleeper only (%s)" % str(got))
	_sim._add_rep(20)
	_check(got == ["car_sleep", "car_obs"], "tier 2 unlocks the observation car (%s)" % str(got))
	_sim._add_rep(40)
	_check(got == ["car_sleep", "car_obs", "car_lug"], "tier 3 unlocks the luggage car (%s)" % str(got))
	ev.car_unlocked.disconnect(rec)
	# items only land in unlocked cars; spot kinds differ per car kind
	_sim.new_game(9)
	_sim.tick(1200.0)
	for it in _sim.get_items_at("spot"):
		var car_id: String = String(_sim._car_of_spot(String(it["spot_id"])))
		_check(_sim._car_unlocked(car_id), "items never spawn in locked cars (%s in %s)" % [it["iid"], car_id])
	var kinds: Dictionary = {}
	for sp in _sim.get_spots():
		if sp["car_id"] == "car_dine":
			kinds[sp["kind"]] = true
	_check(kinds.has("table") and not kinds.has("curtain"), "dining car has tables, no curtains")


# ---- stub cheats used by screenshot setups ----
func _test_cheat_stub() -> void:
	var cheats: Node = _sim.get_node("/root/Cheats")
	cheats.screenshot_mode = false
	_check(not bool(cheats.run("trigger_first_minute")["ok"]), "cheats are locked outside screenshot mode")
	cheats.screenshot_mode = true
	_check(not bool(cheats.run("tokens_100")["ok"]), "only the safe subset works in screenshot mode")
	_sim.new_game(3)
	_sim.tick(40.0)
	_check(bool(cheats.run("trigger_first_minute", true)["ok"]), "trigger_first_minute works for screenshots")
	_check(_sim.clock_s < 1.0 and not _sim.first_delivery_done and _sim.get_items_at("spot").size() == 1, "first-minute state is fresh again")
	var before: int = _sim.stop_index
	_check(bool(cheats.run("skip_next_stop", true)["ok"]), "skip_next_stop works for screenshots")
	_check(_sim.stop_index == before + 1 and String(_sim.get_train()["state"]) == "arriving", "skip_next_stop lands on the arriving state")
	cheats.screenshot_mode = false
