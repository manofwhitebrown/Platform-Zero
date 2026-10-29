extends Node2D
## Test scene: the attendant, the 15 regulars and some ambient passengers in assorted poses.

const ANIMS := ["idle", "wave", "wring", "tap", "peek", "cross", "lean", "hop", "slump", "huff", "walk", "sit", "hand", "idle", "idle", "idle"]
const MOODS := ["calm", "calm", "worried", "hurried", "shy", "grumpy", "calm", "calm", "worried", "grumpy", "hurried", "calm", "shy", "calm", "calm", "calm"]
var _names: Array = []


func _ready() -> void:
	var owners: Array = Content.owners if "owners" in Content else []
	var f := FileAccess.open("res://content/owners.json", FileAccess.READ)
	var data: Array = JSON.parse_string(f.get_as_text())
	var cols: int = 6
	for i in range(data.size() + 3):
		var p := Passenger.new()
		var lk: Dictionary
		var nm: String
		if i < data.size():
			lk = data[i]["look"]
			nm = String(data[i]["name"])
		elif i == data.size():
			lk = {"skin": "#e8b88f", "hair": "#2a1d14", "coat": "#12303B", "hat": "cap", "accessory": "none", "build": "avg", "height": 1.0, "hair_style": "short", "pants": "#1a2a33", "shoes": "#14100d"}
			nm = "Attendant"
		else:
			lk = Passenger.make_look(i * 13)
			nm = "ambient %d" % i
		var col: int = i % cols
		var row: int = i / cols
		p.position = Vector2(100 + col * 176, 560 + row * 520)
		add_child(p)
		p.setup(lk, MOODS[i % MOODS.size()], nm)
		var a: String = ANIMS[i % ANIMS.size()]
		if a == "walk":
			p._walk_ph = 0.9
			p.anim = "walk"
			p._t = 0.0
			p.play("walk")
		else:
			p.play(a)
		p.face = 1 if i % 2 == 0 else -1
		if i == 9:
			p.do_emote("steam")
		if i == 7:
			p.do_emote("hearts")
		if i == 4:
			p.do_emote("sweat")
		_names.append([p.position, nm + "\n" + a])
	# freeze walk phase for the picture
	await get_tree().process_frame
	queue_redraw()
	if ShotHook.wanted():
		add_child(ShotHook.new())


func _draw() -> void:
	var vp: Vector2 = Vector2(1080, 1920)
	Dr.vgrad(self, Rect2(0, 0, vp.x, vp.y), Color("#1d3a44"), Color("#0b1e26"))
	for r in range(3):
		var y: float = 560 + r * 520
		draw_rect(Rect2(0, y, vp.x, 6), Color(Pal.BRASS.r, Pal.BRASS.g, Pal.BRASS.b, 0.5))
		Dr.vgrad(self, Rect2(0, y + 6, vp.x, 30), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0))
	for n in _names:
		var p: Vector2 = n[0]
		var lines: PackedStringArray = String(n[1]).split("\n")
		draw_string(ThemeDB.fallback_font, p + Vector2(-70, 44), lines[0], HORIZONTAL_ALIGNMENT_CENTER, 140, 17, Pal.PARCHMENT)
		draw_string(ThemeDB.fallback_font, p + Vector2(-70, 64), lines[1], HORIZONTAL_ALIGNMENT_CENTER, 140, 15, Pal.MIST)
