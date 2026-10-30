class_name GameRoot
extends Control
## The real game entry point. Theme + settings + audio node, the train world (which owns the HUD,
## bench and claim UI), and the overlay manager for Ledger / Shop / Daily / Welcome-back / Back Office.

var world: TrainWorld
var screens: ScreenManager


## Safe-area insets in viewport pixels (notches, gesture bars). Zero on desktop.
static func safe_insets(vp: Viewport) -> Dictionary:
	var out := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var vis: Vector2 = vp.get_visible_rect().size
	if win.x <= 0.0 or win.y <= 0.0:
		return out
	var area: Rect2i = DisplayServer.get_display_safe_area()
	if area.size.x <= 0 or area.size.y <= 0:
		return out
	var k: Vector2 = vis / win
	out["left"] = maxf(0.0, float(area.position.x)) * k.x
	out["top"] = maxf(0.0, float(area.position.y)) * k.y
	out["right"] = maxf(0.0, win.x - float(area.end.x)) * k.x
	out["bottom"] = maxf(0.0, win.y - float(area.end.y)) * k.y
	return out


func _ready() -> void:
	name = "GameRoot"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = load("res://ui/theme/unclaimed_theme.tres")
	Settings.apply_all()
	add_child(Sfx.new())
	world = (load("res://world/train_world.tscn") as PackedScene).instantiate()
	add_child(world)
	screens = ScreenManager.new()
	add_child(screens)
	get_tree().set_auto_accept_quit(false)


func open_screen(screen_name: String, args: Dictionary = {}) -> Control:
	return screens.open(screen_name, args)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not screens.close_top():
			if world != null and world.bench != null and world.bench.is_open:
				world.bench.close()
			elif world != null and world.hud != null and world.hud.sheet.visible:
				world.hud.toggle_sheet()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Sim.save_game()
		get_tree().quit()
