extends GutTest

const DEBUG_SCENES := [
	"res://scenes/debug/debug_hub.tscn",
	"res://scenes/debug/component_state_lab.tscn",
	"res://scenes/debug/terrain_lab.tscn",
	"res://scenes/debug/enemy_animation_lab.tscn",
	"res://scenes/debug/attack_feedback_lab.tscn",
	"res://scenes/debug/shop_lab.tscn",
	"res://scenes/components/battle_debug_panel.tscn",
]
const COMPONENT_LAB_SCRIPT := preload("res://scripts/dev/debug_component_lab.gd")
const COMPONENT_LAB_SCENE := preload("res://scenes/debug/component_state_lab.tscn")


func test_debug_rooms_are_independently_loadable_scenes() -> void:
	for scene_path in DEBUG_SCENES:
		assert_true(ResourceLoader.exists(scene_path), "missing debug room %s" % scene_path)
		assert_not_null(load(scene_path), "debug room failed to load %s" % scene_path)


func test_component_catalog_lists_direct_screen_hud_overlay_and_visual_states() -> void:
	var lab := COMPONENT_LAB_SCRIPT.new()
	var ids: Array[String] = lab.scenario_ids()
	assert_gte(ids.size(), 18)
	for required_id in [
		"main_menu",
		"character_select",
		"codex",
		"about",
		"prologue",
		"shop",
		"pause",
		"result_victory",
		"result_defeat",
		"hud_standard",
		"hud_critical",
		"hud_dark",
		"hud_boss",
		"banner_upgrade",
		"upgrade_choices",
		"tutorial_page_1",
		"story_subtitle",
		"typography",
		"sprite_atlases",
	]:
		assert_true(ids.has(required_id), "missing directly selectable debug state %s" % required_id)
	assert_gte(lab.scenario_manifest().size(), ids.size())
	lab.free()


func test_debug_component_toolbar_respects_phone_safe_area_and_touch_sizes() -> void:
	var original_viewport_size: Vector2i = get_viewport().size
	var screen_size := Vector2(390.0, 844.0)
	var viewport_size := Vector2(1280.0, 1280.0 * screen_size.y / screen_size.x)
	var scale := screen_size.x / viewport_size.x
	var safe := Vector4(6.0, 24.0, 6.0, 20.0)
	get_viewport().size = Vector2i(roundi(viewport_size.x), roundi(viewport_size.y))
	await wait_process_frames(2)
	var host := Control.new()
	host.size = viewport_size
	add_child_autofree(host)
	var lab := COMPONENT_LAB_SCENE.instantiate()
	lab.set("initial_case", "upgrade_choices")
	host.add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await wait_process_frames(4)
	lab.call("_apply_responsive_layout_for", viewport_size, screen_size, safe)
	await wait_process_frames(2)
	var toolbar := lab.get("_toolbar") as Control
	var toolbar_rect := toolbar.get_global_rect()
	assert_gte(toolbar_rect.position.x * scale, safe.x + 8.0 - 1.0)
	assert_gte(toolbar_rect.position.y * scale, safe.y + 8.0 - 1.0)
	for control_name in ["‹ 目录", "", "收起"]:
		var control: Control
		if control_name.is_empty():
			control = lab.get("_selector") as Control
		else:
			for candidate in lab.find_children("*", "Button", true, false):
				if (candidate as Button).text == control_name:
					control = candidate as Control
					break
		assert_not_null(control, "debug toolbar control should exist: %s" % control_name)
		assert_gte(control.size.y * scale, 44.0, "debug toolbar touch target must be at least 44 CSS pixels")
	var reopen := lab.get("_reopen_button") as Button
	assert_gte(reopen.size.y * scale, 44.0, "reopen control must meet the phone touch target")
	assert_gte(reopen.get_global_rect().position.y * scale, safe.y + 8.0 - 1.0)
	assert_lte(reopen.get_global_rect().end.x * scale, screen_size.x - safe.z - 8.0 + 1.0)
	host.queue_free()
	get_viewport().size = original_viewport_size
	await wait_process_frames(2)


func test_debug_hub_buttons_scale_for_phone_touch_and_safe_insets() -> void:
	var original_viewport_size: Vector2i = get_viewport().size
	var screen_size := Vector2(390.0, 844.0)
	var viewport_size := Vector2(1280.0, 1280.0 * screen_size.y / screen_size.x)
	var scale := screen_size.x / viewport_size.x
	var safe := Vector4(6.0, 24.0, 6.0, 20.0)
	get_viewport().size = Vector2i(roundi(viewport_size.x), roundi(viewport_size.y))
	await wait_process_frames(2)
	var host := Control.new()
	host.size = viewport_size
	add_child_autofree(host)
	var hub := (load("res://scenes/debug/debug_hub.tscn") as PackedScene).instantiate()
	host.add_child(hub)
	hub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await wait_process_frames(3)
	hub.call("_apply_responsive_layout_for", viewport_size, screen_size, safe)
	await wait_process_frames(2)
	var scenario_button := hub.find_child("ScenarioGrid_调试房间", true, false).get_child(0) as Button
	assert_gte(scenario_button.size.y * scale, 74.0, "debug room tiles should remain readable and tappable")
	var margin := hub.get("_margin") as MarginContainer
	assert_gte(margin.get_theme_constant("margin_left") * scale, safe.x + 10.0 - 1.0)
	assert_gte(margin.get_theme_constant("margin_top") * scale, safe.y + 10.0 - 1.0)
	host.queue_free()
	get_viewport().size = original_viewport_size
	await wait_process_frames(2)


func test_hud_portrait_state_loads_without_a_run_game_process() -> void:
	var lab := COMPONENT_LAB_SCENE.instantiate()
	lab.set("initial_case", "hud_dark")
	add_child_autofree(lab)
	await wait_process_frames(3)
	assert_eq(str(lab.get("_current_case")), "hud_dark")
	var hud := lab.get("_current_preview") as RunHUD
	assert_not_null(hud)
	assert_true(hud.visible)
	assert_null(lab.find_child("RunGame", true, false), "debug HUD preview must not require a live run")


func test_level_up_cards_open_directly_without_xp_progression() -> void:
	var lab := COMPONENT_LAB_SCENE.instantiate()
	lab.set("initial_case", "upgrade_choices")
	add_child_autofree(lab)
	await wait_process_frames(4)
	assert_eq(str(lab.get("_current_case")), "upgrade_choices")
	var overlay := lab.get("_current_preview") as LevelUpOverlay
	assert_not_null(overlay)
	assert_true(overlay.visible)
	assert_eq(overlay._options.size(), 3)
	assert_null(lab.find_child("RunGame", true, false), "debug upgrade preview must not wait for XP")


func test_upgrade_banner_is_shown_as_a_standalone_hud_state() -> void:
	var lab := COMPONENT_LAB_SCENE.instantiate()
	lab.set("initial_case", "banner_upgrade")
	add_child_autofree(lab)
	await wait_process_frames(4)
	assert_eq(str(lab.get("_current_case")), "banner_upgrade")
	var hud := lab.get("_current_preview") as RunHUD
	assert_not_null(hud)
	assert_true(hud._banner_panel.visible)
	assert_null(lab.find_child("RunGame", true, false), "debug banner preview must not wait for a level-up event")


func test_run_overlay_previews_are_direct_and_do_not_mutate_save_data() -> void:
	var run_scene := load("res://scenes/run.tscn") as PackedScene
	assert_not_null(run_scene)
	var save_before := SaveSystem.data.duplicate(true)
	var run: Node = run_scene.instantiate()
	run.set("debug_preview_only", true)
	add_child_autofree(run)
	await wait_process_frames(3)
	run.call("debug_preview_state", "pause")
	assert_true((run.get("pause_overlay") as Control).visible)
	assert_eq(SaveSystem.data, save_before, "opening a pause preview must not start or save a run")
	run.call("debug_preview_state", "result_victory")
	assert_true((run.get("result_overlay") as Control).visible)
	assert_eq(SaveSystem.data, save_before, "previewing a result must not write progression")


func test_enemy_debug_room_uses_same_cropped_person_frames_for_walk_and_attack() -> void:
	var battlefield := Battlefield.new()
	add_child_autofree(battlefield)
	battlefield.setup(20261128)
	var enemy_index := battlefield.spawn_enemy_at("scout", battlefield.player_pos + Vector2(120, 0))
	assert_gte(enemy_index, 0)
	var walk_frames: Array = battlefield.enemy_sprite_frames.get("scout", []) as Array
	var enemy: Dictionary = battlefield.enemies[enemy_index]
	var attack_frames: Array = enemy.get("attack_frames", []) as Array
	assert_eq(walk_frames.size(), 8)
	assert_eq(attack_frames, walk_frames, "attack pose must keep this enemy's own full-character atlas row")
	for frame in walk_frames:
		assert_eq((frame as Texture2D).get_size(), Vector2(128, 128))
	var initial_position: Vector2 = enemy.get("pos", Vector2.ZERO)
	var player_state := {"pos": battlefield.player_pos, "facing": Vector2.LEFT, "radius": 18.0}
	for _frame_index in 60:
		battlefield.update_world(1.0 / 60.0, player_state)
		battlefield.advance_flow_field(256)
	var moved_enemy: Dictionary = battlefield.enemies[enemy_index]
	assert_gt((moved_enemy.get("pos", Vector2.ZERO) as Vector2).distance_to(initial_position), 4.0, "enemy row must animate on an actually moving enemy")
