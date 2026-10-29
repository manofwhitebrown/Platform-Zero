class_name Backdrop
extends Control
## Procedural dusk-teal station: gradient sky, parallax arches, hanging lamps with warm pools, drifting steam/dust.
## Call set_scroll(0..1) from navigation to slide the layers.
const GLOW := preload("res://shaders/lamp_glow.gdshader")
var scroll := 0.0
var _target := 0.0
var _dust: Array = []
var _lamps: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 38:
		_dust.append({"p": Vector2(rng.randf(), rng.randf()), "s": rng.randf_range(0.004, 0.02), "r": rng.randf_range(2.0, 6.0), "a": rng.randf_range(0.1, 0.4), "ph": rng.randf() * TAU})
	for i in 3:
		var x := 0.2 + 0.3 * i
		_lamps.append(x)
		var g := ColorRect.new()
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = GLOW
		m.set_shader_parameter("radius", 0.5)
		m.set_shader_parameter("intensity", 0.55)
		m.set_shader_parameter("speed", 0.8 + i * 0.3)
		g.material = m
		g.color = Color.WHITE
		g.name = "Glow%d" % i
		add_child(g)
	resized.connect(_layout_glows)
	_layout_glows()

func _layout_glows() -> void:
	for i in 3:
		var g: ColorRect = get_node_or_null("Glow%d" % i)
		if g:
			var d := size.x * 0.9
			g.size = Vector2(d, d)
			g.position = Vector2(size.x * (0.2 + 0.3 * i) - d / 2.0 - scroll * 40.0 * (i + 1), size.y * 0.16 - d / 2.0)

func set_scroll(v: float) -> void:
	_target = v

func _process(delta: float) -> void:
	if not Pal.reduced_motion():
		scroll = lerpf(scroll, _target, clampf(delta * 3.0, 0.0, 1.0))
		_layout_glows()
		queue_redraw()
	elif scroll != _target:
		scroll = _target
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	# sky gradient (banded strips)
	var bands := 24
	for i in bands:
		var t := float(i) / bands
		draw_rect(Rect2(0, h * t, w, h / bands + 1), Pal.DEEP.lerp(Pal.NIGHT, 1.0 - abs(t - 0.35) * 1.2))
	# far arches (slow)
	_arches(w, h, 0.34, 520.0, 0.75, Color(Pal.NIGHT.r, Pal.NIGHT.g, Pal.NIGHT.b, 0.7), 0.4)
	# near arches (faster, darker)
	_arches(w, h, 0.42, 380.0, 1.6, Color(Pal.DEEP.r, Pal.DEEP.g, Pal.DEEP.b, 0.85), 0.55)
	# brass beams + hanging lamps
	for i in _lamps.size():
		var x: float = w * _lamps[i] - scroll * 40.0 * (i + 1)
		draw_line(Vector2(x, 0), Vector2(x, h * 0.13), Pal.BRASS, 4.0, true)
		draw_circle(Vector2(x, h * 0.16), 26.0, Pal.BRASS)
		draw_circle(Vector2(x, h * 0.16), 16.0, Pal.LAMP)
	# floor: platform planks with lamp-warm sheen
	draw_rect(Rect2(0, h * 0.86, w, h * 0.14), Pal.DEEP)
	draw_rect(Rect2(0, h * 0.86, w, 6), Pal.BRASS.darkened(0.3))
	# dust / steam
	var t := Time.get_ticks_msec() / 1000.0
	for d in _dust:
		var px: float = fposmod(d.p.x + t * d.s - scroll * 0.05, 1.0) * w
		var py: float = fposmod(d.p.y - t * d.s * 0.6, 1.0) * h
		var a: float = d.a * (0.6 + 0.4 * sin(t + d.ph))
		draw_circle(Vector2(px, py), d.r, Color(Pal.LAMP.r, Pal.LAMP.g, Pal.LAMP.b, a * 0.5))

func _arches(w: float, h: float, base_y: float, span: float, par: float, col: Color, height_f: float) -> void:
	var off := fposmod(-scroll * 100.0 * par, span)
	var n := int(w / span) + 3
	for i in range(-1, n):
		var cx := off + i * span + span / 2.0
		var top := h * (base_y - height_f * 0.35)
		var bottom := h * 0.86
		var r := span * 0.38
		# pillar pair + semicircle arch outline
		var pts := PackedVector2Array()
		for k in 21:
			var a := PI + PI * k / 20.0
			pts.append(Vector2(cx + cos(a) * r, top + r + sin(a) * r))
		draw_polyline(pts, col, 14.0, true)
		draw_line(Vector2(cx - r, top + r), Vector2(cx - r, bottom), col, 14.0, true)
		draw_line(Vector2(cx + r, top + r), Vector2(cx + r, bottom), col, 14.0, true)
