class_name NarrativePlayer
extends CanvasLayer

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const INK := Color(0.025, 0.035, 0.038, 0.93)
const VERMILION := Color("#c05a41")

var _root: Control
var _panel: PanelContainer
var _speaker: Label
var _body: Label
var _source: Label
var _category: Label
var _voice: VoiceLinePlayer
var _backing: ColorRect
var _margin: MarginContainer


func _ready() -> void:
	layer = 8
	_build()
	get_viewport().size_changed.connect(_on_viewport_resized)
	visible = false
	_on_viewport_resized()


func _on_viewport_resized() -> void:
	_apply_responsive_layout(get_viewport().get_visible_rect().size, _css_view_size())


func _css_view_size() -> Vector2:
	if OS.has_feature("web"):
		var parsed: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify([window.innerWidth, window.innerHeight])", true)))
		if parsed is Array and (parsed as Array).size() >= 2:
			return Vector2(float(parsed[0]), float(parsed[1]))
	var window_size := DisplayServer.window_get_size()
	return Vector2(window_size.x, window_size.y)


func _apply_responsive_layout(view_size: Vector2, css_size: Vector2) -> void:
	if css_size.x <= 0.0 or css_size.y <= 0.0:
		return
	if css_size.x >= css_size.y:
		_backing.offset_left = 210.0
		_backing.offset_right = -210.0
		_backing.offset_top = -114.0
		_backing.offset_bottom = -20.0
		_panel.offset_left = 210.0
		_panel.offset_right = -210.0
		_panel.offset_top = -114.0
		_panel.offset_bottom = -20.0
		_speaker.add_theme_font_size_override("font_size", 16)
		_category.add_theme_font_size_override("font_size", 11)
		_source.add_theme_font_size_override("font_size", 10)
		_body.add_theme_font_size_override("font_size", 18)
		_body.custom_minimum_size.y = 38.0
		return
	var scale_x := view_size.x / css_size.x
	var scale_y := view_size.y / css_size.y
	var text_scale := minf(scale_x, scale_y)
	var portrait := css_size.y > css_size.x
	var panel_height := (132.0 if portrait else 192.0) * scale_y
	for panel in [_backing, _panel]:
		panel.offset_left = (10.0 if portrait else 18.0) * scale_x
		panel.offset_right = -(10.0 if portrait else 18.0) * scale_x
		if portrait:
			panel.anchor_top = 0.0
			panel.anchor_bottom = 0.0
			var top := maxf(_safe_top_in_css() + 8.0, css_size.y * 0.28)
			panel.offset_top = top * scale_y
			panel.offset_bottom = panel.offset_top + panel_height
		else:
			panel.anchor_top = 1.0
			panel.anchor_bottom = 1.0
			panel.offset_top = -panel_height - 10.0 * scale_y
			panel.offset_bottom = -10.0 * scale_y
	_speaker.add_theme_font_size_override("font_size", maxi(18, roundi((19.0 if portrait else 18.0) * text_scale)))
	_category.add_theme_font_size_override("font_size", maxi(14, roundi((13.0 if portrait else 11.0) * text_scale)))
	_source.add_theme_font_size_override("font_size", maxi(12, roundi((12.0 if portrait else 10.0) * text_scale)))
	_body.add_theme_font_size_override("font_size", maxi(20, roundi((20.0 if portrait else 18.0) * text_scale)))
	_body.custom_minimum_size.y = (66.0 if portrait else 52.0) * scale_y
	if portrait:
		_speaker.custom_minimum_size.x = 76.0 * scale_x
		_source.custom_minimum_size.x = 92.0 * scale_x
		_margin.add_theme_constant_override("margin_left", roundi(10.0 * scale_x))
		_margin.add_theme_constant_override("margin_right", roundi(10.0 * scale_x))
		_margin.add_theme_constant_override("margin_top", roundi(6.0 * scale_y))
		_margin.add_theme_constant_override("margin_bottom", roundi(6.0 * scale_y))
	else:
		_speaker.custom_minimum_size.x = 120.0
		_source.custom_minimum_size.x = 280.0
		_margin.add_theme_constant_override("margin_left", 20)
		_margin.add_theme_constant_override("margin_right", 20)
		_margin.add_theme_constant_override("margin_top", 12)
		_margin.add_theme_constant_override("margin_bottom", 10)


func _safe_top_in_css() -> float:
	if not OS.has_feature("web"):
		return 0.0
	var raw: Variant = JavaScriptBridge.eval(
		"""(() => { const e=document.createElement('div'); e.style.cssText='position:fixed;inset:0;visibility:hidden;padding-top:env(safe-area-inset-top)'; document.body.appendChild(e); const n=parseFloat(getComputedStyle(e).paddingTop)||0; e.remove(); return n; })()""",
		true
	)
	return maxf(0.0, float(raw))


func show_line(line: Dictionary) -> void:
	visible = true
	_speaker.text = _speaker_name(line)
	_body.text = GameData.loc(line, "zh") if Locale.current == "zh" else str(line.get("en", ""))
	_category.text = str(line.get("category", "演绎"))
	_category.add_theme_color_override(
		"font_color",
		GOLD if _category.text == "史实" else VERMILION
	)
	_source.text = GameData.source_label(line)
	_voice.play_line(line)


func clear_line() -> void:
	visible = false
	_voice.stop_line()


func _build() -> void:
	_root = Control.new()
	_root.name = "NarrativeRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# 不透明底板：阻断半透明字幕面板下的 HUD 文字透视，避免重影。
	_backing = ColorRect.new()
	_backing.name = "SubtitleOpaqueBacking"
	_backing.color = Color("#0d1213")
	_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backing.anchor_left = 0.0
	_backing.anchor_right = 1.0
	_backing.anchor_top = 1.0
	_backing.anchor_bottom = 1.0
	_backing.offset_left = 210.0
	_backing.offset_right = -210.0
	_backing.offset_top = -114.0
	_backing.offset_bottom = -20.0
	_root.add_child(_backing)

	_panel = PanelContainer.new()
	_panel.name = "SubtitlePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 底部字幕条：锚定底边，宽 860、高 94（原 940×146，去掉冗余提示行）。
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 210.0
	_panel.offset_right = -210.0
	_panel.offset_top = -114.0
	_panel.offset_bottom = -20.0
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	_margin = margin
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	column.add_child(heading)
	_speaker = _label("", 16, GOLD)
	_speaker.custom_minimum_size = Vector2(120.0, 0.0)
	heading.add_child(_speaker)
	_category = _label("", 11, VERMILION)
	heading.add_child(_category)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	_source = _label("", 10, Color(MUTED, 0.70))
	_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_source.clip_text = true
	_source.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_source.custom_minimum_size = Vector2(280.0, 0.0)
	heading.add_child(_source)

	_body = _label("", 18, PAPER)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(0.0, 38.0)
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	column.add_child(_body)

	_voice = VoiceLinePlayer.new()
	_voice.name = "VoiceLinePlayer"
	add_child(_voice)


func _speaker_name(line: Dictionary) -> String:
	var speaker_key := "speaker_%s" % Locale.current
	return str(line.get(speaker_key, line.get("speaker_zh", "")))


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = INK
	box.border_color = Color(GOLD, 0.34)
	box.border_width_left = 2
	box.border_width_top = 1
	box.border_width_right = 2
	box.border_width_bottom = 1
	box.corner_radius_top_left = 3
	box.corner_radius_top_right = 3
	box.corner_radius_bottom_left = 3
	box.corner_radius_bottom_right = 3
	return box
