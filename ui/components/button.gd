class_name UButton
extends Button
## Brass ticket button with squash/stretch on press. Theme supplies the look.

func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	button_down.connect(_squash)
	button_up.connect(_release)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _squash() -> void:
	Sfx.play("tap")
	if Pal.reduced_motion():
		return
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.06, 0.92), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _release() -> void:
	if Pal.reduced_motion():
		scale = Vector2.ONE
		return
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(0.96, 1.06), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
