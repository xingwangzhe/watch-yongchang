extends GutTest

const CELL := 128


func test_enemy_caps_keep_desktop_design_and_limit_mobile_web_crowds() -> void:
	assert_eq(Battlefield.enemy_cap_for_platform(false, false), 460)
	assert_eq(Battlefield.enemy_cap_for_platform(true, false), 180)
	assert_eq(Battlefield.enemy_cap_for_platform(true, true), 120)


func test_enemy_obstacle_steering_keeps_committed_side() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	var layout := MapLayout.new()
	layout.setup("steering_hysteresis", {
		"layout": {
			"world_tiles": [24, 24],
			"start_tile": [3, 3],
			"base_tile": "mud_a",
		}
	})
	layout.mark_solid_rect(Rect2i(10, 8, 1, 8))
	layout.finalize()
	field.map_layout = layout
	var position := layout.cell_center(Vector2i(8, 12))
	var navigation := Vector2.RIGHT
	var enemy := {"steer_side": 1}
	var first := field._enemy_obstacle_steering(position, navigation, 10.0, false, 1)
	assert_gt(navigation.cross(first), 0.0, "the first clear detour must honor its preferred side")
	field._commit_enemy_steer_side(enemy, navigation, first)
	var second := field._enemy_obstacle_steering(
		position + Vector2(0.0, 2.0),
		navigation,
		10.0,
		false,
		int(enemy["steer_side"])
	)
	assert_gt(navigation.cross(second), 0.0, "small position changes must not flip the chosen side")


func test_full_character_sheets_map_complete_rows_for_runtime_units() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.enemy_data = GameData.get_enemies()
	for enemy_id in field.enemy_data:
		var enemy: Dictionary = field.enemy_data[enemy_id] as Dictionary
		field.enemy_sprite_frames[enemy_id] = field._materialize_sprite_frames(SpriteSheetFrames.path_row(
			str(enemy.get("sprite_sheet", "")),
			int(enemy.get("sprite_columns", 8)),
			int(enemy.get("sprite_rows", 1)),
			int(enemy.get("sprite_row", 0))
		))
		var frames: Array = field.enemy_sprite_frames.get(str(enemy_id), []) as Array
		var sprite_sheet := str(enemy.get("sprite_sheet", ""))
		var sprite_columns := int(enemy.get("sprite_columns", 0))
		var sprite_rows := int(enemy.get("sprite_rows", 0))
		var sprite_row := int(enemy.get("sprite_row", -1))
		var expected_frames := int(enemy.get("sprite_frames", 0))
		assert_eq(frames.size(), expected_frames, "%s uses all declared walk frames" % enemy_id)
		assert_eq(sprite_columns, 8, "%s is an eight-column categorized atlas" % enemy_id)
		assert_gte(sprite_row, 0, "%s row must be declared" % enemy_id)
		assert_lt(sprite_row, sprite_rows, "%s row must fit its atlas" % enemy_id)
		var source := ResourceLoader.load(sprite_sheet) as Texture2D
		var source_image := source.get_image() if source != null else null
		for frame_index in range(frames.size()):
			var frame := frames[frame_index] as Texture2D
			assert_not_null(frame, "%s frame %d must be a materialized texture" % [enemy_id, frame_index])
			if frame == null or source_image == null:
				continue
			assert_eq(frame.get_size(), Vector2(128, 128), "%s frame %d has cell dimensions" % [enemy_id, frame_index])
			var expected := source_image.get_region(Rect2i(frame_index * 128, sprite_row * 128, 128, 128))
			assert_eq(frame.get_image().get_data(), expected.get_data(), "%s frame %d contains only its declared atlas cell" % [enemy_id, frame_index])
		assert_true(str(enemy.get("sprite_sheet", "")).begins_with("res://assets/units/full_sheets/"))
		assert_false(enemy.has("attack_sheet"), "%s must not switch to a different character atlas while attacking" % enemy_id)
		var index := field.spawn_enemy_at(str(enemy_id), Vector2(180.0 + field.enemies.size() * 10.0, 180.0))
		assert_gte(index, 0)
		if index >= 0:
			var attack_frames: Array = field.enemies[index].get("attack_frames", []) as Array
			assert_eq(attack_frames.size(), 8)
			assert_eq(attack_frames, frames, "%s keeps its own full-character frames during attacks" % enemy_id)


func test_players_and_allies_use_full_character_frames_without_rig_assembly() -> void:
	var player: Dictionary = GameData.get_characters()["wanglu"] as Dictionary
	var frames := SpriteSheetFrames.path_row(
		str(player.get("sprite_sheet", "")),
		int(player.get("sprite_columns", 8)),
		int(player.get("sprite_rows", 3)),
		int(player.get("sprite_row", 0))
	)
	assert_eq(frames.size(), 8)
	assert_eq((frames[0] as AtlasTexture).region.size, Vector2(128, 128))
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(20261127)
	assert_true(field.spawn_ally("yishi_spear", Vector2(180, 180)))
	assert_eq((field.allies[0].get("walk_frames", []) as Array).size(), 8)
	assert_eq((field.allies[0].get("attack_frames", []) as Array).size(), 8)
	assert_false(field.allies[0].has("runtime_rig"))


func test_player_attack_frames_match_walk_visual_height_and_keep_foot_anchor() -> void:
	var definition: Dictionary = GameData.get_characters()["wanglu"] as Dictionary
	var field := Battlefield.new()
	add_child_autofree(field)
	field.set_player_sprites(definition)
	assert_gt(field.player_attack_scale, 1.0)
	assert_lt(field.player_attack_scale, 1.4)
	var walk_height := field._average_visible_frame_height(field.player_walk_frames)
	var attack_height := field._average_visible_frame_height(field.player_attack_frames)
	assert_almost_eq(
		attack_height * field.player_attack_scale / walk_height,
		0.95,
		0.025,
		"uniform scaling should preserve a slight attack crouch"
	)
	var walk_rect := field.player_frame_draw_rect(false)
	var attack_rect := field.player_frame_draw_rect(true)
	var walk_draw_bottom := walk_rect.position.y + 124.0 / 128.0 * walk_rect.size.y
	var attack_draw_bottom := attack_rect.position.y + 124.0 / 128.0 * attack_rect.size.y
	assert_almost_eq(attack_draw_bottom, walk_draw_bottom, 0.0001, "attack and walk share the same foot baseline")


func test_debug_capture_resets_scene_before_spawning_repeatable_enemy_ring() -> void:
	var run := preload("res://scenes/run.tscn").instantiate()
	add_child_autofree(run)
	var first: Dictionary = run.debug_prepare_capture("tower")
	assert_eq(first.get("enemies"), 44)
	assert_eq(first.get("towers"), 3)
	var second: Dictionary = run.debug_prepare_capture("tower")
	assert_eq(second.get("enemies"), 44, "repeat captures must clear the previous enemy ring")
	assert_eq(second.get("towers"), 3, "repeat captures must clear the previous towers")
