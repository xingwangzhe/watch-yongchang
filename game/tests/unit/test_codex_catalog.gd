extends GutTest


func before_each() -> void:
	Locale.set_language("zh", false)


func after_each() -> void:
	Locale.set_language("zh", false)


func test_codex_defaults_to_six_live_wanglu_cards() -> void:
	var codex = await _open_codex()
	assert_eq(codex.current_tab_id(), "cards")
	assert_eq(codex.card_entry_count(), 6)
	assert_not_null(codex.find_child("TabCards", true, false))
	assert_not_null(codex.find_child("TabUpgrades", true, false))
	assert_not_null(codex.find_child("TabHistory", true, false))
	for character_id in ["wanglu", "amei", "ashi", "achong", "agong", "aqi"]:
		assert_not_null(codex.find_child("Card_%s" % character_id, true, false))
	var card_text := _node_text(codex.find_child("Card_wanglu", true, false))
	assert_string_contains(card_text, "王陆 · 均衡位")
	assert_string_contains(card_text, "生命 140")
	assert_string_contains(card_text, "腰刀")
	assert_string_contains(card_text, "绑腿")
	var portrait := codex.find_child("Portrait_wanglu", true, false) as Control
	assert_not_null(portrait)
	assert_true(portrait.custom_minimum_size.x >= 160.0)
	var ally_text := _node_text(codex.find_child("Ally_wangpei_spirit", true, false))
	assert_string_contains(ally_text, "传世")
	assert_string_contains(ally_text, "全队：伤害 +9%")


func test_background_history_stays_out_of_default_page() -> void:
	var codex = await _open_codex()
	var default_text := _all_text(codex)
	assert_false(default_text.contains("宁村所 · 1386"))
	assert_false(default_text.contains("王德为解温州府城之围"))
	assert_string_contains(default_text, "清《永嘉县志·岁时》")
	assert_string_contains(default_text, "《永昌堡：十三进士与抗倭纪略》")
	assert_not_null(codex.find_child("SourceFooter", true, false))
	codex.select_tab("history")
	await wait_process_frames(2)
	var history_text := _all_text(codex)
	assert_string_contains(history_text, "宁村所 · 1386")
	assert_string_contains(history_text, "王德")
	assert_string_contains(history_text, "东瓯王庙")


func test_catalog_tabs_use_live_json_counts() -> void:
	var codex = await _open_codex()
	codex.select_tab("equipment")
	await wait_process_frames(2)
	assert_eq(_count_name_prefix(codex, "GearPassive_"), 12)
	assert_eq(_count_name_prefix(codex, "GearTrait_"), 51)
	codex.select_tab("weapons")
	await wait_process_frames(2)
	assert_eq(_count_name_prefix(codex, "Weapon_"), 7)
	var saber_text := _node_text(codex.find_child("Weapon_saber", true, false))
	assert_string_contains(saber_text, "伤害 15")
	assert_string_contains(saber_text, "冷却 0.58s")
	assert_string_contains(saber_text, "进化：断浪刀")
	assert_string_contains(saber_text, "需满级 磨刀石")
	assert_string_contains(saber_text, "三百六十度大斩")
	var cannon_text := _node_text(codex.find_child("Weapon_cannon", true, false))
	assert_string_contains(cannon_text, "无进化 · 直接成型")
	codex.select_tab("enemies")
	await wait_process_frames(2)
	assert_eq(_count_name_prefix(codex, "Enemy_"), 9)
	assert_not_null(codex.find_child("Enemy_general", true, false))
	assert_not_null(codex.find_child("Enemy_daimyo", true, false))
	var shield_text := _node_text(codex.find_child("Enemy_shield", true, false))
	assert_string_contains(shield_text, "减伤 18%")
	assert_string_contains(shield_text, "击退、穿透和灼烧")
	codex.select_tab("maps")
	await wait_process_frames(2)
	assert_eq(_count_name_prefix(codex, "Map_"), 3)
	assert_eq(_count_name_prefix(codex, "Event_"), 22)
	assert_not_null(codex.find_child("Event_pirate_tide", true, false))
	var tideland_text := _node_text(codex.find_child("Map_tideland", true, false))
	assert_string_contains(tideland_text, "敌速 ×1.00")
	assert_string_contains(tideland_text, "适合绕行拉怪")


func test_upgrade_tab_contains_the_full_one_of_three_pool() -> void:
	var codex = await _open_codex()
	codex.select_tab("upgrades")
	await wait_process_frames(2)
	var upgrades := GameData.load_json("res://data/upgrades.json")
	var expected := 0
	for family in ["attributes", "skills", "events", "towers"]:
		expected += (upgrades.get(family, {}) as Dictionary).size()
	assert_eq(_count_name_prefix(codex, "Upgrade_"), expected)
	assert_eq(expected, 143)
	assert_not_null(codex.find_child("Upgrade_attributes_whetstone", true, false))
	assert_not_null(codex.find_child("Upgrade_skills_watch_volley", true, false))
	assert_not_null(codex.find_child("Upgrade_events_pirate_tide", true, false))
	assert_not_null(codex.find_child("Upgrade_towers_tower_ascent", true, false))
	var skill_text := _node_text(codex.find_child("Upgrade_skills_watch_volley", true, false))
	assert_string_contains(skill_text, "望楼箭雨")
	assert_string_contains(skill_text, "每 2.4 秒向最近敌人齐射 2 箭")
	assert_string_contains(skill_text, "上限 Lv.5")
	var tower_text := _node_text(codex.find_child("Upgrade_towers_tower_ascent", true, false))
	assert_string_contains(tower_text, "箭塔升阶")
	assert_string_contains(tower_text, "所有箭塔升一阶")


func test_every_catalog_entry_has_a_detail_target() -> void:
	var codex = await _open_codex()
	var expected := {
		"cards": 16,
		"upgrades": 143,
		"equipment": 63,
		"weapons": 7,
		"enemies": 9,
		"maps": 25,
		"history": 14,
	}
	for tab_id in expected.keys():
		codex.select_tab(str(tab_id))
		await wait_process_frames(2)
		assert_eq(
			_count_detail_hits(codex),
			int(expected[tab_id]),
			"detail target count on %s" % tab_id
		)


func test_detail_opens_and_closes_with_button_backdrop_and_escape() -> void:
	var codex = await _open_codex()
	var card: Node = codex.find_child("Card_wanglu", true, false)
	var hit := card.find_child("DetailHit", true, false) as Button
	assert_not_null(hit)
	hit.pressed.emit()
	await wait_process_frames(2)
	assert_true(codex.detail_is_open())
	var overlay := codex.find_child("CodexDetailOverlay", true, false) as Control
	assert_not_null(overlay)
	assert_true(overlay.visible)
	assert_string_contains(_node_text(overlay), "王陆")
	assert_string_contains(_node_text(overlay), "均衡位")
	var detail_body := overlay.find_child("DetailSections", true, false)
	for label in detail_body.find_children("*", "Label", true, false):
		assert_ne((label as Label).autowrap_mode, TextServer.AUTOWRAP_OFF)
	var close := overlay.find_child("DetailClose", true, false) as Button
	assert_not_null(close)
	assert_eq(close.get_focus_mode_with_override(), Control.FOCUS_ALL)
	close.pressed.emit()
	assert_false(codex.detail_is_open())

	hit.pressed.emit()
	var backdrop := overlay.find_child("DetailBackdrop", true, false) as Button
	assert_not_null(backdrop)
	backdrop.pressed.emit()
	assert_false(codex.detail_is_open())

	hit.pressed.emit()
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.physical_keycode = KEY_ESCAPE
	cancel.pressed = true
	codex._unhandled_input(cancel)
	assert_false(codex.detail_is_open())


func test_history_culture_notes_expand_to_full_text() -> void:
	var codex = await _open_codex()
	codex.select_tab("history")
	await wait_process_frames(2)
	var culture: Node = codex.find_child("Culture_garrison", true, false)
	assert_not_null(culture)
	var preview := _node_text(culture)
	assert_string_contains(preview, "宁村所：把海防落到乡里")
	assert_string_contains(preview, "卫所")
	assert_string_contains(preview, "点击阅读全文")
	var hit := culture.find_child("DetailHit", true, false) as Button
	hit.pressed.emit()
	await wait_process_frames(2)
	var overlay_text := _node_text(codex.find_child("CodexDetailOverlay", true, false))
	assert_string_contains(overlay_text, "洪武十九年")
	assert_string_contains(overlay_text, "屯田")
	assert_string_contains(overlay_text, "《汤和信俗·抵御倭患第一人》")


func test_forge_first_frames_are_used_for_cards_and_enemies() -> void:
	var codex = await _open_codex()
	var player_texture := _portrait_texture(codex, "Portrait_wanglu")
	assert_true(player_texture is AtlasTexture)
	var player_atlas := player_texture as AtlasTexture
	assert_eq(player_atlas.region.position, Vector2.ZERO)
	assert_eq(player_atlas.region.size, Vector2(128, 128))
	assert_string_contains(player_atlas.atlas.resource_path, "res://assets/units/full_sheets/wanglu_watchposts.webp")
	codex.select_tab("enemies")
	await wait_process_frames(2)
	var enemy_texture := _portrait_texture(codex, "Portrait_scout")
	assert_true(enemy_texture is AtlasTexture)
	var enemy_atlas := enemy_texture as AtlasTexture
	assert_eq(enemy_atlas.region.position, Vector2.ZERO)
	assert_eq(enemy_atlas.region.size, Vector2(128, 128))
	assert_string_contains(enemy_atlas.atlas.resource_path, "res://assets/units/full_sheets/enemies_walk.webp")
	for character in GameData.get_characters().values():
		assert_false((character as Dictionary).has("texture"))


func test_codex_keys_and_ui_are_bilingual() -> void:
	var zh_keys: Array[String] = []
	var en_keys: Array[String] = []
	for key in Locale.table("zh").keys():
		if str(key).begins_with("codex."):
			zh_keys.append(str(key))
	for key in Locale.table("en").keys():
		if str(key).begins_with("codex."):
			en_keys.append(str(key))
	zh_keys.sort()
	en_keys.sort()
	assert_eq(zh_keys, en_keys)
	for key in zh_keys:
		assert_gt(str(Locale.table("zh")[key]).length(), 0, "empty zh key %s" % key)
		assert_gt(str(Locale.table("en")[key]).length(), 0, "empty en key %s" % key)
	var codex = await _open_codex()
	Locale.set_language("en", false)
	await wait_process_frames(2)
	var text := _all_text(codex)
	assert_string_contains(text, "Hero Codex")
	assert_string_contains(text, "Wang Lu")
	assert_string_contains(text, "History")
	assert_string_contains(text, "Heroes")
	assert_string_contains(text, "Upgrades")
	codex.select_tab("upgrades")
	await wait_process_frames(2)
	var upgrade_text := _all_text(codex)
	assert_string_contains(upgrade_text, "One-of-Three Upgrade Codex")
	assert_string_contains(upgrade_text, "Watchtower Volley")
	assert_string_contains(upgrade_text, "Attribute Cards")
	assert_false(upgrade_text.contains("属性牌"))
	var first_upgrade: Node = codex.find_child("Upgrade_skills_watch_volley", true, false)
	var detail_hit := first_upgrade.find_child("DetailHit", true, false) as Button
	detail_hit.pressed.emit()
	await wait_process_frames(2)
	var detail_text := _node_text(codex.find_child("CodexDetailOverlay", true, false))
	assert_string_contains(detail_text, "Press Esc")
	assert_string_contains(detail_text, "Card-Pool Rule")
	assert_false(detail_text.contains("制度"))


func test_arrow_keys_switch_tabs() -> void:
	var codex = await _open_codex()
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	codex._unhandled_input(right)
	assert_eq(codex.current_tab_id(), "upgrades")
	var left := InputEventKey.new()
	left.keycode = KEY_LEFT
	left.physical_keycode = KEY_LEFT
	left.pressed = true
	codex._unhandled_input(left)
	assert_eq(codex.current_tab_id(), "cards")


func _open_codex():
	var codex := (load("res://scenes/codex.tscn") as PackedScene).instantiate()
	add_child_autofree(codex)
	await wait_process_frames(3)
	return codex


func _all_text(root: Node) -> String:
	var text := ""
	for label in root.find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	for button in root.find_children("*", "Button", true, false):
		text += (button as Button).text + "\n"
	return text


func _node_text(root: Node) -> String:
	if root == null:
		return ""
	return _all_text(root)


func _count_name_prefix(root: Node, prefix: String) -> int:
	var count := 0
	for control in root.find_children("*", "Control", true, false):
		if str((control as Control).name).begins_with(prefix):
			count += 1
	return count


func _count_detail_hits(root: Node) -> int:
	var count := 0
	for button in root.find_children("DetailHit", "Button", true, false):
		if (button as Button).is_visible_in_tree():
			count += 1
	return count


func _portrait_texture(root: Node, portrait_name: String) -> Texture2D:
	var portrait := root.find_child(portrait_name, true, false)
	assert_not_null(portrait, "missing portrait %s" % portrait_name)
	var texture_rect := portrait.find_child("PortraitTexture", true, false) as TextureRect
	assert_not_null(texture_rect, "missing portrait texture for %s" % portrait_name)
	return texture_rect.texture
