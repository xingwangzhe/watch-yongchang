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
	Locale.set_language("zh", false)
	AudioBus.menu_enabled = true


func after_each() -> void:
	SaveSystem.save_path = SaveSystem.SAVE_PATH
	GameSettings.config_path = GameSettings.CONFIG_PATH
	Locale.set_language("zh", false)
	GameSettings.language = "zh"
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
	assert_not_null(overlay)
	assert_not_null(start)
	assert_not_null(about)
	assert_not_null(timer, "the menu must own its autosave timer")
	assert_almost_eq(timer.wait_time, 20.0, 0.01)
	assert_false(timer.is_stopped(), "autosave timer must be running")
	assert_false(overlay.visible, "settings must start closed")
	assert_eq(start.text, Locale.t("menu.start"))
	assert_eq(about.text, Locale.t("menu.about"))
	menu.open_settings()
	await wait_process_frames(1)
	assert_true(overlay.visible, "open_settings must reveal the overlay")
	menu.close_settings()
	await wait_process_frames(1)
	assert_false(overlay.visible, "close_settings must hide the overlay")


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
