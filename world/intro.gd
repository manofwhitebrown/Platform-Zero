class_name Intro
extends Control
## Title scene: the night train rolls into Platform Zero. Skippable (tap), emits `finished`.
## Intro.draw_train(ci, origin, w, t) is reusable (Welcome-back / loading exterior shot).

signal finished

const DUR: float = 9.0
var _t: float = 0.0
var _done: bool = false
var _stars: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in range(70):
		_stars.append(Vector3(r.randf(), r.randf() * 0.5, r.randf_range(0.5, 1.6)))


func _process(dt: float) -> void:
	_t += dt
	if _t >= DUR and not _done:
		_finish()
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if _t > 0.6 and ((e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed) or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventKey and (e as InputEventKey).pressed)):
		_finish()


func skip() -> void:
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


## Side-on silhouette train: engine + n cars with warm lit windows. origin = rail-level front-left.
static func draw_train(ci: CanvasItem, origin: Vector2, car_w: float, t: float, cars: int = 6) -> void:
	var h: float = car_w * 0.34
	for i in range(cars):
		var x: float = origin.x + float(i) * (car_w + 6.0)
		var body := Rect2(x, origin.y - h - 14.0, car_w, h)
		ci.draw_rect(body, Color("#0b1e26"))
		ci.draw_rect(Rect2(body.position.x, body.position.y, car_w, 6.0), Color("#B8893E"))
		ci.draw_rect(Rect2(body.position.x, body.end.y - 8.0, car_w, 8.0), Color(0, 0, 0, 0.5))
		var wn: int = 5
		for k in range(wn):
			var wx: float = x + car_w * (0.07 + 0.18 * float(k))
			var lit: float = 0.65 + 0.35 * sin(t * 1.7 + float(i * 7 + k))
			ci.draw_rect(Rect2(wx, body.position.y + h * 0.22, car_w * 0.12, h * 0.34), Color(0.95, 0.72, 0.3, 0.55 + 0.35 * lit))
		ci.draw_circle(Vector2(x + car_w * 0.18, origin.y - 8.0), 9.0, Color("#050d11"))
		ci.draw_circle(Vector2(x + car_w * 0.82, origin.y - 8.0), 9.0, Color("#050d11"))
	# locomotive at the front (right end of the draw, train moves right)
	var lx: float = origin.x + float(cars) * (car_w + 6.0)
	var lh: float = h * 1.05
	ci.draw_rect(Rect2(lx, origin.y - lh - 14.0, car_w * 0.7, lh), Color("#0a1a21"))
	ci.draw_rect(Rect2(lx + car_w * 0.45, origin.y - lh - 34.0, car_w * 0.2, 24.0), Color("#0a1a21"))
	ci.draw_circle(Vector2(lx + car_w * 0.7, origin.y - lh * 0.5 - 14.0), h * 0.07, Color(1.0, 0.88, 0.5, 0.95))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(lx + car_w * 0.7, origin.y - lh * 0.5 - 14.0 - 14.0), Vector2(lx + car_w * 2.2, origin.y - lh * 0.5 - 90.0), Vector2(lx + car_w * 2.2, origin.y - lh * 0.5 + 60.0), Vector2(lx + car_w * 0.7, origin.y - lh * 0.5 + 0.0)]), Color(1.0, 0.88, 0.5, 0.07))


func _draw() -> void:
	var s: Vector2 = size
	var port: bool = s.y > s.x
	# sky
	var steps: int = 24
	for i in range(steps):
		var k: float = float(i) / float(steps)
		draw_rect(Rect2(0, s.y * k, s.x, s.y / float(steps) + 1.0), Color("#0B1E26").lerp(Color("#1d4a55"), pow(k, 1.6)))
	for st in _stars:
		var tw: float = 0.5 + 0.5 * sin(_t * st.z * 2.0 + st.x * 20.0)
		draw_circle(Vector2(st.x * s.x, st.y * s.y), st.z, Color(1, 0.95, 0.8, 0.25 + 0.5 * tw))
	# distant hills
	var hy: float = s.y * (0.66 if port else 0.62)
	var pts := PackedVector2Array([Vector2(0, s.y), Vector2(0, hy)])
	for i in range(0, 41):
		var x: float = s.x * float(i) / 40.0
		pts.append(Vector2(x, hy - 40.0 * sin(float(i) * 0.5) - 26.0 * sin(float(i) * 1.3 + 1.0)))
	pts.append(Vector2(s.x, s.y))
	draw_colored_polygon(pts, Color("#0e2c34"))
	# platform + rail
	var rail_y: float = s.y * (0.74 if port else 0.76)
	draw_rect(Rect2(0, rail_y, s.x, s.y - rail_y), Color("#06141a"))
	draw_rect(Rect2(0, rail_y, s.x, 5), Color("#B8893E"))
	var plat := Rect2(s.x * 0.58, rail_y - 26.0, s.x * 0.42, 26.0)
	draw_rect(plat, Color("#2a3d42"))
	for i in range(3):
		var lx: float = plat.position.x + plat.size.x * (0.2 + 0.3 * float(i))
		draw_line(Vector2(lx, plat.position.y), Vector2(lx, plat.position.y - s.y * 0.2), Color("#B8893E"), 5.0)
		draw_circle(Vector2(lx, plat.position.y - s.y * 0.2), 40.0, Color(1.0, 0.78, 0.4, 0.14))
		draw_circle(Vector2(lx, plat.position.y - s.y * 0.2), 13.0, Color(1.0, 0.9, 0.6))
	# sign board
	var sb := Rect2(s.x * 0.66, rail_y - s.y * 0.2 - 4.0, s.x * 0.26, s.y * 0.05)
	draw_rect(Rect2(sb.position.x, sb.position.y + sb.size.y, 5, s.y * 0.1), Color("#B8893E"))
	draw_rect(sb, Color("#12303B"))
	draw_rect(sb, Color("#B8893E"), false, 3.0)
	var f: Font = ThemeDB.fallback_font
	var fs: int = int(sb.size.y * 0.6)
	var label: String = "PLATFORM ZERO"
	var lw: float = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if lw > sb.size.x * 0.88:
		fs = int(float(fs) * sb.size.x * 0.88 / lw)
		lw = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(sb.position.x + (sb.size.x - lw) * 0.5, sb.position.y + sb.size.y * 0.72), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#EADFC8"))
	# train: eased arrival from off-screen left, stops with the engine near the platform
	var car_w: float = s.x * (0.28 if port else 0.17)
	var total: float = 7.0 * (car_w + 6.0)
	var k2: float = clampf(_t / 6.0, 0.0, 1.0)
	var e: float = 1.0 - pow(1.0 - k2, 2.6)
	var stop_x: float = s.x * 0.58 - total
	var start_x: float = -total - car_w * 2.0
	var ox: float = lerpf(start_x, stop_x, e)
	var sway: float = sin(_t * 9.0) * 1.5 * (1.0 - e)
	draw_train(self, Vector2(ox, rail_y + sway), car_w, _t)
	# steam from the engine
	var ex: float = ox + total - car_w * 0.2
	for i in range(14):
		var a: float = fmod(_t * 0.5 + float(i) / 14.0, 1.0)
		draw_circle(Vector2(ex + a * -80.0 + sin(a * 6.0 + float(i)) * 14.0, rail_y - car_w * 0.45 - a * s.y * 0.2), 14.0 + a * 46.0, Color(0.85, 0.9, 0.9, 0.22 * (1.0 - a)))
	# title
	var ta: float = clampf((_t - 2.2) / 1.6, 0.0, 1.0)
	var tfs: int = int(s.x * (0.1 if port else 0.055))
	var tw2: float = f.get_string_size("PLATFORM ZERO", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	var ty: float = s.y * 0.2 - (1.0 - ta) * 18.0
	draw_string(f, Vector2((s.x - tw2) * 0.5 + 3, ty + 4), "PLATFORM ZERO", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(0, 0, 0, 0.5 * ta))
	draw_string(f, Vector2((s.x - tw2) * 0.5, ty), "PLATFORM ZERO", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(0.95, 0.72, 0.29, ta))
	var sub: String = "the lost property car"
	var sfs: int = int(tfs * 0.34)
	var sw: float = f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
	draw_string(f, Vector2((s.x - sw) * 0.5, ty + tfs * 0.5), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(0.92, 0.87, 0.78, ta * 0.85))
	# tap hint
	if _t > 3.5:
		var ha: float = 0.6 + 0.3 * sin(_t * 3.0)
		var hint: String = "tap to begin"
		var hw: float = f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(sfs)).x
		draw_string(f, Vector2((s.x - hw) * 0.5, s.y * 0.93), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(0.92, 0.87, 0.78, ha))
	# fade in / out
	var fi: float = clampf(1.0 - _t / 0.8, 0.0, 1.0)
	var fo: float = clampf((_t - (DUR - 0.8)) / 0.8, 0.0, 1.0)
	if fi > 0.0 or fo > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.08, 0.1, maxf(fi, fo)))
