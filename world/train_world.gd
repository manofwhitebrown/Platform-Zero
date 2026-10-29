class_name TrainWorld
extends Node2D
## The whole train as one scrolling 1D world (x from the rear). Builds everything in code.
## Reads Sim (contract v2). Responsive: portrait shows ~1080 world px of width, landscape ~1920.

const CAR_W: float = 1800.0
const CAM_Y: float = 520.0
const FLOOR_Y: float = 880.0   # feet line for actors

var cam: Camera2D
var scenery: Scenery
var shells: Dictionary = {}
var props: LPProps
var lights: Array = []
var modulate_node: CanvasModulate
var vignette_rect: ColorRect
var lamp_light: PointLight2D
var _bg_layer: CanvasLayer
var _fx_layer: CanvasLayer
var _scroll: float = 0.0
var _t: float = 0.0
var _cam_x: float = 0.0
var _look: float = 0.0
var _follow_x: float = 0.0
var low_effects: bool = false


func _ready() -> void:
	_build()
	if ShotHook.wanted():
		add_child(ShotHook.new())


func _build() -> void:
	# background scenery (screen space, unmodulated)
	_bg_layer = CanvasLayer.new()
	_bg_layer.layer = -10
	add_child(_bg_layer)
	scenery = Scenery.new()
	_bg_layer.add_child(scenery)

	modulate_node = CanvasModulate.new()
	modulate_node.color = Color(0.5, 0.56, 0.68)
	add_child(modulate_node)

	var cars: Array = Sim.get_cars()
	for c in cars:
		var sh := CarShell.new()
		sh.position = Vector2(float(c["x"]), 0)
		sh.setup(c)
		add_child(sh)
		shells[String(c["id"])] = sh
		_add_car_lights(c)
		if String(c["kind"]) == "lp":
			props = LPProps.new()
			props.position = sh.position
			add_child(props)
			_add_lp_lights(sh.position)

	cam = Camera2D.new()
	cam.position = Vector2(float(Sim.get_player().get("x", 4500.0)), CAM_Y)
	add_child(cam)
	cam.make_current()
	_follow_x = float(Sim.get_player().get("x", 4500.0))
	_cam_x = _follow_x

	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 50
	add_child(_fx_layer)
	vignette_rect = ColorRect.new()
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette_grain.gdshader")
	vignette_rect.material = mat
	_fx_layer.add_child(vignette_rect)
	_update_camera(0.0)


static func _light_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _make_light(pos: Vector2, scale_f: float, energy: float, col: Color) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _light_tex()
	l.texture_scale = scale_f
	l.energy = energy
	l.color = col
	l.position = pos
	add_child(l)
	lights.append(l)
	return l


func _add_car_lights(c: Dictionary) -> void:
	var x0: float = float(c["x"])
	var warm: Color = Color(1.0, 0.82, 0.5)
	for lx in [330.0, 900.0, 1470.0]:
		_make_light(Vector2(x0 + lx, 200), 6.0, 1.0, warm)
	# window-cool wash from the night outside
	_make_light(Vector2(x0 + 900, 300), 9.0, 0.22, Color(0.45, 0.6, 0.9))


func _add_lp_lights(car_pos: Vector2) -> void:
	_make_light(car_pos + Vector2(990, 280), 4.0, 1.0, Color(1.0, 0.8, 0.45))     # hanging lamp pool
	_make_light(car_pos + Vector2(340, 640), 2.4, 0.9, Color(1.0, 0.9, 0.6))      # bench lamp
	_make_light(car_pos + Vector2(1460, 520), 3.0, 0.55, Color(1.0, 0.75, 0.45))  # shelf glow


func _process(delta: float) -> void:
	_t += delta
	var train: Dictionary = Sim.get_train()
	var spd: float = float(train.get("speed", 1.0))
	if String(train.get("state", "moving")) == "stopped":
		spd = 0.0
	_scroll += delta * spd * 260.0
	var p: Dictionary = Sim.get_player()
	_follow_x = lerpf(_follow_x, float(p.get("x", _follow_x)), clampf(delta * 5.0, 0.0, 1.0))
	_update_camera(delta)
	var wheel: float = _scroll * 0.05
	for k in shells:
		(shells[k] as CarShell).set_wheels(wheel)
	var sway_a: float = sin(_t * 1.3) * 0.035 + sin(_t * 2.9) * 0.018
	if props:
		props.sway(sway_a)
	var vis: Vector2 = get_viewport().get_visible_rect().size
	scenery.push_state(cam.get_screen_center_position(), cam.zoom.x, vis, _scroll, float(train.get("time_of_day", 0.8)), String((train.get("stop", {}) as Dictionary).get("biome", "plains")), String(train.get("weather", "clear")), _t)
	if vignette_rect and vignette_rect.material:
		(vignette_rect.material as ShaderMaterial).set_shader_parameter("t", fmod(_t, 10.0))
		(vignette_rect.material as ShaderMaterial).set_shader_parameter("res", vis)


func _update_camera(_delta: float) -> void:
	var vis: Vector2 = get_viewport().get_visible_rect().size
	var portrait: bool = vis.y > vis.x
	var want_w: float = 1080.0 if portrait else 1920.0
	var z: float = vis.x / want_w
	cam.zoom = Vector2(z, z)
	var half_w: float = want_w * 0.5
	var min_x: float = half_w - 60.0
	var max_x: float = CAR_W * 6.0 - half_w + 60.0
	var cx: float = clampf(_follow_x + _look, min_x, max_x)
	var bob: float = sin(_t * 2.1) * 2.5 + sin(_t * 5.3) * 1.2
	cam.position = Vector2(cx, CAM_Y + bob)


## Scene-specific shot setup hook (see ShotHook).
func shot_setup(call: String, args: Array) -> void:
	if call == "noop":
		return
