extends Control
## The Dusty Shelf: wrongly offered items wait here. Nothing expires. Tap one to look at it again.
const POPUP := preload("res://scenes/inspect_popup.tscn")
var _grid: GridContainer
var _empty: Control
var _title: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(col)
	_title = Label.new()
	_title.text = "The Dusty Shelf"
	_title.add_theme_font_size_override("font_size", 56)
	_title.add_theme_color_override("font_color", Pal.LAMP)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.custom_minimum_size = Vector2(0, 110)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	col.add_child(_title)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 24)
	sc.add_child(m)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 24)
	m.add_child(_grid)
	_empty = CenterContainer.new()
	_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := UPanel.new()
	var l := Label.new()
	l.text = "The shelf is clean.\nFor now."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 46)
	p.add_child(l)
	_empty.add_child(p)
	add_child(_empty)
	resized.connect(func(): _grid.columns = maxi(2, int((size.x - 48.0) / 270.0)))
	Events.shelf_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var items: Array = GameState.get_shelf_items()
	_empty.visible = items.is_empty()
	for it in items:
		var wrap := Control.new()
		wrap.custom_minimum_size = Vector2(250, 330)
		var tag := UTag.new()
		# dusty: desaturated tint, slightly faded, tilted
		var tint := Color(it.get("tint", "#ffffff"))
		tag.setup(it.get("icon", "key"), tint.lerp(Pal.MIST, 0.55), it.get("name", ""))
		tag.size = Vector2(250, 330)
		tag.modulate = Color(0.85, 0.82, 0.78, 0.92)
		tag.tapped.connect(_open.bind(it["id"]))
		wrap.add_child(tag)
		_grid.add_child(wrap)

func _open(id: String) -> void:
	var p = POPUP.instantiate()
	add_child(p)
	p.open(id)
