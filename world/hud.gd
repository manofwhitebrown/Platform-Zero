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
	var skip_rect: Rect2 = Rect2()
	var book: Rect2 = Rect2()
	var map_rect: Rect2 = Rect2()
	var map_icon: Texture2D
	var shop_rect: Rect2 = Rect2()
	var night_rect: Rect2 = Rect2()
	var help_rect: Rect2 = Rect2()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		coin = load("res://assets/icons/coin.svg")
		map_icon = load("res://assets/icons/map.svg")
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
		var wcol: float = minf(vs.x * 0.3, 340.0)
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
		var rw: float = minf(vs.x * 0.1, 110.0)
		var rx: float = bar.position.x + 224  # left of the stop name, clear of map/book/gear buttons
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
		# ledger book button
		book = Rect2(gear.position.x - 100, bar.position.y + 6, 96, 84)
		var bk: Rect2 = book.grow(-14)
		Dr.rrect(self, bk, 8, Pal.PARCHMENT)
		draw_rect(bk, Pal.BRASS, false, 3.0)
		draw_line(bk.get_center() + Vector2(0, -bk.size.y / 2.0), bk.get_center() + Vector2(0, bk.size.y / 2.0), Pal.BRASS, 3.0)
		for i in range(3):
			draw_line(bk.position + Vector2(8, 14 + i * 12), bk.position + Vector2(bk.size.x / 2.0 - 8, 14 + i * 12), Color(Pal.INK, 0.5), 2.0)
		# train map button
		map_rect = Rect2(book.position.x - 100, bar.position.y + 6, 96, 84)
		var mr: Rect2 = map_rect.grow(-14)
		Dr.rrect(self, mr, 8, Pal.BRASS)
		if map_icon != null:
			draw_texture_rect(map_icon, mr.grow(-4), false, Pal.DEEP)
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
		# help button
		help_rect = Rect2(14, bar.end.y + 176, 96, 84)
		var hc: Vector2 = help_rect.get_center()
		draw_circle(hc, 32, Color(Pal.DEEP, 0.85))
		draw_arc(hc, 32, 0, TAU, 32, Color(Pal.BRASS, 0.9), 3.0)
		txt(Vector2(hc.x - 30, hc.y + 15), "?", 44, Pal.PARCHMENT, 60.0, HORIZONTAL_ALIGNMENT_CENTER)
		# shop pill
		shop_rect = Rect2(14, bar.end.y + 92, 190, 72)
		var shr: Rect2 = shop_rect.grow_individual(0, -12, 0, -12)
		Dr.rrect(self, shr, 18, Color(Pal.BRASS, 0.85))
		if coin != null:
			draw_texture_rect(coin, Rect2(shr.position + Vector2(10, 3), Vector2(42, 42)), false, Pal.DEEP)
		txt(Vector2(shr.position.x + 58, shr.position.y + 34), "Shop", 28, Pal.DEEP)
		# night case pill (hidden during the tutorial and for cheated runs)
		night_rect = Rect2()
		if String(Sim.get_tutorial().get("stage", "done")) == "done" and not Sim.cheated:
			night_rect = Rect2(214, bar.end.y + 92, 290, 72)
			var nr: Rect2 = night_rect.grow_individual(0, -12, 0, -12)
			var solved: bool = bool(Sim.get_daily().get("done", false))
			Dr.rrect(self, nr, 18, Color(Pal.MIST, 0.35) if solved else Color(Pal.LAMP, 0.9))
			draw_circle(nr.position + Vector2(30, 24), 13, Pal.DEEP)
			draw_circle(nr.position + Vector2(36, 20), 12, Color(Pal.LAMP, 0.9) if not solved else Color(Pal.MIST, 0.6))
			txt(Vector2(nr.position.x + 56, nr.position.y + 34), "Night Case", 26, Pal.DEEP)
		# quiet tutorial skip
		skip_rect = Rect2()
		if String(Sim.get_tutorial().get("stage", "done")) != "done":
			skip_rect = Rect2(vs.x / 2.0 + minf(vs.x - 60, 880.0) / 2.0 - 170, bar.end.y + 92, 170, 72)
			var sr: Rect2 = skip_rect.grow_individual(0, -12, 0, -12)
			Dr.rrect(self, sr, 18, Color(Pal.DEEP, 0.55))
			txt(Vector2(sr.position.x, sr.position.y + 34), "Skip intro", 24, Color(Pal.PARCHMENT, 0.8), sr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
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
			if book.has_point((e as InputEventMouseButton).position) and not hud.world.get("bench").is_open:
				var gr: Node = hud.world.get_parent()
				if gr is GameRoot:
					(gr as GameRoot).open_screen("ledger")
					Audio.play("ui_tap")
					get_viewport().set_input_as_handled()
					return
			if map_rect.has_point((e as InputEventMouseButton).position) and not hud.world.get("bench").is_open:
				var gm: Node = hud.world.get_parent()
				if gm is GameRoot:
					(gm as GameRoot).open_screen("map")
					get_viewport().set_input_as_handled()
					return
			if shop_rect.has_point((e as InputEventMouseButton).position) and not hud.world.get("bench").is_open:
				var gr2: Node = hud.world.get_parent()
				if gr2 is GameRoot:
					(gr2 as GameRoot).open_screen("shop")
					Audio.play("ui_tap")
					get_viewport().set_input_as_handled()
					return
			if night_rect.has_point((e as InputEventMouseButton).position) and not hud.world.get("bench").is_open:
				var gr3: Node = hud.world.get_parent()
				if gr3 is GameRoot:
					(gr3 as GameRoot).open_screen("daily")
					Audio.play("ui_tap")
					get_viewport().set_input_as_handled()
					return
			if help_rect.has_point((e as InputEventMouseButton).position) and not hud.world.get("bench").is_open:
				var gr4: Node = hud.world.get_parent()
				if gr4 is GameRoot:
					(gr4 as GameRoot).open_screen("help")
					Audio.play("ui_open")
					get_viewport().set_input_as_handled()
					return
			if skip_rect.has_point((e as InputEventMouseButton).position):
				Sim.skip_tutorial()
				get_viewport().set_input_as_handled()
				return
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
	## Settings now live in SettingsScreen (ScreenManager overlay); `sheet` stays as a hidden stub.
	sheet = PanelContainer.new()
	sheet.visible = false
	add_child(sheet)


func toggle_sheet() -> void:
	var gr: Node = world.get_parent()
	if gr is GameRoot:
		(gr as GameRoot).open_screen("settings")
	Audio.play("ui_open")
