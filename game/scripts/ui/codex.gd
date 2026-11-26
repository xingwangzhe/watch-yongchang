extends Control

signal closed

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const VERMILION := Color("#c05a41")
const INK := Color("#081114")
const TEAL := Color("#7fb7a8")
const BLUE := Color("#79a9bf")
const PURPLE := Color("#9b7fbf")
const GREEN := Color("#9bc27e")

const TAB_SPECS := [
	{"id": "cards", "label": "codex.tab.cards", "accent": "#e1b35a"},
	{"id": "upgrades", "label": "codex.tab.upgrades", "accent": "#79a9bf"},
	{"id": "equipment", "label": "codex.tab.equipment", "accent": "#7fb7a8"},
	{"id": "weapons", "label": "codex.tab.weapons", "accent": "#d8a548"},
	{"id": "enemies", "label": "codex.tab.enemies", "accent": "#c05a41"},
	{"id": "maps", "label": "codex.tab.maps", "accent": "#79a9bf"},
	{"id": "history", "label": "codex.tab.history", "accent": "#d1ad62"},
]
const UPGRADE_FAMILY_SPECS := [
	{"id": "attributes", "label": "codex.upgrades.family.attributes", "accent": "#79a9bf"},
	{"id": "skills", "label": "codex.upgrades.family.skills", "accent": "#c05a41"},
	{"id": "events", "label": "codex.upgrades.family.events", "accent": "#9b7fbf"},
	{"id": "towers", "label": "codex.upgrades.family.towers", "accent": "#c9a04e"},
]
const RARITY_ORDER := ["legendary", "rare", "uncommon", "common"]
const TONE_ORDER := ["boon", "mixed", "risk"]
var _data: Dictionary = {}
var _characters: Dictionary = {}
var _weapons: Dictionary = {}
var _passives: Dictionary = {}
var _enemies: Dictionary = {}
var _maps: Dictionary = {}
var _mercenaries: Dictionary = {}
var _upgrades: Dictionary = {}
var _waves: Dictionary = {}
var _content: Control
var _scroll: ScrollContainer
var _page_host: VBoxContainer
var _tab_buttons: Dictionary = {}
var _detail_overlay: Control
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_subtitle: Label
var _detail_badges: HFlowContainer
var _detail_image_plate: PanelContainer
var _detail_image: TextureRect
var _detail_sections: VBoxContainer
var _detail_source: Label
var _detail_hint: Label
var _detail_close: Button
var _detail_scroll: ScrollContainer
var _zoom_hit: Button
var _zoom_overlay: Control
var _zoom_backdrop: Button
var _zoom_image: TextureRect
var _zoom_close: Button
var _zoom_hint: Label
var active_tab := "cards"
var embedded := false


func _ready() -> void:
	InputSetup.ensure_defaults()
	_load_catalog_data()
	var theme_res := Theme.new()
	theme_res.default_font = UI_FONT
	theme_res.default_font_size = 18
	theme = theme_res
	_build_backdrop()
	_content = Control.new()
	_content.name = "CodexContentRoot"
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_content)
	_build_detail_overlay()
	_rebuild()
	Locale.language_changed.connect(_on_language_changed)


func _load_catalog_data() -> void:
	_data = GameData.load_json("res://data/codex.json")
	_characters = GameData.get_characters()
	_weapons = GameData.get_weapons()
	_passives = GameData.get_passives()
	_enemies = GameData.get_enemies()
	_maps = GameData.get_maps()
	_mercenaries = GameData.get_mercenaries()
	_upgrades = GameData.load_json("res://data/upgrades.json")
	_waves = GameData.load_json("res://data/waves.json")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if zoom_is_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_codex"):
			close_zoom()
			get_viewport().set_input_as_handled()
		return
	if detail_is_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_codex"):
			close_detail()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_codex"):
		_return_to_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_cycle_tab(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_cycle_tab(1)
		get_viewport().set_input_as_handled()


func _on_language_changed(_code: String) -> void:
	_rebuild()


func current_tab_id() -> String:
	return active_tab


func select_tab(tab_id: String) -> void:
	if not _valid_tab(tab_id):
		return
	close_detail()
	active_tab = tab_id
	_update_tab_styles()
	_build_active_page()
	if _scroll != null:
		_scroll.scroll_vertical = 0


func card_entry_count() -> int:
	return _card_ids().size()


func detail_is_open() -> bool:
	return _detail_overlay != null and _detail_overlay.visible


func _rebuild() -> void:
	close_detail()
	if _detail_close != null:
		_detail_close.text = Locale.t("codex.detail.close")
		_detail_hint.text = Locale.t("codex.detail.hint")
	if _zoom_hit != null:
		_zoom_hit.tooltip_text = Locale.t("codex.detail.zoom_tip")
	if _zoom_hint != null:
		_zoom_hint.text = Locale.t("codex.zoom.hint")
	if _zoom_close != null:
		_zoom_close.text = Locale.t("codex.detail.close")
	if not _valid_tab(active_tab):
		active_tab = "cards"
	for child in _content.get_children():
		_content.remove_child(child)
		child.free()
	_tab_buttons.clear()
	_build_header()
	_build_tabs()
	_build_scroll_shell()
	_build_active_page()


func _valid_tab(tab_id: String) -> bool:
	for spec in TAB_SPECS:
		if str((spec as Dictionary).get("id", "")) == tab_id:
			return true
	return false


func _cycle_tab(direction: int) -> void:
	var ids: Array[String] = []
	for spec in TAB_SPECS:
		ids.append(str((spec as Dictionary).get("id", "")))
	var current := ids.find(active_tab)
	if current < 0:
		current = 0
	var next := posmod(current + direction, ids.size())
	select_tab(ids[next])


func _build_backdrop() -> void:
	var background := ColorRect.new()
	background.name = "CodexBackdrop"
	background.color = INK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in range(11):
		var line := ColorRect.new()
		line.color = Color(0.55, 0.45, 0.26, 0.042)
		line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		line.offset_left = 20.0
		line.offset_right = -20.0
		line.offset_top = 54.0 + float(index) * 64.0
		line.offset_bottom = line.offset_top + 1.0
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
	for index in range(10):
		var vertical := ColorRect.new()
		vertical.color = Color(0.55, 0.45, 0.26, 0.022)
		vertical.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		vertical.offset_left = 46.0 + float(index) * 132.0
		vertical.offset_right = vertical.offset_left + 1.0
		vertical.offset_top = 18.0
		vertical.offset_bottom = -18.0
		vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(vertical)


func _build_header() -> void:
	var title := _label(GameData.loc(_data, "title"), 38, GOLD)
	title.name = "CodexTitle"
	title.anchor_left = 0.0
	title.anchor_top = 0.0
	title.offset_left = 42.0
	title.offset_top = 18.0
	title.offset_right = 660.0
	title.offset_bottom = 64.0
	_content.add_child(title)
	var subtitle := _label(GameData.loc(_data, "subtitle"), 15, Color(PAPER, 0.84))
	subtitle.name = "CodexSubtitle"
	subtitle.offset_left = 44.0
	subtitle.offset_top = 66.0
	subtitle.offset_right = 930.0
	subtitle.offset_bottom = 92.0
	_content.add_child(subtitle)
	var back := _button(Locale.t("codex.back"), true)
	back.name = "CodexBack"
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	back.offset_left = -218.0
	back.offset_top = 28.0
	back.offset_right = -42.0
	back.offset_bottom = 70.0
	back.pressed.connect(_return_to_menu)
	_content.add_child(back)
	var hint := _label(Locale.t("codex.hint"), 11, Color(MUTED, 0.64))
	hint.name = "CodexHint"
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.offset_left = -520.0
	hint.offset_top = 77.0
	hint.offset_right = -42.0
	hint.offset_bottom = 96.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_content.add_child(hint)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.22)
	rule.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rule.offset_left = 42.0
	rule.offset_right = -42.0
	rule.offset_top = 108.0
	rule.offset_bottom = 109.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(rule)


func _build_tabs() -> void:
	var tab_bar := HBoxContainer.new()
	tab_bar.name = "CodexTabs"
	tab_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tab_bar.offset_left = 42.0
	tab_bar.offset_right = -42.0
	tab_bar.offset_top = 118.0
	tab_bar.offset_bottom = 166.0
	tab_bar.add_theme_constant_override("separation", 7)
	_content.add_child(tab_bar)
	for spec in TAB_SPECS:
		var tab_spec := spec as Dictionary
		var tab_id := str(tab_spec.get("id", ""))
		var label := Locale.t(str(tab_spec.get("label", "")))
		var count := _tab_count(tab_id)
		if count > 0:
			label = "%s  %d" % [label, count]
		var button := Button.new()
		button.name = "Tab%s" % tab_id.capitalize()
		button.text = label
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font", UI_FONT)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(select_tab.bind(tab_id))
		tab_bar.add_child(button)
		_tab_buttons[tab_id] = button
	_update_tab_styles()


func _tab_count(tab_id: String) -> int:
	match tab_id:
		"cards":
			return _card_ids().size()
		"upgrades":
			return _upgrade_card_count()
		"equipment":
			return _passives.size() + (_upgrades.get("attributes", {}) as Dictionary).size()
		"weapons":
			return _weapons.size()
		"enemies":
			return _enemies.size()
		"maps":
			return _maps.size() + (_upgrades.get("events", {}) as Dictionary).size()
	return 0


func _update_tab_styles() -> void:
	for raw_id in _tab_buttons.keys():
		var tab_id := str(raw_id)
		var button: Button = _tab_buttons[tab_id] as Button
		var active := tab_id == active_tab
		var fill := Color(GOLD, 0.92) if active else Color(0.035, 0.050, 0.050, 0.88)
		var border := Color(GOLD, 0.85) if active else Color(MUTED, 0.20)
		var font := INK if active else Color(PAPER, 0.86)
		button.add_theme_color_override("font_color", font)
		button.add_theme_color_override("font_hover_color", INK if active else PAPER)
		button.add_theme_stylebox_override("normal", _flat_box(fill, border, 4, 9))
		button.add_theme_stylebox_override(
			"hover",
			_flat_box(Color(GOLD, 0.24) if not active else Color(GOLD, 0.98), border, 4, 9)
		)
		button.add_theme_stylebox_override(
			"pressed",
			_flat_box(Color(GOLD, 0.30) if not active else GOLD, border, 4, 9)
		)


func _build_scroll_shell() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "CodexScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.focus_mode = Control.FOCUS_ALL
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 42.0
	_scroll.offset_right = -42.0
	_scroll.offset_top = 178.0
	_scroll.offset_bottom = -22.0
	_content.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 24)
	_scroll.add_child(margin)
	_page_host = VBoxContainer.new()
	_page_host.name = "CodexContent"
	_page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_host.add_theme_constant_override("separation", 16)
	margin.add_child(_page_host)


func _build_active_page() -> void:
	if _page_host == null:
		return
	for child in _page_host.get_children():
		_page_host.remove_child(child)
		child.free()
	match active_tab:
		"cards":
			_build_cards_page()
		"upgrades":
			_build_upgrades_page()
		"equipment":
			_build_equipment_page()
		"weapons":
			_build_weapons_page()
		"enemies":
			_build_enemies_page()
		"maps":
			_build_maps_page()
		"history":
			_build_history_page()


func _build_page_header(title_key: String, lead_key: String) -> void:
	var title := _label(Locale.t(title_key), 27, GOLD)
	title.name = "PageTitle"
	_page_host.add_child(title)
	var lead := _label(Locale.t(lead_key), 14, Color(PAPER, 0.82))
	lead.name = "PageLead"
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_host.add_child(lead)


func _build_cards_page() -> void:
	_build_page_header("codex.cards.title", "codex.cards.lead")
	var disclaimer := _label(Locale.t("codex.cards.disclaimer"), 12, Color(VERMILION, 0.88))
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_host.add_child(disclaimer)
	var read_more := _label(Locale.t("codex.cards.read_more"), 11, Color(MUTED, 0.72))
	read_more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_host.add_child(read_more)
	var grid := _grid(3, 14)
	var ids := _card_ids()
	for index in range(ids.size()):
		grid.add_child(_character_card(ids[index], index))
	_page_host.add_child(grid)
	_add_section_heading(Locale.t("codex.cards.allies_heading"), _mercenary_ids().size(), TEAL)
	var ally_lead := _label(Locale.t("codex.cards.allies_lead"), 13, Color(MUTED, 0.82))
	ally_lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_host.add_child(ally_lead)
	var ally_grid := _grid(4, 12)
	for mercenary_id in _mercenary_ids():
		ally_grid.add_child(_mercenary_card(mercenary_id))
	_page_host.add_child(ally_grid)
	_source_footer()


func _character_card(character_id: String, index: int) -> PanelContainer:
	var character: Dictionary = _characters[character_id] as Dictionary
	var panel := _card_panel(str(character.get("tint", "#e1b35a")))
	panel.name = "Card_%s" % character_id
	panel.custom_minimum_size = Vector2(0, 370)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var portrait_row := CenterContainer.new()
	portrait_row.add_child(_portrait(
		str(character.get("battle_idle", "")),
		int(character.get("battle_idle_frames", 1)),
		"Portrait_%s" % character_id,
		160,
		Color(str(character.get("tint", "#e1b35a")))
	))
	column.add_child(portrait_row)
	var title := _label(
		"%s · %s" % [
			GameData.loc(character, "name"),
			GameData.loc(character, "preset_name"),
		],
		22,
		PAPER
	)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var alias := _label(GameData.loc(character, "preset_alias"), 13, Color(MUTED, 0.88))
	alias.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alias.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(alias)
	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation", 6)
	badge_row.add_child(_badge(Locale.t("codex.cards.post", {"index": index + 1}), GOLD))
	var unlocked := int(SaveSystem.data.get("total_merit", 0)) >= int(character.get("unlock_merit", 0))
	badge_row.add_child(_badge(
		Locale.t("codex.unlocked" if unlocked else "codex.locked"),
		GREEN if unlocked else MUTED
	))
	column.add_child(badge_row)
	var stats := _label(
		Locale.t("codex.cards.stats", {
			"hp": _num(float(character.get("hp", 0.0))),
			"speed": _num(float(character.get("speed", 0.0))),
			"pickup": _num(float(character.get("pickup_radius", 0.0))),
			"oil": _num(float(character.get("oil_max", 0.0))),
		}),
		12,
		Color(BLUE, 0.92)
	)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(stats)
	var weapon := _weapons.get(str(character.get("starting_weapon", "")), {}) as Dictionary
	var passive := _passives.get(str(character.get("starting_passive", "")), {}) as Dictionary
	var loadout := _label(
		"%s\n%s" % [
			Locale.t("codex.cards.starter", {"weapon": GameData.loc(weapon, "name")}),
			Locale.t("codex.cards.passive", {"passive": GameData.loc(passive, "name")}),
		],
		12,
		Color(GOLD, 0.92)
	)
	loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(loadout)
	var note := _label(GameData.loc(character, "note"), 12, Color(PAPER, 0.80))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(note)
	var unlock_text := Locale.t("codex.cards.unlock_initial")
	if int(character.get("unlock_merit", 0)) > 0:
		unlock_text = Locale.t("codex.cards.unlock_merit", {"value": int(character.get("unlock_merit", 0))})
	column.add_child(_source_line("%s · %s" % [
		unlock_text,
		Locale.t("codex.cards.source", {"role": GameData.loc(character, "role")}),
	]))
	_attach_detail(panel, _character_detail(character, index, unlocked))
	return panel


func _character_detail(character: Dictionary, index: int, unlocked: bool) -> Dictionary:
	var weapon := _weapons.get(str(character.get("starting_weapon", "")), {}) as Dictionary
	var passive := _passives.get(str(character.get("starting_passive", "")), {}) as Dictionary
	var unlock_text := Locale.t("codex.cards.unlock_initial")
	if int(character.get("unlock_merit", 0)) > 0:
		unlock_text = Locale.t("codex.cards.unlock_merit", {
			"value": int(character.get("unlock_merit", 0)),
		})
	var stats_text := Locale.t("codex.cards.stats", {
		"hp": _num(float(character.get("hp", 0.0))),
		"speed": _num(float(character.get("speed", 0.0))),
		"pickup": _num(float(character.get("pickup_radius", 0.0))),
		"oil": _num(float(character.get("oil_max", 0.0))),
	})
	return {
		"title": "%s · %s" % [
			GameData.loc(character, "name"),
			GameData.loc(character, "preset_name"),
		],
		"subtitle": GameData.loc(character, "alias"),
		"accent": Color(str(character.get("tint", "#e1b35a"))),
		"image_path": str(character.get("battle_idle", "")),
		"image_frames": int(character.get("battle_idle_frames", 1)),
		"badges": [
			{"text": Locale.t("codex.cards.post", {"index": index + 1}), "color": GOLD},
			{"text": Locale.t("codex.unlocked" if unlocked else "codex.locked"), "color": GREEN if unlocked else MUTED},
			{"text": GameData.loc(character, "role"), "color": BLUE},
		],
		"sections": [
			{"heading": Locale.t("codex.detail.identity"), "body": GameData.loc(character, "note")},
			{"heading": Locale.t("codex.detail.stats"), "body": stats_text},
			{"heading": Locale.t("codex.detail.loadout"), "body": "%s\n%s" % [
				Locale.t("codex.cards.starter", {"weapon": GameData.loc(weapon, "name")}),
				Locale.t("codex.cards.passive", {"passive": GameData.loc(passive, "name")}),
			]},
			{"heading": Locale.t("codex.detail.unlock"), "body": unlock_text},
		],
		"source": Locale.t("codex.cards.source", {"role": GameData.loc(character, "role")}),
	}


func _mercenary_card(mercenary_id: String) -> PanelContainer:
	var mercenary: Dictionary = _mercenaries[mercenary_id] as Dictionary
	var panel := _card_panel("#7fb7a8")
	panel.name = "Ally_%s" % mercenary_id
	panel.custom_minimum_size = Vector2(0, 245)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 9)
	column.add_child(head)
	head.add_child(_portrait(
		str(mercenary.get("battle_idle", "")),
		int(mercenary.get("battle_idle_frames", 1)),
		"Portrait_%s" % mercenary_id,
		78,
		TEAL
	))
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 3)
	head.add_child(title_box)
	var title := _label(GameData.loc(mercenary, "name"), 17, PAPER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(title)
	var role := _label(GameData.loc(mercenary, "role"), 11, Color(TEAL, 0.94))
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(role)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 5)
	tags.add_child(_badge(
		Locale.t("codex.cards.ally_price", {"value": int(mercenary.get("price", 0))}),
		GOLD
	))
	var rarity := str(mercenary.get("rarity", "common"))
	tags.add_child(_badge(UpgradeCatalog.rarity_label(rarity), _rarity_color(rarity)))
	title_box.add_child(tags)
	var stats := _label(
		Locale.t("codex.cards.ally_stats", {
			"hp": _num(float(mercenary.get("hp", 0.0))),
			"speed": _num(float(mercenary.get("speed", 0.0))),
			"damage": _num(float(mercenary.get("damage", 0.0))),
			"range": _num(float(mercenary.get("attack_range", 0.0))),
		}),
		11,
		Color(BLUE, 0.92)
	)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(stats)
	var note_text := GameData.loc(mercenary, "shop_note")
	if note_text.is_empty():
		note_text = GameData.loc(mercenary, "description")
	var note := _label(note_text, 11, Color(PAPER, 0.82))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(note)
	var bonus := _party_bonus_text(mercenary.get("party_bonus", {}) as Dictionary)
	if not bonus.is_empty():
		column.add_child(_label(
			Locale.t("codex.cards.ally_bonus", {"bonus": bonus}),
			11,
			Color(GREEN, 0.92)
		))
	column.add_child(_source_line(GameData.source_label(mercenary)))
	_attach_detail(panel, _mercenary_detail(mercenary, note_text, bonus))
	return panel


func _mercenary_detail(mercenary: Dictionary, note_text: String, bonus: String) -> Dictionary:
	var stats_text := Locale.t("codex.cards.ally_stats", {
		"hp": _num(float(mercenary.get("hp", 0.0))),
		"speed": _num(float(mercenary.get("speed", 0.0))),
		"damage": _num(float(mercenary.get("damage", 0.0))),
		"range": _num(float(mercenary.get("attack_range", 0.0))),
	})
	var sections: Array = [
		{"heading": Locale.t("codex.detail.identity"), "body": GameData.loc(mercenary, "role")},
		{"heading": Locale.t("codex.detail.stats"), "body": stats_text},
		{"heading": Locale.t("codex.detail.description"), "body": note_text},
	]
	if not bonus.is_empty():
		sections.append({
			"heading": Locale.t("codex.detail.party_bonus"),
			"body": bonus,
		})
	return {
		"title": GameData.loc(mercenary, "name"),
		"subtitle": Locale.t("codex.cards.allies_heading"),
		"accent": TEAL,
		"image_path": str(mercenary.get("battle_idle", "")),
		"image_frames": int(mercenary.get("battle_idle_frames", 1)),
		"badges": [
			{"text": Locale.t("codex.cards.ally_price", {"value": int(mercenary.get("price", 0))}), "color": GOLD},
			{"text": UpgradeCatalog.rarity_label(str(mercenary.get("rarity", "common"))), "color": _rarity_color(str(mercenary.get("rarity", "common")))},
		],
		"sections": sections,
		"source": GameData.source_label(mercenary),
	}


func _build_upgrades_page() -> void:
	_build_page_header("codex.upgrades.title", "codex.upgrades.lead")
	var summary := _label(
		Locale.t("codex.upgrades.summary", {
			"cards": _upgrade_card_count(),
			"offers": _upgrade_offer_count(),
		}),
		13,
		Color(BLUE, 0.92)
	)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_host.add_child(summary)
	var rule := _label(Locale.t("codex.upgrades.rule"), 11, Color(GOLD, 0.82))
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_host.add_child(rule)
	for raw_spec in UPGRADE_FAMILY_SPECS:
		var spec := raw_spec as Dictionary
		var family := str(spec.get("id", ""))
		var entries := _upgrades.get(family, {}) as Dictionary
		if entries.is_empty():
			continue
		_add_section_heading(
			Locale.t(str(spec.get("label", ""))),
			entries.size(),
			Color(str(spec.get("accent", "#79a9bf")))
		)
		var ids: Array[String] = []
		for raw_id in entries.keys():
			ids.append(str(raw_id))
		ids.sort()
		var grid := _grid(3, 12)
		for card_id in ids:
			grid.add_child(_upgrade_card(family, card_id, entries[card_id] as Dictionary))
		_page_host.add_child(grid)
	_source_footer()


func _upgrade_card_count() -> int:
	var total := 0
	for raw_spec in UPGRADE_FAMILY_SPECS:
		var family := str((raw_spec as Dictionary).get("id", ""))
		total += (_upgrades.get(family, {}) as Dictionary).size()
	return total


func _upgrade_offer_count() -> int:
	var total := 0
	for raw_spec in UPGRADE_FAMILY_SPECS:
		var family := str((raw_spec as Dictionary).get("id", ""))
		var entries := _upgrades.get(family, {}) as Dictionary
		for definition in entries.values():
			total += int((definition as Dictionary).get("max_level", 1))
	return total


func _upgrade_family_spec(family: String) -> Dictionary:
	for raw_spec in UPGRADE_FAMILY_SPECS:
		var spec := raw_spec as Dictionary
		if str(spec.get("id", "")) == family:
			return spec
	return {}


func _upgrade_kind_label(family: String) -> String:
	var spec := _upgrade_family_spec(family)
	if spec.is_empty():
		return family
	return Locale.t(str(spec.get("label", "")))


func _upgrade_card(family: String, card_id: String, definition: Dictionary) -> PanelContainer:
	var spec := _upgrade_family_spec(family)
	var accent := Color(str(spec.get("accent", "#79a9bf")))
	var rarity := str(definition.get("rarity", "common"))
	var panel := _card_panel(str(spec.get("accent", "#79a9bf")))
	panel.name = "Upgrade_%s_%s" % [family, card_id]
	panel.custom_minimum_size = Vector2(0, 214)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 9)
	column.add_child(head)
	head.add_child(_icon_frame(str(definition.get("icon", "")), 46, accent))
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 3)
	head.add_child(title_box)
	var title := _label(GameData.loc(definition, "name"), 17, PAPER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(title)
	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 5)
	badges.add_child(_badge(_upgrade_kind_label(family), accent))
	badges.add_child(_badge(UpgradeCatalog.rarity_label(rarity), _rarity_color(rarity)))
	title_box.add_child(badges)
	column.add_child(_label(
		Locale.t("codex.upgrades.max", {"level": int(definition.get("max_level", 1))}),
		10,
		Color(MUTED, 0.82)
	))
	var description := _label(GameData.loc(definition, "desc"), 12, Color(PAPER, 0.86))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	var effects := _upgrade_effect_text(definition)
	if not effects.is_empty():
		var effect_label := _label(
			Locale.t("codex.upgrades.effect", {"effect": effects}),
			11,
			Color(BLUE, 0.92)
		)
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(effect_label)
	var culture_text := GameData.loc(definition, "culture")
	var culture := _label(culture_text, 11, Color(MUTED, 0.82))
	culture.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	culture.tooltip_text = culture_text
	culture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(culture)
	column.add_child(_source_line("%s · %s" % [
		Locale.t("codex.upgrades.source"),
		GameData.source_label(definition),
	]))
	_attach_detail(panel, _upgrade_detail(family, definition))
	return panel


func _upgrade_detail(family: String, definition: Dictionary) -> Dictionary:
	var spec := _upgrade_family_spec(family)
	var accent := Color(str(spec.get("accent", "#79a9bf")))
	var rarity := str(definition.get("rarity", "common"))
	var effects := _upgrade_effect_text(definition)
	var badges: Array = [
		{"text": _upgrade_kind_label(family), "color": accent},
		{"text": UpgradeCatalog.rarity_label(rarity), "color": _rarity_color(rarity)},
		{"text": Locale.t("codex.upgrades.max", {"level": int(definition.get("max_level", 1))}), "color": MUTED},
	]
	if family == "events":
		badges.append({"text": Locale.t("codex.upgrades.once"), "color": PURPLE})
	var sections: Array = [
		{"heading": Locale.t("codex.detail.description"), "body": GameData.loc(definition, "desc")},
	]
	if not effects.is_empty():
		sections.append({"heading": Locale.t("codex.detail.effect"), "body": effects})
	var category := _category_label(str(definition.get("category", "")))
	if not category.is_empty():
		badges.append({"text": category, "color": GOLD})
	sections.append({
		"heading": Locale.t("codex.detail.culture"),
		"body": GameData.loc(definition, "culture"),
	})
	sections.append({
		"heading": Locale.t("codex.detail.rule"),
		"body": Locale.t("codex.upgrades.detail_rule"),
	})
	return {
		"title": GameData.loc(definition, "name"),
		"subtitle": _upgrade_kind_label(family),
		"accent": accent,
		"icon_path": str(definition.get("icon", "")),
		"badges": badges,
		"sections": sections,
		"source": GameData.source_label(definition),
	}


func _upgrade_effect_text(definition: Dictionary) -> String:
	var effects := UpgradeCatalog.effect_summary(definition, 1)
	if effects.contains("skill.") or effects.contains("event."):
		return ""
	return effects


func _build_equipment_page() -> void:
	_build_page_header("codex.equipment.title", "codex.equipment.lead")
	_add_section_heading(Locale.t("codex.equipment.shop_heading"), _passives.size(), TEAL)
	var passive_grid := _grid(3, 12)
	var passive_ids: Array[String] = []
	for raw_id in _passives.keys():
		passive_ids.append(str(raw_id))
	passive_ids.sort()
	for passive_id in passive_ids:
		passive_grid.add_child(_passive_card(passive_id))
	_page_host.add_child(passive_grid)
	var attributes := _upgrades.get("attributes", {}) as Dictionary
	_add_section_heading(Locale.t("codex.equipment.trait_heading"), attributes.size(), GOLD)
	for rarity in RARITY_ORDER:
		var ids: Array[String] = []
		for raw_id in attributes.keys():
			var definition := attributes[raw_id] as Dictionary
			if str(definition.get("rarity", "common")) == rarity:
				ids.append(str(raw_id))
		if ids.is_empty():
			continue
		ids.sort()
		var rarity_row := HBoxContainer.new()
		rarity_row.add_theme_constant_override("separation", 9)
		rarity_row.add_child(_badge(
			UpgradeCatalog.rarity_label(rarity),
			_rarity_color(rarity)
		))
		rarity_row.add_child(_label(
			Locale.t("codex.count", {"count": ids.size()}),
			12,
			Color(MUTED, 0.72)
		))
		_page_host.add_child(rarity_row)
		var rarity_grid := _grid(3, 12)
		for attribute_id in ids:
			rarity_grid.add_child(_attribute_card(attribute_id, attributes[attribute_id] as Dictionary))
		_page_host.add_child(rarity_grid)
	_source_footer()


func _passive_card(passive_id: String) -> PanelContainer:
	var passive: Dictionary = _passives[passive_id] as Dictionary
	var panel := _card_panel("#7fb7a8")
	panel.name = "GearPassive_%s" % passive_id
	panel.custom_minimum_size = Vector2(0, 184)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	head.add_child(_icon_frame(str(passive.get("icon", "")), 52, TEAL))
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 4)
	head.add_child(title_box)
	var title := _label(GameData.loc(passive, "name"), 17, PAPER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(title)
	title_box.add_child(_badge(
		Locale.t("codex.equipment.max", {"level": int(passive.get("max_level", 1))}),
		TEAL
	))
	var description := _label(GameData.loc(passive, "description"), 12, Color(PAPER, 0.84))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(description)
	column.add_child(_source_line("%s · %s" % [
		Locale.t("codex.equipment.shop_source"),
		GameData.source_label(passive),
	]))
	_attach_detail(panel, {
		"title": GameData.loc(passive, "name"),
		"subtitle": Locale.t("codex.equipment.shop_heading"),
		"accent": TEAL,
		"icon_path": str(passive.get("icon", "")),
		"badges": [
			{"text": Locale.t("codex.equipment.max", {"level": int(passive.get("max_level", 1))}), "color": TEAL},
		],
		"sections": [
			{"heading": Locale.t("codex.detail.description"), "body": GameData.loc(passive, "description")},
			{"heading": Locale.t("codex.detail.culture"), "body": GameData.loc(passive, "culture")},
		],
		"source": GameData.source_label(passive),
	})
	return panel


func _attribute_card(attribute_id: String, definition: Dictionary) -> PanelContainer:
	var rarity := str(definition.get("rarity", "common"))
	var panel := _card_panel("#7fb7a8")
	panel.name = "GearTrait_%s" % attribute_id
	panel.custom_minimum_size = Vector2(0, 168)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 9)
	column.add_child(head)
	head.add_child(_icon_frame(str(definition.get("icon", "")), 44, _rarity_color(rarity)))
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 3)
	head.add_child(title_box)
	var title := _label(GameData.loc(definition, "name"), 16, PAPER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(title)
	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 5)
	badges.add_child(_badge(UpgradeCatalog.rarity_label(rarity), _rarity_color(rarity)))
	badges.add_child(_badge(
		Locale.t("codex.equipment.max", {"level": int(definition.get("max_level", 1))}),
		Color(MUTED, 0.82)
	))
	title_box.add_child(badges)
	var category := str(definition.get("category", ""))
	if not category.is_empty():
		column.add_child(_label(_category_label(category), 10, Color(MUTED, 0.74)))
	var description := _label(GameData.loc(definition, "desc"), 12, Color(PAPER, 0.86))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(description)
	column.add_child(_source_line("%s · %s" % [
		Locale.t("codex.equipment.trait_source"),
		GameData.source_label(definition),
	]))
	_attach_detail(panel, _upgrade_detail("attributes", definition))
	return panel


func _build_weapons_page() -> void:
	_build_page_header("codex.weapons.title", "codex.weapons.lead")
	var starters := _starter_posts_by_weapon()
	var grid := _grid(2, 14)
	for weapon_id in _ordered_ids(_data.get("weapon_order", []) as Array, _weapons):
		grid.add_child(_weapon_card(weapon_id, starters))
	_page_host.add_child(grid)
	_source_footer()


func _starter_posts_by_weapon() -> Dictionary:
	var result: Dictionary = {}
	for character_id in _card_ids():
		var character: Dictionary = _characters[character_id] as Dictionary
		var weapon_id := str(character.get("starting_weapon", ""))
		if weapon_id.is_empty():
			continue
		if not result.has(weapon_id):
			result[weapon_id] = []
		var posts: Array = result[weapon_id] as Array
		posts.append(GameData.loc(character, "preset_name"))
	return result


func _weapon_card(weapon_id: String, starters: Dictionary) -> PanelContainer:
	var weapon: Dictionary = _weapons[weapon_id] as Dictionary
	var panel := _card_panel("#d8a548")
	panel.name = "Weapon_%s" % weapon_id
	panel.custom_minimum_size = Vector2(0, 286)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	column.add_child(head)
	head.add_child(_icon_frame(str(weapon.get("icon", "")), 68, GOLD))
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 4)
	head.add_child(title_box)
	var title := _label(GameData.loc(weapon, "name"), 21, PAPER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(title)
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 6)
	badge_row.add_child(_badge(_weapon_type_label(str(weapon.get("type", ""))), GOLD))
	var starter_posts: Array = starters.get(weapon_id, []) as Array
	if not starter_posts.is_empty():
		badge_row.add_child(_badge(
			"%s：%s" % [Locale.t("codex.weapons.starter"), ", ".join(starter_posts)],
			GREEN
		))
	title_box.add_child(badge_row)
	var stats := _label(
		Locale.t("codex.weapons.stats", {
			"damage": _num(float(weapon.get("damage", 0.0))),
			"cooldown": _num(float(weapon.get("cooldown", 0.0))),
			"range": _num(float(weapon.get("range", 0.0))),
		}),
		12,
		Color(BLUE, 0.94)
	)
	column.add_child(stats)
	var description := _label(GameData.loc(weapon, "description"), 13, Color(PAPER, 0.88))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	var evolution := _label(_weapon_evolution_text(weapon), 12, Color(GOLD, 0.92))
	evolution.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evolution.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(evolution)
	var culture := _label(GameData.loc(weapon, "culture"), 11, Color(MUTED, 0.82))
	culture.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	culture.tooltip_text = GameData.loc(weapon, "culture")
	column.add_child(culture)
	column.add_child(_source_line("%s · %s" % [
		Locale.t("codex.weapons.source"),
		GameData.source_label(weapon),
	]))
	var detail_badges: Array = [
		{"text": _weapon_type_label(str(weapon.get("type", ""))), "color": GOLD},
	]
	if not starter_posts.is_empty():
		detail_badges.append({
			"text": "%s：%s" % [Locale.t("codex.weapons.starter"), ", ".join(starter_posts)],
			"color": GREEN,
		})
	_attach_detail(panel, {
		"title": GameData.loc(weapon, "name"),
		"subtitle": _weapon_type_label(str(weapon.get("type", ""))),
		"accent": GOLD,
		"icon_path": str(weapon.get("icon", "")),
		"badges": detail_badges,
		"sections": [
			{"heading": Locale.t("codex.detail.description"), "body": GameData.loc(weapon, "description")},
			{"heading": Locale.t("codex.detail.stats"), "body": Locale.t("codex.weapons.stats", {
				"damage": _num(float(weapon.get("damage", 0.0))),
				"cooldown": _num(float(weapon.get("cooldown", 0.0))),
				"range": _num(float(weapon.get("range", 0.0))),
			})},
			{"heading": Locale.t("codex.detail.evolution"), "body": _weapon_evolution_text(weapon)},
			{"heading": Locale.t("codex.detail.culture"), "body": GameData.loc(weapon, "culture")},
		],
		"source": GameData.source_label(weapon),
	})
	return panel


func _weapon_evolution_text(weapon: Dictionary) -> String:
	var evolution_name := GameData.loc(weapon, "evolve_name")
	if evolution_name.is_empty():
		return Locale.t("codex.weapons.final")
	var passive := _passives.get(str(weapon.get("evolve_passive", "")), {}) as Dictionary
	var lines: Array[String] = [Locale.t("codex.weapons.evolve", {"name": evolution_name})]
	if not passive.is_empty():
		lines.append(Locale.t("codex.weapons.evolve_need", {
			"passive": GameData.loc(passive, "name"),
		}))
	var evolution_description := GameData.loc(weapon, "evolve_description")
	if not evolution_description.is_empty():
		lines.append(evolution_description)
	return "\n".join(lines)


func _weapon_type_label(weapon_type: String) -> String:
	var key := "codex.weapons.type.%s" % weapon_type
	var translated := Locale.t(key)
	return translated if translated != key else weapon_type


func _build_enemies_page() -> void:
	_build_page_header("codex.enemies.title", "codex.enemies.lead")
	var normal_ids: Array[String] = []
	var elite_ids: Array[String] = []
	for enemy_id in _enemy_ids():
		var tier := _enemy_tier(enemy_id)
		if tier == "normal":
			normal_ids.append(enemy_id)
		else:
			elite_ids.append(enemy_id)
	_add_section_heading(Locale.t("codex.enemies.normal_heading"), normal_ids.size(), VERMILION)
	var normal_grid := _grid(2, 14)
	for enemy_id in normal_ids:
		normal_grid.add_child(_enemy_card(enemy_id))
	_page_host.add_child(normal_grid)
	_add_section_heading(Locale.t("codex.enemies.elite_heading"), elite_ids.size(), GOLD)
	var elite_grid := _grid(2, 14)
	for enemy_id in elite_ids:
		elite_grid.add_child(_enemy_card(enemy_id))
	_page_host.add_child(elite_grid)
	_source_footer()


func _enemy_card(enemy_id: String) -> PanelContainer:
	var enemy: Dictionary = _enemies[enemy_id] as Dictionary
	var tier := _enemy_tier(enemy_id)
	var accent := GOLD if tier != "normal" else VERMILION
	var panel := _card_panel("#e1b35a" if tier != "normal" else "#c05a41")
	panel.name = "Enemy_%s" % enemy_id
	panel.custom_minimum_size = Vector2(0, 258)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 13)
	column.add_child(head)
	head.add_child(_portrait(
		str(enemy.get("texture", "")),
		int(enemy.get("sprite_frames", 1)),
		"Portrait_%s" % enemy_id,
		116,
		accent
	))
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 5)
	head.add_child(title_box)
	var title := _label(GameData.loc(enemy, "name"), 21, PAPER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(title)
	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 6)
	badges.add_child(_badge(Locale.t("codex.enemies.tier.%s" % tier), accent))
	badges.add_child(_badge(
		Locale.t("codex.enemies.first_seen", {"time": _time_label(_first_enemy_seconds(enemy_id))}),
		Color(MUTED, 0.84)
	))
	if float(enemy.get("armor", 0.0)) > 0.0:
		badges.add_child(_badge(
			Locale.t("codex.enemies.armor", {"value": _num(float(enemy.get("armor", 0.0)) * 100.0)}),
			BLUE
		))
	title_box.add_child(badges)
	var stats := _label(
		Locale.t("codex.enemies.stats", {
			"hp": _num(float(enemy.get("hp", 0.0))),
			"speed": _num(float(enemy.get("speed", 0.0))),
			"damage": _num(float(enemy.get("damage", 0.0))),
			"xp": _num(float(enemy.get("xp", 0.0))),
		}),
		12,
		Color(BLUE, 0.94)
	)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(stats)
	var attack := _label(_enemy_attack_text(enemy), 11, Color(PAPER, 0.76))
	attack.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(attack)
	var tip_entry: Dictionary = (
		(_data.get("enemy_tips", {}) as Dictionary).get(enemy_id, {}) as Dictionary
	)
	var tip := _label(
		Locale.t("codex.enemies.tip", {"tip": GameData.loc(tip_entry, "tip")}),
		12,
		Color(GOLD, 0.88)
	)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tip)
	column.add_child(_source_line(Locale.t("codex.enemies.source")))
	_attach_detail(panel, _enemy_detail(enemy_id, enemy, tip_entry, tier, accent))
	return panel


func _enemy_detail(
	enemy_id: String,
	enemy: Dictionary,
	tip_entry: Dictionary,
	tier: String,
	accent: Color
) -> Dictionary:
	var badges: Array = [
		{"text": Locale.t("codex.enemies.tier.%s" % tier), "color": accent},
		{"text": Locale.t("codex.enemies.first_seen", {"time": _time_label(_first_enemy_seconds(enemy_id))}), "color": MUTED},
	]
	if float(enemy.get("armor", 0.0)) > 0.0:
		badges.append({
			"text": Locale.t("codex.enemies.armor", {"value": _num(float(enemy.get("armor", 0.0)) * 100.0)}),
			"color": BLUE,
		})
	return {
		"title": GameData.loc(enemy, "name"),
		"subtitle": Locale.t("codex.enemies.lead"),
		"accent": accent,
		"image_path": str(enemy.get("texture", "")),
		"image_frames": int(enemy.get("sprite_frames", 1)),
		"badges": badges,
		"sections": [
			{"heading": Locale.t("codex.detail.stats"), "body": Locale.t("codex.enemies.stats", {
				"hp": _num(float(enemy.get("hp", 0.0))),
				"speed": _num(float(enemy.get("speed", 0.0))),
				"damage": _num(float(enemy.get("damage", 0.0))),
				"xp": _num(float(enemy.get("xp", 0.0))),
			})},
			{"heading": Locale.t("codex.detail.tactics"), "body": "%s\n%s" % [
				_enemy_attack_text(enemy),
				Locale.t("codex.enemies.tip", {"tip": GameData.loc(tip_entry, "tip")}),
			]},
			{"heading": Locale.t("codex.detail.record"), "body": Locale.t("codex.enemies.source")},
		],
		"source": "",
	}


func _enemy_ids() -> Array[String]:
	return _ordered_ids(_data.get("enemy_order", []) as Array, _enemies)


func _enemy_tier(enemy_id: String) -> String:
	var enemy: Dictionary = _enemies.get(enemy_id, {}) as Dictionary
	match str(enemy.get("behavior", "chase")):
		"boss":
			return "boss"
		"elite":
			return "elite"
	return "normal"


func _first_enemy_seconds(enemy_id: String) -> float:
	if enemy_id == "daimyo":
		return float(_waves.get("boss_second", 930.0))
	var best := 1.0e20
	for raw_phase in _waves.get("phases", []) as Array:
		var phase := raw_phase as Dictionary
		for raw_mix in phase.get("mix", []) as Array:
			var mix := raw_mix as Dictionary
			if str(mix.get("id", "")) == enemy_id:
				best = minf(best, float(phase.get("start", best)))
	for raw_event in _waves.get("scale_events", []) as Array:
		var scale_event := raw_event as Dictionary
		if str(scale_event.get("enemy", "")) == enemy_id:
			best = minf(best, float(scale_event.get("t", best)))
	return best


func _enemy_attack_text(enemy: Dictionary) -> String:
	var behavior := str(enemy.get("behavior", "chase"))
	var parts: Array[String] = [Locale.t("codex.enemies.behavior.%s" % behavior)]
	if enemy.has("attack_range"):
		parts.append(Locale.t("codex.enemies.range", {
			"value": _num(float(enemy.get("attack_range", 0.0))),
		}))
	if enemy.has("aura_radius"):
		parts.append(Locale.t("codex.enemies.aura", {
			"value": _num(float(enemy.get("aura_radius", 0.0))),
		}))
	if enemy.has("charge_cooldown"):
		parts.append(Locale.t("codex.enemies.charge", {
			"value": _num(float(enemy.get("charge_cooldown", 0.0))),
		}))
	return " · ".join(parts)


func _build_maps_page() -> void:
	_build_page_header("codex.maps.title", "codex.maps.lead")
	_add_section_heading(Locale.t("codex.tab.maps"), _maps.size(), BLUE)
	var map_grid := _grid(3, 14)
	for map_id in _ordered_ids(_data.get("map_order", []) as Array, _maps):
		map_grid.add_child(_map_card(map_id))
	_page_host.add_child(map_grid)
	var events := _upgrades.get("events", {}) as Dictionary
	_add_section_heading(
		Locale.t("codex.maps.encounters_heading", {"count": events.size()}),
		events.size(),
		PURPLE
	)
	var encounters_lead := _label(Locale.t("codex.maps.encounters_lead"), 13, Color(MUTED, 0.82))
	encounters_lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_host.add_child(encounters_lead)
	var encounter_grid := _grid(3, 12)
	for event_id in _encounter_ids(events):
		encounter_grid.add_child(_encounter_card(event_id, events[event_id] as Dictionary))
	_page_host.add_child(encounter_grid)
	_source_footer()


func _map_card(map_id: String) -> PanelContainer:
	var map: Dictionary = _maps[map_id] as Dictionary
	var panel := _card_panel("#79a9bf")
	panel.name = "Map_%s" % map_id
	panel.custom_minimum_size = Vector2(0, 278)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	var title := _label(GameData.loc(map, "name"), 22, PAPER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var subtitle := _label(GameData.loc(map, "subtitle"), 12, Color(BLUE, 0.94))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	var unlock_value := int(map.get("unlock_merit", 0))
	column.add_child(_badge(
		Locale.t("codex.maps.unlock_initial" if unlock_value <= 0 else "codex.maps.unlock_merit", {
			"value": unlock_value,
		}),
		GREEN if unlock_value <= 0 else GOLD
	))
	var stats := _label(
		Locale.t("codex.maps.stats", {
			"speed": _ratio(float(map.get("enemy_speed_mult", 1.0))),
			"hp": _ratio(float(map.get("enemy_hp_mult", 1.0))),
			"spawn": _ratio(float(map.get("spawn_rate_mult", 1.0))),
		}),
		12,
		Color(PAPER, 0.86)
	)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(stats)
	column.add_child(_label(
		"%s · %s" % [
			Locale.t("codex.maps.oil", {"value": int(map.get("oil_interval", 30))}),
			Locale.t("codex.maps.light", {"value": _ratio(float(map.get("light_scale", 1.0)))}),
		],
		11,
		Color(BLUE, 0.88)
	))
	var description := _label(GameData.loc(map, "description"), 12, Color(PAPER, 0.80))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	var landmarks := _map_landmarks_text(map)
	if not landmarks.is_empty():
		var landmarks_label := _label(
			Locale.t("codex.maps.landmarks", {"names": landmarks}),
			11,
			Color(MUTED, 0.82)
		)
		landmarks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(landmarks_label)
	var tip_entry: Dictionary = (
		(_data.get("map_tips", {}) as Dictionary).get(map_id, {}) as Dictionary
	)
	var tip := _label(GameData.loc(tip_entry, "tip"), 12, Color(GOLD, 0.88))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tip)
	_attach_detail(panel, _map_detail(map, tip_entry))
	return panel


func _map_detail(map: Dictionary, tip_entry: Dictionary) -> Dictionary:
	var unlock_value := int(map.get("unlock_merit", 0))
	var badges: Array = [
		{
			"text": Locale.t("codex.maps.unlock_initial" if unlock_value <= 0 else "codex.maps.unlock_merit", {
				"value": unlock_value,
			}),
			"color": GREEN if unlock_value <= 0 else GOLD,
		},
	]
	var landmarks := _map_landmarks_text(map)
	if not landmarks.is_empty():
		badges.append({"text": Locale.t("codex.maps.landmarks", {"names": landmarks}), "color": BLUE})
	return {
		"title": GameData.loc(map, "name"),
		"subtitle": GameData.loc(map, "subtitle"),
		"accent": BLUE,
		"badges": badges,
		"sections": [
			{"heading": Locale.t("codex.detail.description"), "body": GameData.loc(map, "description")},
			{"heading": Locale.t("codex.detail.stats"), "body": "%s\n%s" % [
				Locale.t("codex.maps.stats", {
					"speed": _ratio(float(map.get("enemy_speed_mult", 1.0))),
					"hp": _ratio(float(map.get("enemy_hp_mult", 1.0))),
					"spawn": _ratio(float(map.get("spawn_rate_mult", 1.0))),
				}),
				"%s · %s" % [
					Locale.t("codex.maps.oil", {"value": int(map.get("oil_interval", 30))}),
					Locale.t("codex.maps.light", {"value": _ratio(float(map.get("light_scale", 1.0)))}),
				],
			]},
			{"heading": Locale.t("codex.detail.tactics"), "body": GameData.loc(tip_entry, "tip")},
		],
		"source": "",
	}


func _map_landmarks_text(map: Dictionary) -> String:
	var layout := map.get("layout", {}) as Dictionary
	var landmarks: Array = layout.get("landmarks", []) as Array
	var names: Array[String] = []
	for raw_landmark in landmarks:
		if names.size() >= 4:
			break
		var landmark := raw_landmark as Dictionary
		var name := GameData.loc(landmark, "name")
		if not name.is_empty():
			names.append(name)
	if landmarks.size() > names.size():
		names.append("…")
	return ", ".join(names)


func _encounter_ids(events: Dictionary) -> Array[String]:
	var grouped: Dictionary = {}
	for raw_id in events.keys():
		var tone := _event_tone(str(raw_id))
		if not grouped.has(tone):
			grouped[tone] = []
		(grouped[tone] as Array).append(str(raw_id))
	var result: Array[String] = []
	for tone in TONE_ORDER:
		var ids: Array = grouped.get(tone, []) as Array
		ids.sort()
		for raw_id in ids:
			result.append(str(raw_id))
	return result


func _event_tone(event_id: String) -> String:
	return str((_data.get("encounter_tones", {}) as Dictionary).get(event_id, "mixed"))


func _encounter_card(event_id: String, definition: Dictionary) -> PanelContainer:
	var rarity := str(definition.get("rarity", "common"))
	var tone := _event_tone(event_id)
	var tone_color := _tone_color(tone)
	var panel := _card_panel("#9b7fbf")
	panel.name = "Event_%s" % event_id
	panel.custom_minimum_size = Vector2(0, 206)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 9)
	column.add_child(head)
	head.add_child(_icon_frame(str(definition.get("icon", "")), 48, tone_color))
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 4)
	head.add_child(title_box)
	var title := _label(GameData.loc(definition, "name"), 17, PAPER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(title)
	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 5)
	badges.add_child(_badge(Locale.t("codex.maps.tone.%s" % tone), tone_color))
	badges.add_child(_badge(UpgradeCatalog.rarity_label(rarity), _rarity_color(rarity)))
	title_box.add_child(badges)
	var description := _label(GameData.loc(definition, "desc"), 12, Color(PAPER, 0.86))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	var effects := UpgradeCatalog.effect_summary(definition, 1)
	if not effects.is_empty():
		var effect_label := _label(effects, 11, Color(BLUE, 0.90))
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(effect_label)
	var culture := _label(GameData.loc(definition, "culture"), 11, Color(MUTED, 0.82))
	culture.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	culture.tooltip_text = GameData.loc(definition, "culture")
	culture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(culture)
	column.add_child(_source_line("%s · %s" % [
		Locale.t("codex.maps.encounter_source"),
		GameData.source_label(definition),
	]))
	var detail := _upgrade_detail("events", definition)
	detail["subtitle"] = Locale.t("codex.maps.encounters_heading", {"count": 1})
	detail["accent"] = tone_color
	var detail_badges := detail.get("badges", []) as Array
	detail_badges.push_front({"text": Locale.t("codex.maps.tone.%s" % tone), "color": tone_color})
	detail["badges"] = detail_badges
	_attach_detail(panel, detail)
	return panel


func _tone_color(tone: String) -> Color:
	match tone:
		"boon":
			return GREEN
		"risk":
			return VERMILION
	return PURPLE


func _build_history_page() -> void:
	_build_page_header("codex.history.title", "codex.history.lead")
	var facts := " · ".join(_localized_array(_data, "facts"))
	if not facts.is_empty():
		var facts_label := _label(facts, 12, Color(MUTED, 0.82))
		facts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_page_host.add_child(facts_label)
	var grid := _grid(3, 14)
	grid.add_child(_history_panel(_data.get("left", {}) as Dictionary, Color("#d1ad62"), "HistoryLeft"))
	grid.add_child(_bridge_panel())
	grid.add_child(_history_panel(_data.get("right", {}) as Dictionary, Color("#b95a43"), "HistoryRight"))
	_page_host.add_child(grid)
	var culture_sections := _data.get("culture_sections", []) as Array
	_add_section_heading(Locale.t("codex.history.deep_heading"), culture_sections.size(), PURPLE)
	var deep_lead := _label(Locale.t("codex.history.deep_lead"), 13, Color(PAPER, 0.82))
	deep_lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_host.add_child(deep_lead)
	var culture_grid := _grid(2, 14)
	for raw_section in culture_sections:
		culture_grid.add_child(_culture_card(raw_section as Dictionary))
	_page_host.add_child(culture_grid)
	_add_section_heading(Locale.t("codex.timeline"), (_data.get("timeline", []) as Array).size(), GOLD)
	var timeline_grid := _grid(3, 10)
	for raw_entry in _data.get("timeline", []) as Array:
		var entry := raw_entry as Dictionary
		var panel := _flat_panel(Color(0.045, 0.058, 0.058, 0.92), Color(GOLD, 0.20))
		panel.name = "Timeline_%s" % str(entry.get("year", ""))
		panel.custom_minimum_size = Vector2(0, 104)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		panel.add_child(column)
		var year := _label(str(entry.get("year", "")), 20, GOLD)
		year.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(year)
		var text := _label(str(entry.get(
			"zh" if Locale.current == "zh" else "en",
			entry.get("zh", "")
		)), 12, Color(PAPER, 0.82))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(text)
		_attach_detail(panel, _timeline_detail(entry))
		timeline_grid.add_child(panel)
	_page_host.add_child(timeline_grid)
	_add_section_heading(Locale.t("codex.sources"), _localized_array(_data, "sources").size(), MUTED)
	var sources := _label(" · ".join(_localized_array(_data, "sources")), 11, Color(MUTED, 0.74))
	sources.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_host.add_child(sources)


func _culture_card(section: Dictionary) -> PanelContainer:
	var category_key := str(section.get("category_zh", ""))
	var accent := _culture_accent(category_key)
	var panel := _flat_panel(Color(0.045, 0.058, 0.058, 0.94), Color(accent, 0.34))
	panel.name = "Culture_%s" % str(section.get("id", ""))
	panel.custom_minimum_size = Vector2(0, 252)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 7)
	badge_row.add_child(_badge(GameData.loc(section, "category"), accent))
	badge_row.add_child(_badge(Locale.t("codex.history.read_more"), Color(MUTED, 0.84)))
	column.add_child(badge_row)
	var title := _label(GameData.loc(section, "title"), 21, accent)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(accent, 0.28)
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)
	var body_text := GameData.loc(section, "body")
	var body := _label(body_text, 12, Color(PAPER, 0.88))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = body_text
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	column.add_child(_source_line(GameData.source_label(section)))
	_attach_detail(panel, {
		"title": GameData.loc(section, "title"),
		"subtitle": GameData.loc(section, "category"),
		"accent": accent,
		"badges": [
			{"text": GameData.loc(section, "category"), "color": accent},
			{"text": Locale.t("codex.history.deep_heading"), "color": GOLD},
		],
		"sections": [
			{"heading": Locale.t("codex.detail.record"), "body": body_text},
		],
		"source": GameData.source_label(section),
	})
	return panel


func _culture_accent(category: String) -> Color:
	match category:
		"史实":
			return GOLD
		"制度":
			return BLUE
		"民俗":
			return TEAL
		"演绎":
			return PURPLE
	return MUTED


func _history_detail(section: Dictionary, accent: Color) -> Dictionary:
	var points: Array[String] = []
	for raw_point in _localized_array(section, "points"):
		points.append("· %s" % str(raw_point))
	return {
		"title": GameData.loc(section, "title"),
		"subtitle": GameData.loc(section, "lead"),
		"accent": accent,
		"badges": [
			{"text": Locale.t("codex.history.deep_heading"), "color": accent},
		],
		"sections": [
			{"heading": Locale.t("codex.detail.record"), "body": GameData.loc(section, "lead")},
			{"heading": Locale.t("codex.detail.timeline"), "body": "\n".join(points)},
		],
		"source": GameData.source_label(section),
	}


func _timeline_detail(entry: Dictionary) -> Dictionary:
	var body := str(entry.get("zh" if Locale.current == "zh" else "en", entry.get("zh", "")))
	return {
		"title": str(entry.get("year", "")),
		"subtitle": body,
		"accent": GOLD,
		"badges": [
			{"text": Locale.t("codex.timeline"), "color": GOLD},
		],
		"sections": [
			{"heading": Locale.t("codex.detail.timeline"), "body": body},
		],
		"source": "",
	}


func _history_panel(section: Dictionary, accent: Color, node_name: String) -> PanelContainer:
	var panel := _flat_panel(Color(0.045, 0.058, 0.058, 0.92), Color(accent, 0.34))
	panel.name = node_name
	panel.custom_minimum_size = Vector2(0, 330)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := _label(GameData.loc(section, "title"), 21, accent)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(accent, 0.32)
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)
	var lead := _label(GameData.loc(section, "lead"), 13, PAPER)
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(lead)
	for raw_point in _localized_array(section, "points"):
		var point := _label("· %s" % str(raw_point), 11, Color(PAPER, 0.84))
		point.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(point)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grow)
	column.add_child(_source_line(GameData.source_label(section)))
	_attach_detail(panel, _history_detail(section, accent))
	return panel


func _bridge_panel() -> PanelContainer:
	var bridge := _data.get("bridge", {}) as Dictionary
	var panel := _flat_panel(Color(0.060, 0.064, 0.054, 0.96), Color(GOLD, 0.42))
	panel.name = "HistoryBridge"
	panel.custom_minimum_size = Vector2(0, 330)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := _label(GameData.loc(bridge, "title"), 20, GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.32)
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)
	var body := _label(GameData.loc(bridge, "body"), 13, PAPER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	var chain := _label(Locale.t("codex.chain"), 12, Color(GOLD, 0.92))
	chain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(chain)
	var forbidden := _label("%s：%s" % [
		Locale.t("codex.forbidden"),
		GameData.loc(_data, "do_not_claim"),
	], 11, Color("#dc8b74"))
	forbidden.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	forbidden.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(forbidden)
	column.add_child(_source_line(GameData.source_label(bridge)))
	_attach_detail(panel, {
		"title": GameData.loc(bridge, "title"),
		"subtitle": Locale.t("codex.bridge"),
		"accent": GOLD,
		"badges": [
			{"text": Locale.t("codex.bridge"), "color": GOLD},
			{"text": Locale.t("codex.forbidden"), "color": VERMILION},
		],
		"sections": [
			{"heading": Locale.t("codex.detail.record"), "body": GameData.loc(bridge, "body")},
			{"heading": Locale.t("codex.timeline"), "body": Locale.t("codex.chain")},
			{"heading": Locale.t("codex.forbidden"), "body": GameData.loc(_data, "do_not_claim")},
		],
		"source": GameData.source_label(bridge),
	})
	return panel


func _source_footer() -> void:
	var rule := ColorRect.new()
	rule.color = Color(MUTED, 0.13)
	rule.custom_minimum_size = Vector2(0, 1)
	_page_host.add_child(rule)
	var footer := _label(Locale.t("codex.footer"), 10, Color(MUTED, 0.58))
	footer.name = "SourceFooter"
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.tooltip_text = Locale.t("codex.footer")
	_page_host.add_child(footer)


func _card_ids() -> Array[String]:
	var result: Array[String] = []
	for character_id in _ordered_ids(_data.get("card_order", []) as Array, _characters):
		if not _characters.has(character_id):
			continue
		var character := _characters[character_id] as Dictionary
		if bool(character.get("selectable", false)):
			result.append(character_id)
	return result


func _mercenary_ids() -> Array[String]:
	return _ordered_ids(_data.get("mercenary_order", []) as Array, _mercenaries)


func _ordered_ids(order: Array, source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_id in order:
		var item_id := str(raw_id)
		if source.has(item_id) and not result.has(item_id):
			result.append(item_id)
	var extras: Array[String] = []
	for raw_id in source.keys():
		var item_id := str(raw_id)
		if not result.has(item_id) and not extras.has(item_id):
			extras.append(item_id)
	extras.sort()
	result.append_array(extras)
	return result


func _party_bonus_text(bonus: Dictionary) -> String:
	var parts: Array[String] = []
	for raw_stat in bonus.keys():
		var effect := UpgradeCatalog.format_effect(str(raw_stat), float(bonus[raw_stat]))
		if not effect.is_empty():
			parts.append(effect)
	return " · ".join(parts)


func _add_section_heading(text: String, count: int, accent: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var heading := _label(text, 20, accent)
	heading.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(heading)
	if count > 0:
		row.add_child(_badge(
			Locale.t("codex.count", {"count": count}),
			Color(accent, 0.88)
		))
	var rule := ColorRect.new()
	rule.color = Color(accent, 0.18)
	rule.custom_minimum_size = Vector2(24, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rule)
	_page_host.add_child(row)


func _grid(columns: int, separation: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", separation)
	grid.add_theme_constant_override("v_separation", separation)
	return grid


func _card_panel(accent_hex: String) -> PanelContainer:
	var accent := Color(accent_hex)
	var panel := _flat_panel(Color(0.036, 0.048, 0.048, 0.94), Color(accent, 0.27))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


func _flat_panel(fill: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _flat_box(fill, border, 6, 12))
	return panel


func _icon_frame(path: String, size: int, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(size, size)
	panel.add_theme_stylebox_override(
		"panel",
		_flat_box(Color(0.018, 0.027, 0.027, 0.90), Color(accent, 0.34), 4, 5)
	)
	var texture_rect := TextureRect.new()
	texture_rect.texture = GameData.texture(path)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(texture_rect)
	return panel


func _portrait(path: String, frames: int, node_name: String, size: int, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.custom_minimum_size = Vector2(size, size)
	panel.add_theme_stylebox_override(
		"panel",
		_flat_box(Color(0.016, 0.024, 0.024, 0.92), Color(accent, 0.42), 4, 4)
	)
	var texture_rect := TextureRect.new()
	texture_rect.name = "PortraitTexture"
	texture_rect.texture = _first_frame_texture(path, frames)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(texture_rect)
	return panel


func _first_frame_texture(path: String, frames: int) -> Texture2D:
	var strip := GameData.texture(path)
	if strip == null:
		return null
	var frame_count := maxi(1, frames)
	if frame_count <= 1:
		return strip
	if strip.get_width() % frame_count != 0:
		return strip
	var atlas := AtlasTexture.new()
	atlas.atlas = strip
	atlas.region = Rect2(
		0.0,
		0.0,
		float(strip.get_width() / frame_count),
		float(strip.get_height())
	)
	return atlas


func _badge(text: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override(
		"panel",
		_flat_box(Color(accent, 0.10), Color(accent, 0.36), 3, 5)
	)
	var label := _label(text, 10, Color(accent, 0.96))
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_child(label)
	return panel


func _source_line(text: String) -> Label:
	var source := _label(text, 9, Color(MUTED, 0.66))
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source.tooltip_text = text
	return source


func _flat_box(fill: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = float(margin)
	box.content_margin_right = float(margin)
	box.content_margin_top = float(margin)
	box.content_margin_bottom = float(margin)
	return box


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return GOLD
		"rare":
			return BLUE
		"uncommon":
			return TEAL
	return MUTED


func _time_label(seconds: float) -> String:
	if seconds >= 1.0e19:
		return "—"
	var total := maxi(0, int(round(seconds)))
	return "%02d:%02d" % [int(total / 60), total % 60]


func _num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return String.num(value, 2)


func _ratio(value: float) -> String:
	return "%.2f" % value


func _localized_array(dictionary: Dictionary, field: String) -> Array:
	var localized_key := "%s_%s" % [field, Locale.current]
	if dictionary.has(localized_key):
		return dictionary[localized_key] as Array
	var chinese_key := "%s_zh" % field
	if dictionary.has(chinese_key):
		return dictionary[chinese_key] as Array
	return dictionary.get(field, []) as Array


func _build_detail_overlay() -> void:
	_detail_overlay = Control.new()
	_detail_overlay.name = "CodexDetailOverlay"
	_detail_overlay.z_index = 80
	_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_detail_overlay)

	var backdrop := Button.new()
	backdrop.name = "DetailBackdrop"
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_theme_stylebox_override(
		"normal",
		_flat_box(Color(0.004, 0.007, 0.008, 0.90), Color(0, 0, 0, 0), 0, 0)
	)
	backdrop.add_theme_stylebox_override(
		"hover",
		_flat_box(Color(0.004, 0.007, 0.008, 0.90), Color(0, 0, 0, 0), 0, 0)
	)
	backdrop.add_theme_stylebox_override(
		"pressed",
		_flat_box(Color(0.004, 0.007, 0.008, 0.94), Color(0, 0, 0, 0), 0, 0)
	)
	backdrop.pressed.connect(close_detail)
	_detail_overlay.add_child(backdrop)

	_detail_panel = PanelContainer.new()
	_detail_panel.name = "CodexDetailDialog"
	_detail_panel.anchor_left = 0.5
	_detail_panel.anchor_top = 0.5
	_detail_panel.anchor_right = 0.5
	_detail_panel.anchor_bottom = 0.5
	_detail_panel.offset_left = -470.0
	_detail_panel.offset_top = -302.0
	_detail_panel.offset_right = 470.0
	_detail_panel.offset_bottom = 302.0
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_panel.add_theme_stylebox_override(
		"panel",
		_flat_box(Color(0.026, 0.035, 0.035, 0.99), Color(GOLD, 0.54), 8, 18)
	)
	_detail_overlay.add_child(_detail_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_detail_panel.add_child(outer)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	outer.add_child(header)
	_detail_title = _label("", 30, GOLD)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_detail_title)
	_detail_close = _button(Locale.t("codex.detail.close"), false)
	_detail_close.name = "DetailClose"
	_detail_close.custom_minimum_size = Vector2(150, 42)
	_detail_close.focus_mode = Control.FOCUS_ALL
	_detail_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_detail_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_close.pressed.connect(close_detail)
	header.add_child(_detail_close)
	_detail_subtitle = _label("", 14, Color(MUTED, 0.92))
	_detail_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_detail_subtitle)
	_detail_badges = HFlowContainer.new()
	_detail_badges.add_theme_constant_override("h_separation", 6)
	_detail_badges.add_theme_constant_override("v_separation", 5)
	outer.add_child(_detail_badges)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	outer.add_child(body)
	_detail_image_plate = PanelContainer.new()
	_detail_image_plate.name = "DetailImagePlate"
	_detail_image_plate.custom_minimum_size = Vector2(198, 198)
	_detail_image_plate.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_detail_image_plate.add_theme_stylebox_override(
		"panel",
		_flat_box(Color(0.012, 0.020, 0.020, 0.96), Color(GOLD, 0.36), 6, 6)
	)
	body.add_child(_detail_image_plate)
	_detail_image = TextureRect.new()
	_detail_image.name = "DetailImage"
	_detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_image_plate.add_child(_detail_image)
	_zoom_hit = Button.new()
	_zoom_hit.name = "DetailZoomHit"
	_zoom_hit.text = ""
	_zoom_hit.focus_mode = Control.FOCUS_NONE
	_zoom_hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_zoom_hit.tooltip_text = Locale.t("codex.detail.zoom_tip")
	_zoom_hit.add_theme_stylebox_override(
		"normal",
		_flat_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6, 0)
	)
	_zoom_hit.add_theme_stylebox_override(
		"hover",
		_flat_box(Color(GOLD, 0.06), Color(GOLD, 0.66), 6, 0)
	)
	_zoom_hit.add_theme_stylebox_override(
		"pressed",
		_flat_box(Color(GOLD, 0.12), Color(GOLD, 0.86), 6, 0)
	)
	_zoom_hit.pressed.connect(open_zoom)
	_detail_image_plate.add_child(_zoom_hit)
	_zoom_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "DetailScroll"
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_detail_scroll)
	var detail_margin := MarginContainer.new()
	detail_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_margin.add_theme_constant_override("margin_left", 2)
	detail_margin.add_theme_constant_override("margin_right", 12)
	detail_margin.add_theme_constant_override("margin_top", 2)
	detail_margin.add_theme_constant_override("margin_bottom", 8)
	_detail_scroll.add_child(detail_margin)
	_detail_sections = VBoxContainer.new()
	_detail_sections.name = "DetailSections"
	_detail_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_sections.add_theme_constant_override("separation", 13)
	detail_margin.add_child(_detail_sections)

	_detail_source = _label("", 10, Color(MUTED, 0.66))
	_detail_source.name = "DetailSource"
	_detail_source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_detail_source)
	_detail_hint = _label("", 10, Color(MUTED, 0.54))
	_detail_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_detail_hint)
	_detail_overlay.visible = false
	_build_zoom_overlay()


func _build_zoom_overlay() -> void:
	_zoom_overlay = Control.new()
	_zoom_overlay.name = "CodexZoomOverlay"
	_zoom_overlay.z_index = 95
	_zoom_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_zoom_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_zoom_overlay)

	_zoom_backdrop = Button.new()
	_zoom_backdrop.name = "ZoomBackdrop"
	_zoom_backdrop.focus_mode = Control.FOCUS_NONE
	_zoom_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zoom_backdrop.add_theme_stylebox_override(
		"normal",
		_flat_box(Color(0.002, 0.004, 0.005, 0.96), Color(0, 0, 0, 0), 0, 0)
	)
	_zoom_backdrop.add_theme_stylebox_override(
		"hover",
		_flat_box(Color(0.002, 0.004, 0.005, 0.96), Color(0, 0, 0, 0), 0, 0)
	)
	_zoom_backdrop.add_theme_stylebox_override(
		"pressed",
		_flat_box(Color(0.002, 0.004, 0.005, 0.99), Color(0, 0, 0, 0), 0, 0)
	)
	_zoom_backdrop.pressed.connect(close_zoom)
	_zoom_overlay.add_child(_zoom_backdrop)

	_zoom_image = TextureRect.new()
	_zoom_image.name = "ZoomImage"
	_zoom_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_zoom_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_zoom_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_zoom_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zoom_image.offset_left = 48.0
	_zoom_image.offset_right = -48.0
	_zoom_image.offset_top = 26.0
	_zoom_image.offset_bottom = -62.0
	_zoom_overlay.add_child(_zoom_image)

	_zoom_hint = _label(Locale.t("codex.zoom.hint"), 12, Color(PAPER, 0.82))
	_zoom_hint.name = "ZoomHint"
	_zoom_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_zoom_hint.offset_left = 40.0
	_zoom_hint.offset_right = -40.0
	_zoom_hint.offset_top = -40.0
	_zoom_hint.offset_bottom = -12.0
	_zoom_overlay.add_child(_zoom_hint)

	_zoom_close = _button(Locale.t("codex.detail.close"), true)
	_zoom_close.name = "ZoomClose"
	_zoom_close.custom_minimum_size = Vector2(150, 42)
	_zoom_close.focus_mode = Control.FOCUS_ALL
	_zoom_close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_zoom_close.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_zoom_close.offset_left = -190.0
	_zoom_close.offset_top = 16.0
	_zoom_close.offset_right = -30.0
	_zoom_close.offset_bottom = 58.0
	_zoom_close.pressed.connect(close_zoom)
	_zoom_overlay.add_child(_zoom_close)
	_zoom_overlay.visible = false


func open_zoom() -> void:
	if _zoom_overlay == null or not detail_is_open() or _detail_image.texture == null:
		return
	_zoom_image.texture = _detail_image.texture
	_zoom_hint.text = Locale.t("codex.zoom.hint")
	_zoom_close.text = Locale.t("codex.detail.close")
	_zoom_overlay.visible = true
	_zoom_close.grab_focus()


func close_zoom() -> void:
	if _zoom_overlay == null or not _zoom_overlay.visible:
		return
	_zoom_overlay.visible = false
	_zoom_image.texture = null
	if detail_is_open():
		_detail_close.grab_focus()


func zoom_is_open() -> bool:
	return _zoom_overlay != null and _zoom_overlay.visible


func _attach_detail(panel: PanelContainer, detail: Dictionary) -> void:
	if detail.is_empty():
		return
	var accent: Color = detail.get("accent", GOLD)
	var hit := Button.new()
	hit.name = "DetailHit"
	hit.text = ""
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.tooltip_text = str(detail.get("title", ""))
	hit.add_theme_stylebox_override(
		"normal",
		_flat_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6, 0)
	)
	hit.add_theme_stylebox_override(
		"hover",
		_flat_box(Color(accent, 0.03), Color(accent, 0.58), 6, 0)
	)
	hit.add_theme_stylebox_override(
		"pressed",
		_flat_box(Color(accent, 0.07), Color(accent, 0.80), 6, 0)
	)
	hit.add_theme_stylebox_override(
		"focus",
		_flat_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6, 0)
	)
	hit.pressed.connect(_show_detail.bind(detail))
	panel.add_child(hit)
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _show_detail(detail: Dictionary) -> void:
	if _detail_overlay == null:
		_build_detail_overlay()
	close_zoom()
	var accent: Color = detail.get("accent", GOLD)
	for child in _detail_badges.get_children():
		_detail_badges.remove_child(child)
		child.free()
	for raw_badge in detail.get("badges", []) as Array:
		var badge := raw_badge as Dictionary
		var text := str(badge.get("text", ""))
		if text.is_empty():
			continue
		var badge_color: Color = badge.get("color", accent)
		_detail_badges.add_child(_badge(text, badge_color))
	for child in _detail_sections.get_children():
		_detail_sections.remove_child(child)
		child.free()
	for raw_section in detail.get("sections", []) as Array:
		var section := raw_section as Dictionary
		var body_text := str(section.get("body", ""))
		if body_text.is_empty():
			continue
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 4)
		var heading := _label(str(section.get("heading", "")), 13, accent)
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		block.add_child(heading)
		var body := _label(body_text, 14, Color(PAPER, 0.92))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		block.add_child(body)
		_detail_sections.add_child(block)
	var image_path := str(detail.get("image_path", ""))
	if image_path.is_empty():
		image_path = str(detail.get("icon_path", ""))
	var image_texture: Texture2D = _first_frame_texture(
		image_path,
		int(detail.get("image_frames", 1))
	)
	_detail_image.texture = image_texture
	_detail_image_plate.visible = image_texture != null
	_detail_image_plate.add_theme_stylebox_override(
		"panel",
		_flat_box(Color(0.012, 0.020, 0.020, 0.96), Color(accent, 0.46), 6, 6)
	)
	_detail_title.text = str(detail.get("title", ""))
	_detail_title.add_theme_color_override("font_color", accent)
	_detail_subtitle.text = str(detail.get("subtitle", ""))
	var source_text := str(detail.get("source", ""))
	_detail_source.visible = not source_text.is_empty()
	_detail_source.text = Locale.t("codex.detail.source", {"source": source_text})
	_detail_panel.add_theme_stylebox_override(
		"panel",
		_flat_box(Color(0.026, 0.035, 0.035, 0.99), Color(accent, 0.62), 8, 18)
	)
	_detail_close.text = Locale.t("codex.detail.close")
	_detail_hint.text = Locale.t("codex.detail.hint")
	_zoom_hit.tooltip_text = Locale.t("codex.detail.zoom_tip")
	_zoom_overlay.visible = false
	_detail_overlay.visible = true
	_detail_scroll.scroll_vertical = 0
	_detail_close.grab_focus()


func close_detail() -> void:
	if _detail_overlay == null:
		return
	if zoom_is_open():
		close_zoom()
	_detail_overlay.visible = false


func _category_label(category: String) -> String:
	return UpgradeCatalog.localized_category(category)


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
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", INK if primary else PAPER)
	button.add_theme_stylebox_override(
		"normal",
		_flat_box(Color(GOLD, 0.88) if primary else Color(GOLD, 0.08), Color(GOLD, 0.62), 4, 9)
	)
	button.add_theme_stylebox_override(
		"hover",
		_flat_box(Color(GOLD, 0.98) if primary else Color(GOLD, 0.18), GOLD, 4, 9)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_flat_box(GOLD if primary else Color(GOLD, 0.24), GOLD, 4, 9)
	)
	return button
