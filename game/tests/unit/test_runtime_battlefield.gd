extends GutTest

const CELL := 128


func test_enemy_caps_keep_desktop_design_and_limit_mobile_web_crowds() -> void:
	assert_eq(Battlefield.enemy_cap_for_platform(false, false), 460)
	assert_eq(Battlefield.enemy_cap_for_platform(true, false), 180)
	assert_eq(Battlefield.enemy_cap_for_platform(true, true), 120)


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
			field.enemy_sprite_frames.has(draw_id)
				or (field.enemy_variant_atlas_data.get("variants", {}) as Dictionary).has(draw_id),
			"%s must resolve to a runtime sprite or atlas cell" % draw_id
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
			assert_true(
				field.enemy_sprite_frames.has(draw_id)
					or (field.enemy_variant_atlas_data.get("variants", {}) as Dictionary).has(draw_id)
			)
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
		assert_true(
			(field.enemy_variant_atlas_data.get("variants", {}) as Dictionary).has(draw_id),
			"%s must resolve through the shared animation atlas" % draw_id
		)
		seen[draw_id] = true
	assert_gte(seen.size(), 6, "spawns must sample a wide set of equipment combinations")
	# 全部烘焙变体都允许出现；绘制仍按 draw_id 分批。
	assert_lte(seen.size(), 12, "the baked foot variant pool is capped at 12 looks")


func test_enemy_variant_atlas_covers_all_frames_and_uses_isolated_canvas_batches() -> void:
	var atlas_data := GameData.load_json("res://data/enemy_variant_atlas.json")
	var variants: Dictionary = atlas_data.get("variants", {}) as Dictionary
	assert_eq(int(atlas_data.get("variant_count", 0)), 144)
	assert_eq(variants.size(), 144)
	assert_eq(int(atlas_data.get("frames", 0)), 8)
	assert_eq(int(atlas_data.get("columns", 0)), 36)
	assert_eq(int(atlas_data.get("rows", 0)), 32)
	var unique_cells := {}
	for draw_id in variants:
		var entry: Dictionary = variants[draw_id] as Dictionary
		var first_cell := int(entry.get("first_cell", -1))
		assert_gte(first_cell, 0, "%s must have a first atlas cell" % draw_id)
		assert_eq(first_cell % 8, 0, "%s must start on an eight-frame strip" % draw_id)
		assert_eq(int(entry.get("frames", 0)), 8)
		for cell in range(first_cell, first_cell + 8):
			assert_false(unique_cells.has(cell), "%s must not overlap another variant" % draw_id)
			unique_cells[cell] = true
	assert_eq(unique_cells.size(), 144 * 8)

	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(20261127)
	assert_not_null(field.enemy_atlas_batch)
	assert_not_null(field.enemy_variant_atlas_texture)
	assert_eq(field.enemy_variant_atlas_texture.get_size(), Vector2(4608, 4096))
	assert_true(field.enemy_atlas_batch.body_batch.multimesh.use_custom_data)
	assert_true(field.enemy_atlas_batch.shadow_batch.multimesh.use_custom_data)
	assert_not_null(field.enemy_atlas_batch.body_batch.material)
	assert_eq(field.material, null, "atlas shader must not affect Battlefield drawing")
