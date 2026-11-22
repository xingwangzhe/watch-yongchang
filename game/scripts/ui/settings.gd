extends Control
## 设置界面：BGM/SFX 音量分离调节，实时试听，返回时自动持久化。

const BackgroundArt = preload("res://scripts/ui/background_art.gd")
const FONT_PATH := "res://assets/fonts/LXGWWenKai-Regular.ttf"

const C_INK := Color(0.86, 0.83, 0.72)
const C_GOLD := Color(0.82, 0.70, 0.40)
const C_RED := Color(0.62, 0.24, 0.20)
const C_BTN := Color(0.16, 0.22, 0.24, 0.92)
const C_BTN_HOVER := Color(0.26, 0.34, 0.34, 0.98)

var _font: Font
var _bgm_slider: HSlider
var _sfx_slider: HSlider
var _bgm_value: Label
var _sfx_value: Label

func _ready() -> void:
	_font = load(FONT_PATH) as Font
	_build_ui()
	print("[SETTINGS] ready bgm=%.2f sfx=%.2f" % [AudioManager.get_bgm_volume(), AudioManager.get_sfx_volume()])

func _build_ui() -> void:
	var bg := Control.new()
	bg.name = "BackgroundArt"
	bg.set_script(BackgroundArt)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 半透明遮罩，提升文字可读性
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.07, 0.08, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340.0
	panel.offset_top = -260.0
	panel.offset_right = 340.0
	panel.offset_bottom = 250.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.13, 0.14, 0.97)
	sb.set_border_width_all(2)
	sb.border_color = C_GOLD
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var h := Label.new()
	h.text = "设 置"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", _font)
	h.add_theme_font_size_override("font_size", 38)
	h.add_theme_color_override("font_color", C_GOLD)
	vbox.add_child(h)

	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", _make_line())
	vbox.add_child(divider)

	# BGM 音量
	_bgm_value = Label.new()
	vbox.add_child(_bgm_value)
	_bgm_slider = _add_slider(vbox, AudioManager.get_bgm_volume())
	_bgm_slider.value_changed.connect(_on_bgm_changed)
	_on_bgm_changed(_bgm_slider.value)

	# SFX 音量
	_sfx_value = Label.new()
	vbox.add_child(_sfx_value)
	_sfx_slider = _add_slider(vbox, AudioManager.get_sfx_volume())
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_on_sfx_changed(_sfx_slider.value)

	# 试听按钮
	var preview := Button.new()
	preview.text = "试听音效"
	preview.custom_minimum_size = Vector2(0, 48)
	preview.add_theme_font_override("font", _font)
	preview.add_theme_font_size_override("font_size", 21)
	preview.add_theme_stylebox_override("normal", _make_style(C_BTN, C_GOLD))
	preview.add_theme_stylebox_override("hover", _make_style(C_BTN_HOVER, C_RED))
	preview.pressed.connect(func(): AudioManager.play_sfx(&"wave"))
	vbox.add_child(preview)

	var back := Button.new()
	back.text = "返 回"
	back.custom_minimum_size = Vector2(0, 52)
	back.add_theme_font_override("font", _font)
	back.add_theme_font_size_override("font_size", 24)
	back.add_theme_stylebox_override("normal", _make_style(C_BTN, C_RED))
	back.add_theme_stylebox_override("hover", _make_style(C_BTN_HOVER, C_GOLD))
	back.pressed.connect(_on_back)
	vbox.add_child(back)
	back.grab_focus()

func _add_slider(parent: Node, initial: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(0, 34)
	parent.add_child(slider)
	return slider

func _on_bgm_changed(v: float) -> void:
	AudioManager.set_bgm_volume(v)
	_bgm_value.text = "背景音乐  %d%%" % int(v * 100.0)
	_bgm_value.add_theme_font_override("font", _font)
	_bgm_value.add_theme_font_size_override("font_size", 22)
	_bgm_value.add_theme_color_override("font_color", C_INK)

func _on_sfx_changed(v: float) -> void:
	AudioManager.set_sfx_volume(v)
	_sfx_value.text = "音效音量  %d%%" % int(v * 100.0)
	_sfx_value.add_theme_font_override("font", _font)
	_sfx_value.add_theme_font_size_override("font_size", 22)
	_sfx_value.add_theme_color_override("font_color", C_INK)

func _on_back() -> void:
	AudioManager.save_settings()
	GameFlow.return_from_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		AudioManager.save_settings()

func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb

func _make_line() -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = C_GOLD
	line.thickness = 2
	return line
