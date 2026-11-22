extends CanvasLayer
## HUD：资源条、波次提示、文化事件横幅、终局面板与重开。

@onready var title_label: Label = $TopBar/TopMargin/TopRow/TitleLabel
@onready var wave_label: Label = $TopBar/TopMargin/TopRow/WaveLabel
@onready var grain_label: Label = $TopBar/TopMargin/TopRow/GrainLabel
@onready var silver_label: Label = $TopBar/TopMargin/TopRow/SilverLabel
@onready var ammo_label: Label = $TopBar/TopMargin/TopRow/AmmoLabel
@onready var keep_label: Label = $TopBar/TopMargin/TopRow/KeepLabel
@onready var wave_toast: Label = $WaveToast
@onready var event_banner: PanelContainer = $EventBanner
@onready var banner_text: Label = $EventBanner/BannerMargin/BannerText
@onready var end_panel: PanelContainer = $EndPanel
@onready var end_title: Label = $EndPanel/EndMargin/EndVBox/EndTitle
@onready var end_summary: Label = $EndPanel/EndMargin/EndVBox/EndSummary
@onready var restart_button: Button = $EndPanel/EndMargin/EndVBox/RestartButton

const FONT_PATH := "res://assets/fonts/LXGWWenKai-Regular.ttf"
const C_INK := Color(0.86, 0.83, 0.72)
const C_GOLD := Color(0.82, 0.70, 0.40)
const C_RED := Color(0.62, 0.24, 0.20)
const C_BTN := Color(0.16, 0.22, 0.24, 0.94)
const C_BTN_HOVER := Color(0.26, 0.34, 0.34, 0.98)

var _banner_tween: Tween
var _font: Font
var _pause_panel: PanelContainer
var _back_to_menu_button: Button

func _ready() -> void:
	_font = load(FONT_PATH) as Font
	for node in [title_label, wave_label, grain_label, silver_label, ammo_label,
			keep_label, wave_toast, banner_text, end_title, end_summary, restart_button]:
		if node != null:
			node.add_theme_font_override("font", _font)
	event_banner.visible = false
	end_panel.visible = false
	restart_button.pressed.connect(func(): GameFlow.restart_battle())
	EventBus.wave_started.connect(_on_wave)
	EventBus.culture_event.connect(_on_culture)
	EventBus.result_decided.connect(_on_result)
	_add_end_buttons()
	_build_pause_panel()

func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb

func _make_button(text: String, min_size: Vector2, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", C_INK)
	btn.add_theme_color_override("font_hover_color", C_GOLD)
	btn.add_theme_stylebox_override("normal", _make_style(C_BTN, C_GOLD))
	btn.add_theme_stylebox_override("hover", _make_style(C_BTN_HOVER, C_RED))
	btn.pressed.connect(callback)
	return btn

func _add_end_buttons() -> void:
	# 在结算面板 VBox 追加"返回主菜单"
	var vbox := end_panel.get_node_or_null("EndMargin/EndVBox") as VBoxContainer
	if vbox == null:
		return
	_back_to_menu_button = _make_button("返回主菜单", Vector2(180, 48), func(): GameFlow.goto_main_menu())
	vbox.add_child(_back_to_menu_button)

func _build_pause_panel() -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.name = "PausePanel"
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.anchor_left = 0.5
	_pause_panel.anchor_top = 0.5
	_pause_panel.anchor_right = 0.5
	_pause_panel.anchor_bottom = 0.5
	_pause_panel.offset_left = -190.0
	_pause_panel.offset_top = -230.0
	_pause_panel.offset_right = 190.0
	_pause_panel.offset_bottom = 230.0
	_pause_panel.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.11, 0.12, 0.98), C_GOLD))
	_pause_panel.visible = false
	add_child(_pause_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_pause_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var h := Label.new()
	h.text = "暂 停"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", _font)
	h.add_theme_font_size_override("font_size", 34)
	h.add_theme_color_override("font_color", C_GOLD)
	vbox.add_child(h)

	vbox.add_child(_make_button("继续守城", Vector2(0, 52), func(): toggle_pause(false)))
	vbox.add_child(_make_button("设置", Vector2(0, 52), func(): GameFlow.goto_settings(GameFlow.SCENE_BATTLE)))
	vbox.add_child(_make_button("重开一局", Vector2(0, 52), func(): GameFlow.restart_battle()))
	vbox.add_child(_make_button("返回主菜单", Vector2(0, 52), func(): GameFlow.goto_main_menu()))

func toggle_pause(show: bool) -> void:
	if _pause_panel == null:
		return
	_pause_panel.visible = show
	if show:
		var first := _pause_panel.get_node_or_null("MarginContainer/VBoxContainer")
		if first != null and first.get_child_count() > 2:
			var btn := first.get_child(2) as Button
			if btn != null:
				btn.grab_focus()
	get_tree().paused = show

func is_paused() -> bool:
	return _pause_panel != null and _pause_panel.visible

func update_stats(grain: int, silver: int, ammo: int, keep: int, wave: int) -> void:
	wave_label.text = "波次 %d/3" % wave
	grain_label.text = "粮 %d" % grain
	silver_label.text = "银 %d" % silver
	ammo_label.text = "弹 %d" % ammo
	keep_label.text = "主堡 %d" % keep
	if wave > 0:
		wave_toast.text = "第 %d 波来袭" % wave
		wave_toast.visible = true

func _on_wave(wave: int, _count: int) -> void:
	wave_toast.text = "第 %d 波来袭" % wave
	wave_toast.visible = true

func _on_culture(_card: StringName, desc: String) -> void:
	banner_text.text = desc
	event_banner.visible = true
	event_banner.modulate.a = 0.0
	if _banner_tween != null and _banner_tween.is_running():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(event_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(2.5)
	_banner_tween.tween_property(event_banner, "modulate:a", 0.0, 0.35)
	_banner_tween.tween_callback(func(): event_banner.visible = false)

func _on_result(win: bool, _reason: String) -> void:
	end_title.text = "守住永昌" if win else "永昌失守"
	end_summary.text = "波次 %d/3" % GameState.wave_index
	end_panel.visible = true
	restart_button.grab_focus()
