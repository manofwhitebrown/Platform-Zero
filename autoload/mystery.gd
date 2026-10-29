extends Node
## Daily mystery (STUB).

func get_daily() -> Dictionary:
	var owners: Array = Content.owners.slice(0, 3)
	return {"item": Content.objects[0].duplicate(true), "owners": owners, "solved": false, "clues_used": 0}

func guess_daily(owner_id: String) -> Dictionary:
	return {"correct": owner_id == "own_001", "clues_used": 0, "share": share_text()}

func share_text() -> String:
	return "Unclaimed #1 🔎🔎🟩"
