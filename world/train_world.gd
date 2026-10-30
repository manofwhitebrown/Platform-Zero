class_name TrainWorld
extends Node2D
## The whole train as one scrolling 1D world (x from the rear). Builds everything in code.
## Reads Sim (contract v2). Responsive: portrait shows ~1080 world px of width, landscape ~1920.

const CAR_W: float = 1800.0
const CAM_Y: float = 520.0
const FLOOR_Y: float = 880.0   # feet line for actors

signal brass_clock_tapped
signal lamp_held

var cam: Camera2D
var scenery: Scenery
var shells: Dictionary = {}
var glass: GlassFx
var _vspd: float = 1.0
var _force: Dictionary = {}   # screenshot/debug override: biome, weather, tod
var car_props: Array = []
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
var attendant: Passenger
var winput: WorldInput
var crowd: Crowd
var claim_ui: ClaimUI
var bench: Bench
var hud: Hud
var _dir_look: float = 0.0
var _last_follow: float = 0.0
var _push: float = 0.0          # 0..1 target push-in (interviews)
var _push_k: float = 0.0        # eased
var _push_dx: float = 0.0       # world-x shift toward the focus point
var _focus_x: float = -1.0
var _door_k: float = 0.0        # car-to-car transition pulse
var _last_car: int = -1


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
		if String(c["kind"]) != "lp":
			var cp := CarProps.new()
			cp.position = sh.position
			cp.setup(String(c["kind"]), String(c["id"]), false, bool(c.get("unlocked", true)))
			add_child(cp)
			car_props.append(cp)
		if String(c["kind"]) == "lp":
			props = LPProps.new()
			props.position = sh.position
			add_child(props)
			_add_lp_lights(sh.position)

	glass = GlassFx.new()
	add_child(glass)

	cam = Camera2D.new()
	cam.position = Vector2(float(Sim.get_player().get("x", 4500.0)), CAM_Y)
	add_child(cam)
	cam.make_current()
	_follow_x = float(Sim.get_player().get("x", 4500.0))
	_cam_x = _follow_x

	attendant = Passenger.new()
	attendant.position = Vector2(_follow_x, FLOOR_Y)
	add_child(attendant)
	attendant.setup({"skin": "#e8b88f", "hair": "#2a1d14", "coat": "#12303B", "hat": "cap", "accessory": "none", "build": "avg", "height": 1.0, "hair_style": "short", "pants": "#1a2a33", "shoes": "#14100d"}, "calm", "attendant")
	if Sim.has_method("get_equipped"):
		attendant.look["cosmetics"] = Sim.call("get_equipped")
		attendant.queue_redraw()
	crowd = Crowd.new()
	add_child(crowd)
	crowd.setup(self)
	for c2 in cars:
		if String(c2["kind"]) != "lp":
			var cf := CarProps.new()
			cf.position = Vector2(float(c2["x"]), 0)
			cf.setup(String(c2["kind"]), String(c2["id"]), true, bool(c2.get("unlocked", true)))
			add_child(cf)
			car_props.append(cf)
	attendant.z_index = 3
	winput = WorldInput.new()
	add_child(winput)
	winput.setup(self, attendant)
	claim_ui = ClaimUI.new()
	add_child(claim_ui)
	claim_ui.setup(self, crowd)
	bench = (load("res://bench/bench.tscn") as PackedScene).instantiate()
	add_child(bench)
	winput.interacted.connect(_on_interacted)
	winput.brass_clock_tapped.connect(func() -> void: brass_clock_tapped.emit())
	winput.lamp_held.connect(func() -> void: lamp_held.emit())
	hud = Hud.new()
	hud.world = self
	add_child(hud)

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
	Events.car_unlocked.connect(_on_car_unlocked)
	if Events.has_signal("fast_travelled"):
		Events.connect("fast_travelled", _on_fast_travelled)


## D11: fast travel. Sim already moved the player: start the camera at from_x and let it glide
## (accelerated follow + zoom pulse) so the move reads as a carriage-to-carriage whoosh.
var _ft: float = 0.0
func _on_fast_travelled(_car_id: String, from_x: float, _to_x: float) -> void:
	_follow_x = from_x
	_last_follow = float(Sim.get_player().get("x", from_x))
	_ft = 1.0
	_door_k = 1.0


func _on_car_unlocked(car_id: String) -> void:
	for c in Sim.get_cars():
		if String(c["id"]) == car_id and shells.has(car_id):
			(shells[car_id] as CarShell).setup(c)
	for cp in car_props:
		if (cp as CarProps).car_id == car_id:
			(cp as CarProps).modulate = Color.WHITE


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


const LAMP_COL: Dictionary = {"pass": Color(1.0, 0.85, 0.55), "dine": Color(1.0, 0.7, 0.4), "sleep": Color(0.85, 0.7, 1.0), "obs": Color(0.6, 0.78, 1.0), "lug": Color(1.0, 0.78, 0.4)}


func _add_dust(x0: float) -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(x0 + 900.0, 620.0)
	p.amount = 14
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(860.0, 220.0)
	p.gravity = Vector2(0.0, -3.0)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 8.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(1.0, 0.9, 0.65, 0.35)
	add_child(p)


func _add_car_lights(c: Dictionary) -> void:
	var x0: float = float(c["x"])
	var warm: Color = LAMP_COL.get(String(c["kind"]), Color(1.0, 0.82, 0.5))
	if String(c["kind"]) != "lp":
		_add_dust(x0)
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
	# visual speed eases down into the station and up out of it (Sim speed is a flag, not a curve)
	var st: String = String(train.get("state", "moving"))
	var ph: float = float(train.get("phase_t", 0.0))
	var plat_off: float = 99999.0
	var steam: float = 0.0
	var brake: float = 0.0
	match st:
		"arriving":
			spd = pow(1.0 - ph, 1.6)
			plat_off = pow(1.0 - ph, 2.2) * 4600.0
			brake = sin(ph * PI) * 0.8 * (1.0 if ph > 0.5 else 0.2)
		"stopped":
			spd = 0.0
			plat_off = 0.0
		"departing":
			spd = ph * ph
			plat_off = -pow(ph, 2.0) * 4600.0
			steam = clampf(1.0 - ph * 3.0, 0.0, 1.0)
			brake = maxf(0.0, 1.0 - ph * 5.0) * 0.8
	_vspd = lerpf(_vspd, spd, clampf(delta * 6.0, 0.0, 1.0))
	_scroll += delta * _vspd * 260.0
	if _force.has("plat"):
		plat_off = float(_force["plat"])
		steam = float(_force.get("steam", 0.0))
	scenery.set_station(plat_off, steam, String((train.get("stop", {}) as Dictionary).get("name", "")), int(hash(String((train.get("stop", {}) as Dictionary).get("name", ""))) & 0xff))
	if is_instance_valid(cam):
		cam.offset = Vector2(sin(_t * 41.0), sin(_t * 57.0) * 0.6) * 3.0 * brake
	var p: Dictionary = Sim.get_player()
	var tx: float = float(p.get("x", _follow_x))
	var mv: float = tx - _last_follow
	_last_follow = tx
	var want_look: float = clampf(mv / maxf(delta, 0.0001) * 0.5, -140.0, 140.0) if absf(mv) > 0.01 else 0.0
	_dir_look = lerpf(_dir_look, want_look, clampf(delta * 2.5, 0.0, 1.0))
	_look = _dir_look
	_ft = maxf(0.0, _ft - delta * 1.1)
	_follow_x = lerpf(_follow_x, tx, clampf(delta * (5.0 + 5.0 * _ft), 0.0, 1.0))
	_push_k = lerpf(_push_k, _push, clampf(delta * 2.2, 0.0, 1.0))
	var mid: float = (tx + _focus_x) * 0.5 if _focus_x >= 0.0 else tx
	_push_dx = (mid - _follow_x) * _push_k
	var car_i: int = int(floorf(tx / CAR_W))
	if _last_car >= 0 and car_i != _last_car:
		_door_k = 1.0
	_last_car = car_i
	_door_k = maxf(0.0, _door_k - delta * 1.6)
	_update_camera(delta)
	_cull()
	var door_k: float = 0.0
	match st:
		"arriving":
			door_k = clampf((ph - 0.88) / 0.12, 0.0, 1.0)
		"stopped":
			door_k = 1.0
		"departing":
			door_k = clampf(1.0 - ph / 0.12, 0.0, 1.0)
	for k3 in shells:
		(shells[k3] as CarShell).set_door(door_k)
	var wheel: float = _scroll * 0.05
	for k in shells:
		(shells[k] as CarShell).set_wheels(wheel)
	var sway_a: float = sin(_t * 1.3) * 0.035 + sin(_t * 2.9) * 0.018
	if props:
		props.sway(sway_a)
	var vis: Vector2 = get_viewport().get_visible_rect().size
	var biome_s: String = String(_force.get("biome", (train.get("stop", {}) as Dictionary).get("biome", "plains")))
	var weather_s: String = String(_force.get("weather", train.get("weather", "clear")))
	scenery.push_state(cam.get_screen_center_position(), cam.zoom.x, vis, _scroll, float(_force.get("tod", train.get("time_of_day", 0.8))), biome_s, weather_s, _t)
	glass.set_state(weather_s, _t, cam.get_screen_center_position().x, vis.x * 0.5 / maxf(cam.zoom.x, 0.01))
	if vignette_rect and vignette_rect.material:
		(vignette_rect.material as ShaderMaterial).set_shader_parameter("t", fmod(_t, 10.0))
		(vignette_rect.material as ShaderMaterial).set_shader_parameter("res", vis)


func _update_camera(_delta: float) -> void:
	var vis: Vector2 = get_viewport().get_visible_rect().size
	var portrait: bool = vis.y > vis.x
	var want_w: float = 1080.0 if portrait else 1920.0
	var z: float = vis.x / want_w
	z *= 1.0 + 0.12 * _push_k - (0.03 + 0.04 * _ft) * sin(_door_k * PI)
	cam.zoom = Vector2(z, z)
	var half_w: float = want_w * 0.5
	var min_x: float = half_w - 60.0
	var max_x: float = CAR_W * 6.0 - half_w + 60.0
	var cx: float = clampf(_follow_x + _look + _push_dx, min_x, max_x)
	var bob: float = sin(_t * 2.1) * 2.5 + sin(_t * 5.3) * 1.2
	cam.position = Vector2(cx, CAM_Y + bob)


## Shot helpers: tools/shoot.gd calls bare setup names as methods on the scene root,
## ShotHook goes through shot_setup(). Both end up here.
## Screenshot/debug: force the view outside the windows (biome, weather, time of day 0..1).
## Public camera API (B/claim UI): gentle push-in toward a world x during an interview.
func camera_push_in(focus_x: float, amount: float = 1.0) -> void:
	_focus_x = focus_x
	_push = clampf(amount, 0.0, 1.0)


func camera_release() -> void:
	_push = 0.0


## Perf: only draw/simulate what is near the camera (cars, props, point lights). Cheap, no allocations.
var _cull_t: float = 0.0
func _cull() -> void:
	_cull_t -= get_process_delta_time()
	if _cull_t > 0.0 and not _force.has("cull_now"):
		return
	_cull_t = 0.15
	var vis: Vector2 = get_viewport().get_visible_rect().size
	var half: float = vis.x * 0.5 / maxf(cam.zoom.x, 0.01) + CAR_W * 0.5 + 260.0
	var cx: float = cam.position.x
	for k in shells:
		var sh: CarShell = shells[k] as CarShell
		sh.visible = absf(sh.position.x + CAR_W * 0.5 - cx) < half
	for cp in car_props:
		var n: Node2D = cp as Node2D
		n.visible = absf(n.position.x + CAR_W * 0.5 - cx) < half
		n.set_process(n.visible)
	for l in lights:
		var ln: Node2D = l as Node2D
		if is_instance_valid(ln):
			ln.visible = absf(ln.position.x - cx) < half


func shot_scene(biome_s: String, weather_s: String, tod: float) -> void:
	_force = {"biome": biome_s, "weather": weather_s, "tod": tod}


## Screenshot/debug: park the platform alongside (plat 0) or mid-slide, with optional steam.
func shot_platform(plat: float, steam: float = 0.0) -> void:
	_force["plat"] = plat
	_force["steam"] = steam


func tap_world(x: float, y: float = 800.0) -> void:
	winput.tap_world(Vector2(x, y))


func claim_ask(q: int) -> void:
	var fq: Array = Sim.get_queue()
	if not fq.is_empty():
		Sim.ask(String(fq[0]), q)


func handover_front() -> void:
	var fp: String = ""
	for p in Sim.get_passengers():
		if String(p["kind"]) != "ambient" and (String(p["state"]) == "waiting" or String(p["state"]) == "asking"):
			fp = String(p["pid"])
	var iid: String = String(Sim.get_player().get("carrying", ""))
	if iid == "":
		var bi: Array = Sim.get_items_at("bench")
		if not bi.is_empty():
			iid = String((bi[0] as Dictionary)["iid"])
	if fp != "" and iid != "":
		Sim.hand_over(iid, fp)


func shot_setup(call: String, args: Array) -> void:
	if has_method(call):
		callv(call, args)


func _on_interacted(kind: String, _id: String) -> void:
	if kind == "bench":
		get_tree().create_timer(0.45).timeout.connect(bench.open)
	elif kind == "bench_open":
		bench.open()


## Shot helper: pick up the first item, put it on the bench, open the close-up in a tool pose.
func bench_demo(tool: String, prog: float = 0.5) -> void:
	if Sim.get_items_at("bench").is_empty():
		for sp in Sim.get_spots():
			if String(sp["item_iid"]) != "":
				var r: Dictionary = Sim.pick_up(String(sp["id"]))
				if bool(r.get("ok", false)):
					Sim.place_on_bench(String(r["iid"]))
				break
	bench.open(tool)
	bench.demo(tool, prog)
	if prog >= 1.0:
		var iid: String = bench.view.sel
		if iid != "":
			Sim.reveal(iid, tool)


func hud_toast(text: String) -> void:
	Events.toast.emit(text, "good")
