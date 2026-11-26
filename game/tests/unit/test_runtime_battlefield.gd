extends GutTest

const CELL := 128


func test_cavalry_enemy_rolls_melee_and_ranged_forge_variants() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(20261126)
	assert_not_null(field.runtime_loadout, "battlefield must configure the runtime loadout once")
	var seen_melee := false
	var seen_ranged := false
	var seen_visual_keys := {}
	for index in 32:
		field.rng.seed = 9100 + index
		var enemy_index := field.spawn_enemy_at(
			"cavalry",
			Vector2(180.0 + float(index % 8) * 34.0, 160.0 + float(index / 8) * 34.0)
		)
		assert_gte(enemy_index, 0)
		if enemy_index < 0:
			continue
		var enemy: Dictionary = field.enemies[enemy_index]
		var loadout: Dictionary = enemy.get("runtime_loadout", {}) as Dictionary
		assert_false(loadout.is_empty(), "every spawn needs a generated loadout snapshot")
		assert_eq(str(enemy.get("runtime_role", "")), "cavalry")
		assert_eq(field.runtime_loadout.validation_errors(loadout).size(), 0)
		var attack_class := str(enemy.get("runtime_attack_class", ""))
		var draw_id := str(enemy.get("draw_id", ""))
		seen_visual_keys[str(enemy.get("runtime_visual_key", ""))] = true
		if attack_class == "ranged":
			seen_ranged = true
			assert_true(
				draw_id.begins_with("cavalry_") or draw_id == "wokou_black_bow",
				"riders must use a mounted ranged visual"
			)
			assert_eq(str(enemy.get("behavior", "")), "ranged")
		else:
			seen_melee = true
			assert_true(
				draw_id.begins_with("cavalry_") or draw_id == "wokou_grey_saber",
				"riders must use a mounted melee visual"
			)
			assert_eq(str(enemy.get("behavior", "")), "chase")
		assert_true(
			field.enemy_sprite_frames.has(draw_id),
			"%s must be cached before it reaches the draw loop" % draw_id
		)
	assert_true(seen_melee, "the run must produce saber riders")
	assert_true(seen_ranged, "the run must produce horse archers")
	assert_gt(seen_visual_keys.size(), 20, "runtime styles must not collapse into one preset")


func test_elite_and_boss_runtime_roles_select_mounted_visuals() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(20261126)
	var enemies := GameData.get_enemies()
	for enemy_id in ["general", "daimyo"]:
		var definition: Dictionary = enemies[enemy_id] as Dictionary
		var seen_mounted := false
		var seen_ranged := false
		for index in 72:
			field.rng.seed = 12000 + index + enemy_id.hash()
			var loadout := field._generate_runtime_loadout(enemy_id, definition)
			assert_false(loadout.is_empty())
			assert_eq(field.runtime_loadout.validation_errors(loadout).size(), 0)
			var visual := field._runtime_visual_for(definition, loadout)
			if str(loadout.get("role", "")) != "cavalry":
				continue
			seen_mounted = true
			var draw_id := str(visual.get("draw_id", ""))
			assert_true(field.enemy_sprite_frames.has(draw_id))
			if str(loadout.get("attack_class", "")) == "ranged":
				seen_ranged = true
				assert_eq(draw_id, "wokou_black_bow")
				assert_eq(str(visual.get("behavior", "")), "ranged")
			else:
				assert_true(draw_id in ["wokou_black_lancer", "wokou_oni_lancer"])
		assert_true(seen_mounted, "%s must be able to roll a mounted loadout" % enemy_id)
		if enemy_id == "daimyo":
			assert_true(seen_ranged, "the boss must also be able to roll a mounted ranged loadout")


func test_runtime_visual_strips_are_forge_baked() -> void:
	var templates := GameData.load_json("res://data/character_templates.json")
	var cavalry_recipes: Array = templates.get("cavalry_recipes", []) as Array
	var by_id := {}
	for raw_recipe: Variant in cavalry_recipes:
		var recipe: Dictionary = raw_recipe
		by_id[str(recipe.get("id", ""))] = recipe
	for draw_id in ["wokou_black_bow", "wokou_black_lancer", "wokou_oni_lancer"]:
		assert_true(by_id.has(draw_id), "%s must be a CharacterForge cavalry recipe" % draw_id)
		var recipe: Dictionary = by_id[draw_id] as Dictionary
		assert_eq(str(recipe.get("faction", "")), "wokou")
		for clip in ["idle", "walk"]:
			var path := str(recipe.get("battle_%s" % clip, ""))
			assert_true(ResourceLoader.exists(path), "%s %s missing" % [draw_id, clip])
			var texture := load(path) as Texture2D
			assert_not_null(texture)
			if texture != null:
				var frames := int(recipe.get("battle_%s_frames" % clip, 0))
				assert_eq(texture.get_width(), frames * CELL)
				assert_eq(texture.get_height(), CELL)



func test_foot_enemy_spawns_sample_multiple_bounded_variants() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(20261126)
	var seen := {}
	for index in 24:
		field.rng.seed = 4200 + index
		var enemy_index := field.spawn_enemy_at(
			"scout",
			Vector2(100.0 + float(index % 8) * 22.0, 100.0 + float(index / 8) * 22.0)
		)
		assert_gte(enemy_index, 0)
		if enemy_index < 0:
			continue
		var enemy: Dictionary = field.enemies[enemy_index]
		var draw_id := str(enemy.get("draw_id", ""))
		assert_true(draw_id.begins_with("scout_foot_"), "foot spawns must use baked variants")
		assert_true(field.enemy_sprite_frames.has(draw_id), "%s must be cached" % draw_id)
		seen[draw_id] = true
	assert_gte(seen.size(), 6, "spawns must sample a wide set of equipment combinations")
	# 全部烘焙变体都允许出现；绘制仍按 draw_id 分批，无需把视觉池锁死为 4 个。
	assert_lte(seen.size(), 12, "the baked foot variant pool is capped at 12 looks")
