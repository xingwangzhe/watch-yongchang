extends Node

const MENU_BGM_PATH := "res://assets/audio/bgm_watch.ogg"
const BATTLE_BGM_PATH := "res://assets/audio/bgm_battle.ogg"
const UI_CLICK_STREAM := preload("res://assets/audio/ui_click.ogg")
const UI_CONFIRM_STREAM := preload("res://assets/audio/ui_confirm.ogg")
const UI_BACK_STREAM := preload("res://assets/audio/ui_back.ogg")

var player: AudioStreamPlayer
var stream: AudioStream
var menu_stream: AudioStream
var battle_stream: AudioStream
var menu_enabled := true
var current_bgm := "menu"
var _ui_players: Array[AudioStreamPlayer] = []
var _ui_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_stream = load(MENU_BGM_PATH)
	battle_stream = load(BATTLE_BGM_PATH)
	_set_loop(menu_stream)
	_set_loop(battle_stream)
	stream = menu_stream
	player = AudioStreamPlayer.new()
	player.name = "BgmPlayer"
	player.stream = stream
	player.bus = "Master"
	add_child(player)
	for i in range(4):
		var ui_player := AudioStreamPlayer.new()
		ui_player.name = "UiPlayer%d" % i
		ui_player.bus = "Master"
		add_child(ui_player)
		_ui_players.append(ui_player)
	get_tree().node_added.connect(_on_node_added)
	_bind_existing_buttons.call_deferred()
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
	_set_bgm(menu_stream, "menu")
	if DisplayServer.get_name() == "headless":
		return
	if GameSettings.bgm_volume > 0.001 and not player.playing:
		player.play()


func play_battle_bgm() -> void:
	menu_enabled = true
	_set_bgm(battle_stream, "battle")
	if DisplayServer.get_name() == "headless":
		return
	if GameSettings.bgm_volume > 0.001 and not player.playing:
		player.play()


func play_click() -> void:
	_play_ui(UI_CLICK_STREAM, 1.0, 0.72)


func play_confirm() -> void:
	_play_ui(UI_CONFIRM_STREAM, 1.0, 0.76)


func play_back() -> void:
	_play_ui(UI_BACK_STREAM, 0.94, 0.66)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_bind_button(node as BaseButton)


func _bind_existing_buttons() -> void:
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		if node is BaseButton:
			_bind_button(node as BaseButton)


func _bind_button(button: BaseButton) -> void:
	if button.has_meta("audio_click_bound"):
		return
	button.set_meta("audio_click_bound", true)
	button.pressed.connect(_on_button_pressed.bind(button))


func _on_button_pressed(button: BaseButton) -> void:
	var key := button.name.to_lower()
	if key.contains("back") or key.contains("close"):
		play_back()
	else:
		play_click()


func _play_ui(ui_stream: AudioStream, pitch: float, volume_scale: float) -> void:
	if ui_stream == null or DisplayServer.get_name() == "headless" or _ui_players.is_empty():
		return
	var ui_player := _ui_players[_ui_index]
	_ui_index = (_ui_index + 1) % _ui_players.size()
	var volume := clampf(GameSettings.sfx_volume * volume_scale, 0.0, 1.0)
	ui_player.stream = ui_stream
	ui_player.pitch_scale = pitch
	ui_player.volume_db = -80.0 if volume <= 0.001 else linear_to_db(volume)
	ui_player.play()


func _set_bgm(next_stream: AudioStream, tag: String) -> void:
	if next_stream == null:
		return
	current_bgm = tag
	if player.stream == next_stream:
		return
	var was_playing := player.playing
	player.stop()
	player.stream = next_stream
	stream = next_stream
	if was_playing:
		player.play()


func _set_loop(bgm_stream: AudioStream) -> void:
	if bgm_stream is AudioStreamOggVorbis:
		(bgm_stream as AudioStreamOggVorbis).loop = true


func _sync_volume() -> void:
	var volume := clampf(GameSettings.bgm_volume, 0.0, 1.0)
	player.volume_db = -80.0 if volume <= 0.001 else linear_to_db(volume)
	if DisplayServer.get_name() == "headless" or not menu_enabled:
		return
	if volume > 0.001 and not player.playing:
		player.play()
