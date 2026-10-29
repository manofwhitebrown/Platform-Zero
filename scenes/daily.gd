extends Control
## Daily Mystery: one object, three suspects. Reveal clues, pick the owner, share a spoiler-free result card.
var _daily: Dictionary = {}
var _shown := 1
var _solved := false
var _body: VBoxContainer
var _notes: VBoxContainer
var _status: Label
var _more: UButton
var _share_btn: UButton
var _toast: Label
var _guess_btns := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Events.daily_ready.connect(_build)
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_daily = Mystery.get_daily()
	_solved = _daily.get("solved", false)
	_shown = maxi(1, int(_daily.get("clues_used", 0)))
	_guess_btns.clear()
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 28)
	sc.add_child(m)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 20)
	m.add_child(_body)
	var title := Label.new()
	title.text = "Daily Mystery"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Pal.LAMP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(title)
	var item: Dictionary = _daily.get("item", {})
	var tag := UTag.new()
	tag.hang = false
	tag.custom_minimum_size = Vector2(300, 400)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.setup(item.get("icon", "key"), Color(item.get("tint", "#ffffff")), item.get("name", ""))
	_body.add_child(tag)
	_notes = VBoxContainer.new()
	_notes.add_theme_constant_override("separation", 10)
	_body.add_child(_notes)
	_more = UButton.new()
	_more.text = "Look for another clue"
	_more.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_more.pressed.connect(_more_clue)
	_body.add_child(_more)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Pal.MIST)
	_body.add_child(_status)
	_render_notes(false)
	var who := Label.new()
	who.text = "Whose is it?"
	who.add_theme_font_size_override("font_size", 44)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(who)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_body.add_child(row)
	for o in _daily.get("owners", []):
		row.add_child(_suspect(o))
	_share_btn = UButton.new()
	_share_btn.text = "Share result"
	_share_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_share_btn.visible = _solved
	_share_btn.pressed.connect(_share)
	_body.add_child(_share_btn)
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", Pal.LAMP)
	_body.add_child(_toast)
	if _solved:
		_lock_guesses()
		_status.text = "Solved. Come back tomorrow."

func _suspect(o: Dictionary) -> Control:
	var p := UPanel.new()
	p.custom_minimum_size = Vector2(190, 0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var pt := Portrait.new()
	pt.animate = false
	pt.custom_minimum_size = Vector2(160, 190)
	pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pt.set_look(o.get("look", {}))
	v.add_child(pt)
	var n := Label.new()
	n.text = o.get("name", "")
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", 26)
	v.add_child(n)
	var line := Label.new()
	line.text = o.get("claim_lines", [""])[0]
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 22)
	line.add_theme_color_override("font_color", Pal.MIST)
	v.add_child(line)
	var b := UButton.new()
	b.text = "It's theirs"
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(_guess.bind(o.get("id", ""), p, pt))
	v.add_child(b)
	_guess_btns[o.get("id", "")] = b
	return p

func _render_notes(animate: bool) -> void:
	var clues: Array = _daily.get("item", {}).get("clues", [])
	var count := mini(_shown, clues.size())
	while _notes.get_child_count() < count:
		var card := UCard.new()
		card.add_child(UCard.ink_label(clues[_notes.get_child_count()].get("text", ""), 32))
		_notes.add_child(card)
		if animate:
			await get_tree().process_frame
			card.stamp()
	_more.visible = _shown < clues.size() and not _solved

func _more_clue() -> void:
	if Mystery.has_method("reveal_daily_clue"):
		Mystery.reveal_daily_clue()
	_shown += 1
	_render_notes(true)

func _guess(owner_id: String, panel: Control, pt: Portrait) -> void:
	if _solved:
		return
	var res: Dictionary = Mystery.guess_daily(owner_id)
	if res.get("correct", false):
		_solved = true
		pt.emote("happy")
		Sfx.play("correct")
		Sfx.buzz(60)
		Sparkle.burst(self, panel.get_global_rect().get_center() - global_position, Pal.LAMP, 60, "confetti")
		_status.text = "Solved! Well spotted."
		_lock_guesses()
		_share_btn.visible = true
		_more.visible = false
	else:
		pt.emote("neutral")
		_guess_btns[owner_id].disabled = true
		_status.text = "Not quite. Perhaps another clue?"

func _lock_guesses() -> void:
	for b in _guess_btns.values():
		b.disabled = true

# --- shareable card ---
func _share() -> void:
	_share_btn.disabled = true
	var img := await _render_card()
	var path := "user://unclaimed_daily.png"
	if img:
		img.save_png(path)
		# best effort: gallery folder (needs storage permission on Android; harmless if it fails)
		var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
		if pics != "":
			img.save_png(pics.path_join("unclaimed_daily.png"))
	DisplayServer.clipboard_set(Mystery.share_text())
	_toast.text = "Result copied. Card saved."
	_share_btn.disabled = false

func _render_card() -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(1080, 1350)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var root := Control.new()
	root.theme = load("res://ui/theme/unclaimed_theme.tres")
	root.size = Vector2(1080, 1350)
	vp.add_child(root)
	var bg := ColorRect.new()
	bg.color = Pal.DEEP
	bg.size = root.size
	root.add_child(bg)
	var glow := ColorRect.new()
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/lamp_glow.gdshader")
	gm.set_shader_parameter("intensity", 0.9)
	glow.material = gm
	glow.size = Vector2(1400, 1400)
	glow.position = Vector2(-160, -300)
	root.add_child(glow)
	var col := VBoxContainer.new()
	col.size = root.size
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 30)
	root.add_child(col)
	var t := Label.new()
	t.text = "PLATFORM ZERO"
	t.add_theme_font_size_override("font_size", 110)
	t.add_theme_color_override("font_color", Pal.LAMP)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var tag := UTag.new()
	tag.hang = false
	tag.custom_minimum_size = Vector2(420, 560)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var item: Dictionary = _daily.get("item", {})
	tag.setup(item.get("icon", "key"), Color(0.05, 0.12, 0.15, 0.75), "???")  # silhouette: spoiler-free
	col.add_child(tag)
	var s := Label.new()
	s.text = Mystery.share_text()
	s.add_theme_font_size_override("font_size", 84)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(s)
	var f := Label.new()
	f.text = "Can you find the owner?"
	f.add_theme_font_size_override("font_size", 44)
	f.add_theme_color_override("font_color", Pal.MIST)
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(f)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img
