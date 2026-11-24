extends Control

const BackdropScript := preload("res://scripts/ui/menu_backdrop.gd")
const UIControls := preload("res://scripts/ui/ui_control_theme.gd")
const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const CREDITS_PATH := "res://data/credits.json"
const ABOUT_BGM_PATH := "res://assets/audio/bgm_about.ogg"

const PAPER := Color("#e8d8b6")
const MUTED := Color("#a99778")
const GOLD := Color("#d8a548")
const VERMILION := Color("#8f3326")
const INK := Color("#06090c")

const SCROLL_SPEED := 38.0
const START_DELAY := 1.0

var _credits: Dictionary = {}
var _scroll: ScrollContainer
var _content: VBoxContainer
var _status: Label
var _progress_fill: ColorRect
var _about_player: AudioStreamPlayer
var _about_stream: AudioStream
var _auto_scroll := true
var _delay_left := START_DELAY
var _scroll_accum := 0.0
var _end_reached := false


func _ready() -> void:
	_build_theme()
	_credits = _load_credits()
	_build_background()
	_build_roll()
	_build_chrome()
	AudioBus.stop_bgm()
	_start_about_music()
	GameSettings.changed.connect(_sync_about_volume)
	SaveSystem.autosave({"last_mode": "about"})
	_scroll.scroll_vertical = 0
	_scroll.grab_focus()


func is_auto_scrolling() -> bool:
	return _auto_scroll


func credits_data() -> Dictionary:
	return _credits


func about_stream() -> AudioStream:
	return _about_stream


func about_player() -> AudioStreamPlayer:
	return _about_player


func _process(delta: float) -> void:
	if not _auto_scroll:
		return
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	var bar := _scroll.get_v_scroll_bar()
	var max_scroll := int(maxf(0.0, bar.max_value - bar.page))
	if max_scroll <= 0:
		return
	if _scroll.scroll_vertical >= max_scroll:
		_finish_roll()
		return
	_scroll_accum += SCROLL_SPEED * delta
	var step := int(_scroll_accum)
	if step > 0:
		_scroll.scroll_vertical = mini(_scroll.scroll_vertical + step, max_scroll)
		_scroll_accum -= float(step)
	_update_progress(max_scroll)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_take_over_scroll()
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_take_over_scroll()
	elif event is InputEventPanGesture:
		_take_over_scroll()


func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if (
			mouse_event.pressed
			and mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
		):
			_take_over_scroll()
	elif event is InputEventPanGesture:
		_take_over_scroll()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_menu()
		get_viewport().set_input_as_handled()
	elif not _auto_scroll and event.is_action_pressed("ui_down"):
		_scroll.scroll_vertical += 58
		get_viewport().set_input_as_handled()
	elif not _auto_scroll and event.is_action_pressed("ui_up"):
		_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical - 58)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveSystem.autosave({"last_mode": "about"})
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		SaveSystem.autosave({"last_mode": "about"})


func _build_theme() -> void:
	var page_theme := Theme.new()
	page_theme.default_font = UI_FONT
	page_theme.default_font_size = 18
	theme = page_theme


func _build_background() -> void:
	var backdrop := BackdropScript.new()
	backdrop.name = "Backdrop"
	backdrop.modulate = Color(1.0, 1.0, 1.0, 0.28)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.012, 0.018, 0.022, 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_roll() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "CreditsScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.focus_mode = Control.FOCUS_ALL
	_scroll.gui_input.connect(_on_scroll_gui_input)
	add_child(_scroll)
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 48.0
	_scroll.offset_bottom = -56.0

	var page_margin := MarginContainer.new()
	page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_margin.add_theme_constant_override("margin_left", 210)
	page_margin.add_theme_constant_override("margin_right", 210)
	page_margin.add_theme_constant_override("margin_top", 34)
	page_margin.add_theme_constant_override("margin_bottom", 120)
	_scroll.add_child(page_margin)

	_content = VBoxContainer.new()
	_content.name = "CreditsContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	page_margin.add_child(_content)

	_add_spacer(16)
	_add_line(str(_credits.get("title", "守望·永昌")), 62, GOLD, 0)
	_add_line(_pick(_credits.get("subtitle", {})), 18, Color(MUTED, 0.88), 0)
	_add_rule()

	var about: Dictionary = _credits.get("about", {})
	for section in _array_value(about.get("sections", [])):
		if not section is Dictionary:
			continue
		_add_heading(_bi(section, "title"))
		for line in _lines(section):
			_add_line(str(line), 18, Color(PAPER, 0.90), 0)
		for entry in _array_value(section.get("entries", [])):
			if not entry is Dictionary:
				continue
			var entry_title := _bi(entry, "title")
			if entry_title.is_empty():
				continue
			var entry_url := str(entry.get("url", ""))
			if entry_url.is_empty():
				_add_line(entry_title, 18, PAPER, 0)
			else:
				_add_link(entry_title, entry_url, 18)
			var entry_note := _bi(entry, "note")
			if not entry_note.is_empty():
				_add_line(entry_note, 14, Color(MUTED, 0.78), 0)
			_add_credit_links(entry)
			_add_spacer(10)

	_add_heading(Locale.t("about.music"))
	for entry in _array_value(_credits.get("music", [])):
		if not entry is Dictionary:
			continue
		_add_link(str(entry.get("title", "")), str(entry.get("url", "")), 22)
		_add_line(
			"%s · %s" % [str(entry.get("artist", "")), str(entry.get("license", ""))],
			15,
			Color(MUTED, 0.92),
			0
		)
		_add_line(_bi(entry, "usage"), 15, Color(PAPER, 0.82), 0)
		_add_line(_bi(entry, "changes"), 14, Color(MUTED, 0.72), 0)
		_add_credit_links(entry)
		_add_spacer(10)

	_add_heading(Locale.t("about.sfx"))
	for entry in _array_value(_credits.get("sfx", [])):
		if not entry is Dictionary:
			continue
		_add_link(str(entry.get("title", "")), str(entry.get("url", "")), 22)
		_add_line(
			"%s · %s" % [str(entry.get("artist", "")), str(entry.get("license", ""))],
			15,
			Color(MUTED, 0.92),
			0
		)
		_add_line(_bi(entry, "usage"), 15, Color(PAPER, 0.82), 0)
		_add_line(_bi(entry, "changes"), 14, Color(MUTED, 0.72), 0)
		_add_credit_links(entry)
		_add_spacer(10)

	_add_heading(Locale.t("about.fonts"))
	for entry in _array_value(_credits.get("fonts", [])):
		if not entry is Dictionary:
			continue
		_add_link(str(entry.get("title", "")), str(entry.get("url", "")), 22)
		_add_line(
			"%s · %s" % [str(entry.get("artist", "")), str(entry.get("license", ""))],
			15,
			Color(MUTED, 0.92),
			0
		)
		_add_line(_bi(entry, "notice"), 14, Color(MUTED, 0.72), 0)
		_add_credit_links(entry)
		_add_spacer(10)

	_add_heading(Locale.t("about.icons"))
	for entry in _array_value(_credits.get("icons", [])):
		if not entry is Dictionary:
			continue
		_add_link(str(entry.get("title", "")), str(entry.get("url", "")), 19)
		_add_line(
			"%s · %s" % [str(entry.get("artist", "")), str(entry.get("license", ""))],
			14,
			Color(MUTED, 0.92),
			0
		)
		_add_line(_bi(entry, "usage"), 14, Color(PAPER, 0.82), 0)
		_add_line(_bi(entry, "changes"), 13, Color(MUTED, 0.72), 0)
		_add_credit_links(entry)
		_add_spacer(7)

	_add_heading(Locale.t("about.tools"))
	for entry in _array_value(_credits.get("tools", [])):
		if not entry is Dictionary:
			continue
		var tool_label := "%s · %s" % [
			str(entry.get("title", "")),
			str(entry.get("license", "")),
		]
		var tool_url := str(entry.get("url", ""))
		if tool_url.is_empty():
			_add_line(tool_label, 17, Color(PAPER, 0.86), 0)
		else:
			_add_link(tool_label, tool_url, 17)
		_add_credit_links(entry)

	_add_spacer(50)
	_add_line(Locale.t("about.thanks_end"), 34, GOLD, 0)
	_add_line(Locale.t("about.version"), 14, Color(MUTED, 0.62), 0)
	_add_line(Locale.t("about.hint"), 14, Color(MUTED, 0.58), 0)
	_add_spacer(110)


func _build_chrome() -> void:
	var top_bar := ColorRect.new()
	top_bar.name = "TopBar"
	top_bar.color = Color(0.012, 0.018, 0.021, 0.94)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 48.0

	var top_rule := ColorRect.new()
	top_rule.color = Color(GOLD, 0.34)
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_rule)
	top_rule.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_rule.offset_top = 47.0
	top_rule.offset_bottom = 48.0

	var header := Label.new()
	header.name = "AboutHeader"
	header.text = Locale.t("about.header")
	header.add_theme_font_override("font", UI_FONT)
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", GOLD)
	UILayout.place(header, 42.0, 12.0, 500.0, 24.0)
	add_child(header)

	var brand := Label.new()
	brand.name = "AboutBrand"
	brand.text = "WATCH · YONGCHANG"
	brand.add_theme_font_override("font", UI_FONT)
	brand.add_theme_font_size_override("font_size", 14)
	brand.add_theme_color_override("font_color", Color(MUTED, 0.62))
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UILayout.place(brand, 1000.0, 14.0, 238.0, 22.0, 1.0, 0.0)
	add_child(brand)

	var progress_track := ColorRect.new()
	progress_track.name = "ProgressTrack"
	progress_track.color = Color(GOLD, 0.13)
	progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress_track)
	progress_track.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	progress_track.offset_top = -58.0
	progress_track.offset_bottom = -56.0

	_progress_fill = ColorRect.new()
	_progress_fill.name = "ProgressFill"
	_progress_fill.color = Color(GOLD, 0.78)
	_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress_fill)
	UILayout.place(_progress_fill, 0.0, 662.0, 0.0, 2.0, 0.0, 1.0)

	var bottom_bar := ColorRect.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.color = Color(0.012, 0.018, 0.021, 0.94)
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_bar)
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -56.0

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	add_child(footer)
	UILayout.place(footer, 42.0, 670.0, 1196.0, 40.0, 0.5, 1.0)

	_status = Label.new()
	_status.name = "ScrollStatus"
	_status.text = Locale.t("about.auto")
	_status.add_theme_font_override("font", UI_FONT)
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(GOLD, 0.80))
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_status)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var hint := Label.new()
	hint.name = "AboutHint"
	hint.text = Locale.t("about.hint")
	hint.add_theme_font_override("font", UI_FONT)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(MUTED, 0.62))
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(hint)

	var back := Button.new()
	back.name = "AboutBackButton"
	back.text = Locale.t("about.return")
	back.custom_minimum_size = Vector2(166.0, 36.0)
	back.add_theme_font_override("font", UI_FONT)
	back.add_theme_font_size_override("font_size", 15)
	back.add_theme_color_override("font_color", PAPER)
	back.add_theme_color_override("font_hover_color", Color("#fff0cf"))
	UIControls.apply_compact(back)
	back.pressed.connect(_return_to_menu)
	footer.add_child(back)


func _start_about_music() -> void:
	_about_stream = load(ABOUT_BGM_PATH)
	if _about_stream is AudioStreamOggVorbis:
		(_about_stream as AudioStreamOggVorbis).loop = true
	_about_player = AudioStreamPlayer.new()
	_about_player.name = "AboutBgmPlayer"
	_about_player.stream = _about_stream
	_about_player.bus = "Master"
	add_child(_about_player)
	_sync_about_volume()
	if DisplayServer.get_name() != "headless":
		_about_player.play()


func _sync_about_volume() -> void:
	if not is_instance_valid(_about_player):
		return
	var volume := clampf(GameSettings.bgm_volume * 0.9, 0.0, 1.0)
	_about_player.volume_db = -80.0 if volume <= 0.001 else linear_to_db(volume)
	if DisplayServer.get_name() == "headless" or volume <= 0.001:
		return
	if not _about_player.playing:
		_about_player.play()


func _take_over_scroll() -> void:
	if not _auto_scroll:
		return
	_auto_scroll = false
	_end_reached = false
	_status.text = Locale.t("about.takeover")
	_status.add_theme_color_override("font_color", Color(PAPER, 0.92))


func _finish_roll() -> void:
	if _end_reached:
		return
	_auto_scroll = false
	_end_reached = true
	_status.text = Locale.t("about.end")
	_status.add_theme_color_override("font_color", Color(GOLD, 0.95))
	_update_progress(int(maxf(1.0, _scroll.get_v_scroll_bar().max_value - _scroll.get_v_scroll_bar().page)))


func _update_progress(max_scroll: int) -> void:
	if max_scroll <= 0:
		return
	var ratio := clampf(float(_scroll.scroll_vertical) / float(max_scroll), 0.0, 1.0)
	UILayout.set_size(_progress_fill, size.x * ratio, 2.0)


func _return_to_menu() -> void:
	if is_instance_valid(_about_player):
		_about_player.stop()
	SaveSystem.autosave({"last_mode": "menu"})
	AudioBus.resume_bgm()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _open_url(url: String) -> void:
	if url.is_empty():
		return
	OS.shell_open(url)


func _load_credits() -> Dictionary:
	var file := FileAccess.open(CREDITS_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open credits data: %s" % CREDITS_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Invalid credits data: %s" % CREDITS_PATH)
	return {}


func _pick(value: Variant) -> String:
	if value is Dictionary:
		var table := value as Dictionary
		return str(table.get(Locale.current, table.get("zh", "")))
	return str(value)


func _bi(entry: Dictionary, field: String) -> String:
	var localized := "%s_%s" % [field, Locale.current]
	var fallback := "%s_zh" % field
	return str(entry.get(localized, entry.get(fallback, "")))


func _lines(entry: Dictionary) -> Array:
	var localized := "lines_%s" % Locale.current
	var fallback := "lines_zh"
	var lines: Variant = entry.get(localized, entry.get(fallback, []))
	return _array_value(lines)


func _array_value(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _add_heading(text: String) -> void:
	_add_spacer(30)
	_add_line(text, 26, GOLD, 0)
	_add_rule()
	_add_spacer(4)


func _add_line(text: String, font_size: int, color: Color, spacing_before: int = 0) -> Label:
	if spacing_before > 0:
		_add_spacer(float(spacing_before))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_content.add_child(label)
	return label


func _add_link(text: String, url: String, font_size: int = 14) -> void:
	if url.is_empty():
		return
	var link := LinkButton.new()
	link.text = text
	link.tooltip_text = url
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	link.add_theme_font_override("font", UI_FONT)
	link.add_theme_font_size_override("font_size", font_size)
	link.add_theme_color_override("font_color", Color(GOLD, 0.76))
	link.add_theme_color_override("font_hover_color", GOLD)
	link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	link.pressed.connect(_open_url.bind(url))
	_content.add_child(link)


func _add_credit_links(entry: Dictionary) -> void:
	var source_url := str(entry.get("url", ""))
	var license_url := str(entry.get("license_url", ""))
	if not source_url.is_empty():
		_add_link("来源 / Source", source_url, 12)
	if not license_url.is_empty():
		_add_link("许可 / License", license_url, 12)
	var alternate_license_url := str(entry.get("license_alt_url", ""))
	if not alternate_license_url.is_empty() and alternate_license_url != license_url:
		_add_link("备选许可 / Alternate License", alternate_license_url, 12)
	var art_license_url := str(entry.get("art_license_url", ""))
	if not art_license_url.is_empty():
		_add_link("素材许可 / Asset License", art_license_url, 12)


func _add_rule() -> void:
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.color = Color(GOLD, 0.28)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(rule)


func _add_spacer(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	_content.add_child(spacer)
