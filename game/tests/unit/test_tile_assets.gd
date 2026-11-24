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


func test_passability_tiles_exist_and_read_as_distinct_surfaces() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	assert_not_null(parsed, "tile index must parse")
	if parsed == null:
		return
	var terrain: Dictionary = parsed["atlases"]["terrain"]
	var architecture: Dictionary = parsed["atlases"]["architecture"]
	var terrain_names: Array = terrain["tiles"]
	var architecture_names: Array = architecture["tiles"]
	for tile_name in ["water_shallow_a", "water_shallow_b", "water_deep_a", "water_deep_b"]:
		assert_true(terrain_names.has(tile_name), "terrain atlas must expose %s" % tile_name)
	for tile_name in ["dock_horizontal", "dock_vertical"]:
		assert_true(terrain_names.has(tile_name), "terrain atlas must expose %s" % tile_name)
	for tile_name in ["mountain_a", "mountain_b", "mountain_c", "mountain_d", "mountain_e", "mountain_f", "mountain_g", "mountain_h"]:
		assert_true(terrain_names.has(tile_name), "terrain atlas must expose %s" % tile_name)
	for tile_name in ["wood_railing", "wood_railing_vertical"]:
		assert_true(architecture_names.has(tile_name), "architecture atlas must expose %s" % tile_name)
	var water := _tile_image(parsed, "terrain", "water_shallow_a")
	var mountain := _tile_image(parsed, "terrain", "mountain_a")
	assert_not_null(water, "shallow water tile must load")
	assert_not_null(mountain, "mountain tile must load")
	if water == null or mountain == null:
		return
	var water_blue_pixels := 0
	var water_palette := {}
	for y in 32:
		for x in 32:
			var water_color := water.get_pixel(x, y)
			water_palette[water_color] = true
			if water_color.b > water_color.r + 0.1:
				water_blue_pixels += 1
	var mountain_water_palette_pixels := 0
	for y in 32:
		for x in 32:
			if water_palette.has(mountain.get_pixel(x, y)):
				mountain_water_palette_pixels += 1
	assert_gt(water_blue_pixels, 500, "water must read as a blue-green passable surface")
	assert_eq(mountain_water_palette_pixels, 0, "mountain rock must not reuse the water palette")
	assert_eq(mountain.get_pixel(0, 31).a, 1.0, "mountain must be opaque through its blocked footprint")


func test_bridge_decks_and_railings_have_continuous_joining_edges() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	assert_not_null(parsed, "tile index must parse")
	if parsed == null:
		return
	var horizontal_deck := _tile_image(parsed, "terrain", "dock_horizontal")
	var vertical_deck := _tile_image(parsed, "terrain", "dock_vertical")
	var horizontal_railing := _tile_image(parsed, "architecture", "wood_railing")
	var vertical_railing := _tile_image(parsed, "architecture", "wood_railing_vertical")
	for image: Image in [horizontal_deck, vertical_deck, horizontal_railing, vertical_railing]:
		assert_not_null(image, "bridge tile must load")
	if horizontal_deck == null or vertical_deck == null or horizontal_railing == null or vertical_railing == null:
		return
	for y in 32:
		assert_eq(horizontal_deck.get_pixel(0, y), horizontal_deck.get_pixel(31, y), "horizontal deck west/east seam")
		var west := horizontal_railing.get_pixel(0, y)
		var east := horizontal_railing.get_pixel(31, y)
		assert_eq(west.a, east.a, "horizontal railing west/east coverage seam")
		if west.a > 0.0:
			assert_eq(west, east, "horizontal railing west/east visible seam")
	for x in 32:
		assert_eq(vertical_deck.get_pixel(x, 0), vertical_deck.get_pixel(x, 31), "vertical deck north/south seam")
		var north := vertical_railing.get_pixel(x, 0)
		var south := vertical_railing.get_pixel(x, 31)
		assert_eq(north.a, south.a, "vertical railing north/south coverage seam")
		if north.a > 0.0:
			assert_eq(north, south, "vertical railing north/south visible seam")
	assert_ne(horizontal_railing.get_pixel(16, 9), vertical_railing.get_pixel(16, 9), "railing orientations must use distinct art")


func test_preview_scene_builds_three_tile_layers() -> void:
	var scene := load("res://scenes/tile_preview.tscn") as PackedScene
	assert_not_null(scene, "tile preview scene must load")
	if scene == null:
		return
	var preview := scene.instantiate()
	add_child_autofree(preview)
	await get_tree().process_frame
	var layers := 0
	var terrain_layer: TileMapLayer
	for child in preview.get_children():
		if child is TileMapLayer:
			layers += 1
			assert_not_null((child as TileMapLayer).tile_set, "layer must have a tile set")
			if (child as TileMapLayer).z_index == -10:
				terrain_layer = child as TileMapLayer
	assert_eq(layers, 3, "terrain, architecture, and props layers")
	assert_not_null(terrain_layer, "preview must expose its terrain layer")
	if terrain_layer != null:
		assert_eq(terrain_layer.get_cell_atlas_coords(Vector2i(13, 8)).y, 4, "preview must include the fifth terrain row")


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


func _tile_image(parsed: Dictionary, atlas_key: String, tile_name: String) -> Image:
	var atlas: Dictionary = parsed["atlases"][atlas_key]
	var names: Array = atlas["tiles"]
	var index := names.find(tile_name)
	if index < 0:
		return null
	var texture := load(str(atlas["path"])) as Texture2D
	if texture == null:
		return null
	var source := texture.get_image()
	if source == null:
		return null
	var tile_size := int(parsed["tile_size"])
	var columns := int(atlas["columns"])
	var cell := Vector2i(index % columns, index / columns) * tile_size
	var image := Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
	image.blit_rect(source, Rect2i(cell, Vector2i.ONE * tile_size), Vector2i.ZERO)
	return image
