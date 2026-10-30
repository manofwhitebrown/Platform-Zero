class_name Ledger
extends Control
## Ledger overlay: History / Regulars / Collection / Lore. Opened from the HUD book button.

var mgr: ScreenManager
var _tab: String = "history"
var _body: VBoxContainer
var _tabs: Dictionary = {}


class ArtBox extends Control:
	var item: Dictionary = {}
	var dim: bool = false
	func _draw() -> void:
		if item.is_empty():
			return
		var m: float = minf(size.x, size.y)
		var r := Rect2((size - Vector2(m, m)) / 2.0, Vector2(m, m))
		ItemArt.draw(self, item, r, {"finish": m > 90})
		if dim:
			var ic: Texture2D = ItemArt.icon_tex(item)
			if ic != null:
				draw_texture_rect(ic, r, false, Color(Pal.DEEP, 0.75))


static func _lbl(text: String, sz: int, col: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _init(p_mgr: ScreenManager = null) -> void:
	mgr = p_mgr


func _ready() -> void:
	theme = load("res://ui/theme/unclaimed_theme.tres")
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Pal.panel_style(Pal.NIGHT, Pal.BRASS))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var t := _lbl("The Ledger", 52, Pal.LAMP)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := UButton.new()
	x.text = "Close"
	x.custom_minimum_size = Vector2(190, 100)
	x.pressed.connect(func() -> void: mgr.close_top())
	head.add_child(x)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for k in [["history", "History"], ["regulars", "Regulars"], ["collection", "Found"], ["lore", "Lore"]]:
		var b := UButton.new()
		b.text = String(k[1])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = String(k[0])
		b.pressed.connect(func() -> void: _show(id))
		row.add_child(b)
		_tabs[id] = b
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	sc.add_child(_body)
	_show(_tab)


func _show(id: String) -> void:
	_tab = id
	for k in _tabs:
		(_tabs[k] as Button).button_pressed = (k == id)
	for c in _body.get_children():
		c.queue_free()
	match id:
		"history": _history()
		"regulars": _regulars()
		"collection": _collection()
		_: _lore()


func _card(h: float = 0.0) -> HBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Pal.panel_style(Color(Pal.PARCHMENT, 0.96), Pal.BRASS, 18))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	if h > 0.0:
		pc.custom_minimum_size = Vector2(0, h)
	pc.add_child(hb)
	_body.add_child(pc)
	return hb


func _empty(title: String, sub: String) -> void:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(0, 520)
	var a := ArtBox.new()
	a.item = {"icon": "letter", "tint": "#B8893E", "name": "empty"}
	a.custom_minimum_size = Vector2(220, 220)
	a.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	a.dim = true
	v.add_child(a)
	var l1 := _lbl(title, 42, Pal.PARCHMENT)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	var l2 := _lbl(sub, 30, Color(Pal.PARCHMENT, 0.7), true)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l2)
	_body.add_child(v)


func _history() -> void:
	var led: Dictionary = Sim.get_ledger()
	var claims: Array = (led.get("claims", []) as Array).filter(func(c: Dictionary) -> bool: return (led.get("catalog", []) as Array).has(String(c.get("def_id", ""))))
	if claims.is_empty():
		_empty("No claims yet.", "Hand a lost thing back to its owner and its story is kept here.")
		return
	for i in range(claims.size() - 1, -1, -1):
		var c: Dictionary = claims[i]
		var def: Dictionary = Content.object_by_id(String(c.get("def_id", "")))
		var hb := _card(150)
		var a := ArtBox.new()
		a.item = def
		a.custom_minimum_size = Vector2(120, 120)
		hb.add_child(a)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_lbl("%s: %s" % [String(c.get("name", "")), String(def.get("name", "an item"))], 32, Pal.INK, true))
		v.add_child(_lbl(String(def.get("story", c.get("line", ""))), 26, Color(Pal.INK, 0.8), true))
		hb.add_child(v)


func _regulars() -> void:
	var met: Dictionary = {}
	for g in Sim.get_ledger().get("gallery", []):
		met[String(g["owner_id"])] = int(g["deliveries"])
	for o in Content.owners:
		var oid: String = String(o.get("id", ""))
		var n: int = int(met.get(oid, 0))
		var total: int = (Content.arcs.get(oid, []) as Array).size()
		var hb := _card(190)
		var p := Portrait.new()
		p.animate = false
		p.custom_minimum_size = Vector2(120, 170)
		p.set_look(o.get("look", {}))
		if n == 0:
			p.modulate = Color(0.25, 0.25, 0.3)
		hb.add_child(p)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_lbl(String(o.get("name", "")) if n > 0 else "Someone not yet met", 34, Pal.INK, true))
		var shown: int = mini(n, total)
		v.add_child(_lbl("Returned %d time%s" % [n, "" if n == 1 else "s"] if n > 0 else "Waiting to lose something.", 26, Color(Pal.INK, 0.75)))
		var bar := ProgressBar.new()
		bar.max_value = maxi(total, 1)
		bar.value = shown
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 22)
		v.add_child(bar)
		v.add_child(_lbl("Story %d / %d" % [shown, total], 22, Color(Pal.INK, 0.6)))
		hb.add_child(v)


func _collection() -> void:
	var ids: Array = Sim.get_ledger().get("catalog", [])
	var total: int = Content._object_index.size()
	_body.add_child(_lbl("%d of %d things returned" % [ids.size(), total], 32, Pal.LAMP))
	if ids.is_empty():
		_empty("Nothing found yet.", "Every item you reunite with its owner is shelved here.")
		return
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_body.add_child(grid)
	for id in ids:
		var def: Dictionary = Content.object_by_id(String(id))
		if def.is_empty():
			continue
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var a := ArtBox.new()
		a.item = def
		a.custom_minimum_size = Vector2(0, 170)
		v.add_child(a)
		var rar: String = String(def.get("rarity", "common"))
		v.add_child(_lbl(String(def.get("name", "")), 22, Pal.PARCHMENT, true))
		v.add_child(_lbl(rar.capitalize(), 20, Pal.LAMP if rar != "common" else Pal.MIST))
		grid.add_child(v)


func _lore() -> void:
	var tier: int = Sim.tier_for(Sim.rep)
	var scraps: Array = []
	var f := FileAccess.open("res://content/lore.json", FileAccess.READ)
	if f != null:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				if d[k] is Array:
					scraps = d[k]
		elif d is Array:
			scraps = d
	var shown: int = 0
	for s in scraps:
		if not (s is Dictionary):
			continue
		var open: bool = int(s.get("tier", 0)) <= tier
		var hb := _card(0)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_lbl(String(s.get("title", "")) if open else "A scrap you have not earned yet", 30, Pal.INK, true))
		if open:
			v.add_child(_lbl(String(s.get("text", "")), 26, Color(Pal.INK, 0.85), true))
			shown += 1
		else:
			v.add_child(_lbl("Reputation tier %d" % (int(s.get("tier", 0)) + 1), 22, Color(Pal.INK, 0.6)))
		hb.add_child(v)
	if scraps.is_empty():
		_empty("Nothing written yet.", "Scraps of the Zero Line's story will gather here.")
