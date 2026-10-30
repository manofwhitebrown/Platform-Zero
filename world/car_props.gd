class_name CarProps
extends Node2D
## Seating + table furniture for the five non-Lost-Property cars (D1).
## Two instances per car: the BACK layer (seat frames, backrests, cushions: people sit in front of
## them) and the FRONT layer (table tops, cloths: they overlap sitters' laps). Static art, drawn once.
## Local origin = car rear (same as CarShell). Seat slots mirror Sim: x = 300 + 130 * slot (10 slots);
## the two "seat" hotspot spots sit at x = 150 and x = 1550.

const SLOT_X0: float = 300.0
const SLOT_DX: float = 130.0
const SLOTS: int = 10
const HALF: int = 5
const SPOT_SEATS: Array = [150.0, 1550.0]
const FLOOR: float = 880.0      # feet line (same as Crowd.FLOOR_Y)
const SEAT_TOP: float = 812.0   # cushion top: hip joint of the "sit" pose is 70 above the feet

var kind: String = "pass"
var car_id: String = ""
var front: bool = false
var _seed: int = 0


func setup(p_kind: String, p_car_id: String, p_front: bool, p_unlocked: bool = true) -> void:
	kind = p_kind
	car_id = p_car_id
	front = p_front
	_seed = hash(p_car_id) & 0xffff
	z_index = 1 if p_front else 0
	if not p_unlocked:
		modulate = Color(0.26, 0.3, 0.34)   # sits under the locked-car veil
	queue_redraw()


## Seat orientation per slot: even slots face right, odd face left (benches face each other).
static func orient(slot: int) -> int:
	return 1 if slot % 2 == 0 else -1


static func slot_x(slot: int) -> float:
	return SLOT_X0 + SLOT_DX * float(slot)


func _h(n: int, salt: int = 0) -> float:
	return float(absi(hash(str(_seed) + "/" + str(n) + "/" + str(salt))) % 1000) / 1000.0


func _draw() -> void:
	if front:
		if kind == "dine":
			for k in range(HALF):
				_table((slot_x(2 * k) + slot_x(2 * k + 1)) * 0.5, k)
		return
	for s in range(SLOTS):
		_seat(slot_x(s), orient(s), s)
	for j in range(SPOT_SEATS.size()):
		_seat(float(SPOT_SEATS[j]), 1 if j == 0 else -1, 20 + j)
	if kind == "sleep":
		_bunk_curtains()


func _rr(rc: Rect2, rad: float, col: Color) -> void:
	Dr.rrect(self, rc, rad, col)


func _span(a: float, b: float, y0: float, y1: float) -> Rect2:
	return Rect2(minf(a, b), y0, absf(b - a), y1 - y0)


func _floor_shadow(cx: float, half_w: float) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(cx - half_w, FLOOR - 6), Vector2(cx + half_w, FLOOR - 6), Vector2(cx + half_w + 10, FLOOR + 6), Vector2(cx - half_w - 10, FLOOR + 6)]), Color(0, 0, 0, 0.3))


func _seat(cx: float, o: int, n: int) -> void:
	match kind:
		"pass": _seat_pass(cx, o, n)
		"dine": _seat_dine(cx, o, n)
		"sleep": _seat_sleep(cx, o, n)
		"obs": _seat_obs(cx, o, n)
		"lug": _seat_lug(cx, o, n)


# ---------------------------------------------------------------- passenger: velvet benches
func _seat_pass(cx: float, o: int, n: int) -> void:
	var vel: Color = ([Color("#3b5b8f"), Color("#7a3340"), Color("#4a4f8c"), Color("#2f6a6a")][n % 4]) as Color
	var wood: Color = Color("#5a3b22")
	var bx: float = cx - 36.0 * o   # back side of the seat
	_floor_shadow(cx, 52.0)
	# frame base + brass feet
	draw_rect(_span(bx - 4.0 * o, cx + 52.0 * o, 832.0, 866.0), wood)
	draw_rect(_span(bx - 4.0 * o, cx + 52.0 * o, 832.0, 836.0), Color(0, 0, 0, 0.35))
	for fx in [bx, cx + 46.0 * o]:
		draw_rect(Rect2(fx - 5.0, 866.0, 10.0, 12.0), Pal.BRASS)
	# backrest (tall, tufted)
	var br: Rect2 = _span(bx - 24.0 * o, bx + 4.0 * o, 690.0, 820.0)
	_rr(br, 10.0, Dr.shade(vel, 0.85))
	var face: Rect2 = _span(bx - 18.0 * o, bx + 4.0 * o, 700.0, 814.0)
	_rr(face, 8.0, vel)
	for ty in [730.0, 770.0]:
		draw_circle(Vector2(bx - 8.0 * o, ty), 3.5, Pal.BRASS)
	# headrest doily
	draw_rect(_span(bx - 22.0 * o, bx + 4.0 * o, 706.0, 730.0), Color(Pal.PARCHMENT.r, Pal.PARCHMENT.g, Pal.PARCHMENT.b, 0.75))
	draw_line(Vector2(bx - 22.0 * o, 730.0), Vector2(bx + 4.0 * o, 730.0), Pal.BRASS, 2.0)
	# cushion
	_rr(_span(bx - 8.0 * o, cx + 56.0 * o, SEAT_TOP - 6.0, 834.0), 9.0, vel)
	draw_rect(_span(bx - 4.0 * o, cx + 50.0 * o, SEAT_TOP - 6.0, SEAT_TOP - 2.0), Color(1, 1, 1, 0.14))
	draw_line(Vector2(bx + 6.0 * o, SEAT_TOP + 4.0), Vector2(cx + 50.0 * o, SEAT_TOP + 4.0), Color(0, 0, 0, 0.18), 2.0)


# ---------------------------------------------------------------- dining: bentwood chairs
func _seat_dine(cx: float, o: int, _n: int) -> void:
	var wood: Color = Color("#7c4a28")
	var bx: float = cx - 32.0 * o
	_floor_shadow(cx, 44.0)
	# rear legs + front legs (side view: two visible)
	draw_rect(_span(bx - 4.0 * o, bx + 5.0 * o, 818.0, 876.0), Dr.shade(wood, 0.8))
	draw_rect(_span(cx + 38.0 * o, cx + 47.0 * o, 818.0, 876.0), wood)
	draw_rect(_span(bx, cx + 42.0 * o, 852.0, 857.0), Dr.shade(wood, 0.7))
	# backrest posts + cane slats
	draw_rect(_span(bx - 6.0 * o, bx + 5.0 * o, 700.0, 820.0), wood)
	for sy in [722.0, 752.0, 782.0]:
		draw_rect(_span(bx - 12.0 * o, bx + 5.0 * o, sy, sy + 12.0), Dr.shade(wood, 1.15))
		draw_rect(_span(bx - 12.0 * o, bx + 5.0 * o, sy + 8.0, sy + 12.0), Color(0, 0, 0, 0.25))
	draw_circle(Vector2(bx - 0.5 * o, 700.0), 7.0, Pal.BRASS)
	# seat pad with piping
	_rr(_span(bx - 8.0 * o, cx + 50.0 * o, SEAT_TOP - 4.0, 826.0), 6.0, wood)
	_rr(_span(bx - 4.0 * o, cx + 46.0 * o, SEAT_TOP - 8.0, SEAT_TOP + 4.0), 5.0, Color("#9a3b32"))
	draw_line(Vector2(bx - 4.0 * o, SEAT_TOP - 7.0), Vector2(cx + 46.0 * o, SEAT_TOP - 7.0), Pal.BRASS, 1.5)


# ---------------------------------------------------------------- sleeper: bunks
func _seat_sleep(cx: float, o: int, n: int) -> void:
	var wood: Color = Color("#4d3326")
	var blanket: Color = ([Color("#7b3a52"), Color("#3c6a7a"), Color("#a07a3a"), Color("#56507f")][n % 4]) as Color
	_floor_shadow(cx, 62.0)
	# lower bunk: box frame + mattress + folded blanket + pillow at the back
	draw_rect(Rect2(cx - 60.0, 828.0, 120.0, 40.0), wood)
	draw_rect(Rect2(cx - 60.0, 828.0, 120.0, 5.0), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(cx - 60.0, 868.0, 120.0, 8.0), Dr.shade(wood, 0.6))
	draw_rect(Rect2(cx - 40.0, 846.0, 80.0, 3.0), Color(0, 0, 0, 0.22))
	_rr(Rect2(cx - 62.0, SEAT_TOP - 6.0, 124.0, 26.0), 10.0, Color("#d9cfba"))
	_rr(Rect2(cx - 62.0 + (0.0 if o > 0 else 62.0), SEAT_TOP - 4.0, 62.0, 22.0), 9.0, blanket)
	for k in range(3):
		draw_line(Vector2(cx - 62.0 + (0.0 if o > 0 else 62.0) + 10.0 + k * 18.0, SEAT_TOP), Vector2(cx - 62.0 + (0.0 if o > 0 else 62.0) + 10.0 + k * 18.0, SEAT_TOP + 14.0), Color(1, 1, 1, 0.16), 3.0)
	var px: float = cx - 40.0 * o
	draw_colored_polygon(PackedVector2Array([Vector2(px - 24.0, SEAT_TOP - 6.0), Vector2(px + 24.0, SEAT_TOP - 6.0), Vector2(px + 20.0, SEAT_TOP - 26.0), Vector2(px - 20.0, SEAT_TOP - 26.0)]), Color("#efe6d2"))
	# upper bunk: slab + mattress + brass rail
	draw_rect(Rect2(cx - 62.0, 640.0, 124.0, 22.0), wood)
	draw_rect(Rect2(cx - 62.0, 640.0, 124.0, 4.0), Color(1, 1, 1, 0.12))
	_rr(Rect2(cx - 60.0, 616.0, 120.0, 26.0), 9.0, Dr.shade(blanket, 0.8))
	draw_line(Vector2(cx - 58.0, 604.0), Vector2(cx + 58.0, 604.0), Pal.BRASS, 3.0)
	draw_line(Vector2(cx - 58.0, 604.0), Vector2(cx - 58.0, 640.0), Pal.BRASS, 3.0)
	draw_line(Vector2(cx + 58.0, 604.0), Vector2(cx + 58.0, 640.0), Pal.BRASS, 3.0)
	# reading lamp over the head
	var lx: float = cx - 34.0 * o
	draw_line(Vector2(lx, 666.0), Vector2(lx, 690.0), Pal.BRASS, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(lx - 12.0, 704.0), Vector2(lx + 12.0, 704.0), Vector2(lx + 6.0, 688.0), Vector2(lx - 6.0, 688.0)]), Pal.BRASS)
	draw_rect(Rect2(lx - 8.0, 703.0, 16.0, 4.0), Color(1.0, 0.9, 0.55, 0.9))


func _bunk_curtains() -> void:
	# tied-back curtain between each pair of bays (behind people: this is the back layer)
	var col: Color = Color("#5a3a74")
	for k in range(HALF + 1):
		var x: float = SLOT_X0 + SLOT_DX * (2.0 * k - 0.5) - 0.0
		if x < 140.0 or x > 1700.0:
			continue
		var top: float = 560.0
		draw_rect(Rect2(x - 14.0, top - 4.0, 28.0, 6.0), Pal.BRASS)
		var pts := PackedVector2Array([Vector2(x - 14.0, top), Vector2(x + 14.0, top), Vector2(x + 6.0, 700.0), Vector2(x + 16.0, 760.0), Vector2(x + 16.0, 876.0), Vector2(x - 16.0, 876.0), Vector2(x - 16.0, 760.0), Vector2(x - 6.0, 700.0)])
		draw_colored_polygon(pts, col)
		for f in range(-2, 3):
			draw_line(Vector2(x + f * 6.0, top + 6.0), Vector2(x + f * 7.0, 874.0), Color(0, 0, 0, 0.22), 2.0)
		draw_rect(Rect2(x - 18.0, 722.0, 36.0, 8.0), Pal.BRASS)   # tie-back band


# ---------------------------------------------------------------- observation: tufted lounge seats
func _seat_obs(cx: float, o: int, _n: int) -> void:
	var leather: Color = Color("#8a4a2e")
	var bx: float = cx - 38.0 * o
	_floor_shadow(cx, 56.0)
	draw_rect(_span(bx - 2.0 * o, cx + 54.0 * o, 834.0, 862.0), Color("#3a2a1c"))
	for fx in [bx + 2.0 * o, cx + 48.0 * o]:
		draw_rect(Rect2(fx - 4.0, 862.0, 8.0, 14.0), Pal.BRASS)
	# low wide back, tufted + studded
	_rr(_span(bx - 26.0 * o, bx + 6.0 * o, 730.0, 822.0), 12.0, Dr.shade(leather, 0.8))
	_rr(_span(bx - 20.0 * o, bx + 6.0 * o, 738.0, 816.0), 10.0, leather)
	for ty in [758.0, 790.0]:
		draw_circle(Vector2(bx - 8.0 * o, ty), 3.5, Pal.BRASS)
		draw_line(Vector2(bx - 18.0 * o, ty + 14.0), Vector2(bx + 2.0 * o, ty + 14.0), Color(0, 0, 0, 0.18), 2.0)
	# plump cushion
	_rr(_span(bx - 10.0 * o, cx + 58.0 * o, SEAT_TOP - 8.0, 838.0), 12.0, leather)
	draw_rect(_span(bx - 4.0 * o, cx + 52.0 * o, SEAT_TOP - 8.0, SEAT_TOP - 3.0), Color(1, 1, 1, 0.16))
	for k in range(4):
		draw_circle(Vector2(bx + 10.0 * o + k * 24.0 * o, SEAT_TOP + 4.0), 2.5, Pal.BRASS)


# ---------------------------------------------------------------- luggage: crate + trunk seats
func _seat_lug(cx: float, o: int, n: int) -> void:
	var plank: Color = Color("#7b6038")
	_floor_shadow(cx, 50.0)
	var trunk_variant: bool = _h(n, 1) > 0.55
	# a tall trunk behind as a backrest on some seats
	if _h(n, 2) > 0.4:
		var tx: float = cx - 54.0 * o
		var tr: Rect2 = Rect2(tx - 22.0, 744.0, 44.0, 128.0)
		_rr(tr, 5.0, Color("#3e3326"))
		draw_rect(Rect2(tr.position.x, tr.position.y + 40.0, tr.size.x, 5.0), Pal.BRASS)
		draw_rect(Rect2(tr.position.x, tr.position.y + 84.0, tr.size.x, 5.0), Pal.BRASS)
		draw_circle(Vector2(tx, 806.0), 4.0, Pal.BRASS)
	var rc := Rect2(cx - 40.0, SEAT_TOP - 4.0, 80.0, 872.0 - SEAT_TOP + 4.0)
	if trunk_variant:
		_rr(rc, 8.0, Color("#4a3a2a"))
		draw_rect(Rect2(rc.position.x, rc.position.y + 22.0, rc.size.x, 5.0), Pal.BRASS)
		for sx in [-24.0, 24.0]:
			draw_rect(Rect2(cx + sx - 4.0, rc.position.y, 8.0, rc.size.y), Color("#2a2018"))
		draw_rect(Rect2(cx - 5.0, rc.position.y + 16.0, 10.0, 14.0), Pal.BRASS)
		draw_rect(Rect2(cx - 40.0, rc.position.y, 80.0, 4.0), Color(1, 1, 1, 0.14))
	else:
		draw_rect(rc, plank)
		for py in [828.0, 846.0]:
			draw_line(Vector2(rc.position.x, py), Vector2(rc.end.x, py), Color(0, 0, 0, 0.35), 2.0)
		draw_rect(rc, Color("#3a2c1a"), false, 4.0)
		draw_line(rc.position + Vector2(4, 4), rc.end - Vector2(4, 4), Color("#3a2c1a"), 4.0)
		draw_rect(Rect2(cx - 22.0, 836.0, 44.0, 10.0), Color(0.93, 0.87, 0.74, 0.55))   # stencilled label
		draw_rect(Rect2(rc.position.x, rc.position.y, rc.size.x, 4.0), Color(1, 1, 1, 0.18))


# ---------------------------------------------------------------- dining table (front layer)
func _table(mx: float, k: int) -> void:
	var cloth: Color = Color("#e9dfc8") if k % 2 == 0 else Color("#e2cfa8")
	# pedestal
	draw_rect(Rect2(mx - 5.0, 806.0, 10.0, 66.0), Color("#2f2018"))
	draw_rect(Rect2(mx - 30.0, 868.0, 60.0, 8.0), Color("#2f2018"))
	draw_rect(Rect2(mx - 30.0, 868.0, 60.0, 2.0), Pal.BRASS)
	# cloth top + short drop with a red stripe
	_rr(Rect2(mx - 52.0, 768.0, 104.0, 12.0), 4.0, cloth)
	var drop := PackedVector2Array([Vector2(mx - 50.0, 779.0), Vector2(mx + 50.0, 779.0), Vector2(mx + 44.0, 806.0), Vector2(mx - 44.0, 806.0)])
	draw_colored_polygon(drop, Dr.shade(cloth, 0.9))
	draw_rect(Rect2(mx - 48.0, 782.0, 96.0, 4.0), Color("#b8483a"))
	for q in range(-3, 4):
		draw_line(Vector2(mx + q * 14.0, 786.0), Vector2(mx + q * 12.0, 806.0), Color(0, 0, 0, 0.12), 2.0)
	# small brass lamp with a glowing shade + cup + plate
	draw_rect(Rect2(mx - 3.0, 744.0, 6.0, 24.0), Pal.BRASS)
	draw_colored_polygon(PackedVector2Array([Vector2(mx - 16.0, 746.0), Vector2(mx + 16.0, 746.0), Vector2(mx + 8.0, 722.0), Vector2(mx - 8.0, 722.0)]), Color(1.0, 0.78, 0.4))
	draw_rect(Rect2(mx - 16.0, 745.0, 32.0, 3.0), Pal.BRASS)
	if k % 2 == 1:
		draw_rect(Rect2(mx - 40.0, 758.0, 14.0, 10.0), Color("#e8e2d4"))
	else:
		draw_rect(Rect2(mx + 24.0, 758.0, 14.0, 10.0), Color("#e8e2d4"))
