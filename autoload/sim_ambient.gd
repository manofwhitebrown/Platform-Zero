extends RefCounted
## Ambient passenger sim (A2.1). Owned by Sim (see sim.gd). 30+ distinct passengers per run:
## they sit in per-car seat slots with routines, board and leave while the train is stopped,
## drop items at spots when they leave, and two scripted walkers roam the train (conductor, vendor).
##
## Passenger dict extras (kind == "ambient"):
##   state    seated | standing_up | walking (boarding, or walker) | idle (walker pause) | leaving
##   routine  reading | napping | eating | staring | chatting | kids | vendor | conductor
##   role     "" (seated passenger) | "conductor" | "vendor"
##   seat_slot "car_pass_a3", slot int, partner pid (chatting pairs), stops (stops aboard)
## Routine changes emit Events.passenger_state_changed(pid, <routine name>).

const SLOT_X0: float = 300.0
const SLOT_DX: float = 130.0
const SLOTS_PER_CAR: int = 10
const TARGET: Dictionary = {"car_pass": 7, "car_dine": 6, "car_sleep": 5, "car_obs": 4, "car_lug": 2}
const INITIAL: Dictionary = {"car_pass": 5, "car_dine": 4}
const ROUTINE_WEIGHTS: Dictionary = {
	"car_pass": {"reading": 30, "napping": 22, "staring": 20, "chatting": 18, "eating": 5},
	"car_dine": {"eating": 55, "chatting": 20, "reading": 10, "staring": 10, "napping": 5},
	"car_sleep": {"napping": 70, "reading": 20, "staring": 10},
	"car_obs": {"staring": 60, "reading": 20, "chatting": 20},
	"car_lug": {"staring": 60, "reading": 40},
}
const LEAVE_CHANCE: float = 0.35
const DROP_CHANCE: float = 0.30
const BARK_RANGE: float = 1200.0
const COARSE_RANGE: float = 1500.0  # seated people farther than this from the attendant tick coarsely
const COARSE_STEP: float = 1.0
const WALK_SPEED: float = 120.0
const CONDUCTOR_SPEED: float = 110.0
const VENDOR_SPEED: float = 70.0

var sim: Node
var boarding: Array = []  # {in, car_id, slot}
var dropped: Array = []  # iids dropped by leavers; their owners show up at the next stop
var bark_cool: float = 0.0
var total_seen: int = 0
var drops_total: int = 0


func _init(sim_node: Node) -> void:
	sim = sim_node


func reset() -> void:
	boarding.clear()
	dropped.clear()
	bark_cool = 0.0
	total_seen = 0
	drops_total = 0


func to_dict() -> Dictionary:
	return {"boarding": boarding.duplicate(true), "dropped": dropped.duplicate(true), "bark_cool": bark_cool, "total_seen": total_seen, "drops_total": drops_total}


func from_dict(d: Dictionary) -> void:
	boarding = (d.get("boarding", []) as Array).duplicate(true)
	dropped = (d.get("dropped", []) as Array).duplicate(true)
	bark_cool = float(d.get("bark_cool", 0.0))
	total_seen = int(d.get("total_seen", 0))
	drops_total = int(d.get("drops_total", 0))
	ensure_walkers()


# ---------- geometry ----------
func slot_x(car_id: String, slot: int) -> float:
	return _car(car_id)["x"] + SLOT_X0 + SLOT_DX * slot


func door_x(car_id: String) -> float:
	return float(_car(car_id)["x"]) + float(sim.CAR_W) - 60.0


func _car(car_id: String) -> Dictionary:
	for c in sim._cars:
		if c["id"] == car_id:
			return c
	return sim._cars[0]


func _span() -> Vector2:
	var lo: float = 1.0e9
	var hi: float = -1.0
	for c in sim._cars:
		if bool(c["unlocked"]):
			lo = minf(lo, float(c["x"]) + 120.0)
			hi = maxf(hi, float(c["x"]) + float(sim.CAR_W) - 120.0)
	return Vector2(lo, hi)


# ---------- creation ----------
func populate_initial() -> void:
	var r: RandomNumberGenerator = sim._local_rng("amb_init")
	for car_id in INITIAL.keys():
		var slots: Array = range(SLOTS_PER_CAR)
		for i in range(slots.size() - 1, 0, -1):
			var j: int = r.randi_range(0, i)
			var t: Variant = slots[i]
			slots[i] = slots[j]
			slots[j] = t
		for k in range(int(INITIAL[car_id])):
			var p: Dictionary = _new_ambient(String(car_id), int(slots[k]), true)
			Events.passenger_spawned.emit(p)
	ensure_walkers()


func ensure_walkers() -> void:
	var have: Dictionary = {}
	for p in sim._passengers.values():
		if p["kind"] == "ambient" and String(p.get("role", "")) != "":
			have[String(p["role"])] = true
	for role in ["conductor", "vendor"]:
		if not have.has(role):
			var car_id: String = "car_pass" if role == "conductor" else "car_dine"
			var pid: String = sim._new_pid("amb")
			var p: Dictionary = sim._make_passenger(pid, "ambient", "", "The Conductor" if role == "conductor" else "The Vendor",
				slot_x(car_id, 5), "calm", car_id, "idle")
			p["look"] = sim._random_look(pid)
			p["role"] = role
			p["routine"] = role
			p["r_t"] = 3.0
			p["dest_x"] = float(p["x"])
			p["seat_slot"] = ""
			p["leave_in"] = -1.0
			p["stops"] = 0
			p["partner"] = ""
			p["bark_in"] = 20.0
			sim._passengers[pid] = p
			Events.passenger_spawned.emit(p)


func spawn_ambient(car_id: String) -> Dictionary:
	var slot: int = _free_slot(car_id)
	if slot < 0:
		return {}
	var p: Dictionary = _new_ambient(car_id, slot, true)
	Events.passenger_spawned.emit(p)
	return p


func _new_ambient(car_id: String, slot: int, at_seat: bool) -> Dictionary:
	var pid: String = sim._new_pid("amb")
	var r: RandomNumberGenerator = sim._local_rng("amb|" + pid)
	var kid: bool = r.randf() < 0.06
	var look: Dictionary = sim._random_look(pid)
	look["height"] = 0.7 if kid else r.randf_range(0.92, 1.08)
	var sx: float = slot_x(car_id, slot)
	var x: float = sx if at_seat else door_x(car_id)
	var mood: String = String(sim.MOODS[r.randi_range(0, sim.MOODS.size() - 1)])
	var p: Dictionary = sim._make_passenger(pid, "ambient", "", _pick_name(r), x, mood, car_id, "seated" if at_seat else "walking")
	p["look"] = look
	p["facing"] = 1 if r.randf() < 0.5 else -1
	p["role"] = ""
	p["slot"] = slot
	p["seat_slot"] = "%s_a%d" % [car_id, slot]
	p["routine"] = "kids" if kid else _roll_routine(car_id, r)
	p["r_t"] = r.randf_range(20.0, 80.0)
	p["leave_in"] = -1.0
	p["stops"] = 0
	p["partner"] = ""
	p["bark_in"] = r.randf_range(20.0, 120.0)
	p["dest_x"] = sx
	sim._passengers[pid] = p
	total_seen += 1
	return p


func _pick_name(r: RandomNumberGenerator) -> String:
	var full: Array = Content.names.get("full", []) as Array
	var taken: Dictionary = {}
	for q in sim._passengers.values():
		taken[String(q["name"])] = true
	for _i in range(12):
		if full.is_empty():
			break
		var cand: String = String(full[r.randi_range(0, full.size() - 1)])
		if not taken.has(cand):
			return cand
	return "Passenger %d" % (total_seen + 1)


func _roll_routine(car_id: String, r: RandomNumberGenerator) -> String:
	var weights: Dictionary = ROUTINE_WEIGHTS.get(car_id, ROUTINE_WEIGHTS["car_pass"])
	var sum: int = 0
	for k in weights.keys():
		sum += int(weights[k])
	var roll: int = r.randi_range(0, sum - 1)
	for k in weights.keys():
		roll -= int(weights[k])
		if roll < 0:
			return String(k)
	return "staring"


# ---------- slots ----------
func _slot_taken(car_id: String, slot: int) -> bool:
	for p in sim._passengers.values():
		if p["kind"] == "ambient" and String(p.get("role", "")) == "" and p["car_id"] == car_id and int(p.get("slot", -1)) == slot and p["state"] != "leaving" and p["state"] != "standing_up":
			return true
	for b in boarding:
		if b["car_id"] == car_id and int(b["slot"]) == slot:
			return true
	return false


func _free_slot(car_id: String) -> int:
	var open: Array = []
	for s in range(SLOTS_PER_CAR):
		if not _slot_taken(car_id, s):
			open.append(s)
	if open.is_empty():
		return -1
	return int(open[sim.rng.randi_range(0, open.size() - 1)])


func _count_in(car_id: String) -> int:
	var n: int = 0
	for p in sim._passengers.values():
		if p["kind"] == "ambient" and String(p.get("role", "")) == "" and p["car_id"] == car_id and p["state"] != "leaving" and p["state"] != "standing_up":
			n += 1
	for b in boarding:
		if b["car_id"] == car_id:
			n += 1
	return n


# ---------- the stop: leavers, boarders, dropped items ----------
func on_stopped() -> void:
	for p in sim._passengers.values():
		if p["kind"] == "ambient" and String(p.get("role", "")) == "":
			p["stops"] = int(p.get("stops", 0)) + 1
			if p["state"] == "seated" and int(p["stops"]) >= 2 and float(p.get("leave_in", -1.0)) < 0.0 and sim.rng.randf() < LEAVE_CHANCE:
				p["leave_in"] = sim.rng.randf_range(4.0, 50.0)
	for car in sim._cars:
		var car_id: String = String(car["id"])
		if not bool(car["unlocked"]) or not TARGET.has(car_id):
			continue
		var deficit: int = int(TARGET[car_id]) - _count_in(car_id)
		if deficit <= 0:
			continue
		var n: int = mini(deficit, sim.rng.randi_range(1, 3))
		for _i in range(n):
			var slot: int = _free_slot(car_id)
			if slot < 0:
				break
			boarding.append({"in": sim.rng.randf_range(3.0, 55.0), "car_id": car_id, "slot": slot})


## Aggregate churn for ONE skipped stop (A6.1): no walking, people simply end up seated or gone.
func offline_stop() -> void:
	for b in boarding:
		_new_ambient(String(b["car_id"]), int(b["slot"]), true)
	boarding.clear()
	for p in sim._passengers.values():
		if p["kind"] != "ambient" or String(p.get("role", "")) != "":
			continue
		var st: String = String(p["state"])
		if st == "leaving" or st == "standing_up":
			_unpair(p)
			_drop_quiet(p)
		elif st == "walking":
			p["x"] = float(p.get("dest_x", p["x"]))
			p["state"] = "seated"
		if not sim._passengers.has(p["pid"]):
			continue
		p["stops"] = int(p.get("stops", 0)) + 1
		p["leave_in"] = -1.0
		if int(p["stops"]) >= 2 and sim.rng.randf() < LEAVE_CHANCE:
			_unpair(p)
			_maybe_drop(p)
			_drop_quiet(p)
	for car in sim._cars:
		var car_id: String = String(car["id"])
		if not bool(car["unlocked"]) or not TARGET.has(car_id):
			continue
		var deficit: int = int(TARGET[car_id]) - _count_in(car_id)
		var n: int = mini(deficit, sim.rng.randi_range(1, 3)) if deficit > 0 else 0
		for _i in range(n):
			var slot: int = _free_slot(car_id)
			if slot < 0:
				break
			var q: Dictionary = _new_ambient(car_id, slot, true)
			Events.passenger_spawned.emit(q)


func _drop_quiet(p: Dictionary) -> void:
	var pid: String = String(p["pid"])
	sim._queue.erase(pid)
	sim._passengers.erase(pid)
	Events.passenger_left.emit(pid, true)


## Items dropped by leavers since the last stop that are still lying around (their owners come asking).
func take_dropped() -> Array:
	var out: Array = []
	for iid in dropped:
		if sim._items.has(iid) and sim._items[iid]["loc"] == "spot":
			out.append(sim._items[iid])
	dropped.clear()
	return out


# ---------- per-step ----------
func tick_global(dt: float) -> void:
	bark_cool = maxf(0.0, bark_cool - dt)
	var i: int = 0
	while i < boarding.size():
		var b: Dictionary = boarding[i]
		b["in"] = float(b["in"]) - dt
		if float(b["in"]) <= 0.0:
			boarding.remove_at(i)
			var p: Dictionary = _new_ambient(String(b["car_id"]), int(b["slot"]), false)
			p["facing"] = -1
			Events.passenger_spawned.emit(p)
			_bark(p, "boarding", 0.4)
		else:
			i += 1


func tick(p: Dictionary, dt: float) -> void:
	if not p.has("routine"):
		_migrate(p)
	var role: String = String(p.get("role", ""))
	if role != "":
		_tick_walker(p, dt, role)
		return
	if String(p["state"]) == "seated" and absf(float(p["x"]) - float(sim._player["x"])) > COARSE_RANGE:
		var acc: float = float(p.get("acc", 0.0)) + dt
		if acc < COARSE_STEP:
			p["acc"] = acc
			return
		dt = acc
		p["acc"] = 0.0
	match String(p["state"]):
		"seated":
			p["r_t"] = float(p["r_t"]) - dt
			if float(p["r_t"]) <= 0.0:
				_reroll(p)
			p["bark_in"] = float(p["bark_in"]) - dt
			if float(p["bark_in"]) <= 0.0:
				p["bark_in"] = sim._local_rng("bk|%s|%d" % [p["pid"], int(sim.clock_s)]).randf_range(40.0, 140.0)
				_bark(p, String(p["routine"]), 0.5)
			if float(p["leave_in"]) >= 0.0:
				p["leave_in"] = float(p["leave_in"]) - dt
				if float(p["leave_in"]) < 0.0:
					_begin_leave(p)
		"standing_up":
			p["t"] = float(p["t"]) - dt
			if float(p["t"]) <= 0.0:
				sim._set_pstate(p, "leaving")
		"walking":
			var tx: float = float(p["dest_x"])
			p["facing"] = 1 if tx > float(p["x"]) else -1
			sim._walk_toward(p, tx, WALK_SPEED * dt)
			if absf(float(p["x"]) - tx) < 1.0:
				p["facing"] = 1 if int(p.get("slot", 0)) % 2 == 0 else -1
				sim._set_pstate(p, "seated")
		"leaving":
			var dx: float = door_x(String(p["car_id"]))
			p["facing"] = 1
			sim._walk_toward(p, dx, WALK_SPEED * dt)
			if absf(float(p["x"]) - dx) < 1.0:
				p["leave_mood"] = "happy"
				sim._remove_passenger(p)


func _migrate(p: Dictionary) -> void:
	p["role"] = String(p.get("role", ""))
	p["routine"] = "staring"
	p["r_t"] = 30.0
	p["leave_in"] = -1.0
	p["stops"] = 0
	p["partner"] = ""
	p["bark_in"] = 60.0
	p["slot"] = int(p.get("slot", -1))
	p["dest_x"] = float(p["x"])


func _reroll(p: Dictionary) -> void:
	var r: RandomNumberGenerator = sim._local_rng("rr|%s|%d" % [p["pid"], int(sim.clock_s)])
	_unpair(p)
	var kid: bool = float((p["look"] as Dictionary).get("height", 1.0)) < 0.8
	var routine: String = "kids" if kid and r.randf() < 0.7 else _roll_routine(String(p["car_id"]), r)
	if routine == "chatting":
		var other: Dictionary = _neighbour(p)
		if other.is_empty():
			routine = "staring"
		else:
			p["partner"] = other["pid"]
			other["partner"] = p["pid"]
			other["routine"] = "chatting"
			other["r_t"] = float(p["r_t"])
			Events.passenger_state_changed.emit(other["pid"], "chatting")
	p["routine"] = routine
	p["r_t"] = r.randf_range(25.0, 90.0)
	if routine == "chatting" and p["partner"] != "":
		(sim._passengers[p["partner"]] as Dictionary)["r_t"] = p["r_t"]
	Events.passenger_state_changed.emit(p["pid"], routine)


func _neighbour(p: Dictionary) -> Dictionary:
	var slot: int = int(p.get("slot", -1))
	for q in sim._passengers.values():
		if q["kind"] == "ambient" and String(q.get("role", "")) == "" and q["state"] == "seated" and q["car_id"] == p["car_id"] \
				and q["pid"] != p["pid"] and absi(int(q.get("slot", -9)) - slot) == 1 and String(q.get("partner", "")) == "":
			return q
	return {}


func _unpair(p: Dictionary) -> void:
	var pp: String = String(p.get("partner", ""))
	if pp != "" and sim._passengers.has(pp):
		var o: Dictionary = sim._passengers[pp]
		o["partner"] = ""
		o["routine"] = "staring"
		o["r_t"] = 10.0
		Events.passenger_state_changed.emit(pp, "staring")
	p["partner"] = ""


func _begin_leave(p: Dictionary) -> void:
	_unpair(p)
	_bark(p, "leaving", 0.5)
	_maybe_drop(p)
	p["facing"] = 1
	sim._set_pstate(p, "standing_up")
	p["t"] = 0.8


func _maybe_drop(p: Dictionary) -> void:
	if String(sim._train["state"]) != "stopped" or sim.rng.randf() >= DROP_CHANCE:
		return
	var best: String = ""
	var best_d: float = 1.0e9
	for sp in sim._spots:
		if sp["car_id"] == p["car_id"] and String(sp["item_iid"]) == "" and String(sp["kind"]) != "seat":
			var d: float = absf(float(sp["x"]) - float(p["x"]))
			if d < best_d:
				best_d = d
				best = String(sp["id"])
	var def_id: String = sim._pick_def()
	if best == "" or def_id == "":
		return
	var it: Dictionary = sim._spawn_item(def_id, best)
	dropped.append(String(it["iid"]))
	drops_total += 1


func _tick_walker(p: Dictionary, dt: float, role: String) -> void:
	var speed: float = CONDUCTOR_SPEED if role == "conductor" else VENDOR_SPEED
	if String(p["state"]) == "idle":
		p["r_t"] = float(p["r_t"]) - dt
		if float(p["r_t"]) <= 0.0:
			var sp: Vector2 = _span()
			var r: RandomNumberGenerator = sim._local_rng("wk|%s|%d" % [p["pid"], int(sim.clock_s)])
			p["dest_x"] = r.randf_range(sp.x, sp.y)
			sim._set_pstate(p, "walking")
		return
	var tx: float = float(p["dest_x"])
	p["facing"] = 1 if tx > float(p["x"]) else -1
	sim._walk_toward(p, tx, speed * dt)
	p["car_id"] = sim._car_at(float(p["x"]))
	if absf(float(p["x"]) - tx) < 1.0:
		p["r_t"] = sim._local_rng("wp|%s|%d" % [p["pid"], int(sim.clock_s)]).randf_range(6.0, 18.0)
		sim._set_pstate(p, "idle")
		_bark(p, role, 0.7)


func _bark(p: Dictionary, key: String, chance: float) -> void:
	if bark_cool > 0.0:
		return
	var player_x: float = float(sim._player["x"])
	if absf(float(p["x"]) - player_x) > BARK_RANGE:
		return
	var r: RandomNumberGenerator = sim._local_rng("bark|%s|%s|%d" % [p["pid"], key, int(sim.clock_s)])
	if r.randf() >= chance:
		return
	var lines: Array = Content.lines("barks", ["ambient", key])
	if lines.is_empty():
		return
	bark_cool = 5.0
	Events.passenger_said.emit(p["pid"], String(lines[r.randi_range(0, lines.size() - 1)]))
