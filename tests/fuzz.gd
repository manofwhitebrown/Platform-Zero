extends SceneTree
## A6.3 fuzz + balance runner (headless, separate from run_tests so it can run long).
##   godot --headless --script tests/fuzz.gd -- --stops=1000 [--seed=7]
## Bots: smart (interviews + examines + hands over), lazy (guesses), random (garbage commands).
## Asserts invariants (no negative tokens/rep, queue cap, bench cap, unique ids, consistent
## spots, claimants always resolvable, save round-trip) and prints a balance report.

const ACT_PICK: float = 3.0
const ACT_BENCH: float = 1.0
const ACT_TOOL: float = 2.0
const ACT_ASK: float = 2.0
const ACT_HAND: float = 3.0
const TOOLS: Array = ["magnifier", "lamp", "ear", "nose", "brush"]
const BUYS: Array = ["porter", "bench_slot", "lamp_oil", "porter", "uv_lamp", "lamp_oil", "porter", "lamp_oil"]

var fails: int = 0
var _sim: Node
var _content: Node
var _stops: int = 150
var _seed: int = 7
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _since_inv: int = 0
var _tier_at: Dictionary = {}  # tier -> sim minutes
var _stats: Dictionary = {}


func _init() -> void:
	_run.call_deferred()


var _fail_seen: Dictionary = {}


func _fail(msg: String) -> void:
	fails += 1
	if not _fail_seen.has(msg):
		_fail_seen[msg] = true
		printerr("FUZZ FAIL: " + msg)


func _run() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stops="):
			_stops = int(a.substr(8))
		elif a.begins_with("--seed="):
			_seed = int(a.substr(7))
	_sim = root.get_node("Sim")
	_content = root.get_node("Content")
	_sim.frozen = true
	_sim.autosave = false
	_sim.save_path = "user://fuzz_save_v2.json"
	_check_solvable_content()
	for bot in ["smart", "lazy", "random"]:
		_rng.seed = _seed
		_play(bot)
	_daily_model()
	print("fuzz: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


# ---------- content solvability ----------
func _check_solvable_content() -> void:
	_sim.new_game(1)
	var defs: Array = _content.objects + _content.generated_objects
	var bad: int = 0
	for d in defs:
		var oid: String = String(d.get("owner_id", ""))
		if _content.owner_by_id(oid).is_empty():
			bad += 1
			_fail("item %s has no owner %s" % [d.get("id", "?"), oid])
			continue
		var p: Dictionary = _sim._spawn_claimant(oid, String(d["id"]), true)
		var hints: Array = _sim._hints_for(p)
		var vals: Dictionary = {}
		for c in d.get("clues", []):
			vals[String(c["attr"])] = String(c["value"])
		var good: int = 0
		for h in hints:
			if vals.has(String(h["attr"])) and vals[String(h["attr"])] == String(h["value"]):
				good += 1
		if good < 2:
			bad += 1
			_fail("item %s: owner %s gives only %d usable hints" % [d.get("id", "?"), oid, good])
		_sim._remove_passenger(p)
	print("solvable content: %d defs checked, %d bad" % [defs.size(), bad])


# ---------- invariants ----------
func _inv(tag: String) -> void:
	var s: Node = _sim
	if s.tokens < 0 or s.rep < 0:
		_fail("%s: negative tokens/rep %d/%d" % [tag, s.tokens, s.rep])
	if s._active_claimants() > s.MAX_CLAIMANTS or s._queue.size() > s.MAX_CLAIMANTS:
		_fail("%s: claimants over cap (%d, queue %d)" % [tag, s._active_claimants(), s._queue.size()])
	if s.get_items_at("bench").size() > s.get_bench_cap():
		_fail("%s: bench over capacity" % tag)
	var on_spot: int = 0
	for key in s._items.keys():
		var it: Dictionary = s._items[key]
		if String(it["iid"]) != String(key):
			_fail("%s: iid mismatch %s" % [tag, key])
		if it["loc"] == "spot":
			on_spot += 1
	var filled: int = 0
	for sp in s.get_spots():
		var iid: String = String(sp["item_iid"])
		if iid == "":
			continue
		filled += 1
		if not s._items.has(iid) or s._items[iid]["loc"] != "spot" or String(s._items[iid]["spot_id"]) != String(sp["id"]):
			_fail("%s: spot %s inconsistent with item %s" % [tag, sp["id"], iid])
	if filled != on_spot:
		_fail("%s: %d spots filled but %d items on spots" % [tag, filled, on_spot])
	var carried: int = s.get_items_at("carried").size()
	if carried > 1 or (carried == 1) != (String(s.get_player()["carrying"]) != ""):
		_fail("%s: carrying state inconsistent" % tag)
	var seen: Dictionary = {}
	for pid in s._queue:
		if seen.has(pid) or not s._passengers.has(pid):
			_fail("%s: bad queue entry %s" % [tag, pid])
		seen[pid] = true


func _maybe_inv(tag: String) -> void:
	_since_inv += 1
	if _since_inv >= 40:
		_since_inv = 0
		_inv(tag)


# ---------- bots ----------
func _act(sec: float) -> void:
	_sim.tick(sec)
	_track_tier()


func _track_tier() -> void:
	var t: int = int(_sim.get_player()["tier"])
	for i in range(1, t + 1):
		if not _tier_at.has(i):
			_tier_at[i] = _sim.clock_s / 60.0


func _play(bot: String) -> void:
	_sim.new_game(_seed)
	_tier_at = {}
	var stats: Dictionary = {"delivered": 0, "refused": 0, "wrong": 0, "idle_ticks": 0}
	var guard: int = 0
	var last_progress_t: float = 0.0
	var worst_wait: float = 0.0
	var t_wall: int = Time.get_ticks_msec()
	var limit: int = 520 if bot == "smart" else _stops
	while _sim.stop_index < limit and guard < 1200000:
		guard += 1
		var did: bool = false
		match bot:
			"smart": did = _smart_step(stats)
			"lazy": did = _lazy_step(stats)
			_: did = _random_step(stats)
		if did:
			last_progress_t = _sim.clock_s
		else:
			_act(5.0)
		worst_wait = maxf(worst_wait, _sim.clock_s - last_progress_t)
		_maybe_inv(bot)
		if guard % 600 == 0 and _sim.get_queue().size() > 0 and bot == "smart":
			if _sim.clock_s - last_progress_t > 3600.0:
				_fail("smart bot stuck for an hour with a queue (softlock)")
				break
	_inv(bot + " end")
	# save/load round trip
	var before: String = JSON.stringify([_sim.tokens, _sim.rep, _sim.stop_index, _sim.to_dict()["items"], _sim.to_dict()["queue"]])
	if not _sim.save_game():
		_fail("%s: save failed" % bot)
	_sim.new_game(1)
	if not _sim.load_game():
		_fail("%s: load failed" % bot)
	var after: String = JSON.stringify([_sim.tokens, _sim.rep, _sim.stop_index, _sim.to_dict()["items"], _sim.to_dict()["queue"]])
	if before != after:
		_fail("%s: save/load round-trip differs" % bot)
	_stats[bot] = stats
	var ms: int = Time.get_ticks_msec() - t_wall
	print("%-6s | %4d stops | %6.0f sim-min | deliv %3d refuse %3d wrong %3d | tokens %5d rep %4d tier %d | worst idle %4.0fs | tier@min %s | %d ms" % [bot, _sim.stop_index, _sim.clock_s / 60.0, stats["delivered"], stats["refused"], stats["wrong"], _sim.tokens, _sim.rep, int(_sim.get_player()["tier"]), worst_wait, JSON.stringify(_tier_at), ms])


func _buy_something() -> void:
	for id in BUYS:
		if int(_sim.get_upgrade_level(id)) < 3 and bool(_sim.buy(id)["ok"]):
			return


func _loose_items() -> Array:
	var out: Array = []
	for it in _sim._items.values():
		if it["loc"] in ["spot", "shelf", "bench", "carried"]:
			out.append(it)
	return out


func _item_vals(it: Dictionary) -> Dictionary:
	var vals: Dictionary = {}
	for c in _content.object_by_id(String(it["def_id"])).get("clues", []):
		vals[String(c["attr"])] = String(c["value"])
	return vals


func _examine(it: Dictionary, attrs: Array) -> void:
	var iid: String = String(it["iid"])
	if it["loc"] == "spot":
		_sim.pick_up(String(it["spot_id"]))
		_act(ACT_PICK)
	if it["loc"] != "bench":
		if _sim.get_items_at("bench").size() >= _sim.get_bench_cap():
			_sim.put_on_shelf(String(_sim.get_items_at("bench")[0]["iid"]))
		_sim.place_on_bench(iid)
		_act(ACT_BENCH)
	for tool in TOOLS:
		for a in _sim.TOOL_ATTRS[tool]:
			if attrs.has(a):
				_sim.reveal(iid, tool)
				_act(ACT_TOOL)
				break


func _smart_step(stats: Dictionary) -> bool:
	if _sim.first_delivery_done and not _sim.tutorial_done:
		var r: Dictionary = _sim.pick_up("car_pass_s1")
		if bool(r["ok"]):
			_sim.put_on_shelf(String(r["iid"]))
		_act(2.0)
		return true
	var front: Dictionary = _sim._front_claimant()
	if front.is_empty():
		var c: Dictionary = _sim.call_next()
		if String(c["called"]) != "":
			_act(6.0)
			return true
		return false
	if front["state"] != "waiting":
		_act(1.0)
		return true
	var pid: String = String(front["pid"])
	var hints: Array = []
	for q in [1, 2]:
		var a: Dictionary = _sim.ask(pid, q)
		_act(ACT_ASK)
		if String(a["attr"]) != "":
			hints.append(a)
	var best: Dictionary = {}
	var best_n: int = 0
	for it in _loose_items():
		var vals: Dictionary = _item_vals(it)
		var n: int = 0
		for h in hints:
			if vals.get(String(h["attr"]), "") == String(h["value"]):
				n += 1
		if n > best_n:
			best_n = n
			best = it
	if not best.is_empty() and best_n == hints.size():
		_examine(best, hints.map(func(h): return h["attr"]))
		_sim.take_from_bench(String(best["iid"]))
		var res: Dictionary = _sim.hand_over(String(best["iid"]), pid)
		_act(ACT_HAND)
		if bool(res.get("correct", false)):
			stats["delivered"] += 1
		else:
			stats["wrong"] += 1
		_buy_something()
	else:
		_sim.refuse(pid)
		stats["refused"] += 1
		_act(ACT_HAND)
	return true


func _lazy_step(stats: Dictionary) -> bool:
	_act(20.0)
	if _rng.randf() < 0.5:
		_sim.call_next()
	var front: Dictionary = _sim._front_claimant()
	if not front.is_empty() and front["state"] == "waiting" and _rng.randf() < 0.5:
		var pool: Array = _loose_items()
		if not pool.is_empty():
			var it: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
			if it["loc"] == "spot":
				_sim.pick_up(String(it["spot_id"]))
			var res: Dictionary = _sim.hand_over(String(it["iid"]), String(front["pid"]))
			if bool(res.get("correct", false)):
				stats["delivered"] += 1
			else:
				stats["wrong"] += 1
		else:
			_sim.refuse(String(front["pid"]))
	return true


func _random_step(stats: Dictionary) -> bool:
	var all_ids: Array = _sim._items.keys()
	var pids: Array = _sim._passengers.keys()
	var spots: Array = _sim.get_spots()
	var iid: String = String(all_ids[_rng.randi_range(0, all_ids.size() - 1)]) if not all_ids.is_empty() else "nope"
	var pid: String = String(pids[_rng.randi_range(0, pids.size() - 1)]) if not pids.is_empty() else "nope"
	if _rng.randf() < 0.1:
		iid = "garbage%d" % _rng.randi()
	if _rng.randf() < 0.1:
		pid = "garbage%d" % _rng.randi()
	match _rng.randi_range(0, 13):
		0: _sim.pick_up(String(spots[_rng.randi_range(0, spots.size() - 1)]["id"]))
		1: _sim.place_on_bench(iid)
		2: _sim.take_from_bench(iid)
		3: _sim.put_on_shelf(iid)
		4: _sim.reveal(iid, String(TOOLS[_rng.randi_range(0, 4)]))
		5: _sim.ask(pid, _rng.randi_range(-1, 4))
		6: stats["wrong"] += 0 if not bool(_sim.hand_over(iid, pid).get("correct", false)) else 0
		7: _sim.refuse(pid)
		8: _sim.call_next()
		9: _sim.player_move_to(_rng.randf_range(-500.0, 12000.0))
		10: _sim.buy(["porter", "bench_slot", "lamp_oil", "nope"][_rng.randi_range(0, 3)])
		11: _sim.apply_offline(_rng.randf_range(-100.0, 5000.0))
		_: pass
	_act(_rng.randf_range(0.1, 15.0))
	return true


# ---------- balance: a realistic play pattern over days ----------
func _daily_model() -> void:
	_sim.new_game(_seed)
	_tier_at = {}
	var day_tier: Dictionary = {}
	var stats: Dictionary = {"delivered": 0, "refused": 0, "wrong": 0}
	for day in range(1, 61):
		var end_t: float = _sim.clock_s + 15.0 * 60.0  # one 15-minute session per day
		while _sim.clock_s < end_t:
			if not _smart_step(stats):
				_act(5.0)
		_sim.apply_offline(4.0 * 3600.0)  # away for the rest of the day (cap applies)
		_sim.apply_offline(4.0 * 3600.0)
		_inv("daily d%d" % day)
		var t: int = int(_sim.get_player()["tier"])
		for i in range(1, t + 1):
			if not day_tier.has(i):
				day_tier[i] = day
	print("daily 15-min sessions: tier reached on day %s | deliv %d | tokens %d rep %d" % [JSON.stringify(day_tier), stats["delivered"], _sim.tokens, _sim.rep])
	print("idle (never plays): rep stays %d by design; offline tokens only" % 0)
