extends Control

const BackdropScript := preload("res://scripts/ui/menu_backdrop.gd")
const UIControls := preload("res://scripts/ui/ui_control_theme.gd")
const IconChips := preload("res://scripts/ui/icon_chip.gd")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.png")
const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const ICON_LANTERN := preload("res://assets/icons/game_icons/ui_lantern.svg")
const ICON_WATCHTOWER := preload("res://assets/icons/game_icons/ui_watchtower.svg")
const ICON_SCROLL := preload("res://assets/icons/game_icons/ui_scroll.svg")
const ICON_FEAST := preload("res://assets/icons/game_icons/ui_feast.svg")
const ICON_SHIELD := preload("res://assets/icons/game_icons/wpn_shield.svg")

const INK := Color("#081014")
const PAPER := Color("#e8d8b6")
const MUTED := Color("#a99778")
const GOLD := Color("#d8a548")
const GOLD_DIM := Color("#8f6c32")
const VERMILION := Color("#8f3326")
const VERMILION_LIGHT := Color("#a94333")
const PANEL_FILL := Color(0.055, 0.070, 0.070, 0.92)

var _i18n_labels: Array[Dictionary] = []
var _start_button: Button
var _settings_button: Button
var _about_button: Button
var _language_button: Button
var _codex_button: Button
var _quit_button: Button
var _autosave_value: Label
var _last_saved_value: Label
var _runs_value: Label
var _best_value: Label
var _language_value: Label
var _settings_overlay: Control
var _settings_panel: PanelContainer
var _bgm_slider: HSlider
var _bgm_value: Label
var _sfx_slider: HSlider
var _sfx_value: Label
var _fullscreen_toggle: CheckButton
var _fps_option: OptionButton
var _vsync_toggle: CheckButton
var _renderer_option: OptionButton
var _renderer_status: Label
var _renderer_restart_button: Button
var _language_option: OptionButton
var _back_button: Button


func _ready() -> void:
	InputSetup.ensure_defaults()
	_build_theme()
	_build_backdrop()
	_build_header()
	_build_menu()
	_build_watch_panel()
	_build_footer()
	_build_settings_overlay()
	_sync_settings_controls()
	_connect_signals()
	_refresh_texts()
	_update_stats()
	_install_autosave_timer()
	SaveSystem.autosave({"last_mode": "menu"})
	AudioBus.resume_bgm()
	_start_button.grab_focus()


func open_settings() -> void:
	if _settings_overlay.visible:
		return
	_settings_overlay.visible = true
	for button in [_start_button, _settings_button, _about_button, _language_button, _quit_button]:
		button.focus_mode = Control.FOCUS_NONE
	_sync_settings_controls()
	_bgm_slider.grab_focus()
	SaveSystem.autosave({"last_mode": "settings"})


func close_settings() -> void:
	if not _settings_overlay.visible:
		return
	_settings_overlay.visible = false
	for button in [_start_button, _settings_button, _about_button, _language_button, _quit_button]:
		button.focus_mode = Control.FOCUS_ALL
	_settings_button.grab_focus()
	SaveSystem.autosave({"last_mode": "menu"})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _settings_overlay.visible:
		close_settings()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_codex") and not _settings_overlay.visible:
		_on_codex_pressed()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveSystem.autosave({"last_mode": "menu"})
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		var mode := "menu"
		if is_instance_valid(_settings_overlay) and _settings_overlay.visible:
			mode = "settings"
		SaveSystem.autosave({"last_mode": mode})


func _build_theme() -> void:
	var menu_theme := Theme.new()
	menu_theme.default_font = UI_FONT
	menu_theme.default_font_size = 20
	UIControls.install(menu_theme)
	theme = menu_theme


func _build_backdrop() -> void:
	var backdrop := BackdropScript.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_header() -> void:
	var seal := Panel.new()
	seal.name = "Seal"
	seal.position = Vector2(96.0, 110.0)
	seal.size = Vector2(60.0, 84.0)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.add_theme_stylebox_override("panel", _flat_box(VERMILION, GOLD, 1, 2))
	add_child(seal)

	var seal_text := _make_label("SealText", "永\n昌", 20, PAPER)
	seal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal_text.add_theme_constant_override("line_spacing", -6)
	seal.add_child(seal_text)
	seal_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title_shadow := _label("TitleShadow", "守望", Vector2(178.0, 92.0), 94, Color(0.0, 0.0, 0.0, 0.62))
	title_shadow.add_theme_constant_override("outline_size", 8)
	title_shadow.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.48))

	var title := _label("Title", "守望", Vector2(174.0, 88.0), 94, GOLD)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color("#160d08"))

	_register_label(_label("Era", "", Vector2(180.0, 208.0), 21, MUTED), "app.era")
	_register_label(_label("Tagline", "", Vector2(182.0, 242.0), 19, Color(PAPER, 0.92)), "app.tagline")

	var rule := ColorRect.new()
	rule.name = "TitleRule"
	rule.position = Vector2(181.0, 286.0)
	rule.size = Vector2(402.0, 1.0)
	rule.color = Color(GOLD, 0.42)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)

	var brand_mark := _label("BrandMark", "2026 · OSGJ", Vector2(182.0, 272.0 + 2.0), 12, Color(MUTED, 0.62))
	brand_mark.position = Vector2(506.0, 294.0)


func _build_menu() -> void:
	var button_y := 318.0
	_start_button = _make_button("StartButton", "menu.start", true)
	_start_button.position = Vector2(180.0, button_y)
	add_child(_start_button)
	_start_button.pressed.connect(_on_start_pressed)

	_settings_button = _make_button("SettingsButton", "menu.settings")
	_settings_button.position = Vector2(180.0, button_y + 58.0)
	add_child(_settings_button)
	_settings_button.pressed.connect(open_settings)

	_about_button = _make_button("AboutButton", "menu.about")
	_about_button.position = Vector2(180.0, button_y + 116.0)
	add_child(_about_button)
	_about_button.pressed.connect(_on_about_pressed)

	_language_button = _make_button("LanguageButton", "menu.language")
	_language_button.position = Vector2(180.0, button_y + 174.0)
	add_child(_language_button)
	_language_button.pressed.connect(_on_language_pressed)

	_quit_button = _make_button("QuitButton", "menu.quit")
	_quit_button.position = Vector2(180.0, button_y + 232.0)
	add_child(_quit_button)
	_quit_button.pressed.connect(_on_quit_pressed)


func _build_watch_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "WatchPanel"
	panel.position = Vector2(792.0, 128.0)
	panel.size = Vector2(400.0, 470.0)
	panel.add_theme_stylebox_override("panel", _panel_texture_box(30))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 11)
	margin.add_child(column)

	var heading := HBoxContainer.new()
	column.add_child(heading)
	_register_label(_make_label("PanelTitle", "", 27, GOLD), "panel.title")
	heading.add_child(_i18n_labels[-1]["node"])
	var heading_spacer := Control.new()
	heading_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(heading_spacer)
	_codex_button = _make_text_button("CodexButton", Locale.t("menu.codex"), 13, Vector2(86.0, 30.0))
	_codex_button.pressed.connect(_on_codex_pressed)
	heading.add_child(_codex_button)
	var small_seal := _make_label("PanelSeal", "永昌", 13, Color(VERMILION_LIGHT, 0.95))
	small_seal.add_theme_constant_override("outline_size", 1)
	small_seal.add_theme_color_override("font_outline_color", Color(GOLD, 0.45))
	heading.add_child(small_seal)

	column.add_child(_rule())

	_autosave_value = _stat_row(column, "panel.autosave", "AutosaveValue")
	_last_saved_value = _stat_row(column, "panel.last_saved", "LastSavedValue")
	_runs_value = _stat_row(column, "panel.runs", "RunsValue")
	_best_value = _stat_row(column, "panel.best", "BestValue")
	_language_value = _stat_row(column, "panel.language", "LanguageValue")

	column.add_child(_rule())
	_register_label(_make_label("MusicHeading", "", 15, MUTED), "panel.music")
	column.add_child(_i18n_labels[-1]["node"])

	var music_title := _make_label("MusicTitle", "Samurai Nights", 22, PAPER)
	column.add_child(music_title)
	_register_label(_make_label("MusicCredit", "", 14, Color(MUTED, 0.88)), "panel.music_credit")
	column.add_child(_i18n_labels[-1]["node"])
	_register_label(_make_label("MusicLicense", "", 12, Color(MUTED, 0.62)), "panel.license")
	column.add_child(_i18n_labels[-1]["node"])

	_build_night_anchors(column)

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grow)

	_register_label(_make_label("PanelQuote", "", 17, Color(GOLD, 0.78)), "panel.quote")
	column.add_child(_i18n_labels[-1]["node"])

	var version_row := HBoxContainer.new()
	column.add_child(version_row)
	var version := _make_label("Version", "v0.4 · M3", 12, Color(MUTED, 0.54))
	version_row.add_child(version)
	var version_spacer := Control.new()
	version_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version_row.add_child(version_spacer)
	var autosave_note := _make_label("AutosaveNote", "●", 12, Color(GOLD, 0.72))
	version_row.add_child(autosave_note)


func _build_night_anchors(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "NightAnchors"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var anchors := [
		{"name": "AnchorLantern", "key": "anchor.lantern", "icon": ICON_LANTERN},
		{"name": "AnchorWatchtower", "key": "anchor.watchtower", "icon": ICON_WATCHTOWER},
		{"name": "AnchorShield", "key": "anchor.shield", "icon": ICON_SHIELD},
		{"name": "AnchorFeast", "key": "anchor.feast", "icon": ICON_FEAST},
		{"name": "AnchorScroll", "key": "anchor.scroll", "icon": ICON_SCROLL},
	]
	for spec in anchors:
		var key := str(spec["key"])
		var chip: Dictionary = IconChips.make_inline(
			spec["icon"] as Texture2D,
			Locale.t(key),
			22
		)
		var chip_root: Control = chip["root"]
		chip_root.name = str(spec["name"])
		row.add_child(chip_root)
		_register_label(chip["label"] as Label, key)


func _build_footer() -> void:
	_register_label(_label("Hint", "", Vector2(182.0, 644.0), 14, Color(MUTED, 0.70)), "menu.hint")
	var build := _label("Build", "YONGCHANG · 1558", Vector2(1000.0, 674.0), 12, Color(MUTED, 0.46))
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build.size = Vector2(180.0, 20.0)


func _build_settings_overlay() -> void:
	_settings_overlay = Control.new()
	_settings_overlay.name = "SettingsOverlay"
	_settings_overlay.visible = false
	_settings_overlay.z_index = 20
	add_child(_settings_overlay)
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.015, 0.025, 0.030, 0.80)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.position = Vector2(340.0, 40.0)
	_settings_panel.custom_minimum_size = Vector2(600.0, 640.0)
	_settings_panel.size = Vector2(600.0, 640.0)
	_settings_panel.add_theme_stylebox_override("panel", _panel_texture_box(28))
	_settings_overlay.add_child(_settings_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	_settings_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_register_label(_make_label("SettingsTitle", "", 30, GOLD), "settings.title")
	header.add_child(_i18n_labels[-1]["node"])
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var close_button := _make_text_button("CloseButton", "×", 30, Vector2(42.0, 38.0))
	close_button.pressed.connect(close_settings)
	header.add_child(close_button)

	column.add_child(_rule())

	var bgm_row := HBoxContainer.new()
	bgm_row.add_theme_constant_override("separation", 12)
	_bgm_slider = _make_slider(GameSettings.bgm_volume)
	_bgm_slider.name = "BgmSlider"
	_bgm_slider.value_changed.connect(_on_bgm_changed)
	_bgm_slider.drag_ended.connect(_on_slider_drag_ended)
	bgm_row.add_child(_bgm_slider)
	_bgm_value = _make_label("BgmValue", "", 15, MUTED)
	_bgm_value.custom_minimum_size = Vector2(54.0, 0.0)
	_bgm_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bgm_row.add_child(_bgm_value)
	_setting_row(column, "settings.bgm", bgm_row)

	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 12)
	_sfx_slider = _make_slider(GameSettings.sfx_volume)
	_sfx_slider.name = "SfxSlider"
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_sfx_slider.drag_ended.connect(_on_slider_drag_ended)
	sfx_row.add_child(_sfx_slider)
	_sfx_value = _make_label("SfxValue", "", 15, MUTED)
	_sfx_value.custom_minimum_size = Vector2(54.0, 0.0)
	_sfx_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sfx_row.add_child(_sfx_value)
	_setting_row(column, "settings.sfx", sfx_row)

	_fullscreen_toggle = CheckButton.new()
	_fullscreen_toggle.name = "FullscreenToggle"
	_fullscreen_toggle.button_pressed = GameSettings.fullscreen
	_fullscreen_toggle.add_theme_font_size_override("font_size", 17)
	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	_setting_row(column, "settings.fullscreen", _fullscreen_toggle)

	_fps_option = OptionButton.new()
	_fps_option.name = "FpsLimitOption"
	_fps_option.custom_minimum_size = Vector2(206.0, 36.0)
	for limit in GameSettings.FPS_LIMITS:
		_fps_option.add_item(_fps_option_text(int(limit)))
	_fps_option.item_selected.connect(_on_fps_selected)
	UIControls.apply_option(_fps_option)
	_setting_row(column, "settings.fps", _fps_option)

	_vsync_toggle = CheckButton.new()
	_vsync_toggle.name = "VsyncToggle"
	_vsync_toggle.add_theme_font_size_override("font_size", 17)
	_vsync_toggle.toggled.connect(_on_vsync_toggled)
	_setting_row(column, "settings.vsync", _vsync_toggle)

	_renderer_option = OptionButton.new()
	_renderer_option.name = "RendererOption"
	_renderer_option.custom_minimum_size = Vector2(206.0, 36.0)
	for mode in GameSettings.RENDERER_MODES:
		_renderer_option.add_item(_renderer_option_text(str(mode)))
	_renderer_option.item_selected.connect(_on_renderer_selected)
	UIControls.apply_option(_renderer_option)
	_setting_row(column, "settings.renderer", _renderer_option)

	var renderer_status_row := HBoxContainer.new()
	renderer_status_row.name = "RendererStatusRow"
	renderer_status_row.add_theme_constant_override("separation", 12)
	_renderer_status = _make_label("RendererStatus", "", 13, Color(MUTED, 0.80))
	_renderer_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_renderer_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	renderer_status_row.add_child(_renderer_status)
	_renderer_restart_button = _make_text_button(
		"RestartRendererButton",
		"",
		14,
		Vector2(132.0, 34.0)
	)
	_renderer_restart_button.pressed.connect(_on_restart_renderer_pressed)
	renderer_status_row.add_child(_renderer_restart_button)
	column.add_child(renderer_status_row)

	_language_option = OptionButton.new()
	_language_option.name = "LanguageOption"
	_language_option.custom_minimum_size = Vector2(206.0, 36.0)
	_language_option.add_item("中文", 0)
	_language_option.add_item("English", 1)
	_language_option.item_selected.connect(_on_language_selected)
	UIControls.apply_option(_language_option)
	_setting_row(column, "settings.language", _language_option)

	column.add_child(_rule())
	_register_label(_make_label("SettingsCredit", "", 13, Color(MUTED, 0.74)), "settings.credit")
	column.add_child(_i18n_labels[-1]["node"])
	_register_label(_make_label("SettingsNote", "", 12, Color(MUTED, 0.54)), "settings.note")
	column.add_child(_i18n_labels[-1]["node"])

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grow)

	var back_row := HBoxContainer.new()
	column.add_child(back_row)
	var back_spacer := Control.new()
	back_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_row.add_child(back_spacer)
	_back_button = _make_button("BackButton", "settings.back", true)
	_back_button.custom_minimum_size = Vector2(236.0, 48.0)
	_back_button.size = Vector2(236.0, 48.0)
	_back_button.pressed.connect(close_settings)
	back_row.add_child(_back_button)


func _connect_signals() -> void:
	Locale.language_changed.connect(_on_language_changed)
	SaveSystem.saved.connect(_update_stats)


func _install_autosave_timer() -> void:
	var timer := Timer.new()
	timer.name = "AutosaveTimer"
	timer.wait_time = 20.0
	timer.autostart = true
	timer.timeout.connect(_on_autosave_timeout)
	add_child(timer)


func _on_start_pressed() -> void:
	if not bool(SaveSystem.data.get("prologue_seen", false)):
		SaveSystem.autosave({"last_mode": "prologue"})
		get_tree().change_scene_to_file("res://scenes/prologue.tscn")
		return
	SaveSystem.autosave({"last_mode": "select"})
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")


func _on_language_pressed() -> void:
	Locale.toggle_language()
	SaveSystem.autosave({"settings": GameSettings.to_dict()})


func _on_about_pressed() -> void:
	AudioBus.stop_bgm()
	SaveSystem.autosave({"last_mode": "about"})
	get_tree().change_scene_to_file("res://scenes/about.tscn")


func _on_codex_pressed() -> void:
	SaveSystem.autosave({"last_mode": "codex"})
	get_tree().change_scene_to_file("res://scenes/codex.tscn")


func _on_quit_pressed() -> void:
	SaveSystem.autosave({"last_mode": "menu"})
	get_tree().quit()


func _on_language_changed(_code: String) -> void:
	_refresh_texts()
	_update_stats()
	_sync_settings_controls()


func _on_language_selected(index: int) -> void:
	Locale.set_language("zh" if index == 0 else "en")
	SaveSystem.autosave({"settings": GameSettings.to_dict()})


func _on_bgm_changed(value: float) -> void:
	_bgm_value.text = "%d%%" % int(round(value * 100.0))
	GameSettings.set_bgm_volume(value, false)


func _on_sfx_changed(value: float) -> void:
	_sfx_value.text = "%d%%" % int(round(value * 100.0))
	GameSettings.set_sfx_volume(value, false)


func _on_slider_drag_ended(_value_changed: bool) -> void:
	GameSettings.save_settings()
	SaveSystem.autosave({"settings": GameSettings.to_dict()})


func _on_fullscreen_toggled(enabled: bool) -> void:
	GameSettings.set_fullscreen(enabled)
	_sync_settings_controls()
	SaveSystem.autosave({"settings": GameSettings.to_dict()})


func _on_fps_selected(index: int) -> void:
	if index < 0 or index >= GameSettings.FPS_LIMITS.size():
		return
	GameSettings.set_fps_limit(int(GameSettings.FPS_LIMITS[index]))
	_sync_settings_controls()
	SaveSystem.autosave({"settings": GameSettings.to_dict()})


func _on_vsync_toggled(enabled: bool) -> void:
	GameSettings.set_vsync(enabled)
	_sync_settings_controls()
	SaveSystem.autosave({"settings": GameSettings.to_dict()})


func _on_renderer_selected(index: int) -> void:
	if index < 0 or index >= GameSettings.RENDERER_MODES.size():
		return
	GameSettings.set_renderer_mode(str(GameSettings.RENDERER_MODES[index]))
	_update_renderer_status()
	SaveSystem.autosave({"settings": GameSettings.to_dict()})


func _on_restart_renderer_pressed() -> void:
	if GameSettings.restart_with_renderer():
		return
	_renderer_status.text = Locale.t("settings.renderer_restart_failed")
	_renderer_status.add_theme_color_override("font_color", Color(VERMILION_LIGHT, 0.95))


func _on_autosave_timeout() -> void:
	SaveSystem.autosave({"last_mode": "settings" if _settings_overlay.visible else "menu"})
	_update_stats()


func _refresh_texts() -> void:
	for entry in _i18n_labels:
		var label: Label = entry["node"]
		if is_instance_valid(label):
			label.text = Locale.t(str(entry["key"]))
	_start_button.text = Locale.t("menu.continue" if SaveSystem.has_progress() else "menu.start")
	_settings_button.text = Locale.t("menu.settings")
	_about_button.text = Locale.t("menu.about")
	_language_button.text = Locale.t("menu.language", {"name": Locale.language_name()})
	_codex_button.text = Locale.t("menu.codex")
	_quit_button.text = Locale.t("menu.quit")
	_back_button.text = Locale.t("settings.back")
	_fullscreen_toggle.text = Locale.t("settings.on" if GameSettings.fullscreen else "settings.off")
	for index in range(GameSettings.FPS_LIMITS.size()):
		_fps_option.set_item_text(index, _fps_option_text(int(GameSettings.FPS_LIMITS[index])))
	_vsync_toggle.text = Locale.t("settings.on" if GameSettings.vsync else "settings.off")
	_renderer_restart_button.text = Locale.t("settings.renderer_restart")
	_refresh_renderer_texts()
	_update_renderer_status()


func _sync_settings_controls() -> void:
	_bgm_slider.set_value_no_signal(GameSettings.bgm_volume)
	_bgm_value.text = "%d%%" % int(round(GameSettings.bgm_volume * 100.0))
	_sfx_slider.set_value_no_signal(GameSettings.sfx_volume)
	_sfx_value.text = "%d%%" % int(round(GameSettings.sfx_volume * 100.0))
	_fullscreen_toggle.set_pressed_no_signal(GameSettings.fullscreen)
	_fullscreen_toggle.text = Locale.t("settings.on" if GameSettings.fullscreen else "settings.off")
	var fps_index := GameSettings.FPS_LIMITS.find(GameSettings.fps_limit)
	_fps_option.selected = fps_index if fps_index >= 0 else GameSettings.FPS_LIMITS.find(GameSettings.DEFAULT_FPS_LIMIT)
	_vsync_toggle.set_pressed_no_signal(GameSettings.vsync)
	_vsync_toggle.text = Locale.t("settings.on" if GameSettings.vsync else "settings.off")
	_renderer_option.selected = GameSettings.RENDERER_MODES.find(GameSettings.renderer_mode)
	_refresh_renderer_texts()
	_update_renderer_status()
	_language_option.selected = 0 if Locale.current == "zh" else 1


func _update_stats() -> void:
	if not is_instance_valid(_autosave_value):
		return
	_autosave_value.text = Locale.t("panel.enabled")
	var stamp := SaveSystem.last_saved_text()
	_last_saved_value.text = stamp if not stamp.is_empty() else Locale.t("common.never")
	_runs_value.text = str(int(SaveSystem.data.get("runs", 0)))
	_best_value.text = str(int(SaveSystem.data.get("total_merit", 0)))
	_language_value.text = Locale.language_name()
	_start_button.text = Locale.t("menu.continue" if SaveSystem.has_progress() else "menu.start")


func _register_label(label: Label, key: String) -> Label:
	_i18n_labels.append({"node": label, "key": key})
	label.text = Locale.t(key)
	return label


func _stat_row(parent: VBoxContainer, key: String, value_name: String) -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 27.0)
	var caption := _make_label("%sLabel" % value_name, "", 15, MUTED)
	caption.custom_minimum_size = Vector2(128.0, 0.0)
	_register_label(caption, key)
	row.add_child(caption)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var value := _make_label(value_name, "", 16, PAPER)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	parent.add_child(row)
	return value


func _setting_row(parent: VBoxContainer, key: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 44.0)
	row.add_theme_constant_override("separation", 18)
	var safe_key := key.replace(".", "_")
	var caption := _make_label("%sSettingLabel" % safe_key, "", 17, Color(PAPER, 0.86))
	caption.custom_minimum_size = Vector2(150.0, 0.0)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_register_label(caption, key)
	row.add_child(caption)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	parent.add_child(row)


func _label(node_name: String, text: String, position: Vector2, font_size: int, color: Color) -> Label:
	var label := _make_label(node_name, text, font_size, color)
	label.position = position
	add_child(label)
	return label


func _make_label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(node_name: String, key: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = Locale.t(key)
	button.custom_minimum_size = Vector2(320.0, 48.0)
	button.size = Vector2(320.0, 48.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color("#fff0cf"))
	button.add_theme_color_override("font_pressed_color", Color("#f4dfb2"))
	button.add_theme_color_override("font_focus_color", Color("#fff0cf"))

	if primary:
		UIControls.apply_primary(button)
	return button


func _make_text_button(node_name: String, text: String, font_size: int, minimum: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = minimum
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(MUTED, 0.9))
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_stylebox_override("normal", _flat_box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0))
	button.add_theme_stylebox_override("hover", _flat_box(Color(GOLD, 0.08), Color(GOLD, 0.45), 1))
	button.add_theme_stylebox_override("pressed", _flat_box(Color(GOLD, 0.14), Color(GOLD, 0.65), 1))
	return button


func _make_slider(value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(300.0, 28.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return slider


func _renderer_option_text(mode: String) -> String:
	if mode == GameSettings.RENDERER_AUTO:
		var detected := (
			GameSettings.RENDERER_VULKAN
			if GameSettings.vulkan_supported()
			else GameSettings.RENDERER_OPENGL
		)
		return Locale.t("settings.renderer_auto", {"name": _renderer_display_name(detected)})
	return Locale.t("settings.renderer_%s" % mode)


func _renderer_display_name(renderer: String) -> String:
	match renderer:
		GameSettings.RENDERER_VULKAN:
			return "Vulkan"
		GameSettings.RENDERER_OPENGL:
			return "OpenGL"
		_:
			return Locale.t("settings.renderer_unknown")


func _refresh_renderer_texts() -> void:
	if not is_instance_valid(_renderer_option):
		return
	var vulkan_available := GameSettings.vulkan_supported()
	for index in range(GameSettings.RENDERER_MODES.size()):
		var mode := str(GameSettings.RENDERER_MODES[index])
		_renderer_option.set_item_text(index, _renderer_option_text(mode))
		_renderer_option.set_item_disabled(
			index,
			mode == GameSettings.RENDERER_VULKAN and not vulkan_available
		)


func _update_renderer_status() -> void:
	if not is_instance_valid(_renderer_status):
		return
	var selected := _renderer_display_name(GameSettings.resolved_renderer())
	var active := _renderer_display_name(GameSettings.active_renderer())
	var requires_restart := GameSettings.renderer_requires_restart()
	_renderer_restart_button.visible = requires_restart
	if requires_restart:
		_renderer_status.text = Locale.t(
			"settings.renderer_restart_required",
			{"selected": selected, "active": active}
		)
		_renderer_status.add_theme_color_override("font_color", Color(GOLD, 0.92))
		return
	if not GameSettings.vulkan_supported():
		_renderer_status.text = Locale.t(
			"settings.renderer_fallback",
			{"active": active}
		)
	else:
		_renderer_status.text = Locale.t("settings.renderer_active", {"name": active})
	_renderer_status.add_theme_color_override("font_color", Color(MUTED, 0.80))


func _fps_option_text(limit: int) -> String:
	if limit <= 0:
		return Locale.t("settings.fps_unlimited")
	return "%d FPS" % limit


func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.color = Color(GOLD, 0.30)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _flat_box(fill: Color, border: Color, width: int, left_width: int = -1, radius: int = 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	if left_width >= 0:
		box.border_width_left = left_width
		box.border_width_top = width
		box.border_width_right = width
		box.border_width_bottom = width
	else:
		box.border_width_left = width
		box.border_width_top = width
		box.border_width_right = width
		box.border_width_bottom = width
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 22.0
	box.content_margin_right = 18.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


func _panel_texture_box(content_margin: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = PANEL_TEXTURE
	box.texture_margin_left = 28.0
	box.texture_margin_top = 28.0
	box.texture_margin_right = 28.0
	box.texture_margin_bottom = 28.0
	box.content_margin_left = float(content_margin)
	box.content_margin_top = float(content_margin)
	box.content_margin_right = float(content_margin)
	box.content_margin_bottom = float(content_margin)
	return box
