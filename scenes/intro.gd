extends Control
## First-run intro: three paper cards. Emits finished.
signal finished
const CARDS := [
	["Things get lost on the trains.", "They turn up at your counter while you're away."],
	["Look closely.", "Tap an object to find its clues. Owners only half remember what they lost."],
	["Match it to its owner.", "Take your time. Nothing expires. Wrong guesses just go to the shelf."],
]
var _i := 0
var _title: Label
var _body: Label
var _btn: UButton
var _dots: HBoxContainer
var _card: UCard

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.08, 0.1, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	_card = UCard.new()
	_card.custom_minimum_size = Vector2(min(get_viewport_rect().size.x - 100.0, 860.0), 0)
	c.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 28)
	_card.add_child(v)
	_title = UCard.ink_label("", 56)
	_title.add_theme_color_override("font_color", Pal.SIGNAL)
	v.add_child(_title)
	_body = UCard.ink_label("", 38)
	v.add_child(_body)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 14)
	v.add_child(_dots)
	_btn = UButton.new()
	_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn.pressed.connect(_next)
	v.add_child(_btn)
	_show()

func _show() -> void:
	_title.text = CARDS[_i][0]
	_body.text = CARDS[_i][1]
	_btn.text = "Next" if _i < CARDS.size() - 1 else "Open the counter"
	for d in _dots.get_children():
		d.queue_free()
	for k in CARDS.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.color = Pal.BRASS if k == _i else Pal.BRASS.darkened(0.6)
		_dots.add_child(dot)
	await get_tree().process_frame
	_card.stamp()

func _next() -> void:
	_i += 1
	if _i >= CARDS.size():
		Settings.set_bool("intro_done", true)
		finished.emit()
		queue_free()
	else:
		_show()
