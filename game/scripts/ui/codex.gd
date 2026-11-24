extends Control

signal closed

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.png")
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const VERMILION := Color("#c05a41")
const INK := Color("#081114")

var _data: Dictionary = {}
var _content: Control
var embedded := false


func _ready() -> void:
	InputSetup.ensure_defaults()
	_data = GameData.load_json("res://data/codex.json")
	var theme_res := Theme.new()
	theme_res.default_font = UI_FONT
	theme_res.default_font_size = 18
	theme = theme_res
	_build_backdrop()
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_content)
	_rebuild()
	Locale.language_changed.connect(_on_language_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_codex"):
		_return_to_menu()
		get_viewport().set_input_as_handled()


func _on_language_changed(_code: String) -> void:
	_rebuild()


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()
	_build_header()
	_build_columns()
	_build_timeline()
	_build_sources()


func _build_backdrop() -> void:
	var background := ColorRect.new()
	background.color = INK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in range(9):
		var line := ColorRect.new()
		line.color = Color(0.55, 0.45, 0.26, 0.045)
		line.position = Vector2(0, 80 + i * 72)
		line.size = Vector2(1280, 1)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
	for i in range(8):
		var vertical := ColorRect.new()
		vertical.color = Color(0.55, 0.45, 0.26, 0.025)
		vertical.position = Vector2(80 + i * 160, 0)
		vertical.size = Vector2(1, 720)
		vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(vertical)


func _build_header() -> void:
	var title := _label(_loc("title"), 40, GOLD)
	title.position = Vector2(56, 22)
	_content.add_child(title)
	var subtitle := _label(_loc("subtitle"), 18, Color(PAPER, 0.92))
	subtitle.position = Vector2(58, 70)
	subtitle.size = Vector2(990, 28)
	_content.add_child(subtitle)
	var boundary := _label(" · ".join(_localized_array("facts")), 12, Color(MUTED, 0.72))
	boundary.position = Vector2(58, 101)
	boundary.size = Vector2(1060, 26)
	_content.add_child(boundary)
	var back := _button(Locale.t("codex.back"), true)
	back.position = Vector2(1054, 34)
	back.size = Vector2(170, 44)
	back.pressed.connect(_return_to_menu)
	_content.add_child(back)
	var hint := _label(Locale.t("codex.hint"), 11, Color(MUTED, 0.52))
	hint.position = Vector2(1050, 82)
	hint.size = Vector2(180, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_content.add_child(hint)


func _build_columns() -> void:
	var left := _panel({
		"title": _loc("left", "title"),
		"lead": _loc("left", "lead"),
		"points": _localized_array("left", "points"),
		"source": str(_data.get("left", {}).get("source_ref", "")),
		"accent": Color("#d1ad62"),
	})
	left.position = Vector2(48, 138)
	left.size = Vector2(356, 336)
	_content.add_child(left)

	var center := _bridge_panel()
	center.position = Vector2(432, 138)
	center.size = Vector2(416, 336)
	_content.add_child(center)

	var right := _panel({
		"title": _loc("right", "title"),
		"lead": _loc("right", "lead"),
		"points": _localized_array("right", "points"),
		"source": str(_data.get("right", {}).get("source_ref", "")),
		"accent": Color("#b95a43"),
	})
	right.position = Vector2(876, 138)
	right.size = Vector2(356, 336)
	_content.add_child(right)


func _panel(spec: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var title := _label(str(spec.get("title", "")), 24, spec.get("accent", GOLD) as Color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(spec.get("accent", GOLD) as Color, 0.34)
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)
	var lead := _label(str(spec.get("lead", "")), 15, PAPER)
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead.custom_minimum_size = Vector2(0, 42)
	column.add_child(lead)
	for point in spec.get("points", []) as Array:
		var bullet := _label("· %s" % str(point), 13, Color(PAPER, 0.88))
		bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bullet.custom_minimum_size = Vector2(0, 36)
		column.add_child(bullet)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grow)
	var full_source := str(spec.get("source", ""))
	var source := _label(_display_source(full_source), 10, Color(MUTED, 0.58))
	source.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	source.max_lines_visible = 2
	source.clip_text = true
	source.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	source.tooltip_text = full_source
	source.custom_minimum_size = Vector2(0, 26)
	column.add_child(source)
	return panel


func _bridge_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(true))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var title := _label(_loc("bridge", "title"), 21, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.34)
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)
	var body := _label(_loc("bridge", "body"), 15, PAPER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(0, 54)
	column.add_child(body)
	var chain := _label("1386 宁村所  →  1558 王德移师\n1558 金岙  →  1559 永昌堡", 13, Color(GOLD, 0.92))
	chain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chain.custom_minimum_size = Vector2(0, 44)
	column.add_child(chain)
	var forbidden := _label("%s：%s" % [Locale.t("codex.forbidden"), _loc("do_not_claim")], 12, Color("#dc8b74"))
	forbidden.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	forbidden.custom_minimum_size = Vector2(0, 66)
	column.add_child(forbidden)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grow)
	var full_source := str(_data.get("bridge", {}).get("source_ref", ""))
	var source := _label(_display_source(full_source), 10, Color(MUTED, 0.58))
	source.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	source.max_lines_visible = 2
	source.clip_text = true
	source.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	source.tooltip_text = full_source
	source.custom_minimum_size = Vector2(0, 26)
	column.add_child(source)
	return panel


func _build_timeline() -> void:
	var heading := _label(Locale.t("codex.timeline"), 17, GOLD)
	heading.position = Vector2(54, 488)
	_content.add_child(heading)
	var row := HBoxContainer.new()
	row.position = Vector2(50, 514)
	row.size = Vector2(1180, 88)
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	for entry in _data.get("timeline", []) as Array:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(188, 94)
		card.add_theme_stylebox_override("panel", _timeline_style())
		row.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 3)
		card.add_child(column)
		var year := _label(str(entry.get("year", "")), 19, GOLD)
		year.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(year)
		var text := _label(str(entry.get("zh" if Locale.current == "zh" else "en", "")), 12, Color(PAPER, 0.82))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.custom_minimum_size = Vector2(0, 50)
		column.add_child(text)


func _build_sources() -> void:
	var heading := _label(Locale.t("codex.sources"), 13, Color(MUTED, 0.82))
	heading.position = Vector2(54, 630)
	_content.add_child(heading)
	var display_sources: Array[String] = []
	for source in _localized_array("sources"):
		display_sources.append(_display_source(str(source)))
	var sources := _label(" · ".join(display_sources), 9, Color(MUTED, 0.56))
	sources.position = Vector2(124, 629)
	sources.size = Vector2(1100, 42)
	sources.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	sources.max_lines_visible = 2
	sources.clip_text = true
	sources.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_content.add_child(sources)


func _display_source(value: String) -> String:
	return value \
		.replace("docs/06-资料文本化/文档文本/", "") \
		.replace("docs/06-资料文本化/", "") \
		.replace("永昌堡-十三进士与抗倭纪略-全文.txt", "永昌堡纪略") \
		.replace("汤和信俗(11.18)__抵御倭患第一人+汤和(1)(1).txt", "汤和信俗·抵御倭患") \
		.replace("意绘抗倭英雄汤和-漫画全文.txt", "汤和漫画") \
		.replace("汤和信俗(11.18)__汤和庙基地介绍.txt", "汤和庙介绍") \
		.replace("汤和信俗(11.18)__龙湾汤和信俗文化节启幕在即 拼字龙灯邀您共同祈愿“天下太平”(3)(1).txt", "龙灯节报道")


func _loc(section: String, field: String = "") -> String:
	var dictionary: Dictionary = _data.get(section, {}) as Dictionary if not section.is_empty() else _data
	if field.is_empty():
		var key := "%s_%s" % [section, Locale.current] if section in ["title", "subtitle", "do_not_claim"] else "%s_%s" % [section, Locale.current]
		return str(_data.get(key, _data.get("%s_zh" % section, "")))
	return str(dictionary.get("%s_%s" % [field, Locale.current], dictionary.get("%s_zh" % field, "")))


func _localized_array(section: String, field: String = "") -> Array:
	if field.is_empty():
		return _data.get("%s_%s" % [section, Locale.current], _data.get("%s_zh" % section, [])) as Array
	var dictionary: Dictionary = _data.get(section, {}) as Dictionary
	return dictionary.get("%s_%s" % [field, Locale.current], dictionary.get("%s_zh" % field, [])) as Array


func _return_to_menu() -> void:
	if embedded:
		closed.emit()
		queue_free()
		return
	SaveSystem.autosave({"last_mode": "menu"})
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


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
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", PAPER)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(GOLD, 0.14 if primary else 0.05)
	box.border_color = Color(GOLD, 0.65 if primary else 0.25)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	button.add_theme_stylebox_override("normal", box)
	return button


func _panel_style(accented: bool = false) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = PANEL_TEXTURE
	box.texture_margin_left = 28.0
	box.texture_margin_top = 28.0
	box.texture_margin_right = 28.0
	box.texture_margin_bottom = 28.0
	box.content_margin_left = 22.0
	box.content_margin_right = 22.0
	box.content_margin_top = 18.0
	box.content_margin_bottom = 16.0
	if accented:
		box.modulate_color = Color(1.08, 1.02, 0.90, 1.0)
	return box


func _timeline_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.048, 0.061, 0.061, 0.92)
	box.border_color = Color(GOLD, 0.22)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box
