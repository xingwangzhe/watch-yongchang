extends Node

signal changed

const CONFIG_PATH := "user://settings.cfg"
const DEFAULT_LANGUAGE := "zh"
const LANGUAGE_CODES := ["zh", "en"]
const FPS_LIMITS := [30, 60, 90, 120, 144, 240, 0]
const DEFAULT_FPS_LIMIT := 60
# Web 单线程 WASM 下不限帧会持续跑满主线程、触发浏览器/系统降频，实测更卡。
# 锁到 60 让固定步长循环有稳定预算，低端设备也能保持可玩帧率。
const DEFAULT_FPS_LIMIT_WEB := 60
const DEFAULT_BGM_VOLUME := 0.42
const RENDERER_AUTO := "auto"
const RENDERER_VULKAN := "vulkan"
const RENDERER_OPENGL := "opengl"
const RENDERER_MODES := [RENDERER_AUTO, RENDERER_VULKAN, RENDERER_OPENGL]
const RENDERER_MIRROR_NAME := "renderer.cfg"

var config_path: String = CONFIG_PATH
var language: String = DEFAULT_LANGUAGE
var bgm_volume: float = DEFAULT_BGM_VOLUME
var sfx_volume: float = 0.78
var fullscreen: bool = false
var fps_limit: int = DEFAULT_FPS_LIMIT
var vsync: bool = true
var renderer_mode: String = RENDERER_AUTO
var vulkan_probe_override: int = -1
var web_platform_override: int = -1
var active_renderer_override: String = ""
var renderer_mirror_override: String = ""
var restart_enabled: bool = true
var bindings: Dictionary = {}
var web_capabilities: Dictionary = {
	"webgl2": true,
	"renderer": "",
	"webgpu_api": false,
}

var _config := ConfigFile.new()
var _vulkan_available := -1


func _ready() -> void:
	fps_limit = default_fps_limit()
	load_settings()
	if is_web_platform():
		renderer_mode = RENDERER_OPENGL
	_probe_web_capabilities()
	_apply_display()
	_apply_performance()
	InputSetup.ensure_defaults()
	InputSetup.apply_bindings(bindings)


func load_settings() -> void:
	if not FileAccess.file_exists(config_path):
		renderer_mode = _valid_renderer_mode(_read_renderer_mirror())
		return
	if _config.load(config_path) != OK:
		push_warning("Settings file could not be loaded: %s" % config_path)
		return
	language = _valid_language(str(_config.get_value("general", "language", language)))
	bgm_volume = clampf(float(_config.get_value("audio", "bgm_volume", bgm_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(_config.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(_config.get_value("display", "fullscreen", fullscreen))
	fps_limit = _valid_fps_limit(int(_config.get_value("display", "fps_limit", fps_limit)))
	vsync = bool(_config.get_value("display", "vsync", vsync))
	var stored_mode := str(_config.get_value("rendering", "renderer_mode", ""))
	if stored_mode.is_empty():
		stored_mode = _read_renderer_mirror()
	renderer_mode = _valid_renderer_mode(stored_mode)
	bindings = _sanitize_bindings(_config.get_value("input", "bindings", {}))


func save_settings(notify: bool = true) -> void:
	_config.set_value("general", "language", language)
	_config.set_value("audio", "bgm_volume", bgm_volume)
	_config.set_value("audio", "sfx_volume", sfx_volume)
	_config.set_value("display", "fullscreen", fullscreen)
	_config.set_value("display", "fps_limit", fps_limit)
	_config.set_value("display", "vsync", vsync)
	_config.set_value("rendering", "renderer_mode", renderer_mode)
	_config.set_value("input", "bindings", bindings)
	var error := _config.save(config_path)
	if error != OK:
		push_warning("Settings file could not be saved: %s" % config_path)
	_write_renderer_mirror()
	if notify:
		changed.emit()


func set_language(code: String) -> void:
	code = _valid_language(code)
	if language == code:
		return
	language = code
	save_settings()


func set_binding(action: String, token: String) -> void:
	if not InputSetup.BINDABLE.has(action):
		return
	if token.is_empty():
		bindings.erase(action)
	else:
		bindings[action] = [token]
	InputSetup.apply_bindings(bindings)
	save_settings()


func reset_bindings() -> void:
	bindings.clear()
	InputSetup.reset_to_defaults()
	save_settings()


func _sanitize_bindings(raw: Variant) -> Dictionary:
	var clean := {}
	if not (raw is Dictionary):
		return clean
	for action in InputSetup.ORDER:
		var tokens: Variant = (raw as Dictionary).get(action, [])
		if not (tokens is Array) or (tokens as Array).is_empty():
			continue
		var valid: Array[String] = []
		for token in tokens as Array:
			var text := str(token)
			if text.begins_with("k:") or text.begins_with("m:"):
				valid.append(text)
		if not valid.is_empty():
			clean[action] = valid
	return clean


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


func set_fps_limit(limit: int) -> void:
	var next := _valid_fps_limit(limit)
	if fps_limit == next:
		return
	fps_limit = next
	_apply_performance()
	save_settings()


func set_vsync(enabled: bool) -> void:
	if vsync == enabled:
		return
	vsync = enabled
	_apply_performance()
	save_settings()


func set_renderer_mode(mode: String) -> void:
	var next := RENDERER_OPENGL if is_web_platform() else _valid_renderer_mode(mode)
	if renderer_mode == next:
		return
	renderer_mode = next
	save_settings()


func resolved_renderer() -> String:
	if is_web_platform():
		return RENDERER_OPENGL
	match renderer_mode:
		RENDERER_OPENGL:
			return RENDERER_OPENGL
		RENDERER_VULKAN:
			return RENDERER_VULKAN if vulkan_supported() else RENDERER_OPENGL
		_:
			return RENDERER_VULKAN if vulkan_supported() else RENDERER_OPENGL


func active_renderer() -> String:
	if not active_renderer_override.is_empty():
		return active_renderer_override
	var driver := RenderingServer.get_current_rendering_driver_name().to_lower()
	if driver.contains("vulkan"):
		return RENDERER_VULKAN
	if driver.contains("opengl") or driver.contains("gles"):
		return RENDERER_OPENGL
	return ""


func is_web_platform() -> bool:
	if web_platform_override >= 0:
		return web_platform_override == 1
	return OS.has_feature("web")


func default_fps_limit() -> int:
	return DEFAULT_FPS_LIMIT_WEB if is_web_platform() else DEFAULT_FPS_LIMIT


func renderer_modes_for_ui() -> Array:
	if is_web_platform():
		return [RENDERER_OPENGL, RENDERER_VULKAN]
	return RENDERER_MODES.duplicate()


func vulkan_supported() -> bool:
	if is_web_platform():
		return false
	if vulkan_probe_override >= 0:
		return vulkan_probe_override == 1
	if _vulkan_available >= 0:
		return _vulkan_available == 1
	_vulkan_available = 1 if _probe_vulkan() else 0
	return _vulkan_available == 1


func webgl_supported() -> bool:
	return bool(web_capabilities.get("webgl2", true))


func webgl_renderer() -> String:
	return str(web_capabilities.get("renderer", ""))


func webgpu_api_available() -> bool:
	return bool(web_capabilities.get("webgpu_api", false))


func _probe_web_capabilities() -> void:
	if not OS.has_feature("web"):
		return
	var raw := str(JavaScriptBridge.eval("""
(() => {
  const caps = { webgl2: false, renderer: "", webgpu_api: !!navigator.gpu };
  try {
    const canvas = document.createElement("canvas");
    const gl = canvas.getContext("webgl2");
    caps.webgl2 = !!gl;
    if (gl) {
      const debug = gl.getExtension("WEBGL_debug_renderer_info");
      caps.renderer = debug ? String(gl.getParameter(debug.UNMASKED_RENDERER_WEBGL)) : "";
    }
  } catch (error) {
    caps.renderer = String(error);
  }
  return JSON.stringify(caps);
})()
""", true))
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		web_capabilities.merge(parsed, true)


func reset_vulkan_probe() -> void:
	_vulkan_available = -1


func renderer_mirror_path() -> String:
	if not renderer_mirror_override.is_empty():
		return renderer_mirror_override
	match OS.get_name():
		"Windows":
			var appdata := OS.get_environment("APPDATA")
			if appdata.is_empty():
				appdata = OS.get_environment("USERPROFILE").path_join("AppData/Roaming")
			return appdata.path_join("WatchYongchang").path_join(RENDERER_MIRROR_NAME)
		"macOS":
			return OS.get_environment("HOME").path_join(
				"Library/Application Support/WatchYongchang"
			).path_join(RENDERER_MIRROR_NAME)
		_:
			var config_home := OS.get_environment("XDG_CONFIG_HOME")
			if config_home.is_empty():
				config_home = OS.get_environment("HOME").path_join(".config")
			return config_home.path_join("watch-yongchang").path_join(RENDERER_MIRROR_NAME)


func renderer_requires_restart() -> bool:
	if is_web_platform():
		return false
	return resolved_renderer() != active_renderer()


func renderer_restart_args() -> PackedStringArray:
	var target := resolved_renderer()
	var args := PackedStringArray()
	if OS.has_feature("editor"):
		args.append("--path")
		args.append(ProjectSettings.globalize_path("res://"))
	args.append("--rendering-method")
	args.append("forward_plus" if target == RENDERER_VULKAN else "gl_compatibility")
	args.append("--rendering-driver")
	args.append("vulkan" if target == RENDERER_VULKAN else "opengl3")
	return args


func restart_with_renderer() -> bool:
	if is_web_platform() or not restart_enabled:
		return false
	var pid := OS.create_process(OS.get_executable_path(), renderer_restart_args())
	if pid <= 0:
		push_error("Could not start a new process for the selected renderer.")
		return false
	get_tree().quit()
	return true


func to_dict() -> Dictionary:
	return {
		"language": language,
		"bgm_volume": bgm_volume,
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen,
		"fps_limit": fps_limit,
		"vsync": vsync,
		"renderer_mode": renderer_mode,
	}


func _valid_language(code: String) -> String:
	var normalized := code.to_lower()
	if normalized.begins_with("en"):
		return "en"
	return DEFAULT_LANGUAGE


func _valid_fps_limit(limit: int) -> int:
	return limit if FPS_LIMITS.has(limit) else DEFAULT_FPS_LIMIT


func _valid_renderer_mode(mode: String) -> String:
	var normalized := mode.to_lower()
	return normalized if RENDERER_MODES.has(normalized) else RENDERER_AUTO


func _write_renderer_mirror() -> void:
	var path := renderer_mirror_path()
	var directory := path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Renderer mirror could not be saved: %s" % path)
		return
	file.store_line("renderer_mode=\"%s\"" % renderer_mode)


func _read_renderer_mirror() -> String:
	var path := renderer_mirror_path()
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	for line in file.get_as_text().split("\n"):
		var trimmed := line.strip_edges()
		if not trimmed.begins_with("renderer_mode="):
			continue
		var parts := trimmed.split("=", true, 1)
		if parts.size() == 2:
			return str(parts[1]).strip_edges().replace("\"", "")
	return ""


func _probe_vulkan() -> bool:
	if active_renderer() == RENDERER_VULKAN:
		return true
	match OS.get_name():
		"Windows":
			return _windows_vulkan_available()
		"Linux":
			return _probe_vulkaninfo() or _has_linux_vulkan_device()
		"Web", "Android", "iOS":
			return false
		_:
			return _probe_vulkaninfo()


func _probe_vulkaninfo() -> bool:
	var output: Array = []
	var exit_code := OS.execute(
		"vulkaninfo",
		PackedStringArray(["--summary"]),
		output,
		true
	)
	if exit_code == 0:
		var summary := ""
		for line in output:
			summary += str(line) + "\n"
		return summary.contains("Devices:") and summary.contains("deviceName")
	return false


func _windows_vulkan_available() -> bool:
	var windows_root := OS.get_environment("SystemRoot")
	if windows_root.is_empty():
		windows_root = OS.get_environment("WINDIR")
	if windows_root.is_empty():
		windows_root = "C:/Windows"
	for directory in ["System32", "SysWOW64"]:
		if FileAccess.file_exists(windows_root.path_join(directory).path_join("vulkan-1.dll")):
			return true
	return FileAccess.file_exists("C:/Windows/System32/vulkan-1.dll")


func _has_linux_vulkan_device() -> bool:
	var has_icd := false
	for directory in [
		"/usr/share/vulkan/icd.d",
		"/usr/local/share/vulkan/icd.d",
		"/etc/vulkan/icd.d",
	]:
		if not DirAccess.dir_exists_absolute(directory):
			continue
		for file in DirAccess.get_files_at(directory):
			if file.ends_with(".json"):
				has_icd = true
				break
		if has_icd:
			break
	if not has_icd or not DirAccess.dir_exists_absolute("/dev/dri"):
		return false
	for device in DirAccess.get_files_at("/dev/dri"):
		if device.begins_with("renderD"):
			return true
	return false


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


func _apply_performance() -> void:
	Engine.max_fps = fps_limit
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)
