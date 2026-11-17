extends Node

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx := 0
const POOL_SIZE := 8


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

	var sound_files := {
		"dice_roll": "res://assets/audio/dice_roll.wav",
		"piece_move": "res://assets/audio/piece_move.wav",
		"capture": "res://assets/audio/capture.wav",
		"ui_click": "res://assets/audio/ui_click.wav",
		"chat_ping": "res://assets/audio/chat_ping.wav",
		"win": "res://assets/audio/win.wav",
	}
	for key in sound_files:
		if ResourceLoader.exists(sound_files[key]):
			_streams[key] = load(sound_files[key])


func play(sfx_name: String, pitch_jitter: float = 0.06) -> void:
	if not GameState.settings.get("sfx_enabled", true):
		return
	if not _streams.has(sfx_name):
		return
	var player := _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	player.stream = _streams[sfx_name]
	var vol: float = clampf(float(GameState.settings.get("sfx_volume", 0.85)), 0.01, 1.0)
	player.volume_db = linear_to_db(vol)
	player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.play()
