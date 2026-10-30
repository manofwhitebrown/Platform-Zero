class_name Daily
extends Control
## Night Case overlay: today's case, start/resume, solved summary + share card (clipboard + toast).

var mgr: ScreenManager
var _col: VBoxContainer


func _init(p_mgr: ScreenManager = null) -> void:
	mgr = p_mgr


func _ready() -> void:
	theme = load("res://ui/theme/unclaimed_theme.tres")
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Pal.panel_style(Pal.NIGHT, Pal.BRASS))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	add_child(panel)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 18)
	panel.add_child(_col)
	_build()


func _build() -> void:
	for c in _col.get_children():
		c.queue_free()
	var d: Dictionary = Sim.get_daily()
	var head := HBoxContainer.new()
	_col.add_child(head)
	var t := Ledger._lbl("Night Case #%d" % int(d.get("number", 0)), 52, Pal.LAMP)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := UButton.new()
	x.text = "Close"
	x.custom_minimum_size = Vector2(190, 100)
	x.pressed.connect(func() -> void: mgr.close_top())
	head.add_child(x)
	_col.add_child(Ledger._lbl(String(d.get("date", "")), 30, Color(Pal.PARCHMENT, 0.7)))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Pal.panel_style(Color(Pal.PARCHMENT, 0.96), Pal.BRASS, 22))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var done: bool = bool(d.get("done", false))
	var def: Dictionary = Content.object_by_id(String(d.get("def_id", "")))
	var a := Ledger.ArtBox.new()
	a.item = def
	a.dim = not done
	a.custom_minimum_size = Vector2(0, 280)
	v.add_child(a)
	var name_l := Ledger._lbl(String(d.get("title", "")) if done else "A thing nobody has named yet", 42, Pal.INK, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var avail: bool = bool(d.get("available", true))
	var msg: String
	if not avail:
		msg = "The Night Case is only for honest runs. This one used the Back Office."
	elif done:
		msg = "Solved. Come back tomorrow night for a new case."
	elif bool(d.get("started", false)):
		msg = "It is on the train. Find it, examine it, and hand it to the right owner."
	else:
		msg = "One lost thing, one owner, same for everyone tonight. Wrong hand-overs are counted."
	var m := Ledger._lbl(msg, 30, Color(Pal.INK, 0.85), true)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(m)
	if done and avail:
		var sh := Ledger._lbl(String(d.get("share", "")), 34, Pal.INK, true)
		sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sh)
		var cp := UButton.new()
		cp.text = "Copy share card"
		cp.custom_minimum_size = Vector2(0, 110)
		cp.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(String(d.get("share", "")))
			Events.toast.emit("Share card copied.", "good")
			Sfx.play("tap"))
		v.add_child(cp)
	elif avail:
		var go := UButton.new()
		go.text = "Resume the case" if bool(d.get("started", false)) else "Start tonight's case"
		go.custom_minimum_size = Vector2(0, 120)
		go.pressed.connect(func() -> void:
			var r: Dictionary = Sim.start_daily()
			if not bool(r.get("ok", false)):
				Events.toast.emit(String(r.get("reason", "Not right now.")), "info")
			mgr.close_top())
		v.add_child(go)
