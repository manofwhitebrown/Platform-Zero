class_name UTabBar
extends PanelContainer
## Bottom, thumb-friendly tab bar. Emits tab_selected(index). Respects the safe area.
signal tab_selected(index: int)
var _buttons: Array[Button] = []
var _row: HBoxContainer
var _glow: ColorRect
var current := 0

func setup(names: Array) -> void:
	var s := Pal.panel_style(Pal.DEEP, Pal.BRASS, 32)
	s.corner_radius_bottom_left = 0
	s.corner_radius_bottom_right = 0
	s.shadow_offset = Vector2(0, -6)
	add_theme_stylebox_override("panel", s)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	add_child(_row)
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 120)
		b.add_theme_stylebox_override("normal", _flat(Color(0, 0, 0, 0)))
		b.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.05)))
		b.add_theme_stylebox_override("pressed", _flat(Pal.BRASS.darkened(0.4)))
		b.add_theme_color_override("font_color", Pal.MIST)
		b.add_theme_color_override("font_pressed_color", Pal.LAMP)
		b.add_theme_color_override("font_hover_color", Pal.PARCHMENT)
		b.pressed.connect(select.bind(i))
		_row.add_child(b)
		_buttons.append(b)
	select(0, false)
	_apply_safe_area()

func _flat(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(20)
	return s

func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var bottom_inset := maxf(0.0, float(win.y - (safe.position.y + safe.size.y)))
	var st: StyleBoxFlat = get_theme_stylebox("panel")
	st.content_margin_bottom = 12.0 + bottom_inset

func select(i: int, emit: bool = true) -> void:
	current = i
	for j in _buttons.size():
		_buttons[j].set_pressed_no_signal(j == i)
	if emit:
		tab_selected.emit(i)
