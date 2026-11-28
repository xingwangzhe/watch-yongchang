extends GutTest

const CodexScene := preload("res://scenes/codex.tscn")
const ShopLabScene := preload("res://scenes/debug/shop_lab.tscn")
const SCREEN_SIZES := [Vector2(360.0, 800.0), Vector2(390.0, 844.0), Vector2(1080.0, 2340.0)]
const SAFE_INSETS := Vector4(6.0, 24.0, 6.0, 20.0)
const GEOMETRY_EPSILON := 0.01


func test_shop_portrait_layout_respects_safe_area_scroll_and_touch_targets() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 61028
	var hired: Array[String] = []
	var offers := ShopCatalog.build_offers(
		[{"id": "saber", "level": 1}], {"gaiters": 1}, hired, rng
	)
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var shop := ShopOverlay.new()
	layer.add_child(shop)
	await wait_process_frames(2)
	shop.show_shop(offers, 500, 25, {"count": 0, "max": 3, "names": ""})
	await wait_process_frames(2)

	var panel := shop.get("_panel") as PanelContainer
	var scroll := shop.get("_scroll") as ScrollContainer
	var grid := shop.get("_grid") as GridContainer
	var reroll := shop.get("_reroll_button") as Button
	var continue_button := shop.get("_continue_button") as Button
	for screen_size in SCREEN_SIZES:
		var viewport_size := _logical_viewport(screen_size)
		var scale: float = float(screen_size.x) / viewport_size.x
		shop.call("_apply_responsive_layout_for", viewport_size, screen_size, SAFE_INSETS)
		await wait_process_frames(2)
		assert_true(shop.get("_portrait_layout"))
		assert_eq(grid.columns, 1, "offers must stack in one column at %s" % screen_size)
		assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
		assert_gte(panel.offset_left * scale, SAFE_INSETS.x + 8.0 - GEOMETRY_EPSILON)
		assert_gte(panel.offset_top * scale, SAFE_INSETS.y + 8.0 - GEOMETRY_EPSILON)
		assert_gte(-panel.offset_right * scale, SAFE_INSETS.z + 8.0 - GEOMETRY_EPSILON)
		assert_gte(-panel.offset_bottom * scale, SAFE_INSETS.w + 8.0 - GEOMETRY_EPSILON)
		var card := shop.find_child("ShopCard1", true, false) as Button
		assert_gte(card.custom_minimum_size.x * scale, 280.0, "shop cards need usable width")
		assert_lte(card.custom_minimum_size.x * scale, screen_size.x - SAFE_INSETS.x - SAFE_INSETS.z - 16.0)
		assert_gte(card.custom_minimum_size.y * scale, 180.0, "two-line offer text needs vertical room")
		assert_eq(card.focus_mode, Control.FOCUS_ALL, "cards must remain keyboard and gamepad reachable")
		assert_gte(reroll.custom_minimum_size.y * scale, 48.0 - GEOMETRY_EPSILON)
		assert_gte(continue_button.custom_minimum_size.y * scale, 48.0 - GEOMETRY_EPSILON)
		var title := card.find_child("CardTitle", true, false) as Label
		assert_gt(title.get_theme_constant("outline_size"), 0)
		assert_eq(title.get_theme_color("font_outline_color"), Color("#081114", 0.98))
		var card_background := card.get_theme_stylebox("normal") as StyleBoxFlat
		assert_gt(card_background.bg_color.a, 0.9, "card text must sit on an opaque dark background")


func test_debug_shop_lab_populates_offers_inside_a_fullscreen_layer() -> void:
	var original_viewport_size: Vector2i = get_viewport().size
	get_viewport().size = Vector2i(390, 844)
	await wait_process_frames(2)
	var lab := ShopLabScene.instantiate()
	add_child_autofree(lab)
	await wait_process_frames(4)
	var shop := lab.find_child("ShopOverlay", true, false) as ShopOverlay
	var offers: Array = shop.get("_offers")
	var scroll := shop.find_child("OfferScroll", true, false) as ScrollContainer
	var first_card := shop.find_child("ShopCard1", true, false) as Button
	assert_true(shop.visible)
	assert_eq(offers.size(), 12, "the direct debug scene must populate every shop offer")
	assert_gte(shop.size.x, 390.0 - GEOMETRY_EPSILON, "shop overlay must fill the phone viewport")
	assert_gte(shop.size.y, 844.0 - GEOMETRY_EPSILON, "shop overlay must fill the phone viewport")
	assert_true(first_card.visible, "the first offer must be visible in the direct preview")
	assert_true(scroll.get_global_rect().has_area(), "offer list must receive the available panel space")
	get_viewport().size = original_viewport_size


func test_codex_portrait_layout_wraps_tabs_cards_and_detail_with_safe_area() -> void:
	var codex := CodexScene.instantiate()
	add_child_autofree(codex)
	await wait_process_frames(3)
	var tabs := codex.find_child("CodexTabs", true, false) as GridContainer
	var scroll := codex.find_child("CodexScroll", true, false) as ScrollContainer
	var title := codex.find_child("CodexTitle", true, false) as Label
	var back := codex.find_child("CodexBack", true, false) as Button
	var content := codex.get("_content") as Control
	for screen_size in SCREEN_SIZES:
		var viewport_size := _logical_viewport(screen_size)
		var scale: float = float(screen_size.x) / viewport_size.x
		codex.call("_apply_responsive_layout_for", viewport_size, screen_size, SAFE_INSETS)
		await wait_process_frames(2)
		assert_true(codex.get("_portrait_layout"))
		assert_eq(tabs.columns, 3, "seven tabs must wrap into reachable rows at %s" % screen_size)
		assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
		assert_gte(title.offset_top * scale, SAFE_INSETS.y + 9.9)
		assert_gte(title.get_theme_font_size("font_size") * scale, 18.0)
		assert_gte(back.custom_minimum_size.y * scale, 44.0 - GEOMETRY_EPSILON)
		assert_eq(back.focus_mode, Control.FOCUS_ALL)
		assert_gte(scroll.offset_top * scale, SAFE_INSETS.y + 250.0)
		assert_lte(scroll.offset_bottom * scale, screen_size.y - SAFE_INSETS.w - 12.0)
		assert_gte(scroll.offset_left * scale, SAFE_INSETS.x + 12.0)
		assert_lte(scroll.offset_right * scale, screen_size.x - SAFE_INSETS.z - 12.0)
		for tab in tabs.get_children():
			var button := tab as Button
			assert_gte(button.custom_minimum_size.y * scale, 44.0 - GEOMETRY_EPSILON)
			assert_eq(button.focus_mode, Control.FOCUS_ALL)
		var page_host := codex.get("_page_host") as VBoxContainer
		var page_grids := page_host.find_children("*", "GridContainer", true, false)
		assert_gt(page_grids.size(), 0)
		for page_grid in page_grids:
			assert_eq((page_grid as GridContainer).columns, 1, "catalog cards must use the phone width")
		var card := codex.find_child("Card_wanglu", true, false)
		var card_labels := card.find_children("*", "Label", true, false)
		assert_gt(card_labels.size(), 0, "character card must expose its outlined title")
		var card_title := card_labels[0] as Label
		assert_gt(card_title.get_theme_constant("outline_size"), 0)
		var scroll_width := scroll.size.x
		codex.call("_apply_responsive_layout_for", viewport_size, screen_size, SAFE_INSETS)
		await wait_process_frames(2)
		assert_almost_eq(
			scroll.size.x,
			scroll_width,
			GEOMETRY_EPSILON,
			"reapplying portrait layout must not shrink the codex content area"
		)

	var card := codex.find_child("Card_wanglu", true, false)
	var detail_hit := card.find_child("DetailHit", true, false) as Button
	assert_eq(detail_hit.focus_mode, Control.FOCUS_ALL)
	detail_hit.pressed.emit()
	await wait_process_frames(2)
	var detail_panel := codex.find_child("CodexDetailDialog", true, false) as PanelContainer
	var detail_scroll := codex.find_child("DetailScroll", true, false) as ScrollContainer
	var detail_close := codex.find_child("DetailClose", true, false) as Button
	var zoom_hit := codex.find_child("DetailZoomHit", true, false) as Button
	assert_eq(zoom_hit.focus_mode, Control.FOCUS_ALL)
	assert_eq(content.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED)
	assert_eq((codex.find_child("CodexDetailOverlay", true, false) as Control).focus_behavior_recursive, Control.FOCUS_BEHAVIOR_ENABLED)
	assert_eq(detail_close.get_focus_mode_with_override(), Control.FOCUS_ALL)
	assert_eq(content.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED)
	for screen_size in SCREEN_SIZES:
		var viewport_size := _logical_viewport(screen_size)
		var scale: float = float(screen_size.x) / viewport_size.x
		codex.call("_apply_responsive_layout_for", viewport_size, screen_size, SAFE_INSETS)
		await wait_process_frames(2)
		assert_gte(detail_panel.offset_left * scale, SAFE_INSETS.x + 10.0 - GEOMETRY_EPSILON)
		assert_gte(detail_panel.offset_top * scale, SAFE_INSETS.y + 10.0 - GEOMETRY_EPSILON)
		assert_gte(-detail_panel.offset_right * scale, SAFE_INSETS.z + 10.0 - GEOMETRY_EPSILON)
		assert_gte(-detail_panel.offset_bottom * scale, SAFE_INSETS.w + 10.0 - GEOMETRY_EPSILON)
		assert_eq(detail_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
		assert_gte(detail_close.custom_minimum_size.y * scale, 44.0 - GEOMETRY_EPSILON)
		assert_eq((codex.get("_detail_image_plate") as Control).get_parent(), codex.get("_detail_outer"))

	codex.open_zoom()
	await wait_process_frames(1)
	var zoom_close := codex.find_child("ZoomClose", true, false) as Button
	var detail_overlay := codex.find_child("CodexDetailOverlay", true, false) as Control
	assert_eq(detail_overlay.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED)
	assert_gte(zoom_close.custom_minimum_size.y * (SCREEN_SIZES[2].x / _logical_viewport(SCREEN_SIZES[2]).x), 44.0 - GEOMETRY_EPSILON)
	assert_almost_eq(
		(codex.get("_zoom_image") as Control).offset_top * (SCREEN_SIZES[2].x / _logical_viewport(SCREEN_SIZES[2]).x),
		SAFE_INSETS.y + 12.0,
		GEOMETRY_EPSILON
	)
	codex.close_zoom()
	assert_eq(detail_overlay.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_ENABLED)
	codex.close_detail()
	assert_eq(content.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_ENABLED)


func test_shop_portrait_english_long_copy_wraps_inside_the_panel() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1128
	var shop := ShopOverlay.new()
	add_child_autofree(shop)
	await wait_process_frames(2)
	shop.show_shop(ShopCatalog.build_offers([], {}, [], rng), 500, 25, {"count": 0, "max": 3, "names": ""})
	var screen_size := Vector2(390.0, 844.0)
	shop.call("_apply_responsive_layout_for", screen_size, screen_size, SAFE_INSETS)
	var subtitle := shop.get("_subtitle") as Label
	var hint := shop.get("_hint") as Label
	subtitle.text = "The lantern market refreshes its equipment stock during every two-minute watch." \
		+ " Compare prices and choose the supplies that support your formation."
	hint.text = "Long English market messages must wrap in the footer while reroll and continue buttons remain available."
	await wait_process_frames(3)
	assert_eq(subtitle.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(hint.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_gte(subtitle.get_visible_line_count(), subtitle.get_line_count())
	assert_gte(hint.get_visible_line_count(), hint.get_line_count())
	var panel_rect := (shop.get("_panel") as Control).get_global_rect()
	assert_true(panel_rect.encloses(subtitle.get_global_rect()), "market subtitle must stay inside its panel")
	assert_true(panel_rect.encloses(hint.get_global_rect()), "market footer copy must stay inside its panel")


func _logical_viewport(screen_size: Vector2) -> Vector2:
	return Vector2(1280.0, 1280.0 * screen_size.y / screen_size.x)
