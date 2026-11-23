extends GutTest

const TEST_SAVE := "user://test_ui_foundation_save.json"
const TEST_SETTINGS := "user://test_ui_foundation_settings.cfg"


func before_each() -> void:
	SaveSystem.save_path = TEST_SAVE
	SaveSystem.reset_memory()
	GameSettings.config_path = TEST_SETTINGS
	GameSettings.language = "zh"
	GameSettings.bgm_volume = 0.62
	GameSettings.sfx_volume = 0.78
	GameSettings.fps_limit = GameSettings.DEFAULT_FPS_LIMIT
	GameSettings.vsync = true
	GameSettings._apply_performance()
	Locale.set_language("zh", false)
	AudioBus.menu_enabled = true


func after_each() -> void:
	SaveSystem.save_path = SaveSystem.SAVE_PATH
	GameSettings.config_path = GameSettings.CONFIG_PATH
	Locale.set_language("zh", false)
	GameSettings.language = "zh"
	GameSettings.fps_limit = GameSettings.DEFAULT_FPS_LIMIT
	GameSettings.vsync = true
	GameSettings._apply_performance()
	AudioBus.menu_enabled = true
	_remove_user_file(TEST_SAVE)
	_remove_user_file(TEST_SETTINGS)


func test_translation_tables_share_the_same_keys() -> void:
	var zh := Locale.table("zh")
	var en := Locale.table("en")
	assert_gt(zh.size(), 20, "zh table must contain the menu copy")
	assert_eq(zh.size(), en.size(), "language tables must stay aligned")
	for key in zh.keys():
		assert_true(en.has(key), "en is missing translation key: %s" % key)
		assert_true((zh[key] as String).length() > 0, "zh copy is empty: %s" % key)
		assert_true((en[key] as String).length() > 0, "en copy is empty: %s" % key)


func test_core_menu_keys_translate() -> void:
	for key in [
		"menu.start",
		"menu.settings",
		"menu.language",
		"panel.autosave",
		"settings.language",
		"run.title",
	]:
		assert_ne(Locale.t(key), key, "missing translated copy for %s" % key)


func test_save_roundtrip_keeps_progress() -> void:
	var payload := SaveSystem.default_data()
	payload["runs"] = 4
	payload["best_merit"] = 1200
	payload["last_mode"] = "run"
	assert_eq(SaveSystem.write_to(TEST_SAVE, payload), OK)
	var loaded := SaveSystem.load_from(TEST_SAVE)
	assert_eq(int(loaded.get("runs", 0)), 4)
	assert_eq(int(loaded.get("best_merit", 0)), 1200)
	assert_eq(str(loaded.get("last_mode", "")), "run")


func test_autosave_writes_settings_and_timestamp() -> void:
	SaveSystem.autosave({"runs": 2, "last_mode": "menu"})
	assert_true(FileAccess.file_exists(TEST_SAVE), "autosave must create the save file")
	var loaded := SaveSystem.load_from(TEST_SAVE)
	assert_eq(int(loaded.get("runs", 0)), 2)
	assert_eq(str(loaded.get("last_saved_local", "")).length(), 16)
	assert_eq(loaded.get("settings", {}).get("language", ""), "zh")


func test_begin_run_increments_and_autosaves() -> void:
	SaveSystem.data["runs"] = 2
	SaveSystem.begin_run()
	assert_eq(int(SaveSystem.data.get("runs", 0)), 3)
	var loaded := SaveSystem.load_from(TEST_SAVE)
	assert_eq(int(loaded.get("runs", 0)), 3)
	assert_eq(str(loaded.get("last_mode", "")), "run")
	assert_true(SaveSystem.has_progress())


func test_settings_file_persists_audio_values() -> void:
	GameSettings.set_bgm_volume(0.33)
	assert_true(FileAccess.file_exists(TEST_SETTINGS))
	var config := ConfigFile.new()
	assert_eq(config.load(TEST_SETTINGS), OK)
	assert_almost_eq(float(config.get_value("audio", "bgm_volume", 0.0)), 0.33, 0.001)


func test_settings_file_persists_fps_and_vsync() -> void:
	GameSettings.set_fps_limit(0)
	GameSettings.set_vsync(false)
	assert_true(FileAccess.file_exists(TEST_SETTINGS))
	var config := ConfigFile.new()
	assert_eq(config.load(TEST_SETTINGS), OK)
	assert_eq(int(config.get_value("display", "fps_limit", -1)), 0)
	assert_false(bool(config.get_value("display", "vsync", true)))
	assert_eq(Engine.max_fps, 0, "unlimited frame limit must clear the engine cap")


func test_audio_bus_loads_looping_bgm() -> void:
	AudioBus._sync_volume()
	assert_not_null(AudioBus.player)
	assert_true(AudioBus.stream is AudioStreamOggVorbis, "BGM must be an Ogg Vorbis stream")
	assert_true((AudioBus.stream as AudioStreamOggVorbis).loop, "BGM must loop")
	assert_almost_eq(AudioBus.player.volume_db, linear_to_db(0.62), 0.02)


func test_about_page_auto_scroll_and_wheel_takeover() -> void:
	var about := (load("res://scenes/about.tscn") as PackedScene).instantiate()
	add_child_autofree(about)
	await wait_process_frames(3)
	assert_true(about.is_auto_scrolling(), "about page must start auto-scrolling")
	assert_false(AudioBus.menu_enabled, "about page must stop the global menu BGM")
	assert_true(about.about_stream() is AudioStreamOggVorbis)
	assert_true((about.about_stream() as AudioStreamOggVorbis).loop)
	assert_not_null(about.about_player())

	var credits: Dictionary = about.credits_data()
	assert_eq((credits.get("music", []) as Array).size(), 2)
	for entry in credits.get("music", []):
		assert_true((entry.get("license", "") as String).begins_with("CC-BY"))
		assert_true((entry.get("url", "") as String).begins_with("https://"))
	var font_entry: Dictionary = (credits.get("fonts", []) as Array)[0]
	assert_string_contains(font_entry.get("notice_zh", ""), "OFL")
	var icon_entries: Array = credits.get("icons", [])
	assert_eq(icon_entries.size(), 12, "every used game-icons asset must be credited")
	for entry in icon_entries:
		assert_true(entry is Dictionary)
		assert_eq(str(entry.get("license", "")), "CC BY 3.0")
		assert_true(str(entry.get("url", "")).begins_with("https://game-icons.net/"))
		assert_true(ResourceLoader.exists(str(entry.get("file", ""))))
	var about_sections: Array = (credits.get("about", {}) as Dictionary).get("sections", [])
	var linked_sections: Array[Dictionary] = []
	for section in about_sections:
		if section is Dictionary and str(section.get("title_zh", "")) in ["致谢", "文化参考"]:
			linked_sections.append(section)
	assert_eq(linked_sections.size(), 2, "thanks and culture sections must be present")
	var found_official := false
	for section in linked_sections:
		var entries: Array = section.get("entries", [])
		assert_gt(entries.size(), 0, "linked sections must carry inline source entries")
		for entry in entries:
			assert_true(entry is Dictionary)
			var url := str(entry.get("url", ""))
			assert_true(url.begins_with("https://"), "inline source entries must link directly")
			assert_gt(str(entry.get("note_zh", "")).length(), 0)
			if url.begins_with("https://2026gamejam.osgame.org/"):
				found_official = true
	assert_true(found_official, "inline sources must include the official OSGJ site")
	assert_false(credits.has("references"), "sources must not be split into a separate block")
	assert_false(Locale.table("zh").has("about.references"))

	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	about._input(wheel)
	await wait_process_frames(1)
	assert_false(about.is_auto_scrolling(), "mouse wheel must stop auto-scroll")
	var status: Label = about.find_child("ScrollStatus", true, false)
	assert_string_contains(status.text, "滚轮已接管")


func test_about_scroll_container_wheel_takeover() -> void:
	var about := (load("res://scenes/about.tscn") as PackedScene).instantiate()
	add_child_autofree(about)
	await wait_process_frames(3)
	var scroll: ScrollContainer = about.find_child("CreditsScroll", true, false)
	assert_not_null(scroll)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	scroll.gui_input.emit(wheel)
	await wait_process_frames(1)
	assert_false(about.is_auto_scrolling(), "ScrollContainer wheel input must stop auto-scroll")
	var status: Label = about.find_child("ScrollStatus", true, false)
	assert_string_contains(status.text, "滚轮已接管")


func test_main_menu_builds_and_opens_settings() -> void:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_process_frames(3)
	var overlay: Control = menu.find_child("SettingsOverlay", true, false)
	var start: Button = menu.find_child("StartButton", true, false)
	var about: Button = menu.find_child("AboutButton", true, false)
	var timer: Timer = menu.find_child("AutosaveTimer", true, false)
	var fps_option: OptionButton = menu.find_child("FpsLimitOption", true, false)
	var vsync_toggle: CheckButton = menu.find_child("VsyncToggle", true, false)
	assert_not_null(overlay)
	assert_not_null(start)
	assert_not_null(about)
	assert_not_null(timer, "the menu must own its autosave timer")
	assert_not_null(fps_option, "the menu must expose a frame limit setting")
	assert_not_null(vsync_toggle, "the menu must expose a VSync setting")
	assert_almost_eq(timer.wait_time, 20.0, 0.01)
	assert_false(timer.is_stopped(), "autosave timer must be running")
	assert_false(overlay.visible, "settings must start closed")
	assert_eq(start.text, Locale.t("menu.start"))
	assert_eq(about.text, Locale.t("menu.about"))
	assert_eq(fps_option.get_item_text(fps_option.selected), "60 FPS")
	assert_eq(vsync_toggle.text, Locale.t("settings.on"))
	menu.open_settings()
	await wait_process_frames(1)
	assert_true(overlay.visible, "open_settings must reveal the overlay")
	var unlimited_index: int = GameSettings.FPS_LIMITS.find(0)
	fps_option.select(unlimited_index)
	fps_option.item_selected.emit(unlimited_index)
	vsync_toggle.set_pressed_no_signal(false)
	vsync_toggle.toggled.emit(false)
	await wait_process_frames(1)
	assert_eq(GameSettings.fps_limit, 0, "unlimited option must reach GameSettings")
	assert_false(GameSettings.vsync, "VSync toggle must reach GameSettings")
	assert_eq(Engine.max_fps, 0)
	menu.close_settings()
	await wait_process_frames(1)
	assert_false(overlay.visible, "close_settings must hide the overlay")


func test_main_menu_exposes_night_anchor_icons() -> void:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_process_frames(3)
	var anchors: HBoxContainer = menu.find_child("NightAnchors", true, false)
	assert_not_null(anchors, "the main menu must show the night-anchor icon row")
	assert_eq(anchors.get_child_count(), 5)
	for chip in anchors.get_children():
		var icon := chip.find_child("Icon", true, false) as TextureRect
		var label := chip.find_child("IconLabel", true, false) as Label
		assert_not_null(icon, "each night anchor must render an icon")
		assert_not_null(icon.texture)
		assert_not_null(label)
		assert_gt(label.text.length(), 0)


func test_run_placeholder_exposes_loadout_icons() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	var heading: Label = run.find_child("ArsenalHeading", true, false)
	var row: HBoxContainer = run.find_child("ArsenalRow", true, false)
	assert_not_null(heading)
	assert_not_null(row, "the run placeholder must show the loadout row")
	assert_eq(row.get_child_count(), 8)
	assert_eq(heading.text, Locale.t("run.arsenal"))
	for chip in row.get_children():
		var icon := chip.find_child("Icon", true, false) as TextureRect
		assert_not_null(icon, "each loadout card must render an icon")
		assert_not_null(icon.texture)
	Locale.set_language("en")
	await wait_process_frames(2)
	assert_eq(heading.text, "First Night Loadout")
	var first_label := row.get_child(0).find_child("IconLabel", true, false) as Label
	assert_eq(first_label.text, "Saber")


func test_game_icons_include_license_and_attribution() -> void:
	for path in [
		"res://assets/icons/game_icons/LICENSE-CC-BY-3.0.txt",
		"res://assets/icons/game_icons/ATTRIBUTION.md",
	]:
		assert_true(FileAccess.file_exists(path), "missing icon license file: %s" % path)


func test_language_switch_updates_live_menu_copy() -> void:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_process_frames(2)
	var language: Button = menu.find_child("LanguageButton", true, false)
	var start: Button = menu.find_child("StartButton", true, false)
	assert_string_contains(language.text, "中文")
	Locale.set_language("en")
	await wait_process_frames(2)
	assert_string_contains(language.text, "English")
	assert_eq(start.text, "Start Game")
	assert_eq(menu.find_child("SettingsButton", true, false).text, "Settings")


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
