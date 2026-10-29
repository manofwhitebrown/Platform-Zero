class_name Tiers
extends RefCounted
## Display names for reputation tiers and the station wings they open. (A owns the numbers; this is only labels.)
const NAMES := ["Newcomer", "Clerk", "Keeper", "Stationmaster", "Legend of the Line"]
const WINGS := ["Front Counter", "Lamp Room", "Map Gallery", "Clock Tower", "Moon Platform"]

static func tier_name(t: int) -> String:
	return NAMES[clampi(t, 0, NAMES.size() - 1)]
