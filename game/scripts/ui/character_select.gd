extends Control

const BackdropScript := preload("res://scripts/ui/menu_backdrop.gd")
const UIControls := preload("res://scripts/ui/ui_control_theme.gd")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.png")
const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.ttf")

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

	var title := _label(Locale.t("select.title"), 48, GOLD)
	title.position = Vector2(72, 34)
	add_child(title)
	var subtitle := _label(Locale.t("select.subtitle"), 18, Color(PAPER, 0.88))
	subtitle.position = Vector2(74, 92)
	add_child(subtitle)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.36)
	rule.position = Vector2(74, 124)
	rule.size = Vector2(710, 1)
	add_child(rule)
	_merit_label = _label("", 17, GOLD)
	_merit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_merit_label.position = Vector2(920, 50)
	_merit_label.size = Vector2(286, 30)
	add_child(_merit_label)

	_build_character_panel()
	_build_detail_panel()
	_build_footer()


func _build_character_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(72, 146)
	panel.size = Vector2(344, 500)
	panel.add_theme_stylebox_override("panel", _panel_box(26))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := _label(Locale.t("select.roster"), 19, MUTED)
	column.add_child(heading)
	for character_id in CHARACTER_ORDER:
		if not _characters.has(character_id):
			continue
		var entry := _characters[character_id] as Dictionary
		var button := _card_button("", false)
		button.name = "Character_%s" % character_id
		button.custom_minimum_size = Vector2(0, 59)
		button.pressed.connect(_select_character.bind(character_id))
		column.add_child(button)
		_char_buttons[character_id] = button


func _build_detail_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(440, 146)
	panel.size = Vector2(768, 500)
	panel.add_theme_stylebox_override("panel", _panel_box(30))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(248, 278)
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
	details.add_theme_constant_override("separation", 9)
	body.add_child(details)
	_name_label = _label("", 38, GOLD)
	details.add_child(_name_label)
	_alias_label = _label("", 20, PAPER)
	details.add_child(_alias_label)
	_role_label = _label("", 16, VERMILION)
	details.add_child(_role_label)
	var detail_rule := ColorRect.new()
	detail_rule.color = Color(GOLD, 0.22)
	detail_rule.custom_minimum_size = Vector2(0, 1)
	details.add_child(detail_rule)
	_note_label = _label("", 16, Color(PAPER, 0.88))
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.custom_minimum_size = Vector2(0, 92)
	details.add_child(_note_label)
	_loadout_label = _label("", 15, Color(MUTED, 0.94))
	_loadout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_map_description.position = Vector2(0, 0)
	_map_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_description.custom_minimum_size = Vector2(0, 46)
	column.add_child(_map_description)


func _build_footer() -> void:
	_begin_button = _card_button(Locale.t("select.begin"), true)
	_begin_button.name = "BeginButton"
	_begin_button.position = Vector2(1000, 656)
	_begin_button.size = Vector2(208, 48)
	_begin_button.pressed.connect(_begin_run)
	add_child(_begin_button)
	var back := _card_button(Locale.t("select.back"), false)
	back.name = "BackButton"
	back.position = Vector2(440, 656)
	back.size = Vector2(168, 48)
	back.pressed.connect(_back_to_menu)
	add_child(back)
	var hint := _label(Locale.t("select.hint"), 13, Color(MUTED, 0.62))
	hint.position = Vector2(626, 670)
	add_child(hint)


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
		var suffix := ""
		if not unlocked:
			suffix = " · %s" % Locale.t("select.lock", {"value": int(entry.get("unlock_merit", 0))})
		button.text = "%s · %s%s" % [
			_preset_name(entry),
			GameData.loc(entry, "preset_alias"),
			suffix,
		]
		button.disabled = not unlocked
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
	_portrait.texture = _forge_portrait(character)
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
	_begin_button.disabled = false


func _forge_portrait(character: Dictionary) -> Texture2D:
	var strip := GameData.texture(str(character.get("battle_idle", "")))
	if strip == null:
		return null
	var frames := maxi(1, int(character.get("battle_idle_frames", 1)))
	var frame_width := float(strip.get_width()) / float(frames)
	var atlas := AtlasTexture.new()
	atlas.atlas = strip
	atlas.region = Rect2(0.0, 0.0, frame_width, float(strip.get_height()))
	return atlas


func _preset_name(entry: Dictionary) -> String:
	var preset := GameData.loc(entry, "preset_name")
	return preset if not preset.is_empty() else GameData.loc(entry, "name")


func _is_unlocked(entry: Dictionary) -> bool:
	return int(SaveSystem.data.get("total_merit", 0)) >= int(entry.get("unlock_merit", 0))


func _begin_run() -> void:
	SaveSystem.data["selected_character"] = _selected_character
	SaveSystem.data["selected_map"] = _selected_map
	SaveSystem.begin_run()
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
