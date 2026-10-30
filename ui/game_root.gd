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
	screens.register("daily", func(_a: Dictionary) -> Control: return Daily.new(screens))
	Events.daily_completed.connect(func(_d: Dictionary) -> void:
		await get_tree().create_timer(2.5).timeout
		open_screen("daily"))
	screens.register("shop", func(_a: Dictionary) -> Control: return Shop.new(screens))
	screens.register("ledger", func(_a: Dictionary) -> Control: return Ledger.new(screens))
	get_tree().set_auto_accept_quit(false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--daily="):
			daily_demo.call_deferred(a.substr(8))
		if a.begins_with("--shop="):
			shop_demo.call_deferred(int(a.substr(7)))
		if a.begins_with("--ledger="):
			ledger_demo.call_deferred(a.substr(9))


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


## Shot helper: play the first handover so the Ledger has content, then open it on a tab.
func ledger_demo(tab: String = "history") -> void:
	if tab != "empty":
		var r: Dictionary = Sim.pick_up("car_lp_s3")
		var iid: String = String(r.get("iid", ""))
		if iid != "":
			Sim.place_on_bench(iid)
			Sim.reveal(iid, "magnifier")
			for i in 40:
				Sim.tick(1.0)
				if not Sim.get_queue().is_empty():
					break
			var q: Array = Sim.get_queue()
			if not q.is_empty():
				Sim.hand_over(iid, String(q[0]))
	var l: Control = open_screen("ledger")
	if l != null and tab != "empty":
		(l as Ledger)._show(tab)


## Shot helper: give tokens then open the shop.
func shop_demo(tokens: int = 60) -> void:
	Sim.tokens = tokens
	open_screen("shop")


## Shot helper: "fresh" shows the unstarted case, "solved" plays it to completion first.
func daily_demo(state: String = "fresh") -> void:
	if state == "solved":
		Sim.start_daily()
		var d: Dictionary = Sim.get_daily()
		var iid: String = ""
		for sp in Sim.get_spots():
			var cand: String = String(sp["item_iid"])
			if cand != "" and String(Sim.get_item(cand).get("def_id", "")) == String(d["def_id"]):
				iid = cand
				Sim.pick_up(String(sp["id"]))
		if iid != "":
			Sim.place_on_bench(iid)
			Sim.reveal(iid, "magnifier")
			for i in 120:
				Sim.tick(1.0)
				for p in Sim.get_passengers():
					if String(p.get("owner_id", "")) == String(d["owner_id"]) and String(p["kind"]) != "ambient" and (String(p["state"]) == "waiting" or String(p["state"]) == "asking"):
						Sim.hand_over(iid, String(p["pid"]))
						break
				if bool(Sim.get_daily().get("done", false)):
					break
	open_screen("daily")
