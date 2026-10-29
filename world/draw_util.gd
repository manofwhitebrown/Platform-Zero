class_name Dr
extends RefCounted
## Small drawing helpers. Call from inside a CanvasItem's _draw, passing `self`.

static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bot: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	ci.draw_polygon(pts, PackedColorArray([top, top, bot, bot]))


static func hgrad(ci: CanvasItem, r: Rect2, left: Color, right: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	ci.draw_polygon(pts, PackedColorArray([left, right, right, left]))


static func shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0), c.a)


## Rounded rect via polygon (corner radius r).
static func rrect(ci: CanvasItem, rc: Rect2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var corners: Array = [
		[Vector2(rc.end.x - rad, rc.position.y + rad), -PI / 2.0],
		[Vector2(rc.end.x - rad, rc.end.y - rad), 0.0],
		[Vector2(rc.position.x + rad, rc.end.y - rad), PI / 2.0],
		[Vector2(rc.position.x + rad, rc.position.y + rad), PI],
	]
	for c in corners:
		for i in range(7):
			var a: float = float(c[1]) + (PI / 2.0) * float(i) / 6.0
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	ci.draw_colored_polygon(pts, col)


## Wooden planks (vertical) in rect, deterministic by seed.
static func planks(ci: CanvasItem, rc: Rect2, base: Color, plank_w: float, seed_i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var x: float = rc.position.x
	while x < rc.end.x:
		var w: float = minf(plank_w, rc.end.x - x)
		var f: float = rng.randf_range(0.86, 1.1)
		var c: Color = shade(base, f)
		vgrad(ci, Rect2(x, rc.position.y, w, rc.size.y), shade(c, 1.08), shade(c, 0.9))
		ci.draw_line(Vector2(x, rc.position.y), Vector2(x, rc.end.y), Color(0, 0, 0, 0.35), 2.0)
		ci.draw_line(Vector2(x + 2.0, rc.position.y), Vector2(x + 2.0, rc.end.y), Color(1, 1, 1, 0.06), 1.0)
		# grain streaks
		for k in range(2):
			var gx: float = x + rng.randf_range(5.0, maxf(6.0, w - 5.0))
			var y0: float = rc.position.y + rng.randf_range(0.0, rc.size.y * 0.5)
			ci.draw_line(Vector2(gx, y0), Vector2(gx + rng.randf_range(-2.0, 2.0), y0 + rng.randf_range(30.0, rc.size.y * 0.5)), Color(0, 0, 0, 0.10), 1.0)
		x += plank_w
