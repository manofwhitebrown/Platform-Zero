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
	_wall_dress()
	for i in range(8):
		var sx: float = 150.0 + 200.0 * float(i)
		var sk: String = String((Sim.SPOT_LAYOUT.get(kind, Sim.SPOT_LAYOUT["lp"]) as Array)[i])
		match sk:
			"rack": _spot_rack(sx, i)
			"sill": _spot_sill(sx)
			"curtain": _spot_curtain(sx, i)
			"table": _spot_shelf(sx)
	for s in range(SLOTS):
		_seat(slot_x(s), orient(s), s)
	for j in range(SPOT_SEATS.size()):
		_seat(float(SPOT_SEATS[j]), 1 if j == 0 else -1, 20 + j)
	if kind == "sleep":
		_bunk_curtains()
	for i in range(8):
		var sx2: float = 150.0 + 200.0 * float(i)
		var sk2: String = String((Sim.SPOT_LAYOUT.get(kind, Sim.SPOT_LAYOUT["lp"]) as Array)[i])
		if sk2 == "bin":
			_spot_bin(sx2)
		elif sk2 == "floor":
			_spot_mat(sx2, i)
	_signature()


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


# ---------------------------------------------------------------- D2: spot props (hotspot = visible prop)
func _spot_rack(x: float, i: int) -> void:
	# brass luggage rack with a rope net and bag silhouettes (item rests at y~380)
	var y: float = 396.0
	draw_line(Vector2(x - 78.0, y), Vector2(x + 78.0, y), Pal.BRASS, 5.0)
	draw_line(Vector2(x - 78.0, y + 22.0), Vector2(x + 78.0, y + 22.0), Pal.BRASS, 3.0)
	for bx in [x - 78.0, x + 78.0]:
		draw_line(Vector2(bx, y), Vector2(bx, y + 22.0), Pal.BRASS, 3.0)
		draw_line(Vector2(bx, y + 22.0), Vector2(bx + (14.0 if bx < x else -14.0), 440.0), Pal.BRASS, 3.0)
	for k in range(-5, 6):
		draw_line(Vector2(x + k * 14.0, y + 3.0), Vector2(x + k * 12.0, y + 21.0), Color(0.9, 0.8, 0.55, 0.45), 1.5)
	var bag: Color = ([Color("#4a3a2a"), Color("#5a2f2c"), Color("#2f4a52")][i % 3]) as Color
	_rr(Rect2(x - 60.0 + 8.0 * (i % 2), 362.0, 44.0, 32.0), 6.0, bag)
	draw_rect(Rect2(x - 52.0 + 8.0 * (i % 2), 370.0, 28.0, 3.0), Pal.BRASS)


func _spot_sill(x: float) -> void:
	# brass-edged ledge in front of the window (item rests at y~470)
	draw_rect(Rect2(x - 70.0, 474.0, 140.0, 12.0), Color("#6a4a2a"))
	draw_rect(Rect2(x - 70.0, 474.0, 140.0, 3.0), Color(1, 0.9, 0.6, 0.5))
	draw_rect(Rect2(x - 74.0, 486.0, 148.0, 4.0), Pal.BRASS)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 60.0, 490.0), Vector2(x + 60.0, 490.0), Vector2(x + 48.0, 506.0), Vector2(x - 48.0, 506.0)]), Color(0, 0, 0, 0.25))


func _spot_curtain(x: float, i: int) -> void:
	# window curtain tied back on both sides, with a fold to hide things in (item at y~420)
	var col: Color = Color("#6a3040") if kind != "sleep" else Color("#5a3a74")
	draw_rect(Rect2(x - 86.0, 126.0, 172.0, 7.0), Pal.BRASS)
	for side in [-1.0, 1.0]:
		var ax: float = x + side * 74.0
		draw_colored_polygon(PackedVector2Array([Vector2(ax - 16.0, 134.0), Vector2(ax + 16.0, 134.0), Vector2(ax + (10.0 if side > 0.0 else 8.0), 400.0), Vector2(ax + 22.0, 474.0), Vector2(ax - 22.0, 474.0), Vector2(ax - (8.0 if side > 0.0 else 10.0), 400.0)]), col)
		for f in range(-2, 3):
			draw_line(Vector2(ax + f * 6.0, 140.0), Vector2(ax + f * 8.0, 470.0), Color(0, 0, 0, 0.22), 2.0)
		draw_rect(Rect2(ax - 14.0, 392.0, 28.0, 8.0), Pal.BRASS)
	draw_arc(Vector2(x, 134.0), 48.0, 0.15, PI - 0.15, 12, Dr.shade(col, 0.8), 6.0)


func _spot_shelf(x: float) -> void:
	# wall shelf on two brass brackets (item rests at y~735)
	draw_rect(Rect2(x - 44.0, 746.0, 88.0, 8.0), Color("#6a4a2a"))
	draw_rect(Rect2(x - 44.0, 746.0, 88.0, 2.0), Color(1, 0.9, 0.6, 0.5))
	for bx in [x - 30.0, x + 30.0]:
		draw_line(Vector2(bx, 754.0), Vector2(bx, 780.0), Pal.BRASS, 4.0)
		draw_line(Vector2(bx, 780.0), Vector2(bx - 12.0, 754.0), Pal.BRASS, 2.0)


func _spot_bin(x: float) -> void:
	# wicker bin (item at y~838)
	var w: Color = Color("#8a6a3a")
	draw_colored_polygon(PackedVector2Array([Vector2(x - 34.0, 826.0), Vector2(x + 34.0, 826.0), Vector2(x + 28.0, 874.0), Vector2(x - 28.0, 874.0)]), w)
	for k in range(5):
		draw_line(Vector2(x - 32.0 + k * 3.0, 832.0 + k * 9.0), Vector2(x + 32.0 - k * 3.0, 832.0 + k * 9.0), Color(0, 0, 0, 0.28), 2.0)
	draw_rect(Rect2(x - 36.0, 822.0, 72.0, 6.0), Dr.shade(w, 0.7))


func _spot_mat(x: float, i: int) -> void:
	# a worn mat with a dark floor shadow (item at y~862)
	var c: Color = ([Color("#7a3a32"), Color("#3a5a6a"), Color("#8a7a4a")][i % 3]) as Color
	_rr(Rect2(x - 52.0, 862.0, 104.0, 14.0), 5.0, c)
	draw_rect(Rect2(x - 52.0, 862.0, 104.0, 3.0), Color(1, 1, 1, 0.14))
	draw_rect(Rect2(x - 44.0, 868.0, 88.0, 2.0), Color(1, 0.9, 0.6, 0.35))


# ---------------------------------------------------------------- D2: per-car signature props
func _wall_dress() -> void:
	match kind:
		"pass":
			for wi in range(4):   # half-drawn blinds
				var wx: float = 100.0 + 400.0 * float(wi)
				var d: float = 24.0 + 40.0 * _h(wi, 7)
				draw_rect(Rect2(wx, 130.0, 340.0, d), Color("#d9cfb4"))
				for ly in range(0, int(d), 8):
					draw_line(Vector2(wx, 134.0 + ly), Vector2(wx + 340.0, 134.0 + ly), Color(0, 0, 0, 0.13), 2.0)
				draw_rect(Rect2(wx, 130.0 + d, 340.0, 4.0), Pal.BRASS)
			# route map + punch box on the pillar walls
			_rr(Rect2(450.0, 520.0, 40.0, 56.0), 3.0, Color("#e9dfc8"))
			draw_line(Vector2(456.0, 560.0), Vector2(484.0, 530.0), Color("#c8503c"), 2.0)
		"dine":
			# menu board
			_rr(Rect2(870.0, 515.0, 120.0, 90.0), 5.0, Color("#1b2a2a"))
			draw_rect(Rect2(870.0, 515.0, 120.0, 90.0), Pal.BRASS, false, 4.0)
			for ly in range(0, 5):
				draw_line(Vector2(884.0, 536.0 + ly * 14.0), Vector2(884.0 + 60.0 + 30.0 * _h(ly, 3), 536.0 + ly * 14.0), Color(0.93, 0.9, 0.8, 0.7), 3.0)
			# kitchen pass-through hatch (right end)
			_rr(Rect2(1650.0, 560.0, 110.0, 80.0), 4.0, Color("#0e1a1c"))
			draw_rect(Rect2(1650.0, 560.0, 110.0, 80.0), Pal.BRASS, false, 5.0)
			draw_rect(Rect2(1650.0, 638.0, 110.0, 8.0), Color("#6a4a2a"))
			draw_rect(Rect2(1664.0, 604.0, 24.0, 34.0), Color("#c9c3b4"))
			draw_rect(Rect2(1700.0, 612.0, 20.0, 26.0), Color("#c8503c"))
			for t in range(-1, 2):   # hanging pendant lamps over the tables
				pass
		"sleep":
			# star-pattern valance in the ceiling cove
			for k in range(26):
				draw_circle(Vector2(60.0 + 66.0 * float(k), 78.0 + 18.0 * _h(k, 5)), 2.2, Color(1, 0.9, 0.6, 0.55))
		"obs":
			# brass rail below the windows + star dome in the cove
			draw_line(Vector2(0.0, 520.0), Vector2(1800.0, 520.0), Pal.BRASS, 5.0)
			for px in range(40, 1800, 220):
				draw_line(Vector2(px, 520.0), Vector2(px, 560.0), Pal.BRASS, 3.0)
			draw_rect(Rect2(0.0, 76.0, 1800.0, 44.0), Color("#0b1a30"))
			for k in range(70):
				draw_circle(Vector2(1800.0 * _h(k, 11), 78.0 + 40.0 * _h(k, 12)), 1.2 + 1.4 * _h(k, 13), Color(1, 0.95, 0.8, 0.4 + 0.5 * _h(k, 14)))
		"lug":
			# stencilled wall tags and hanging lanterns
			for k in range(5):
				var tx: float = 280.0 + 340.0 * float(k)
				draw_line(Vector2(tx, 130.0), Vector2(tx, 168.0), Color("#2a2018"), 2.0)
				_rr(Rect2(tx - 10.0, 168.0, 20.0, 26.0), 3.0, Color("#e2cfa8"))


func _signature() -> void:
	match kind:
		"obs":   # brass telescope on a tripod
			var c := Vector2(1020.0, 872.0)
			draw_line(c, c + Vector2(-30.0, -90.0), Pal.BRASS, 4.0)
			draw_line(c, c + Vector2(30.0, -90.0), Pal.BRASS, 4.0)
			draw_line(c, c + Vector2(0.0, -96.0), Dr.shade(Pal.BRASS, 0.7), 4.0)
			draw_line(c + Vector2(-34.0, -92.0), c + Vector2(70.0, -150.0), Color("#c9a24a"), 12.0)
			draw_circle(c + Vector2(70.0, -150.0), 9.0, Color("#6a8a96"))
		"sleep":   # slippers by the bunks
			for sx in [372.0, 892.0, 1412.0]:
				_rr(Rect2(sx, 866.0, 26.0, 10.0), 4.0, Color("#8a3a4a"))
				_rr(Rect2(sx + 30.0, 866.0, 26.0, 10.0), 4.0, Color("#8a3a4a"))
		"lug":   # lantern glow bodies
			for k in range(3):
				var lx: float = 560.0 + 520.0 * float(k)
				draw_line(Vector2(lx, 130.0), Vector2(lx, 250.0), Color("#2a2018"), 2.0)
				_rr(Rect2(lx - 12.0, 250.0, 24.0, 34.0), 5.0, Color(1.0, 0.8, 0.4))
				draw_rect(Rect2(lx - 14.0, 246.0, 28.0, 6.0), Pal.BRASS)
