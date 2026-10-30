class_name HelpScreen
extends Control
## How-to-play cards from content/help.json, plus a random tip. Also hosts Tips.random().

var mgr: ScreenManager


static func random_tip() -> String:
	var f := FileAccess.open("res://content/tips.json", FileAccess.READ)
	if f == null:
		return ""
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary and (d as Dictionary).get("tips") is Array and not (d["tips"] as Array).is_empty():
		var t: Variant = (d["tips"] as Array).pick_random()
		return String((t as Dictionary).get("text", "")) if t is Dictionary else str(t)
	return ""


func _init(p_mgr: ScreenManager = null) -> void:
	mgr = p_mgr


func _ready() -> void:
	theme = load("res://ui/theme/unclaimed_theme.tres")
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Pal.panel_style(Pal.NIGHT, Pal.BRASS))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	add_child(panel)
	resized.connect(func() -> void:
		var m: float = maxf(16.0, (size.x - 1000.0) / 2.0)
		panel.offset_left = m
		panel.offset_right = -m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var t := Ledger._lbl("How to play", 52, Pal.LAMP)
	Secrets.on_taps(t, 5, ["Every lost thing is waiting for someone.", "The kettle in Dining is always warm.", "Bram says hello."], "steam_hiss")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := UButton.new()
	x.text = "Got it"
	x.custom_minimum_size = Vector2(190, 100)
	x.pressed.connect(func() -> void: mgr.close_top())
	head.add_child(x)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	sc.add_child(body)
	var cards: Array = []
	var f := FileAccess.open("res://content/help.json", FileAccess.READ)
	if f != null:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary and (d as Dictionary).get("cards") is Array:
			cards = d["cards"]
	var n: int = 0
	for c in cards:
		n += 1
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", Pal.panel_style(Color(Pal.PARCHMENT, 0.96), Pal.BRASS, 18))
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		pc.add_child(v)
		v.add_child(Ledger._lbl("%d.  %s" % [n, String(c.get("title", ""))], 34, Pal.SIGNAL, true))
		for ln in c.get("lines", []):
			v.add_child(Ledger._lbl(String(ln), 27, Color(Pal.INK, 0.9), true))
		body.add_child(pc)
	if cards.is_empty():
		body.add_child(Ledger._lbl("Look around, pick things up, use the bench, hand things back.", 32, Pal.PARCHMENT, true))
	var tip: String = random_tip()
	if tip != "":
		body.add_child(Ledger._lbl("Tip: " + tip, 28, Pal.MIST, true))
