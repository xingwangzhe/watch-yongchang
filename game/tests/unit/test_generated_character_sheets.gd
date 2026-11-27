extends GutTest


func test_complete_character_atlases_have_eight_128px_frames_per_row() -> void:
	var sheets := {
		"player_actions": Vector2i(8, 3),
		"allies_walk": Vector2i(8, 4),
		"enemies_walk": Vector2i(8, 5),
		"cavalry_walk": Vector2i(8, 4),
		"unit_attacks": Vector2i(8, 8),
	}
	for sheet_id in sheets:
		var path := "res://assets/units/full_sheets/%s.webp" % sheet_id
		var texture := ResourceLoader.load(path) as Texture2D
		assert_not_null(texture, "%s atlas must load" % sheet_id)
		if texture == null:
			continue
		var layout: Vector2i = sheets[sheet_id]
		assert_eq(texture.get_size(), Vector2(layout.x * 128, layout.y * 128))
		for row in layout.y:
			var frames := SpriteSheetFrames.path_row(path, layout.x, layout.y, row)
			assert_eq(frames.size(), 8, "%s row %d has eight complete frames" % [sheet_id, row])
			for frame in frames:
				assert_eq((frame as AtlasTexture).region.size, Vector2(128, 128))


func test_actor_catalogs_point_only_to_complete_character_atlases() -> void:
	for path in ["res://data/characters.json", "res://data/enemies.json", "res://data/mercenaries.json"]:
		var root: Dictionary = GameData.load_json(path)
		var key := "characters" if path.ends_with("characters.json") else ("enemies" if path.ends_with("enemies.json") else "mercenaries")
		for actor_id in (root.get(key, {}) as Dictionary):
			var actor: Dictionary = root[key][actor_id] as Dictionary
			assert_true(str(actor.get("sprite_sheet", "")).begins_with("res://assets/units/full_sheets/"))
			assert_eq(int(actor.get("sprite_columns", 0)), 8)
			assert_gte(int(actor.get("sprite_rows", 0)), 3)
			if path.ends_with("enemies.json"):
				assert_false(actor.has("attack_sheet"), "%s must keep its enemy identity in every attack frame" % actor_id)
			else:
				assert_true(ResourceLoader.exists(str(actor.get("attack_sheet", ""))))
			assert_false(actor.has("runtime_visuals"), "%s must not select legacy baked variants" % actor_id)


func test_player_attack_pose_matches_starting_weapon_family() -> void:
	var characters: Dictionary = GameData.get_characters()
	for character_id in ["wanglu", "ashi"]:
		var character: Dictionary = characters[character_id] as Dictionary
		assert_eq(str(character.get("starting_weapon", "")), "saber")
		assert_eq(int(character.get("attack_row", -1)), 1, "%s saber attack must use the dao slash row" % character_id)
	var spear_character: Dictionary = characters["aqi"] as Dictionary
	assert_eq(str(spear_character.get("starting_weapon", "")), "spear")
	assert_eq(int(spear_character.get("attack_row", -1)), 2, "spear post must use the spear thrust row")


func test_runtime_sprite_mass_anchor_stays_stable_across_each_animation_row() -> void:
	var sheets := {
		"player_actions": Vector2i(8, 3),
		"allies_walk": Vector2i(8, 4),
		"enemies_walk": Vector2i(8, 5),
		"cavalry_walk": Vector2i(8, 4),
		"unit_attacks": Vector2i(8, 8),
	}
	for sheet_id in sheets:
		var path := "res://assets/units/full_sheets/%s.webp" % sheet_id
		var texture := ResourceLoader.load(path) as Texture2D
		assert_not_null(texture, "%s atlas must load for mass-anchor checks" % sheet_id)
		if texture == null:
			continue
		var image := texture.get_image()
		assert_not_null(image, "%s atlas image must load" % sheet_id)
		if image == null:
			continue
		var anchors := _row_mass_anchors(image, sheets[sheet_id])
		for row in anchors.size():
			var row_anchors: Array = anchors[row]
			assert_eq(row_anchors.size(), 8)
			var min_anchor := float(row_anchors[0])
			var max_anchor := min_anchor
			for anchor in row_anchors:
				min_anchor = minf(min_anchor, float(anchor))
				max_anchor = maxf(max_anchor, float(anchor))
				assert_almost_eq(float(anchor), 64.0, 1.5, "%s row %d mass center must remain centered" % [sheet_id, row])
			assert_lte(max_anchor - min_anchor, 1.5, "%s row %d mass center must not drift between frames" % [sheet_id, row])


func _row_mass_anchors(image: Image, sheet_size: Vector2i) -> Array:
	var rows: Array = []
	var data := image.get_data()
	var image_width := image.get_width()
	for row in sheet_size.y:
		var row_anchors: Array[float] = []
		for column in sheet_size.x:
			var histogram := PackedInt32Array()
			histogram.resize(128)
			var total_mass := 0
			for y in range(row * 128, (row + 1) * 128):
				for x in range(column * 128, (column + 1) * 128):
					var alpha := int(data[(y * image_width + x) * 4 + 3])
					if alpha >= 24:
						histogram[x - column * 128] += alpha
					total_mass += alpha if alpha >= 24 else 0
			var half_mass := float(total_mass) * 0.5
			var accumulated := 0
			var anchor := 64.0
			for x in histogram.size():
				accumulated += histogram[x]
				if accumulated >= half_mass:
					anchor = float(x) + 0.5
					break
			row_anchors.append(anchor)
		rows.append(row_anchors)
	return rows
