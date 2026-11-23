extends GutTest

const INDEX_PATH := "res://data/yongchang_tiles.json"
const ACTOR_PATH := "res://data/actors.json"


func test_tile_atlases_match_declared_grid() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	assert_not_null(parsed, "tile index must parse")
	if parsed == null:
		return
	var tile_size: int = parsed["tile_size"]
	for key: String in ["terrain", "architecture", "props"]:
		var atlas: Dictionary = parsed["atlases"][key]
		var texture := load(atlas["path"]) as Texture2D
		assert_not_null(texture, "%s atlas must load" % key)
		if texture == null:
			continue
		assert_eq(texture.get_width(), int(atlas["columns"]) * tile_size, "%s width" % key)
		assert_eq(texture.get_height(), int(atlas["rows"]) * tile_size, "%s height" % key)
		assert_eq(
			(atlas["tiles"] as Array).size(),
			int(atlas["columns"]) * int(atlas["rows"]),
			"%s tile names" % key
		)


func test_preview_scene_builds_three_tile_layers() -> void:
	var scene := load("res://scenes/tile_preview.tscn") as PackedScene
	assert_not_null(scene, "tile preview scene must load")
	if scene == null:
		return
	var preview := scene.instantiate()
	add_child_autofree(preview)
	await get_tree().process_frame
	var layers := 0
	for child in preview.get_children():
		if child is TileMapLayer:
			layers += 1
			assert_not_null((child as TileMapLayer).tile_set, "layer must have a tile set")
	assert_eq(layers, 3, "terrain, architecture, and props layers")


func test_actor_atlases_match_declared_grid() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ACTOR_PATH))
	assert_not_null(parsed, "actor index must parse")
	if parsed == null:
		return
	var atlas: Dictionary = parsed["wokou_atlas"]
	var wokou_texture := load(atlas["path"]) as Texture2D
	assert_not_null(wokou_texture, "wokou atlas must load")
	if wokou_texture != null:
		assert_eq(int(atlas["cell"]), 128, "wokou frame cell is 128")
		assert_eq(
			wokou_texture.get_width(),
			int(atlas["columns"]) * int(atlas["cell"]),
			"wokou atlas width"
		)
		assert_eq(
			wokou_texture.get_height(),
			int(atlas["rows"]) * int(atlas["cell"]),
			"wokou atlas height"
		)
	var hero: Dictionary = parsed["hero"]
	var hero_texture := load(hero["path"]) as Texture2D
	assert_not_null(hero_texture, "hero strip must load")
	if hero_texture != null:
		assert_eq(int(hero["cell"]), 128, "hero frame cell is 128")
		assert_eq(
			hero_texture.get_width(),
			int(hero["cell"]) * int(hero["frame_count"]),
			"hero strip width"
		)
		assert_eq(hero_texture.get_height(), int(hero["cell"]), "hero strip height")
	var types: Array = parsed["wokou"]
	assert_eq(types.size(), 16, "sixteen wokou types")
	var seen := {}
	for entry: Dictionary in types:
		var row: int = int(entry["row"])
		assert_false(seen.has(row), "row %d must be unique" % row)
		seen[row] = true
	assert_eq(seen.size(), 16, "all sixteen rows are used")
	var clips: Dictionary = atlas["clips"]
	assert_eq((clips["idle"] as Array).size(), 2, "idle clip")
	assert_eq((clips["walk"] as Array).size(), 8, "walk clip")
	assert_eq((clips["attack"] as Array).size(), 6, "attack clip")


func test_animated_props_match_declared_grid() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	assert_not_null(parsed, "tile index must parse")
	if parsed == null:
		return
	var animated: Dictionary = parsed["atlases"]["animated_props"]
	var texture := load(str(animated["path"])) as Texture2D
	assert_not_null(texture, "animated props atlas must load")
	if texture != null:
		assert_eq(
			texture.get_width(),
			int(animated["columns"]) * int(animated["cell"]),
			"animated props width"
		)
		assert_eq(
			texture.get_height(),
			int(animated["rows"]) * int(animated["cell"]),
			"animated props height"
		)
	var clips: Dictionary = animated["clips"]
	assert_eq(clips.size(), 4, "lantern, boat, banner, and beacon clips")
	var placements: Array = animated["placements"]
	assert_eq(placements.size(), 7, "seven animated map placements")
	for placement: Dictionary in placements:
		assert_true(clips.has(str(placement["clip"])), "placement clip must exist")


func test_actors_preview_scene_loads() -> void:
	var scene := load("res://scenes/actors_preview.tscn") as PackedScene
	assert_not_null(scene, "actors preview scene must load")
