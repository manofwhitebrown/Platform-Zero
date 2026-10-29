extends Node
## Content loader (STUB: mock data in contract shapes).

var objects: Array = [
	{"id": "obj_001", "name": "Smoky Mitten", "icon": "mitten", "tint": "#C8503C", "rarity": "common", "owner_id": "own_001",
	"clues": [{"id": "c1", "text": "Smells faintly of woodsmoke.", "attr": "smell", "value": "smoke"},
		{"id": "c2", "text": "One thumb is darned in blue wool.", "attr": "wear", "value": "darned"}],
	"story": "Bram warms his hands on it every winter."},
	{"id": "obj_002", "name": "Stopped Pocket Watch", "icon": "watch", "tint": "#B8893E", "rarity": "odd", "owner_id": "own_002",
	"clues": [{"id": "c1", "text": "Engraved with the initials M.T.", "attr": "initials", "value": "MT"},
		{"id": "c2", "text": "It ticks only on Tuesdays.", "attr": "sound", "value": "tick"}],
	"story": "Marta's grandfather wound it every dawn."},
	{"id": "obj_003", "name": "Brass Compass", "icon": "compass", "tint": "#7FA6A3", "rarity": "rare", "owner_id": "own_001",
	"clues": [{"id": "c1", "text": "The needle points at home, not north.", "attr": "wear", "value": "odd needle"},
		{"id": "c2", "text": "Station stamp: Lantern Row.", "attr": "station_stamp", "value": "lantern_row"}],
	"story": "It has never once been wrong."},
]
var owners: Array = [
	{"id": "own_001", "name": "Bram the Stoker", "look": {"skin": "#d9a47a", "hair": "#3b2a20", "coat": "#7FA6A3", "hat": "cap", "accessory": "beard"},
	"lost_item_ids": ["obj_001", "obj_003"], "claim_lines": ["I lost a mitten. Red? Sort of red."],
	"hints": {"obj_001": [{"attr": "smell", "value": "smoke"}], "obj_003": [{"attr": "station_stamp", "value": "lantern_row"}]},
	"thanks_line": "Bless you.", "wrong_line": "Hm, that's not mine.", "arc": []},
	{"id": "own_002", "name": "Marta Tull", "look": {"skin": "#f0c9a0", "hair": "#8a8a8a", "coat": "#B8893E", "hat": "top", "accessory": "glasses"},
	"lost_item_ids": ["obj_002"], "claim_lines": ["Something small. Round. It was my grandfather's."],
	"hints": {"obj_002": [{"attr": "initials", "value": "MT"}]},
	"thanks_line": "Oh, there you are.", "wrong_line": "Not mine, dear.", "arc": []},
	{"id": "own_003", "name": "Pip Ardent", "look": {"skin": "#a9744f", "hair": "#12303B", "coat": "#C8503C", "hat": "none", "accessory": "none"},
	"lost_item_ids": [], "claim_lines": ["I lose things professionally."], "hints": {},
	"thanks_line": "Splendid!", "wrong_line": "Nope.", "arc": []},
]
var warnings: Array = []

func get_object(id: String) -> Dictionary:
	for o in objects:
		if o["id"] == id:
			return o
	return {}

func get_owner(id: String) -> Dictionary:
	for o in owners:
		if o["id"] == id:
			return o
	return {}
