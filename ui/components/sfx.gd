class_name Sfx
extends Node
## Sound + haptics. main.gd adds one Sfx node. Anywhere: Sfx.play("tap"), Sfx.buzz(30). Safe if no instance.
static var _inst: Sfx
var _streams := {}
var _hum: AudioStreamPlayer
var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	_inst = self
	for n in ["tap", "clue", "correct", "wrong", "drop"]:
		var p := "res://audio/%s.wav" % n
		if ResourceLoader.exists(p):
			_streams[n] = load(p)
	for i in 4:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_players.append(pl)
	var hp := "res://audio/hum.wav"
	if ResourceLoader.exists(hp):
		var s = load(hp)
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = s.data.size() >> 1
		_hum = AudioStreamPlayer.new()
		_hum.stream = s
		_hum.volume_db = -20.0
		add_child(_hum)
		apply_settings()

func apply_settings() -> void:
	if _hum == null:
		return
	if Settings.get_bool("sound", true):
		if not _hum.playing:
			_hum.play()
	else:
		_hum.stop()

static func play(n: String) -> void:
	if _inst == null or not Settings.get_bool("sound", true) or not _inst._streams.has(n):
		return
	var pl: AudioStreamPlayer = _inst._players[_inst._next]
	_inst._next = (_inst._next + 1) % _inst._players.size()
	pl.stream = _inst._streams[n]
	pl.play()

static func buzz(ms: int = 25) -> void:
	if Settings.get_bool("haptics", true) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
