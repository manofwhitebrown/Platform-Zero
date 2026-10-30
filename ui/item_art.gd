class_name ItemArt
extends RefCounted
## Shared item drawing. ItemArt.draw(canvas, item_or_def, rect, opts) inside any _draw().
## Icon (tinted) + material finish + wear marks + revealed initials/stamp. Never a blank rectangle.
## opts: marks(bool, show revealed initials/stamp), finish(bool, default true), seed(int)

static var _tex: Dictionary = {}
const FALLBACK_ICONS: Array = ["bag", "book", "jar", "key", "letter", "shoe", "ticket", "watch"]
const METAL: Array = ["brass", "copper", "gold", "gilt", "iron", "silver", "steel", "tin", "tarnished"]
const GLASSY: Array = ["glass", "porcelain", "clay", "tortoiseshell", "bone", "tintype"]
const CLOTH: Array = ["wool", "cotton", "felt", "fleece", "linen", "silk", "tweed", "suede", "canvas", "straw"]
const GRAIN: Array = ["wood", "leather", "paper", "card", "pasteboard", "parchment"]


static func _def_of(item: Dictionary) -> Dictionary:
	var d: Dictionary = Content.object_by_id(String(item.get("def_id", item.get("id", ""))))
	return d if not d.is_empty() else item


static func icon_tex(item: Dictionary) -> Texture2D:
	var def: Dictionary = _def_of(item)
	var nm: String = String(item.get("icon", def.get("icon", "")))
	if nm == "" or not ResourceLoader.exists("res://assets/icons/%s.svg" % nm):
		nm = String(FALLBACK_ICONS[absi(String(item.get("name", def.get("name", "x"))).hash()) % FALLBACK_ICONS.size()])
	if not _tex.has(nm):
		_tex[nm] = load("res://assets/icons/%s.svg" % nm) if ResourceLoader.exists("res://assets/icons/%s.svg" % nm) else null
	return _tex[nm]


static func tint_of(item: Dictionary) -> Color:
	var def: Dictionary = _def_of(item)
	return Color(String(item.get("tint", def.get("tint", "#B8893E"))))


static func clue_value(item: Dictionary, attr: String) -> String:
	var def: Dictionary = _def_of(item)
	for c in def.get("clues", []):
		if String(c.get("attr", "")) == attr:
			return String(c.get("value", ""))
	return ""


static func draw(canvas: CanvasItem, item: Dictionary, rect: Rect2, opts: Dictionary = {}) -> void:
	var tint: Color = tint_of(item)
	var tx: Texture2D = icon_tex(item)
	var sd: int = int(opts.get("seed", String(item.get("iid", item.get("id", "x"))).hash()))
	if tx != null:
		canvas.draw_texture_rect(tx, rect, false, tint)
	else:
		_bundle(canvas, rect, tint)
	if not bool(opts.get("finish", true)):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var core: Rect2 = rect.grow_individual(-rect.size.x * 0.24, -rect.size.y * 0.24, -rect.size.x * 0.24, -rect.size.y * 0.24)
	var mat: String = clue_value(item, "material")
	var wear: String = clue_value(item, "wear")
	if METAL.has(mat) or wear == "tarnished" or wear == "polished smooth":
		var a: float = 0.28 if wear != "tarnished" else 0.12
		canvas.draw_line(core.position + Vector2(core.size.x * 0.2, core.size.y * 0.15), core.position + Vector2(core.size.x * 0.05, core.size.y * 0.55), Color(1, 0.95, 0.8, a), maxf(2.0, rect.size.x * 0.03))
	elif GLASSY.has(mat):
		canvas.draw_arc(core.get_center(), core.size.x * 0.32, -2.6, -1.7, 10, Color(1, 1, 1, 0.3), maxf(2.0, rect.size.x * 0.025))
	elif CLOTH.has(mat):
		for i in 5:
			var y: float = core.position.y + core.size.y * (0.15 + 0.17 * i)
			canvas.draw_line(Vector2(core.position.x + core.size.x * 0.1, y), Vector2(core.end.x - core.size.x * 0.1, y + rect.size.y * 0.02), Color(0, 0, 0, 0.10), 2.0)
	elif GRAIN.has(mat):
		for i in 3:
			var x: float = core.position.x + core.size.x * (0.25 + 0.25 * i)
			canvas.draw_line(Vector2(x, core.position.y + core.size.y * 0.1), Vector2(x + rect.size.x * 0.02, core.end.y - core.size.y * 0.1), Color(0, 0, 0, 0.09), 2.0)
	_wear(canvas, wear, core, rect.size.x, rng)
	if bool(opts.get("marks", false)):
		_marks(canvas, item, rect)


static func _wear(canvas: CanvasItem, wear: String, core: Rect2, s: float, rng: RandomNumberGenerator) -> void:
	match wear:
		"scuffed", "creased", "frayed", "threadbare", "dented", "chipped":
			for i in 6:
				var a: Vector2 = core.position + Vector2(rng.randf(), rng.randf()) * core.size
				canvas.draw_line(a, a + Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(0.04, 0.14)) * s, Color(0.08, 0.05, 0.03, 0.35), maxf(2.0, s * 0.015))
		"water-stained", "sooty", "faded", "sticky":
			var col: Color = Color(0.05, 0.04, 0.03, 0.2) if wear == "sooty" else (Color(1, 1, 1, 0.18) if wear == "faded" else Color(0.35, 0.25, 0.1, 0.22))
			for i in 3:
				canvas.draw_circle(core.position + Vector2(rng.randf(), rng.randf()) * core.size, s * rng.randf_range(0.05, 0.11), col)
		"patched", "mended":
			var p := Rect2(core.position + Vector2(core.size.x * 0.5, core.size.y * 0.45), Vector2(s * 0.16, s * 0.14))
			canvas.draw_rect(p, Color(0.72, 0.6, 0.4, 0.9))
			canvas.draw_rect(p, Color(0.2, 0.12, 0.06, 0.8), false, 2.0)
			canvas.draw_line(p.position + Vector2(4, 4), p.end - Vector2(4, 4), Color(0.2, 0.12, 0.06, 0.7), 2.0)
		"tarnished":
			for i in 5:
				canvas.draw_circle(core.position + Vector2(rng.randf(), rng.randf()) * core.size, s * 0.02, Color(0.1, 0.25, 0.2, 0.4))


static func _marks(canvas: CanvasItem, item: Dictionary, rect: Rect2) -> void:
	var known: Array = item.get("clues_known", [])
	var def: Dictionary = _def_of(item)
	var f: Font = ThemeDB.fallback_font
	for c in def.get("clues", []):
		if not known.has(c.get("id", "")):
			continue
		var attr: String = String(c.get("attr", ""))
		if attr == "initials":
			var tag := Rect2(rect.position + Vector2(rect.size.x * 0.58, rect.size.y * 0.66), Vector2(rect.size.x * 0.34, rect.size.y * 0.2))
			canvas.draw_rect(tag, Pal.PARCHMENT)
			canvas.draw_rect(tag, Pal.BRASS, false, 2.0)
			f.draw_string(canvas.get_canvas_item(), tag.position + Vector2(0, tag.size.y * 0.7), String(c.get("value", "")), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, int(tag.size.y * 0.55), Pal.INK)
		elif attr == "station_stamp":
			var cc: Vector2 = rect.position + rect.size * Vector2(0.2, 0.74)
			canvas.draw_arc(cc, rect.size.x * 0.11, 0, TAU, 28, Color(Pal.SIGNAL, 0.85), 3.0)
			canvas.draw_arc(cc, rect.size.x * 0.075, 0, TAU, 24, Color(Pal.SIGNAL, 0.6), 2.0)


## Soft parcel for anything without an icon.
static func _bundle(canvas: CanvasItem, rect: Rect2, tint: Color) -> void:
	var r: Rect2 = rect.grow_individual(-rect.size.x * 0.2, -rect.size.y * 0.25, -rect.size.x * 0.2, -rect.size.y * 0.2)
	Dr.rrect(canvas, r, rect.size.x * 0.08, tint.darkened(0.15))
	canvas.draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Pal.PARCHMENT, 4.0)
	canvas.draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Pal.PARCHMENT, 4.0)
