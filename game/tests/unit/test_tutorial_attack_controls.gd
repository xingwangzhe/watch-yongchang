extends GutTest

const TEST_SAVE := "user://test_tutorial_attack_controls_save.json"
const CURSOR_PATH := "res://assets/ui/watch_cursor.webp"
const EXPECTED_ATTACK_BUFFER := 0.18


func before_each() -> void:
	SaveSystem.save_path = TEST_SAVE
	SaveSystem.reset_memory()
	SaveSystem.data["tutorial_seen"] = true
	InputSetup.reset_to_defaults()
	Locale.set_language("zh", false)
	_remove_user_file(TEST_SAVE)


func after_each() -> void:
	for action in InputSetup.ORDER:
		if Input.is_action_pressed(action):
			Input.action_release(action)
	SaveSystem.save_path = SaveSystem.SAVE_PATH
	SaveSystem.reset_memory()
	InputSetup.reset_to_defaults()
	Locale.set_language("zh", false)
	_remove_user_file(TEST_SAVE)


func test_tutorial_save_default_migration_and_completion() -> void:
	var defaults := SaveSystem.default_data()
	assert_eq(SaveSystem.SAVE_VERSION, 2)
	assert_false(bool(defaults.get("tutorial_seen", true)))

	var legacy := defaults.duplicate(true)
	legacy.erase("tutorial_seen")
	assert_eq(SaveSystem.write_to(TEST_SAVE, legacy), OK)
	var migrated := SaveSystem.load_from(TEST_SAVE)
	assert_false(bool(migrated.get("tutorial_seen", true)), "old saves must receive the tutorial default")

	SaveSystem.complete_tutorial()
	assert_true(bool(SaveSystem.data.get("tutorial_seen", false)))
	assert_true(bool(SaveSystem.load_from(TEST_SAVE).get("tutorial_seen", false)))


func test_first_run_shows_bilingual_paged_tutorial_and_skip_persists() -> void:
	var run: Variant = await _open_first_run_tutorial()
	var overlay := run.tutorial_overlay as TutorialOverlay
	assert_true(overlay.visible)
	assert_true(run._paused)
	assert_false(run._run_started)
	var saved_before_close := SaveSystem.load_from(TEST_SAVE)
	assert_true(bool(saved_before_close.get("intro_seen", false)), "intro completion must save before the tutorial")
	assert_false(bool(saved_before_close.get("tutorial_seen", false)))
	assert_eq(overlay._tabs.size(), TutorialOverlay.PAGE_COUNT)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_STOP)

	var outcomes: Array[bool] = []
	overlay.closed.connect(func(skipped: bool) -> void: outcomes.append(skipped))
	var controls_title := str(overlay._page_title.text)
	overlay._next_button.pressed.emit()
	assert_eq(overlay._page, 1)
	assert_ne(str(overlay._page_title.text), controls_title)
	overlay._prev_button.pressed.emit()
	assert_eq(overlay._page, 0, "previous must read the current page after navigation")
	overlay._go_page(2)
	assert_eq(str(overlay._next_button.text), Locale.t("tutorial.finish"))

	Locale.set_language("en", false)
	assert_string_contains(str(overlay._page_title.text), "Systems")
	overlay._go_page(0)
	assert_string_contains(str(overlay._body.text), "Hold-click")
	assert_string_contains(str(overlay._body.text), "nearest enemy")
	assert_string_contains(str(overlay._body.text), "Press X")

	overlay._skip_button.pressed.emit()
	assert_false(overlay.visible)
	assert_eq(outcomes, [true])
	assert_true(run._run_started)
	assert_false(run._paused)
	assert_true(bool(SaveSystem.data.get("tutorial_seen", false)))
	assert_true(bool(SaveSystem.load_from(TEST_SAVE).get("tutorial_seen", false)))


func test_first_run_tutorial_finish_starts_gameplay_without_skip_flag() -> void:
	var run: Variant = await _open_first_run_tutorial()
	var overlay := run.tutorial_overlay as TutorialOverlay
	var outcomes: Array[bool] = []
	overlay.closed.connect(func(skipped: bool) -> void: outcomes.append(skipped))
	overlay._go_page(TutorialOverlay.PAGE_COUNT - 1)
	overlay._next_button.pressed.emit()
	assert_eq(outcomes, [false])
	assert_true(run._run_started)
	assert_false(run._paused)
	assert_true(bool(SaveSystem.load_from(TEST_SAVE).get("tutorial_seen", false)))


func test_pause_and_main_menu_can_replay_tutorial() -> void:
	var run: Variant = await _started_run()
	run._set_pause(true)
	var replay := run.pause_overlay.find_child("PauseTutorialButton", true, false) as Button
	assert_not_null(replay)
	replay.pressed.emit()
	assert_true(run.tutorial_overlay.visible)
	assert_false(run.pause_overlay.visible)
	run.tutorial_overlay._finish(false)
	assert_false(run.tutorial_overlay.visible)
	assert_true(run._paused, "finishing a pause replay must return to pause")
	assert_true(run.pause_overlay.visible)

	SaveSystem.data["tutorial_seen"] = false
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_process_frames(3)
	var menu_replay := menu.find_child("TutorialButton", true, false) as Button
	assert_not_null(menu_replay)
	menu_replay.pressed.emit()
	assert_true(menu._tutorial_overlay.visible)
	assert_eq(menu._start_button.focus_mode, Control.FOCUS_NONE)
	menu._tutorial_overlay._finish(false)
	assert_false(menu._tutorial_overlay.visible)
	assert_eq(menu._start_button.focus_mode, Control.FOCUS_ALL)
	assert_true(bool(SaveSystem.load_from(TEST_SAVE).get("tutorial_seen", false)))


func test_tutorial_copy_covers_controls_culture_and_systems_in_both_languages() -> void:
	Locale.set_language("zh", false)
	var controls := Locale.t("tutorial.page1.body")
	for phrase in ["WASD", "Space", "鼠标", "长按点击持续攻击", "单点工具攻击", "按 X", "最近敌人", "Esc", "首 1 秒"]:
		assert_string_contains(controls, phrase)
	assert_string_contains(Locale.t("tutorial.page2.body"), "1386")
	assert_string_contains(Locale.t("tutorial.page2.body"), "1559")
	assert_string_contains(Locale.t("tutorial.page3.body"), "军市")
	assert_string_contains(Locale.t("tutorial.page3.body"), "风险与收益")

	Locale.set_language("en", false)
	controls = Locale.t("tutorial.page1.body")
	for phrase in ["WASD", "Space", "Hold-click", "single click", "Press X", "nearest enemy", "Esc", "1 second"]:
		assert_string_contains(controls, phrase)
	assert_string_contains(Locale.t("tutorial.page2.body"), "1386")
	assert_string_contains(Locale.t("tutorial.page2.body"), "1559")
	assert_string_contains(Locale.t("tutorial.page3.body"), "market")
	assert_string_contains(Locale.t("tutorial.page3.body"), "risk-and-reward")


func test_tutorial_keyboard_pages_and_closes() -> void:
	var overlay := TutorialOverlay.new()
	add_child_autofree(overlay)
	await wait_process_frames(2)
	var outcomes: Array[bool] = []
	overlay.closed.connect(func(skipped: bool) -> void: outcomes.append(skipped))
	overlay.open(false)
	overlay._input(_key_event(KEY_RIGHT))
	assert_eq(overlay._page, 1)
	overlay._input(_key_event(KEY_ENTER))
	assert_eq(overlay._page, 2)
	overlay._unhandled_input(_key_event(KEY_ESCAPE))
	assert_false(overlay.visible)
	assert_eq(outcomes, [false], "Esc must close a replay without marking it as skipped")


func test_auto_attack_action_toggles_and_updates_hud() -> void:
	assert_true(InputSetup.tokens_for("toggle_auto_attack").has("k:%d" % KEY_X))
	var run: Variant = await _started_run()
	run._attack_held = true
	run._attack_buffer = EXPECTED_ATTACK_BUFFER
	run._unhandled_input(_key_event(KEY_X))
	assert_true(run._auto_attack)
	assert_false(run._attack_held)
	assert_eq(run._attack_buffer, 0.0)
	var mode := run.hud.find_child("AttackModeLabel", true, false) as Label
	var toggle := run.hud.find_child("AttackToggleLabel", true, false) as Label
	assert_eq(str(mode.text), Locale.t("hud.attack_auto"))
	assert_string_contains(str(toggle.text), "X")

	run._unhandled_input(_key_event(KEY_X))
	assert_false(run._auto_attack)
	assert_eq(str(mode.text), Locale.t("hud.attack_manual"))


func test_quick_click_buffers_until_ready_then_fires_once() -> void:
	var run: Variant = await _started_run()
	run.battlefield.jeff_effects.clear()
	for weapon in run.weapons:
		weapon["timer"] = 0.05
	var before: int = run.battlefield.jeff_effects.size()
	run._unhandled_input(_mouse_button_event(Vector2(640, 360), true))
	run._unhandled_input(_mouse_button_event(Vector2(640, 360), false))
	assert_almost_eq(run._attack_buffer, EXPECTED_ATTACK_BUFFER, 0.001)
	run._update_weapons(0.06)
	assert_gt(run.battlefield.jeff_effects.size(), before, "a buffered click must fire when the weapon becomes ready")
	assert_eq(run._attack_buffer, 0.0, "the click buffer must be consumed by the volley")
	var after_click: int = run.battlefield.jeff_effects.size()
	run._update_weapons(0.06)
	assert_eq(run.battlefield.jeff_effects.size(), after_click, "one quick click must not become continuous fire")


func test_quick_click_buffer_expires_without_a_late_attack() -> void:
	var run: Variant = await _started_run()
	run.battlefield.jeff_effects.clear()
	for weapon in run.weapons:
		weapon["timer"] = 10.0
	run._unhandled_input(_mouse_button_event(Vector2(640, 360), true))
	run._update_player(EXPECTED_ATTACK_BUFFER + 0.01)
	assert_eq(run._attack_buffer, 0.0)
	for weapon in run.weapons:
		weapon["timer"] = 0.0
	run._update_weapons(0.01)
	assert_eq(run.battlefield.jeff_effects.size(), 0, "an expired click must not attack later")


func test_manual_hold_fires_until_release() -> void:
	var run: Variant = await _started_run()
	run.battlefield.jeff_effects.clear()
	for weapon in run.weapons:
		weapon["timer"] = 0.0
	Input.action_press("attack")
	run._update_player(1.0 / 60.0)
	assert_true(run._attack_held)
	run._update_weapons(0.01)
	assert_gt(run.battlefield.jeff_effects.size(), 0)
	Input.action_release("attack")
	run._update_player(1.0 / 60.0)
	assert_false(run._attack_held)
	var released_count: int = run.battlefield.jeff_effects.size()
	run._update_weapons(0.01)
	assert_eq(run.battlefield.jeff_effects.size(), released_count)


func test_auto_mode_aims_at_nearest_living_enemy_and_fires_without_mouse() -> void:
	var run: Variant = await _started_run()
	run.battlefield.enemies.clear()
	var origin: Vector2 = run.battlefield.player_spawn_position()
	run.player["pos"] = origin
	var dead_index: int = run.battlefield.spawn_enemy_at("scout", origin + Vector2(10, 0))
	var near_index: int = run.battlefield.spawn_enemy_at("scout", origin + Vector2(80, -30))
	run.battlefield.spawn_enemy_at("scout", origin + Vector2(300, 0))
	run.battlefield.enemies[dead_index]["alive"] = false
	var nearest: Dictionary = run.battlefield.nearest_enemy_any(origin)
	assert_eq(nearest, run.battlefield.enemies[near_index], "dead enemies must not win auto targeting")

	run._auto_attack = true
	run._release_attack()
	run._mouse_screen_pos = run.get_viewport().get_canvas_transform() * Vector2(500, 0)
	run._has_mouse_screen_pos = true
	run._update_player(1.0 / 60.0)
	var expected: Vector2 = ((nearest["pos"] as Vector2) - origin).normalized()
	assert_almost_eq(run._aim_direction.x, expected.x, 0.001)
	assert_almost_eq(run._aim_direction.y, expected.y, 0.001)
	assert_eq(run.battlefield.player_aim, run._aim_direction)

	run.battlefield.jeff_effects.clear()
	for weapon in run.weapons:
		weapon["timer"] = 0.0
	run._update_weapons(0.01)
	assert_gt(run.battlefield.jeff_effects.size(), 0, "auto mode must fire without a held mouse button")


func test_pause_focus_and_tutorial_clear_attack_state_and_block_toggle() -> void:
	var run: Variant = await _started_run()
	run._attack_held = true
	run._attack_buffer = EXPECTED_ATTACK_BUFFER
	run._set_pause(true)
	assert_false(run._attack_held)
	assert_eq(run._attack_buffer, 0.0)
	var effects_before: int = run.battlefield.jeff_effects.size()
	run._unhandled_input(_mouse_button_event(Vector2(640, 360), true))
	run._unhandled_input(_key_event(KEY_X))
	assert_eq(run._attack_buffer, 0.0, "pause must block click buffering")
	assert_false(run._auto_attack, "pause must block the auto-attack toggle")
	run._auto_attack = true
	run._update_player(1.0 / 60.0)
	run._update_weapons(1.0 / 60.0)
	assert_eq(run.battlefield.jeff_effects.size(), effects_before, "UI pause must block direct weapon updates")
	run._auto_attack = false
	run._set_pause(false)

	run._attack_held = true
	run._attack_buffer = EXPECTED_ATTACK_BUFFER
	run._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(run._attack_held)
	assert_eq(run._attack_buffer, 0.0)

	run._attack_held = true
	run._attack_buffer = EXPECTED_ATTACK_BUFFER
	run._open_tutorial(false)
	assert_false(run._attack_held)
	assert_eq(run._attack_buffer, 0.0)
	run._unhandled_input(_key_event(KEY_X))
	assert_false(run._auto_attack, "gameplay shortcuts must not fire through the tutorial")
	run.tutorial_overlay._finish(false)


func test_aim_indicator_is_short_arc_and_follows_the_actual_vector() -> void:
	var center := Vector2(100, 100)
	var right := Battlefield.aim_indicator_geometry(center, Vector2.RIGHT)
	assert_eq(right["mid"], Vector2(182, 100))
	assert_almost_eq((right["start"] as Vector2).distance_to(center), 82.0, 0.001)
	assert_almost_eq((right["tip"] as Vector2).distance_to(center), 82.0, 0.001)
	assert_almost_eq(
		(right["start"] as Vector2).distance_to(right["tip"] as Vector2),
		164.0 * sin(deg_to_rad(18.0)),
		0.001
	)
	var left := Battlefield.aim_indicator_geometry(center, Vector2.LEFT)
	assert_eq(left["mid"], Vector2(18, 100))
	var fallback := Battlefield.aim_indicator_geometry(Vector2.ZERO, Vector2.ZERO)
	assert_eq(fallback["mid"], Vector2(82, 0))


func test_cursor_asset_and_headless_lifecycle() -> void:
	assert_true(ResourceLoader.exists(CURSOR_PATH))
	var texture := load(CURSOR_PATH) as Texture2D
	assert_not_null(texture)
	if texture != null:
		assert_eq(texture.get_size(), Vector2(24, 24))
	var run: Variant = await _started_run()
	if DisplayServer.get_name() == "headless":
		run._set_gameplay_cursor(true)
		assert_false(run._gameplay_cursor_active, "headless tests must never install a system cursor")
	run._set_gameplay_cursor(false)
	assert_false(run._gameplay_cursor_active)


func test_custom_cursor_scope_tracks_gameplay_ui() -> void:
	var run: Variant = await _started_run()
	assert_true(run._gameplay_cursor_should_show())
	run._set_pause(true)
	assert_false(run._gameplay_cursor_should_show(), "pause must restore the system cursor")
	run._set_pause(false)
	assert_true(run._gameplay_cursor_should_show())

	run._open_shop()
	assert_false(run._gameplay_cursor_should_show(), "shop must restore the system cursor")
	run._on_shop_closed()
	assert_true(run._gameplay_cursor_should_show())

	run._open_tutorial(false)
	assert_false(run._gameplay_cursor_should_show(), "tutorial must restore the system cursor")
	run.tutorial_overlay._finish(false)
	assert_false(run._gameplay_cursor_should_show(), "closing a replay returns to pause")
	run._set_pause(false)
	assert_true(run._gameplay_cursor_should_show())

	run._open_codex()
	assert_false(run._gameplay_cursor_should_show(), "codex must restore the system cursor")
	run.codex_overlay._return_to_menu()
	assert_true(run._gameplay_cursor_should_show())


func test_run_upgrade_shortcut_respects_the_same_input_lock() -> void:
	var run: Variant = await _started_run()
	run._add_xp(float(run.xp_need))
	assert_true(run.level_up_overlay.visible)
	assert_true(run.level_up_overlay.is_locked())
	var pending_before: int = run._pending_levels
	run._on_upgrade_chosen(0)
	assert_true(run.level_up_overlay.visible, "the run handler must not bypass the overlay lock")
	assert_eq(run._pending_levels, pending_before)

	run.level_up_overlay._unlock_at_msec = Time.get_ticks_msec() - 1
	run.level_up_overlay._process(0.0)
	run._on_upgrade_chosen(0)
	assert_false(run.level_up_overlay.visible, "selection must work once the lock expires")
	assert_eq(run._pending_levels, pending_before - 1)


func _open_first_run_tutorial():
	SaveSystem.data["tutorial_seen"] = false
	SaveSystem.data["intro_seen"] = false
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	assert_true(run.story.visible)
	run.story._skip_all()
	await wait_process_frames(3)
	return run


func _started_run():
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	await wait_process_frames(2)
	return run


func _key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


func _mouse_button_event(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	return event


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
