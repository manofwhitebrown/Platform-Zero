class_name ClaimUI
extends CanvasLayer
## Screen-space controls for the claimant at the counter:
## - 3 interview buttons (Sim.ask), Refuse stamp from tier 2 (Sim.refuse)
## - tray of items (carried / bench / shelf): drag one onto the claimant, or tap it (Sim.hand_over)
## - story card after a correct handover

const QUESTIONS: PackedStringArray = ["Where did you last have it?", "What does it look like?", "Anything special?"]
const CHIP: float = 128.0

var world: Node2D
var crowd: Crowd
var root: Control
var ask_box: BoxContainer
var ask_buttons: Array = []
var refuse_btn: UButton
var tray_wrap: VBoxContainer
var tray: HBoxContainer
var hint: Label
var card: PanelContainer
var _card_t: float = 0.0
var _asked: Dictionary = {}
var _tray_sig: String = ""
var _last_vis: Vector2 = Vector2.ZERO
var _front: String = ""
var _drag_iid: String = ""
var _drag_ghost: TextureRect
var _drag_moved: bool = false
var _press_pos: Vector2 = Vector2.ZERO


class Chip extends Control:
	var iid: String = ""
	var tex: Texture2D
	var tint: Color = Color.WHITE
	var tag: String = ""
	var ui: ClaimUI

	func _ready() -> void:
		custom_minimum_size = Vector2(ClaimUI.CHIP, ClaimUI.CHIP)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (e as InputEventMouseButton).pressed:
			ui.begin_drag(iid, tex, tint, get_global_mouse_position())

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var dragging: bool = ui != null and ui._drag_iid == iid
		draw_circle(c + Vector2(0, 6), 58.0, Color(0, 0, 0, 0.35))
		draw_circle(c, 58.0, Color(Pal.NIGHT.r, Pal.NIGHT.g, Pal.NIGHT.b, 0.96))
		draw_arc(c, 58.0, 0, TAU, 40, Pal.BRASS if not dragging else Pal.LAMP, 4.0)
		draw_arc(c, 50.0, 0, TAU, 40, Color(1, 1, 1, 0.08), 2.0)
		if tex:
			var s: float = 74.0
			draw_texture_rect(tex, Rect2(c.x - s * 0.5, c.y - s * 0.5 - 4.0, s, s), false, Color(tint.r, tint.g, tint.b, 0.35 if dragging else 1.0))
		if tag != "":
			var f: Font = ThemeDB.fallback_font
			var w: float = f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(f, Vector2(c.x - w * 0.5, size.y - 4.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.PARCHMENT)


func setup(p_world: Node2D, p_crowd: Crowd) -> void:
	world = p_world
	crowd = p_crowd
	layer = 30
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = load("res://ui/theme/unclaimed_theme.tres")
	add_child(root)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 14)
	col.offset_top = -560
	col.offset_bottom = -34
	root.add_child(col)

	tray_wrap = VBoxContainer.new()
	tray_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_wrap.alignment = BoxContainer.ALIGNMENT_END
	tray_wrap.add_theme_constant_override("separation", 6)
	col.add_child(tray_wrap)
	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Pal.PARCHMENT)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	hint.add_theme_constant_override("outline_size", 8)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_wrap.add_child(hint)
	tray = HBoxContainer.new()
	tray.alignment = BoxContainer.ALIGNMENT_CENTER
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_theme_constant_override("separation", 18)
	tray_wrap.add_child(tray)

	ask_box = BoxContainer.new()
	ask_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ask_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ask_box.add_theme_constant_override("separation", 12)
	col.add_child(ask_box)
	for i in range(3):
		var b := UButton.new()
		b.text = QUESTIONS[i]
		b.add_theme_font_size_override("font_size", 28)
		b.custom_minimum_size = Vector2(0, 84)
		b.pressed.connect(_ask.bind(i))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ask_box.add_child(b)
		ask_buttons.append(b)
	refuse_btn = UButton.new()
	refuse_btn.text = "Refuse"
	refuse_btn.add_theme_font_size_override("font_size", 28)
	refuse_btn.custom_minimum_size = Vector2(0, 84)
	refuse_btn.pressed.connect(_refuse)
	refuse_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ask_box.add_child(refuse_btn)

	card = PanelContainer.new()
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_card_input)
	root.add_child(card)

	crowd.handover_story.connect(_show_story)
	_layout()


func _layout() -> void:
	var vis: Vector2 = get_viewport().get_visible_rect().size
	_last_vis = vis
	var portrait: bool = vis.y > vis.x
	ask_box.vertical = portrait
	for b in ask_buttons:
		(b as Button).custom_minimum_size = Vector2(760 if portrait else 0, 84 if portrait else 96)
		(b as Button).add_theme_font_size_override("font_size", 30 if portrait else 26)
	refuse_btn.custom_minimum_size = Vector2(760 if portrait else 0, 84 if portrait else 96)
	hint.add_theme_font_size_override("font_size", 28 if portrait else 24)
	var col: Control = ask_box.get_parent() as Control
	col.offset_top = -560 if portrait else -330
	col.offset_left = 0
	col.offset_right = 0


func _process(delta: float) -> void:
	if get_viewport().get_visible_rect().size != _last_vis:
		_layout()
	_front = crowd.front_pid()
	var show_ui: bool = _front != "" and not card.visible
	ask_box.visible = show_ui
	var tier: int = int(Sim.get_player().get("tier", 0))
	refuse_btn.visible = tier >= 2
	if show_ui:
		_refresh_tray()
		var nm: String = _name_of(_front)
		hint.text = "Drag an item onto %s, or tap it" % nm if tray.get_child_count() > 0 else "Find something that might be theirs"
		for i in range(3):
			(ask_buttons[i] as Button).modulate.a = 0.55 if (_asked.get(_front, []) as Array).has(i) else 1.0
	tray_wrap.visible = show_ui
	if not show_ui and _drag_iid == "":
		crowd.set_drop_target("")
	if card.visible:
		_card_t += delta
		if _card_t > 8.0:
			card.visible = false


func _name_of(pid: String) -> String:
	for p in Sim.get_passengers():
		if String(p["pid"]) == pid:
			return String(p.get("name", "them")).split(" ")[0]
	return "them"


func _ask(i: int) -> void:
	if _front == "":
		return
	if not _asked.has(_front):
		_asked[_front] = []
	(_asked[_front] as Array).append(i)
	Sim.ask(_front, i)


func _refuse() -> void:
	if _front == "":
		return
	var r: Dictionary = Sim.refuse(_front)
	if bool(r.get("ok", false)):
		crowd._on_said(_front, String(r.get("line", "")))


# ------------------------------------------------------------------ tray
func _refresh_tray() -> void:
	var ids: Array = []
	var carried: String = String(Sim.get_player().get("carrying", ""))
	if carried != "":
		ids.append(carried)
	for loc in ["bench", "shelf"]:
		for it in Sim.get_items_at(loc):
			var iid: String = String((it as Dictionary).get("iid", ""))
			if iid != "" and not ids.has(iid):
				ids.append(iid)
	ids = ids.slice(0, 5)
	var sig: String = ",".join(PackedStringArray(ids)) + "|" + _drag_iid
	if sig == _tray_sig:
		return
	_tray_sig = sig
	for c in tray.get_children():
		c.queue_free()
	for iid in ids:
		var item: Dictionary = Sim.get_item(String(iid))
		var def: Dictionary = Content.object_by_id(String(item.get("def_id", "")))
		var ch := Chip.new()
		ch.ui = self
		ch.iid = String(iid)
		ch.tex = load("res://assets/icons/%s.svg" % String(item.get("icon", def.get("icon", "key"))))
		ch.tint = Color(String(item.get("tint", def.get("tint", "#ffffff"))))
		ch.tag = {"carried": "in hand", "bench": "bench", "shelf": "shelf"}.get(String(item.get("loc", "")), "")
		tray.add_child(ch)


func begin_drag(iid: String, tex: Texture2D, tint: Color, pos: Vector2) -> void:
	_drag_iid = iid
	_drag_moved = false
	_press_pos = pos
	_drag_ghost = TextureRect.new()
	_drag_ghost.texture = tex
	_drag_ghost.modulate = tint
	_drag_ghost.custom_minimum_size = Vector2(120, 120)
	_drag_ghost.size = Vector2(120, 120)
	_drag_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.z_index = 100
	_drag_ghost.position = pos - Vector2(60, 90)
	root.add_child(_drag_ghost)
	_tray_sig = ""


func _input(e: InputEvent) -> void:
	if _drag_iid == "":
		return
	if e is InputEventMouseMotion:
		var pos: Vector2 = (e as InputEventMouseMotion).position
		if pos.distance_to(_press_pos) > 14.0:
			_drag_moved = true
		if _drag_ghost:
			_drag_ghost.position = pos - Vector2(60, 90)
		crowd.set_drop_target(_front if _over_front(pos) else "")
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (e as InputEventMouseButton).pressed:
		var pos2: Vector2 = (e as InputEventMouseButton).position
		var iid: String = _drag_iid
		var give: bool = (not _drag_moved) or _over_front(pos2)
		_drag_iid = ""
		if _drag_ghost:
			_drag_ghost.queue_free()
			_drag_ghost = null
		crowd.set_drop_target("")
		_tray_sig = ""
		get_viewport().set_input_as_handled()
		if give and _front != "":
			Sim.hand_over(iid, _front)


func _over_front(screen_pos: Vector2) -> bool:
	if _front == "":
		return false
	var r: Rect2 = crowd.world_rect_of(_front)
	if r.size == Vector2.ZERO:
		return false
	var xf: Transform2D = world.get_canvas_transform()
	var sr: Rect2 = (xf * r).grow(60.0)
	return sr.has_point(screen_pos)


# ------------------------------------------------------------------ story card
func _show_story(iid: String, _pid: String, res: Dictionary) -> void:
	# let the reaction (hop, hearts, confetti) play before the card covers the scene
	await get_tree().create_timer(1.5).timeout
	for c in card.get_children():
		c.queue_free()
	var item: Dictionary = Sim.get_item(iid)
	var def: Dictionary = Content.object_by_id(String(item.get("def_id", "")))
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Pal.PARCHMENT
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(4)
	sb.border_color = Pal.BRASS
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0, 10)
	sb.content_margin_left = 38
	sb.content_margin_right = 38
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var head := Label.new()
	head.text = "REUNITED"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color(0.55, 0.4, 0.16))
	v.add_child(head)
	var title := Label.new()
	title.text = String(item.get("name", def.get("name", "")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Pal.INK)
	v.add_child(title)
	var art := Ledger.ArtBox.new()
	art.item = item if not item.is_empty() else def
	art.custom_minimum_size = Vector2(0, 170)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(art)
	var story := Label.new()
	story.text = String(res.get("story", ""))
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.add_theme_font_size_override("font_size", 28)
	story.add_theme_color_override("font_color", Pal.INK)
	story.custom_minimum_size = Vector2(700, 0)
	v.add_child(story)
	var arc: String = String(res.get("arc_line", ""))
	if arc != "":
		var ab := PanelContainer.new()
		ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ab.add_theme_stylebox_override("panel", Pal.panel_style(Color(Pal.BRASS, 0.22), Pal.BRASS, 16))
		var av := VBoxContainer.new()
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ab.add_child(av)
		var ah := Label.new()
		ah.text = "A NEW CHAPTER"
		ah.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ah.add_theme_font_size_override("font_size", 22)
		ah.add_theme_color_override("font_color", Color(0.55, 0.4, 0.16))
		av.add_child(ah)
		var al := Label.new()
		al.text = "\"%s\"" % arc
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		al.add_theme_font_size_override("font_size", 28)
		al.add_theme_color_override("font_color", Pal.INK)
		al.custom_minimum_size = Vector2(660, 0)
		av.add_child(al)
		v.add_child(ab)
	var rew := Label.new()
	rew.text = "+%d tokens     +%d reputation" % [int(res.get("tokens", 0)), int(res.get("rep", 0))]
	rew.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rew.add_theme_font_size_override("font_size", 32)
	rew.add_theme_color_override("font_color", Color(0.62, 0.33, 0.14))
	v.add_child(rew)
	var tapl := Label.new()
	tapl.text = "tap to continue"
	tapl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tapl.add_theme_font_size_override("font_size", 20)
	tapl.add_theme_color_override("font_color", Color(0.4, 0.33, 0.25))
	v.add_child(tapl)
	card.visible = true
	_card_t = 0.0
	await get_tree().process_frame
	var vis: Vector2 = get_viewport().get_visible_rect().size
	card.size = Vector2(minf(vis.x - 60.0, 800.0), 0)
	await get_tree().process_frame
	card.position = Vector2((vis.x - card.size.x) * 0.5, maxf(60.0, vis.y * 0.5 - card.size.y * 0.62))
	card.pivot_offset = card.size * 0.5
	if not Pal.reduced_motion():
		card.scale = Vector2(0.7, 0.7)
		card.modulate.a = 0.0
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.25)
	Sfx.play("correct")


func _on_card_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		card.visible = false
