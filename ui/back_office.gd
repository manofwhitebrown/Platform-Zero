class_name BackOffice
extends Control
## Station Master's Ledger: password gate, then the categorized cheat panel from Cheats.list().
## Never stores or logs the typed password. Invisible feature unless Cheats.is_available().

var mgr: ScreenManager
var _root: VBoxContainer
var _pw: LineEdit
var _msg: Label
var _status: Label


func _init(p_mgr: ScreenManager = null) -> void:
	mgr = p_mgr


func _ready() -> void:
	theme = load("res://ui/theme/unclaimed_theme.tres")
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Pal.panel_style(Color("#3a2517"), Pal.BRASS))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	add_child(panel)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 14)
	panel.add_child(_root)
	_rebuild()


func _head() -> void:
	var head := HBoxContainer.new()
	_root.add_child(head)
	var t := Ledger._lbl("Station Master's Ledger", 44, Pal.LAMP)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := UButton.new()
	x.text = "Close"
	x.custom_minimum_size = Vector2(190, 100)
	x.pressed.connect(func() -> void: mgr.close_top())
	head.add_child(x)


func _rebuild() -> void:
	for c in _root.get_children():
		c.queue_free()
	_head()
	if Cheats.is_unlocked():
		_panel()
	else:
		_gate()


func _gate() -> void:
	_root.add_child(Ledger._lbl("Stamped. Signed. Sealed.", 30, Pal.PARCHMENT))
	_pw = LineEdit.new()
	_pw.secret = true
	_pw.custom_minimum_size = Vector2(0, 100)
	_pw.add_theme_font_size_override("font_size", 40)
	_pw.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_pw.text_submitted.connect(func(_t: String) -> void: _try())
	_root.add_child(_pw)
	var go := UButton.new()
	go.text = "Open"
	go.custom_minimum_size = Vector2(0, 100)
	go.pressed.connect(_try)
	_root.add_child(go)
	_msg = Ledger._lbl("", 30, Pal.SIGNAL)
	_root.add_child(_msg)


func _try() -> void:
	if Cheats.lockout_left() > 0.0:
		return
	var ok: bool = Cheats.try_unlock(_pw.text)
	_pw.text = ""
	if ok:
		Audio.play("ui_open")
		_rebuild()
	else:
		Audio.play("refuse")
		_msg.text = "No."


func _process(_d: float) -> void:
	if _msg != null and is_instance_valid(_msg) and not Cheats.is_unlocked():
		var left: float = Cheats.lockout_left()
		if left > 0.0:
			_msg.text = "The ledger is shut. %d:%02d" % [int(left) / 60, int(left) % 60]
	if _status != null and is_instance_valid(_status):
		_status.visible = Sim.cheated


func _panel() -> void:
	_status = Ledger._lbl("Cheats used: this save is marked", 26, Pal.MIST)
	_status.visible = Sim.cheated
	_root.add_child(_status)
	_msg = Ledger._lbl("", 26, Pal.LAMP)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_msg)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(sc)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	sc.add_child(body)
	var last_cat: String = ""
	for e in Cheats.list():
		var cat: String = String(e.get("category", ""))
		if cat != last_cat:
			last_cat = cat
			body.add_child(Ledger._lbl(cat.to_upper(), 26, Pal.BRASS))
		body.add_child(_entry(e))
	var lk := UButton.new()
	lk.text = "Lock ledger"
	lk.custom_minimum_size = Vector2(0, 96)
	lk.pressed.connect(func() -> void:
		Cheats.lock()
		_rebuild())
	body.add_child(lk)


func _run(id: String, v: Variant = null) -> void:
	var r: Dictionary = Cheats.run(id, v)
	Audio.play("ui_tap")
	_msg.text = String(r.get("msg", r.get("reason", "Done." if bool(r.get("ok", true)) else "Failed.")))
	if _status != null:
		_status.visible = Sim.cheated


func _entry(e: Dictionary) -> Control:
	var id: String = String(e["id"])
	var args: Dictionary = e.get("args", {})
	var kind: String = String(e.get("kind", "button"))
	var label: String = String(e.get("label", id))
	match kind:
		"slider", "number":
			var box := VBoxContainer.new()
			var l := Ledger._lbl("%s: %d" % [label, int(args.get("default", 0))], 28, Pal.PARCHMENT)
			box.add_child(l)
			var sl := HSlider.new()
			sl.min_value = float(args.get("min", 0))
			sl.max_value = float(args.get("max", 100))
			sl.step = 1
			sl.value = float(args.get("default", 0))
			sl.custom_minimum_size = Vector2(0, 64)
			sl.value_changed.connect(func(v: float) -> void: l.text = "%s: %d" % [label, int(v)])
			box.add_child(sl)
			var ap := UButton.new()
			ap.text = "Apply"
			ap.custom_minimum_size = Vector2(0, 80)
			ap.pressed.connect(func() -> void: _run(id, int(sl.value)))
			box.add_child(ap)
			return box
		"picker", "choice":
			var box2 := VBoxContainer.new()
			box2.add_child(Ledger._lbl(label, 28, Pal.PARCHMENT))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			for o in args.get("options", []):
				var b := UButton.new()
				b.text = str(o)
				b.custom_minimum_size = Vector2(0, 88)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var val: Variant = o
				b.pressed.connect(func() -> void: _run(id, val))
				row.add_child(b)
			box2.add_child(row)
			return box2
		"text":
			var box3 := VBoxContainer.new()
			box3.add_child(Ledger._lbl(label, 28, Pal.PARCHMENT))
			var le := LineEdit.new()
			le.text = str(args.get("default", ""))
			le.custom_minimum_size = Vector2(0, 80)
			le.add_theme_font_size_override("font_size", 32)
			box3.add_child(le)
			var go := UButton.new()
			go.text = "Run"
			go.custom_minimum_size = Vector2(0, 80)
			go.pressed.connect(func() -> void: _run(id, le.text))
			box3.add_child(go)
			return box3
	var bt := UButton.new()
	bt.text = label
	bt.custom_minimum_size = Vector2(0, 88)
	bt.pressed.connect(func() -> void: _run(id))
	return bt
