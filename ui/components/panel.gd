class_name UPanel
extends PanelContainer
## Rounded 24px night-teal panel with brass edge. Fades/slides in when shown with pop_in().

func _ready() -> void:
	add_theme_stylebox_override("panel", Pal.panel_style())

func pop_in() -> void:
	if Pal.reduced_motion():
		modulate.a = 1.0
		return
	pivot_offset = size / 2.0
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
