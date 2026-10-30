class_name Secrets
extends RefCounted
## Tiny hidden delights: tap a control N times to trigger a whisper toast + sound.

static func on_taps(c: Control, n: int, lines: Array, sound: String = "page_flip") -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := [0, 0]  # taps, line index
	c.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			st[0] += 1
			if st[0] >= n:
				st[0] = 0
				Audio.play(sound)
				Haptics.buzz(30)
				Events.toast.emit(String(lines[st[1] % lines.size()]), "info")
				st[1] += 1)
