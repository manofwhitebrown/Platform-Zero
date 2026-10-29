extends Node
## Global signal bus.

signal object_arrived(item: Dictionary)
signal owner_arrived(owner: Dictionary, wanted_item_id: String)
signal clue_revealed(item_id: String, clue: Dictionary)
signal match_result(item_id: String, owner_id: String, correct: bool, reward: int)
signal shelf_changed()
signal reputation_changed(value: int, tier: int)
signal daily_ready()
