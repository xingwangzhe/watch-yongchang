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
			assert_true(ResourceLoader.exists(str(actor.get("attack_sheet", ""))))
			assert_false(actor.has("runtime_visuals"), "%s must not select legacy baked variants" % actor_id)
