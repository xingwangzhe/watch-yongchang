extends GutTest

const TEST_SAVE := "user://test_ui_foundation_save.json"
const TEST_SETTINGS := "user://test_ui_foundation_settings.cfg"
const TEST_RENDERER_MIRROR := "user://test_ui_foundation_renderer.cfg"


func before_each() -> void:
	SaveSystem.save_path = TEST_SAVE
	SaveSystem.reset_memory()
	SaveSystem.data["tutorial_seen"] = true
	GameSettings.config_path = TEST_SETTINGS
	GameSettings.renderer_mirror_override = TEST_RENDERER_MIRROR
	GameSettings.language = "zh"
	GameSettings.bgm_volume = GameSettings.DEFAULT_BGM_VOLUME
	GameSettings.sfx_volume = 0.78
	GameSettings.fps_limit = GameSettings.DEFAULT_FPS_LIMIT
	GameSettings.vsync = true
	GameSettings.renderer_mode = GameSettings.RENDERER_AUTO
	GameSettings.vulkan_probe_override = 1
	GameSettings.web_platform_override = -1
	GameSettings.web_capabilities = {
		"webgl2": true,
		"renderer": "",
		"webgpu_api": false,
	}
	GameSettings.active_renderer_override = GameSettings.RENDERER_VULKAN
	GameSettings.restart_enabled = false
	GameSettings.bindings.clear()
	InputSetup.reset_to_defaults()
	GameSettings.reset_vulkan_probe()
	GameSettings._apply_performance()
	Locale.set_language("zh", false)
	AudioBus.menu_enabled = true
	AudioBus.resume_bgm()


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
	GameSettings.web_capabilities = {
		"webgl2": true,
		"renderer": "",
		"webgpu_api": false,
	}
	GameSettings.active_renderer_override = ""
	GameSettings.restart_enabled = true
	GameSettings.bindings.clear()
	InputSetup.reset_to_defaults()
	GameSettings.reset_vulkan_probe()
	GameSettings._apply_performance()
	AudioBus.menu_enabled = true
	AudioBus.resume_bgm()
	_remove_user_file(TEST_SAVE)
	_remove_user_file(TEST_SETTINGS)
	_remove_user_file(TEST_RENDERER_MIRROR)


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
	payload["total_merit"] = 2000
	payload["last_mode"] = "run"
	assert_eq(SaveSystem.write_to(TEST_SAVE, payload), OK)
	var loaded := SaveSystem.load_from(TEST_SAVE)
	assert_eq(int(loaded.get("runs", 0)), 4)
	assert_eq(int(loaded.get("best_merit", 0)), 1200)
	assert_eq(int(loaded.get("total_merit", 0)), 2000)
	assert_eq(str(loaded.get("last_mode", "")), "run")


func test_record_run_accumulates_merit_and_unlocks() -> void:
	SaveSystem.record_run(1200, 400, false, 300.0)
	SaveSystem.record_run(600, 220, true, 960.0)
	assert_eq(int(SaveSystem.data.get("total_merit", 0)), 1800)
	assert_eq(int(SaveSystem.data.get("best_merit", 0)), 1200)
	assert_eq(int(SaveSystem.data.get("best_kills", 0)), 400)
	assert_eq(int(SaveSystem.data.get("runs_won", 0)), 1)
	assert_almost_eq(float(SaveSystem.data.get("best_time", 0.0)), 960.0, 0.01)


func test_autosave_writes_settings_and_timestamp() -> void:
	SaveSystem.autosave({"runs": 2, "last_mode": "menu"})
	assert_true(FileAccess.file_exists(TEST_SAVE), "autosave must create the save file")
	var loaded := SaveSystem.load_from(TEST_SAVE)
	assert_eq(int(loaded.get("runs", 0)), 2)
	assert_eq(str(loaded.get("last_saved_local", "")).length(), 16)
	assert_eq(loaded.get("settings", {}).get("language", ""), "zh")


func test_begin_run_increments_and_autosaves() -> void:
	SaveSystem.data["runs"] = 2
	var first_seed := SaveSystem.begin_run()
	assert_eq(int(SaveSystem.data.get("runs", 0)), 3)
	assert_eq(int(SaveSystem.data.get("last_run_seed", 0)), first_seed)
	var loaded := SaveSystem.load_from(TEST_SAVE)
	assert_eq(int(loaded.get("runs", 0)), 3)
	assert_eq(str(loaded.get("last_mode", "")), "run")
	assert_eq(int(loaded.get("last_run_seed", 0)), first_seed)
	assert_true(SaveSystem.has_progress())
	var second_seed := SaveSystem.begin_run()
	assert_ne(second_seed, first_seed, "separate runs must receive different root seeds")


func test_run_purpose_seeds_are_reproducible_and_separated() -> void:
	var seed_a := SaveSystem.make_run_seed(7, 1_700_000_000_123_456, 98_765, 0)
	var seed_a_repeat := SaveSystem.make_run_seed(7, 1_700_000_000_123_456, 98_765, 0)
	var seed_b := SaveSystem.make_run_seed(8, 1_700_000_000_123_456, 98_765, seed_a)
	assert_eq(seed_a_repeat, seed_a, "same run identity must reproduce its root seed")
	assert_ne(seed_b, seed_a, "a new run number must change its root seed")
	assert_eq(SaveSystem.derive_seed(seed_a, "gameplay"), SaveSystem.derive_seed(seed_a, "gameplay"))
	assert_ne(
		SaveSystem.derive_seed(seed_a, "gameplay"),
		SaveSystem.derive_seed(seed_a, "world"),
		"gameplay and world must use independent purpose seeds"
	)
	assert_ne(
		SaveSystem.derive_seed(seed_a, "gameplay"),
		SaveSystem.derive_seed(seed_b, "gameplay"),
		"different run seeds must produce different gameplay seeds"
	)


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


func test_platform_default_frame_limit_is_capped_on_every_platform() -> void:
	GameSettings.web_platform_override = 1
	# Web 单线程 WASM 不限帧会持续跑满主线程并触发降频；固定 60 更稳。
	assert_eq(GameSettings.default_fps_limit(), 60)
	GameSettings.web_platform_override = 0
	assert_eq(GameSettings.default_fps_limit(), GameSettings.DEFAULT_FPS_LIMIT)


func test_settings_file_persists_custom_bindings() -> void:
	var token := "k:%d" % KEY_SHIFT
	GameSettings.set_binding("dash", token)
	var config := ConfigFile.new()
	assert_eq(config.load(TEST_SETTINGS), OK)
	var stored: Dictionary = config.get_value("input", "bindings", {}) as Dictionary
	assert_eq(stored.get("dash", []), [token])
	assert_true(InputSetup.tokens_for("dash").has(token), "binding must reach the InputMap")
	assert_eq(InputSetup.conflict_for("dash", "k:%d" % KEY_A), "move_left")


func test_reset_bindings_restores_defaults() -> void:
	GameSettings.set_binding("dash", "k:%d" % KEY_SHIFT)
	GameSettings.reset_bindings()
	assert_true(GameSettings.bindings.is_empty())
	assert_true(InputSetup.tokens_for("dash").has("k:%d" % KEY_SPACE))
	assert_true(
		InputSetup.describe("attack").contains(Locale.t("input.mouse_left")),
		"default attack must describe the left mouse button"
	)


func test_main_menu_moves_codex_to_menu_and_opens_controls() -> void:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_process_frames(3)
	assert_null(
		menu.find_child("CodexButton", true, false),
		"the watch panel must no longer host the codex entry"
	)
	assert_not_null(
		menu.find_child("MenuCodexButton", true, false),
		"the codex entry must live in the menu column"
	)
	var controls_overlay: Control = menu.find_child("ControlsOverlay", true, false)
	assert_not_null(controls_overlay)
	assert_false(controls_overlay.visible, "the controls panel must start closed")
	assert_not_null(menu.find_child("ControlsButton", true, false), "settings must expose a controls button")
	var version_label := menu.find_child("Version", true, false) as Label
	assert_not_null(version_label)
	assert_eq(version_label.text, "v%s" % ProjectMeta.version)
	var music_title := menu.find_child("MusicTitle", true, false) as Label
	assert_not_null(music_title)
	assert_string_contains(str(music_title.text), "Samurai Nights")
	assert_string_contains(str(music_title.text), "Majadroid")
	assert_false(str(music_title.text).contains("Yongchang Watch"), "restored BGM must be advertised")
	menu.open_settings()
	menu.open_controls()
	await wait_process_frames(1)
	assert_true(controls_overlay.visible, "the controls panel must open from settings")
	for action in InputSetup.ORDER:
		assert_not_null(menu.find_child("Row_%s" % action, true, false), "missing rebind row: %s" % action)
		assert_not_null(menu.find_child("Binding_%s" % action, true, false))
	menu.close_controls()
	await wait_process_frames(1)
	assert_false(controls_overlay.visible, "closing controls must hide the panel")
	menu.close_settings()


func test_auto_renderer_prefers_vulkan_when_supported() -> void:
	GameSettings.renderer_mode = GameSettings.RENDERER_AUTO
	GameSettings.vulkan_probe_override = 1
	GameSettings.active_renderer_override = GameSettings.RENDERER_VULKAN
	assert_true(GameSettings.vulkan_supported())
	assert_eq(GameSettings.resolved_renderer(), GameSettings.RENDERER_VULKAN)
	assert_false(GameSettings.renderer_requires_restart())


func test_auto_renderer_falls_back_to_opengl_without_vulkan() -> void:
	GameSettings.renderer_mode = GameSettings.RENDERER_AUTO
	GameSettings.vulkan_probe_override = 0
	GameSettings.active_renderer_override = GameSettings.RENDERER_OPENGL
	assert_false(GameSettings.vulkan_supported())
	assert_eq(GameSettings.resolved_renderer(), GameSettings.RENDERER_OPENGL)
	assert_false(GameSettings.renderer_requires_restart())


func test_linux_vulkan_probe_tolerates_missing_driver_directories() -> void:
	var probe_result: bool = GameSettings._has_linux_vulkan_device()
	assert_true(probe_result is bool, "missing driver directories must not emit engine errors")


func test_manual_vulkan_falls_back_when_unsupported() -> void:
	GameSettings.renderer_mode = GameSettings.RENDERER_VULKAN
	GameSettings.vulkan_probe_override = 0
	assert_eq(GameSettings.resolved_renderer(), GameSettings.RENDERER_OPENGL)


func test_renderer_mode_persists_and_builds_restart_args() -> void:
	GameSettings.vulkan_probe_override = 1
	GameSettings.set_renderer_mode(GameSettings.RENDERER_OPENGL)
	var config := ConfigFile.new()
	assert_eq(config.load(TEST_SETTINGS), OK)
	assert_eq(
		str(config.get_value("rendering", "renderer_mode", "")),
		GameSettings.RENDERER_OPENGL
	)
	var mirror := FileAccess.open(TEST_RENDERER_MIRROR, FileAccess.READ)
	assert_not_null(mirror)
	assert_string_contains(mirror.get_as_text(), "renderer_mode=\"opengl\"")
	var args := GameSettings.renderer_restart_args()
	var method_index := args.find("--rendering-method")
	var driver_index := args.find("--rendering-driver")
	assert_true(method_index >= 0)
	assert_true(driver_index >= 0)
	assert_eq(args[method_index + 1], "gl_compatibility")
	assert_eq(args[driver_index + 1], "opengl3")


func test_renderer_mirror_is_loaded_without_settings_file() -> void:
	_remove_user_file(TEST_SETTINGS)
	var mirror := FileAccess.open(TEST_RENDERER_MIRROR, FileAccess.WRITE)
	assert_not_null(mirror)
	mirror.store_line("renderer_mode=\"opengl\"")
	mirror.close()
	GameSettings.renderer_mode = GameSettings.RENDERER_AUTO
	GameSettings.load_settings()
	assert_eq(GameSettings.renderer_mode, GameSettings.RENDERER_OPENGL)


func test_audio_bus_loads_looping_bgm() -> void:
	assert_almost_eq(GameSettings.DEFAULT_BGM_VOLUME, 0.28, 0.001, "default BGM must be lowered")
	AudioBus._sync_volume()
	assert_not_null(AudioBus.player)
	assert_true(AudioBus.stream is AudioStreamOggVorbis, "BGM must be an Ogg Vorbis stream")
	assert_true((AudioBus.stream as AudioStreamOggVorbis).loop, "BGM must loop")
	assert_almost_eq(AudioBus.player.volume_db, linear_to_db(GameSettings.DEFAULT_BGM_VOLUME), 0.02)
	assert_true(AudioBus.battle_stream is AudioStreamOggVorbis, "battle BGM must load")
	assert_true((AudioBus.battle_stream as AudioStreamOggVorbis).loop, "battle BGM must loop")
	assert_true(AudioBus.UI_CLICK_STREAM is AudioStreamOggVorbis, "UI click must load")
	for path in [
		"res://assets/audio/bgm_battle.ogg",
		"res://assets/audio/ui_click.ogg",
		"res://assets/audio/ui_confirm.ogg",
		"res://assets/audio/ui_back.ogg",
		"res://assets/audio/sfx_pickup.ogg",
		"res://assets/audio/sfx_event.ogg",
		"res://assets/audio/sfx_enemy_hit.ogg",
		"res://assets/audio/sfx_enemy_kill.ogg",
		"res://assets/audio/sfx_elite_kill.ogg",
		"res://assets/audio/sfx_level_up.ogg",
		"res://assets/audio/sfx_dash.ogg",
		"res://assets/audio/sfx_boss.ogg",
	]:
		assert_true(ResourceLoader.exists(path), "missing audio asset: %s" % path)


func test_audio_bus_switches_menu_and_battle_bgm() -> void:
	AudioBus.play_battle_bgm()
	assert_eq(AudioBus.current_bgm, "battle")
	assert_eq(AudioBus.stream, AudioBus.battle_stream)
	AudioBus.resume_bgm()
	assert_eq(AudioBus.current_bgm, "menu")
	assert_eq(AudioBus.stream, AudioBus.menu_stream)


func test_audio_bus_binds_button_clicks_once() -> void:
	var button := Button.new()
	add_child_autofree(button)
	AudioBus._bind_button(button)
	AudioBus._bind_button(button)
	assert_true(button.has_meta("audio_click_bound"))
	assert_eq(button.get_signal_connection_list("pressed").size(), 1)


func test_about_page_auto_scroll_and_wheel_takeover() -> void:
	var about := (load("res://scenes/about.tscn") as PackedScene).instantiate()
	add_child_autofree(about)
	await wait_process_frames(3)
	assert_true(about.is_auto_scrolling(), "about page must start auto-scrolling")
	assert_false(AudioBus.menu_enabled, "about page must stop the global menu BGM")
	assert_true(about.about_stream() is AudioStreamOggVorbis)
	assert_true((about.about_stream() as AudioStreamOggVorbis).loop)
	assert_not_null(about.about_player())
	assert_ne(about.about_stream().resource_path, AudioBus.menu_stream.resource_path, "about music must be distinct")

	var credits: Dictionary = about.credits_data()
	assert_eq(
		str(ProjectSettings.get_setting("application/config/version", "")),
		ProjectMeta.version
	)
	var free_software: Dictionary = credits.get("free_software", {})
	assert_false(free_software.is_empty(), "the roll must open with a free-software statement")
	assert_string_contains(str(free_software.get("lines_zh", [""])[0]), "自由软件")
	assert_string_contains(str(free_software.get("lines_zh", [""])[1]), "AGPL-3.0-or-later")
	assert_string_contains(str(free_software.get("lines_zh", [""])[1]), "CC BY 4.0")
	var music_entries: Array = credits.get("music", [])
	assert_eq(music_entries.size(), 3)
	var allowed_music_licenses := {
		"CC0 1.0": "https://creativecommons.org/publicdomain/zero/1.0/",
		"CC BY 3.0": "https://creativecommons.org/licenses/by/3.0/",
		"CC BY 4.0": "https://creativecommons.org/licenses/by/4.0/",
		"CC0 1.0 or CC BY 4.0": "https://creativecommons.org/publicdomain/zero/1.0/",
	}
	var music_files: Array[String] = []
	for entry in music_entries:
		var license_id := str(entry.get("license", ""))
		assert_true(allowed_music_licenses.has(license_id), "every shipped BGM must use an open license")
		assert_eq(str(entry.get("license_url", "")), allowed_music_licenses.get(license_id))
		if str(entry.get("artist", "")) == "xingwangzhe":
			assert_eq(license_id, "CC0 1.0 or CC BY 4.0", "original BGM must also offer CC BY 4.0")
			assert_eq(str(entry.get("license_alt_url", "")), "https://creativecommons.org/licenses/by/4.0/")
		assert_true(str(entry.get("url", "")).begins_with("https://"))
		var file := str(entry.get("file", ""))
		assert_true(ResourceLoader.exists(file), "missing BGM: %s" % file)
		assert_false(music_files.has(file), "BGM credits must not duplicate a runtime file")
		music_files.append(file)
	var sfx_entries: Array = credits.get("sfx", [])
	assert_eq(sfx_entries.size(), 6, "both Kenney packs and all four OpenGameArt sources must be credited")
	var sfx_files: Array[String] = []
	for entry in sfx_entries:
		assert_eq(str(entry.get("license", "")), "CC0 1.0")
		assert_eq(str(entry.get("license_url", "")), "https://creativecommons.org/publicdomain/zero/1.0/")
		assert_true(str(entry.get("url", "")).begins_with("https://"))
		var files: Array = entry.get("files", [entry.get("file", "")]) as Array
		assert_gt(files.size(), 0)
		for path in files:
			var file := str(path)
			assert_true(ResourceLoader.exists(file), "missing SFX: %s" % file)
			assert_false(sfx_files.has(file), "SFX credits must not duplicate a runtime file")
			sfx_files.append(file)
	assert_eq(sfx_files.size(), 18, "every runtime SFX must be covered exactly once")
	var font_entry: Dictionary = (credits.get("fonts", []) as Array)[0]
	assert_string_contains(font_entry.get("notice_zh", ""), "OFL")
	assert_true(str(font_entry.get("license_url", "")).begins_with("https://"))
	var icon_entries: Array = credits.get("icons", [])
	assert_eq(icon_entries.size(), 99, "98 game-icons.net assets and the original cursor must be credited")
	var third_party_icons := 0
	var generated_icons := 0
	var cursor_credited := false
	for entry in icon_entries:
		assert_true(entry is Dictionary)
		assert_true(ResourceLoader.exists(str(entry.get("file", ""))))
		if str(entry.get("file", "")) == "res://assets/ui/watch_cursor.webp":
			cursor_credited = true
			assert_eq(str(entry.get("license", "")), "CC BY 4.0")
			assert_eq(str(entry.get("license_url", "")), "https://creativecommons.org/licenses/by/4.0/")
			assert_eq(str(entry.get("artist", "")), "xingwangzhe")
			continue
		if str(entry.get("artist", "")) == "OpenAI ImageGen":
			generated_icons += 1
			assert_false(str(entry.get("file", "")).contains("weapon"), "weapon icons must use the unified game-icons set")
			continue
		third_party_icons += 1
		assert_eq(str(entry.get("license", "")), "CC BY 3.0")
		assert_eq(str(entry.get("license_url", "")), "https://creativecommons.org/licenses/by/3.0/")
		assert_true(str(entry.get("url", "")).begins_with("https://game-icons.net/"))
	assert_eq(third_party_icons, 98)
	assert_eq(generated_icons, 0)
	assert_true(cursor_credited, "the gameplay cursor needs its own original-asset credit")
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
	var content := about.find_child("CreditsContent", true, false) as VBoxContainer
	assert_not_null(content)
	var content_labels: Array[String] = []
	for child in content.get_children():
		if child is Label:
			content_labels.append(str((child as Label).text))
	var free_index := content_labels.find(str(free_software.get("title_zh", "")))
	var thanks_index := content_labels.find("致谢")
	var license_index := content_labels.find("版权与许可")
	var game_index := content_labels.find("作品与当前进度")
	assert_true(free_index >= 0, "free-software statement must be rendered")
	assert_true(free_index < thanks_index, "free-software statement must precede thanks")
	assert_true(thanks_index < license_index, "thanks must precede copyright and licenses")
	assert_true(license_index < game_index, "thanks and licenses must precede the remaining sections")
	assert_eq(content_labels[-1], Locale.t("about.thanks_end"), "the roll must end with thanks to judges and players")
	var renderer_section: Dictionary = {}
	var nightscape_section: Dictionary = {}
	for section in about_sections:
		if not section is Dictionary:
			continue
		match str(section.get("title_zh", "")):
			"渲染与性能":
				renderer_section = section
			"主菜单夜景":
				nightscape_section = section
	assert_false(renderer_section.is_empty(), "credits must explain the renderer switch")
	assert_string_contains(JSON.stringify(renderer_section), "Vulkan")
	assert_string_contains(JSON.stringify(renderer_section), "OpenGL")
	assert_string_contains(JSON.stringify(renderer_section), "重启")
	assert_false(nightscape_section.is_empty(), "credits must explain the animated menu")
	assert_string_contains(JSON.stringify(nightscape_section), "640×360")
	var tool_titles: Array[String] = []
	for tool in credits.get("tools", []):
		if tool is Dictionary:
			tool_titles.append(str(tool.get("title", "")))
	assert_true(tool_titles.has("Pixel Art Studio"))
	assert_true(tool_titles.has("ffmpeg"))

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


func test_about_web_builds_credits_incrementally() -> void:
	GameSettings.web_platform_override = 1
	var about := (load("res://scenes/about.tscn") as PackedScene).instantiate()
	add_child_autofree(about)
	await wait_process_frames(1)
	assert_false(about.is_content_ready(), "web credits must not block the first frame")
	var status: Label = about.find_child("ScrollStatus", true, false)
	assert_not_null(status)
	assert_string_contains(status.text, "加载署名")
	for _frame in range(240):
		if about.is_content_ready():
			break
		await wait_process_frames(1)
	assert_true(about.is_content_ready(), "web credits must finish building incrementally")
	var content := about.find_child("CreditsContent", true, false) as VBoxContainer
	assert_not_null(content)
	assert_gt(content.get_child_count(), 100, "incremental build must populate the full roll")


func test_about_web_prewarms_without_taking_over_menu_audio() -> void:
	GameSettings.web_platform_override = 1
	AudioBus.resume_bgm()
	var about := (load("res://scenes/about.tscn") as PackedScene).instantiate()
	about.prewarm_mode = true
	add_child_autofree(about)
	await wait_process_frames(2)
	assert_true(about.visible, "prewarm must render behind the opaque menu")
	assert_eq(about.modulate.a, 1.0, "prewarm must complete layout before the first reveal")
	for _frame in range(240):
		if about.is_content_ready():
			break
		await wait_process_frames(1)
	assert_true(about.is_content_ready(), "prewarm must finish layout while hidden")
	assert_false(about.is_auto_scrolling(), "prewarm must not start scrolling behind the menu")
	assert_true(AudioBus.menu_enabled, "prewarm must not stop the menu BGM")
	assert_null(about.about_player(), "prewarm must not create the about audio player")
	about.activate()
	await wait_process_frames(2)
	assert_true(about.visible, "activation must reveal the prewarmed overlay")
	assert_eq(about.modulate.a, 1.0, "activation must restore full opacity")
	assert_true(about.is_auto_scrolling(), "activation must enable scrolling")
	assert_false(AudioBus.menu_enabled, "activation must stop the menu BGM")
	assert_not_null(about.about_player(), "activation must start the dedicated about audio player")


func test_about_prewarm_does_not_save_about_as_the_last_mode() -> void:
	GameSettings.web_platform_override = 1
	var about := (load("res://scenes/about.tscn") as PackedScene).instantiate()
	about.prewarm_mode = true
	add_child_autofree(about)
	await wait_process_frames(1)
	SaveSystem.data["last_mode"] = "menu"
	about._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(SaveSystem.data.get("last_mode"), "menu")
	about.activate()
	about._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(SaveSystem.data.get("last_mode"), "about")


func test_web_about_opens_as_overlay_without_scene_change() -> void:
	GameSettings.web_platform_override = 1
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	menu.web_platform_override = 1
	add_child_autofree(menu)
	await wait_process_frames(3)
	menu._on_about_pressed()
	await wait_process_frames(2)
	var about: Control = menu._about_overlay
	assert_not_null(about, "web about must open as an in-tree overlay")
	assert_true(bool(about.overlay_mode))
	assert_false(menu.visible, "the menu must pause behind the about overlay")
	assert_eq(menu.process_mode, Node.PROCESS_MODE_DISABLED)
	about._return_to_menu()
	await wait_process_frames(2)
	assert_true(menu.visible)
	assert_ne(menu.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_null(menu._about_overlay)


func test_web_about_prewarm_rebuilds_after_language_change() -> void:
	GameSettings.web_platform_override = 1
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	menu.web_platform_override = 1
	add_child_autofree(menu)
	await wait_process_frames(1)
	if is_instance_valid(menu._about_prewarm_timer):
		menu._about_prewarm_timer.queue_free()
		menu._about_prewarm_timer = null
	menu._prewarm_about_overlay()
	await wait_process_frames(1)
	var old_overlay: Control = menu._about_overlay
	assert_not_null(old_overlay, "prewarm must create the About overlay")

	Locale.set_language("en", false)
	await wait_process_frames(2)
	assert_false(is_instance_valid(old_overlay), "language changes must discard stale prewarmed copy")
	assert_null(menu._about_overlay)
	assert_not_null(menu._about_prewarm_timer, "language changes must schedule a fresh prewarm")

	menu._about_prewarm_timer.queue_free()
	menu._about_prewarm_timer = null
	menu._prewarm_about_overlay()
	await wait_process_frames(1)
	assert_not_null(menu._about_overlay, "the rebuilt About overlay must be reusable")
	assert_ne(menu._about_overlay, old_overlay)


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
	var renderer_option: OptionButton = menu.find_child("RendererOption", true, false)
	var renderer_status: Label = menu.find_child("RendererStatus", true, false)
	var restart_button: Button = menu.find_child("RestartRendererButton", true, false)
	assert_not_null(overlay)
	assert_not_null(start)
	assert_not_null(about)
	assert_not_null(timer, "the menu must own its autosave timer")
	assert_not_null(fps_option, "the menu must expose a frame limit setting")
	assert_not_null(vsync_toggle, "the menu must expose a VSync setting")
	assert_not_null(renderer_option, "the menu must expose a renderer setting")
	assert_not_null(renderer_status)
	assert_not_null(restart_button)
	assert_almost_eq(timer.wait_time, 20.0, 0.01)
	assert_false(timer.is_stopped(), "autosave timer must be running")
	assert_false(overlay.visible, "settings must start closed")
	assert_eq(start.text, Locale.t("menu.start"))
	assert_eq(about.text, Locale.t("menu.about"))
	assert_eq(fps_option.get_item_text(fps_option.selected), "60 FPS")
	assert_eq(vsync_toggle.text, Locale.t("settings.on"))
	var renderer_modes := GameSettings.renderer_modes_for_ui()
	assert_eq(renderer_option.item_count, renderer_modes.size())
	for index in range(renderer_modes.size()):
		assert_eq(
			str(renderer_option.get_item_metadata(index)),
			str(renderer_modes[index]),
			"renderer options must expose their mode as item metadata"
		)
	assert_eq(
		str(renderer_option.get_item_metadata(renderer_option.selected)),
		GameSettings.RENDERER_AUTO
	)
	assert_string_contains(renderer_status.text, "Vulkan")
	assert_false(restart_button.visible, "matching renderer must not require a restart")
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
	var opengl_index := -1
	for index in range(renderer_option.item_count):
		if str(renderer_option.get_item_metadata(index)) == GameSettings.RENDERER_OPENGL:
			opengl_index = index
			break
	assert_true(opengl_index >= 0, "OpenGL must remain selectable on desktop")
	renderer_option.select(opengl_index)
	renderer_option.item_selected.emit(opengl_index)
	await wait_process_frames(1)
	assert_eq(GameSettings.renderer_mode, GameSettings.RENDERER_OPENGL)
	assert_string_contains(renderer_status.text, "重启游戏以应用渲染变更")
	assert_true(restart_button.visible)
	menu.close_settings()
	await wait_process_frames(1)
	assert_false(overlay.visible, "close_settings must hide the overlay")


func test_web_renderer_ui_disables_vulkan_and_reports_webgl() -> void:
	GameSettings.web_platform_override = 1
	GameSettings.renderer_mode = GameSettings.RENDERER_OPENGL
	GameSettings.active_renderer_override = GameSettings.RENDERER_OPENGL
	GameSettings.web_capabilities = {
		"webgl2": true,
		"renderer": "ANGLE (Test GPU)",
		"webgpu_api": true,
	}
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_process_frames(3)
	var option := menu.find_child("RendererOption", true, false) as OptionButton
	var status := menu.find_child("RendererStatus", true, false) as Label
	var restart := menu.find_child("RestartRendererButton", true, false) as Button
	var note := menu.find_child("SettingsNote", true, false) as Label
	assert_not_null(option)
	assert_eq(option.item_count, 2)
	assert_eq(
		str(option.get_item_metadata(0)),
		GameSettings.RENDERER_OPENGL
	)
	assert_eq(
		str(option.get_item_metadata(1)),
		GameSettings.RENDERER_VULKAN
	)
	assert_true(option.is_item_disabled(1))
	assert_string_contains(option.get_item_text(1), "Web")
	assert_string_contains(option.get_item_text(0), "WebGL 2.0")
	assert_string_contains(status.text, "WebGL 2.0")
	assert_false(restart.visible, "web cannot restart into another renderer")
	assert_string_contains(note.text, "ANGLE (Test GPU)")
	option.item_selected.emit(1)
	await wait_process_frames(1)
	assert_eq(GameSettings.renderer_mode, GameSettings.RENDERER_OPENGL)


func test_main_menu_exposes_night_anchor_icons() -> void:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_process_frames(3)
	var anchors: HFlowContainer = menu.find_child("NightAnchors", true, false)
	assert_not_null(anchors, "the main menu must show the night-anchor icon row")
	assert_eq(anchors.get_child_count(), 5)
	for chip in anchors.get_children():
		var icon := chip.find_child("Icon", true, false) as TextureRect
		var label := chip.find_child("IconLabel", true, false) as Label
		assert_not_null(icon, "each night anchor must render an icon")
		assert_not_null(icon.texture)
		assert_not_null(label)
		assert_gt(label.text.length(), 0)


func test_run_scene_builds_survivor_loop() -> void:
	var runs_before := int(SaveSystem.data.get("runs", 0))
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(4)
	assert_eq(
		int(SaveSystem.data.get("runs", 0)),
		runs_before + 1,
		"entering one run scene must call begin_run exactly once"
	)
	assert_gt(int(SaveSystem.data.get("last_run_seed", 0)), 0)
	assert_eq(
		int(run._run_seed),
		int(SaveSystem.data.get("last_run_seed", 0)),
		"the active run must use the seed saved at its start"
	)
	assert_eq(int(run._rng.seed), SaveSystem.derive_seed(run._run_seed, "gameplay"))
	assert_eq(int(run._world_seed), SaveSystem.derive_seed(run._run_seed, "world"))
	assert_not_null(run.find_child("Battlefield", true, false), "run must own a battle field")
	assert_not_null(run.find_child("HUD", true, false), "run must own a HUD")
	assert_not_null(run.find_child("SubtitlePanel", true, false), "run must expose subtitles")
	assert_not_null(run.level_up_overlay, "run must own the level-up overlay")
	assert_true(run.story.visible, "first run must start with sourced narrative")
	assert_eq(run.weapons.size(), 1, "Wang Lu must start with one auto weapon")
	assert_eq(run.passives.get("gaiters", 0), 1)
	run.story._skip_all()
	await wait_process_frames(2)
	assert_false(run._paused, "closing the intro must start the run")
	for i in range(240):
		run._step(1.0 / 60.0)
	await wait_process_frames(2)
	assert_gt(run.battlefield.alive_count(), 0, "the wave director must spawn enemies")
	var before_xp: float = float(run.xp_need)
	run._add_xp(before_xp)
	await wait_process_frames(2)
	assert_true(run.level_up_overlay.visible, "enough XP must open three-card level-up")
	assert_eq(run._current_upgrade_options.size(), 3)
	run.level_up_overlay._unlock_at_msec = Time.get_ticks_msec() - 1
	run.level_up_overlay._process(0.0)
	run._on_upgrade_chosen(0)
	await wait_process_frames(2)
	assert_false(run.level_up_overlay.visible, "choosing a card must close the overlay")


func test_debug_invincible_mode_blocks_player_damage() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	await wait_process_frames(2)
	var start_hp := float(run.player["hp"])
	run.set_invincible_mode(true)
	run._on_player_hit(50.0)
	assert_eq(float(run.player["hp"]), start_hp, "invincible mode must ignore all hits")
	run.set_invincible_mode(false)
	run._invuln = 0.0
	run._on_player_hit(12.0)
	assert_lt(float(run.player["hp"]), start_hp, "damage must resume after the toggle")


func test_character_select_enforces_unlocks_and_keeps_choice() -> void:
	SaveSystem.data["total_merit"] = 0
	var select := (load("res://scenes/character_select.tscn") as PackedScene).instantiate()
	add_child_autofree(select)
	await wait_process_frames(4)
	assert_eq(select.find_children("Character_*", "Button", true, false).size(), 6)
	assert_eq(select.selected_character(), "wanglu")
	assert_true((select.find_child("Character_amei", true, false) as Button).disabled)
	select._select_character("amei")
	assert_eq(select.selected_character(), "wanglu", "locked characters must not be selected")

	SaveSystem.data["total_merit"] = 2000
	select._refresh()
	select._select_character("amei")
	select._select_map("watergate")
	assert_eq(select.selected_character(), "amei")
	assert_eq(select.selected_map(), "watergate")
	var portrait_texture := (select.find_child("Portrait", true, false) as TextureRect).texture as AtlasTexture
	assert_not_null(portrait_texture, "select portrait must use a forge idle frame")
	if portrait_texture != null:
		assert_string_contains(portrait_texture.atlas.resource_path, "units/full_sheets/wanglu_watchposts.webp")
		assert_eq(portrait_texture.region.size, Vector2(128, 128))
	assert_false((select.find_child("Character_amei", true, false) as Button).disabled)
	assert_false((select.find_child("Map_watergate", true, false) as Button).disabled)


func test_run_uses_selected_character_and_map() -> void:
	SaveSystem.data["total_merit"] = 2000
	SaveSystem.data["selected_character"] = "amei"
	SaveSystem.data["selected_map"] = "watergate"
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	assert_eq(str(run.character_def.get("name_zh", "")), "王陆")
	assert_eq(str(run.character_def.get("preset_name_zh", "")), "龙灯位")
	assert_eq(str(run.map_def.get("name_zh", "")), "水门夜潮")
	assert_eq(run.weapons.size(), 1)
	assert_eq(str(run.weapons[0].get("id", "")), "dragon_lantern")
	assert_eq(int(run.passives.get("colored_paper", 0)), 1)
	assert_eq((run.battlefield as Battlefield).player_idle_frames.size(), 1)
	assert_eq((run.battlefield as Battlefield).player_walk_frames.size(), 8)


func test_run_codex_overlay_pauses_and_returns_to_the_run() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	await wait_process_frames(2)
	run._open_codex()
	await wait_process_frames(2)
	assert_true(run._paused, "opening the codex must pause the watch")
	assert_not_null(run.codex_overlay)
	run.codex_overlay._return_to_menu()
	await wait_process_frames(2)
	assert_false(run._paused, "closing the embedded codex must resume the watch")
	assert_null(run.codex_overlay)


func test_result_lists_new_unlocks_and_keeps_codex_paused() -> void:
	SaveSystem.data["total_merit"] = 300
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	run.merit = 50
	run._show_result(true)
	assert_true(run.result_overlay.visible)
	assert_string_contains(run.result_unlocks.text, "龙灯位")
	assert_false(run.result_unlocks.text.contains("藤牌位"))
	run._open_codex()
	await wait_process_frames(2)
	assert_true(run._paused)
	run._close_codex()
	assert_true(run._paused, "closing the codex from settlement must not resume the run")
	assert_true(run.result_overlay.visible)
	SaveSystem.data["total_merit"] = 0


func test_xp_curve_matches_the_gdd() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(2)
	assert_almost_eq(float(run._xp_need_for_level(1)), 9.35, 0.001)
	assert_almost_eq(float(run._xp_need_for_level(30)), 440.0, 0.001)
	run.level = 30
	run.xp = 0.0
	run.xp_need = run._xp_need_for_level(30)
	run._add_xp(9999.0)
	assert_eq(run.level, 30, "the GDD caps a run at level 30")
	assert_eq(run.xp, 0.0, "max-level XP must not accumulate into hidden levels")
	assert_false(run.level_up_overlay.visible, "max-level XP must not open more upgrade choices")


func test_family_letter_revives_once_and_settlement_records_once() -> void:
	SaveSystem.data["runs_won"] = 0
	SaveSystem.data["total_merit"] = 0
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	run.player["hp"] = float(run.player["max_hp"])
	run.player["revive"] = 1
	run._invuln = 0.0
	run._on_player_hit(99999.0)
	assert_eq(int(run.player["revive"]), 0)
	assert_almost_eq(float(run.player["hp"]), float(run.player["max_hp"]) * 0.5, 0.01)
	run.merit = 123
	run._show_result(true)
	run._show_result(true)
	assert_eq(int(SaveSystem.data.get("runs_won", 0)), 1)
	assert_eq(int(SaveSystem.data.get("total_merit", 0)), 123)


func test_five_scales_trigger_dragon_clear() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	for scale_color in ["red", "yellow", "blue", "green", "black"]:
		run._on_scale_collected(scale_color)
	assert_eq(run.scales.size(), 0, "five-dragon trigger must consume the scales")
	run._on_scale_collected("red")
	assert_eq(run.scales.size(), 1, "a new scale cycle must start after the clear")
	assert_gte(run.merit, 500)
	assert_gt(float(run.battlefield._screen_clear_timer), 0.0)


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


func test_story_structure_splits_opening_and_field_notes() -> void:
	var n := GameData.load_json("res://data/narrative.json")
	var opening: Array = n.get("main_intro", [])
	var field: Array = n.get("field_notes", [])
	assert_eq(opening.size(), 4, "opening hook must stay short so play starts quickly")
	assert_eq(field.size(), 11, "remaining lines must be paced across the run")
	var ids: Dictionary = {}
	for line in opening:
		ids[str(line.get("id", ""))] = true
	for line in field:
		ids[str(line.get("id", ""))] = true
	assert_true(ids.has("narr_1558_01"))
	assert_true(ids.has("narr_1558_02"))
	assert_true(ids.has("narr_1559_01"))
	assert_true(ids.has("narr_1559_02"))
	# 关键史实与角色钩子必须留在开场前 4 句
	assert_true(ids.has("narr_1559_02"), "Wang Lu self-introduction must open the run")


func test_field_notes_are_fully_scheduled_on_timeline() -> void:
	var n := GameData.load_json("res://data/narrative.json")
	var w := GameData.load_json("res://data/waves.json")
	var field_ids: Dictionary = {}
	for line in n.get("field_notes", []) as Array:
		field_ids[str(line.get("id", ""))] = true
	var scheduled: Dictionary = {}
	var last_t := -1.0
	for event in w.get("event_lines", []) as Array:
		var t := float(event.get("t", 0.0))
		assert_gt(t, last_t, "timeline events must be strictly increasing")
		last_t = t
		assert_true(field_ids.has(str(event.get("key", ""))), "timeline key must exist in field_notes")
		scheduled[str(event.get("key", ""))] = true
	assert_eq(scheduled.size(), field_ids.size(), "every field note must be scheduled exactly once")


func test_story_overlay_has_no_fullscreen_dim() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	# 轻量过场：不得存在覆盖全屏、alpha>0.1 的 ColorRect 遮罩
	for rect in run.story.find_children("*", "ColorRect", true, false):
		var cr := rect as ColorRect
		if cr.color.a <= 0.1:
			continue
		var size: Vector2 = cr.size
		assert_lt(size.x * size.y, 1280.0 * 300.0, "story overlay must not dim the whole battlefield")
	assert_not_null(run.story.find_child("BottomFade", true, false), "local bottom fade must exist")


func test_replay_shortens_intro_to_single_line() -> void:
	SaveSystem.data["intro_seen"] = true
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	assert_true(run.story.visible, "replay still shows the sourced self-introduction")
	assert_eq(run.story._lines.size(), 1, "replay must show one line, not re-read the whole intro")
	assert_eq(str(run.story._lines[0].get("id", "")), "narr_1559_02")


func test_source_labels_hide_internal_references_and_name_county_gazetteer() -> void:
	for path in [
		"res://data/narrative.json",
		"res://data/upgrades.json",
		"res://data/weapons.json",
		"res://data/mercenaries.json",
		"res://data/shop.json",
		"res://data/codex.json",
	]:
		_assert_source_tree(GameData.load_json(path))

	var skills := UpgradeCatalog.family_data("skills")
	var dragon := UpgradeCatalog.make_option(
		"skill",
		"dragon_lantern_nova",
		skills["dragon_lantern_nova"] as Dictionary,
		1
	)
	assert_string_contains(GameData.source_label(dragon), "清《永嘉县志·岁时》")
	Locale.set_language("en", false)
	assert_string_contains(GameData.source_label(dragon), "Qing Yongjia County Gazetteer")
	Locale.set_language("zh", false)


func test_upgrade_and_shop_tooltips_use_player_facing_sources() -> void:
	var options: Array[Dictionary] = []
	for option in UpgradeCatalog.build_card_pool({}, {}, 0.0):
		if str(option.get("card_id", "")) == "dragon_lantern_nova":
			options.append(option)
			break
	assert_eq(options.size(), 1)
	var level_up := LevelUpOverlay.new()
	add_child_autofree(level_up)
	await wait_process_frames(2)
	level_up.show_options(options, 2)
	await wait_process_frames(1)
	var upgrade_card := level_up.find_child("UpgradeCard1", true, false) as Button
	assert_not_null(upgrade_card)
	_assert_player_text_clean(upgrade_card.tooltip_text)
	assert_string_contains(upgrade_card.tooltip_text, "清《永嘉县志·岁时》")
	assert_false(str(options[0].get("source_ref", "")).is_empty())
	var category := upgrade_card.find_child("CardCategory", true, false) as Label
	_assert_player_text_clean(category.tooltip_text)

	var hired: Array[String] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var offers := ShopCatalog.build_offers(
		[{"id": "saber", "level": 1}],
		{"gaiters": 1},
		hired,
		rng
	)
	var shop := ShopOverlay.new()
	add_child_autofree(shop)
	await wait_process_frames(2)
	shop.show_shop(offers, 500, 25, {})
	await wait_process_frames(1)
	for i in range(offers.size()):
		var card := shop.find_child("ShopCard%d" % (i + 1), true, false) as Button
		assert_not_null(card)
		_assert_player_text_clean(card.tooltip_text)
		assert_false(str(offers[i].get("source_ref", "")).is_empty())


func test_codex_displays_cultural_sources_without_research_notes() -> void:
	var codex := (load("res://scenes/codex.tscn") as PackedScene).instantiate()
	add_child_autofree(codex)
	await wait_process_frames(3)
	_assert_control_tree_clean(codex)
	var all_text := ""
	for label in codex.find_children("*", "Label", true, false):
		all_text += (label as Label).text + "\n"
	assert_string_contains(all_text, "清《永嘉县志·岁时》")
	assert_string_contains(all_text, "《永昌堡：十三进士与抗倭纪略》")
	assert_false(all_text.contains("语料边界"))
	assert_false(all_text.contains("不要误写"))
	assert_false(all_text.contains("出现 0 次"))


func test_menu_and_settings_keep_attribution_on_about_page_only() -> void:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_process_frames(3)
	menu.open_settings()
	await wait_process_frames(1)
	_assert_control_tree_clean(menu)
	assert_null(menu.find_child("MusicCredit", true, false))
	assert_null(menu.find_child("MusicLicense", true, false))
	assert_null(menu.find_child("SettingsCredit", true, false))
	var credits := GameData.load_json("res://data/credits.json")
	assert_gt((credits.get("music", []) as Array).size(), 0)
	assert_false(str((credits.get("music", []) as Array)[0].get("license", "")).is_empty())


func _assert_source_tree(value: Variant) -> void:
	if value is Dictionary:
		var dictionary := value as Dictionary
		if dictionary.has("source_ref"):
			assert_false(str(dictionary.get("source_ref", "")).is_empty())
			_assert_player_text_clean(GameData.source_label(dictionary))
		for child in dictionary.values():
			_assert_source_tree(child)
	elif value is Array:
		for child in value as Array:
			_assert_source_tree(child)


func _assert_control_tree_clean(root: Node) -> void:
	for control in root.find_children("*", "Control", true, false):
		var ui := control as Control
		_assert_player_text_clean(ui.tooltip_text)
		if ui is Label:
			_assert_player_text_clean((ui as Label).text)
		elif ui is Button:
			_assert_player_text_clean((ui as Button).text)


func _assert_player_text_clean(text: String) -> void:
	for forbidden in [
		"docs/",
		"design/",
		"res://",
		".txt",
		".md",
		"CC-BY",
		"CC BY",
		"CC0",
		"OpenGameArt",
		"Copyright",
		"版权",
		"许可",
		"license",
		"License",
	]:
		assert_false(text.contains(forbidden), "player text exposes '%s': %s" % [forbidden, text])


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
