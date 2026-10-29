extends Node
## Global signal bus.

signal object_arrived(item: Dictionary)
signal owner_arrived(owner: Dictionary, wanted_item_id: String)
signal clue_revealed(item_id: String, clue: Dictionary)
signal match_result(item_id: String, owner_id: String, correct: bool, reward: int)
signal shelf_changed()
signal reputation_changed(value: int, tier: int)
signal daily_ready()

# ---- v2 contract signals (Sim emits, world/UI listens) ----
signal train_state_changed(state: String, stop: Dictionary)
signal passenger_spawned(p: Dictionary)
signal passenger_state_changed(pid: String, state: String)
signal passenger_said(pid: String, line: String)
signal passenger_left(pid: String, happy: bool)
signal item_spawned(item: Dictionary, spot_id: String)
signal item_moved(iid: String, loc: String)
signal clue_revealed_v2(iid: String, clue: Dictionary)
signal claimant_waiting(pid: String)
signal handover_result(iid: String, pid: String, result: Dictionary)
signal tokens_changed(v: int)
signal car_unlocked(car_id: String)
signal toast(text: String, kind: String)
signal offline_report(report: Dictionary)
