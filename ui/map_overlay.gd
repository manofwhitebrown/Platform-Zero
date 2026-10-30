class_name MapOverlay
extends Control
## C14: parchment-and-brass train map. Six cars in a row (drawn in _draw), tap one to select it,
## the card below shows its text and stats and a "Go there" button (Sim.fast_travel).

var mgr: ScreenManager
var rows: Array = []
var sel: int = 0
var canvas: Control
var t: float = 0.0
var _name_l: Label
var _desc_l: Label
var _stat_l: Label
var _msg_l: Label
var _go: UButton
var _rects: Array = []


func _init(p_mgr: ScreenManager = null) -> void:
	mgr = p_mgr


func _ready() -> void:
	theme = load("res://ui/theme/unclaimed_theme.tres")
	rows = MapData.build()
	for i in rows.size():
		if bool(rows[i]["is_player_car"]):
			sel = i
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Pal.panel_style(Pal.NIGHT, Pal.BRASS))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Ledger._lbl("Train map", 52, Pal.LAMP)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UButton.new()
	x.text = "Close"
	x.custom_minimum_size = Vector2(190, 100)
	x.pressed.connect(_close)
	head.add_child(x)
	canvas = Control.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(0, 360)
	canvas.draw.connect(_draw_map)
	canvas.gui_input.connect(_on_input)
	col.add_child(canvas)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Pal.panel_style(Color(Pal.PARCHMENT, 0.97), Pal.BRASS, 18))
	col.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	_name_l = Ledger._lbl("", 40, Pal.SIGNAL)
	_desc_l = Ledger._lbl("", 28, Color(Pal.INK, 0.92), true)
	_stat_l = Ledger._lbl("", 26, Color(Pal.INK, 0.75), true)
	_msg_l = Ledger._lbl("", 26, Pal.SIGNAL, true)
	for l in [_name_l, _desc_l, _stat_l, _msg_l]:
		v.add_child(l)
	_go = UButton.new()
	_go.custom_minimum_size = Vector2(0, 110)
	_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_go.pressed.connect(_go_there)
	v.add_child(_go)
	_refresh()
	Audio.play("map_open")
	set_process(true)


func _process(d: float) -> void:
	t += d
	canvas.queue_redraw()


func _close() -> void:
	Audio.play("map_close")
	mgr.close_top()


func _select(i: int) -> void:
	if i == sel:
		return
	sel = i
	_refresh()
	Audio.play("map_select")


func _refresh() -> void:
	if rows.is_empty():
		return
	var r: Dictionary = rows[sel]
	_name_l.text = String(r["name"])
	_msg_l.text = ""
	if bool(r["unlocked"]):
		_desc_l.text = String(r["desc"])
		_stat_l.text = "Claimants waiting: %d   ·   Items lying about: %d   ·   Passengers: %d" % [int(r["claimants_waiting"]), int(r["items_here"]), int(r["passengers"])]
		_go.disabled = bool(r["is_player_car"])
		_go.text = "You are here" if bool(r["is_player_car"]) else "Go there"
	else:
		_desc_l.text = String(r["lock_hint"])
		_stat_l.text = "Reputation %d needed" % int(r["tier_rep"])
		_go.disabled = true
		_go.text = "Locked"
	canvas.queue_redraw()


func _go_there() -> void:
	var r: Dictionary = rows[sel]
	var res: Dictionary = Sim.fast_travel(String(r["car_id"]))
	if bool(res.get("ok", false)):
		Audio.play("map_close")
		mgr.close_top()
	else:
		_msg_l.text = String(res.get("hint", "Not just yet."))


func _on_input(e: InputEvent) -> void:
	var pos := Vector2.ZERO
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (e as InputEventMouseButton).position
	elif e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
		pos = (e as InputEventScreenTouch).position
	else:
		return
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(pos):
			_select(i)
			return


func _draw_map() -> void:
	if canvas.size.y > canvas.size.x * 0.75:
		_draw_vertical()
	else:
		_draw_horizontal()


func _draw_horizontal() -> void:
	var sz: Vector2 = canvas.size
	var font: Font = get_theme_default_font()
	# night sky strip with a soft lamp wash behind the player's car
	Dr.vgrad(canvas, Rect2(Vector2.ZERO, sz), Color(Pal.DEEP, 0.9), Color(Pal.NIGHT, 0.9))
	canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(Pal.BRASS, 0.5), false, 2.0)
	var n: int = maxi(rows.size(), 1)
	var margin: float = 22.0
	var gap: float = 14.0
	var cw: float = minf((sz.x - margin * 2.0 - gap * float(n - 1)) / float(n), 340.0)
	var ch: float = minf(cw * 0.95, sz.y * 0.6)
	var total: float = cw * float(n) + gap * float(n - 1)
	var x0: float = (sz.x - total) / 2.0
	var y0: float = sz.y * 0.5 - ch * 0.5 - 6.0
	var rail_y: float = y0 + ch + 30.0
	canvas.draw_line(Vector2(0, rail_y), Vector2(sz.x, rail_y), Color(Pal.BRASS, 0.8), 4.0)
	for i in range(0, int(sz.x / 28.0) + 1):
		canvas.draw_line(Vector2(i * 28.0, rail_y + 2), Vector2(i * 28.0, rail_y + 12), Color(Pal.BRASS, 0.35), 3.0)
	_rects.clear()
	for i in rows.size():
		var r: Dictionary = rows[i]
		var rc := Rect2(x0 + float(i) * (cw + gap), y0, cw, ch)
		_rects.append(rc.grow_individual(gap * 0.5, 40, gap * 0.5, 60))
		var open_: bool = bool(r["unlocked"])
		var here: bool = bool(r["is_player_car"])
		if i < rows.size() - 1:
			canvas.draw_rect(Rect2(rc.end.x - 1, rc.position.y + ch * 0.62, gap + 2, 8), Pal.BRASS if open_ else Color(Pal.BRASS, 0.35))
		var body: Color = Color(Pal.PARCHMENT, 0.95) if open_ else Color(Pal.MIST, 0.18)
		if here:
			for k in 4:
				Dr.rrect(canvas, rc.grow(10.0 + k * 9.0), 20 + k * 6, Color(Pal.LAMP, 0.10 - k * 0.02 + (0.0 if Pal.reduced_motion() else sin(t * 2.0) * 0.015)))
			body = Pal.LAMP
		Dr.rrect(canvas, rc, 16, body)
		canvas.draw_rect(rc.grow(-2), Color(Pal.BRASS if open_ else Color(Pal.MIST, 0.5)), false, 3.0)
		# roof line
		canvas.draw_line(rc.position + Vector2(10, 14), rc.position + Vector2(cw - 10, 14), Color(Pal.INK, 0.35 if open_ else 0.15), 3.0)
		# windows
		var ww: float = (cw - 36.0) / 3.0
		for k in 3:
			var wr := Rect2(rc.position.x + 12 + k * (ww + 6), rc.position.y + 28, ww, ch * 0.32)
			var wc: Color = Color(Pal.LAMP, 0.85) if open_ and not here else (Color(Pal.NIGHT, 0.9) if here else Color(Pal.DEEP, 0.7))
			if open_ and here:
				wc = Color(1.0, 0.95, 0.75, 0.95)
			Dr.rrect(canvas, wr, 6, wc)
			canvas.draw_rect(wr, Color(Pal.BRASS, 0.8 if open_ else 0.3), false, 2.0)
		# door
		canvas.draw_rect(Rect2(rc.end.x - 26, rc.position.y + ch * 0.58, 14, ch * 0.34), Color(Pal.INK, 0.45 if open_ else 0.2))
		# wheels
		for wx in [0.24, 0.76]:
			var wc2 := Vector2(rc.position.x + cw * wx, rc.end.y + 14)
			canvas.draw_circle(wc2, 15, Pal.BRASS if open_ else Color(Pal.BRASS, 0.3))
			canvas.draw_circle(wc2, 6, Pal.DEEP)
		# tokens: red dot for waiting claimants, lamp dot for items
		if open_ and int(r["claimants_waiting"]) > 0:
			canvas.draw_circle(rc.position + Vector2(cw - 18, ch - 20), 11, Pal.SIGNAL)
		if open_ and int(r["items_here"]) > 0:
			canvas.draw_circle(rc.position + Vector2(20, ch - 20), 9, Pal.BRASS)
			canvas.draw_circle(rc.position + Vector2(20, ch - 20), 4, Pal.PARCHMENT)
		if not open_:
			_padlock(rc.get_center() + Vector2(0, ch * 0.12), minf(cw * 0.3, 40.0))
		# name
		var fs: int = 21 if cw > 120.0 else 17
		var nm: String = String(r["name"])
		var col: Color = Pal.PARCHMENT if open_ else Color(Pal.PARCHMENT, 0.4)
		canvas.draw_string(font, Vector2(rc.position.x - gap * 0.5, rail_y + 52), nm, HORIZONTAL_ALIGNMENT_CENTER, cw + gap, fs, col)
		if here:
			canvas.draw_string(font, Vector2(rc.position.x - gap * 0.5, y0 - 24 - (0.0 if Pal.reduced_motion() else absf(sin(t * 2.5)) * 6.0)), "you are here", HORIZONTAL_ALIGNMENT_CENTER, cw + gap, 20, Pal.LAMP)
		if i == sel:
			var br: Rect2 = rc.grow(6)
			canvas.draw_rect(br, Pal.SIGNAL, false, 5.0)
			canvas.draw_polygon(PackedVector2Array([Vector2(rc.get_center().x - 12, rail_y + 66), Vector2(rc.get_center().x + 12, rail_y + 66), Vector2(rc.get_center().x, rail_y + 80)]), PackedColorArray([Pal.SIGNAL]))


func _padlock(c: Vector2, s: float) -> void:
	canvas.draw_arc(c + Vector2(0, -s * 0.35), s * 0.4, PI, TAU, 16, Pal.BRASS, 5.0)
	Dr.rrect(canvas, Rect2(c - Vector2(s * 0.55, s * 0.35), Vector2(s * 1.1, s * 0.9)), 6, Pal.BRASS)
	canvas.draw_circle(c + Vector2(0, s * 0.05), s * 0.12, Pal.DEEP)


## Portrait: the train runs down the panel (front car on top), top-down view, big names on the right.
func _draw_vertical() -> void:
	var sz: Vector2 = canvas.size
	var font: Font = get_theme_default_font()
	Dr.vgrad(canvas, Rect2(Vector2.ZERO, sz), Color(Pal.DEEP, 0.9), Color(Pal.NIGHT, 0.9))
	canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(Pal.BRASS, 0.5), false, 2.0)
	var n: int = maxi(rows.size(), 1)
	var m: float = 18.0
	var gap: float = 18.0
	var ch: float = minf((sz.y - m * 2.0 - gap * float(n - 1)) / float(n), 180.0)
	var cw: float = minf(sz.x * 0.38, 360.0)
	var total: float = ch * float(n) + gap * float(n - 1)
	var y0: float = (sz.y - total) / 2.0
	var x0: float = m + 24.0
	var tx: float = x0 + cw + 34.0
	_rects.clear()
	for i in rows.size():
		var r: Dictionary = rows[i]
		var rc := Rect2(x0, y0 + float(i) * (ch + gap), cw, ch)
		_rects.append(Rect2(m, rc.position.y - gap * 0.5, sz.x - m * 2.0, ch + gap))
		var open_: bool = bool(r["unlocked"])
		var here: bool = bool(r["is_player_car"])
		if i == sel:
			Dr.rrect(canvas, Rect2(m, rc.position.y - 6, sz.x - m * 2.0, ch + 12), 18, Color(Pal.PARCHMENT, 0.10))
			canvas.draw_rect(Rect2(m, rc.position.y - 6, sz.x - m * 2.0, ch + 12), Pal.SIGNAL, false, 4.0)
		if i < rows.size() - 1:
			canvas.draw_rect(Rect2(rc.get_center().x - 7, rc.end.y - 1, 14, gap + 2), Pal.BRASS if open_ else Color(Pal.BRASS, 0.35))
		var body: Color = Color(Pal.PARCHMENT, 0.95) if open_ else Color(Pal.MIST, 0.18)
		if here:
			for k in 4:
				Dr.rrect(canvas, rc.grow(8.0 + k * 8.0), 22 + k * 6, Color(Pal.LAMP, 0.10 - k * 0.02 + (0.0 if Pal.reduced_motion() else sin(t * 2.0) * 0.015)))
			body = Pal.LAMP
		# wheels poke out at the sides
		for wy in [0.2, 0.8]:
			for sx in [-1.0, 1.0]:
				var wr := Rect2(rc.get_center().x + sx * (cw * 0.5 + 2.0) - (0.0 if sx > 0.0 else 12.0), rc.position.y + ch * wy - 16, 12, 32)
				canvas.draw_rect(wr, Pal.BRASS if open_ else Color(Pal.BRASS, 0.3))
		Dr.rrect(canvas, rc, 22, body)
		canvas.draw_rect(rc.grow(-2), Pal.BRASS if open_ else Color(Pal.MIST, 0.5), false, 3.0)
		canvas.draw_line(Vector2(rc.get_center().x, rc.position.y + 12), Vector2(rc.get_center().x, rc.end.y - 12), Color(Pal.INK, 0.25 if open_ else 0.12), 3.0)
		for sx2 in [0.0, 1.0]:
			for k in 3:
				var wh: float = (ch - 36.0) / 3.0 - 8.0
				var wr2 := Rect2(rc.position.x + 14 + sx2 * (cw - 28 - 38), rc.position.y + 18 + k * (wh + 8), 38, wh)
				var wc: Color = Color(Pal.LAMP, 0.85) if open_ else Color(Pal.DEEP, 0.7)
				if here:
					wc = Color(1.0, 0.95, 0.75, 0.95) if open_ else wc
				Dr.rrect(canvas, wr2, 6, wc)
				canvas.draw_rect(wr2, Color(Pal.BRASS, 0.8 if open_ else 0.3), false, 2.0)
		if not open_:
			_padlock(rc.get_center(), minf(ch * 0.4, 44.0))
		var cy: float = rc.position.y + ch * 0.5
		var tw: float = sz.x - tx - m - 10.0
		canvas.draw_string(font, Vector2(tx, cy - 6), String(r["name"]), HORIZONTAL_ALIGNMENT_LEFT, tw, 38, Pal.PARCHMENT if open_ else Color(Pal.PARCHMENT, 0.4))
		var sub: String = ""
		var sc: Color = Pal.MIST
		if here:
			sub = "you are here"
			sc = Pal.LAMP
		elif not open_:
			sub = "Reputation %d needed" % int(r["tier_rep"])
		else:
			sub = "%d waiting · %d items" % [int(r["claimants_waiting"]), int(r["items_here"])]
		canvas.draw_string(font, Vector2(tx, cy + 34), sub, HORIZONTAL_ALIGNMENT_LEFT, tw, 26, sc)
		if open_ and int(r["claimants_waiting"]) > 0:
			canvas.draw_circle(Vector2(sz.x - m - 30, cy), 12, Pal.SIGNAL)
