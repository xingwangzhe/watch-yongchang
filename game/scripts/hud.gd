extends CanvasLayer
## 战斗 HUD：顶部资源栏 / 底部建造操作栏 / 波次横幅 / 事件横幅 / 暂停 / 结算。
## 全部代码构建（统一 lxwk 字体与国风配色），不使用世界坐标裸文字遮挡地图。

signal build_selected(index: int)
signal unit_spawn_requested(index: int)
signal pause_toggled()

const FONT_PATH := "res://assets/fonts/LXGWWenKai-Regular.ttf"

const C_PANEL := Color(0.07, 0.10, 0.11, 0.90)
const C_PANEL_SOLID := Color(0.07, 0.10, 0.11, 0.98)
const C_INK := Color(0.88, 0.85, 0.74)
const C_SUB := Color(0.62, 0.62, 0.54)
const C_GOLD := Color(0.84, 0.71, 0.40)
const C_RED := Color(0.66, 0.26, 0.22)
const C_GREEN := Color(0.36, 0.58, 0.44)
const C_BLUE := Color(0.34, 0.52, 0.60)
const C_BTN := Color(0.14, 0.20, 0.22, 0.96)
const C_BTN_HOVER := Color(0.24, 0.32, 0.34, 0.98)
const C_BTN_SELECTED := Color(0.36, 0.28, 0.14, 0.98)

const BUILD_LABELS: Array[String] = ["箭塔 40银", "军械坊 35银", "烽火台 30银"]
const BUILD_KEYS: Array[String] = ["Q", "E", "-"]
const UNIT_LABELS: Array[String] = ["乡勇 10银", "弓手 16银", "龙灯队 36银"]

var _font: Font
var _grain_value: Label
var _silver_value: Label
var _ammo_value: Label
var _keep_value: Label
var _wave_value: Label
var _keep_bar: ProgressBar
var _wave_toast: PanelContainer
var _wave_toast_label: Label
var _wave_toast_tween: Tween
var _event_banner: PanelContainer
var _event_banner_label: Label
var _banner_tween: Tween
var _build_buttons: Array[Button] = []
var _selected_build: int = 0
var _pause_panel: PanelContainer
var _end_panel: PanelContainer
var _end_title: Label
var _end_summary: Label

func _ready() -> void:
	_font = load(FONT_PATH) as Font
	_build_top_bar()
	_build_wave_toast()
	_build_event_banner()
	_build_build_bar()
	_build_end_panel()
	_build_pause_panel()
	set_process(true)
	EventBus.wave_started.connect(_on_wave)
	EventBus.culture_event.connect(_on_culture)
	EventBus.result_decided.connect(_on_result)
	print("[HUD] ready")

# ---------- 顶部状态栏 ----------
func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 58.0
	bar.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_GOLD, 6.0))
	add_child(bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	# 标题（小字，不遮地图）
	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 0)
	row.add_child(title_vbox)
	var title := _label("守望 · 永昌", 22, C_GOLD)
	title_vbox.add_child(title)
	var subtitle := _label("建造布防 · 众志成城", 12, C_SUB)
	title_vbox.add_child(subtitle)

	row.add_child(_vsep())

	# 波次徽章
	var wave_chip := _chip("波次", C_RED)
	_wave_value = wave_chip["value"]
	row.add_child(wave_chip["node"])

	row.add_child(_vsep())

	# 资源
	var grain := _chip("粮", C_GREEN)
	_grain_value = grain["value"]
	row.add_child(grain["node"])
	var silver := _chip("银", C_GOLD)
	_silver_value = silver["value"]
	row.add_child(silver["node"])
	var ammo := _chip("弹", C_BLUE)
	_ammo_value = ammo["value"]
	row.add_child(ammo["node"])

	# 主堡血量（数值 + 血条）
	var keep_chip := _chip("主堡", C_RED)
	_keep_value = keep_chip["value"]
	row.add_child(keep_chip["node"])
	_keep_bar = ProgressBar.new()
	_keep_bar.min_value = 0.0
	_keep_bar.max_value = 1000.0
	_keep_bar.value = 1000.0
	_keep_bar.show_percentage = false
	_keep_bar.custom_minimum_size = Vector2(110, 12)
	_keep_bar.add_theme_stylebox_override("background", _flat_style(Color(0.02, 0.03, 0.03), Color(0.30, 0.30, 0.26), 2.0))
	_keep_bar.add_theme_stylebox_override("fill", _flat_style(C_RED, C_RED, 0.0))
	var bar_holder := VBoxContainer.new()
	bar_holder.add_theme_constant_override("separation", 2)
	var keep_caption := _label("城防", 11, C_SUB)
	bar_holder.add_child(keep_caption)
	bar_holder.add_child(_keep_bar)
	row.add_child(bar_holder)

	# 右侧撑开 + 暂停提示
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var pause_hint := _label("ESC 暂停", 13, C_SUB)
	row.add_child(pause_hint)

# ---------- 波次横幅（定时淡出） ----------
func _build_wave_toast() -> void:
	_wave_toast = PanelContainer.new()
	_wave_toast.name = "WaveToast"
	_wave_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wave_toast.anchor_top = 0.0
	_wave_toast.offset_top = 74.0
	_wave_toast.offset_left = -150.0
	_wave_toast.offset_right = 150.0
	_wave_toast.add_theme_stylebox_override("panel", _panel_style(C_PANEL_SOLID, C_RED, 6.0))
	_wave_toast.visible = false
	add_child(_wave_toast)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 22)
	m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	_wave_toast.add_child(m)
	_wave_toast_label = _label("", 24, C_GOLD)
	_wave_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add_child(_wave_toast_label)

# ---------- 文化事件横幅（定时淡出） ----------
func _build_event_banner() -> void:
	_event_banner = PanelContainer.new()
	_event_banner.name = "EventBanner"
	_event_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_event_banner.anchor_top = 0.0
	_event_banner.offset_top = 126.0
	_event_banner.offset_left = -230.0
	_event_banner.offset_right = 230.0
	_event_banner.add_theme_stylebox_override("panel", _panel_style(C_PANEL_SOLID, C_GOLD, 6.0))
	_event_banner.visible = false
	add_child(_event_banner)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	_event_banner.add_child(m)
	_event_banner_label = _label("", 19, C_INK)
	_event_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add_child(_event_banner_label)

# ---------- 底部建造 / 出兵操作栏 ----------
func _build_build_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "BuildBar"
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -430.0
	bar.offset_right = 430.0
	bar.offset_top = -122.0
	bar.offset_bottom = -10.0
	bar.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_GOLD, 8.0))
	add_child(bar)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	bar.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	m.add_child(vbox)

	# 建造行
	var build_row := HBoxContainer.new()
	build_row.add_theme_constant_override("separation", 10)
	var build_caption := _label("建造", 15, C_GOLD)
	build_caption.custom_minimum_size = Vector2(46, 0)
	build_row.add_child(build_caption)
	for i in range(BUILD_LABELS.size()):
		var btn := _make_button("%s  [%s]" % [BUILD_LABELS[i], BUILD_KEYS[i]], Vector2(150, 42), _on_build_pressed(i))
		_build_buttons.append(btn)
		build_row.add_child(btn)
	vbox.add_child(build_row)

	# 出兵行
	var unit_row := HBoxContainer.new()
	unit_row.add_theme_constant_override("separation", 10)
	var unit_caption := _label("出兵", 15, C_GOLD)
	unit_caption.custom_minimum_size = Vector2(46, 0)
	unit_row.add_child(unit_caption)
	for i in range(UNIT_LABELS.size()):
		var btn := _make_button("%s  [%d]" % [UNIT_LABELS[i], i + 1], Vector2(150, 42), _on_unit_pressed(i))
		unit_row.add_child(btn)
	vbox.add_child(unit_row)

	_set_selected_build(0)

# ---------- 结算面板 ----------
func _build_end_panel() -> void:
	_end_panel = PanelContainer.new()
	_end_panel.name = "EndPanel"
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.offset_left = -200.0
	_end_panel.offset_top = -160.0
	_end_panel.offset_right = 200.0
	_end_panel.offset_bottom = 160.0
	_end_panel.add_theme_stylebox_override("panel", _panel_style(C_PANEL_SOLID, C_GOLD, 8.0))
	_end_panel.visible = false
	add_child(_end_panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 26)
	m.add_theme_constant_override("margin_right", 26)
	m.add_theme_constant_override("margin_top", 22)
	m.add_theme_constant_override("margin_bottom", 22)
	_end_panel.add_child(m)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m.add_child(vbox)

	_end_title = _label("战斗结束", 32, C_GOLD)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_end_title)
	_end_summary = _label("", 19, C_INK)
	_end_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_end_summary)
	vbox.add_child(_make_button("再守一局", Vector2(0, 48), func(): GameFlow.restart_battle()))
	vbox.add_child(_make_button("返回主菜单", Vector2(0, 48), func(): GameFlow.goto_main_menu()))

# ---------- 暂停面板 ----------
func _build_pause_panel() -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.name = "PausePanel"
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -190.0
	_pause_panel.offset_top = -230.0
	_pause_panel.offset_right = 190.0
	_pause_panel.offset_bottom = 230.0
	_pause_panel.add_theme_stylebox_override("panel", _panel_style(C_PANEL_SOLID, C_GOLD, 8.0))
	_pause_panel.visible = false
	add_child(_pause_panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 22)
	m.add_theme_constant_override("margin_bottom", 22)
	_pause_panel.add_child(m)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m.add_child(vbox)

	var h := _label("暂 停", 34, C_GOLD)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(h)
	vbox.add_child(_make_button("继续守城", Vector2(0, 52), func(): toggle_pause(false)))
	vbox.add_child(_make_button("设置", Vector2(0, 52), func(): GameFlow.goto_settings(GameFlow.SCENE_BATTLE)))
	vbox.add_child(_make_button("重开一局", Vector2(0, 52), func(): GameFlow.restart_battle()))
	vbox.add_child(_make_button("返回主菜单", Vector2(0, 52), func(): GameFlow.goto_main_menu()))

# ---------- 控件工厂 ----------
func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _flat_style(bg: Color, border: Color, border_w: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(int(border_w))
	sb.border_color = border
	return sb

func _panel_style(bg: Color, border: Color, radius: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.set_corner_radius_all(int(radius))
	sb.set_content_margin_all(0)
	return sb

func _vsep() -> Control:
	var sep := ColorRect.new()
	sep.color = Color(0.42, 0.38, 0.26, 0.5)
	sep.custom_minimum_size = Vector2(2, 30)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep

func _chip(caption: String, accent: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat_style(Color(0.03, 0.05, 0.05, 0.7), accent, 1.0))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 3)
	m.add_theme_constant_override("margin_bottom", 3)
	panel.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	m.add_child(h)
	var cap := _label(caption, 13, C_SUB)
	h.add_child(cap)
	var value := _label("0", 19, C_INK)
	h.add_child(value)
	return {"node": panel, "value": value}

func _make_button(text: String, min_size: Vector2, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", C_INK)
	btn.add_theme_color_override("font_hover_color", C_GOLD)
	btn.add_theme_stylebox_override("normal", _button_style(C_BTN, C_GOLD))
	btn.add_theme_stylebox_override("hover", _button_style(C_BTN_HOVER, C_RED))
	btn.add_theme_stylebox_override("pressed", _button_style(C_BTN_SELECTED, C_GOLD))
	btn.pressed.connect(callback)
	return btn

func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(6)
	return sb

# ---------- 交互回调 ----------
func _on_build_pressed(index: int) -> Callable:
	return func(): build_selected.emit(index)

func _on_unit_pressed(index: int) -> Callable:
	return func(): unit_spawn_requested.emit(index)

func set_selected_build(index: int) -> void:
	_selected_build = index
	_set_selected_build(index)

func _set_selected_build(index: int) -> void:
	for i in range(_build_buttons.size()):
		var btn := _build_buttons[i]
		if i == index:
			btn.add_theme_stylebox_override("normal", _button_style(C_BTN_SELECTED, C_GOLD))
			btn.add_theme_color_override("font_color", C_GOLD)
		else:
			btn.add_theme_stylebox_override("normal", _button_style(C_BTN, Color(0.32, 0.32, 0.28)))
			btn.add_theme_color_override("font_color", C_INK)

# ---------- 数据更新 ----------
func update_stats(grain: int, silver: int, ammo: int, keep: int, wave: int) -> void:
	_grain_value.text = str(grain)
	_silver_value.text = str(silver)
	_ammo_value.text = str(ammo)
	_keep_value.text = str(keep)
	_wave_value.text = "%d/3" % wave
	_keep_bar.value = float(keep)

func _on_wave(wave: int, count: int) -> void:
	_show_toast("第 %d 波来袭  ·  %d 敌" % [wave, count], C_RED)

func _show_toast(text: String, accent: Color) -> void:
	_wave_toast_label.text = text
	_wave_toast.visible = true
	_wave_toast.modulate.a = 1.0
	var sb := _panel_style(C_PANEL_SOLID, accent, 6.0)
	_wave_toast.add_theme_stylebox_override("panel", sb)
	if _wave_toast_tween != null and _wave_toast_tween.is_running():
		_wave_toast_tween.kill()
	_wave_toast_tween = create_tween()
	_wave_toast_tween.tween_interval(1.8)
	_wave_toast_tween.tween_property(_wave_toast, "modulate:a", 0.0, 0.5)
	_wave_toast_tween.tween_callback(func(): _wave_toast.visible = false)

func _on_culture(_card: StringName, desc: String) -> void:
	_event_banner_label.text = desc
	_event_banner.visible = true
	_event_banner.modulate.a = 0.0
	if _banner_tween != null and _banner_tween.is_running():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_event_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(2.5)
	_banner_tween.tween_property(_event_banner, "modulate:a", 0.0, 0.35)
	_banner_tween.tween_callback(func(): _event_banner.visible = false)

func _on_result(win: bool, reason: String) -> void:
	_end_title.text = "守住永昌" if win else "永昌失守"
	var reason_map: Dictionary = {
		"all_waves_cleared": "击退全部波次",
		"time_survived": "坚守至时限",
		"own_keep_destroyed": "城池被攻破",
		"enemy_keep_destroyed": "敌营被摧毁",
	}
	var reason_text: String = str(reason_map.get(reason, ""))
	_end_summary.text = "波次 %d/3  ·  %s  ·  击杀 %d" % [GameState.wave_index, reason_text, GameState.kills]
	_end_panel.visible = true
	var vbox := _end_panel.get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if vbox != null and vbox.get_child_count() > 2:
		var btn := vbox.get_child(2) as Button
		if btn != null:
			btn.grab_focus()

func toggle_pause(show: bool) -> void:
	if _pause_panel == null:
		return
	_pause_panel.visible = show
	get_tree().paused = show
	if show:
		pause_toggled.emit()
		var vbox := _pause_panel.get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
		if vbox != null and vbox.get_child_count() > 2:
			var btn := vbox.get_child(2) as Button
			if btn != null:
				btn.grab_focus()

func is_paused() -> bool:
	return _pause_panel != null and _pause_panel.visible
