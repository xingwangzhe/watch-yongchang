class_name VoiceLinePlayer
extends Node

signal finished

const VOICE_DATA_PATH := "res://data/voice_lines.json"

var _audio: AudioStreamPlayer
var _timer: Timer
var _voice_data: Dictionary = {}


func _ready() -> void:
	_voice_data = GameData.load_json(VOICE_DATA_PATH)
	_audio = AudioStreamPlayer.new()
	_audio.name = "VoiceAudio"
	_audio.bus = "Master"
	add_child(_audio)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(func() -> void: finished.emit())
	add_child(_timer)


func play_line(line: Dictionary) -> float:
	stop_line()
	var line_id := str(line.get("id", ""))
	var text := GameData.loc(line, "zh") if Locale.current == "zh" else str(line.get("en", ""))
	var audio_path := ""
	var lines: Dictionary = _voice_data.get("lines", {}) as Dictionary
	if bool(_voice_data.get("audio_enabled", false)) and lines.has(line_id):
		var entry := lines[line_id] as Dictionary
		audio_path = str(entry.get("audio", ""))
		if Locale.current != "zh":
			audio_path = str(entry.get("audio_en", audio_path))
	var duration := maxf(2.2, _estimate_duration(text))
	if DisplayServer.get_name() == "headless":
		_timer.start(duration)
		return duration
	if not audio_path.is_empty() and ResourceLoader.exists(audio_path):
		var stream := load(audio_path)
		if stream is AudioStream:
			_audio.stream = stream
			_audio.play()
			duration = maxf(duration, (stream as AudioStream).get_length() + 0.25)
	_timer.start(duration)
	return duration


func stop_line() -> void:
	if is_instance_valid(_timer):
		_timer.stop()
	if is_instance_valid(_audio):
		_audio.stop()


func _exit_tree() -> void:
	stop_line()
	if is_instance_valid(_audio):
		_audio.stream = null


func line_metadata(line_id: String) -> Dictionary:
	var lines: Dictionary = _voice_data.get("lines", {}) as Dictionary
	return lines.get(line_id, {}) as Dictionary


func _estimate_duration(text: String) -> float:
	var syllables := maxf(1.0, float(text.length()))
	return syllables / 4.35
