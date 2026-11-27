extends GutTest

const CELL := 128


func test_enemy_caps_keep_desktop_design_and_limit_mobile_web_crowds() -> void:
	assert_eq(Battlefield.enemy_cap_for_platform(false, false), 460)
	assert_eq(Battlefield.enemy_cap_for_platform(true, false), 180)
	assert_eq(Battlefield.enemy_cap_for_platform(true, true), 120)


func test_full_character_sheets_map_complete_rows_for_runtime_units() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(20261127)
	for enemy_id in GameData.get_enemies():
		var enemy: Dictionary = GameData.get_enemies()[enemy_id] as Dictionary
		var frames: Array = field.enemy_sprite_frames.get(str(enemy_id), []) as Array
		assert_eq(frames.size(), 8, "%s uses eight complete walk frames" % enemy_id)
		assert_true(str(enemy.get("sprite_sheet", "")).begins_with("res://assets/units/full_sheets/"))
		assert_true(ResourceLoader.exists(str(enemy.get("attack_sheet", ""))))
		var index := field.spawn_enemy_at(str(enemy_id), Vector2(180.0 + field.enemies.size() * 10.0, 180.0))
		assert_gte(index, 0)
		if index >= 0:
			assert_eq((field.enemies[index].get("attack_frames", []) as Array).size(), 8)


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
