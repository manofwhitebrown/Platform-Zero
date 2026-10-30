class_name MapData
extends RefCounted
## C14: view-model for the train map. Built only from Sim.get_map() / get_passengers() + content/map.json.
## build() -> Array of {car_id,name,desc,unlocked,unlock_tier,tier_rep,lock_hint,claimants_waiting,
## items_here,passengers,is_player_car,reachable,x,door_x}.

const MAP_PATH := "res://content/map.json"


static func _texts() -> Dictionary:
	var f := FileAccess.open(MAP_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary and (d as Dictionary).get("cars") is Dictionary:
		return d["cars"]
	return {}


static func build(sim: Node = null) -> Array:
	if sim == null:
		sim = (Engine.get_main_loop() as SceneTree).root.get_node("Sim")
	var texts: Dictionary = _texts()
	var width: float = 1800.0
	var cars: Array = sim.get_cars()
	if not cars.is_empty():
		width = float((cars[0] as Dictionary).get("width", 1800.0))
	var pax: Array = sim.get_passengers()
	var out: Array = []
	for row in sim.get_map():
		var cid: String = String(row["id"])
		var t: Dictionary = texts.get(cid, {})
		var x0: float = float(row["x"])
		var n_pax: int = 0
		for p in pax:
			var px: float = float((p as Dictionary).get("x", -1.0))
			if px >= x0 and px < x0 + width and String((p as Dictionary).get("state", "")) != "leaving":
				n_pax += 1
		out.append({
			"car_id": cid,
			"name": String(t.get("name", row["name"])),
			"desc": String(t.get("desc", "")),
			"unlocked": bool(row["unlocked"]),
			"unlock_tier": int(row["unlock_tier"]),
			"tier_rep": int(row["tier_rep"]),
			"lock_hint": String(t.get("lock_hint", "")),
			"claimants_waiting": int(row["claimants"]),
			"items_here": int(row["items"]),
			"passengers": n_pax,
			"is_player_car": bool(row["here"]),
			"reachable": bool(row["reachable"]),
			"x": x0,
			"door_x": x0 + width - 60.0,
		})
	return out
