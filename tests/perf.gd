extends SceneTree
## A6.4 perf probe: godot --headless --script tests/perf.gd
## Fills the train to ~40 passengers and measures Sim.tick(1/60) like a 60 fps frame.
## Fails if the mean frame cost is >= 1 ms or the worst 1% >= 4 ms.
func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	await process_frame
	var sim: Node = root.get_node("Sim")
	sim.frozen = true
	sim.autosave = false
	sim.save_path = "user://perf_save_v2.json"
	sim.new_game(4)
	sim.skip_tutorial()
	for c in sim._cars:
		c["unlocked"] = true
	for _r in range(10):
		for cid in sim.CAR_IDS:
			if sim.get_passengers().size() < 40:
				sim._amb_ref().spawn_ambient(String(cid))
	var n: int = sim.get_passengers().size()
	var samples: Array = []
	for i in range(6000):
		var t0: int = Time.get_ticks_usec()
		sim.tick(1.0 / 60.0)
		samples.append(Time.get_ticks_usec() - t0)
		if i % 1500 == 1499:
			sim.apply_offline(720.0)  # keep the population churning
	samples.sort()
	var sum: float = 0.0
	for v in samples:
		sum += float(v)
	var mean_us: float = sum / samples.size()
	var p99: int = int(samples[int(samples.size() * 0.99)])
	print("perf: %d passengers, mean %.0f us/frame, p99 %d us, max %d us" % [n, mean_us, p99, int(samples[samples.size() - 1])])
	var bad: bool = mean_us >= 1000.0 or p99 >= 4000
	if bad:
		printerr("PERF FAIL: tick too slow")
	quit(1 if bad else 0)
