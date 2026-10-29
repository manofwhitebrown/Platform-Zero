extends Control
## The Counter: lost objects sit on the counter as icons on swinging claim tags. Tap one to inspect.
const POPUP := preload("res://scenes/inspect_popup.tscn")
const TAG_SIZE := Vector2(250, 330)
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty: Control
var _header: Label
var _tags := {}  # item_id -> wrapper

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 56)
	_header.add_theme_color_override("font_color", Pal.LAMP)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.custom_minimum_size = Vector2(0, 110)
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	col.add_child(_header)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 24)
	_scroll.add_child(margin)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 24)
	margin.add_child(_grid)
	_empty = _make_empty()
	add_child(_empty)
	resized.connect(_relayout)
	Events.object_arrived.connect(_on_arrived)
	Events.match_result.connect(func(_a, _b, _c, _d): _refresh())
	Events.shelf_changed.connect(_refresh)
	Events.reputation_changed.connect(func(_v, _t): _update_header())
	_refresh(true)

func _make_empty() -> Control:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := UPanel.new()
	var l := Label.new()
	l.text = "Nothing new.\nTea's on the kettle."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 46)
	p.add_child(l)
	c.add_child(p)
	return c

func _relayout() -> void:
	_grid.columns = maxi(2, int((size.x - 48.0) / (TAG_SIZE.x + 20.0)))

func _update_header() -> void:
	_header.text = "The Counter  ·  %d" % GameState.get_reputation()

func _refresh(first: bool = false) -> void:
	_relayout()
	_update_header()
	var items: Array = GameState.get_counter_items()
	var ids := {}
	for it in items:
		ids[it["id"]] = true
	for id in _tags.keys():
		if not ids.has(id):
			var w: Control = _tags[id]
			_tags.erase(id)
			var t := create_tween()
			t.tween_property(w, "modulate:a", 0.0, 0.25)
			t.tween_callback(w.queue_free)
	var n := 0
	for it in items:
		if not _tags.has(it["id"]):
			_add_tag(it, n * 0.09 if first else 0.0)
			n += 1
	_empty.visible = items.is_empty()

func _on_arrived(item: Dictionary) -> void:
	if _tags.has(item.get("id", "")):
		return
	_add_tag(item, 0.0)
	_empty.visible = false

func _add_tag(item: Dictionary, delay: float) -> void:
	var wrap := Control.new()
	wrap.custom_minimum_size = TAG_SIZE
	var tag := UTag.new()
	tag.setup(item.get("icon", "key"), Color(item.get("tint", "#ffffff")), item.get("name", ""))
	tag.size = TAG_SIZE
	tag.tapped.connect(_open.bind(item["id"]))
	wrap.add_child(tag)
	_grid.add_child(wrap)
	_tags[item["id"]] = wrap
	_scroll.get_v_scroll_bar()
	if Pal.reduced_motion():
		return
	# physical drop: fall from above, squash on landing, tag swings on its own
	tag.position.y = -TAG_SIZE.y * 1.4
	tag.modulate.a = 0.0
	tag.pivot_offset = Vector2(TAG_SIZE.x / 2.0, 0)
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(tag, "modulate:a", 1.0, 0.08)
	t.tween_property(tag, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		if is_instance_valid(tag):
			tag.swing())

func _open(item_id: String) -> void:
	var popup = POPUP.instantiate()
	add_child(popup)
	popup.open(item_id)
