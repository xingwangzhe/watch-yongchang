extends Control

const BackdropScript := preload("res://scripts/ui/menu_backdrop.gd")
const UIControls := preload("res://scripts/ui/ui_control_theme.gd")
const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const ABOUT_BACKDROP := preload("res://assets/ui/menu_backdrop.webp")
const CREDITS_PATH := "res://data/credits.json"
const ABOUT_BGM_PATH := "res://assets/audio/bgm_about.ogg"

const PAPER := Color("#e8d8b6")
const MUTED := Color("#a99778")
const GOLD := Color("#d8a548")
const VERMILION := Color("#8f3326")
const INK := Color("#06090c")

const SCROLL_SPEED := 38.0
const START_DELAY := 1.0
const WEB_SCROLL_INTERVAL := 1.0 / 30.0
const WEB_MIN_SCROLL_STEP := 2.0
const WEB_SKELETON_SLOTS_PER_FRAME := 32
const WEB_INITIAL_MATERIALIZE := 12
const WEB_MATERIALIZE_PER_PASS := 6
const WEB_MATERIALIZE_INTERVAL := 0.12
const WEB_MATERIALIZE_LOOKAHEAD := 520.0
const RICH_ENTRIES_PER_BLOCK := 12
const PRIORITY_SECTION_TITLES := ["致谢", "版权与许可"]

signal content_ready
signal closed

var _credits: Dictionary = {}
var _scroll: ScrollContainer
var _content: VBoxContainer
var _page_margin: MarginContainer
var _backdrop: Control
var _status: Label
var _progress_fill: ColorRect
var _about_player: AudioStreamPlayer
var _about_stream: AudioStream
var _mobile_portrait := false
var _display_scale := 1.0
var _font_size_tag_regex: RegEx
var _auto_scroll := true
var _delay_left := START_DELAY
var _scroll_accum := 0.0
var _web_scroll_accum := 0.0
var _materialize_clock := 0.0
var _progress_ratio := -1.0
var _end_reached := false
var _build_queue: Array[Dictionary] = []
var _web_slots: Array[Dictionary] = []
var _build_index := 0
var _building := false
var _ready_for_scroll := false
var _pending_content := false
var _web_content_started := false
var _activated := false
var overlay_mode := false
var prewarm_mode := false
var defer_content := false


func _ready() -> void:
	_font_size_tag_regex = RegEx.new()
	_font_size_tag_regex.compile("\\[font_size=(\\d+)\\]")
	_build_theme()
	_build_background()
	_build_roll_shell()
	_build_chrome()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	GameSettings.changed.connect(_sync_about_volume)
	if GameSettings.is_web_platform():
		_pending_content = true
		_building = false
		_status.text = Locale.t("about.loading", {"percent": 0})
		if not prewarm_mode or not defer_content:
			call_deferred("_start_web_roll_build")
	else:
		_load_roll_content()
		while _build_index < _build_queue.size():
			_instantiate_spec(_build_queue[_build_index])
			_build_index += 1
		_finish_build()
	if prewarm_mode:
		visible = not defer_content
		modulate = Color.WHITE
		_auto_scroll = false
		set_process(false)
	else:
		activate()


func activate() -> void:
	if _activated:
		return
	var start_deferred_content := defer_content
	_activated = true
	prewarm_mode = false
	defer_content = false
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	modulate = Color.WHITE
	set_process(true)
	AudioBus.stop_bgm()
	call_deferred("_start_about_music")
	SaveSystem.autosave({"last_mode": "about"})
	_scroll.scroll_vertical = 0
	_scroll.grab_focus()
	_auto_scroll = true
	_delay_left = START_DELAY
	if start_deferred_content and not _web_content_started:
		_status.text = Locale.t("about.loading", {"percent": 0})
		call_deferred("_start_web_roll_build")
	elif _pending_content or _building:
		_update_build_status()
	elif _ready_for_scroll:
		_status.text = Locale.t("about.auto")


func is_auto_scrolling() -> bool:
	return _auto_scroll


func credits_data() -> Dictionary:
	return _credits


func about_stream() -> AudioStream:
	return _about_stream


func about_player() -> AudioStreamPlayer:
	return _about_player


func is_content_ready() -> bool:
	return _ready_for_scroll


func _process(delta: float) -> void:
	if _pending_content:
		return
	if _building:
		_build_web_skeleton_chunk()
		if _building:
			return
		_finish_web_build()
	if _ready_for_scroll:
		_materialize_clock -= delta
		if _materialize_clock <= 0.0:
			_materialize_visible_window()
			_materialize_clock = WEB_MATERIALIZE_INTERVAL
	if not _auto_scroll or not _ready_for_scroll:
		return
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	var bar := _scroll.get_v_scroll_bar()
	var max_scroll := int(maxf(0.0, bar.max_value - bar.page))
	if max_scroll <= 0:
		return
	if _scroll.scroll_vertical >= max_scroll:
		if _materialize_visible_window(true) > 0:
			return
		_finish_roll()
		return
	if GameSettings.is_web_platform():
		_web_scroll_accum += delta
		if _web_scroll_accum < WEB_SCROLL_INTERVAL:
			return
		_scroll_accum += SCROLL_SPEED * _web_scroll_accum
		_web_scroll_accum = 0.0
	else:
		_scroll_accum += SCROLL_SPEED * delta
	if GameSettings.is_web_platform() and _scroll_accum < WEB_MIN_SCROLL_STEP:
		return
	var step := int(_scroll_accum)
	if step > 0:
		_scroll.scroll_vertical = mini(_scroll.scroll_vertical + step, max_scroll)
		_scroll_accum -= float(step)
	_update_progress(max_scroll)


func _build_web_skeleton_chunk() -> void:
	var budget := WEB_SKELETON_SLOTS_PER_FRAME
	while _build_index < _build_queue.size() and budget > 0:
		_add_web_slot(_build_queue[_build_index])
		_build_index += 1
		budget -= 1
	if _build_index >= _build_queue.size():
		_building = false
		_finish_web_build()
		return
	_update_build_status()


func _update_build_status() -> void:
	if not is_instance_valid(_status) or not _auto_scroll:
		return
	var total := maxi(1, _build_queue.size())
	var percent := int(round(float(_build_index) / float(total) * 100.0))
	_status.text = Locale.t("about.loading", {"percent": percent})


func _finish_build() -> void:
	if _ready_for_scroll:
		return
	_building = false
	_ready_for_scroll = true
	_delay_left = START_DELAY
	if is_instance_valid(_status) and _auto_scroll:
		_status.text = Locale.t("about.auto")
		_status.add_theme_color_override("font_color", Color(GOLD, 0.80))
	content_ready.emit()


func _finish_web_build() -> void:
	if _ready_for_scroll:
		return
	if _build_index < _build_queue.size():
		return
	_build_queue.clear()
	_build_index = 0
	_materialize_initial_page()
	_finish_build()
	_materialize_clock = WEB_MATERIALIZE_INTERVAL


func _add_web_slot(spec: Dictionary) -> void:
	var slot := VBoxContainer.new()
	slot.name = "CreditSlot%03d" % _web_slots.size()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.custom_minimum_size = Vector2(0.0, _estimate_spec_height(spec))
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(slot)
	_web_slots.append({
		"spec": spec,
		"node": slot,
		"materialized": false,
	})


func _materialize_initial_page() -> void:
	var count := mini(WEB_INITIAL_MATERIALIZE, _web_slots.size())
	for index in count:
		_materialize_slot(index)


func _materialize_visible_window(force_tail: bool = false) -> int:
	if _web_slots.is_empty() or not is_instance_valid(_scroll) or not is_instance_valid(_content):
		return 0
	var page := maxf(_scroll.size.y, 480.0)
	var top := float(_scroll.scroll_vertical) - WEB_MATERIALIZE_LOOKAHEAD * 0.35
	var bottom := float(_scroll.scroll_vertical) + page + WEB_MATERIALIZE_LOOKAHEAD
	if force_tail:
		top = maxf(0.0, float(_scroll.scroll_vertical) - page)
		bottom = float(_scroll.scroll_vertical) + page * 2.0
	var first := -1
	var count := 0
	for index in _web_slots.size():
		if bool(_web_slots[index].get("materialized", false)):
			continue
		var slot: Control = _web_slots[index]["node"] as Control
		var slot_top := slot.position.y
		var slot_bottom := slot_top + maxf(slot.size.y, slot.custom_minimum_size.y)
		if slot_bottom < top or slot_top > bottom:
			continue
		if first < 0:
			first = index
		count += 1
		if count >= WEB_MATERIALIZE_PER_PASS:
			break
	if first < 0:
		return 0
	var built := 0
	for offset in count:
		var index := first + offset
		if index >= _web_slots.size():
			break
		if bool(_web_slots[index].get("materialized", false)):
			continue
		_materialize_slot(index)
		built += 1
	return built


func _materialize_slot(index: int) -> void:
	if index < 0 or index >= _web_slots.size():
		return
	var record := _web_slots[index]
	if bool(record.get("materialized", false)):
		return
	var slot := record["node"] as VBoxContainer
	if not is_instance_valid(slot):
		return
	slot.custom_minimum_size.y = 0.0
	var spec_node := _create_spec_node(record["spec"] as Dictionary)
	slot.add_child(spec_node)
	_apply_spec_text_size(spec_node)
	record["materialized"] = true
	_web_slots[index] = record


func _estimate_spec_height(spec: Dictionary) -> float:
	match str(spec.get("type", "")):
		"line":
			var font_size := maxi(12, int(spec.get("font_size", 18)))
			var text := str(spec.get("text", ""))
			if _mobile_portrait:
				font_size = maxi(font_size, 16)
				var css_width := maxf(120.0, get_viewport_rect().size.x * _display_scale - 40.0)
				var chars_per_line_mobile := maxi(6, int(css_width / float(font_size)))
				var line_count_mobile := maxi(1, int(ceil(float(text.length()) / float(chars_per_line_mobile))))
				return UILayout.display_units(float(line_count_mobile * int(ceil(float(font_size) * 1.45)) + 4), _display_scale)
			var chars_per_line := maxi(12, int(820.0 / float(font_size)))
			var line_count := maxi(1, int(ceil(float(text.length()) / float(chars_per_line))))
			return float(line_count * int(ceil(float(font_size) * 1.45))) + 4.0
		"link":
			var link_size := maxi(int(spec.get("font_size", 14)), 16) if _mobile_portrait else int(spec.get("font_size", 14))
			return UILayout.display_units(float(link_size + 12), _display_scale) if _mobile_portrait else float(maxi(24, link_size)) + 8.0
		"rule":
			return 1.0
		"spacer":
			return float(spec.get("height", 0.0))
		"rich":
			return UILayout.display_units(float(spec.get("estimated_height", 120.0)), _display_scale) if _mobile_portrait else float(spec.get("estimated_height", 120.0))
	return 8.0


func _on_scroll_value_changed(_value: float) -> void:
	if not _activated:
		return
	_materialize_clock = 0.0
	_update_progress_from_scroll()


func _input(event: InputEvent) -> void:
	if prewarm_mode or not _activated:
		return
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
	if prewarm_mode or not _activated:
		return
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
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		set_process(false)
	if prewarm_mode or not _activated:
		return
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
	if GameSettings.is_web_platform():
		var static_backdrop := TextureRect.new()
		static_backdrop.name = "Backdrop"
		static_backdrop.texture = ABOUT_BACKDROP
		static_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		static_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		static_backdrop.modulate = Color(1.0, 1.0, 1.0, 0.28)
		static_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(static_backdrop)
		static_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		_backdrop = BackdropScript.new()
		_backdrop.name = "Backdrop"
		_backdrop.modulate = Color(1.0, 1.0, 1.0, 0.28)
		add_child(_backdrop)
		_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.012, 0.018, 0.022, 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_roll_shell() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "CreditsScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.focus_mode = Control.FOCUS_ALL
	_scroll.gui_input.connect(_on_scroll_gui_input)
	add_child(_scroll)
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_value_changed)
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 48.0
	_scroll.offset_bottom = -56.0

	var page_margin := MarginContainer.new()
	_page_margin = page_margin
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
	_build_queue.clear()
	_web_slots.clear()
	_build_index = 0
	_building = false
	_ready_for_scroll = false


func _apply_responsive_layout() -> void:
	if not is_instance_valid(_page_margin) or not is_instance_valid(_scroll):
		return
	var viewport_size := get_viewport_rect().size
	var screen_size := Vector2(DisplayServer.window_get_size())
	if OS.has_feature("web"):
		var parsed: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify([window.innerWidth || 0, window.innerHeight || 0])", true)))
		if parsed is Array and (parsed as Array).size() >= 2:
			screen_size = Vector2(float(parsed[0]), float(parsed[1]))
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		screen_size = viewport_size
	var scale := UILayout.display_scale(viewport_size, screen_size)
	var portrait := screen_size.y > screen_size.x
	_mobile_portrait = portrait
	_display_scale = scale
	var header := get_node_or_null("AboutHeader") as Label
	var brand := get_node_or_null("AboutBrand") as Label
	var footer := get_node_or_null("AboutBackButton") as Button
	var footer_row := footer.get_parent() as HBoxContainer if is_instance_valid(footer) else null
	var hint := get_node_or_null("AboutHint") as Label
	if is_instance_valid(header):
		UILayout.place(header, UILayout.display_units(18.0, scale), UILayout.display_units(10.0, scale), viewport_size.x - UILayout.display_units(36.0, scale), UILayout.display_units(34.0, scale))
		header.add_theme_font_size_override("font_size", maxi(19, roundi((22.0 if portrait else 20.0) / scale)))
	if is_instance_valid(brand):
		brand.visible = not portrait
	if is_instance_valid(hint):
		hint.visible = not portrait
	if is_instance_valid(footer_row):
		var footer_h := UILayout.display_units(62.0 if portrait else 40.0, scale)
		UILayout.place(footer_row, UILayout.display_units(8.0, scale), -footer_h - UILayout.display_units(6.0, scale), viewport_size.x - UILayout.display_units(16.0, scale), footer_h, 0.0, 1.0)
	_scroll.offset_top = UILayout.display_units(52.0 if portrait else 48.0, scale)
	_scroll.offset_bottom = -UILayout.display_units(76.0 if portrait else 56.0, scale)
	_page_margin.add_theme_constant_override("margin_left", int(UILayout.display_units(20.0 if portrait else 72.0, scale)))
	_page_margin.add_theme_constant_override("margin_right", int(UILayout.display_units(20.0 if portrait else 72.0, scale)))
	_page_margin.add_theme_constant_override("margin_top", int(UILayout.display_units(28.0, scale)))
	_page_margin.add_theme_constant_override("margin_bottom", int(UILayout.display_units(72.0 if portrait else 120.0, scale)))
	if footer is Button and portrait:
		(footer as Button).custom_minimum_size = Vector2(UILayout.display_units(150.0, scale), UILayout.display_units(50.0, scale))
		(footer as Button).add_theme_font_size_override("font_size", maxi(18, roundi(17.0 / scale)))
	_apply_content_text_sizes()


func _start_web_roll_build() -> void:
	if _web_content_started:
		return
	_web_content_started = true
	_pending_content = false
	_load_roll_content()
	_building = not _build_queue.is_empty()
	if _building:
		_update_build_status()
		if prewarm_mode:
			while _build_index < _build_queue.size():
				_add_web_slot(_build_queue[_build_index])
				_build_index += 1
			_building = false
			_finish_web_build()
	else:
		_finish_web_build()


func _load_roll_content() -> void:
	_credits = _load_credits()
	_add_spacer(16)
	_add_line(str(_credits.get("title", "守望·永昌")), 62, GOLD, 0)
	_add_line(_pick(_credits.get("subtitle", {})), 18, Color(MUTED, 0.88), 0)
	_add_rule()

	_render_free_software(_credits.get("free_software", {}))
	var about: Dictionary = _credits.get("about", {})
	var sections := _array_value(about.get("sections", []))
	for section in sections:
		if section is Dictionary and _is_priority_section(section):
			_render_section(section)
	for section in sections:
		if section is Dictionary and not _is_priority_section(section):
			_render_section(section)

	_add_heading(Locale.t("about.music"))
	_render_link_entries(
		_array_value(_credits.get("music", [])),
		"usage",
		"changes",
		22,
		15,
		14
	)

	_add_heading(Locale.t("about.sfx"))
	_render_link_entries(
		_array_value(_credits.get("sfx", [])),
		"usage",
		"changes",
		22,
		15,
		14
	)

	_add_heading(Locale.t("about.fonts"))
	_render_link_entries(
		_array_value(_credits.get("fonts", [])),
		"notice",
		"",
		22,
		15,
		14
	)

	_add_heading(Locale.t("about.icons"))
	_render_link_entries(
		_array_value(_credits.get("icons", [])),
		"usage",
		"changes",
		19,
		14,
		13
	)

	_add_heading(Locale.t("about.tools"))
	_render_tools(_array_value(_credits.get("tools", [])))

	_add_spacer(50)
	_add_line(
		Locale.t("about.version").format({"version": ProjectMeta.version}),
		14,
		Color(MUTED, 0.62),
		0
	)
	var author_line := _add_line(
		Locale.t("about.author").format({
			"author": ProjectMeta.author,
			"email": ProjectMeta.author_email,
		}),
		15,
		Color(PAPER, 0.78),
		0
	)
	author_line["name"] = "AboutAuthor"
	if not ProjectMeta.repo_url.is_empty():
		var repository_link := _add_link(
			Locale.t("about.repository"),
			ProjectMeta.repo_url,
			15
		)
		if not repository_link.is_empty():
			repository_link["name"] = "AboutRepositoryLink"
	if not ProjectMeta.web_url.is_empty():
		var web_link := _add_link(Locale.t("about.web"), ProjectMeta.web_url, 15)
		if not web_link.is_empty():
			web_link["name"] = "AboutWebLink"
	_add_spacer(12)
	_add_line(Locale.t("about.thanks_end"), 34, GOLD, 0)
	_add_spacer(110)


func _render_free_software(free_software: Dictionary) -> void:
	if free_software.is_empty():
		return
	_add_heading(_bi(free_software, "title"))
	for line in _lines(free_software):
		_add_line(str(line), 18, Color(PAPER, 0.90), 0)
	var source_url := str(free_software.get("url", ""))
	var source_label := _bi(free_software, "link")
	if not source_url.is_empty() and not source_label.is_empty():
		_add_spacer(6)
		_add_link(source_label, source_url, 16)


func _render_section(section: Dictionary) -> void:
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


func _render_link_entries(
	entries: Array,
	body_field: String,
	changes_field: String,
	title_size: int,
	meta_size: int,
	body_size: int
) -> void:
	var block := ""
	var block_entries := 0
	for entry in entries:
		if not entry is Dictionary:
			continue
		block += _entry_bbcode(
			entry,
			body_field,
			changes_field,
			title_size,
			meta_size,
			body_size
		)
		block_entries += 1
		if block_entries >= RICH_ENTRIES_PER_BLOCK:
			_add_rich_block(block, block_entries)
			block = ""
			block_entries = 0
	if not block.is_empty():
		_add_rich_block(block, block_entries)


func _entry_bbcode(
	entry: Dictionary,
	body_field: String,
	changes_field: String,
	title_size: int,
	meta_size: int,
	body_size: int
) -> String:
	var title := _bb_escape(str(entry.get("title", "")))
	var title_url := str(entry.get("url", ""))
	var lines := PackedStringArray()
	lines.append(_bb_center(
		_bb_url(title, title_url, title_size, GOLD)
	))
	lines.append(_bb_center(_bb_color(
		"%s · %s" % [
			str(entry.get("artist", "")),
			str(entry.get("license", "")),
		],
		meta_size,
		Color(MUTED, 0.92)
	)))
	var body := _bi(entry, body_field)
	if not body.is_empty():
		lines.append(_bb_center(_bb_color(body, body_size, Color(PAPER, 0.84))))
	if not changes_field.is_empty():
		var changes := _bi(entry, changes_field)
		if not changes.is_empty():
			lines.append(_bb_center(_bb_color(
				changes,
				maxi(12, body_size - 1),
				Color(MUTED, 0.72)
			)))
	var links := _credit_links_bbcode(entry)
	if not links.is_empty():
		lines.append(_bb_center(links))
	return "\n".join(lines) + "\n\n"


func _render_tools(entries: Array) -> void:
	var block := ""
	var block_entries := 0
	for entry in entries:
		if not entry is Dictionary:
			continue
		var label := "%s · %s" % [
			str(entry.get("title", "")),
			str(entry.get("license", "")),
		]
		var url := str(entry.get("url", ""))
		block += _bb_center(_bb_url(label, url, 17, Color(PAPER, 0.86)))
		var links := _credit_links_bbcode(entry)
		if not links.is_empty():
			block += "\n" + _bb_center(links)
		block += "\n\n"
		block_entries += 1
		if block_entries >= RICH_ENTRIES_PER_BLOCK:
			_add_rich_block(block, block_entries)
			block = ""
			block_entries = 0
	if not block.is_empty():
		_add_rich_block(block, block_entries)


func _credit_links_bbcode(entry: Dictionary) -> String:
	var links := PackedStringArray()
	var source_url := str(entry.get("url", ""))
	var license_url := str(entry.get("license_url", ""))
	if not source_url.is_empty():
		links.append(_bb_url("来源 / Source", source_url, 12, GOLD))
	if not license_url.is_empty():
		links.append(_bb_url("许可 / License", license_url, 12, GOLD))
	var alternate_license_url := str(entry.get("license_alt_url", ""))
	if not alternate_license_url.is_empty() and alternate_license_url != license_url:
		links.append(_bb_url("备选许可 / Alternate License", alternate_license_url, 12, GOLD))
	var art_license_url := str(entry.get("art_license_url", ""))
	if not art_license_url.is_empty():
		links.append(_bb_url("素材许可 / Asset License", art_license_url, 12, GOLD))
	return " · ".join(links)


func _bb_url(text: String, url: String, font_size: int, color: Color) -> String:
	var styled := _bb_color(_bb_escape(text), font_size, color)
	if url.is_empty():
		return styled
	return "[url=%s]%s[/url]" % [url, styled]


func _bb_color(text: String, font_size: int, color: Color) -> String:
	var resolved_size := font_size
	if _mobile_portrait:
		resolved_size = roundi(float(maxi(font_size, 16)) / maxf(0.05, _display_scale))
	return "[font_size=%d][color=#%s]%s[/color][/font_size]" % [
		resolved_size,
		color.to_html(false),
		_bb_escape(text),
	]


func _bb_center(text: String) -> String:
	return "[center]%s[/center]" % text


func _bb_escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _is_priority_section(section: Dictionary) -> bool:
	return str(section.get("title_zh", "")) in PRIORITY_SECTION_TITLES


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
	brand.text = ProjectMeta.game_name_en
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
	_about_stream = AudioBus.about_stream
	if _about_stream == null:
		_about_stream = load(ABOUT_BGM_PATH)
	if _about_stream is AudioStreamOggVorbis:
		(_about_stream as AudioStreamOggVorbis).loop = true
	if OS.has_feature("web") and is_instance_valid(AudioBus.about_player):
		_about_player = AudioBus.about_player
		_sync_about_volume()
		return
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
	if _about_player.stream_paused:
		_about_player.stream_paused = false
	elif not _about_player.playing:
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
	if absf(ratio - _progress_ratio) < 0.002:
		return
	_progress_ratio = ratio
	UILayout.set_size(_progress_fill, size.x * ratio, 2.0)


func _update_progress_from_scroll() -> void:
	if not is_instance_valid(_scroll) or not is_instance_valid(_progress_fill):
		return
	var bar := _scroll.get_v_scroll_bar()
	_update_progress(int(maxf(0.0, bar.max_value - bar.page)))


func _return_to_menu() -> void:
	if is_instance_valid(_about_player):
		if OS.has_feature("web") and _about_player == AudioBus.about_player:
			_about_player.stream_paused = true
		else:
			_about_player.stop()
	SaveSystem.autosave({"last_mode": "menu"})
	AudioBus.resume_bgm()
	if overlay_mode:
		closed.emit()
		queue_free()
		return
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _open_url(url: String) -> void:
	if OS.has_feature("baidu_h5") or url.is_empty():
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


func _add_line(text: String, font_size: int, color: Color, spacing_before: int = 0) -> Dictionary:
	if spacing_before > 0:
		_add_spacer(float(spacing_before))
	var spec := {
		"type": "line",
		"text": text,
		"font_size": font_size,
		"color": color,
		"name": "",
	}
	_build_queue.append(spec)
	return spec


func _add_link(text: String, url: String, font_size: int = 14) -> Dictionary:
	if url.is_empty():
		return {}
	var spec := {
		"type": "link",
		"text": text,
		"url": url,
		"font_size": font_size,
		"name": "",
	}
	_build_queue.append(spec)
	return spec


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
	_build_queue.append({"type": "rule"})


func _add_spacer(height: float) -> void:
	_build_queue.append({"type": "spacer", "height": height})


func _add_rich_block(bbcode: String, entries: int = 1) -> void:
	_build_queue.append({
		"type": "rich",
		"bbcode": bbcode,
		"estimated_height": float(maxi(1, entries) * 120),
	})


func _instantiate_spec(spec: Dictionary) -> void:
	var node := _create_spec_node(spec)
	_content.add_child(node)
	_apply_spec_text_size(node)


func _create_spec_node(spec: Dictionary) -> Control:
	match str(spec.get("type", "")):
		"line":
			var label := Label.new()
			label.text = str(spec.get("text", ""))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.add_theme_font_override("font", UI_FONT)
			label.set_meta("about_font_key", "font_size")
			label.set_meta("about_base_font_size", int(spec.get("font_size", 18)))
			label.add_theme_color_override("font_color", spec.get("color", PAPER) as Color)
			var label_name := str(spec.get("name", ""))
			if not label_name.is_empty():
				label.name = label_name
			return label
		"link":
			if _mobile_portrait:
				var rich_link := RichTextLabel.new()
				rich_link.bbcode_enabled = true
				rich_link.fit_content = true
				rich_link.scroll_active = false
				rich_link.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				rich_link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rich_link.mouse_filter = Control.MOUSE_FILTER_PASS
				rich_link.add_theme_font_override("normal_font", UI_FONT)
				rich_link.set_meta("about_font_key", "normal_font_size")
				rich_link.set_meta("about_base_font_size", maxi(int(spec.get("font_size", 14)), 16))
				rich_link.text = _bb_center(_bb_url(str(spec.get("text", "")), str(spec.get("url", "")), int(spec.get("font_size", 14)), GOLD))
				rich_link.meta_clicked.connect(_open_url)
				return rich_link
			var link := LinkButton.new()
			link.text = str(spec.get("text", ""))
			var url := str(spec.get("url", ""))
			link.tooltip_text = url
			link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			link.add_theme_font_override("font", UI_FONT)
			link.set_meta("about_font_key", "font_size")
			link.set_meta("about_base_font_size", int(spec.get("font_size", 14)))
			link.add_theme_color_override("font_color", Color(GOLD, 0.76))
			link.add_theme_color_override("font_hover_color", GOLD)
			link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			link.pressed.connect(_open_url.bind(url))
			var link_name := str(spec.get("name", ""))
			if not link_name.is_empty():
				link.name = link_name
			return link
		"rule":
			var rule := ColorRect.new()
			rule.custom_minimum_size = Vector2(0.0, 1.0)
			rule.color = Color(GOLD, 0.28)
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return rule
		"spacer":
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0.0, float(spec.get("height", 0.0)))
			return spacer
		"rich":
			var rich := RichTextLabel.new()
			rich.bbcode_enabled = true
			rich.fit_content = true
			rich.scroll_active = false
			rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rich.mouse_filter = Control.MOUSE_FILTER_PASS
			rich.add_theme_font_override("normal_font", UI_FONT)
			rich.set_meta("about_font_key", "normal_font_size")
			rich.set_meta("about_base_font_size", 16)
			rich.set_meta("about_base_bbcode", str(spec.get("bbcode", "")))
			rich.add_theme_color_override("default_color", PAPER)
			rich.meta_clicked.connect(_open_url)
			rich.text = _scale_about_bbcode(str(spec.get("bbcode", "")))
			return rich
	return Control.new()


func _apply_content_text_sizes() -> void:
	if not is_instance_valid(_content):
		return
	for node in _content.find_children("*", "Control", true, false):
		_apply_spec_text_size(node)


func _apply_spec_text_size(node: Node) -> void:
	var base_size := int(node.get_meta("about_base_font_size", 0))
	if base_size <= 0 or not node is Control:
		return
	var font_key := str(node.get_meta("about_font_key", "font_size"))
	var css_size := maxi(base_size, 16) if _mobile_portrait else base_size
	var logical_size := roundi(float(css_size) / maxf(0.05, _display_scale)) if _mobile_portrait else css_size
	(node as Control).add_theme_font_size_override(font_key, logical_size)
	if node is RichTextLabel:
		var base_bbcode := str(node.get_meta("about_base_bbcode", ""))
		if not base_bbcode.is_empty():
			(node as RichTextLabel).text = _scale_about_bbcode(base_bbcode)
	if node is Label and _mobile_portrait:
		(node as Label).add_theme_constant_override("line_spacing", roundi(3.0 / maxf(0.05, _display_scale)))
	elif node is RichTextLabel and _mobile_portrait:
		(node as RichTextLabel).add_theme_constant_override("line_separation", roundi(3.0 / maxf(0.05, _display_scale)))


func _scale_about_bbcode(source: String) -> String:
	if not _mobile_portrait or _font_size_tag_regex == null:
		return source
	var matches := _font_size_tag_regex.search_all(source)
	if matches.is_empty():
		return source
	var result := ""
	var cursor := 0
	for found in matches:
		var start := found.get_start()
		var end := found.get_end()
		result += source.substr(cursor, start - cursor)
		var css_size := maxi(16, int(found.get_string(1)))
		var logical_size := roundi(float(css_size) / maxf(0.05, _display_scale))
		result += "[font_size=%d]" % logical_size
		cursor = end
	result += source.substr(cursor)
	return result
