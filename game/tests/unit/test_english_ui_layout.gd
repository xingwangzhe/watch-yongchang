extends GutTest

const TEST_SAVE := "user://test_english_ui_layout_save.json"
const TEST_SETTINGS := "user://test_english_ui_layout_settings.cfg"
const TEST_RENDERER_MIRROR := "user://test_english_ui_layout_renderer.cfg"
const EPSILON := 3.0
const DESIGN_W := 1280.0
const DESIGN_H := 720.0


func before_each() -> void:
	SaveSystem.save_path = TEST_SAVE
	SaveSystem.reset_memory()
	SaveSystem.data["tutorial_seen"] = true
	SaveSystem.data["total_merit"] = 9999
	GameSettings.config_path = TEST_SETTINGS
	GameSettings.renderer_mirror_override = TEST_RENDERER_MIRROR
	GameSettings.language = "en"
	GameSettings.bgm_volume = GameSettings.DEFAULT_BGM_VOLUME
	GameSettings.sfx_volume = 0.78
	GameSettings.fps_limit = GameSettings.DEFAULT_FPS_LIMIT
	GameSettings.vsync = true
	GameSettings.renderer_mode = GameSettings.RENDERER_AUTO
	GameSettings.vulkan_probe_override = 1
	GameSettings.web_platform_override = -1
	GameSettings.active_renderer_override = GameSettings.RENDERER_VULKAN
	GameSettings.restart_enabled = false
	GameSettings.bindings.clear()
	InputSetup.reset_to_defaults()
	GameSettings.reset_vulkan_probe()
	Locale.set_language("en", false)
	AudioBus.menu_enabled = false


func after_each() -> void:
	SaveSystem.save_path = SaveSystem.SAVE_PATH
	GameSettings.config_path = GameSettings.CONFIG_PATH
	GameSettings.renderer_mirror_override = ""
	Locale.set_language("zh", false)
	GameSettings.language = "zh"
	GameSettings.fps_limit = GameSettings.DEFAULT_FPS_LIMIT
	GameSettings.vsync = true
	GameSettings.renderer_mode = GameSettings.RENDERER_AUTO
	GameSettings.vulkan_probe_override = -1
	GameSettings.web_platform_override = -1
	GameSettings.active_renderer_override = ""
	GameSettings.restart_enabled = true
	GameSettings.bindings.clear()
	InputSetup.reset_to_defaults()
	GameSettings.reset_vulkan_probe()
	AudioBus.menu_enabled = true
	_remove_user_file(TEST_SAVE)
	_remove_user_file(TEST_SETTINGS)
	_remove_user_file(TEST_RENDERER_MIRROR)


func test_english_main_menu_surfaces_fit_at_design_and_wide_sizes() -> void:
	for canvas_size in [Vector2(DESIGN_W, DESIGN_H), Vector2(1600, 900)]:
		var host := _host(canvas_size)
		var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
		host.add_child(menu)
		menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await wait_process_frames(4)
		_assert_surface(menu, host.get_global_rect(), "main menu %s" % canvas_size)

		menu.open_settings()
		await wait_process_frames(2)
		_assert_surface(menu, host.get_global_rect(), "settings %s" % canvas_size)
		menu.open_controls()
		await wait_process_frames(2)
		_assert_surface(menu, host.get_global_rect(), "controls %s" % canvas_size)
		menu.close_controls()
		menu.close_settings()
		await wait_process_frames(1)
		menu._tutorial_overlay.open(false)
		for page_index in TutorialOverlay.PAGE_COUNT:
			menu._tutorial_overlay._go_page(page_index)
			await wait_process_frames(2)
			_assert_surface(
				menu,
				host.get_global_rect(),
				"tutorial page %d %s" % [page_index + 1, canvas_size]
			)
		menu._tutorial_overlay._finish(false)
		await wait_process_frames(1)

		menu.show_web_exit_notice()
		await wait_process_frames(2)
		_assert_surface(menu, host.get_global_rect(), "web exit %s" % canvas_size)
		menu.hide_web_exit_notice()
		host.queue_free()
		await wait_process_frames(1)


func test_portrait_english_controls_panel_has_phone_sized_touch_targets() -> void:
	var original_viewport_size: Vector2i = get_viewport().size
	var screen_size := Vector2(390.0, 844.0)
	var viewport_size := _logical_viewport(screen_size)
	var scale := screen_size.x / viewport_size.x
	get_viewport().size = Vector2i(roundi(viewport_size.x), roundi(viewport_size.y))
	await wait_process_frames(2)
	var host := _host(viewport_size)
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	host.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await wait_process_frames(4)
	menu.call("_apply_responsive_layout", viewport_size, screen_size)
	menu.open_controls()
	await wait_process_frames(3)
	menu.call("_apply_controls_responsive_layout", viewport_size, screen_size, Vector4(6, 24, 6, 20), scale, true)
	await wait_process_frames(2)

	var panel := menu.find_child("ControlsPanel", true, false) as Control
	var scroll := menu.find_child("ControlsScroll", true, false) as ScrollContainer
	var rows := menu.find_child("ControlsRows", true, false) as VBoxContainer
	var panel_css_rect := Rect2(panel.get_global_rect().position * scale, panel.get_global_rect().size * scale)
	var panel_bounds := Rect2(Vector2.ZERO, screen_size)
	assert_true(panel_bounds.encloses(panel_css_rect), "controls panel must stay inside the phone viewport")
	assert_gte(panel_css_rect.position.x, 18.0 - EPSILON, "controls panel must respect the left safe inset")
	assert_gte(panel_css_rect.position.y, 36.0 - EPSILON, "controls panel must respect the top safe inset")
	assert_lte(panel_css_rect.end.x, screen_size.x - 18.0 + EPSILON, "controls panel must respect the right safe inset")
	assert_lte(panel_css_rect.end.y, screen_size.y - 32.0 + EPSILON, "controls panel must respect the bottom safe inset")
	for action in InputSetup.ORDER:
		var row := rows.find_child("Row_%s" % action, true, false) as HBoxContainer
		var rebind := row.find_child("Rebind_%s" % action, true, false) as Button
		var action_label := row.find_child("Label_%s" % action, true, false) as Label
		assert_gte(rebind.custom_minimum_size.y * scale, 44.0, "rebind target must meet touch height for %s" % action)
		assert_eq(action_label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
		assert_true(scroll.get_global_rect().intersects(row.get_global_rect()))
		_assert_label(action_label, panel.get_global_rect(), "portrait controls %s" % action)

	menu.close_controls()
	host.queue_free()
	get_viewport().size = original_viewport_size
	await wait_process_frames(2)


func test_english_character_select_copy_fits_for_every_choice() -> void:
	for canvas_size in [Vector2(DESIGN_W, DESIGN_H), Vector2(1600, 900)]:
		var host := _host(canvas_size)
		var select := (load("res://scenes/character_select.tscn") as PackedScene).instantiate()
		host.add_child(select)
		select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await wait_process_frames(4)
		for character_id in select.CHARACTER_ORDER:
			for map_id in select.MAP_ORDER:
				select._select_character(character_id)
				select._select_map(map_id)
				await wait_process_frames(1)
				_assert_surface(
					select,
					host.get_global_rect(),
					"character select %s/%s %s" % [character_id, map_id, canvas_size]
				)
		host.queue_free()
		await wait_process_frames(1)


func test_english_hud_fits_with_long_weapon_and_retinue_names() -> void:
	var original_viewport_size: Vector2i = get_viewport().size
	get_viewport().size = Vector2i(DESIGN_W, DESIGN_H)
	await wait_process_frames(2)
	var hud := RunHUD.new()
	add_child_autofree(hud)
	await wait_process_frames(2)
	hud.update_hud({
		"hp": 123,
		"max_hp": 456,
		"shield": 78,
		"xp": 88,
		"xp_need": 99,
		"level": 30,
		"elapsed": 959,
		"duration": 960,
		"kills": 9999,
		"merit": 123456,
		"coin": 654321,
		"oil": 6,
		"oil_max": 6,
		"dark": true,
		"scales": ["red", "yellow", "blue", "green", "black"],
		"weapons": [
			{"name": "Dragon Lantern", "icon": "res://assets/icons/game_icons/wpn_lantern.svg", "level": 5},
			{"name": "Folangji Cannon", "icon": "res://assets/icons/game_icons/wpn_cannon.svg", "level": 5},
			{"name": "Command Banner", "icon": "res://assets/icons/game_icons/card_tower_flag.svg", "level": 5},
			{"name": "Long Spear", "icon": "res://assets/icons/game_icons/card_spears.svg", "level": 5},
			{"name": "Hand Cannon", "icon": "res://assets/icons/game_icons/wpn_musket.svg", "level": 5},
			{"name": "Saber", "icon": "res://assets/icons/game_icons/wpn_saber.svg", "level": 5},
		],
		"passive_summary": "Gaiters 5 · Rattan Shield 5 · Colored Paper 5 · Incense Ash 5",
		"mercenary_count": 3,
		"mercenary_max": 3,
		"mercenary_summary": "Village Levies · Guest Soldiers · Incense Spirits",
		"skills": 8,
		"cards": 12,
		"build_label": Locale.t("hud.build", {"weapons": 6, "passives": 4}),
		"move_hint": Locale.t("hud.move_hint"),
		"auto_attack": true,
		"attack_mode": Locale.t("hud.attack_auto"),
		"attack_toggle": Locale.t("hud.attack_toggle", {"key": "X"}),
		"boss_active": true,
		"boss_name": "Wokou Daimyo Vanguard",
		"boss_hp": 9999,
		"boss_max_hp": 10000,
	})
	await wait_process_frames(3)
	_assert_surface(hud, get_viewport().get_visible_rect(), "HUD 1280x720")

	var weapon_row := hud.find_child("WeaponRow", true, false) as Control
	var scale_chip := hud.find_child("ScaleChip", true, false) as Control
	var build_chip := hud.find_child("BuildChip", true, false) as Control
	assert_false(
		weapon_row.get_global_rect().intersects(scale_chip.get_global_rect()),
		"weapon row must not overlap the scales chip"
	)
	assert_false(
		weapon_row.get_global_rect().intersects(build_chip.get_global_rect()),
		"weapon row must not overlap the build chip"
	)
	remove_child(hud)
	hud.queue_free()
	get_viewport().size = original_viewport_size
	await wait_process_frames(2)


func test_portrait_standard_upgrade_choices_fit_one_phone_page() -> void:
	var original_viewport_size: Vector2i = get_viewport().size
	for canvas_size in [Vector2i(360, 800), Vector2i(390, 844)]:
		var screen_size := Vector2(canvas_size)
		var viewport_size := _logical_viewport(screen_size)
		var scale := screen_size.x / viewport_size.x
		get_viewport().size = Vector2i(roundi(viewport_size.x), roundi(viewport_size.y))
		await wait_process_frames(2)
		var host := _host(viewport_size)
		var overlay := LevelUpOverlay.new()
		host.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await wait_process_frames(2)
		overlay._apply_responsive_layout_for(viewport_size, screen_size, Vector4(6.0, 24.0, 6.0, 20.0))
		overlay.show_options(_upgrade_options(), 12, {"pool": 120, "taken": 36})
		await wait_process_frames(4)
		await wait_seconds(0.22)
		var scroll_rect: Rect2 = overlay._mobile_scroll.get_global_rect()
		for index in range(3):
			var card := overlay.find_child("UpgradeCard%d" % (index + 1), true, false) as Button
			assert_true(card.visible, "all three standard choices must stay visible in the list")
			assert_true(
				scroll_rect.encloses(card.get_global_rect()),
				"standard choice %d should fit in one portrait page at %s: card=%s scroll=%s" % [
					index + 1, canvas_size, card.get_global_rect(), scroll_rect,
				]
			)
		var scroll_bar := overlay._mobile_scroll.get_v_scroll_bar()
		assert_lte(
			scroll_bar.max_value - scroll_bar.page,
			EPSILON,
			"standard three-choice page should not need vertical scrolling at %s" % canvas_size
		)

	get_viewport().size = original_viewport_size
	await wait_process_frames(2)


func test_portrait_upgrade_cards_and_hud_banner_fit_phone_sizes() -> void:
	var original_viewport_size: Vector2i = get_viewport().size
	for canvas_size in [Vector2i(360, 800), Vector2i(390, 844)]:
		var screen_size := Vector2(canvas_size)
		var viewport_size := _logical_viewport(screen_size)
		var scale := screen_size.x / viewport_size.x
		get_viewport().size = Vector2i(roundi(viewport_size.x), roundi(viewport_size.y))
		await wait_process_frames(2)
		var bounds := Rect2(Vector2.ZERO, viewport_size)
		var host := _host(viewport_size)
		var overlay := LevelUpOverlay.new()
		host.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await wait_process_frames(2)
		overlay._apply_responsive_layout_for(viewport_size, screen_size, Vector4(6.0, 24.0, 6.0, 20.0))
		var options := _upgrade_options()
		options[0]["title"] = "A Long Lantern Watch Blessing That Needs To Wrap Cleanly"
		overlay.show_options(options, 12, {"pool": 120, "taken": 36})
		await wait_process_frames(3)
		await wait_seconds(0.25)

		assert_true(overlay._portrait_layout, "level-up cards must use portrait layout at %s" % canvas_size)
		assert_true(
			bounds.encloses(overlay._column.get_global_rect()),
			"level-up column must fit at %s: rect=%s bounds=%s" % [canvas_size, overlay._column.get_global_rect(), bounds]
		)
		assert_true(overlay._mobile_scroll.clip_contents, "off-screen cards must scroll inside the portrait viewport")
		var first_card := overlay.find_child("UpgradeCard1", true, false) as Button
		var first_card_rect := first_card.get_global_rect()
		assert_true(overlay._mobile_scroll.get_global_rect().encloses(first_card_rect), "first upgrade card must be fully visible and tappable")
		assert_eq(first_card.mouse_filter, Control.MOUSE_FILTER_STOP, "the card surface must receive taps")
		assert_gte(first_card.size.x * scale, screen_size.x - 36.0 - EPSILON, "card hit width must respect the 12px gutters and safe insets")
		assert_gte(first_card.size.y * scale, 180.0, "compact card hit area must remain comfortable to tap")
		assert_lte(first_card.size.y * scale, 280.0, "long copy may grow one card, but must not restore desktop card height")
		assert_false(first_card.disabled, "the card must become tappable after the opening input lock")
		var long_title := first_card.find_child("CardTitle", true, false) as Label
		assert_true(long_title.autowrap_mode != TextServer.AUTOWRAP_OFF, "long upgrade titles must wrap")
		assert_gte(long_title.get_line_count(), 2, "the long title must wrap onto a second line")
		assert_gte(long_title.get_visible_line_count(), long_title.get_line_count(), "wrapped title lines must remain visible")
		var chosen: Array[int] = []
		overlay.chosen.connect(func(index: int) -> void: chosen.append(index))
		first_card.pressed.emit()
		assert_eq(chosen, [0], "the full-width card button must emit its choice")
		for index in range(3):
			var card := overlay.find_child("UpgradeCard%d" % (index + 1), true, false) as Button
			assert_true(card.visible, "all three options must remain available")
			var card_bounds := card.get_global_rect()
			for label_node in card.find_children("*", "Label", true, false):
				_assert_label(label_node as Label, card_bounds, "upgrade card %d %s" % [index + 1, canvas_size])

		var hud := RunHUD.new()
		add_child_autofree(hud)
		await wait_process_frames(2)
		hud._apply_responsive_layout_for(viewport_size, screen_size)
		hud.update_hud({"boss_active": true, "boss_name": "Wokou Vanguard", "boss_hp": 80, "boss_max_hp": 100})
		hud.show_banner(
			"A Long Lantern Watch Banner That Wraps Without Leaving The Screen",
			"A supporting message long enough to wrap while staying beneath important HUD values.",
			5.0
		)
		await wait_process_frames(3)
		var banner := hud.find_child("BannerPanel", true, false) as Control
		var boss := hud.find_child("BossPanel", true, false) as Control
		var banner_rect := banner.get_global_rect()
		assert_true(bounds.encloses(banner_rect), "portrait banner must stay inside %s" % canvas_size)
		var boss_rect := boss.get_global_rect()
		assert_true(bounds.encloses(boss_rect), "portrait boss notice must stay inside %s" % canvas_size)
		assert_false(banner_rect.intersects(boss_rect), "banner must stack below the active boss notice")
		for node_name in ["TopLeftChip", "AttackModeChip", "TimerChip", "ScoreChip", "MobilePauseButton"]:
			var hud_control := hud.find_child(node_name, true, false) as Control
			if hud_control != null and hud_control.visible:
				assert_false(banner_rect.intersects(hud_control.get_global_rect()), "banner must not cover %s" % node_name)
		var banner_title := hud.find_child("BannerTitle", true, false) as Label
		var banner_subtitle := hud.find_child("BannerSubtitle", true, false) as Label
		assert_gte(banner_title.get_line_count(), 2, "long banner title must wrap")
		_assert_label(banner_title, banner_rect, "portrait banner title %s" % canvas_size)
		_assert_label(banner_subtitle, banner_rect, "portrait banner subtitle %s" % canvas_size)
		host.queue_free()
		hud.queue_free()


func test_portrait_long_upgrade_copy_reflows_without_overlapping() -> void:
	var original_viewport_size: Vector2i = get_viewport().size
	for canvas_size in [Vector2i(360, 800), Vector2i(390, 844)]:
		var screen_size := Vector2(canvas_size)
		var viewport_size := _logical_viewport(screen_size)
		var scale := screen_size.x / viewport_size.x
		get_viewport().size = Vector2i(roundi(viewport_size.x), roundi(viewport_size.y))
		await wait_process_frames(2)
		var host := _host(viewport_size)
		var overlay := LevelUpOverlay.new()
		host.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await wait_process_frames(2)
		overlay._apply_responsive_layout_for(viewport_size, screen_size, Vector4(6.0, 24.0, 6.0, 20.0))
		var options := _upgrade_options()
		options[0]["title"] = "守望烽火连营 · 卫所器械全面整备"
		options[0]["description"] = "提升长枪与弩矢的命中距离，改善连续出手后的收招间隔，并让每次攻击保持清晰方向。此卡用于检查长文在手机窄屏上的折行、卡片高度、间距和触控命中区域。"
		options[0]["culture"] = "永昌堡沿海守望依赖烽火、巡夜与乡兵协作。此段仅展示文本布局，不新增史实陈述。"
		options[0]["effect_summary"] = "射程 +18% · 冷却 -10% · 额外箭矢 +1"
		overlay.show_options(options, 12, {"pool": 120, "taken": 36})
		await wait_process_frames(4)
		await wait_seconds(0.22)
		var card := overlay.find_child("UpgradeCard1", true, false) as Button
		var title := card.find_child("CardTitle", true, false) as Label
		var description := card.find_child("CardDescription", true, false) as Label
		var effect := card.find_child("CardEffect", true, false) as Label
		var culture_label := card.find_child("CardCultureLabel", true, false) as Label
		var culture := card.find_child("CardCulture", true, false) as Label
		var meta_rule := card.find_child("CardMetaRule", true, false) as Control
		var layout_epsilon := EPSILON / scale
		assert_lte(title.get_global_rect().end.y, description.get_global_rect().position.y + layout_epsilon)
		assert_lte(description.get_global_rect().end.y, effect.get_global_rect().position.y + layout_epsilon)
		assert_lte(effect.get_global_rect().end.y, culture_label.get_global_rect().position.y + layout_epsilon)
		assert_lte(culture_label.get_global_rect().end.y, culture.get_global_rect().position.y + layout_epsilon)
		assert_lte(culture.get_global_rect().end.y, meta_rule.get_global_rect().position.y + layout_epsilon)
		for label in [title, description, effect, culture_label, culture]:
			assert_gte(label.get_visible_line_count(), label.get_line_count(), "long copy must remain fully visible")
		assert_lte(card.size.y * scale, 280.0, "long-copy card should grow only to fit its measured text")
		host.queue_free()

	get_viewport().size = original_viewport_size
	await wait_process_frames(2)


func test_english_card_and_settlement_surfaces_do_not_clip_copy() -> void:
	var original_viewport_size: Vector2i = get_viewport().size
	get_viewport().size = Vector2i(DESIGN_W, DESIGN_H)
	await wait_process_frames(2)
	var host := _host(Vector2(DESIGN_W, DESIGN_H))
	var level_up := LevelUpOverlay.new()
	host.add_child(level_up)
	await wait_process_frames(2)
	var upgrade_options := _upgrade_options()
	level_up.show_options(upgrade_options, 12, {"pool": 120, "taken": 36})
	await wait_process_frames(3)
	_assert_surface(level_up, host.get_global_rect(), "level-up overlay")

	var shop := ShopOverlay.new()
	host.add_child(shop)
	await wait_process_frames(2)
	var hired: Array[String] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var offers := ShopCatalog.build_offers(
		[{"id": "saber", "level": 1}],
		{"gaiters": 1},
		hired,
		rng
	)
	shop.show_shop(offers, 500, 25, {
		"count": 3,
		"max": 3,
		"names": "Village Levies · Guest Soldiers · Incense Spirits",
	})
	await wait_process_frames(3)
	_assert_surface(shop, host.get_global_rect(), "shop overlay")

	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	run.elapsed = 959.0
	run.kills = 9999
	run.merit = 9999
	run.level = 30
	run._set_pause(true)
	await wait_process_frames(2)
	_assert_surface(run.pause_overlay, get_viewport().get_visible_rect(), "pause overlay")
	run._set_pause(false)
	run._show_result(true)
	await wait_process_frames(2)
	_assert_surface(run.result_overlay, get_viewport().get_visible_rect(), "result overlay")
	run.queue_free()
	host.queue_free()
	get_viewport().size = original_viewport_size
	await wait_process_frames(2)


func _host(canvas_size: Vector2) -> Control:
	var host := Control.new()
	host.name = "EnglishLayoutHost"
	host.position = Vector2.ZERO
	host.size = canvas_size
	add_child_autofree(host)
	return host


func _logical_viewport(screen_size: Vector2) -> Vector2:
	return Vector2(DESIGN_W, DESIGN_W * screen_size.y / screen_size.x)


func _upgrade_options() -> Array[Dictionary]:
	var pool := UpgradeCatalog.build_card_pool({}, {}, 0.8)
	var options: Array[Dictionary] = []
	for family in ["attribute", "skill", "event"]:
		for option in pool:
			if str(option.get("family", "")) == family:
				options.append(option)
				break
	return options


func _assert_surface(root: Node, bounds: Rect2, label: String) -> void:
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.size.x <= 0.0 or control.size.y <= 0.0:
			continue
		var scroll_child := _has_scroll_ancestor(control)
		if control is Label:
			var clip_rect := _clip_rect(control, bounds)
			if not scroll_child:
				_assert_inside(control.get_global_rect(), clip_rect, "%s: %s" % [label, _path(control)])
			_assert_label(control as Label, clip_rect, label, not scroll_child)
		elif control is Button:
			var clip_rect := _clip_rect(control, bounds)
			if not scroll_child:
				_assert_inside(control.get_global_rect(), clip_rect, "%s: %s" % [label, _path(control)])
			_assert_button(control as Button, clip_rect, label, not scroll_child)


func _assert_label(label: Label, clip_rect: Rect2, surface: String, check_bounds: bool = true) -> void:
	var text := label.text
	if text.strip_edges().is_empty():
		return
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var widest := 0.0
		for line in text.split("\n"):
			widest = maxf(widest, font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
		assert_lte(
			widest,
			label.size.x + EPSILON,
			"%s: text overflows width in %s (%s > %s): %s" % [
				surface,
				_path(label),
				widest,
				label.size.x,
				text,
			]
		)
	else:
		var lines := label.get_line_count()
		var visible_lines := label.get_visible_line_count()
		assert_gte(
			visible_lines,
			lines,
			"%s: wrapped text is vertically clipped in %s (%d/%d lines): %s" % [
				surface,
				_path(label),
				visible_lines,
				lines,
				text,
			]
		)
	assert_lte(
		label.get_minimum_size().y,
		label.size.y + EPSILON,
		"%s: label minimum height exceeds its rect in %s: %s" % [
			surface,
			_path(label),
			text,
		]
	)
	if check_bounds:
		_assert_inside(label.get_global_rect(), clip_rect, "%s: text %s" % [surface, _path(label)])


func _assert_button(button: Button, clip_rect: Rect2, surface: String, check_bounds: bool = true) -> void:
	var text := button.text
	if text.strip_edges().is_empty():
		return
	var font := button.get_theme_font("font")
	var font_size := button.get_theme_font_size("font_size")
	var widest := 0.0
	for line in text.split("\n"):
		widest = maxf(widest, font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	var style := button.get_theme_stylebox("normal")
	var margins := style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)
	assert_lte(
		widest + margins,
		button.size.x + EPSILON,
		"%s: button text overflows in %s (%s + %s > %s): %s" % [
			surface,
			_path(button),
			widest,
			margins,
			button.size.x,
			text,
		]
	)
	if check_bounds:
		_assert_inside(button.get_global_rect(), clip_rect, "%s: button %s" % [surface, _path(button)])


func _assert_inside(rect: Rect2, clip_rect: Rect2, label: String) -> void:
	assert_gte(rect.position.x, clip_rect.position.x - EPSILON, "%s crosses the left edge" % label)
	assert_gte(rect.position.y, clip_rect.position.y - EPSILON, "%s crosses the top edge" % label)
	assert_lte(rect.end.x, clip_rect.end.x + EPSILON, "%s crosses the right edge" % label)
	assert_lte(rect.end.y, clip_rect.end.y + EPSILON, "%s crosses the bottom edge" % label)


func _has_scroll_ancestor(control: Control) -> bool:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			return true
		ancestor = ancestor.get_parent()
	return false


func _clip_rect(control: Control, fallback: Rect2) -> Rect2:
	var rect := fallback
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			rect = rect.intersection((ancestor as Control).get_global_rect())
		elif ancestor is Control and (ancestor as Control).clip_contents:
			rect = rect.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	return rect


func _path(control: Control) -> String:
	return str(control.get_path())


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
