extends Control
## Root: backdrop + current screen + bottom tab bar + owner-visit overlay. Screens load by path; missing ones show a placeholder.
const TABS := [
	["Counter", "res://scenes/counter.tscn"],
	["Shelf", "res://scenes/shelf.tscn"],
	["Catalog", "res://scenes/catalog.tscn"],
	["Daily", "res://scenes/daily.tscn"],
]
const OWNER_VISIT := "res://scenes/owner_visit.tscn"
var backdrop: Backdrop
var holder: Control
var tabbar: UTabBar
var current: Control
var current_idx := -1
var overlay: Control
var _busy := false

func _ready() -> void:
	theme = load("res://ui/theme/unclaimed_theme.tres")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop = Backdrop.new()
	add_child(backdrop)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	var top_pad := Control.new()
	top_pad.custom_minimum_size = Vector2(0, _top_inset())
	col.add_child(top_pad)
	holder = Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.clip_contents = true
	col.add_child(holder)
	tabbar = UTabBar.new()
	col.add_child(tabbar)
	tabbar.setup(TABS.map(func(t): return t[0]))
	tabbar.tab_selected.connect(go_to)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	Events.owner_arrived.connect(_on_owner_arrived)
	go_to(0, false)

func _top_inset() -> float:
	var safe := DisplayServer.get_display_safe_area()
	return maxf(0.0, float(safe.position.y))

func _make_screen(path: String, label: String) -> Control:
	if ResourceLoader.exists(path):
		var inst = load(path).instantiate()
		if inst is Control:
			return inst
	var c := CenterContainer.new()
	var p := UPanel.new()
	var l := Label.new()
	l.text = "%s\nComing soon" % label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	c.add_child(p)
	return c

func go_to(i: int, animate: bool = true) -> void:
	if i == current_idx or _busy:
		return
	_busy = true
	var dir := 1.0 if i > current_idx else -1.0
	var next := _make_screen(TABS[i][1], TABS[i][0])
	next.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(next)
	backdrop.set_scroll(float(i) / (TABS.size() - 1))
	var old := current
	current = next
	current_idx = i
	tabbar.select(i, false)
	if animate and not Pal.reduced_motion() and old:
		var w := holder.size.x
		next.position.x = w * dir
		next.modulate.a = 0.0
		var t := create_tween().set_parallel(true)
		t.tween_property(next, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(next, "modulate:a", 1.0, 0.3)
		t.tween_property(old, "position:x", -w * dir * 0.4, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(old, "modulate:a", 0.0, 0.25)
		await t.finished
	if old:
		old.queue_free()
	_busy = false

func _on_owner_arrived(owner: Dictionary, wanted_item_id: String) -> void:
	if overlay.get_child_count() > 0 or not ResourceLoader.exists(OWNER_VISIT):
		return
	var v = load(OWNER_VISIT).instantiate()
	overlay.add_child(v)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if v.has_method("setup"):
		v.setup(owner, wanted_item_id)
	v.tree_exited.connect(func(): overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE)
