class_name StoryOverlay
extends Control

signal finished

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.png")
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


func _ready() -> void:
	name = "StoryOverlay"
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false


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
	# 轻量遮罩：让场景可见，仅压暗到可辨字幕的程度。
	var dim := ColorRect.new()
	dim.color = Color(0.008, 0.012, 0.014, 0.46)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 不透明底板：压住底层 HUD 文字，避免半透明木纹面板透出造成文字重影。
	var subtitle_bg := ColorRect.new()
	subtitle_bg.name = "SubtitleOpaqueBacking"
	subtitle_bg.color = Color("#0d1213")
	subtitle_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_bg.anchor_left = 0.0
	subtitle_bg.anchor_right = 1.0
	subtitle_bg.anchor_top = 1.0
	subtitle_bg.anchor_bottom = 1.0
	subtitle_bg.offset_left = 190.0
	subtitle_bg.offset_right = -190.0
	subtitle_bg.offset_top = -188.0
	subtitle_bg.offset_bottom = -28.0
	add_child(subtitle_bg)

	# 底部紧凑字幕条：锚定父节点底边，宽 900、高 120，占屏比由 69% 降至 17%。
	var panel := PanelContainer.new()
	panel.name = "StoryPanel"
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 190.0
	panel.offset_right = -190.0
	panel.offset_top = -188.0
	panel.offset_bottom = -28.0
	var panel_style := StyleBoxTexture.new()
	panel_style.texture = PANEL_TEXTURE
	panel_style.texture_margin_left = 18.0
	panel_style.texture_margin_top = 18.0
	panel_style.texture_margin_right = 18.0
	panel_style.texture_margin_bottom = 18.0
	panel_style.content_margin_left = 22.0
	panel_style.content_margin_right = 22.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)

	# 单行信息栏：说话人 · 分类 · 出处（出处过长时省略号裁剪）。
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 10)
	column.add_child(heading_row)
	var heading := _label("", 13, Color(MUTED, 0.82))
	heading.name = "StoryHeading"
	heading_row.add_child(heading)
	_category = _label("", 11, VERMILION)
	heading_row.add_child(_category)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(spacer)
	_source = _label("", 10, Color(MUTED, 0.64))
	_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_source.clip_text = true
	_source.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_source.custom_minimum_size = Vector2(300.0, 0.0)
	heading_row.add_child(_source)

	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.26)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	column.add_child(rule)

	_speaker = _label("", 18, GOLD)
	column.add_child(_speaker)
	_body = _label("", 20, PAPER)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(0.0, 36.0)
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
	_source.text = str(line.get("source_ref", ""))
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
	button.custom_minimum_size = Vector2(96.0, 30.0)
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 13)
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
