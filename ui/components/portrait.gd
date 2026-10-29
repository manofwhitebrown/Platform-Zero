class_name Portrait
extends Control
## In-engine owner portrait drawn from `look` params. set_look(owner.look); emote("happy"|"neutral"|"sad").
var look := {"skin": "#d9a47a", "hair": "#3b2a20", "coat": "#7FA6A3", "hat": "none", "accessory": "none"}
var mood := "neutral"
var _bob := 0.0

func set_look(l: Dictionary) -> void:
	look = l
	queue_redraw()

func emote(m: String) -> void:
	mood = m
	queue_redraw()
	if Pal.reduced_motion():
		return
	pivot_offset = size / 2.0
	var t := create_tween()
	if m == "happy":
		t.tween_property(self, "scale", Vector2(1.08, 0.94), 0.1)
		t.tween_property(self, "position:y", position.y - 40, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "position:y", position.y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "scale", Vector2.ONE, 0.2)
	else:
		var x := position.x
		for dx in [-14, 14, -9, 9, 0]:
			t.tween_property(self, "position:x", x + dx, 0.06)

func _process(delta: float) -> void:
	if Pal.reduced_motion():
		return
	_bob += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var cx := w / 2.0
	var bob := sin(_bob * 2.0) * 3.0 if not Pal.reduced_motion() else 0.0
	var skin := Color(look.get("skin", "#d9a47a"))
	var hair := Color(look.get("hair", "#3b2a20"))
	var coat := Color(look.get("coat", "#7FA6A3"))
	var hat: String = look.get("hat", "none")
	var acc: String = look.get("accessory", "none")
	var hr := minf(w, h) * 0.2
	var hy := h * 0.34 + bob
	# shadow
	draw_circle(Vector2(cx, h * 0.97), w * 0.3, Color(0, 0, 0, 0.0))
	# body / coat
	var body := PackedVector2Array([Vector2(cx - w * 0.38, h), Vector2(cx - w * 0.3, h * 0.62 + bob), Vector2(cx - hr * 0.5, h * 0.55 + bob), Vector2(cx + hr * 0.5, h * 0.55 + bob), Vector2(cx + w * 0.3, h * 0.62 + bob), Vector2(cx + w * 0.38, h)])
	draw_colored_polygon(body, coat)
	draw_polyline(PackedVector2Array(Array(body) + [body[0]]), coat.darkened(0.4), 4.0, true)
	draw_line(Vector2(cx, h * 0.62 + bob), Vector2(cx, h), coat.darkened(0.35), 4.0)
	for i in 3:
		draw_circle(Vector2(cx + 14, h * (0.72 + i * 0.1) + bob), 6.0, Pal.BRASS)
	# scarf
	if hat == "scarf":
		draw_rect(Rect2(cx - hr * 0.9, h * 0.54 + bob, hr * 1.8, hr * 0.5), Pal.SIGNAL, true)
	# neck
	draw_rect(Rect2(cx - hr * 0.3, hy + hr * 0.7, hr * 0.6, hr * 0.7), skin.darkened(0.12))
	# back hair
	draw_circle(Vector2(cx, hy), hr * 1.08, hair)
	# head
	draw_circle(Vector2(cx, hy + 4), hr, skin)
	# fringe
	draw_arc(Vector2(cx, hy), hr * 1.02, PI * 1.05, PI * 1.95, 24, hair, hr * 0.35, true)
	# eyes
	var ey := hy + hr * 0.05
	if mood == "happy":
		draw_arc(Vector2(cx - hr * 0.4, ey), hr * 0.14, PI, TAU, 10, Pal.INK, 4.0, true)
		draw_arc(Vector2(cx + hr * 0.4, ey), hr * 0.14, PI, TAU, 10, Pal.INK, 4.0, true)
	else:
		draw_circle(Vector2(cx - hr * 0.4, ey), hr * 0.09, Pal.INK)
		draw_circle(Vector2(cx + hr * 0.4, ey), hr * 0.09, Pal.INK)
	# cheeks
	draw_circle(Vector2(cx - hr * 0.62, ey + hr * 0.3), hr * 0.12, Color(Pal.SIGNAL.r, Pal.SIGNAL.g, Pal.SIGNAL.b, 0.25))
	draw_circle(Vector2(cx + hr * 0.62, ey + hr * 0.3), hr * 0.12, Color(Pal.SIGNAL.r, Pal.SIGNAL.g, Pal.SIGNAL.b, 0.25))
	# mouth
	var my := hy + hr * 0.52
	if mood == "happy":
		draw_arc(Vector2(cx, my - hr * 0.1), hr * 0.3, 0.2, PI - 0.2, 12, Pal.INK, 4.0, true)
	elif mood == "sad":
		draw_arc(Vector2(cx, my + hr * 0.25), hr * 0.25, PI + 0.3, TAU - 0.3, 12, Pal.INK, 4.0, true)
	else:
		draw_line(Vector2(cx - hr * 0.2, my), Vector2(cx + hr * 0.2, my), Pal.INK, 4.0, true)
	# accessories
	if acc == "glasses":
		draw_arc(Vector2(cx - hr * 0.4, ey), hr * 0.26, 0, TAU, 20, Pal.BRASS, 4.0, true)
		draw_arc(Vector2(cx + hr * 0.4, ey), hr * 0.26, 0, TAU, 20, Pal.BRASS, 4.0, true)
		draw_line(Vector2(cx - hr * 0.14, ey), Vector2(cx + hr * 0.14, ey), Pal.BRASS, 4.0)
	elif acc == "beard":
		draw_circle(Vector2(cx, hy + hr * 0.8), hr * 0.55, hair)
		draw_arc(Vector2(cx, my - hr * 0.05), hr * 0.18, 0.2, PI - 0.2, 8, Pal.INK, 4.0, true)
	elif acc == "pipe":
		draw_line(Vector2(cx + hr * 0.2, my + 4), Vector2(cx + hr * 0.85, my + hr * 0.2), Pal.INK.lightened(0.2), 7.0, true)
		draw_circle(Vector2(cx + hr * 0.9, my + hr * 0.1), hr * 0.16, Pal.INK.lightened(0.2))
	# hats
	if hat == "cap":
		draw_arc(Vector2(cx, hy - 4), hr * 1.05, PI, TAU, 24, coat.darkened(0.3), hr * 0.5, true)
		draw_rect(Rect2(cx - hr * 0.2, hy - hr * 0.2, hr * 1.3, hr * 0.16), coat.darkened(0.5))
	elif hat == "top":
		draw_rect(Rect2(cx - hr * 0.95, hy - hr * 0.55, hr * 1.9, hr * 0.2), Pal.DEEP)
		draw_rect(Rect2(cx - hr * 0.6, hy - hr * 1.75, hr * 1.2, hr * 1.25), Pal.DEEP)
		draw_rect(Rect2(cx - hr * 0.6, hy - hr * 0.8, hr * 1.2, hr * 0.18), Pal.BRASS)
