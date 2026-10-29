class_name UCard
extends PanelContainer
## Parchment paper card (story cards, clue notes). Uses paper shader for grain.
const PAPER_SHADER := preload("res://shaders/paper.gdshader")

func _ready() -> void:
	var s := Pal.panel_style(Pal.PARCHMENT, Pal.BRASS, 18)
	s.shadow_size = 10
	add_theme_stylebox_override("panel", s)
	var m := ShaderMaterial.new()
	m.shader = PAPER_SHADER
	material = m
	# Child labels default to ink on parchment.
	theme_type_variation = &""

static func ink_label(text: String, size: int = 34) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Pal.INK)
	l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0))
	l.add_theme_font_size_override("font_size", size)
	return l

## Stamp-in effect for a clue note.
func stamp() -> void:
	if Pal.reduced_motion():
		return
	pivot_offset = size / 2.0
	scale = Vector2(1.4, 1.4)
	modulate.a = 0.0
	rotation = deg_to_rad(randf_range(-3.0, 3.0))
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.12)
