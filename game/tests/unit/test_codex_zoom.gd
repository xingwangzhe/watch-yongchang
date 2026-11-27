extends GutTest


func before_each() -> void:
	Locale.set_language("zh", false)


func after_each() -> void:
	Locale.set_language("zh", false)


func test_zoom_opens_from_detail_image_and_exits_by_backdrop_close_and_escape() -> void:
	var codex = await _open_codex()
	var card: Node = codex.find_child("Card_wanglu", true, false)
	var detail_hit := card.find_child("DetailHit", true, false) as Button
	detail_hit.pressed.emit()
	await wait_process_frames(2)
	assert_true(codex.detail_is_open())

	var zoom_hit := codex.find_child("DetailZoomHit", true, false) as Button
	assert_not_null(zoom_hit)
	zoom_hit.pressed.emit()
	await wait_process_frames(2)
	assert_true(codex.zoom_is_open())
	var overlay := codex.find_child("CodexZoomOverlay", true, false) as Control
	assert_not_null(overlay)
	assert_true(overlay.visible)
	var image := overlay.find_child("ZoomImage", true, false) as TextureRect
	assert_not_null(image)
	assert_not_null(image.texture)
	assert_eq(image.expand_mode, TextureRect.EXPAND_IGNORE_SIZE)
	assert_eq(image.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert_eq(image.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_gte(image.size.x, 1280.0 * 0.8)
	assert_gte(image.size.y, 720.0 * 0.8)
	var backdrop := overlay.find_child("ZoomBackdrop", true, false) as Button
	assert_not_null(backdrop)
	assert_not_null(overlay.find_child("ZoomClose", true, false))

	backdrop.pressed.emit()
	assert_false(codex.zoom_is_open())
	assert_true(codex.detail_is_open())

	zoom_hit.pressed.emit()
	var close := overlay.find_child("ZoomClose", true, false) as Button
	close.pressed.emit()
	assert_false(codex.zoom_is_open())
	assert_true(codex.detail_is_open())

	zoom_hit.pressed.emit()
	codex._unhandled_input(_escape_event())
	assert_false(codex.zoom_is_open())
	assert_true(codex.detail_is_open())


func test_escape_unwinds_zoom_before_detail_and_close_detail_clears_zoom() -> void:
	var codex = await _open_codex()
	var detail_hit := (codex.find_child("Card_wanglu", true, false) as Node).find_child(
		"DetailHit", true, false
	) as Button
	detail_hit.pressed.emit()
	await wait_process_frames(2)
	var zoom_hit := codex.find_child("DetailZoomHit", true, false) as Button
	zoom_hit.pressed.emit()
	assert_true(codex.zoom_is_open())

	var escape := _escape_event()
	codex._unhandled_input(escape)
	assert_false(codex.zoom_is_open())
	assert_true(codex.detail_is_open())
	codex._unhandled_input(escape)
	assert_false(codex.detail_is_open())

	detail_hit.pressed.emit()
	zoom_hit.pressed.emit()
	assert_true(codex.zoom_is_open())
	codex.close_detail()
	assert_false(codex.zoom_is_open())
	assert_false(codex.detail_is_open())


func test_zoom_requires_a_visible_detail_image() -> void:
	var codex = await _open_codex()
	codex.select_tab("maps")
	await wait_process_frames(2)
	var map_hit := (codex.find_child("Map_tideland", true, false) as Node).find_child(
		"DetailHit", true, false
	) as Button
	map_hit.pressed.emit()
	await wait_process_frames(2)
	assert_true(codex.detail_is_open())
	assert_false(codex.find_child("DetailImagePlate", true, false).visible)
	codex.open_zoom()
	assert_false(codex.zoom_is_open())


func test_cards_show_distinct_complete_atlas_frames_for_six_posts() -> void:
	var codex = await _open_codex()
	var frame_positions: Dictionary = {}
	for character_id in ["wanglu", "amei", "ashi", "achong", "agong", "aqi"]:
		var portrait: Node = codex.find_child("Portrait_%s" % character_id, true, false)
		assert_not_null(portrait)
		var texture_rect := portrait.find_child("PortraitTexture", true, false) as TextureRect
		var texture := texture_rect.texture as AtlasTexture
		assert_true(texture is AtlasTexture)
		assert_eq(texture.region.size, Vector2(128, 128))
		assert_string_contains(texture.atlas.resource_path, "res://assets/units/full_sheets/wanglu_watchposts.webp")
		frame_positions[texture.region.position] = true
	assert_eq(frame_positions.size(), 6, "each Wang Lu watch post has a distinct complete-character portrait frame")


func test_english_codex_text_and_controls_fit_at_both_resolutions() -> void:
	for canvas_size in [Vector2(1280, 720), Vector2(1600, 900)]:
		var codex = await _open_codex(canvas_size, "en")
		var bounds := (codex.get_parent() as Control).get_global_rect()
		for tab_id in ["cards", "upgrades", "equipment", "weapons", "enemies", "maps", "history"]:
			codex.select_tab(tab_id)
			await wait_process_frames(1)
			for raw_label in codex.find_children("*", "Label", true, false):
				var label := raw_label as Label
				if label.text.strip_edges().is_empty():
					continue
				assert_false(label.clip_text, "%s clips text" % label.name)
				assert_lte(label.max_lines_visible, 0, "%s caps lines" % label.name)
				assert_eq(
					int(label.text_overrun_behavior),
					0,
					"%s trims text" % label.name
				)
				if label.text.length() >= 80:
					assert_ne(
						label.autowrap_mode,
						TextServer.AUTOWRAP_OFF,
						"%s does not wrap long text" % label.name
					)
			for raw_button in codex.find_children("*", "Button", true, false):
				var button := raw_button as Button
				if not button.is_visible_in_tree() or button.text.strip_edges().is_empty():
					continue
				var font := button.get_theme_font("font")
				var font_size := button.get_theme_font_size("font_size")
				var style := button.get_theme_stylebox("normal")
				var margins := (
					style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)
				)
				assert_lte(
					font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + margins,
					button.size.x + 3.0,
					"%s button text overflows" % button.name
				)
			for raw_control in codex.find_children("*", "Control", true, false):
				var control := raw_control as Control
				if not control.is_visible_in_tree() or control.size.x <= 0.0:
					continue
				assert_gte(control.get_global_rect().position.x, bounds.position.x - 3.0)
				assert_lte(control.get_global_rect().end.x, bounds.end.x + 3.0)


func test_english_culture_detail_shows_the_full_expanded_note() -> void:
	var codex = await _open_codex(Vector2(1280, 720), "en")
	codex.select_tab("history")
	await wait_process_frames(2)
	var culture: Node = codex.find_child("Culture_garrison", true, false)
	assert_not_null(culture)
	var hit := culture.find_child("DetailHit", true, false) as Button
	hit.pressed.emit()
	await wait_process_frames(2)
	var data := GameData.load_json("res://data/codex.json")
	var sections := data.get("culture_sections", []) as Array
	var body_en := str((sections[0] as Dictionary).get("body_en", ""))
	assert_gt(body_en.length(), 700)
	assert_string_contains(_all_text(codex.find_child("CodexDetailOverlay", true, false)), body_en)


func _escape_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	return event


func _open_codex(canvas_size := Vector2(1280, 720), lang := "zh"):
	Locale.set_language(lang, false)
	var host := Control.new()
	host.name = "CodexZoomHost"
	host.position = Vector2.ZERO
	host.size = canvas_size
	add_child_autofree(host)
	var codex := (load("res://scenes/codex.tscn") as PackedScene).instantiate()
	host.add_child(codex)
	codex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await wait_process_frames(3)
	return codex


func _all_text(root: Node) -> String:
	var text := ""
	for label in root.find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	return text
