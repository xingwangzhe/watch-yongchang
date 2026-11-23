extends Node

signal changed

const CONFIG_PATH := "user://settings.cfg"
const DEFAULT_LANGUAGE := "zh"
const LANGUAGE_CODES := ["zh", "en"]

var config_path: String = CONFIG_PATH
var language: String = DEFAULT_LANGUAGE
var bgm_volume: float = 0.62
var sfx_volume: float = 0.78
var fullscreen: bool = false

var _config := ConfigFile.new()


func _ready() -> void:
	load_settings()
	_apply_display()


func load_settings() -> void:
	if not FileAccess.file_exists(config_path):
		return
	if _config.load(config_path) != OK:
		push_warning("Settings file could not be loaded: %s" % config_path)
		return
	language = _valid_language(str(_config.get_value("general", "language", language)))
	bgm_volume = clampf(float(_config.get_value("audio", "bgm_volume", bgm_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(_config.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(_config.get_value("display", "fullscreen", fullscreen))


func save_settings(notify: bool = true) -> void:
	_config.set_value("general", "language", language)
	_config.set_value("audio", "bgm_volume", bgm_volume)
	_config.set_value("audio", "sfx_volume", sfx_volume)
	_config.set_value("display", "fullscreen", fullscreen)
	var error := _config.save(config_path)
	if error != OK:
		push_warning("Settings file could not be saved: %s" % config_path)
	if notify:
		changed.emit()


func set_language(code: String) -> void:
	code = _valid_language(code)
	if language == code:
		return
	language = code
	save_settings()


func set_bgm_volume(value: float, persist: bool = true) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(bgm_volume, next):
		return
	bgm_volume = next
	if persist:
		save_settings()
	else:
		changed.emit()


func set_sfx_volume(value: float, persist: bool = true) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(sfx_volume, next):
		return
	sfx_volume = next
	if persist:
		save_settings()
	else:
		changed.emit()


func set_fullscreen(enabled: bool) -> void:
	if fullscreen == enabled:
		return
	fullscreen = enabled
	_apply_display()
	save_settings()


func to_dict() -> Dictionary:
	return {
		"language": language,
		"bgm_volume": bgm_volume,
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen,
	}


func _valid_language(code: String) -> String:
	var normalized := code.to_lower()
	if normalized.begins_with("en"):
		return "en"
	return DEFAULT_LANGUAGE


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	if not fullscreen:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var centered := usable.position + (usable.size - Vector2i(1280, 720)) / 2
		DisplayServer.window_set_position(centered)
