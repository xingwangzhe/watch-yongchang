class_name NarrativePlayer
extends CanvasLayer

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
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


func _ready() -> void:
	layer = 8
	_build()
	visible = false


func show_line(line: Dictionary) -> void:
	visible = true
	_speaker.text = _speaker_name(line)
	_body.text = GameData.loc(line, "zh") if Locale.current == "zh" else str(line.get("en", ""))
	_category.text = str(line.get("category", "演绎"))
	_category.add_theme_color_override(
		"font_color",
		GOLD if _category.text == "史实" else VERMILION
	)
	_source.text = str(line.get("source_ref", ""))
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

	_panel = PanelContainer.new()
	_panel.name = "SubtitlePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.position = Vector2(170.0, 552.0)
	_panel.size = Vector2(940.0, 146.0)
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_bottom", 11)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	column.add_child(heading)
	_speaker = _label("", 18, GOLD)
	_speaker.custom_minimum_size = Vector2(150.0, 0.0)
	heading.add_child(_speaker)
	_category = _label("", 12, VERMILION)
	heading.add_child(_category)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	_source = _label("", 11, Color(MUTED, 0.74))
	_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_source)

	_body = _label("", 20, PAPER)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(0.0, 54.0)
	column.add_child(_body)

	var hint := _label(Locale.t("story.subtitle_hint"), 11, Color(MUTED, 0.55))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(hint)

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
