class_name ScreenManager
extends CanvasLayer
## Overlay stack for Ledger, Shop, Daily, Welcome-back, Back Office. Register builders by name,
## open(name) pushes, close_top() pops (Android back button). Content sits inside the safe area.

signal changed

var _builders: Dictionary = {}
var _stack: Array = []
var _dim: ColorRect
var _holder: MarginContainer


func _ready() -> void:
	layer = 30
	_dim = ColorRect.new()
	_dim.color = Color(Pal.DEEP, 0.82)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	add_child(_dim)
	_holder = MarginContainer.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	apply_insets()
	get_viewport().size_changed.connect(apply_insets)


func register(screen_name: String, builder: Callable) -> void:
	_builders[screen_name] = builder


func has_screen(screen_name: String) -> bool:
	return _builders.has(screen_name)


func is_open() -> bool:
	return not _stack.is_empty()


func has_open(screen_name: String) -> bool:
	for c in _stack:
		if is_instance_valid(c) and (c as Control).name == screen_name:
			return true
	return false


func apply_insets() -> void:
	var ins: Dictionary = GameRoot.safe_insets(get_viewport())
	_holder.add_theme_constant_override("margin_left", int(ins["left"]))
	_holder.add_theme_constant_override("margin_right", int(ins["right"]))
	_holder.add_theme_constant_override("margin_top", int(ins["top"]))
	_holder.add_theme_constant_override("margin_bottom", int(ins["bottom"]))


func open(screen_name: String, args: Dictionary = {}) -> Control:
	if not _builders.has(screen_name):
		return null
	var c: Control = (_builders[screen_name] as Callable).call(args)
	if c == null:
		return null
	c.name = screen_name
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(c)
	_stack.append(c)
	_sync()
	return c


func close_top() -> bool:
	if _stack.is_empty():
		return false
	var c: Control = _stack.pop_back()
	if is_instance_valid(c):
		c.queue_free()
	_sync()
	return true


func close_all() -> void:
	while close_top():
		pass


func _sync() -> void:
	for i in _stack.size():
		(_stack[i] as Control).visible = (i == _stack.size() - 1)
	_dim.visible = not _stack.is_empty()
	changed.emit()
