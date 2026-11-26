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
			{"name": "Command Banner", "icon": "res://assets/icons/game_icons/wpn_banner.svg", "level": 5},
			{"name": "Long Spear", "icon": "res://assets/icons/game_icons/wpn_spear.svg", "level": 5},
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
		if control is Label:
			var clip_rect := _clip_rect(control, bounds)
			_assert_inside(control.get_global_rect(), clip_rect, "%s: %s" % [label, _path(control)])
			_assert_label(control as Label, clip_rect, label)
		elif control is Button:
			var clip_rect := _clip_rect(control, bounds)
			_assert_inside(control.get_global_rect(), clip_rect, "%s: %s" % [label, _path(control)])
			_assert_button(control as Button, clip_rect, label)


func _assert_label(label: Label, clip_rect: Rect2, surface: String) -> void:
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
	_assert_inside(label.get_global_rect(), clip_rect, "%s: text %s" % [surface, _path(label)])


func _assert_button(button: Button, clip_rect: Rect2, surface: String) -> void:
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
	_assert_inside(button.get_global_rect(), clip_rect, "%s: button %s" % [surface, _path(button)])


func _assert_inside(rect: Rect2, clip_rect: Rect2, label: String) -> void:
	assert_gte(rect.position.x, clip_rect.position.x - EPSILON, "%s crosses the left edge" % label)
	assert_gte(rect.position.y, clip_rect.position.y - EPSILON, "%s crosses the top edge" % label)
	assert_lte(rect.end.x, clip_rect.end.x + EPSILON, "%s crosses the right edge" % label)
	assert_lte(rect.end.y, clip_rect.end.y + EPSILON, "%s crosses the bottom edge" % label)


func _clip_rect(control: Control, fallback: Rect2) -> Rect2:
	var rect := fallback
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control and (ancestor as Control).clip_contents:
			rect = rect.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	return rect


func _path(control: Control) -> String:
	return str(control.get_path())


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
