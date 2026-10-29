extends Node
## Cheats STUB (A5.1 fills this in). Real password check + hash from CI later.

var _unlocked: bool = false
## tools/shoot.gd sets this so screenshot setups can call a small safe subset without the password.
var screenshot_mode: bool = false
## Cheats that screenshot runs may use before the real panel (A5.1) exists.
const SCREENSHOT_SAFE: PackedStringArray = ["trigger_first_minute", "skip_next_stop", "skip_stop"]


func is_available() -> bool: return false
func is_unlocked() -> bool: return _unlocked


func try_unlock(_pw: String) -> bool:
	return false


func list() -> Array:
	return [
		{"id": "tokens_100", "label": "+100 tokens", "category": "Economy", "kind": "button", "args": {}},
		{"id": "skip_stop", "label": "Skip to next stop", "category": "Time", "kind": "button", "args": {}},
	]


func run(id: String, _value: Variant = null) -> Dictionary:
	if not (_unlocked or (screenshot_mode and SCREENSHOT_SAFE.has(id))):
		return {"ok": false, "reason": "locked"}
	match id:
		"trigger_first_minute":
			# fresh dusk start: Platform Zero, mitten in the bin, Bram walks in at ~5 s
			Sim.new_game(Sim.seed_base)
			return {"ok": true}
		"skip_next_stop", "skip_stop":
			return Sim.skip_to_next_stop()
	return {"ok": false, "reason": "not implemented yet"}
