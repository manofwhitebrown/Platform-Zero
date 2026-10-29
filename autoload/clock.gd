extends Node
## Time source. Everything time-based goes through here so tests can control it.

var _override: int = -1


func now() -> int:
	if _override >= 0:
		return _override
	return int(Time.get_unix_time_from_system())


## Freeze time at a unix timestamp (tests / debugging). Pass -1 to restore real time.
func set_override(unix_time: int) -> void:
	_override = unix_time


func advance(seconds: int) -> void:
	if _override < 0:
		_override = int(Time.get_unix_time_from_system())
	_override += seconds


## UTC date as "YYYY-MM-DD" for the given unix time (default: now).
func date_string(unix_time: int = -1) -> String:
	var t: int = now() if unix_time < 0 else unix_time
	return Time.get_date_string_from_unix_time(t)


## Whole days since 1970-01-01 (UTC).
@warning_ignore("integer_division")
func day_number(unix_time: int = -1) -> int:
	var t: int = now() if unix_time < 0 else unix_time
	return t / 86400


## Stable 32-bit FNV-1a hash. Same input -> same output on every platform and
## version (unlike String.hash()), so seeded content is identical for everyone.
func hash_str(s: String) -> int:
	var h: int = 2166136261
	for b in s.to_utf8_buffer():
		h = ((h ^ int(b)) * 16777619) & 0xFFFFFFFF
	return h
