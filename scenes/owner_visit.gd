extends Control
## Owner visit overlay. main.gd calls setup(owner, wanted_item_id) after adding this scene.
## Flow: owner walks in -> claim lines type out -> player taps or drags an item onto the owner -> try_match -> reaction.
var owner_data: Dictionary = {}
var wanted_id := ""
var _portrait: Portrait
var _bubble_label: Label
var _bubble: UCard
var _chips_row: HBoxContainer
var _leave: UButton
var _line_idx := 0
var _lines: Array = []
var _typing: Tween
var _done := false
var _chips := {}  # item_id -> Control
var _drag_chip: Control
var _ghost: UTag
var _drag_moved := 0.0
var _story_layer: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.08, 0.1, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 20)
	col.offset_top = 80
	col.offset_bottom = -40
	col.offset_left = 40
	col.offset_right = -40
	add_child(col)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 640)
	col.add_child(stage)
	_portrait = Portrait.new()
	_portrait.custom_minimum_size = Vector2(520, 620)
	_portrait.size = Vector2(520, 620)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_portrait)
	_portrait.resized.connect(func(): pass)
	stage.resized.connect(func():
		_portrait.position = Vector2((stage.size.x - _portrait.size.x) / 2.0, 0))
	_bubble = UCard.new()
	_bubble.custom_minimum_size = Vector2(0, 190)
	_bubble.gui_input.connect(_bubble_input)
	_bubble_label = UCard.ink_label("", 38)
	_bubble.add_child(_bubble_label)
	col.add_child(_bubble)
	var hint := Label.new()
	hint.text = "Tap or drag an item to offer it"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Pal.MIST)
	hint.add_theme_font_size_override("font_size", 30)
	col.add_child(hint)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 250)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	_chips_row = HBoxContainer.new()
	_chips_row.add_theme_constant_override("separation", 14)
	sc.add_child(_chips_row)
	_leave = UButton.new()
	_leave.text = "Come back later"
	_leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_leave.pressed.connect(close)
	col.add_child(_leave)

func setup(owner: Dictionary, wanted_item_id: String) -> void:
	owner_data = owner
	wanted_id = wanted_item_id
	_portrait.set_look(owner.get("look", {}))
	_lines = _build_lines()
	_fill_chips()
	_walk_in()

func _build_lines() -> Array:
	var out: Array = []
	var matches := 0
	for g in GameState.get_gallery():
		if g.get("id", "") == owner_data.get("id", ""):
			matches = int(g.get("matches", 0))
	var arc_line := ""
	for a in owner_data.get("arc", []):
		if matches >= int(a.get("after_matches", 99)):
			arc_line = a.get("line", "")
	if arc_line != "":
		out.append(arc_line)
	out.append_array(owner_data.get("claim_lines", ["I lost something..."]))
	return out

func _fill_chips() -> void:
	for it in GameState.get_counter_items():
		var chip := Control.new()
		chip.custom_minimum_size = Vector2(150, 220)
		var tag := UTag.new()
		tag.setup(it.get("icon", "key"), Color(it.get("tint", "#ffffff")), "")
		tag.size = Vector2(150, 220)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(tag)
		chip.set_meta("item", it)
		chip.gui_input.connect(_chip_input.bind(chip))
		_chips_row.add_child(chip)
		_chips[it["id"]] = chip

func _walk_in() -> void:
	if Pal.reduced_motion():
		_say(_lines[0])
		return
	_portrait.modulate.a = 0.0
	await get_tree().process_frame
	var target_x := _portrait.position.x
	_portrait.position.x = -600.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_portrait, "position:x", target_x, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_portrait, "modulate:a", 1.0, 0.4)
	await t.finished
	_say(_lines[0])

func _say(text: String) -> void:
	_bubble_label.text = text
	if Pal.reduced_motion():
		_bubble_label.visible_ratio = 1.0
		return
	_bubble_label.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_bubble_label, "visible_ratio", 1.0, maxf(0.4, text.length() * 0.03))

func _bubble_input(e: InputEvent) -> void:
	if _done:
		return
	if e is InputEventMouseButton and e.pressed:
		_line_idx = (_line_idx + 1) % _lines.size()
		_say(_lines[_line_idx])

# --- offering items ---
func _chip_input(e: InputEvent, chip: Control) -> void:
	if _done:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_drag_chip = chip
			_drag_moved = 0.0
		elif _drag_chip == chip:
			var over := _portrait.get_global_rect().grow(60).has_point(get_global_mouse_position())
			var tapped := _drag_moved < 12.0
			_end_drag()
			_drag_chip = null
			if over or tapped:
				_offer(chip)
	elif e is InputEventMouseMotion and _drag_chip == chip:
		_drag_moved += e.relative.length()
		if _drag_moved >= 12.0:
			if _ghost == null:
				var it: Dictionary = chip.get_meta("item")
				_ghost = UTag.new()
				_ghost.setup(it.get("icon", "key"), Color(it.get("tint", "#ffffff")), "")
				_ghost.size = Vector2(170, 250)
				_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(_ghost)
				chip.modulate.a = 0.35
			_ghost.global_position = get_global_mouse_position() - Vector2(85, 30)

func _end_drag() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if _drag_chip:
		_drag_chip.modulate.a = 1.0

func _offer(chip: Control) -> void:
	var it: Dictionary = chip.get_meta("item")
	var res: Dictionary = GameState.try_match(it["id"], owner_data["id"])
	if res.get("correct", false):
		_on_correct(res, chip)
	else:
		_on_wrong(res, chip)

func _on_wrong(res: Dictionary, chip: Control) -> void:
	_portrait.emote("neutral")
	Sfx.play("wrong")
	_say(res.get("line", "Hm, that's not mine."))
	_chips.erase(chip.get_meta("item")["id"])
	if Pal.reduced_motion():
		chip.queue_free()
		return
	# item slides away toward the shelf
	var t := create_tween().set_parallel(true)
	t.tween_property(chip, "modulate:a", 0.0, 0.5)
	t.tween_property(chip.get_child(0), "position:y", 260.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(chip.queue_free)

func _on_correct(res: Dictionary, chip: Control) -> void:
	_done = true
	_portrait.emote("happy")
	Sfx.play("correct")
	Sfx.buzz(60)
	_say(res.get("line", "Bless you."))
	Sparkle.burst(self, _portrait.get_global_rect().get_center() - global_position, Pal.LAMP, 60, "confetti")
	chip.queue_free()
	_leave.visible = false
	await get_tree().create_timer(0.9 if not Pal.reduced_motion() else 0.0).timeout
	_show_story(res)

func _show_story(res: Dictionary) -> void:
	_story_layer = CenterContainer.new()
	_story_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_story_layer)
	var card := UCard.new()
	card.custom_minimum_size = Vector2(820, 0)
	_story_layer.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	card.add_child(v)
	var title := UCard.ink_label("REUNITED", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Pal.SIGNAL)
	v.add_child(title)
	v.add_child(UCard.ink_label(res.get("story", ""), 36))
	var reward := UCard.ink_label("+0", 64)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_color_override("font_color", Pal.BRASS)
	v.add_child(reward)
	var b := UButton.new()
	b.text = "Lovely"
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(close)
	v.add_child(b)
	await get_tree().process_frame
	card.stamp()
	var total: int = int(res.get("reward", 0))
	if Pal.reduced_motion():
		reward.text = "+%d" % total
	else:
		var t := create_tween()
		t.tween_method(func(x): reward.text = "+%d" % int(x), 0.0, float(total), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func close() -> void:
	_end_drag()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)
