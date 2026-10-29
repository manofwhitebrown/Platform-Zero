class_name Hud
extends CanvasLayer
## Top bar (tokens, rep tier + progress, stop + next-stop timer, settings), context chip (tutorial / carrying), toasts, settings sheet.

var v: HudView
var sheet: PanelContainer
var world: Node2D


class HudView extends Control:
	var t: float = 0.0
	var tok_shown: float = 0.0
	var tok_pop: float = 9.0
	var toasts: Array = []
	var gear: Rect2
	var hud: Hud
	var coin: Texture2D
	var inset: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		coin = load("res://assets/icons/coin.svg")
		tok_shown = float(Sim.tokens)
		Events.tokens_changed.connect(func(_n: int) -> void: tok_pop = 0.0)
		Events.toast.connect(func(s: String, k: String) -> void:
			toasts.append({"s": s, "k": k, "t": 0.0})
			if toasts.size() > 3:
				toasts.pop_front())

	func _process(d: float) -> void:
		t += d
		tok_pop += d
		tok_shown = lerpf(tok_shown, float(Sim.tokens), minf(1.0, d * 8.0))
		for tt in toasts:
			tt["t"] = float(tt["t"]) + d
		toasts = toasts.filter(func(x: Dictionary) -> bool: return float(x["t"]) < 3.6)
		var win: Vector2i = DisplayServer.window_get_size()
		var sa: Rect2i = DisplayServer.get_display_safe_area()
		inset = float(sa.position.y) * size.y / maxf(1.0, float(win.y)) if win.y > 0 else 0.0
		queue_redraw()

	func _f() -> Font:
		return get_theme_default_font()

	func txt(p: Vector2, s: String, sz: int, col: Color, w: float = -1.0, al: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
		_f().draw_string(get_canvas_item(), p, s, al, w, sz, col)

	func _draw() -> void:
		var vs: Vector2 = size
		if vs.x < 10:
			return
		var top: float = inset + 12.0
		var h: float = 96.0
		var bar := Rect2(14, top, vs.x - 28, h)
		Dr.rrect(self, bar.grow(3), 28, Color(0, 0, 0, 0.35))
		Dr.rrect(self, bar, 26, Color(Pal.DEEP, 0.88))
		draw_rect(bar, Color(Pal.BRASS, 0.8), false, 3.0)
		# tokens
		var pop: float = 1.0 + (0.25 * exp(-tok_pop * 7.0) * cos(tok_pop * 16.0) if tok_pop < 1.2 else 0.0)
		var cc := Vector2(bar.position.x + 56, bar.position.y + h / 2.0)
		if coin != null:
			draw_texture_rect(coin, Rect2(cc - Vector2(32, 32) * pop, Vector2(64, 64) * pop), false, Pal.LAMP)
		txt(cc + Vector2(48, 16), str(int(round(tok_shown))), 44, Pal.PARCHMENT)
		# stop + timer (centre)
		var tr: Dictionary = Sim.get_train()
		var st: String = String(tr.get("state", "moving"))
		var stop: Dictionary = tr.get("stop", {})
		var label: String = {"moving": "Next stop", "arriving": "Arriving at", "stopped": "Now at", "departing": "Leaving"}.get(st, "Next stop")
		var cx: float = vs.x * 0.5
		var wcol: float = minf(vs.x * 0.36, 380.0)
		txt(Vector2(cx - wcol / 2.0, bar.position.y + 40), "%s" % label, 24, Color(Pal.MIST, 0.9), wcol, HORIZONTAL_ALIGNMENT_CENTER)
		txt(Vector2(cx - wcol / 2.0, bar.position.y + 72), String(stop.get("name", "")), 32, Pal.PARCHMENT, wcol, HORIZONTAL_ALIGNMENT_CENTER)
		var ph: float = float(tr.get("phase_t", 0.0))
		var pr := Rect2(cx - wcol / 2.0 + 20, bar.end.y - 12, wcol - 40, 6)
		draw_rect(pr, Color(0, 0, 0, 0.5))
		draw_rect(Rect2(pr.position, Vector2(pr.size.x * ph, pr.size.y)), Pal.MIST)
		# rep tier
		var tier: int = Sim.tier_for(Sim.rep)
		var th: Array = Sim.TIER_THRESHOLDS
		var lo: float = float(th[tier])
		var hi: float = float(th[tier + 1]) if tier + 1 < th.size() else lo
		var frac: float = 1.0 if hi <= lo else clampf((float(Sim.rep) - lo) / (hi - lo), 0.0, 1.0)
		var rx: float = bar.end.x - 130 - minf(vs.x * 0.2, 210.0)
		var rw: float = minf(vs.x * 0.2, 210.0)
		txt(Vector2(rx, bar.position.y + 40), "Tier %d" % (tier + 1), 26, Pal.LAMP, rw)
		var rb := Rect2(rx, bar.position.y + 54, rw, 14)
		Dr.rrect(self, rb, 7, Color(0, 0, 0, 0.5))
		Dr.rrect(self, Rect2(rb.position, Vector2(maxf(14.0, rb.size.x * frac), rb.size.y)), 7, Pal.LAMP)
		txt(Vector2(rx, bar.position.y + 88), "%d rep" % Sim.rep, 20, Color(Pal.PARCHMENT, 0.7), rw)
		# gear (>=48dp, big)
		gear = Rect2(bar.end.x - 108, bar.position.y + 6, 96, 84)
		var gc: Vector2 = gear.get_center()
		draw_circle(gc, 28, Color(Pal.BRASS, 0.9))
		draw_circle(gc, 11, Pal.DEEP)
		for i in range(8):
			var a: float = float(i) * TAU / 8.0
			draw_line(gc + Vector2.from_angle(a) * 24, gc + Vector2.from_angle(a) * 36, Pal.BRASS, 9.0)
		# context chip
		var chip: String = _context()
		if chip != "":
			var w: float = minf(vs.x - 60, 880.0)
			var cr := Rect2(vs.x / 2.0 - w / 2.0, bar.end.y + 14, w, 70)
			var bob: float = 0.0 if Pal.reduced_motion() else sin(t * 3.0) * 3.0
			cr.position.y += bob
			Dr.rrect(self, cr.grow(3), 22, Color(0, 0, 0, 0.3))
			Dr.rrect(self, cr, 20, Color(Pal.PARCHMENT, 0.96))
			draw_rect(cr.grow(-6), Color(Pal.BRASS, 0.5), false, 2.0)
			txt(cr.position + Vector2(0, 45), chip, 30, Pal.INK, w, HORIZONTAL_ALIGNMENT_CENTER)
		# toasts
		var ty: float = bar.end.y + (110.0 if chip != "" else 14.0) + 90.0
		for tt in toasts:
			var a: float = float(tt["t"])
			var al: float = clampf(minf(a / 0.25, (3.6 - a) / 0.5), 0.0, 1.0)
			var w2: float = minf(vs.x - 80, 760.0)
			var r := Rect2(vs.x / 2.0 - w2 / 2.0, ty + (1.0 - al) * -20.0, w2, 74)
			Dr.rrect(self, r, 22, Color(Pal.NIGHT, 0.94 * al))
			draw_rect(r, Color(Pal.LAMP if String(tt["k"]) == "good" else Pal.BRASS, al), false, 3.0)
			txt(r.position + Vector2(0, 47), String(tt["s"]), 28, Color(Pal.PARCHMENT, al), w2, HORIZONTAL_ALIGNMENT_CENTER)
			ty += 86.0

	func _context() -> String:
		var tut: Dictionary = Sim.get_tutorial()
		if String(tut.get("stage", "done")) != "done" and String(tut.get("hint", "")) != "":
			return String(tut["hint"])
		var c: String = String(Sim.get_player().get("carrying", ""))
		if c != "":
			return "Carrying %s. Take it to the bench." % String(Sim.get_item(c).get("name", "something"))
		return ""

	func _input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if gear.has_point((e as InputEventMouseButton).position) and not hud.world.get("bench").is_open:
				hud.toggle_sheet()
				get_viewport().set_input_as_handled()


func _ready() -> void:
	layer = 15
	v = HudView.new()
	v.hud = self
	add_child(v)
	_build_sheet()


func _build_sheet() -> void:
	sheet = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", Pal.panel_style(Pal.NIGHT, Pal.BRASS))
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	sheet.add_child(col)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Pal.LAMP)
	col.add_child(title)
	for opt in [["sound", "Sound", true], ["haptics", "Haptics", true], ["reduced_motion", "Reduce motion", false]]:
		var b := UButton.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(560, 110)
		b.text = String(opt[1])
		b.button_pressed = Settings.get_bool(String(opt[0]), bool(opt[2]))
		var key: String = String(opt[0])
		var lbl: String = String(opt[1])
		b.text = "%s: %s" % [lbl, "On" if b.button_pressed else "Off"]
		b.toggled.connect(func(on: bool) -> void:
			Settings.set_bool(key, on)
			b.text = "%s: %s" % [lbl, "On" if on else "Off"]
			if key == "sound" or key == "haptics":
				Sfx.apply_settings())
		col.add_child(b)
	var done := UButton.new()
	done.text = "Close"
	done.custom_minimum_size = Vector2(560, 110)
	done.pressed.connect(toggle_sheet)
	col.add_child(done)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	holder.add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_CENTER)


func toggle_sheet() -> void:
	sheet.visible = not sheet.visible
	sheet.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	Sfx.play("tap")
