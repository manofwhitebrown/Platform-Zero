extends Control
## Catalog: reputation tier + wings header, then Objects (locked silhouettes) / Owners (gallery) pages.
var _grid: GridContainer
var _head_tier: Label
var _head_bar: ProgressBar
var _wings: HBoxContainer
var _tab_objects: Button
var _tab_owners: Button
var _mode := 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	var head := UPanel.new()
	col.add_child(head)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	head.add_child(hv)
	_head_tier = Label.new()
	_head_tier.add_theme_font_size_override("font_size", 46)
	_head_tier.add_theme_color_override("font_color", Pal.LAMP)
	_head_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(_head_tier)
	_head_bar = ProgressBar.new()
	_head_bar.show_percentage = false
	_head_bar.custom_minimum_size = Vector2(0, 18)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Pal.DEEP
	bg.set_corner_radius_all(9)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Pal.LAMP
	fg.set_corner_radius_all(9)
	_head_bar.add_theme_stylebox_override("background", bg)
	_head_bar.add_theme_stylebox_override("fill", fg)
	hv.add_child(_head_bar)
	_wings = HBoxContainer.new()
	_wings.alignment = BoxContainer.ALIGNMENT_CENTER
	_wings.add_theme_constant_override("separation", 10)
	hv.add_child(_wings)
	var seg := HBoxContainer.new()
	seg.alignment = BoxContainer.ALIGNMENT_CENTER
	seg.add_theme_constant_override("separation", 16)
	col.add_child(seg)
	_tab_objects = UButton.new()
	_tab_objects.text = "Objects"
	_tab_objects.pressed.connect(_set_mode.bind(0))
	seg.add_child(_tab_objects)
	_tab_owners = UButton.new()
	_tab_owners.text = "Owners"
	_tab_owners.pressed.connect(_set_mode.bind(1))
	seg.add_child(_tab_owners)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 20)
	sc.add_child(m)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 20)
	m.add_child(_grid)
	resized.connect(_cols)
	Events.reputation_changed.connect(func(_v, _t): _refresh_head())
	Events.match_result.connect(func(_a, _b, _c, _d): _fill())
	_cols()
	_refresh_head()
	_fill()

func _cols() -> void:
	_grid.columns = maxi(2, int((size.x - 40.0) / 236.0))

func _set_mode(m: int) -> void:
	_mode = m
	_fill()

func _refresh_head() -> void:
	var tier := GameState.get_tier()
	_head_tier.text = "%s  ·  %d" % [Tiers.tier_name(tier), GameState.get_reputation()]
	_head_bar.max_value = 100
	_head_bar.value = GameState.get_reputation() % 100
	for c in _wings.get_children():
		c.queue_free()
	for i in Tiers.WINGS.size():
		var l := Label.new()
		var open := i <= tier
		l.text = ("◆ " if open else "◇ ") + Tiers.WINGS[i]
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", Pal.LAMP if open else Pal.MIST.darkened(0.4))
		_wings.add_child(l)

func _fill() -> void:
	_tab_objects.disabled = _mode == 0
	_tab_owners.disabled = _mode == 1
	for c in _grid.get_children():
		c.queue_free()
	if _mode == 0:
		for it in GameState.get_catalog():
			_grid.add_child(_object_cell(it))
	else:
		for o in GameState.get_gallery():
			_grid.add_child(_owner_cell(o))

func _object_cell(it: Dictionary) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(220, 290)
	var tag := UTag.new()
	tag.hang = false
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if it.get("discovered", false):
		tag.setup(it.get("icon", "key"), Color(it.get("tint", "#ffffff")), it.get("name", ""))
	else:
		tag.setup(it.get("icon", "key"), Color(0.05, 0.12, 0.15, 0.7), "???")
	tag.size = Vector2(220, 290)
	wrap.add_child(tag)
	return wrap

func _owner_cell(o: Dictionary) -> Control:
	var card := UPanel.new()
	card.custom_minimum_size = Vector2(220, 330)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var pt := Portrait.new()
	pt.animate = false
	pt.custom_minimum_size = Vector2(180, 200)
	pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var met: bool = o.get("met", false)
	pt.set_look(o.get("look", {}))
	if not met:
		pt.modulate = Color(0.02, 0.06, 0.08, 0.8)
	v.add_child(pt)
	var n := Label.new()
	n.text = o.get("name", "") if met else "???"
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.add_theme_font_size_override("font_size", 26)
	v.add_child(n)
	if met:
		var s := Label.new()
		s.text = "Reunited: %d" % int(o.get("matches", 0))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_font_size_override("font_size", 24)
		s.add_theme_color_override("font_color", Pal.LAMP)
		v.add_child(s)
	return card
