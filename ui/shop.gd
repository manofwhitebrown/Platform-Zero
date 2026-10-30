class_name Shop
extends Control
## Shop overlay: upgrades from Sim.get_shop(), buy via Sim.buy(id). Cosmetics can be worn (Settings equip_<id>).

const KIND_ICON: Dictionary = {"porter": "bag", "bench": "jar", "lamp_oil": "lantern", "uv_lamp": "spectacles", "cosmetic": "hat"}
const ID_ICON: Dictionary = {"velvet_curtains": "scarf", "lantern_charm": "lantern", "brass_cap": "hat"}
const KIND_TINT: Dictionary = {"porter": "#7FA6A3", "bench": "#B8893E", "lamp_oil": "#F2B84B", "uv_lamp": "#8E6FD0", "cosmetic": "#C8503C"}

var mgr: ScreenManager
var _list: VBoxContainer
var _tok: Label
var _pulse_id: String = ""
var _pulse_t: float = 0.0


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
	var t := Ledger._lbl("Station Shop", 52, Pal.LAMP)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_tok = Ledger._lbl("", 40, Pal.PARCHMENT)
	_tok.custom_minimum_size = Vector2(150, 0)
	head.add_child(_tok)
	var x := UButton.new()
	x.text = "Close"
	x.custom_minimum_size = Vector2(190, 100)
	x.pressed.connect(func() -> void: mgr.close_top())
	head.add_child(x)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	sc.add_child(_list)
	_refresh()


func _process(d: float) -> void:
	_pulse_t += d


func _refresh() -> void:
	_tok.text = "%d tokens" % Sim.tokens
	for c in _list.get_children():
		c.queue_free()
	for u in Sim.get_shop():
		_row(u)


func _row(u: Dictionary) -> void:
	var id: String = String(u["id"])
	var kind: String = String(u["kind"])
	var pc := PanelContainer.new()
	var affordable: bool = bool(u["affordable"])
	pc.add_theme_stylebox_override("panel", Pal.panel_style(Color(Pal.PARCHMENT, 0.96 if (affordable or bool(u["owned"])) else 0.72), Pal.BRASS, 18))
	_list.add_child(pc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	pc.add_child(hb)
	var a := Ledger.ArtBox.new()
	a.item = {"icon": ID_ICON.get(id, KIND_ICON.get(kind, "key")), "tint": KIND_TINT.get(kind, "#B8893E"), "name": id}
	a.custom_minimum_size = Vector2(120, 120)
	hb.add_child(a)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Ledger._lbl(String(u["name"]), 34, Pal.INK, true))
	v.add_child(Ledger._lbl(String(u["desc"]), 24, Color(Pal.INK, 0.8), true))
	var mx: int = int(u["max_level"])
	var pips: String = ""
	for i in mx:
		pips += "● " if i < int(u["level"]) else "○ "
	v.add_child(Ledger._lbl(pips.strip_edges(), 28, Color(Pal.BRASS.darkened(0.2))))
	hb.add_child(v)
	var b := UButton.new()
	b.custom_minimum_size = Vector2(210, 110)
	if kind == "cosmetic" and bool(u["owned"]):
		var on: bool = Settings.get_bool("equip_" + id, false)
		b.text = "Wearing" if on else "Wear"
		b.pressed.connect(func() -> void:
			Settings.set_bool("equip_" + id, not Settings.get_bool("equip_" + id, false))
			Sfx.play("tap")
			_refresh())
	elif bool(u["maxed"]):
		b.text = "Owned"
		b.disabled = true
	else:
		b.text = "%d\n%s" % [int(u["cost"]), "Buy" if affordable else "Need more"]
		b.disabled = not affordable
		b.pressed.connect(func() -> void:
			var r: Dictionary = Sim.buy(id)
			if bool(r.get("ok", false)):
				Sfx.play("correct")
				Sfx.buzz(30)
				_refresh()
				_pop(id))
	hb.add_child(b)


func _pop(id: String) -> void:
	for c in _list.get_children():
		if c is Control:
			(c as Control).pivot_offset = (c as Control).size / 2.0
	var idx: int = 0
	for u in Sim.get_shop():
		if String(u["id"]) == id:
			break
		idx += 1
	await get_tree().process_frame
	if idx < _list.get_child_count():
		var n: Control = _list.get_child(idx) as Control
		n.pivot_offset = n.size / 2.0
		var tw := create_tween()
		tw.tween_property(n, "scale", Vector2(1.04, 1.04), 0.09)
		tw.tween_property(n, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
