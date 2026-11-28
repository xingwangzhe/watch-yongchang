extends GutTest

const PrologueScript := preload("res://scripts/actors/prologue.gd")
const MainMenuScene := preload("res://scenes/main_menu.tscn")
const CharacterSelectScene := preload("res://scenes/character_select.tscn")
const RunGameScript := preload("res://scripts/actors/run_game.gd")
const TouchControlsScript := preload("res://scripts/ui/touch_controls.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const StoryScript := preload("res://scripts/core/story_overlay.gd")
const SETTINGS_PATH := "user://test_mobile_portrait_settings.cfg"
const RENDERER_PATH := "user://test_mobile_portrait_renderer.cfg"

var _prologue: Node


func before_each() -> void:
	_prologue = PrologueScript.new()
	add_child(_prologue)
	await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(_prologue):
		_prologue.queue_free()
		await get_tree().process_frame
	GameSettings.config_path = GameSettings.CONFIG_PATH
	GameSettings.renderer_mirror_override = ""
	GameSettings.web_platform_override = -1
	GameSettings.web_capabilities = {
		"webgl2": true,
		"renderer": "",
		"webgpu_api": false,
		"touch": false,
		"orientation": "unknown",
		"viewport_width": 0,
		"viewport_height": 0,
	}
	GameSettings.web_orientation = "portrait"
	Locale.set_language("zh", false)
	_remove_file(SETTINGS_PATH)
	_remove_file(RENDERER_PATH)


func test_portrait_prologue_text_and_controls_keep_css_pixel_readability() -> void:
	var view_size := Vector2(1280.0, 2768.0)
	var css_size := Vector2(390.0, 844.0)
	_prologue.call("_apply_ui_layout", view_size, css_size)
	var title := _prologue.get("_title_label") as Label
	var subtitle := _prologue.get("_subtitle_label") as Label
	var source := _prologue.get("_source_label") as Label
	var objective := _prologue.get("_objective") as Label
	var continue_button := _prologue.get("_continue") as Button
	var scale := view_size.x / css_size.x
	assert_gte(title.get_theme_font_size("font_size") / scale, 25.0)
	assert_gte(subtitle.get_theme_font_size("font_size") / scale, 15.0)
	assert_gte(source.get_theme_font_size("font_size") / scale, 10.0)
	assert_gte(objective.get_theme_font_size("font_size") / scale, 15.0)
	assert_gte(continue_button.get_theme_font_size("font_size") / scale, 15.0)
	assert_false((_prologue.get("_hint_label") as Label).visible)
	var story := _prologue.get("story") as StoryOverlay
	story.call("_apply_responsive_layout", view_size, css_size)
	var story_body := story.get("_body") as Label
	var story_next := story.get("_next") as Button
	assert_gte(story_body.get_theme_font_size("font_size") / scale, 17.9)
	assert_gte(story_next.custom_minimum_size.y / (view_size.y / css_size.y), 34.0)
	var narrative := _prologue.get("narrative") as NarrativePlayer
	narrative.call("_apply_responsive_layout", view_size, css_size)
	var narrative_body := narrative.get("_body") as Label
	var narrative_panel := narrative.get("_panel") as PanelContainer
	assert_gte(narrative_body.get_theme_font_size("font_size") / scale, 17.9)
	var narrative_rect := narrative_panel.get_global_rect()
	assert_gte(narrative_rect.position.y / scale, 12.0)
	assert_lte(narrative_rect.end.y / scale, css_size.y * 0.60)
	var touch := _prologue.get("_touch_controls") as PrologueTouchControls
	touch.size = view_size
	touch.call("_apply_layout", view_size, css_size)
	assert_almost_eq(touch.get("_joystick_radius") / (view_size.x / css_size.x), 68.0, 0.1)
	var interact: Rect2 = touch.call("_interact_rect")
	assert_almost_eq(interact.size.x / (view_size.x / css_size.x), 156.0, 0.1)
	assert_almost_eq((view_size.y - interact.end.y) / (view_size.y / css_size.y), 34.0, 0.1)


func test_480x854_portrait_objective_and_bottom_controls_do_not_overlap() -> void:
	var css_size := Vector2(480.0, 854.0)
	var view_size := Vector2(1280.0, 854.0 * 1280.0 / 480.0)
	_prologue.call("_apply_ui_layout", view_size, css_size)
	var objective := _prologue.get("_objective") as Label
	var continue_button := _prologue.get("_continue") as Button
	var progress := _prologue.get("_progress") as Label
	var scale := view_size.y / css_size.y
	assert_eq(objective.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_gte((continue_button.offset_top - objective.offset_bottom) / scale, 30.0)
	var progress_top := css_size.y + progress.offset_top / scale
	var continue_bottom := continue_button.offset_bottom / scale
	assert_gte(progress_top - continue_bottom, 20.0)


func test_landscape_prologue_keeps_desktop_composition_and_scale() -> void:
	var view_size := Vector2(1280.0, 720.0)
	_prologue.call("_apply_ui_layout", view_size, view_size)
	var title := _prologue.get("_title_label") as Label
	var story := _prologue.get("story") as StoryOverlay
	var narrative := _prologue.get("narrative") as NarrativePlayer
	var touch := _prologue.get("_touch_controls") as PrologueTouchControls
	touch.size = view_size
	story.call("_apply_responsive_layout", view_size, view_size)
	narrative.call("_apply_responsive_layout", view_size, view_size)
	touch.call("_apply_layout", view_size, view_size)
	assert_eq(title.get_theme_font_size("font_size"), 36)
	assert_eq((story.get("_body") as Label).get_theme_font_size("font_size"), 18)
	assert_eq((narrative.get("_body") as Label).get_theme_font_size("font_size"), 18)
	assert_eq(touch.get("_joystick_radius"), 68.0)
	assert_eq(touch.call("_interact_rect").size, Vector2(156.0, 82.0))
	assert_true((_prologue.get("_hint_label") as Label).visible)


func test_web_orientation_preference_defaults_and_roundtrips() -> void:
	GameSettings.config_path = SETTINGS_PATH
	GameSettings.renderer_mirror_override = RENDERER_PATH
	GameSettings.web_platform_override = 0
	GameSettings.web_orientation = "portrait"
	assert_eq(GameSettings.to_dict().get("web_orientation"), "portrait")
	GameSettings.set_web_orientation("landscape")
	assert_eq(GameSettings.web_orientation, "landscape")
	GameSettings.web_orientation = "portrait"
	GameSettings.load_settings()
	assert_eq(GameSettings.web_orientation, "landscape")
	GameSettings.web_platform_override = 1
	GameSettings.web_capabilities["touch"] = false
	GameSettings.web_capabilities["viewport_width"] = 390
	GameSettings.web_capabilities["viewport_height"] = 844
	GameSettings.web_orientation = "portrait"
	var menu := MainMenuScene.instantiate()
	add_child_autofree(menu)
	await wait_process_frames(2)
	var orientation := menu.find_child("WebOrientationOption", true, false) as OptionButton
	var close := menu.find_child("CloseButton", true, false) as Button
	assert_true(orientation.visible, "Web settings must expose an orientation selector even when embedded touch detection is late")
	assert_eq(orientation.get_item_text(0), "竖屏")
	assert_eq(orientation.get_item_text(1), "横屏")
	Locale.set_language("en", false)
	menu.call("_refresh_texts")
	assert_eq(orientation.get_item_text(0), "Portrait")
	assert_eq(orientation.get_item_text(1), "Landscape")
	assert_gte(close.custom_minimum_size.x, 42.0)
	orientation.select(1)
	orientation.item_selected.emit(1)
	assert_eq(GameSettings.web_orientation, "landscape")


func test_portrait_main_menu_title_and_era_do_not_overlap() -> void:
	GameSettings.web_platform_override = 1
	var menu := MainMenuScene.instantiate()
	add_child_autofree(menu)
	await wait_process_frames(2)
	menu.call("_apply_responsive_layout", Vector2(1280.0, 2768.0), Vector2(390.0, 844.0))
	var title := menu.find_child("Title", true, false) as Control
	var era := menu.find_child("Era", true, false) as Control
	var tagline := menu.find_child("Tagline", true, false) as Control
	assert_not_null(title)
	assert_not_null(era)
	assert_not_null(tagline)
	assert_gte(era.offset_top, title.offset_bottom, "portrait title must leave clear space before the era caption")
	assert_eq(era.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(tagline.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_gte(tagline.offset_top, era.offset_bottom)
	menu.queue_free()
	await wait_process_frames(2)


func test_portrait_selection_uses_readable_css_sized_panels_and_targets() -> void:
	var select := CharacterSelectScene.instantiate()
	add_child_autofree(select)
	await wait_process_frames(2)
	select.call(
		"_apply_responsive_layout_for",
		Vector2(1280.0, 2768.0),
		Vector2(390.0, 844.0),
		Vector4(6.0, 24.0, 6.0, 20.0)
	)
	var scale := 1280.0 / 390.0
	var title := select.get("_title_label") as Label
	var roster := select.get("_character_panel") as PanelContainer
	var portrait := select.get("_portrait_frame") as PanelContainer
	var start := select.get("_begin_button") as Button
	var scroll := select.get("_mobile_scroll") as ScrollContainer
	var stack := select.get("_mobile_stack") as VBoxContainer
	assert_gte(title.get_theme_font_size("font_size") / scale, 25.0)
	assert_gte(title.offset_top / scale, 31.9, "selection title must clear the top safe area")
	assert_true(scroll.visible, "portrait selection must use a scrollable layout")
	assert_gte(-scroll.offset_bottom / scale, 76.0 + 20.0 + 12.0, "selection scroll area must leave room for the safe footer")
	assert_true(roster.get_parent() == stack, "portrait roster must be stacked above details")
	assert_true(select.get("_detail_panel").get_parent() == stack, "portrait details must remain reachable below roster")
	assert_gte((select.get("_char_buttons").values()[0] as Button).custom_minimum_size.y / scale, 44.0)
	assert_gte(portrait.custom_minimum_size.x / scale, 44.0)
	assert_gte(start.custom_minimum_size.y / scale, 34.0)
	assert_false((select.get("_footer_hint") as Label).visible)
	select.queue_free()
	await wait_process_frames(2)


func test_portrait_battle_camera_and_web_touch_targets_scale_to_mobile_view() -> void:
	assert_gt(RunGameScript.portrait_camera_zoom(Vector2(1280.0, 2768.0)), 1.0)
	assert_gte(RunGameScript.portrait_camera_zoom(Vector2(1280.0, 2768.0)), 2.6)
	assert_eq(RunGameScript.portrait_camera_zoom(Vector2(1280.0, 720.0)), 1.0)
	var controls := TouchControlsScript.new()
	add_child_autofree(controls)
	controls.force_visible = true
	controls.call("_layout_for", Vector2(1280.0, 2768.0), Vector2(390.0, 844.0))
	assert_gte(controls.joystick_radius / (1280.0 / 390.0), 48.0)
	assert_gte(controls.attack_radius / (1280.0 / 390.0), 45.0)


func test_portrait_story_card_stays_above_touch_controls() -> void:
	var story := StoryScript.new()
	add_child_autofree(story)
	await wait_process_frames(2)
	var view_size := Vector2(1280.0, 2768.0)
	var css_size := Vector2(390.0, 844.0)
	story.call("_apply_responsive_layout", view_size, css_size)
	var panel := story.get("_panel") as Control
	var scale_y := view_size.y / css_size.y
	var panel_bottom_css := panel.offset_bottom / scale_y
	assert_gte(panel.offset_top / scale_y, 158.0)
	assert_lte(panel_bottom_css, 158.0 + 156.0 + 2.0)
	assert_lt(panel_bottom_css, css_size.y * 0.60, "story panel must leave the joystick and attack deck unobstructed")


func test_portrait_hud_stacks_readable_status_and_exposes_pause_button() -> void:
	var hud := HudScript.new()
	add_child(hud)
	await wait_process_frames(2)
	var view_size := Vector2(1280.0, 2768.0)
	var css_size := Vector2(390.0, 844.0)
	hud.call("_apply_responsive_layout_for", view_size, css_size, Vector4(6.0, 24.0, 6.0, 20.0))
	var root := hud.get("_root") as Control
	var scale := view_size.x / css_size.x
	var health_chip := root.get_node("TopLeftChip") as Control
	var timer_chip := root.get_node("TimerChip") as Control
	var attack_chip := root.get_node("AttackModeChip") as Control
	var score_chip := root.get_node("ScoreChip") as Control
	for control in [health_chip, timer_chip, attack_chip, score_chip]:
		var rect: Rect2 = control.get_global_rect()
		assert_gte(rect.position.x, 0.0, "%s must stay inside the portrait viewport" % control.name)
		assert_gte(rect.position.y, 0.0, "%s must stay inside the portrait viewport" % control.name)
		assert_lte(rect.end.x, view_size.x, "%s must stay inside the portrait viewport" % control.name)
		assert_lte(rect.end.y, view_size.y, "%s must stay inside the portrait viewport" % control.name)
		assert_gte(rect.position.x / scale, 6.0, "%s must clear the left safe area" % control.name)
		assert_gte(rect.position.y / scale, 24.0, "%s must clear the top safe area" % control.name)
		assert_lte(rect.end.x / scale, css_size.x - 6.0, "%s must clear the right safe area" % control.name)
	assert_gte(timer_chip.get_global_rect().position.y, health_chip.get_global_rect().end.y)
	assert_false(
		timer_chip.get_global_rect().intersects(attack_chip.get_global_rect()),
		"timer and attack mode share a row without overlapping"
	)
	assert_gte(
		score_chip.get_global_rect().position.y,
		maxf(timer_chip.get_global_rect().end.y, attack_chip.get_global_rect().end.y)
	)
	assert_false((root.get_node("OilChip") as Control).visible)
	assert_false((root.get_node("ScaleChip") as Control).visible)
	assert_true(score_chip.find_child("OilMeter", true, false) != null)
	assert_true(score_chip.find_child("ScaleMeter", true, false) != null)
	var pause_button := root.get_node("MobilePauseButton") as Button
	assert_true(pause_button.visible, "portrait battle must expose a touch pause entry")
	assert_lte(pause_button.get_global_rect().end.x / scale, css_size.x - 6.0)
	var pause_events: Array[bool] = []
	hud.pause_requested.connect(func() -> void: pause_events.append(true))
	pause_button.pressed.emit()
	assert_eq(pause_events.size(), 1, "pause button must emit pause_requested")
	hud.free()


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
