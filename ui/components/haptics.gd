class_name Haptics
extends RefCounted
## Vibration helper. Respects the "haptics" setting. Safe on desktop (no-op).

static func buzz(ms: int = 25) -> void:
	if Settings.get_bool("haptics", true) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
