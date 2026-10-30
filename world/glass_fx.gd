class_name GlassFx
extends Node2D
## Weather on the window glass (D4): raindrops with trails, fog condensation with a wiped streak.
## One node for the whole train; only windows near the camera are drawn, and only while it rains/fogs.

var weather: String = "clear"
var t: float = 0.0
var cam_x: float = 0.0
var half_w: float = 900.0
var _lens: Array = []   # [x, y, w, h] window rects relative to car origin (filled from CarShell geometry)


func _ready() -> void:
	z_index = 0
	for i in range(CarShell.WIN_COUNT):
		_lens.append(Rect2(CarShell.WIN_X0 + i * CarShell.WIN_PITCH, CarShell.Y_WIN0, CarShell.WIN_W, CarShell.Y_WIN1 - CarShell.Y_WIN0))


func set_state(p_weather: String, p_t: float, p_cam_x: float, p_half_w: float) -> void:
	var changed: bool = p_weather != weather
	weather = p_weather
	t = p_t
	cam_x = p_cam_x
	half_w = p_half_w
	if weather == "rain" or weather == "fog" or changed:
		queue_redraw()


func _h(n: float) -> float:
	return fposmod(sin(n * 12.9898) * 43758.5453, 1.0)


func _draw() -> void:
	if weather != "rain" and weather != "fog":
		return
	var c0: int = maxi(0, int(floor((cam_x - half_w) / CarShell.W)))
	var c1: int = mini(5, int(floor((cam_x + half_w) / CarShell.W)))
	for ci in range(c0, c1 + 1):
		for wi in range(_lens.size()):
			var r: Rect2 = _lens[wi]
			var o := Vector2(float(ci) * CarShell.W + r.position.x, r.position.y)
			var seed_f: float = float(ci * 10 + wi)
			if weather == "fog":
				draw_rect(Rect2(o, r.size), Color(0.8, 0.88, 0.92, 0.2))
				continue
			for d in range(7):
				var k: float = seed_f * 7.0 + float(d)
				var x: float = o.x + 16.0 + _h(k) * (r.size.x - 32.0)
				var spd: float = 14.0 + _h(k + 2.0) * 40.0
				var y: float = o.y + fposmod(_h(k + 1.0) * r.size.y + t * spd, r.size.y)
				var rad: float = 3.0 + _h(k + 3.0) * 4.0
				var trail: float = 10.0 + spd * 0.9
				draw_line(Vector2(x, y - trail), Vector2(x, y), Color(0.8, 0.9, 1.0, 0.12), rad * 0.6)
				draw_circle(Vector2(x, y), rad, Color(0.75, 0.88, 1.0, 0.28))
				draw_circle(Vector2(x - rad * 0.3, y - rad * 0.3), rad * 0.35, Color(1, 1, 1, 0.55))
