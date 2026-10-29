class_name Sparkle
extends RefCounted
## One-shot particle bursts. Sparkle.burst(parent, local_pos, color, amount, kind)  kind: "sparkle" | "confetti"

static func burst(parent: Node, pos: Vector2, color: Color = Pal.LAMP, amount: int = 24, kind: String = "sparkle") -> void:
	if Pal.reduced_motion():
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.9 if kind == "sparkle" else 1.6
	p.direction = Vector2(0, -1)
	p.spread = 180.0 if kind == "sparkle" else 70.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 420.0 if kind == "sparkle" else 760.0
	p.gravity = Vector2(0, 200.0 if kind == "sparkle" else 1100.0)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 11.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	if kind == "confetti":
		var g := Gradient.new()
		g.colors = PackedColorArray([Pal.LAMP, Pal.SIGNAL, Pal.MIST, Pal.PARCHMENT])
		g.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
		p.color_initial_ramp = g
	else:
		p.color = color
		var fade := Gradient.new()
		fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		p.color_ramp = fade
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
