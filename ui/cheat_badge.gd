class_name CheatBadge
extends Control
## Small drawn flask shown top-left while Sim.cheated is true.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(56, 56)
	position = Vector2(14, 200)
	size = Vector2(56, 56)

func _process(_d: float) -> void:
	var v: bool = Sim.cheated
	if visible != v:
		visible = v
	queue_redraw()

func _draw() -> void:
	var c := Color(Pal.MIST, 0.9)
	draw_colored_polygon(PackedVector2Array([Vector2(22, 6), Vector2(34, 6), Vector2(34, 24), Vector2(50, 50), Vector2(6, 50), Vector2(22, 24)]), Color(Pal.NIGHT, 0.85))
	draw_polyline(PackedVector2Array([Vector2(22, 6), Vector2(22, 24), Vector2(6, 50), Vector2(50, 50), Vector2(34, 24), Vector2(34, 6)]), c, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(14, 40), Vector2(42, 40), Vector2(48, 49), Vector2(8, 49)]), Color(Pal.LAMP, 0.8))
