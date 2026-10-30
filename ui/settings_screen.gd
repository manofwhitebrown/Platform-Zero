class_name SettingsScreen
extends Control
## Settings overlay: volume sliders, haptics, text speed, reduced motion, colorblind icons,
## orientation lock, reset (double confirm), credits.

var mgr: ScreenManager
var _col: VBoxContainer
var _reset_row: HBoxContainer
var _reset_btn: UButton
var _credits: Label


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
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	var t := Ledger._lbl("Settings", 52, Pal.LAMP)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := UButton.new()
	x.text = "Close"
	x.custom_minimum_size = Vector2(190, 100)
	x.pressed.connect(func() -> void: mgr.close_top())
	head.add_child(x)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	_col = VBoxContainer.new()
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_theme_constant_override("separation", 12)
	sc.add_child(_col)
	_build()


func _section(s: String) -> void:
	var l := Ledger._lbl(s.to_upper(), 26, Pal.BRASS)
	l.add_theme_constant_override("line_spacing", 4)
	_col.add_child(l)


func _slider(key: String, label: String) -> void:
	var box := VBoxContainer.new()
	var l := Ledger._lbl("%s  %d%%" % [label, int(Settings.get_float(key, 1.0) * 100.0)], 32, Pal.PARCHMENT)
	box.add_child(l)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = Settings.get_float(key, 1.0)
	sl.custom_minimum_size = Vector2(0, 64)
	style_slider(sl)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(v: float) -> void:
		Settings.set_float(key, v)
		l.text = "%s  %d%%" % [label, int(v * 100.0)])
	sl.drag_ended.connect(func(_c: bool) -> void: Audio.play("ui_tap"))
	box.add_child(sl)
	_col.add_child(box)


func _toggle(key: String, label: String, default: bool) -> void:
	var b := UButton.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 96)
	b.button_pressed = Settings.get_bool(key, default)
	b.text = "%s: %s" % [label, "On" if b.button_pressed else "Off"]
	b.toggled.connect(func(on: bool) -> void:
		Settings.set_bool(key, on)
		b.text = "%s: %s" % [label, "On" if on else "Off"]
		Audio.play("ui_toggle")
		if on and key == "haptics":
			Haptics.buzz(40))
	_col.add_child(b)


func _choice(key: String, label: String, opts: Array, default: String) -> void:
	_col.add_child(Ledger._lbl(label, 32, Pal.PARCHMENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var btns: Array = []
	for o in opts:
		var b := UButton.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = String(o[1])
		b.button_pressed = Settings.get_str(key, default) == String(o[0])
		var val: String = String(o[0])
		b.pressed.connect(func() -> void:
			Settings.set_str(key, val)
			Audio.play("ui_toggle")
			for bb in btns:
				(bb as Button).set_pressed_no_signal(bb == b))
		btns.append(b)
		row.add_child(b)
	_col.add_child(row)


func _build() -> void:
	_section("Sound")
	_slider("vol_master", "Master")
	_slider("vol_sfx", "Effects")
	_slider("vol_ambience", "Ambience")
	_slider("vol_music", "Music")
	_section("Feel")
	_toggle("haptics", "Haptics", true)
	_toggle("reduced_motion", "Reduce motion", false)
	_toggle("colorblind", "Mood icons on bubbles", false)
	_choice("text_speed", "Text speed", [["slow", "Slow"], ["normal", "Normal"], ["fast", "Fast"]], "normal")
	_section("Screen")
	_choice("orientation", "Orientation", [["auto", "Auto"], ["portrait", "Portrait"], ["landscape", "Landscape"]], "auto")
	_section("Game")
	_reset_btn = UButton.new()
	_reset_btn.text = "Reset game"
	_reset_btn.custom_minimum_size = Vector2(0, 96)
	_reset_btn.pressed.connect(_ask_reset)
	_col.add_child(_reset_btn)
	_reset_row = HBoxContainer.new()
	_reset_row.visible = false
	_reset_row.add_theme_constant_override("separation", 10)
	_col.add_child(_reset_row)
	var cr := UButton.new()
	cr.text = "Credits"
	cr.custom_minimum_size = Vector2(0, 96)
	cr.pressed.connect(func() -> void:
		_credits.visible = not _credits.visible)
	_col.add_child(cr)
	_credits = Ledger._lbl("Platform Zero\nA night train that never reaches its last stop.\n\nMade by Mohammed Abdul Nayeem.\nArt, sound and story are handmade and procedural.\nThanks for looking after Lost Property.", 28, Pal.MIST)
	_credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credits.visible = false
	_col.add_child(_credits)


func _ask_reset() -> void:
	for c in _reset_row.get_children():
		c.queue_free()
	_reset_btn.visible = false
	_reset_row.visible = true
	var keep := UButton.new()
	keep.text = "Keep playing"
	keep.custom_minimum_size = Vector2(0, 96)
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep.pressed.connect(func() -> void:
		_reset_row.visible = false
		_reset_btn.visible = true)
	_reset_row.add_child(keep)
	var go := UButton.new()
	go.text = "Erase everything?"
	go.custom_minimum_size = Vector2(0, 96)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stage := [0]
	go.pressed.connect(func() -> void:
		if stage[0] == 0:
			stage[0] = 1
			go.text = "Yes, I'm sure"
			return
		Sim.new_game(int(Time.get_unix_time_from_system()) % 100000)
		Sim.save_game()
		mgr.close_all()
		get_tree().reload_current_scene())
	_reset_row.add_child(go)


static var _grab: ImageTexture


## Brass-styled slider (default Godot slider is thin grey with a tiny dot).
static func style_slider(sl: HSlider) -> void:
	if _grab == null:
		var img := Image.create(56, 56, false, Image.FORMAT_RGBA8)
		for y in 56:
			for x in 56:
				var d: float = Vector2(x - 27.5, y - 27.5).length()
				if d <= 26.0:
					img.set_pixel(x, y, Pal.LAMP if d > 20.0 else Pal.BRASS.lightened(0.15))
		_grab = ImageTexture.create_from_image(img)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(Pal.DEEP, 0.9)
	bg.set_corner_radius_all(10)
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	var fill := StyleBoxFlat.new()
	fill.bg_color = Pal.BRASS
	fill.set_corner_radius_all(10)
	fill.content_margin_top = 10
	fill.content_margin_bottom = 10
	sl.add_theme_stylebox_override("slider", bg)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	sl.add_theme_icon_override("grabber", _grab)
	sl.add_theme_icon_override("grabber_highlight", _grab)
