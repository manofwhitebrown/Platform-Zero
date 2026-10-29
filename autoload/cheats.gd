extends Node
## Cheats STUB (A5.1 fills this in). Real password check + hash from CI later.

var _unlocked: bool = false


func is_available() -> bool: return false
func is_unlocked() -> bool: return _unlocked


func try_unlock(_pw: String) -> bool:
	return false


func list() -> Array:
	return [
		{"id": "tokens_100", "label": "+100 tokens", "category": "Economy", "kind": "button", "args": {}},
		{"id": "skip_stop", "label": "Skip to next stop", "category": "Time", "kind": "button", "args": {}},
	]


func run(_id: String, _value: Variant = null) -> Dictionary:
	return {"ok": false, "reason": "stub"}
