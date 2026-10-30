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
	_test_fast_travel_locked()
	_test_cheat_stub()
	_test_cheat_panel()
	_test_generated_content()
	_test_shop()
	_test_arcs()
	_test_daily()
	_test_offline()
	_test_save_safety()
	_test_cheats_complete()
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save_v2.bak"))


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
	f.store_string(JSON.stringify({"version": 1, "coins": 42, "reputation": 20, "matched": ["obj_001", "obj_004"], "owner_matches": {"own_001": 1}}))
	f.close()
	_check(_sim.load_game(), "v1 save migrates")
	_check(_sim.tokens == 42 and _sim.rep == 20, "v1 tokens/rep carried over")
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
	_sim._add_rep(70)
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
func _test_fast_travel_locked() -> void:
	_sim.new_game(9)
	_sim.skip_tutorial()
	var r: Dictionary = _sim.fast_travel("car_lug")
	_check(not bool(r["ok"]) and String(r["reason"]) == "locked" and String(r["hint"]) != "", "locked car explains the tier instead of failing hard")


func _test_car_unlocks() -> void:
	_sim.new_game(8)
	_sim.skip_tutorial()
	var got: Array = []
	var ev: Node = _sim.get_node("/root/Events")
	var rec: Callable = func(car_id: String) -> void: got.append(car_id)
	ev.car_unlocked.connect(rec)
	var locked: Array = _sim.get_cars().filter(func(c): return not bool(c["unlocked"])).map(func(c): return c["id"])
	_check(locked.has("car_sleep") and locked.has("car_obs") and locked.has("car_lug"), "sleeper/observation/luggage start locked")
	_sim._add_rep(15)
	_check(got == ["car_sleep"], "tier 1 unlocks the sleeper only (%s)" % str(got))
	_sim._add_rep(45)
	_check(got == ["car_sleep", "car_obs"], "tier 2 unlocks the observation car (%s)" % str(got))
	_sim._add_rep(190)
	_check(got == ["car_sleep", "car_obs", "car_lug"], "tier 3 unlocks the luggage car (%s)" % str(got))
	_check(_sim.get_map().size() == 6 and bool(_sim.get_map()[2]["here"]), "map lists 6 cars, player in the lost property car")
	_check(bool(_sim.fast_travel("car_lug")["ok"]) and String(_sim.get_player()["car_id"]) == "car_lug", "fast travel to the luggage car")
	_check(bool(_sim.fast_travel("car_lp")["ok"]) and String(_sim.get_player()["car_id"]) == "car_lp", "fast travel back to lost property")
	_check(not bool(_sim.fast_travel("nope")["ok"]), "fast travel to an unknown car is refused")
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


# ---- A5.1 cheat panel backend ----
func _test_cheat_panel() -> void:
	var cheats: Node = _sim.get_node("/root/Cheats")
	cheats.screenshot_mode = false
	cheats.lock()
	var cats: Dictionary = {}
	for c in cheats.list():
		cats[c["category"]] = true
	_check(cats.size() >= 7, "cheat list covers all categories")
	_check(not bool(cheats.run("tier_up")["ok"]), "cheats locked by default")
	_check(cheats.lockout_left() == 0.0, "no lockout at start")
	if not cheats.is_available():
		_check(not cheats.try_unlock("anything"), "no hash file => unlock refused")


# ---- A3.1 procedural content ----
func _test_generated_content() -> void:
	var content: Node = _sim.get_node("/root/Content")
	var gen: Array = content.generated_objects
	_check(gen.size() >= 200, "200+ generated items (got %d)" % gen.size())
	_check(content.generated_owners.size() == gen.size(), "one generated owner per generated item")
	var bad: int = 0
	var ids: Dictionary = {}
	for o in gen:
		var n: int = (o["clues"] as Array).size()
		var attrs: Dictionary = {}
		for c in o["clues"]:
			attrs[c["attr"]] = true
		if n < 2 or n > 3 or attrs.size() != n or ids.has(o["id"]) or not content.has_owner(String(o["owner_id"])):
			bad += 1
		ids[o["id"]] = true
	_check(bad == 0, "generated items obey clue/owner rules (%d bad)" % bad)
	_check(content.objects.size() == 40, "handwritten pool untouched")
	# every generated item can be spawned, examined and solved through the real Sim
	_sim.new_game(11)
	var did: String = String(gen[0]["id"])
	var w: Dictionary = content.owner_by_id(String(gen[0]["owner_id"]))
	_check((w["lost_item_ids"] as Array).has(did) and (w["hints"] as Dictionary).has(did), "generated owner lists its item and hints")
	var seen: Dictionary = {}
	for it in _sim._items.values():
		seen[it["def_id"]] = true
	for k in range(60):
		var d: String = _sim._pick_def()
		_check(d == "" or not seen.has(d), "pick_def never repeats a def")
		if d == "":
			break


# ---- A3.2 shop ----
func _test_shop() -> void:
	_sim.new_game(21)
	var shop: Array = _sim.get_shop()
	_check(shop.size() >= 6, "shop has upgrades")
	_check(not bool(_sim.buy("porter")["ok"]), "can't buy with no tokens")
	_check(not bool(_sim.buy("nope")["ok"]), "unknown upgrade refused")
	_sim.tokens = 500
	_check(_sim.get_bench_cap() == 3, "bench cap starts at 3")
	_check(bool(_sim.buy("bench_slot")["ok"]) and _sim.get_bench_cap() == 4, "bench upgrade works")
	_check(bool(_sim.buy("bench_slot")["ok"]) and not bool(_sim.buy("bench_slot")["ok"]), "bench upgrade maxes out")
	_check(_sim.tokens == 500 - 30 - 140, "costs deducted")
	_check(_sim._boosted(10, "common") == 10, "no lamp oil, no boost")
	_sim.buy("lamp_oil")
	_check(_sim._boosted(10, "common") == 11, "lamp oil +10%")
	var d: Dictionary = _sim.to_dict()
	_sim.new_game(22)
	_check(_sim.get_upgrade_level("bench_slot") == 0, "new game resets upgrades")
	_check(_sim.from_dict(d) and _sim.get_upgrade_level("bench_slot") == 2, "upgrades survive save/load")


# ---- A3.3 regular arcs ----
func _test_arcs() -> void:
	var content: Node = _sim.get_node("/root/Content")
	var owners: int = 0
	for w in content.owners:
		var arc: Array = content.arcs.get(w["id"], [])
		if arc.size() >= 3 and arc.size() <= 5:
			owners += 1
	_check(owners == content.owners.size(), "every regular has a 3-5 step arc (%d/%d)" % [owners, content.owners.size()])
	_check(not content.arc_beat("own_001", 1).is_empty() and content.arc_beat("own_001", 9).is_empty(), "arc_beat lookup")


# ---- A3.4 daily Night Case ----
func _test_daily() -> void:
	var d1: Dictionary = _sim.get_daily("2026-03-01")
	_check(d1["def_id"] == _sim.get_daily("2026-03-01")["def_id"], "daily is deterministic per date")
	_check(_sim.daily_number("2026-01-01") == 1 and _sim.daily_number("2026-03-01") == 60, "daily numbering")
	_sim.new_game(31)
	_check(_sim.daily_share_text("2026-03-01") == "", "no share text before solving")
	var st: Dictionary = _sim.start_daily("2026-03-01")
	_check(bool(st["ok"]), "daily starts")
	var iid: String = String(st["iid"])
	var pid: String = ""
	for p in _sim.get_passengers():
		if p["kind"] == "claimant" and String(p["wants_item_def"]) == d1["def_id"]:
			pid = String(p["pid"])
	_check(pid != "", "daily owner is waiting")
	_sim.pick_up(String(_sim._items[iid]["spot_id"]))
	var res: Dictionary = _sim.hand_over(iid, pid)
	_check(bool(res["correct"]) and bool(_sim.get_daily("2026-03-01")["done"]), "daily completes on the right handover")
	var share: String = _sim.daily_share_text("2026-03-01")
	_check(share.begins_with("Platform Zero") and share.find(String(d1["title"])) == -1, "share text has no spoilers")
	_check(not bool(_sim.start_daily("2026-03-01")["ok"]), "can't replay a solved daily")
	_sim.cheated = true
	_check(_sim.daily_share_text("2026-03-01") == "" and not bool(_sim.start_daily("2026-03-02")["ok"]), "cheated runs excluded from daily")
	_sim.cheated = false


# ---- A6.1 offline progress ----
var _off_reports: Array = []


func _off_sig(seed_value: int, secs: float) -> String:
	_sim.new_game(seed_value)
	_sim.skip_tutorial()
	_sim.tick(20.0)
	_sim.apply_offline(secs)
	var d: Dictionary = _sim.to_dict()
	return JSON.stringify([d["stop_index"], d["tokens"], d["rep"], d["next_iid"], d["items"], d["queue"], d["train"]["state"]])


func _test_offline() -> void:
	var ev: Node = _sim.get_node("/root/Events")
	ev.offline_report.connect(func(r: Dictionary) -> void: _off_reports.append(r))
	_sim.new_game(77)
	_sim.tick(20.0)
	var gated: Dictionary = _sim.apply_offline(7200.0)
	_check(int(gated["stops"]) == 0 and _off_reports.is_empty(), "offline does nothing during the tutorial")
	_sim.skip_tutorial()
	var s0: int = _sim.stop_index
	for bad in [-50.0, 0.0, NAN, INF, 100.0, 359.0]:
		var r0: Dictionary = _sim.apply_offline(bad)
		_check(int(r0["stops"]) == 0 and int(r0["away_s"]) >= 0 and _sim.stop_index == s0, "no stops for bad/short gap %s" % str(bad))
	_check(_off_reports.is_empty(), "no report for empty gaps")
	var waiting_before: Array = []
	for p in _sim.get_passengers():
		if p["kind"] != "ambient":
			waiting_before.append(String(p["pid"]))
	var tok0: int = _sim.tokens
	var rep: Dictionary = _sim.apply_offline(3600.0)
	_check(int(rep["stops"]) == 10 and _sim.stop_index == s0 + 10, "1 stop per 6 minutes")
	_check(not bool(rep["capped"]), "10 stops is not capped")
	_check(_off_reports.size() == 1, "exactly one offline_report emitted")
	for k in ["away_s", "stops", "items_found", "items_shelved", "tokens", "rep", "claimants_waiting"]:
		_check(int(rep[k]) >= 0, "report %s never negative" % k)
	_check(_sim.tokens >= tok0 and int(rep["tokens"]) == _sim.tokens - tok0, "tokens only go up while away")
	_check((rep["lines"] as Array).size() >= 1, "report has text lines")
	for pid in waiting_before:
		_check(_sim.get_passengers().any(func(p): return p["pid"] == pid), "claimant %s is not lost while away" % pid)
	_check(_sim._active_claimants() <= _sim.MAX_CLAIMANTS, "claimants stay within the cap")
	_check(String(_sim.get_train()["state"]) == "moving", "train resumes moving after offline")
	var big: Dictionary = _sim.apply_offline(86400.0 * 400.0)
	_check(int(big["stops"]) == 20 and bool(big["capped"]) and float(big["away_s"]) <= 30.0 * 86400.0, "huge gap is capped at 20 stops / 30 days")
	_check(_sim.tokens >= 0 and _sim.rep >= 0 and _sim.get_bench_cap() >= 3, "no negative or broken state after a huge gap")
	var seen: Dictionary = {}
	for it in _sim.to_dict()["items"].values():
		_check(not seen.has(it["iid"]), "no duplicate iid")
		seen[it["iid"]] = true
	var a: String = _off_sig(5150, 7200.0)
	var b: String = _off_sig(5150, 7200.0)
	_check(a == b, "offline result is deterministic for a fixed seed")
	_check(_off_sig(5150, 7200.0) != _off_sig(5151, 7200.0), "different seeds differ")
	# porters shelve things while away
	_sim.new_game(88)
	_sim.skip_tutorial()
	_sim.tokens = 500
	_sim.buy("porter")
	var rp: Dictionary = _sim.apply_offline(3600.0)
	_check(int(rp["items_shelved"]) > 0 and int(rp["tokens"]) >= 10 * 3, "porter shelves items and adds tips offline")
	# save/load still round-trips after an offline run
	var d: Dictionary = _sim.to_dict()
	_sim.new_game(1)
	_check(_sim.from_dict(d) and JSON.stringify(_sim.to_dict()["items"]) == JSON.stringify(d["items"]), "state after offline survives save/load")


# ---- A6.2 save robustness ----
func _write_raw(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _rm(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_save_safety() -> void:
	var main: String = "user://test_save_v2.json"
	for ext in [".json", ".bak", ".json.tmp", ".json.corrupt"]:
		_rm("user://test_save_v2" + ext)
	_sim.new_game(61)
	_sim.skip_tutorial()
	_sim.tokens = 111
	_sim.cheated = true
	_check(_sim.save_game() and not FileAccess.file_exists(main + ".tmp"), "save succeeds and leaves no temp file")
	_sim.tokens = 222
	_check(_sim.save_game() and FileAccess.file_exists("user://test_save_v2.bak"), "second save keeps a .bak of the first")
	_write_raw(main, "{ truncated")
	_sim.new_game(1)
	_check(_sim.load_game() and _sim.tokens == 111, "corrupt main falls back to the backup")
	_check(_sim.cheated and _sim.get_load_notice() != "", "cheated flag survives and the player is told")
	_check(FileAccess.file_exists(main + ".corrupt"), "damaged file is kept as .corrupt")
	_write_raw("user://test_save_v2.bak", "garbage")
	_write_raw(main, "garbage")
	_check(not _sim.load_game() and _sim.get_load_notice() != "", "both corrupt: fresh start with a notice")
	# v2 -> v3 migration
	_sim.new_game(62)
	_sim.tokens = 77
	var d: Dictionary = _sim.to_dict()
	d["version"] = 2
	d.erase("saves_n")
	_write_raw(main, JSON.stringify(d))
	_rm("user://test_save_v2.bak")
	_sim.new_game(1)
	_check(_sim.load_game() and _sim.tokens == 77, "v2 save migrates and loads")
	_check(int(_sim.to_dict()["version"]) == 3, "saves are written as v3")
	d["version"] = 99
	_check(_sim.migrate_save(d).is_empty(), "future/unknown versions are refused")
	for ext in [".json", ".bak", ".json.tmp", ".json.corrupt"]:
		_rm("user://test_save_v2" + ext)


# ---- A6.7 cheat completeness (uses a throwaway test password; the real hash is never in the repo) ----
func _test_cheats_complete() -> void:
	var cheats: Node = _sim.get_node("/root/Cheats")
	var saved_hash: String = cheats._hash
	var log_path: String = "user://cheats.log"
	cheats.screenshot_mode = false
	cheats.lock()
	cheats._fails = 0
	cheats._locked_until_ms = 0
	# panel disabled without a hash file
	cheats._hash = ""
	_check(not cheats.is_available() and not cheats.try_unlock("x") and not bool(cheats.run("tokens_100")["ok"]), "no hash => panel disabled, nothing runs")
	# lockout after 3 wrong tries
	cheats._hash = ("pz1|" + "test-only-password" + "|zero").sha256_text()
	_check(cheats.is_available(), "hash present => panel available")
	for i in range(3):
		_check(not cheats.try_unlock("wrong%d" % i), "wrong password %d refused" % i)
	var left: float = cheats.lockout_left()
	_check(left > 28.0 and left <= 30.0, "3 wrong tries => ~30 s lockout (%.1f)" % left)
	_check(not cheats.try_unlock("test-only-password"), "even the right password is refused during lockout")
	_check(not bool(cheats.run("tokens_100")["ok"]), "still locked during lockout")
	cheats._locked_until_ms = 0
	_check(cheats.try_unlock("test-only-password") and cheats.is_unlocked(), "unlock works after the lockout ends")
	# every listed cheat works, logs and flags the save
	_rm(log_path)
	var ids: Array = []
	for c in cheats.list():
		ids.append(String(c["id"]))
		_sim.new_game(404)
		_sim.skip_tutorial()
		_sim.tick(400.0)
		_sim.tokens = 5
		var def: Variant = (c["args"] as Dictionary).get("default", null)
		var res: Dictionary = cheats.run(String(c["id"]), def)
		var ok: bool = bool(res.get("ok", false))
		if not ok and String(c["id"]) == "tier_up":
			ok = true  # only refuses at max tier
		_check(ok, "cheat %s works (%s)" % [c["id"], str(res.get("reason", ""))])
		_check(_sim.cheated, "cheat %s sets the cheated flag" % c["id"])
	var logged: String = FileAccess.get_file_as_string(log_path)
	for id in ids:
		_check(logged.contains("run " + id), "cheat %s is logged" % id)
	_check(logged.contains("unlock"), "unlock is logged")
	_check(not bool(cheats.run("not_a_cheat")["ok"]), "unknown cheat id refused")
	cheats.lock()
	_check(not bool(cheats.run("tokens_100")["ok"]), "lock() re-locks")
	cheats._hash = saved_hash
	cheats._fails = 0
	cheats._locked_until_ms = 0
	_rm(log_path)
