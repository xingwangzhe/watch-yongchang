class_name TutorialOverlay
extends Control

## 首次守夜与主菜单／暂停菜单共用的分页教程。
## 只负责展示和导航；是否记住教程由调用方写入 SaveSystem。

signal closed(skipped: bool)

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.webp")
const UIControls := preload("res://scripts/ui/ui_control_theme.gd")
const PAGE_COUNT := 3

const INK := Color("#081014")
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const VERMILION := Color("#a34a38")
const JADE := Color("#7fb7a8")

var _page := 0
var _first_run := false
var _page_label: Label
var _page_title: Label
var _body: Label
var _note: Label
var _hint: Label
var _prev_button: Button
var _next_button: Button
var _skip_button: Button
var _tabs: Array[Button] = []


func _ready() -> void:
	name = "TutorialOverlay"
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var theme := Theme.new()
	theme.default_font = UI_FONT
	theme.default_font_size = 18
	UIControls.install(theme)

	_build()
	visible = false
	Locale.language_changed.connect(_refresh)


func open(first_run: bool = false) -> void:
	_first_run = first_run
	_page = 0
	visible = true
	_refresh()
	_next_button.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var code := int(key_event.physical_keycode)
	if code <= 0:
		code = int(key_event.keycode)
	match code:
		KEY_LEFT:
			_go_page(_page - 1)
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			_go_page(_page + 1)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if _page == PAGE_COUNT - 1:
				_finish(false)
			else:
				_go_page(_page + 1)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_finish(_first_run)
		get_viewport().set_input_as_handled()


func _go_page(index: int) -> void:
	var next_page := clampi(index, 0, PAGE_COUNT - 1)
	if next_page == _page:
		return
	_page = next_page
	_refresh()


func _finish(skipped: bool) -> void:
	if not visible:
		return
	visible = false
	closed.emit(skipped)


func _refresh(_code: String = "") -> void:
	if _page_title == null:
		return
	var page_number := _page + 1
	_page_label.text = Locale.t("tutorial.page", {"page": page_number, "pages": PAGE_COUNT})
	_page_title.text = Locale.t("tutorial.page%d.title" % page_number)
	_body.text = Locale.t("tutorial.page%d.body" % page_number)
	_note.text = Locale.t("tutorial.page%d.note" % page_number)
	_prev_button.disabled = _page == 0
	if _page == PAGE_COUNT - 1:
		_next_button.text = Locale.t("tutorial.finish" if _first_run else "tutorial.close")
	else:
		_next_button.text = Locale.t("tutorial.next")
	_skip_button.text = Locale.t("tutorial.skip" if _first_run else "tutorial.close")
	_hint.text = Locale.t("tutorial.hint")
	for index in range(_tabs.size()):
		var tab := _tabs[index]
		tab.button_pressed = index == _page
		tab.add_theme_stylebox_override("normal", _tab_style(index == _page))


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.004, 0.009, 0.012, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "TutorialPanel"
	UILayout.place(panel, 120.0, 55.0, 1040.0, 610.0, 0.5, 0.5)
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	var seal := PanelContainer.new()
	seal.custom_minimum_size = Vector2(48, 48)
	seal.add_theme_stylebox_override("panel", _flat_style(Color(VERMILION, 0.92), Color(GOLD, 0.72), 1, 3))
	header.add_child(seal)
	var seal_text := _label(Locale.t("tutorial.seal"), 25, PAPER)
	seal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_child(seal_text)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var kicker := _label(Locale.t("tutorial.kicker"), 12, Color(MUTED, 0.82))
	heading.add_child(kicker)
	var title := _label(Locale.t("tutorial.title"), 29, GOLD)
	heading.add_child(title)
	_page_label = _label("", 14, Color(MUTED, 0.82))
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_page_label)

	var tabs := HBoxContainer.new()
	tabs.name = "TutorialTabs"
	tabs.add_theme_constant_override("separation", 10)
	column.add_child(tabs)
	for index in range(PAGE_COUNT):
		var tab := _button("TutorialTab%d" % (index + 1), Locale.t("tutorial.tab_%s" % ["controls", "culture", "systems"][index]), false)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.toggle_mode = true
		tab.pressed.connect(_go_page.bind(index))
		tabs.add_child(tab)
		_tabs.append(tab)

	column.add_child(_rule())

	var content := PanelContainer.new()
	content.name = "TutorialContent"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_stylebox_override("panel", _flat_style(Color(0.025, 0.040, 0.041, 0.82), Color(GOLD, 0.20), 1, 4))
	column.add_child(content)
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 24)
	content_margin.add_theme_constant_override("margin_right", 24)
	content_margin.add_theme_constant_override("margin_top", 20)
	content_margin.add_theme_constant_override("margin_bottom", 16)
	content.add_child(content_margin)
	var content_column := VBoxContainer.new()
	content_column.add_theme_constant_override("separation", 12)
	content_margin.add_child(content_column)
	_page_title = _label("", 28, PAPER)
	content_column.add_child(_page_title)
	_body = _label("", 17, Color(PAPER, 0.92))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body.add_theme_constant_override("line_spacing", 7)
	content_column.add_child(_body)
	_note = _label("", 12, Color(JADE, 0.90))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(0, 40)
	content_column.add_child(_note)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	_skip_button = _button("TutorialSkipButton", Locale.t("tutorial.skip"), false)
	_skip_button.custom_minimum_size = Vector2(146, 44)
	_skip_button.pressed.connect(_finish.bind(true))
	footer.add_child(_skip_button)
	_hint = _label(Locale.t("tutorial.hint"), 11, Color(MUTED, 0.66))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_hint)
	_prev_button = _button("TutorialPrevButton", Locale.t("tutorial.prev"), false)
	_prev_button.custom_minimum_size = Vector2(108, 44)
	_prev_button.pressed.connect(func() -> void: _go_page(_page - 1))
	footer.add_child(_prev_button)
	_next_button = _button("TutorialNextButton", Locale.t("tutorial.next"), true)
	_next_button.custom_minimum_size = Vector2(150, 44)
	_next_button.pressed.connect(func() -> void:
		if _page == PAGE_COUNT - 1:
			_finish(false)
		else:
			_go_page(_page + 1)
	)
	footer.add_child(_next_button)


func _button(node_name: String, text: String, primary: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color("#fff0cf"))
	button.add_theme_color_override("font_pressed_color", Color("#f4dfb2"))
	button.add_theme_color_override("font_focus_color", Color("#fff0cf"))
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.42))
	button.add_theme_stylebox_override("normal", _flat_style(Color(GOLD, 0.14 if primary else 0.045), Color(GOLD, 0.72 if primary else 0.28), 1, 3))
	button.add_theme_stylebox_override("hover", _flat_style(Color(GOLD, 0.23), Color(GOLD, 0.88), 1, 3))
	button.add_theme_stylebox_override("pressed", _flat_style(Color(GOLD, 0.30), Color(GOLD, 0.96), 1, 3))
	button.add_theme_stylebox_override("disabled", _flat_style(Color(0.03, 0.04, 0.04, 0.65), Color(GOLD, 0.12), 1, 3))
	return button


func _tab_style(selected: bool) -> StyleBoxFlat:
	return _flat_style(
		Color(GOLD, 0.18 if selected else 0.035),
		Color(GOLD, 0.82 if selected else 0.22),
		1,
		3
	)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(GOLD, 0.30)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _flat_style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.border_width_left = width
	box.border_width_top = width
	box.border_width_right = width
	box.border_width_bottom = width
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box


func _panel_style() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = PANEL_TEXTURE
	box.texture_margin_left = 28.0
	box.texture_margin_top = 28.0
	box.texture_margin_right = 28.0
	box.texture_margin_bottom = 28.0
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box
