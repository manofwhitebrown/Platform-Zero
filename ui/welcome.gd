class_name Welcome
extends Control
## "While you were away" overlay from Events.offline_report. Short, skippable (tap anywhere or the button).

var mgr: ScreenManager
var rpt: Dictionary = {}


func _init(p_mgr: ScreenManager = null, p_rpt: Dictionary = {}) -> void:
	mgr = p_mgr
	rpt = p_rpt


func _ready() -> void:
	theme = load("res://ui/theme/unclaimed_theme.tres")
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Pal.panel_style(Color(Pal.PARCHMENT, 0.98), Pal.BRASS, 26))
	panel.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 80.0, 900.0), 0)
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var h := Ledger._lbl("While you were away", 46, Pal.INK, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	var mins: int = int(rpt.get("away_s", 0)) / 60
	var sub := Ledger._lbl("%d minute%s on the Zero Line%s" % [mins, "" if mins == 1 else "s", " (the night got long)" if bool(rpt.get("capped", false)) else ""], 26, Color(Pal.INK, 0.65), true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var rows: Array = [
		["Stops passed", int(rpt.get("stops", 0)), "watch"],
		["Things found", int(rpt.get("items_found", 0)), "letter"],
		["Tokens earned", int(rpt.get("tokens", 0)), "coin"],
		["Waiting at the counter", int(rpt.get("claimants_waiting", 0)), "ticket"]]
	for r in rows:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		var a := Ledger.ArtBox.new()
		a.item = {"icon": r[2], "tint": "#B8893E", "name": r[0]}
		a.custom_minimum_size = Vector2(76, 76)
		hb.add_child(a)
		var l := Ledger._lbl(String(r[0]), 32, Pal.INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		hb.add_child(Ledger._lbl(str(r[1]), 44, Pal.SIGNAL))
		v.add_child(hb)
	var lines: Array = rpt.get("lines", [])
	if not lines.is_empty():
		var q := Ledger._lbl(String(lines[0]), 28, Color(Pal.INK, 0.85), true)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(q)
	var b := UButton.new()
	b.text = "Back to the train"
	b.custom_minimum_size = Vector2(0, 110)
	b.pressed.connect(func() -> void: mgr.close_top())
	v.add_child(b)
