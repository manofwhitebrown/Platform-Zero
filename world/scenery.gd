class_name Scenery
extends Node2D
## Outside world drawn on a CanvasLayer behind the train (screen space).
## The car shells leave holes where the windows are, so this shows through.
## State is pushed in by TrainWorld every frame.

const HORIZON_Y: float = 430.0   # world y of the horizon line as seen in the windows

const BIOMES: Dictionary = {
	"plains": {"hill1": Color("#1a3a48"), "hill2": Color("#122c38"), "ground": Color("#0f2630"), "feature": "poles", "snow": false},
	"snow":   {"hill1": Color("#c7d8e6"), "hill2": Color("#a9bfd2"), "ground": Color("#dbe6ef"), "feature": "pines", "snow": true},
	"sea":    {"hill1": Color("#264a5e"), "hill2": Color("#1b3a4c"), "ground": Color("#14303f"), "feature": "waves", "snow": false},
	"city":   {"hill1": Color("#1b2a3c"), "hill2": Color("#121e2c"), "ground": Color("#0d1722"), "feature": "buildings", "snow": false},
	"desert": {"hill1": Color("#6a3a3a"), "hill2": Color("#4a2a2e"), "ground": Color("#3a2224"), "feature": "cacti", "snow": false},
	"tunnel": {"hill1": Color("#0a0f12"), "hill2": Color("#06090b"), "ground": Color("#05080a"), "feature": "none", "snow": false},
	"forest": {"hill1": Color("#18382f"), "hill2": Color("#102a24"), "ground": Color("#0c211c"), "feature": "pines", "snow": false},
}

var cam_pos: Vector2 = Vector2(0, 500)
var zoom: float = 1.0
var vis: Vector2 = Vector2(1080, 1920)
var scroll: float = 0.0
var tod: float = 0.8
var biome: String = "plains"
var weather: String = "clear"
var time_s: float = 0.0
var _stars: Array = []
var plat_off: float = 99999.0   # platform slide offset in world px (0 = alongside the train)
var plat_steam: float = 0.0     # departure steam puff 0..1
var station_name: String = ""
var stop_seed: int = 0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(140):
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.5, 2.2)))


func push_state(p_cam: Vector2, p_zoom: float, p_vis: Vector2, p_scroll: float, p_tod: float, p_biome: String, p_weather: String, p_time: float) -> void:
	cam_pos = p_cam
	zoom = p_zoom
	vis = p_vis
	scroll = p_scroll
	tod = p_tod
	biome = p_biome
	weather = p_weather
	time_s = p_time
	queue_redraw()


func set_station(p_off: float, p_steam: float, p_name: String, p_seed: int) -> void:
	plat_off = p_off
	plat_steam = p_steam
	station_name = p_name
	stop_seed = p_seed


func _sx(wx: float) -> float:
	return (wx + plat_off - cam_pos.x) * zoom + vis.x * 0.5


func _sy(wy: float) -> float:
	return (wy - cam_pos.y) * zoom + vis.y * 0.5


func _night_amount() -> float:
	# 0 = day, 1 = deep night. tod: 0 midnight, .25 dawn, .5 noon, .75 dusk
	var d: float = absf(tod - 0.5) * 2.0   # 1 at midnight, 0 at noon
	return clampf((d - 0.35) / 0.4, 0.0, 1.0)


func _sky_colors() -> Array:
	var keys: Array = [
		[0.0, Color("#060d1c"), Color("#12303b")],
		[0.22, Color("#1d3256"), Color("#e8946a")],
		[0.5, Color("#5a9ccf"), Color("#cfe6f0")],
		[0.78, Color("#1a2650"), Color("#e0845a")],
		[0.9, Color("#0a1226"), Color("#2a3d58")],
		[1.0, Color("#060d1c"), Color("#12303b")],
	]
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if tod >= float(a[0]) and tod <= float(b[0]):
			var t: float = (tod - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			return [(a[1] as Color).lerp(b[1], t), (a[2] as Color).lerp(b[2], t)]
	return [keys[0][1], keys[0][2]]


func _draw() -> void:
	var b: Dictionary = BIOMES.get(biome, BIOMES["plains"])
	var sky: Array = _sky_colors()
	var top_c: Color = sky[0]
	var hor_c: Color = sky[1]
	var hy: float = _sy(HORIZON_Y)
	# sky: tall gradient above horizon (top offscreen -> top color)
	var sky_top: float = minf(0.0, hy - 1150.0 * zoom)
	_vstrip(Rect2(0, sky_top, vis.x, hy - sky_top), top_c, hor_c, 40)
	var night: float = _night_amount()
	# stars + moon
	if night > 0.02:
		for s in _stars:
			var v: Vector3 = s
			var sx: float = fposmod(v.x * vis.x - cam_pos.x * 0.02 * zoom - scroll * 0.002, vis.x)
			var sy: float = v.y * (hy - 40.0)
			var tw: float = 0.55 + 0.45 * sin(time_s * (1.0 + v.z) + v.x * 40.0)
			draw_circle(Vector2(sx, sy), v.z * zoom, Color(1, 0.97, 0.88, night * tw * 0.9))
		var mp := Vector2(fposmod(vis.x * 0.78 - cam_pos.x * 0.01 * zoom, vis.x + 200.0) - 100.0, hy - 520.0 * zoom)
		draw_circle(mp, 120.0 * zoom, Color(0.95, 0.9, 0.7, 0.07 * night))
		draw_circle(mp, 70.0 * zoom, Color(0.95, 0.9, 0.7, 0.12 * night))
		draw_circle(mp, 38.0 * zoom, Color("#f3ead0"))
		draw_circle(mp + Vector2(12, -6) * zoom, 32.0 * zoom, Color(top_c.r, top_c.g, top_c.b, 0.35 * night))
	elif tod > 0.35 and tod < 0.65:
		var sp := Vector2(vis.x * 0.3, hy - 480.0 * zoom)
		draw_circle(sp, 90.0 * zoom, Color(1, 0.95, 0.7, 0.18))
		draw_circle(sp, 44.0 * zoom, Color("#fff4c8"))

	# far hills -> mid hills
	var hill1: Color = (b["hill1"] as Color).lerp(top_c, 0.25 * (1.0 - night)).lerp(Color(0.05, 0.1, 0.16), 0.1)
	var hill2: Color = b["hill2"]
	if bool(b["snow"]):
		hill1 = hill1.lerp(Color("#27384e"), night * 0.75)
		hill2 = hill2.lerp(Color("#1f2f44"), night * 0.75)
	_hills(0.05, 0.02, 90.0, 55.0, hill1, 1.0)
	_hills(0.14, 0.06, 70.0, 35.0, hill2, 2.0)
	if biome == "snow":
		_peaks(night)
	_features(String(b["feature"]), b, night)
	if biome == "desert":   # permanent dusk glow low on the horizon
		_vstrip(Rect2(0, hy - 260.0 * zoom, vis.x, 300.0 * zoom), Color(0.95, 0.5, 0.3, 0.0), Color(0.95, 0.5, 0.3, 0.32), 14)
	# near ground strip visible at the bottom of the windows, then the track bed below the car
	var ground: Color = (b["ground"] as Color)
	if bool(b["snow"]):
		ground = ground.lerp(Color("#2d3f55"), night * 0.8)
	var gy0: float = _sy(HORIZON_Y + 30.0)
	_vstrip(Rect2(0, gy0, vis.x, vis.y - gy0), ground, Dr.shade(ground, 0.55), 6)
	if absf(plat_off) < 5200.0:
		_platform(night)
	# ballast + sleepers + foreground racing past under the car
	var by: float = _sy(1086.0)
	var gravel: Color = Color("#141d22").lerp(Color("#3a4a58"), 0.0 if not bool(b["snow"]) else 0.7 * (1.0 - night * 0.6))
	_vstrip(Rect2(0, by, vis.x, vis.y - by), gravel, Dr.shade(gravel, 0.45), 8)
	var sp_step: float = 120.0
	var off: float = fposmod(scroll * 3.2 + cam_pos.x * 1.0, sp_step)
	var x: float = -off * zoom
	while x < vis.x + 150.0:
		draw_rect(Rect2(x, by + 14.0 * zoom, 70.0 * zoom, 26.0 * zoom), Color("#2a2119"))
		x += sp_step * zoom
	draw_rect(Rect2(0, by - 4.0 * zoom, vis.x, 6.0 * zoom), Color("#46535b"))
	# fast foreground: fence posts + bushes + far lamp posts at the bottom
	var fy: float = by + 150.0 * zoom
	var lxf: float = scroll * 4.5 + cam_pos.x * 1.2
	var tile: float = 260.0
	var first: int = int(floor((lxf - vis.x * 0.5 / zoom) / tile)) - 1
	var cnt: int = int(vis.x / (tile * zoom)) + 4
	for i in range(first, first + cnt):
		var sx: float = (float(i) * tile - lxf) * zoom + vis.x * 0.5
		var hh: float = _hash(float(i) * 3.1)
		if hh > 0.45:
			draw_circle(Vector2(sx, fy + 40.0 * zoom), (50.0 + hh * 40.0) * zoom, Color(0.04, 0.09, 0.1, 1.0).lerp(Color("#cfdde8") if bool(b["snow"]) else Color(0.04, 0.09, 0.1), 0.0 if not bool(b["snow"]) else 0.35 * (1.0 - night)))
		else:
			draw_rect(Rect2(sx, fy - 80.0 * zoom, 14.0 * zoom, 200.0 * zoom), Color("#0a1216"))
			draw_circle(Vector2(sx + 7.0 * zoom, fy - 80.0 * zoom), 9.0 * zoom, Color(1.0, 0.8, 0.45, 0.35 + 0.6 * night))
	_vstrip(Rect2(0, fy + 90.0 * zoom, vis.x, maxf(0.0, vis.y - fy - 90.0 * zoom)), Color(0.03, 0.06, 0.08, 1), Color(0.01, 0.02, 0.03, 1), 6)
	if biome == "tunnel":
		_tunnel()
	_weather(b, night)


func _peaks(night: float) -> void:
	var hy: float = _sy(HORIZON_Y + 10.0)
	var lx: float = _layer_x(0.08, 0.03)
	var tile: float = 420.0
	var first: int = int(floor((lx - vis.x * 0.5 / zoom) / tile)) - 1
	var cnt: int = int(vis.x / (tile * zoom)) + 4
	var rock: Color = Color("#7a8fa6").lerp(Color("#27384e"), night * 0.8)
	var capc: Color = Color("#f2f7fb").lerp(Color("#8fa4bd"), night * 0.7)
	for i in range(first, first + cnt):
		var sx: float = (float(i) * tile + _hash(float(i) * 2.3) * 160.0 - lx) * zoom + vis.x * 0.5
		var h: float = (220.0 + _hash(float(i) + 5.0) * 200.0) * zoom
		var w: float = (190.0 + _hash(float(i) + 8.0) * 80.0) * zoom
		Dr.poly(self, PackedVector2Array([Vector2(sx - w, hy), Vector2(sx, hy - h), Vector2(sx + w, hy)]), rock)
		Dr.poly(self, PackedVector2Array([Vector2(sx - w * 0.28, hy - h * 0.72), Vector2(sx, hy - h), Vector2(sx + w * 0.28, hy - h * 0.72), Vector2(sx + w * 0.1, hy - h * 0.6), Vector2(sx - w * 0.08, hy - h * 0.68)]), capc)


func _platform(night: float) -> void:
	var x0: float = _sx(2500.0)
	var x1: float = _sx(6500.0)
	var top: float = _sy(440.0)
	var tint: Color = Color(1, 1, 1).lerp(Color(0.45, 0.5, 0.62), night * 0.7)
	# slab + front wall + yellow safety edge
	draw_rect(Rect2(x0, top, x1 - x0, 140.0 * zoom), Color("#6a7078") * tint)
	draw_rect(Rect2(x0, top + 30.0 * zoom, x1 - x0, 110.0 * zoom), Color("#3c4249") * tint)
	draw_rect(Rect2(x0, top, x1 - x0, 5.0 * zoom), Color("#e0b84e") * tint)
	for i in range(int((x1 - x0) / (90.0 * zoom)) + 1):
		draw_line(Vector2(x0 + i * 90.0 * zoom, top + 34.0 * zoom), Vector2(x0 + i * 90.0 * zoom, top + 138.0 * zoom), Color(0, 0, 0, 0.18), 2.0)
	# lamp posts with lanterns
	for i in range(7):
		var lx: float = _sx(2700.0 + float(i) * 560.0)
		draw_rect(Rect2(lx - 4.0 * zoom, _sy(250.0), 8.0 * zoom, 190.0 * zoom), Color("#10181c"))
		draw_rect(Rect2(lx - 14.0 * zoom, _sy(236.0), 28.0 * zoom, 26.0 * zoom), Color(1.0, 0.82, 0.45))
		draw_circle(Vector2(lx, _sy(249.0)), 70.0 * zoom, Color(1.0, 0.8, 0.45, 0.06 + 0.12 * night))
		draw_circle(Vector2(lx, _sy(249.0)), 30.0 * zoom, Color(1.0, 0.8, 0.45, 0.12 + 0.2 * night))
	# station name boards on two posts
	for bx in [3900.0, 5400.0]:
		var cx: float = _sx(bx)
		var bw: float = 330.0 * zoom
		draw_rect(Rect2(cx - bw * 0.42, _sy(330.0), 8.0 * zoom, 110.0 * zoom), Color("#10181c"))
		draw_rect(Rect2(cx + bw * 0.42 - 8.0 * zoom, _sy(330.0), 8.0 * zoom, 110.0 * zoom), Color("#10181c"))
		var br := Rect2(cx - bw * 0.5, _sy(250.0), bw, 84.0 * zoom)
		draw_rect(br, Color("#12303b"))
		draw_rect(br, Pal.BRASS, false, 4.0 * zoom)
		draw_rect(Rect2(br.position.x + 8.0 * zoom, br.position.y + 8.0 * zoom, br.size.x - 16.0 * zoom, br.size.y - 16.0 * zoom), Color(Pal.PARCHMENT.r, Pal.PARCHMENT.g, Pal.PARCHMENT.b, 0.25), false, 2.0 * zoom)
		draw_string(ThemeDB.fallback_font, Vector2(br.position.x, br.position.y + br.size.y * 0.62), station_name, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, int(34.0 * zoom), Pal.PARCHMENT)
	# waiting figures + luggage
	var sd: int = stop_seed
	for i in range(9):
		var h1: float = _hash(float(sd * 13 + i) * 1.3)
		var h2: float = _hash(float(sd * 7 + i) * 2.9)
		var fx: float = _sx(2800.0 + float(i) * 400.0 + h1 * 160.0)
		var fh: float = (62.0 + h2 * 22.0) * zoom
		var col: Color = Color.from_hsv(h1, 0.25, 0.28 + 0.2 * h2) * tint
		var fy: float = top + 4.0 * zoom
		Dr.rrect(self, Rect2(fx - 14.0 * zoom, fy - fh, 28.0 * zoom, fh), 9.0 * zoom, col)
		draw_circle(Vector2(fx, fy - fh - 10.0 * zoom), 12.0 * zoom, Color("#c9a487") * tint)
		if h2 > 0.4:
			draw_rect(Rect2(fx - 16.0 * zoom, fy - fh - 26.0 * zoom, 32.0 * zoom, 8.0 * zoom), col)
			draw_rect(Rect2(fx - 10.0 * zoom, fy - fh - 40.0 * zoom, 20.0 * zoom, 16.0 * zoom), col)
		if h1 > 0.5:
			draw_rect(Rect2(fx + 16.0 * zoom, fy - 24.0 * zoom, 22.0 * zoom, 22.0 * zoom), Color("#5a3a22") * tint)
	# steam drifting along the platform (puff on departure)
	for k in range(6):
		var ph: float = fmod(time_s * 0.18 + float(k) * 0.17, 1.0)
		var sx: float = _sx(5200.0 + float(k) * 260.0) + ph * 60.0 * zoom
		var sy: float = top - ph * 150.0 * zoom
		draw_circle(Vector2(sx, sy), (30.0 + ph * 60.0) * zoom, Color(0.85, 0.9, 0.95, (0.09 + 0.3 * plat_steam) * (1.0 - ph)))


func _tunnel() -> void:
	var by: float = _sy(1086.0)
	draw_rect(Rect2(0, 0, vis.x, by), Color("#04070a"))
	# brick arches + passing wall lamps (parallax-fast)
	var lx: float = scroll * 4.0 + cam_pos.x * 1.0
	var tile: float = 360.0
	var first: int = int(floor((lx - vis.x * 0.5 / zoom) / tile)) - 1
	var cnt: int = int(vis.x / (tile * zoom)) + 4
	for i in range(first, first + cnt):
		var sx: float = (float(i) * tile - lx) * zoom + vis.x * 0.5
		draw_rect(Rect2(sx, 0, 26.0 * zoom, by), Color("#0b1217"))
		var ly: float = _sy(300.0)
		draw_circle(Vector2(sx + 13.0 * zoom, ly), 90.0 * zoom, Color(1.0, 0.75, 0.4, 0.07))
		draw_circle(Vector2(sx + 13.0 * zoom, ly), 40.0 * zoom, Color(1.0, 0.75, 0.4, 0.14))
		draw_circle(Vector2(sx + 13.0 * zoom, ly), 10.0 * zoom, Color(1.0, 0.9, 0.6, 0.95))
	for k in range(5):
		var yy: float = _sy(160.0 + float(k) * 90.0)
		draw_rect(Rect2(0, yy, vis.x, 2.0), Color(1, 1, 1, 0.025))


func _vstrip(rc: Rect2, c0: Color, c1: Color, steps: int) -> void:
	for i in range(steps):
		var t0: float = float(i) / float(steps)
		var t1: float = float(i + 1) / float(steps)
		var y0: float = rc.position.y + rc.size.y * t0
		var y1: float = rc.position.y + rc.size.y * t1
		draw_rect(Rect2(rc.position.x, y0, rc.size.x, y1 - y0 + 1.0), c0.lerp(c1, (t0 + t1) * 0.5))


func _layer_x(f_cam: float, f_scroll: float) -> float:
	return cam_pos.x * f_cam + scroll * f_scroll


func _hills(f_cam: float, f_scroll: float, amp: float, base_lift: float, col: Color, seed_f: float) -> void:
	var step: float = 28.0
	var pts := PackedVector2Array()
	var lx: float = _layer_x(f_cam, f_scroll)
	var n: int = int(vis.x / step) + 3
	var hy: float = _sy(HORIZON_Y)
	for i in range(-1, n):
		var sx: float = float(i) * step
		var wx: float = (sx - vis.x * 0.5) / zoom + lx
		var h: float = sin(wx * 0.0021 * seed_f + seed_f) * 0.55 + sin(wx * 0.0057 + seed_f * 3.0) * 0.3 + sin(wx * 0.013 + seed_f) * 0.15
		pts.append(Vector2(sx, hy - (base_lift + h * amp + amp * 0.6) * zoom))
	pts.append(Vector2(float(n) * step, hy + 60.0 * zoom))
	pts.append(Vector2(-step, hy + 60.0 * zoom))
	Dr.poly(self, pts, col)


func _hash(n: float) -> float:
	return fposmod(sin(n * 12.9898) * 43758.5453, 1.0)


func _features(kind: String, b: Dictionary, night: float) -> void:
	var hy: float = _sy(HORIZON_Y + 24.0)
	var snow: bool = bool(b["snow"])
	match kind:
		"pines":
			var tile: float = 150.0
			var lx: float = _layer_x(0.45, 0.55)
			var first: int = int(floor((lx - vis.x * 0.5 / zoom) / tile)) - 1
			var cnt: int = int(vis.x / (tile * zoom)) + 4
			for i in range(first, first + cnt):
				var wx: float = float(i) * tile + _hash(float(i)) * 90.0
				var sx: float = (wx - lx) * zoom + vis.x * 0.5
				var h: float = (90.0 + _hash(float(i) + 9.0) * 90.0) * zoom
				var col: Color = Color("#0e2620") if not snow else Color("#8fa8bd").lerp(Color("#1e2d41"), night * 0.8)
				Dr.poly(self, PackedVector2Array([Vector2(sx - 32 * zoom, hy), Vector2(sx, hy - h), Vector2(sx + 32 * zoom, hy)]), col)
				Dr.poly(self, PackedVector2Array([Vector2(sx - 26 * zoom, hy - h * 0.35), Vector2(sx, hy - h * 1.15), Vector2(sx + 26 * zoom, hy - h * 0.35)]), col)
		"poles":
			var tile2: float = 520.0
			var lx2: float = _layer_x(0.8, 1.0)
			var first2: int = int(floor((lx2 - vis.x * 0.5 / zoom) / tile2)) - 1
			var cnt2: int = int(vis.x / (tile2 * zoom)) + 3
			var prev: Vector2 = Vector2.ZERO
			for i in range(first2, first2 + cnt2):
				var sx2: float = (float(i) * tile2 - lx2) * zoom + vis.x * 0.5
				var top: Vector2 = Vector2(sx2, hy - 210.0 * zoom)
				draw_line(Vector2(sx2, hy + 6.0 * zoom), top, Color("#0a1419"), 7.0 * zoom)
				draw_line(top + Vector2(-34, 22) * zoom, top + Vector2(34, 22) * zoom, Color("#0a1419"), 6.0 * zoom)
				if i > first2:
					for w in range(2):
						var a: Vector2 = prev + Vector2(-30 + w * 60, 22) * zoom
						var c: Vector2 = top + Vector2(-30 + w * 60, 22) * zoom
						var m: Vector2 = (a + c) * 0.5 + Vector2(0, 26.0 * zoom)
						draw_polyline(PackedVector2Array([a, a.lerp(m, 0.5) + Vector2(0, 8 * zoom), m, c.lerp(m, 0.5) + Vector2(0, 8 * zoom), c]), Color("#0a1419"), 2.0)
				prev = top
			# a couple of far farmhouse lights
			var lx3: float = _layer_x(0.3, 0.2)
			for k in range(6):
				var wx3: float = float(k) * 900.0 + 300.0
				var sx3: float = fposmod((wx3 - lx3) * zoom, vis.x + 400.0) - 200.0
				draw_circle(Vector2(sx3, hy - 30.0 * zoom), 4.0 * zoom, Color(1.0, 0.8, 0.45, 0.4 + 0.5 * night))
		"buildings":
			var tile3: float = 130.0
			var lx4: float = _layer_x(0.5, 0.6)
			var first3: int = int(floor((lx4 - vis.x * 0.5 / zoom) / tile3)) - 1
			var cnt3: int = int(vis.x / (tile3 * zoom)) + 4
			for i in range(first3, first3 + cnt3):
				var bx: float = (float(i) * tile3 - lx4) * zoom + vis.x * 0.5
				var bh: float = (120.0 + _hash(float(i)) * 280.0) * zoom
				var bw: float = (80.0 + _hash(float(i) + 3.0) * 40.0) * zoom
				draw_rect(Rect2(bx, hy - bh, bw, bh), Color("#0c1520"))
				for wy in range(int(bh / (26.0 * zoom))):
					for wxi in range(3):
						if _hash(float(i) * 31.0 + float(wy) * 7.0 + float(wxi)) > 0.55:
							draw_rect(Rect2(bx + (10.0 + wxi * 24.0) * zoom, hy - bh + (14.0 + wy * 26.0) * zoom, 12.0 * zoom, 14.0 * zoom), Color(1.0, 0.82, 0.5, 0.35 + 0.5 * night))
		"cacti":
			var tile4: float = 340.0
			var lx6: float = _layer_x(0.5, 0.6)
			var first4: int = int(floor((lx6 - vis.x * 0.5 / zoom) / tile4)) - 1
			var cnt4: int = int(vis.x / (tile4 * zoom)) + 4
			for i in range(first4, first4 + cnt4):
				var cx: float = (float(i) * tile4 + _hash(float(i) * 1.7) * 160.0 - lx6) * zoom + vis.x * 0.5
				var ch: float = (80.0 + _hash(float(i) + 4.0) * 70.0) * zoom
				var cc: Color = Color("#1a1618")
				draw_rect(Rect2(cx - 7.0 * zoom, hy - ch, 14.0 * zoom, ch), cc)
				draw_rect(Rect2(cx - 28.0 * zoom, hy - ch * 0.7, 8.0 * zoom, ch * 0.35), cc)
				draw_rect(Rect2(cx - 28.0 * zoom, hy - ch * 0.4, 28.0 * zoom, 7.0 * zoom), cc)
				draw_rect(Rect2(cx + 20.0 * zoom, hy - ch * 0.85, 8.0 * zoom, ch * 0.4), cc)
				draw_rect(Rect2(cx, hy - ch * 0.5, 28.0 * zoom, 7.0 * zoom), cc)
		"waves":
			var lx5: float = _layer_x(0.2, 0.9)
			for r in range(4):
				var y: float = hy - (6.0 + r * 12.0) * zoom
				var pts := PackedVector2Array()
				for i in range(int(vis.x / 30.0) + 2):
					var sx5: float = float(i) * 30.0
					var wx5: float = (sx5 - vis.x * 0.5) / zoom + lx5
					pts.append(Vector2(sx5, y + sin(wx5 * 0.02 + time_s * 1.5 + r) * 4.0 * zoom))
				draw_polyline(pts, Color(0.75, 0.9, 0.95, 0.18 - r * 0.03), 2.0)
			# lighthouse sweep
			var lhx: float = fposmod((900.0 - lx5 * 0.3) * zoom, vis.x + 600.0) - 300.0
			draw_rect(Rect2(lhx, hy - 140 * zoom, 18 * zoom, 140 * zoom), Color("#0c1822"))
			if night > 0.3:
				draw_circle(Vector2(lhx + 9 * zoom, hy - 146 * zoom), 8 * zoom, Color(1, 0.9, 0.5, 0.9))


func _weather(b: Dictionary, night: float) -> void:
	if weather == "rain":
		var cyc: float = fmod(time_s + 3.0, 13.0)
		if cyc < 0.35:
			var fl: float = (1.0 - cyc / 0.35) * (0.55 + 0.45 * sin(cyc * 70.0))
			draw_rect(Rect2(0, 0, vis.x, vis.y), Color(0.85, 0.92, 1.0, 0.42 * fl))
			var bx: float = fposmod(floorf((time_s + 3.0) / 13.0) * 377.0, vis.x * 0.8) + vis.x * 0.1
			var by0: float = _sy(HORIZON_Y - 330.0)
			draw_polyline(PackedVector2Array([Vector2(bx, by0), Vector2(bx - 22.0, by0 + 70.0 * zoom), Vector2(bx + 10.0, by0 + 120.0 * zoom), Vector2(bx - 30.0, by0 + 200.0 * zoom), Vector2(bx - 12.0, _sy(HORIZON_Y))]), Color(1, 1, 1, fl), 3.0 * zoom)
		var rng := RandomNumberGenerator.new()
		for i in range(90):
			rng.seed = i * 31
			var x: float = fposmod(rng.randf() * vis.x - scroll * 2.0, vis.x)
			var y: float = fposmod(rng.randf() * vis.y + time_s * 900.0 * (0.6 + rng.randf() * 0.6), vis.y)
			draw_line(Vector2(x, y), Vector2(x - 6, y + 28), Color(0.7, 0.85, 1.0, 0.25), 1.5)
	elif weather == "snow" or bool(b["snow"]) and weather != "clear":
		var rng2 := RandomNumberGenerator.new()
		for i in range(70):
			rng2.seed = i * 17
			var x2: float = fposmod(rng2.randf() * vis.x - scroll * 1.2 + sin(time_s + i) * 12.0, vis.x)
			var y2: float = fposmod(rng2.randf() * vis.y + time_s * 80.0 * (0.5 + rng2.randf()), vis.y)
			draw_circle(Vector2(x2, y2), 2.2 + rng2.randf() * 2.0, Color(1, 1, 1, 0.7))
	elif weather == "fog":
		draw_rect(Rect2(0, 0, vis.x, vis.y), Color(0.7, 0.8, 0.85, 0.22))
