class_name CarShell
extends Node2D
## One train car interior: ceiling cove, window pillars (holes show the scenery behind),
## wallpaper, wainscot, carpet, door, underframe + wheels. Local origin = car rear, x 0..W.

const W: float = 1800.0
const Y_ROOF: float = 30.0
const Y_WIN0: float = 130.0
const Y_WIN1: float = 470.0
const Y_FLOOR: float = 820.0
const Y_BODY_END: float = 960.0
const WIN_X0: float = 100.0
const WIN_PITCH: float = 400.0
const WIN_W: float = 340.0
const WIN_COUNT: int = 4

const STYLE: Dictionary = {
	"lp":    {"wall": Color("#1f4f55"), "wood": Color("#6a4326"), "carpet": Color("#7a2f2c"), "paper": Color("#2a6068")},
	"pass":  {"wall": Color("#2e4a40"), "wood": Color("#7a5530"), "carpet": Color("#2c3f5c"), "paper": Color("#3a5a4e")},
	"dine":  {"wall": Color("#5a2c2a"), "wood": Color("#4a2d1a"), "carpet": Color("#c9b88e"), "paper": Color("#6e3733")},
	"sleep": {"wall": Color("#3c2c4c"), "wood": Color("#5a3b2c"), "carpet": Color("#4d3a64"), "paper": Color("#4b3860")},
	"obs":   {"wall": Color("#2a4252"), "wood": Color("#6f5a3a"), "carpet": Color("#5b6e78"), "paper": Color("#36566a")},
	"lug":   {"wall": Color("#3a3f36"), "wood": Color("#55452e"), "carpet": Color("#2a2e2a"), "paper": Color("#454b40")},
}

var kind: String = "lp"
var car_id: String = ""
var unlocked: bool = true
var wheel_rot: float = 0.0
var _style: Dictionary = STYLE["lp"]


func setup(c: Dictionary) -> void:
	kind = String(c.get("kind", "lp"))
	car_id = String(c.get("id", ""))
	unlocked = bool(c.get("unlocked", true))
	_style = STYLE.get(kind, STYLE["lp"])
	queue_redraw()


func set_wheels(rot: float) -> void:
	wheel_rot = rot
	queue_redraw()


func window_rects() -> Array:
	var out: Array = []
	for i in range(WIN_COUNT):
		out.append(Rect2(WIN_X0 + i * WIN_PITCH, Y_WIN0, WIN_W, Y_WIN1 - Y_WIN0))
	return out


func _draw() -> void:
	var wall: Color = _style["wall"]
	var wood: Color = _style["wood"]
	var carpet: Color = _style["carpet"]
	var paper: Color = _style["paper"]
	var seed_i: int = hash(car_id) & 0xffff

	# --- curved roof, vents (above the cabin)
	var roof := PackedVector2Array([Vector2(-4, Y_ROOF + 2), Vector2(W + 4, Y_ROOF + 2), Vector2(W - 40, Y_ROOF - 26), Vector2(W * 0.5, Y_ROOF - 46), Vector2(40, Y_ROOF - 26)])
	draw_colored_polygon(roof, Color("#0f2630"))
	draw_line(Vector2(40, Y_ROOF - 26), Vector2(W * 0.5, Y_ROOF - 46), Color(1, 1, 1, 0.12), 3.0)
	draw_line(Vector2(W * 0.5, Y_ROOF - 46), Vector2(W - 40, Y_ROOF - 26), Color(1, 1, 1, 0.06), 3.0)
	for vx in [420.0, 900.0, 1380.0]:
		draw_rect(Rect2(vx - 22, Y_ROOF - 66, 44, 22), Color("#16323c"))
		draw_rect(Rect2(vx - 28, Y_ROOF - 72, 56, 8), Color("#1c3d49"))
	draw_rect(Rect2(0, Y_ROOF - 2, W, 6), Pal.BRASS)
	# --- outer roof + ceiling cove (above windows)
	Dr.vgrad(self, Rect2(0, Y_ROOF, W, 40), Color("#0b1e26"), Color("#13303a"))
	Dr.vgrad(self, Rect2(0, Y_ROOF + 40, W, Y_WIN0 - Y_ROOF - 40), Dr.shade(wall, 1.15), Dr.shade(wall, 0.8))
	# cove ribs
	for i in range(0, int(W), 60):
		draw_line(Vector2(i, Y_ROOF + 44), Vector2(i, Y_WIN0 - 6), Color(0, 0, 0, 0.12), 2.0)
	draw_rect(Rect2(0, Y_WIN0 - 14, W, 14), Pal.BRASS)
	draw_rect(Rect2(0, Y_WIN0 - 14, W, 3), Color(1, 0.9, 0.6, 0.55))
	draw_rect(Rect2(0, Y_WIN0 - 2, W, 4), Color(0, 0, 0, 0.35))

	# --- window pillars (full height between windows, plus ends)
	var xs: Array = [0.0]
	for i in range(WIN_COUNT):
		xs.append(WIN_X0 + i * WIN_PITCH)
		xs.append(WIN_X0 + i * WIN_PITCH + WIN_W)
	xs.append(W)
	for i in range(0, xs.size(), 2):
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		if x1 - x0 < 1.0:
			continue
		Dr.vgrad(self, Rect2(x0, Y_WIN0, x1 - x0, Y_WIN1 - Y_WIN0), Dr.shade(paper, 1.1), Dr.shade(paper, 0.85))
		_lattice(Rect2(x0, Y_WIN0, x1 - x0, Y_WIN1 - Y_WIN0), Color(1, 1, 1, 0.06))
		draw_line(Vector2(x0, Y_WIN0), Vector2(x0, Y_WIN1), Color(0, 0, 0, 0.3), 2.0)
		draw_line(Vector2(x1, Y_WIN0), Vector2(x1, Y_WIN1), Color(0, 0, 0, 0.3), 2.0)

	# --- window frames + glass
	for r in window_rects():
		var rc: Rect2 = r
		var fr: Color = Dr.shade(wood, 1.15)
		draw_rect(Rect2(rc.position.x - 12, rc.position.y - 6, rc.size.x + 24, 12), fr)
		draw_rect(Rect2(rc.position.x - 12, rc.end.y - 6, rc.size.x + 24, 18), fr)
		draw_rect(Rect2(rc.position.x - 12, rc.position.y, 12, rc.size.y), fr)
		draw_rect(Rect2(rc.end.x, rc.position.y, 12, rc.size.y), fr)
		draw_rect(Rect2(rc.position.x - 12, rc.end.y + 10, rc.size.x + 24, 4), Pal.BRASS)
		# glass tint + diagonal reflection
		draw_rect(rc, Color(0.55, 0.75, 0.85, 0.06))
		var refl := PackedVector2Array([
			rc.position + Vector2(rc.size.x * 0.12, 0), rc.position + Vector2(rc.size.x * 0.34, 0),
			Vector2(rc.position.x + rc.size.x * 0.12, rc.end.y), Vector2(rc.position.x - rc.size.x * 0.10, rc.end.y)])
		draw_colored_polygon(refl, Color(1, 1, 1, 0.045))
		# drop shadow from top frame
		Dr.vgrad(self, Rect2(rc.position.x, rc.position.y, rc.size.x, 26), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0))

	# --- wallpaper band + wainscot
	Dr.vgrad(self, Rect2(0, Y_WIN1 + 14, W, 150), Dr.shade(paper, 0.95), Dr.shade(paper, 0.7))
	_lattice(Rect2(0, Y_WIN1 + 14, W, 150), Color(Pal.BRASS.r, Pal.BRASS.g, Pal.BRASS.b, 0.16))
	# dado rail
	var rail_y: float = Y_WIN1 + 164
	draw_rect(Rect2(0, rail_y, W, 16), Pal.BRASS)
	draw_rect(Rect2(0, rail_y, W, 3), Color(1, 0.92, 0.65, 0.6))
	draw_rect(Rect2(0, rail_y + 16, W, 6), Color(0, 0, 0, 0.4))
	Dr.planks(self, Rect2(0, rail_y + 22, W, Y_FLOOR - rail_y - 22), wood, 54.0, seed_i)
	# panel inlays on wainscot
	for i in range(0, int(W), 300):
		var pr := Rect2(i + 26, rail_y + 44, 248, Y_FLOOR - rail_y - 78)
		draw_rect(pr, Color(0, 0, 0, 0.16), false, 3.0)
		draw_rect(Rect2(pr.position + Vector2(3, 3), pr.size - Vector2(6, 6)), Color(1, 1, 1, 0.05), false, 1.5)
	# skirting + brass kick
	draw_rect(Rect2(0, Y_FLOOR - 16, W, 16), Dr.shade(wood, 0.7))
	draw_rect(Rect2(0, Y_FLOOR - 16, W, 3), Color(1, 1, 1, 0.12))

	# --- floor / carpet runner
	Dr.vgrad(self, Rect2(0, Y_FLOOR, W, 140), Dr.shade(wood, 0.55), Dr.shade(wood, 0.3))
	for i in range(0, int(W), 90):
		draw_line(Vector2(i, Y_FLOOR), Vector2(i - 70, Y_FLOOR + 140), Color(0, 0, 0, 0.16), 2.0)
	var run := Rect2(40, Y_FLOOR + 22, W - 80, 62)
	Dr.vgrad(self, run, Dr.shade(carpet, 1.1), Dr.shade(carpet, 0.8))
	draw_rect(run, Pal.BRASS, false, 3.0)
	draw_rect(Rect2(run.position + Vector2(10, 10), run.size - Vector2(20, 20)), Color(Pal.PARCHMENT.r, Pal.PARCHMENT.g, Pal.PARCHMENT.b, 0.35), false, 2.0)
	for i in range(0, int(run.size.x), 48):
		var cx: float = run.position.x + 24.0 + i
		var cy: float = run.position.y + run.size.y * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - 14), Vector2(cx + 16, cy), Vector2(cx, cy + 14), Vector2(cx - 16, cy)]), Color(Pal.PARCHMENT.r, Pal.PARCHMENT.g, Pal.PARCHMENT.b, 0.28))
	Dr.vgrad(self, Rect2(0, Y_FLOOR + 100, W, 40), Color(0, 0, 0, 0), Color(0, 0, 0, 0.45))

	# --- door at the rear end of the car
	_door(Rect2(8, Y_WIN0 + 30, 96, Y_FLOOR - Y_WIN0 - 30), wood)

	# --- underframe + bogies + rail
	Dr.vgrad(self, Rect2(0, Y_BODY_END, W, 60), Color("#10242c"), Color("#050d11"))
	draw_rect(Rect2(0, Y_BODY_END, W, 6), Pal.BRASS)
	for cx2 in [260.0, 1540.0]:
		_bogie(Vector2(cx2, 1022.0))
	draw_rect(Rect2(0, 1076, W, 8), Color("#2a3238"))
	draw_rect(Rect2(0, 1076, W, 2), Color(1, 1, 1, 0.25))

	# ambient occlusion at wall/ceiling + floor
	Dr.vgrad(self, Rect2(0, Y_WIN1 + 14, W, 36), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0))
	if not unlocked:
		_locked_overlay()


func _lattice(rc: Rect2, col: Color) -> void:
	var step: float = 40.0
	var x: float = rc.position.x - rc.size.y
	while x < rc.end.x:
		var a := Vector2(x, rc.position.y)
		var b := Vector2(x + rc.size.y, rc.end.y)
		var a2 := Vector2(x + rc.size.y, rc.position.y)
		var b2 := Vector2(x, rc.end.y)
		_clip_line(a, b, rc, col)
		_clip_line(a2, b2, rc, col)
		x += step


func _clip_line(a: Vector2, b: Vector2, rc: Rect2, col: Color) -> void:
	# cheap clip: sample the line at its ends against rc by parametric trimming
	var t0: float = 0.0
	var t1: float = 1.0
	var d: Vector2 = b - a
	var p: Array = [-d.x, d.x, -d.y, d.y]
	var q: Array = [a.x - rc.position.x, rc.end.x - a.x, a.y - rc.position.y, rc.end.y - a.y]
	for i in range(4):
		var pi: float = p[i]
		var qi: float = q[i]
		if absf(pi) < 0.0001:
			if qi < 0.0:
				return
		else:
			var t: float = qi / pi
			if pi < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
	if t0 < t1:
		draw_line(a + d * t0, a + d * t1, col, 1.5)


func _door(rc: Rect2, wood: Color) -> void:
	Dr.vgrad(self, rc, Dr.shade(wood, 0.95), Dr.shade(wood, 0.7))
	draw_rect(rc, Pal.BRASS, false, 5.0)
	var gl := Rect2(rc.position.x + 16, rc.position.y + 24, rc.size.x - 32, 120)
	draw_rect(gl, Color("#0b1e26"))
	draw_rect(gl, Pal.BRASS, false, 3.0)
	draw_rect(Rect2(gl.position, Vector2(gl.size.x, 40)), Color(1, 1, 1, 0.05))
	draw_circle(Vector2(rc.end.x - 18, rc.position.y + rc.size.y * 0.55), 7.0, Pal.BRASS)
	draw_circle(Vector2(rc.end.x - 18, rc.position.y + rc.size.y * 0.55), 3.0, Color(1, 0.92, 0.65))
	draw_rect(Rect2(rc.position.x + 14, rc.position.y + 170, rc.size.x - 28, rc.size.y - 210), Color(0, 0, 0, 0.18), false, 3.0)


func _bogie(c: Vector2) -> void:
	draw_rect(Rect2(c.x - 140, c.y - 36, 280, 16), Color("#1a2a31"))
	for dx in [-70.0, 70.0]:
		var p := Vector2(c.x + dx, c.y + 20.0)
		draw_circle(p, 58.0, Color("#1b252b"))
		draw_arc(p, 56.0, 0, TAU, 40, Color("#5b6a72"), 5.0)
		draw_circle(p, 12.0, Pal.BRASS)
		for k in range(6):
			var a: float = wheel_rot + float(k) * TAU / 6.0
			draw_line(p, p + Vector2(cos(a), sin(a)) * 50.0, Color("#3a4850"), 4.0)


func _locked_overlay() -> void:
	draw_rect(Rect2(0, Y_ROOF, W, Y_BODY_END - Y_ROOF), Color(0.02, 0.05, 0.07, 0.72))
	var c := Vector2(W * 0.5, 520)
	Dr.rrect(self, Rect2(c.x - 150, c.y - 50, 300, 100), 14.0, Pal.PARCHMENT)
	draw_rect(Rect2(c.x - 150, c.y - 50, 300, 100), Pal.BRASS, false, 4.0)
	draw_arc(c + Vector2(0, -80), 26.0, PI, TAU, 16, Pal.BRASS, 8.0)
	Dr.rrect(self, Rect2(c.x - 34, c.y - 80, 68, 48), 8.0, Pal.BRASS)
