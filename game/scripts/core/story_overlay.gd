class_name StoryOverlay
extends Control

signal finished

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.webp")
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const VERMILION := Color("#c05a41")

var _lines: Array[Dictionary] = []
var _index := 0
var _speaker: Label
var _body: Label
var _source: Label
var _category: Label
var _progress: Label
var _next: Button
var _skip: Button
var _voice: VoiceLinePlayer
var _panel: PanelContainer
var _subtitle_bg: ColorRect
var _bottom_fade: TextureRect
var _margin: MarginContainer
var _heading: Label
var _hint: Label


func _ready() -> void:
	name = "StoryOverlay"
	z_index = 40
	# 轻量过场：不拦截整屏鼠标，仅字幕面板接收点击，战场区域输入照常透传。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	visible = false


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
		_bottom_fade.offset_top = -224.0
		_subtitle_bg.offset_left = 210.0
		_subtitle_bg.offset_right = -210.0
		_subtitle_bg.offset_top = -180.0
		_subtitle_bg.offset_bottom = -20.0
		_panel.offset_left = 210.0
		_panel.offset_right = -210.0
		_panel.offset_top = -180.0
		_panel.offset_bottom = -20.0
		_heading.add_theme_font_size_override("font_size", 12)
		_category.add_theme_font_size_override("font_size", 10)
		_source.add_theme_font_size_override("font_size", 9)
		_speaker.add_theme_font_size_override("font_size", 16)
		_body.add_theme_font_size_override("font_size", 18)
		_body.custom_minimum_size.y = 32.0
		_progress.add_theme_font_size_override("font_size", 10)
		_hint.add_theme_font_size_override("font_size", 10)
		for button in [_skip, _next]:
			button.custom_minimum_size = Vector2(88.0, 28.0)
			button.add_theme_font_size_override("font_size", 12)
		_margin.add_theme_constant_override("margin_left", 20)
		_margin.add_theme_constant_override("margin_right", 20)
		_margin.add_theme_constant_override("margin_top", 18)
		_margin.add_theme_constant_override("margin_bottom", 8)
		return
	var scale_x := view_size.x / css_size.x
	var scale_y := view_size.y / css_size.y
	var text_scale := minf(scale_x, scale_y)
	# Keep the narrative card above the touch-control deck; the lower fifth is reserved
	# for joystick and action buttons. On short landscape screens retain bottom captions.
	var portrait := css_size.y > css_size.x
	var panel_height := (176.0 if portrait else 176.0) * scale_y
	_bottom_fade.offset_top = -(panel_height + 24.0 * scale_y) if portrait else -260.0 * scale_y
	for panel in [_subtitle_bg, _panel]:
		panel.offset_left = (12.0 if portrait else 18.0) * scale_x
		panel.offset_right = -(12.0 if portrait else 18.0) * scale_x
		if portrait:
			panel.anchor_top = 0.0
			panel.anchor_bottom = 0.0
			panel.offset_top = maxf(_portrait_story_top(css_size), css_size.y * 0.36) * scale_y
			panel.offset_bottom = panel.offset_top + panel_height
		else:
			panel.anchor_top = 1.0
			panel.anchor_bottom = 1.0
			panel.offset_top = -panel_height - 10.0 * scale_y
			panel.offset_bottom = -10.0 * scale_y
	_heading.add_theme_font_size_override("font_size", maxi(18, roundi((16.0 if portrait else 14.0) * text_scale)))
	_category.add_theme_font_size_override("font_size", maxi(14, roundi((12.0 if portrait else 10.0) * text_scale)))
	_source.add_theme_font_size_override("font_size", maxi(14, roundi((12.0 if portrait else 9.0) * text_scale)))
	_speaker.add_theme_font_size_override("font_size", maxi(22, roundi((19.0 if portrait else 18.0) * text_scale)))
	_body.add_theme_font_size_override("font_size", maxi(24, roundi((21.0 if portrait else 20.0) * text_scale)))
	_body.custom_minimum_size.y = (48.0 if portrait else 60.0) * scale_y
	_body.clip_text = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress.add_theme_font_size_override("font_size", maxi(12, roundi(10.0 * text_scale)))
	_hint.add_theme_font_size_override("font_size", maxi(12, roundi(10.0 * text_scale)))
	_margin.add_theme_constant_override("margin_left", roundi(14.0 * scale_x))
	_margin.add_theme_constant_override("margin_right", roundi(14.0 * scale_x))
	_margin.add_theme_constant_override("margin_top", roundi(8.0 * scale_y))
	_margin.add_theme_constant_override("margin_bottom", roundi(8.0 * scale_y))
	for button in [_skip, _next]:
		button.custom_minimum_size = Vector2((96.0 if portrait else 104.0) * scale_x, (42.0 if portrait else 40.0) * scale_y)
		button.add_theme_font_size_override("font_size", maxi(18, roundi((16.0 if portrait else 14.0) * text_scale)))


func _portrait_story_top(css_size: Vector2) -> float:
	var safe_top := 0.0
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval(
			"""(() => { const e=document.createElement('div'); e.style.cssText='position:fixed;inset:0;visibility:hidden;padding-top:env(safe-area-inset-top)'; document.body.appendChild(e); const n=parseFloat(getComputedStyle(e).paddingTop)||0; e.remove(); return n; })()""",
			true
		)
		safe_top = float(raw)
	elif OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var window_size := Vector2(DisplayServer.window_get_size())
		if window_size.y > 0.0:
			safe_top = safe.position.y * css_size.y / window_size.y
	return maxf(158.0, safe_top + 12.0)


func start(lines: Array, heading: String = "") -> void:
	_lines.clear()
	for line in lines:
		if line is Dictionary:
			_lines.append(line)
	_index = 0
	visible = not _lines.is_empty()
	if heading.is_empty():
		heading = Locale.t("story.chronicle")
	var heading_label := find_child("StoryHeading", true, false) as Label
	if heading_label != null:
		heading_label.text = heading
	_refresh()


func advance() -> void:
	if not visible:
		return
	_index += 1
	if _index >= _lines.size():
		visible = false
		_voice.stop_line()
		finished.emit()
		return
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_skip_all()
		get_viewport().set_input_as_handled()


func _build() -> void:
	# 轻量压暗：仅底部字幕区，由上至下渐深；上方战场完全可见。
	var fade_gradient := Gradient.new()
	fade_gradient.add_point(0.0, Color(0.01, 0.015, 0.02, 0.0))
	fade_gradient.add_point(1.0, Color(0.01, 0.015, 0.02, 0.62))
	var fade_texture := GradientTexture2D.new()
	fade_texture.gradient = fade_gradient
	fade_texture.fill_from = Vector2(0.0, 0.0)
	fade_texture.fill_to = Vector2(0.0, 1.0)
	_bottom_fade = TextureRect.new()
	_bottom_fade.name = "BottomFade"
	_bottom_fade.texture = fade_texture
	_bottom_fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bottom_fade.stretch_mode = TextureRect.STRETCH_SCALE
	_bottom_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_fade.anchor_left = 0.0
	_bottom_fade.anchor_right = 1.0
	_bottom_fade.anchor_top = 1.0
	_bottom_fade.anchor_bottom = 1.0
	_bottom_fade.offset_left = 0.0
	_bottom_fade.offset_right = 0.0
	_bottom_fade.offset_top = -224.0
	_bottom_fade.offset_bottom = 0.0
	add_child(_bottom_fade)

	# 不透明底板：压住底层 HUD 文字，避免半透明面板透出造成文字重影。
	_subtitle_bg = ColorRect.new()
	_subtitle_bg.name = "SubtitleOpaqueBacking"
	_subtitle_bg.color = Color("#0d1213")
	_subtitle_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_bg.anchor_left = 0.0
	_subtitle_bg.anchor_right = 1.0
	_subtitle_bg.anchor_top = 1.0
	_subtitle_bg.anchor_bottom = 1.0
	_subtitle_bg.offset_left = 210.0
	_subtitle_bg.offset_right = -210.0
	_subtitle_bg.offset_top = -180.0
	_subtitle_bg.offset_bottom = -20.0
	add_child(_subtitle_bg)

	# 底部字幕条：来源单独占一行，避免长出处挤进装饰边框。
	_panel = PanelContainer.new()
	_panel.name = "StoryPanel"
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 210.0
	_panel.offset_right = -210.0
	_panel.offset_top = -180.0
	_panel.offset_bottom = -20.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxTexture.new()
	panel_style.texture = PANEL_TEXTURE
	panel_style.texture_margin_left = 14.0
	panel_style.texture_margin_top = 14.0
	panel_style.texture_margin_right = 14.0
	panel_style.texture_margin_bottom = 14.0
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	_margin = MarginContainer.new()
	_margin.add_theme_constant_override("margin_left", 20)
	_margin.add_theme_constant_override("margin_right", 20)
	_margin.add_theme_constant_override("margin_top", 18)
	_margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_margin.add_child(column)

	# 标题与分类独立一行；较长出处移到完整宽度的第二行。
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 10)
	column.add_child(heading_row)
	_heading = _label("", 12, Color(MUTED, 0.82))
	_heading.name = "StoryHeading"
	heading_row.add_child(_heading)
	_category = _label("", 10, VERMILION)
	heading_row.add_child(_category)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(spacer)
	_source = _label("", 9, Color(MUTED, 0.72))
	_source.name = "StorySource"
	_source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_source.clip_text = true
	_source.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_source)

	_speaker = _label("", 16, GOLD)
	column.add_child(_speaker)
	_body = _label("", 18, PAPER)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(0.0, 32.0)
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	column.add_child(_body)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	_progress = _label("", 10, Color(MUTED, 0.55))
	footer.add_child(_progress)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	_hint = _label(Locale.t("story.hint"), 10, Color(MUTED, 0.5))
	footer.add_child(_hint)
	_skip = _button(Locale.t("story.skip"), false)
	_skip.pressed.connect(_skip_all)
	footer.add_child(_skip)
	_next = _button(Locale.t("story.next"), true)
	_next.pressed.connect(advance)
	footer.add_child(_next)

	_voice = VoiceLinePlayer.new()
	_voice.name = "StoryVoice"
	add_child(_voice)


func _refresh() -> void:
	if _lines.is_empty() or _index < 0 or _index >= _lines.size():
		return
	var line := _lines[_index]
	_speaker.text = str(line.get("speaker_%s" % Locale.current, line.get("speaker_zh", "")))
	_body.text = GameData.loc(line, "zh") if Locale.current == "zh" else str(line.get("en", ""))
	_source.text = GameData.source_label(line)
	_category.text = str(line.get("category", "演绎"))
	_category.add_theme_color_override(
		"font_color",
		GOLD if _category.text == "史实" else VERMILION
	)
	_progress.text = "%d / %d" % [_index + 1, _lines.size()]
	_next.text = Locale.t("story.finish" if _index == _lines.size() - 1 else "story.next")
	_voice.play_line(line)


func _skip_all() -> void:
	if not visible:
		return
	visible = false
	_voice.stop_line()
	finished.emit()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(88.0, 28.0)
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 12)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(GOLD, 0.13 if primary else 0.05)
	box.border_color = Color(GOLD, 0.72 if primary else 0.28)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_color_override("font_color", PAPER)
	return button
