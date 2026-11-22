extends Node
## 显示管理：全屏 / 窗口全屏（无边框）/ 窗口化 三种显示模式与窗口化分辨率。
##
## 自适应策略（参考 GodotPrompter godot-project-setup / responsive-ui）：
## - 拉伸模式 canvas_items + aspect expand：内容随窗口任意尺寸缩放，不留黑边
## - F11 在三种模式间循环；Alt+Enter 在窗口化与窗口全屏间切换
## - 设置持久化 user://settings.cfg 的 [display] 段，与 AudioManager 同文件

signal display_mode_changed(mode: int)

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "display"

enum DisplayMode { WINDOWED, WINDOWED_FULLSCREEN, FULLSCREEN }

const MODE_LABELS: Dictionary = {
	DisplayMode.WINDOWED: "窗口化",
	DisplayMode.WINDOWED_FULLSCREEN: "窗口全屏",
	DisplayMode.FULLSCREEN: "全屏",
}

## 窗口化分辨率档位（从基线 1280×720 起）
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var display_mode: int = DisplayMode.WINDOWED
var windowed_resolution: Vector2i = Vector2i(1280, 720)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_display_mode(false)
	print("[DISPLAY] ready mode=%s res=%dx%d" % [
		MODE_LABELS.get(display_mode, "?"),
		windowed_resolution.x, windowed_resolution.y,
	])

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			cycle_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER and event.alt_pressed:
			toggle_windowed_fullscreen()
			get_viewport().set_input_as_handled()

## 应用当前显示模式。persist=false 时仅应用不写盘（启动时用）。
func apply_display_mode(persist: bool = true) -> void:
	var window := get_window()
	match display_mode:
		DisplayMode.FULLSCREEN:
			window.mode = Window.MODE_FULLSCREEN
		DisplayMode.WINDOWED_FULLSCREEN:
			window.mode = Window.MODE_FULLSCREEN
			window.borderless = true
		_:
			window.borderless = false
			window.mode = Window.MODE_WINDOWED
			if windowed_resolution in RESOLUTIONS:
				window.size = windowed_resolution
	window.move_to_center()
	if persist:
		save_settings()
	display_mode_changed.emit(display_mode)

## 设置显示模式（幂等）。mode 取 DisplayMode 枚举值。
func set_display_mode(mode: int) -> void:
	mode = clampi(mode, 0, 2)
	if mode == display_mode:
		return
	display_mode = mode
	if mode == DisplayMode.WINDOWED_FULLSCREEN:
		borderless_follows_mode()
	apply_display_mode()

## 窗口全屏进入/退出时维护 borderless 标志。
func borderless_follows_mode() -> void:
	var window := get_window()
	window.borderless = (display_mode == DisplayMode.WINDOWED_FULLSCREEN)

## F11：三种模式循环 窗口化 → 全屏 → 窗口全屏 → 窗口化。
func cycle_mode() -> void:
	set_display_mode((display_mode + 1) % 3)

## Alt+Enter：窗口化 ↔ 窗口全屏。
func toggle_windowed_fullscreen() -> void:
	if display_mode == DisplayMode.WINDOWED:
		set_display_mode(DisplayMode.WINDOWED_FULLSCREEN)
	else:
		set_display_mode(DisplayMode.WINDOWED)

## 设置窗口化分辨率（仅窗口化模式立即改尺寸）。
func set_windowed_resolution(size: Vector2i) -> void:
	if not (size in RESOLUTIONS):
		return
	windowed_resolution = size
	if display_mode == DisplayMode.WINDOWED:
		get_window().size = size
		get_window().move_to_center()
	save_settings()

func mode_label() -> String:
	return str(MODE_LABELS.get(display_mode, "窗口化"))

func resolution_label() -> String:
	return "%d×%d" % [windowed_resolution.x, windowed_resolution.y]

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # 保留 audio 段
	cfg.set_value(SECTION, "mode", display_mode)
	cfg.set_value(SECTION, "windowed_width", windowed_resolution.x)
	cfg.set_value(SECTION, "windowed_height", windowed_resolution.y)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	display_mode = clampi(int(cfg.get_value(SECTION, "mode", display_mode)), 0, 2)
	var w := int(cfg.get_value(SECTION, "windowed_width", windowed_resolution.x))
	var h := int(cfg.get_value(SECTION, "windowed_height", windowed_resolution.y))
	var size := Vector2i(w, h)
	if size in RESOLUTIONS:
		windowed_resolution = size

func get_debug_snapshot() -> Dictionary:
	return {
		"mode": display_mode,
		"mode_label": mode_label(),
		"windowed_resolution": [windowed_resolution.x, windowed_resolution.y],
		"window_size": [get_window().size.x, get_window().size.y],
	}
