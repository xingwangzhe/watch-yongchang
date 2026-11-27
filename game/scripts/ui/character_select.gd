extends Control

const BackdropScript := preload("res://scripts/ui/menu_backdrop.gd")
const UIControls := preload("res://scripts/ui/ui_control_theme.gd")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.webp")
const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")

const CHARACTER_ORDER := ["wanglu", "amei", "ashi", "achong", "agong", "aqi"]
const MAP_ORDER := ["tideland", "watergate", "crossstreet"]
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const VERMILION := Color("#c05a41")
const INK := Color(0.018, 0.028, 0.031, 0.88)

var _characters: Dictionary = {}
var _maps: Dictionary = {}
var _weapons: Dictionary = {}
var _passives: Dictionary = {}
var _selected_character := "wanglu"
var _selected_map := "tideland"
var _char_buttons: Dictionary = {}
var _char_labels: Dictionary = {}
var _map_buttons: Dictionary = {}
var _portrait: TextureRect
var _name_label: Label
var _alias_label: Label
var _role_label: Label
var _note_label: Label
var _loadout_label: Label
var _map_description: Label
var _merit_label: Label
var _begin_button: Button
var _title_label: Label
var _subtitle_label: Label
var _rule: ColorRect
var _panels: HBoxContainer
var _mobile_scroll: ScrollContainer
var _mobile_stack: VBoxContainer
var _mobile_layout_active := false
var _character_panel: PanelContainer
var _detail_panel: PanelContainer
var _portrait_frame: PanelContainer
var _footer_hint: Label
var _back_button: Button


func _ready() -> void:
	_characters = GameData.get_characters()
	_maps = GameData.get_maps()
	_weapons = GameData.get_weapons()
	_passives = GameData.get_passives()
	_selected_character = str(SaveSystem.data.get("selected_character", "wanglu"))
	_selected_map = str(SaveSystem.data.get("selected_map", "tideland"))
	if not _characters.has(_selected_character) or not _is_unlocked(_characters[_selected_character] as Dictionary):
		_selected_character = "wanglu"
	if not _maps.has(_selected_map) or not _is_unlocked(_maps[_selected_map] as Dictionary):
		_selected_map = "tideland"
	_build_theme()
	_build_ui()
	_refresh()
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	AudioBus.resume_bgm()
	SaveSystem.autosave({
		"last_mode": "select",
		"selected_character": _selected_character,
		"selected_map": _selected_map,
	})


func selected_character() -> String:
	return _selected_character


func selected_map() -> String:
	return _selected_map


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back_to_menu()
		get_viewport().set_input_as_handled()


func _build_theme() -> void:
	var select_theme := Theme.new()
	select_theme.default_font = UI_FONT
	select_theme.default_font_size = 18
	UIControls.install(select_theme)
	theme = select_theme


func _build_ui() -> void:
	var backdrop := BackdropScript.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.010, 0.012, 0.67)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	_title_label = _label(Locale.t("select.title"), 48, GOLD)
	var title := _title_label
	UILayout.place(title, 72, 34, 640, 56)
	add_child(title)
	_subtitle_label = _label(Locale.t("select.subtitle"), 18, Color(PAPER, 0.88))
	var subtitle := _subtitle_label
	UILayout.place(subtitle, 74, 92, 710, 26)
	add_child(subtitle)
	_rule = ColorRect.new()
	var rule := _rule
	rule.color = Color(GOLD, 0.36)
	UILayout.place(rule, 74, 124, 710, 1)
	add_child(rule)
	_merit_label = _label("", 17, GOLD)
	_merit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UILayout.place(_merit_label, 920, 50, 286, 30, 1.0, 0.0)
	add_child(_merit_label)

	_panels = HBoxContainer.new()
	var panels := _panels
	panels.name = "SelectionPanels"
	panels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panels.offset_left = 72.0
	panels.offset_right = -72.0
	panels.offset_top = 146.0
	panels.offset_bottom = -16.0
	panels.add_theme_constant_override("separation", 24)
	add_child(panels)
	_mobile_scroll = ScrollContainer.new()
	_mobile_scroll.name = "MobileSelectionScroll"
	_mobile_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mobile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mobile_scroll.visible = false
	add_child(_mobile_scroll)
	_mobile_stack = VBoxContainer.new()
	_mobile_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mobile_stack.add_theme_constant_override("separation", 10)
	_mobile_scroll.add_child(_mobile_stack)
	_build_character_panel(panels)
	_build_detail_panel(panels)


func _build_character_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	_character_panel = panel
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(344, 0)
	panel.add_theme_stylebox_override("panel", _panel_box(26))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var heading := _label(Locale.t("select.roster"), 19, MUTED)
	column.add_child(heading)
	for character_id in CHARACTER_ORDER:
		if not _characters.has(character_id):
			continue
		var card := _character_card(character_id)
		var button := card["button"] as Button
		button.name = "Character_%s" % character_id
		button.pressed.connect(_select_character.bind(character_id))
		column.add_child(button)
		_char_buttons[character_id] = button
		_char_labels[character_id] = card


func _build_detail_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	_detail_panel = panel
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 0)
	panel.add_theme_stylebox_override("panel", _panel_box(22))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var portrait_frame := PanelContainer.new()
	_portrait_frame = portrait_frame
	portrait_frame.custom_minimum_size = Vector2(220, 220)
	portrait_frame.add_theme_stylebox_override("panel", _flat_box(Color(0.03, 0.04, 0.04, 0.84), Color(GOLD, 0.34)))
	body.add_child(portrait_frame)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_frame.add_child(_portrait)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 6)
	body.add_child(details)
	_name_label = _label("", 38, GOLD)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_name_label)
	_alias_label = _label("", 20, PAPER)
	_alias_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_alias_label)
	_role_label = _label("", 16, VERMILION)
	_role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_role_label)
	var detail_rule := ColorRect.new()
	detail_rule.color = Color(GOLD, 0.22)
	detail_rule.custom_minimum_size = Vector2(0, 1)
	details.add_child(detail_rule)
	_note_label = _label("", 16, Color(PAPER, 0.88))
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.custom_minimum_size = Vector2(0, 64)
	details.add_child(_note_label)
	_loadout_label = _label("", 15, Color(MUTED, 0.94))
	_loadout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loadout_label.custom_minimum_size = Vector2(0, 56)
	details.add_child(_loadout_label)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(grow)
	var fiction_note := _label(Locale.t("select.fiction_note"), 12, Color(MUTED, 0.62))
	fiction_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(fiction_note)

	var map_rule := ColorRect.new()
	map_rule.color = Color(GOLD, 0.22)
	map_rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(map_rule)
	var map_heading := _label(Locale.t("select.map_heading"), 18, MUTED)
	column.add_child(map_heading)
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 8)
	column.add_child(map_row)
	for map_id in MAP_ORDER:
		if not _maps.has(map_id):
			continue
		var map_button := _card_button("", false)
		map_button.name = "Map_%s" % map_id
		map_button.custom_minimum_size = Vector2(0, 44)
		map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_button.pressed.connect(_select_map.bind(map_id))
		map_row.add_child(map_button)
		_map_buttons[map_id] = map_button
	_map_description = _label("", 14, Color(PAPER, 0.76))
	_map_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_description.custom_minimum_size = Vector2(0, 64)
	column.add_child(_map_description)
	_build_footer(column)


# 页脚作为详情面板内 VBoxContainer 的最后一行，由容器自动排布，
# 不再使用绝对坐标，杜绝说明文字与按钮重叠。
func _build_footer(parent: VBoxContainer) -> void:
	var footer_rule := ColorRect.new()
	footer_rule.color = Color(GOLD, 0.22)
	footer_rule.custom_minimum_size = Vector2(0, 1)
	parent.add_child(footer_rule)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 46)
	parent.add_child(row)

	var back := _card_button(Locale.t("select.back"), false)
	_back_button = back
	back.name = "BackButton"
	back.custom_minimum_size = Vector2(164, 44)
	back.pressed.connect(_back_to_menu)
	row.add_child(back)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_spacer)

	var hint := _label(Locale.t("select.hint"), 13, Color(MUTED, 0.62))
	_footer_hint = hint
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hint)

	_begin_button = _card_button(Locale.t("select.begin"), true)
	_begin_button.name = "BeginButton"
	_begin_button.custom_minimum_size = Vector2(180, 44)
	_begin_button.pressed.connect(_begin_run)
	row.add_child(_begin_button)


func _responsive_screen_size(viewport_size: Vector2) -> Vector2:
	if OS.has_feature("web"):
		var raw := str(JavaScriptBridge.eval("JSON.stringify([window.innerWidth || 0, window.innerHeight || 0])", true))
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Array and (parsed as Array).size() >= 2:
			var values: Array = parsed
			if float(values[0]) > 0.0 and float(values[1]) > 0.0:
				return Vector2(float(values[0]), float(values[1]))
	var window_size := DisplayServer.window_get_size()
	return window_size if window_size.x > 0.0 and window_size.y > 0.0 else viewport_size


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	_apply_responsive_layout_for(viewport_size, _responsive_screen_size(viewport_size))


func _apply_responsive_layout_for(viewport_size: Vector2, screen_size: Vector2) -> void:
	if not is_instance_valid(_panels):
		return
	var scale := UILayout.display_scale(viewport_size, screen_size)
	var portrait := screen_size.y > screen_size.x
	UILayout.scale_theme_fonts(self, 1.0 / scale)
	if portrait != _mobile_layout_active:
		_mobile_layout_active = portrait
		_character_panel.get_parent().remove_child(_character_panel)
		_detail_panel.get_parent().remove_child(_detail_panel)
		if portrait:
			_panels.visible = false
			_mobile_scroll.visible = true
			_mobile_stack.add_child(_character_panel)
			_mobile_stack.add_child(_detail_panel)
		else:
			_mobile_scroll.visible = false
			_panels.visible = true
			_panels.add_child(_character_panel)
			_panels.add_child(_detail_panel)
	if portrait:
		var margin := UILayout.display_units(12.0, scale)
		_title_label.add_theme_font_size_override("font_size", maxi(24, int(34.0 / scale)))
		UILayout.place(_title_label, 16.0 / scale, 8.0 / scale, 240.0 / scale, 42.0 / scale)
		_subtitle_label.visible = false
		_rule.visible = false
		_merit_label.add_theme_font_size_override("font_size", maxi(11, int(14.0 / scale)))
		UILayout.place(_merit_label, 220.0 / scale, 18.0 / scale, screen_size.x / scale - 232.0 / scale, 26.0 / scale, 1.0, 0.0)
		_mobile_scroll.offset_left = margin
		_mobile_scroll.offset_right = -margin
		_mobile_scroll.offset_top = 58.0 / scale
		_mobile_scroll.offset_bottom = -margin
		_character_panel.custom_minimum_size = Vector2(0, 0)
		_detail_panel.custom_minimum_size = Vector2(0, 0)
		_character_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_portrait_frame.custom_minimum_size = Vector2(72.0 / scale, 72.0 / scale)
		var body := _portrait_frame.get_parent() as HBoxContainer
		if body != null:
			body.add_theme_constant_override("separation", int(8.0 / scale))
		_footer_hint.visible = false
		_back_button.custom_minimum_size = Vector2(74.0 / scale, 40.0 / scale)
		_begin_button.custom_minimum_size = Vector2(88.0 / scale, 40.0 / scale)
		for button in _char_buttons.values():
			(button as Button).custom_minimum_size.y = 48.0 / scale
		for button in _map_buttons.values():
			(button as Button).custom_minimum_size = Vector2(0, 44.0 / scale)
		_map_description.custom_minimum_size.y = 0.0
		_note_label.custom_minimum_size.y = 0.0
		_loadout_label.custom_minimum_size.y = 0.0
		_back_button.custom_minimum_size.x = 112.0 / scale
		_begin_button.custom_minimum_size.x = 128.0 / scale
	else:
		_title_label.add_theme_font_size_override("font_size", 48)
		UILayout.place(_title_label, 72, 34, 640, 56)
		_subtitle_label.visible = true
		_rule.visible = true
		UILayout.place(_subtitle_label, 74, 92, 710, 26)
		UILayout.place(_rule, 74, 124, 710, 1)
		UILayout.place(_merit_label, 920, 50, 286, 30, 1.0, 0.0)
		_panels.offset_left = 72.0
		_panels.offset_right = -72.0
		_panels.offset_top = 146.0
		_panels.offset_bottom = -16.0
		_panels.add_theme_constant_override("separation", 24)
		_character_panel.custom_minimum_size.x = 344.0
		_portrait_frame.custom_minimum_size = Vector2(220, 220)
		_footer_hint.visible = true
		_back_button.custom_minimum_size = Vector2(164, 44)
		_begin_button.custom_minimum_size = Vector2(180, 44)
		for button in _char_buttons.values():
			(button as Button).custom_minimum_size.y = 54.0
		for button in _map_buttons.values():
			(button as Button).custom_minimum_size.y = 44.0


func _select_character(character_id: String) -> void:
	if not _characters.has(character_id):
		return
	var entry := _characters[character_id] as Dictionary
	if not _is_unlocked(entry):
		return
	_selected_character = character_id
	_refresh()


func _select_map(map_id: String) -> void:
	if not _maps.has(map_id):
		return
	var entry := _maps[map_id] as Dictionary
	if not _is_unlocked(entry):
		return
	_selected_map = map_id
	_refresh()


func _refresh() -> void:
	_merit_label.text = Locale.t("select.merit", {"value": int(SaveSystem.data.get("total_merit", 0))})
	for character_id in _char_buttons.keys():
		var entry := _characters.get(character_id, {}) as Dictionary
		var button := _char_buttons[character_id] as Button
		var unlocked := _is_unlocked(entry)
		var selected := str(character_id) == _selected_character
		var labels := _char_labels.get(character_id, {}) as Dictionary
		(labels["title"] as Label).text = _preset_name(entry)
		(labels["meta"] as Label).text = (
			GameData.loc(entry, "alias")
			if unlocked
			else Locale.t("select.lock", {"value": int(entry.get("unlock_merit", 0))})
		)
		button.disabled = not unlocked
		button.tooltip_text = "%s · %s" % [_preset_name(entry), GameData.loc(entry, "alias")]
		_apply_button_style(button, selected, unlocked)
	for map_id in _map_buttons.keys():
		var entry := _maps.get(map_id, {}) as Dictionary
		var button := _map_buttons[map_id] as Button
		var unlocked := _is_unlocked(entry)
		var selected := str(map_id) == _selected_map
		button.text = GameData.loc(entry, "name")
		if not unlocked:
			button.text += " · %d" % int(entry.get("unlock_merit", 0))
		button.disabled = not unlocked
		_apply_button_style(button, selected, unlocked)

	var character := _characters[_selected_character] as Dictionary
	_portrait.texture = _character_portrait(character)
	_name_label.text = _preset_name(character)
	_alias_label.text = "%s · %s" % [
		GameData.loc(character, "name"),
		GameData.loc(character, "alias"),
	]
	_role_label.text = Locale.t("select.role_era", {
		"role": GameData.loc(character, "role"),
		"era": str(character.get("era", "1559")),
	})
	_note_label.text = GameData.loc(character, "note")
	var weapon := _weapons.get(str(character.get("starting_weapon", "")), {}) as Dictionary
	var passive := _passives.get(str(character.get("starting_passive", "")), {}) as Dictionary
	_loadout_label.text = Locale.t("select.loadout", {
		"weapon": GameData.loc(weapon, "name"),
		"passive": GameData.loc(passive, "name"),
		"hp": int(character.get("hp", 100)),
		"speed": int(character.get("speed", 150)),
		"oil": int(character.get("oil_max", 6)),
	})
	var map := _maps[_selected_map] as Dictionary
	_map_description.text = Locale.t("select.map_line", {
		"subtitle": GameData.loc(map, "subtitle"),
		"description": GameData.loc(map, "description"),
	})
	_map_description.tooltip_text = _map_description.text
	_begin_button.disabled = false


func _character_portrait(character: Dictionary) -> Texture2D:
	var codex_path := str(character.get("codex_portrait_sheet", ""))
	if not codex_path.is_empty():
		var codex_frames := SpriteSheetFrames.path_row(
			codex_path,
			int(character.get("codex_portrait_columns", 1)),
			1,
			0
		)
		var codex_index := int(character.get("codex_portrait_frame", 0))
		if codex_index >= 0 and codex_index < codex_frames.size():
			return codex_frames[codex_index]
	var frames := SpriteSheetFrames.path_row(
		str(character.get("sprite_sheet", "")),
		int(character.get("sprite_columns", 8)),
		int(character.get("sprite_rows", 1)),
		int(character.get("sprite_row", 0))
	)
	return frames[0] if not frames.is_empty() else null


func _preset_name(entry: Dictionary) -> String:
	var preset := GameData.loc(entry, "preset_name")
	return preset if not preset.is_empty() else GameData.loc(entry, "name")


func _is_unlocked(entry: Dictionary) -> bool:
	return int(SaveSystem.data.get("total_merit", 0)) >= int(entry.get("unlock_merit", 0))


func _begin_run() -> void:
	SaveSystem.data["selected_character"] = _selected_character
	SaveSystem.data["selected_map"] = _selected_map
	get_tree().change_scene_to_file("res://scenes/run.tscn")


func _back_to_menu() -> void:
	SaveSystem.autosave({
		"last_mode": "menu",
		"selected_character": _selected_character,
		"selected_map": _selected_map,
	})
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _apply_button_style(button: Button, selected: bool, unlocked: bool) -> void:
	var normal := _flat_box(
		Color(GOLD, 0.13 if selected else (0.035 if unlocked else 0.018)),
		Color(GOLD, 0.66 if selected else (0.24 if unlocked else 0.12))
	)
	var hover := _flat_box(Color(GOLD, 0.18), Color(GOLD, 0.78))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", PAPER if unlocked else Color(MUTED, 0.44))
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.44))


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _card_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_stylebox_override("normal", _flat_box(
		Color(GOLD, 0.12 if primary else 0.04),
		Color(GOLD, 0.62 if primary else 0.24)
	))
	button.add_theme_stylebox_override("hover", _flat_box(Color(GOLD, 0.18), Color(GOLD, 0.72)))
	button.add_theme_stylebox_override("focus", _flat_box(Color(GOLD, 0.18), Color(GOLD, 0.72)))
	return button


func _character_card(character_id: String) -> Dictionary:
	var button := _card_button("", false)
	button.custom_minimum_size = Vector2(0, 54)
	button.tooltip_text = character_id
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", -1)
	margin.add_child(column)
	var title := _label("", 16, PAPER)
	title.name = "CharacterTitle"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var meta := _label("", 11, Color(MUTED, 0.86))
	meta.name = "CharacterMeta"
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(meta)
	return {"button": button, "title": title, "meta": meta}


func _flat_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	return box


func _panel_box(margin: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = PANEL_TEXTURE
	box.texture_margin_left = 28.0
	box.texture_margin_top = 28.0
	box.texture_margin_right = 28.0
	box.texture_margin_bottom = 28.0
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box
