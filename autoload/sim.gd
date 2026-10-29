extends Node
## Sim v2 STUB (A0.1). Canned data in the exact CONTRACT v2 shapes so B can build
## the world now. Real logic replaces the internals later; the API stays identical.
## World is 1D: x in px from the rear of the train (0) forward.

const CAR_W: float = 1800.0
const TOOL_ATTRS: Dictionary = {
	"magnifier": ["initials", "station_stamp"],
	"lamp": ["color", "material"],
	"ear": ["sound"],
	"nose": ["smell"],
	"brush": ["wear"],
}
const WALK_SPEED: float = 300.0
const STATE_DUR: Dictionary = {"arriving": 15.0, "stopped": 20.0, "departing": 10.0, "moving": 30.0}
const STOPS: Array = [
	{"name": "Platform Zero", "biome": "plains", "index": 0},
	{"name": "Lantern Junction", "biome": "snow", "index": 1},
	{"name": "Saltmarsh Halt", "biome": "sea", "index": 2},
]

var time_scale: float = 1.0
var _cars: Array = []
var _spots: Array = []
var _items: Dictionary = {}
var _passengers: Dictionary = {}
var _train: Dictionary = {}
var _player: Dictionary = {}
var _target_x: float = -1.0
var _state_t: float = 0.0
var _next_iid: int = 100
var _first_said: bool = false


func _ready() -> void:
	_build_world()


func _build_world() -> void:
	var kinds: Array = ["obs", "sleep", "lp", "pass", "dine", "lug"]
	var ids: Array = ["car_obs", "car_sleep", "car_lp", "car_pass", "car_dine", "car_lug"]
	var open: Array = ["car_lp", "car_pass", "car_dine"]
	_cars.clear()
	_spots.clear()
	for i in range(kinds.size()):
		_cars.append({"id": ids[i], "kind": kinds[i], "index": i, "x": i * CAR_W, "width": CAR_W, "unlocked": open.has(ids[i])})
		var spot_kinds: Array = ["seat", "rack", "floor", "bin", "sill", "curtain", "table", "seat"]
		for s in range(8):
			_spots.append({"id": "%s_s%d" % [ids[i], s], "car_id": ids[i], "x": i * CAR_W + 150.0 + s * 200.0, "kind": spot_kinds[s], "item_iid": ""})
	_items.clear()
	_spawn_item("obj_001", "car_lp_s3")
	_spawn_item("obj_004", "car_pass_s1")
	_spawn_item("obj_007", "car_dine_s6")
	_train = {"state": "moving", "stop": STOPS[0].duplicate(), "phase_t": 0.0, "speed": 1.0, "time_of_day": 0.8, "weather": "clear"}
	_player = {"x": 2 * CAR_W + 900.0, "car_id": "car_lp", "carrying": "", "tokens": 0, "rep": 0, "tier": 0}
	_passengers.clear()
	for n in range(6):
		var car: Dictionary = _cars[3 + (n % 2)]
		var pid: String = "amb_%d" % n
		_passengers[pid] = _make_passenger(pid, "ambient", "", "Passenger %d" % n, car["x"] + 300.0 + n * 150.0, "calm", String(car["id"]), "seated")
	var bram: Dictionary = _make_passenger("clm_1", "claimant", "own_001", "Bram the Stoker", 2 * CAR_W + 1200.0, "calm", "car_lp", "at_counter")
	bram["wants_item_def"] = "obj_001"
	bram["line"] = "I lost a mitten. Red? Sort of red."
	_passengers["clm_1"] = bram


func _make_passenger(pid: String, kind: String, owner_id: String, pname: String, x: float, mood: String, car_id: String, state: String) -> Dictionary:
	return {"pid": pid, "kind": kind, "owner_id": owner_id, "name": pname, "look": {}, "x": x, "facing": -1, "state": state, "mood": mood, "car_id": car_id, "seat_spot": "", "line": "", "wants_item_def": "", "patience": 1.0}


func _spawn_item(def_id: String, spot_id: String) -> Dictionary:
	var d: Dictionary = Content.object_by_id(def_id)
	var attrs: Array = []
	for c in d.get("clues", []):
		attrs.append(str(c.get("attr", "")))
	_next_iid += 1
	var iid: String = "i%d" % _next_iid
	var item: Dictionary = {"iid": iid, "def_id": def_id, "name": d.get("name", def_id), "icon": d.get("icon", "key"), "tint": d.get("tint", "#FFFFFF"), "rarity": d.get("rarity", "common"), "loc": "spot", "spot_id": spot_id, "clues_known": [], "unknown_attrs": attrs, "tag_note": ""}
	_items[iid] = item
	for sp in _spots:
		if sp["id"] == spot_id:
			sp["item_iid"] = iid
	return item


func _process(delta: float) -> void:
	var dt: float = delta * time_scale
	if _target_x >= 0.0:
		var dx: float = _target_x - float(_player["x"])
		var step: float = WALK_SPEED * dt
		if absf(dx) <= step:
			_player["x"] = _target_x
			_target_x = -1.0
		else:
			_player["x"] = float(_player["x"]) + signf(dx) * step
		_player["car_id"] = _car_at(float(_player["x"]))
	_state_t += dt
	_train["phase_t"] = clampf(_state_t / float(STATE_DUR[_train["state"]]), 0.0, 1.0)
	if _state_t >= float(STATE_DUR[_train["state"]]):
		_advance_train()
	if not _first_said and Time.get_ticks_msec() > 5000:
		_first_said = true
		Events.passenger_said.emit("clm_1", String(_passengers["clm_1"]["line"]))
		Events.claimant_waiting.emit("clm_1")


func _advance_train() -> void:
	var order: Array = ["moving", "arriving", "stopped", "departing"]
	var i: int = (order.find(_train["state"]) + 1) % order.size()
	_train["state"] = order[i]
	_state_t = 0.0
	if _train["state"] == "arriving":
		_train["stop"] = STOPS[(int(_train["stop"]["index"]) + 1) % STOPS.size()].duplicate()
	_train["speed"] = 0.0 if _train["state"] == "stopped" else 1.0
	Events.train_state_changed.emit(_train["state"], _train["stop"])


func _car_at(x: float) -> String:
	var i: int = clampi(int(x / CAR_W), 0, _cars.size() - 1)
	return String(_cars[i]["id"])


# ---------------- queries ----------------
func get_cars() -> Array: return _cars
func get_spots() -> Array: return _spots
func get_item(iid: String) -> Dictionary: return _items.get(iid, {})
func get_passengers() -> Array: return _passengers.values()
func get_train() -> Dictionary: return _train
func get_player() -> Dictionary: return _player
func get_ledger() -> Dictionary: return {"claims": [], "items": [], "catalog": [], "gallery": [], "daily": {}}
func get_shop() -> Array: return [{"id": "uv_lamp", "name": "UV Lamp", "cost": 50, "owned": false}]


func get_items_at(loc: String) -> Array:
	var out: Array = []
	for it in _items.values():
		if it["loc"] == loc:
			out.append(it)
	return out


# ---------------- commands ----------------
func player_move_to(x: float) -> Dictionary:
	_target_x = clampf(x, 0.0, CAR_W * _cars.size())
	return {"ok": true, "target_x": _target_x}


func pick_up(spot_id: String) -> Dictionary:
	if String(_player["carrying"]) != "":
		return {"ok": false, "reason": "hands full"}
	for sp in _spots:
		if sp["id"] == spot_id and String(sp["item_iid"]) != "":
			var iid: String = String(sp["item_iid"])
			sp["item_iid"] = ""
			_items[iid]["loc"] = "carried"
			_items[iid]["spot_id"] = ""
			_player["carrying"] = iid
			Events.item_moved.emit(iid, "carried")
			return {"ok": true, "iid": iid}
	return {"ok": false, "reason": "nothing there"}


func place_on_bench(iid: String) -> Dictionary:
	if not _items.has(iid):
		return {"ok": false, "reason": "no such item"}
	_items[iid]["loc"] = "bench"
	if String(_player["carrying"]) == iid:
		_player["carrying"] = ""
	Events.item_moved.emit(iid, "bench")
	return {"ok": true}


func take_from_bench(iid: String) -> Dictionary:
	if not _items.has(iid) or _items[iid]["loc"] != "bench":
		return {"ok": false, "reason": "not on bench"}
	_items[iid]["loc"] = "carried"
	_player["carrying"] = iid
	Events.item_moved.emit(iid, "carried")
	return {"ok": true}


func reveal(iid: String, tool: String) -> Dictionary:
	if not _items.has(iid) or not TOOL_ATTRS.has(tool):
		return {"ok": false, "reason": "bad item or tool"}
	var item: Dictionary = _items[iid]
	var found: Array = []
	for c in Content.object_by_id(String(item["def_id"])).get("clues", []):
		var attr: String = String(c.get("attr", ""))
		if (TOOL_ATTRS[tool] as Array).has(attr) and not (item["clues_known"] as Array).has(c["id"]):
			(item["clues_known"] as Array).append(c["id"])
			(item["unknown_attrs"] as Array).erase(attr)
			found.append(c)
			Events.clue_revealed_v2.emit(iid, c)
	return {"ok": true, "clues": found}


func ask(pid: String, q: int) -> Dictionary:
	var lines: Array = ["Left it by the stove car, I think.", "Red. Sort of red.", "It smelled like work."]
	return {"ok": true, "line": lines[clampi(q, 0, 2)], "attr": ["", "color", "smell"][clampi(q, 0, 2)], "value": ["", "red", "smoke"][clampi(q, 0, 2)]}


func hand_over(iid: String, pid: String) -> Dictionary:
	if not _items.has(iid) or not _passengers.has(pid):
		return {"ok": false, "reason": "bad ids"}
	var correct: bool = String(_items[iid]["def_id"]) == String(_passengers[pid]["wants_item_def"])
	var res: Dictionary = {"ok": true, "correct": correct, "was_imposter": false, "tokens": 5 if correct else 0, "rep": 1 if correct else 0, "story": "Bram presses it to his chest.", "line": "Bless you." if correct else "Hm, that's not mine."}
	if correct:
		_items[iid]["loc"] = "delivered"
		_player["tokens"] = int(_player["tokens"]) + 5
		_player["rep"] = int(_player["rep"]) + 1
		_passengers[pid]["state"] = "leaving"
		Events.tokens_changed.emit(_player["tokens"])
		Events.reputation_changed.emit(_player["rep"], _player["tier"])
		Events.passenger_left.emit(pid, true)
	else:
		_items[iid]["loc"] = "shelf"
	Events.handover_result.emit(iid, pid, res)
	return res


func refuse(pid: String) -> Dictionary:
	return {"ok": true, "was_imposter": false, "tokens": 0, "rep": 0, "line": "Oh. Right. Sorry to bother you."}


func call_next() -> Dictionary: return {"ok": true}
func buy(upgrade_id: String) -> Dictionary: return {"ok": false, "reason": "stub"}


func set_time_scale(x: float) -> Dictionary:
	time_scale = clampf(x, 0.0, 100.0)
	return {"ok": true, "time_scale": time_scale}
