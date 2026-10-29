extends Control
## Inspect popup: big icon on a tag; each tap on the icon reveals the next clue as a stamped parchment note (with sparkle).
var item_id := ""
var _item: Dictionary = {}
var _tag: UTag
var _notes: VBoxContainer
var _status: Label
var _panel: UPanel
var _dim: ColorRect

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = Color(0.03, 0.08, 0.1, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			close())
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = UPanel.new()
	_panel.custom_minimum_size = Vector2(min(get_viewport_rect().size.x - 80.0, 900.0), 0)
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	_panel.add_child(v)
	_tag = UTag.new()
	_tag.custom_minimum_size = Vector2(440, 560)
	_tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tag.tapped.connect(_look)
	v.add_child(_tag)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Pal.MIST)
	v.add_child(_status)
	_notes = VBoxContainer.new()
	_notes.add_theme_constant_override("separation", 12)
	v.add_child(_notes)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	var look := UButton.new()
	look.text = "Look closer"
	look.pressed.connect(_look)
	row.add_child(look)
	var done := UButton.new()
	done.text = "Done"
	done.pressed.connect(close)
	row.add_child(done)
	var tw := create_tween()
	tw.tween_property(_dim, "color:a", 0.7, 0.25)
	await get_tree().process_frame
	_panel.pop_in()

func open(id: String) -> void:
	item_id = id
	_item = Content.get_object(id)
	await get_tree().process_frame
	_tag.setup(_item.get("icon", "key"), Color(_item.get("tint", "#ffffff")), _item.get("name", ""))
	var revealed: Array = []
	for it in GameState.get_counter_items():
		if it["id"] == id:
			revealed = it.get("revealed", [])
	for c in _item.get("clues", []):
		if revealed.has(c["id"]):
			_add_note(c["text"], false)
	_update_status()

func _update_status() -> void:
	var total: int = _item.get("clues", []).size()
	var seen := _notes.get_child_count()
	_status.text = "Clues found: %d / %d" % [seen, total]

func _look() -> void:
	var clue: Dictionary = GameState.inspect(item_id)
	# zoom pulse on the tag
	if not Pal.reduced_motion():
		_tag.pivot_offset = _tag.size / 2.0
		var t := create_tween()
		t.tween_property(_tag, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(_tag, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if clue.is_empty():
		_status.text = "That's everything it has to say."
		return
	Sfx.play("clue")
	Sfx.buzz(20)
	_add_note(clue.get("text", ""), true)
	_update_status()
	Sparkle.burst(self, _tag.get_global_rect().get_center() - global_position, Pal.LAMP, 28)

func _add_note(text: String, animate: bool) -> void:
	var card := UCard.new()
	card.add_child(UCard.ink_label(text, 34))
	_notes.add_child(card)
	if animate:
		await get_tree().process_frame
		card.stamp()

func close() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.chain().tween_callback(queue_free)
