class_name LPProps
extends Node2D
## Lost Property car furniture. Local origin = car rear. Positions match Sim's stub:
## bin spot ~x750, counter between attendant (~900) and claimant (~1200).

const FLOOR_Y: float = 820.0
var clock_node: Node2D
var lamp_node: Node2D
var _hands_t: float = -1.0


func _ready() -> void:
	var cp := DrawProxy.new()
	cp.fn = _draw_clock
	cp.position = Vector2(870, 300)
	add_child(cp)
	clock_node = cp
	var lp := DrawProxy.new()
	lp.fn = _draw_hanging_lamp
	lp.position = Vector2(990, 120)
	add_child(lp)
	lamp_node = lp


func _process(_d: float) -> void:
	var t: float = floorf(Time.get_unix_time_from_system())
	if t != _hands_t:
		_hands_t = t
		clock_node.queue_redraw()


func sway(angle: float) -> void:
	if lamp_node:
		lamp_node.rotation = angle


func _draw() -> void:
	_pegboard(Rect2(318, 500, 340, 190))
	_shelf_unit(Rect2(1290, 220, 340, 600))
	_bench(Rect2(300, 740, 370, 80))
	_bin(Vector2(750, FLOOR_Y + 36))
	_counter(Rect2(820, 740, 320, 120))
	_notice_board(Rect2(1180, 520, 90, 120))


func _brass_line(a: Vector2, b: Vector2, w: float = 3.0) -> void:
	draw_line(a, b, Pal.BRASS, w)
	draw_line(a + Vector2(0, -1), b + Vector2(0, -1), Color(1, 0.92, 0.65, 0.5), 1.0)


func _pegboard(rc: Rect2) -> void:
	Dr.vgrad(self, rc, Color("#4b3220"), Color("#3a2517"))
	draw_rect(rc, Pal.BRASS, false, 4.0)
	for x in range(int(rc.position.x) + 16, int(rc.end.x) - 8, 24):
		for y in range(int(rc.position.y) + 16, int(rc.end.y) - 8, 24):
			draw_circle(Vector2(x, y), 2.0, Color(0, 0, 0, 0.35))
	# hanging keys + tags
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(7):
		var x: float = rc.position.x + 34 + i * 44
		var y: float = rc.position.y + 28
		draw_line(Vector2(x, y), Vector2(x, y + 28), Color("#2a1d12"), 1.5)
		draw_circle(Vector2(x, y + 36), 8.0, Pal.BRASS)
		draw_circle(Vector2(x, y + 36), 3.5, Color("#3a2517"))
		draw_rect(Rect2(x - 3, y + 44, 6, 22), Dr.shade(Pal.BRASS, 0.85))
		if i % 2 == 0:
			var tag := Rect2(x - 12, y + 70, 24, 30)
			draw_rect(tag, Pal.PARCHMENT)
			draw_rect(tag, Color(0, 0, 0, 0.35), false, 1.5)
			draw_line(Vector2(x - 6, y + 80), Vector2(x + 6, y + 80), Color(0, 0, 0, 0.35), 1.5)
			draw_line(Vector2(x - 6, y + 88), Vector2(x + 4, y + 88), Color(0, 0, 0, 0.35), 1.5)
	# toolbar rack silhouettes
	draw_line(Vector2(rc.position.x + 20, rc.end.y - 28), Vector2(rc.end.x - 20, rc.end.y - 28), Color("#2a1d12"), 4.0)


func _bench(rc: Rect2) -> void:
	# legs + lower shelf
	for lx in [rc.position.x + 14, rc.end.x - 34]:
		Dr.vgrad(self, Rect2(lx, rc.position.y + 26, 20, FLOOR_Y - rc.position.y - 22), Color("#5b3b22"), Color("#3a2414"))
	draw_rect(Rect2(rc.position.x + 20, rc.position.y + 98, rc.size.x - 40, 14), Color("#4b3019"))
	# drawers
	Dr.vgrad(self, Rect2(rc.position.x + 40, rc.position.y + 26, rc.size.x - 80, 60), Color("#6f4728"), Color("#563519"))
	for i in range(2):
		var dr := Rect2(rc.position.x + 52 + i * 140, rc.position.y + 34, 130, 44)
		draw_rect(dr, Color(0, 0, 0, 0.25), false, 2.0)
		draw_circle(dr.get_center(), 6.0, Pal.BRASS)
	# top slab
	Dr.vgrad(self, Rect2(rc.position.x - 8, rc.position.y, rc.size.x + 16, 26), Color("#8b5a30"), Color("#5f3c1f"))
	draw_rect(Rect2(rc.position.x - 8, rc.position.y, rc.size.x + 16, 3), Color(1, 1, 1, 0.22))
	# leather mat
	Dr.rrect(self, Rect2(rc.position.x + 60, rc.position.y - 6, 190, 10), 4.0, Color("#244b3a"))
	# tool tray with 5 tools
	var tray := Rect2(rc.position.x + 100, rc.position.y - 34, 160, 30)
	Dr.rrect(self, tray, 6.0, Color("#3a2517"))
	draw_rect(tray, Pal.BRASS, false, 2.0)
	_tool_magnifier(tray.position + Vector2(24, 14))
	_tool_lamp(tray.position + Vector2(56, 14))
	_tool_ear(tray.position + Vector2(88, 14))
	_tool_nose(tray.position + Vector2(118, 14))
	_tool_brush(tray.position + Vector2(146, 14))
	# desk lamp (left)
	var lp: Vector2 = Vector2(rc.position.x + 40, rc.position.y)
	draw_line(lp, lp + Vector2(0, -50), Pal.BRASS, 5.0)
	draw_line(lp + Vector2(0, -50), lp + Vector2(36, -96), Pal.BRASS, 5.0)
	draw_colored_polygon(PackedVector2Array([lp + Vector2(18, -112), lp + Vector2(66, -92), lp + Vector2(50, -76), lp + Vector2(10, -96)]), Color("#2f6a55"))
	draw_circle(lp + Vector2(40, -80), 7.0, Color(1, 0.88, 0.5))
	draw_rect(Rect2(lp.x - 14, lp.y - 6, 28, 8), Dr.shade(Pal.BRASS, 0.8))
	# jar of pencils + parcel
	draw_rect(Rect2(rc.end.x - 70, rc.position.y - 36, 22, 36), Color(0.6, 0.8, 0.8, 0.5))
	for i in range(3):
		draw_line(Vector2(rc.end.x - 66 + i * 7, rc.position.y - 36), Vector2(rc.end.x - 68 + i * 8, rc.position.y - 54), [Pal.SIGNAL, Pal.LAMP, Pal.PARCHMENT][i], 3.0)
	draw_rect(Rect2(rc.end.x - 42, rc.position.y - 26, 36, 26), Color("#a07a4c"))
	draw_line(Vector2(rc.end.x - 24, rc.position.y - 26), Vector2(rc.end.x - 24, rc.position.y), Color("#6b4a28"), 2.0)
	draw_line(Vector2(rc.end.x - 42, rc.position.y - 13), Vector2(rc.end.x - 6, rc.position.y - 13), Color("#6b4a28"), 2.0)


func _tool_magnifier(p: Vector2) -> void:
	draw_arc(p + Vector2(-2, -3), 8.0, 0, TAU, 20, Pal.BRASS, 3.0)
	draw_circle(p + Vector2(-2, -3), 6.0, Color(0.7, 0.9, 1.0, 0.35))
	draw_line(p + Vector2(4, 3), p + Vector2(11, 10), Color("#3a2517"), 4.0)


func _tool_lamp(p: Vector2) -> void:
	Dr.rrect(self, Rect2(p.x - 7, p.y - 6, 14, 14), 3.0, Pal.BRASS)
	draw_circle(p + Vector2(0, 1), 4.0, Color(1, 0.88, 0.5))


func _tool_ear(p: Vector2) -> void:
	draw_arc(p + Vector2(0, -2), 9.0, PI, TAU, 14, Color("#7a8a90"), 2.5)
	draw_circle(p + Vector2(0, 8), 5.0, Pal.BRASS)


func _tool_nose(p: Vector2) -> void:
	Dr.rrect(self, Rect2(p.x - 6, p.y - 4, 12, 13), 4.0, Color(0.75, 0.55, 0.85, 0.9))
	draw_rect(Rect2(p.x - 3, p.y - 9, 6, 6), Color("#3a2517"))


func _tool_brush(p: Vector2) -> void:
	draw_rect(Rect2(p.x - 3, p.y - 10, 6, 14), Color("#8b5a30"))
	draw_rect(Rect2(p.x - 6, p.y + 3, 12, 8), Color("#e0cfa0"))


func _bin(base: Vector2) -> void:
	# wicker basket centred on base.x, bottom at base.y
	var pts := PackedVector2Array([base + Vector2(-46, -92), base + Vector2(46, -92), base + Vector2(36, 0), base + Vector2(-36, 0)])
	draw_colored_polygon(pts, Color("#9a6f3c"))
	for i in range(6):
		var y: float = base.y - 92 + i * 15
		draw_line(Vector2(base.x - 46 + i * 1.6, y), Vector2(base.x + 46 - i * 1.6, y), Color(0.3, 0.18, 0.06, 0.55), 2.0)
	for i in range(-3, 4):
		draw_line(Vector2(base.x + i * 14, base.y - 92), Vector2(base.x + i * 11, base.y), Color(1, 0.85, 0.5, 0.15), 2.0)
	draw_rect(Rect2(base.x - 50, base.y - 98, 100, 8), Color("#b98a50"))
	# peeking lost things (scarf + umbrella tip)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-30, -98), base + Vector2(-8, -128), base + Vector2(14, -98)]), Pal.SIGNAL)
	draw_line(base + Vector2(26, -98), base + Vector2(40, -150), Color("#223a4a"), 5.0)
	var sign_r := Rect2(base.x - 34, base.y - 74, 68, 32)
	draw_rect(sign_r, Pal.PARCHMENT)
	draw_rect(sign_r, Color(0, 0, 0, 0.4), false, 1.5)
	draw_line(sign_r.position + Vector2(8, 12), sign_r.end - Vector2(8, 20), Color(0, 0, 0, 0.35), 2.0)
	draw_line(sign_r.position + Vector2(8, 22), sign_r.end - Vector2(18, 10), Color(0, 0, 0, 0.35), 2.0)


func _counter(rc: Rect2) -> void:
	# body
	var body := Rect2(rc.position.x, rc.position.y + 22, rc.size.x, FLOOR_Y + 40 - rc.position.y - 22)
	Dr.planks(self, body, Color("#6a4326"), 40.0, 11)
	for i in range(3):
		var pr := Rect2(body.position.x + 14 + i * 100, body.position.y + 18, 90, body.size.y - 40)
		draw_rect(pr, Color(0, 0, 0, 0.22), false, 3.0)
		draw_rect(Rect2(pr.position + Vector2(3, 3), pr.size - Vector2(6, 6)), Color(1, 1, 1, 0.06), false, 1.5)
	_brass_line(Vector2(rc.position.x + 4, body.end.y - 14), Vector2(rc.end.x - 4, body.end.y - 14), 6.0)
	# top slab
	Dr.vgrad(self, Rect2(rc.position.x - 14, rc.position.y, rc.size.x + 28, 24), Color("#9a6636"), Color("#6a4326"))
	draw_rect(Rect2(rc.position.x - 14, rc.position.y, rc.size.x + 28, 3), Color(1, 0.9, 0.7, 0.28))
	_brass_line(Vector2(rc.position.x - 14, rc.position.y + 24), Vector2(rc.end.x + 14, rc.position.y + 24), 4.0)
	# service bell
	var bp: Vector2 = Vector2(rc.end.x - 50, rc.position.y)
	draw_arc(bp, 20.0, PI, TAU, 16, Pal.BRASS, 6.0)
	draw_colored_polygon(_half_disc(bp, 20.0), Pal.BRASS)
	draw_rect(Rect2(bp.x - 24, bp.y - 4, 48, 5), Dr.shade(Pal.BRASS, 0.8))
	draw_circle(bp + Vector2(0, -22), 4.0, Pal.BRASS)
	# open ledger
	var lg := Rect2(rc.position.x + 24, rc.position.y - 14, 84, 14)
	draw_colored_polygon(PackedVector2Array([lg.position + Vector2(0, 0), lg.position + Vector2(42, -6), lg.position + Vector2(84, 0), lg.position + Vector2(84, 14), lg.position + Vector2(0, 14)]), Pal.PARCHMENT)
	draw_line(lg.position + Vector2(42, -6), lg.position + Vector2(42, 14), Color(0, 0, 0, 0.35), 2.0)
	for i in range(3):
		draw_line(lg.position + Vector2(8, 3 + i * 3), lg.position + Vector2(36, 3 + i * 3), Color(0, 0, 0, 0.18), 1.0)
		draw_line(lg.position + Vector2(48, 3 + i * 3), lg.position + Vector2(76, 3 + i * 3), Color(0, 0, 0, 0.18), 1.0)
	# stamp
	Dr.rrect(self, Rect2(rc.position.x + 130, rc.position.y - 16, 26, 16), 4.0, Pal.SIGNAL)
	draw_rect(Rect2(rc.position.x + 138, rc.position.y - 30, 10, 14), Color("#3a2517"))


func _half_disc(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(17):
		var a: float = PI + PI * float(i) / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _shelf_unit(rc: Rect2) -> void:
	Dr.vgrad(self, rc, Color("#3a2517"), Color("#26170e"))
	draw_rect(rc, Pal.BRASS, false, 5.0)
	var rows: int = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var cols: Array = [Pal.SIGNAL, Color("#c9a96a"), Color("#3e6a8a"), Color("#6f8a52"), Color("#8a5a8a"), Pal.LAMP]
	for r in range(rows):
		var y: float = rc.position.y + 40 + r * 140 + 100
		draw_rect(Rect2(rc.position.x, y, rc.size.x, 12), Color("#6b4527"))
		draw_rect(Rect2(rc.position.x, y, rc.size.x, 2), Color(1, 1, 1, 0.2))
		var x: float = rc.position.x + 14
		while x < rc.end.x - 40:
			var w: float = rng.randf_range(34, 62)
			var h: float = rng.randf_range(34, 88)
			var c: Color = cols[rng.randi() % cols.size()]
			var kindr: int = rng.randi() % 3
			if kindr == 0:
				draw_rect(Rect2(x, y - h, w, h), c)
				draw_rect(Rect2(x, y - h, w, h), Color(0, 0, 0, 0.3), false, 2.0)
				draw_line(Vector2(x + w * 0.5, y - h), Vector2(x + w * 0.5, y), Color(0, 0, 0, 0.3), 2.0)
				draw_rect(Rect2(x + 4, y - h * 0.6, 14, 18), Pal.PARCHMENT)
			elif kindr == 1:
				draw_arc(Vector2(x + w * 0.5, y - 14), w * 0.5, PI, TAU, 14, c, 10.0)
				draw_rect(Rect2(x - 2, y - 16, w + 4, 6), Dr.shade(c, 0.7))
			else:
				draw_rect(Rect2(x, y - h * 0.7, w, h * 0.7), Dr.shade(c, 0.9))
				draw_circle(Vector2(x + w * 0.5, y - h * 0.7), w * 0.4, c)
			x += w + 10
	# shelf-end label
	var lab := Rect2(rc.position.x + 100, rc.position.y - 26, 140, 26)
	Dr.rrect(self, lab, 4.0, Pal.PARCHMENT)
	draw_rect(lab, Pal.BRASS, false, 2.0)
	draw_line(lab.position + Vector2(14, 10), lab.end - Vector2(14, 14), Color(0, 0, 0, 0.35), 3.0)
	draw_line(lab.position + Vector2(14, 18), lab.end - Vector2(40, 8), Color(0, 0, 0, 0.35), 3.0)


func _notice_board(rc: Rect2) -> void:
	Dr.vgrad(self, rc, Color("#7a5a36"), Color("#5a3f22"))
	draw_rect(rc, Pal.BRASS, false, 4.0)
	for i in range(3):
		var p := Rect2(rc.position.x + 10 + (i % 2) * 36, rc.position.y + 12 + i * 34, 30, 26)
		draw_rect(p, Pal.PARCHMENT)
		draw_circle(p.position + Vector2(15, 3), 3.0, Pal.SIGNAL)


func _draw_clock(ci: CanvasItem) -> void:
	var r: float = 50.0
	ci.draw_circle(Vector2.ZERO, r + 8, Pal.BRASS)
	ci.draw_circle(Vector2.ZERO, r + 8, Color(1, 0.92, 0.65, 0.25))
	ci.draw_circle(Vector2.ZERO, r, Pal.PARCHMENT)
	ci.draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(0, 0, 0, 0.35), 2.0)
	for i in range(12):
		var a: float = float(i) * TAU / 12.0 - PI / 2.0
		ci.draw_line(Vector2(cos(a), sin(a)) * (r - 10), Vector2(cos(a), sin(a)) * (r - 3), Color("#2a2018"), 3.0 if i % 3 == 0 else 1.5)
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var h: float = float(int(dt["hour"]) % 12) + float(dt["minute"]) / 60.0
	var m: float = float(dt["minute"]) + float(dt["second"]) / 60.0
	var ha: float = h / 12.0 * TAU - PI / 2.0
	var ma: float = m / 60.0 * TAU - PI / 2.0
	ci.draw_line(Vector2.ZERO, Vector2(cos(ha), sin(ha)) * (r * 0.5), Color("#2a2018"), 5.0)
	ci.draw_line(Vector2.ZERO, Vector2(cos(ma), sin(ma)) * (r * 0.78), Color("#2a2018"), 3.0)
	ci.draw_circle(Vector2.ZERO, 4.0, Pal.SIGNAL)


func _draw_hanging_lamp(ci: CanvasItem) -> void:
	# origin = ceiling mount; chain down to a glass-shaded brass lamp
	ci.draw_line(Vector2.ZERO, Vector2(0, 110), Pal.BRASS, 4.0)
	ci.draw_circle(Vector2.ZERO, 8.0, Pal.BRASS)
	var top := Vector2(0, 110)
	ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-16, 0), top + Vector2(16, 0), top + Vector2(46, 56), top + Vector2(-46, 56)]), Color("#2f6a55"))
	ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-8, 6), top + Vector2(8, 6), top + Vector2(24, 50), top + Vector2(-24, 50)]), Color(1, 0.9, 0.55, 0.55))
	ci.draw_rect(Rect2(top.x - 48, top.y + 54, 96, 6), Pal.BRASS)
	ci.draw_circle(top + Vector2(0, 66), 15.0, Color(1, 0.92, 0.6))
	ci.draw_circle(top + Vector2(0, 66), 26.0, Color(1, 0.85, 0.4, 0.25))
