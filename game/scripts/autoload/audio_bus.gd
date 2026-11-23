extends Node

const BGM_PATH := "res://assets/audio/bgm_watch.ogg"

var player: AudioStreamPlayer
var stream: AudioStream
var menu_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stream = load(BGM_PATH)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	player = AudioStreamPlayer.new()
	player.name = "BgmPlayer"
	player.stream = stream
	player.bus = "Master"
	add_child(player)
	GameSettings.changed.connect(_sync_volume)
	_sync_volume()


func restart() -> void:
	resume_bgm()


func stop_bgm() -> void:
	menu_enabled = false
	if is_instance_valid(player):
		player.stop()


func resume_bgm() -> void:
	menu_enabled = true
	if DisplayServer.get_name() == "headless":
		return
	if GameSettings.bgm_volume > 0.001 and not player.playing:
		player.play()


func _sync_volume() -> void:
	var volume := clampf(GameSettings.bgm_volume, 0.0, 1.0)
	player.volume_db = -80.0 if volume <= 0.001 else linear_to_db(volume)
	if DisplayServer.get_name() == "headless" or not menu_enabled:
		return
	if volume > 0.001 and not player.playing:
		player.play()
