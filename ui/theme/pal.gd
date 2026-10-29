class_name Pal
extends RefCounted
## Contract palette. Use these everywhere.
const NIGHT := Color("#12303B")
const DEEP := Color("#0B1E26")
const LAMP := Color("#F2B84B")
const BRASS := Color("#B8893E")
const PARCHMENT := Color("#EADFC8")
const SIGNAL := Color("#C8503C")
const MIST := Color("#7FA6A3")
const INK := Color("#2A2018")
const RADIUS := 24

static func panel_style(bg: Color = NIGHT, border: Color = BRASS, radius: int = RADIUS) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(3)
	s.border_color = border
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 6)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 22
	s.content_margin_bottom = 22
	return s

static func reduced_motion() -> bool:
	return ProjectSettings.get_setting("unclaimed/reduced_motion", false)
