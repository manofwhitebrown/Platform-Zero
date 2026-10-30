class_name UTag
extends Control
## Paper claim tag: icon on a parchment tag hanging from a string. Swings gently.
## Usage: var t := UTag.new(); t.setup("mitten", Color("#C8503C"), "Smoky Mitten"); t.custom_minimum_size = Vector2(220, 280)

signal tapped
var icon_key := "key"
var tint := Color.WHITE
var label_text := ""
var _tex: Texture2D
var _swing: Tween
var hang := true  # set false for static grids (catalog) to skip swinging

func setup(key: String, c: Color, text: String = "") -> void:
	icon_key = key
	tint = c
	label_text = text
	var path := "res://assets/icons/%s.svg" % key
	_tex = load(path) if ResourceLoader.exists(path) else null
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func(): pivot_offset = Vector2(size.x / 2.0, 0.0))
	pivot_offset = Vector2(size.x / 2.0, 0.0)
	if hang:
		swing(true)

func swing(initial: bool = false) -> void:
	if Pal.reduced_motion() or not hang:
		return
	if _swing:
		_swing.kill()
	var amp := 5.0 if initial else 12.0
	_swing = create_tween()
	for a in [amp, -amp * 0.7, amp * 0.4, -amp * 0.2, 0.0]:
		_swing.tween_property(self, "rotation", deg_to_rad(a), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_swing.tween_callback(func():
		await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
		if is_inside_tree():
			swing(true))

func _gui_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if pressed:
		Audio.play("ui_tap")
		swing()
		tapped.emit()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var tag_top := h * 0.14
	# string
	draw_line(Vector2(w / 2.0, 0), Vector2(w / 2.0, tag_top + 10), Pal.BRASS, 4.0, true)
	# tag body (clipped-corner shape)
	var c := 28.0
	var pts := PackedVector2Array([
		Vector2(c, tag_top), Vector2(w - c, tag_top), Vector2(w - 6, tag_top + c),
		Vector2(w - 6, h - 12), Vector2(6, h - 12), Vector2(6, tag_top + c)])
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, 6))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
	draw_colored_polygon(pts, Pal.PARCHMENT)
	draw_polyline(PackedVector2Array(Array(pts) + [pts[0]]), Pal.BRASS, 3.0, true)
	# eyelet
	draw_circle(Vector2(w / 2.0, tag_top + 22), 9.0, Pal.BRASS)
	draw_circle(Vector2(w / 2.0, tag_top + 22), 5.0, Pal.DEEP)
	# icon
	var box := Rect2(w * 0.17, tag_top + 50, w * 0.66, w * 0.66)
	if _tex:
		draw_texture_rect(_tex, box, false, tint)
	# label
	if label_text != "":
		var f := get_theme_default_font()
		var fs := 26
		var ts := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, w - 24, fs)
		draw_string(f, Vector2((w - ts.x) / 2.0, h - 36), label_text, HORIZONTAL_ALIGNMENT_LEFT, w - 24, fs, Pal.INK)
