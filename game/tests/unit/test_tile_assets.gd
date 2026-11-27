extends GutTest

const INDEX_PATH := "res://data/yongchang_tiles.json"
const WATER_MAP_IDS := ["tideland", "watergate", "crossstreet"]
const WATER_COMPONENT_MIN_CELLS := 16


func test_map_layers_share_tileset_and_resolve_atlas_cells() -> void:
	var maps := GameData.get_maps()
	var definition := (maps["tideland"] as Dictionary).duplicate(true)
	var layout := MapLayout.new()
	layout.setup("tideland", definition)
	var renderer := MapRenderer.new()
	add_child_autofree(renderer)
	renderer.build(layout, definition, 20261126)

	var shared_tile_set := renderer.terrain_layer.tile_set
	assert_not_null(shared_tile_set, "map layers must have a TileSet")
	assert_eq(renderer.architecture_layer.tile_set, shared_tile_set, "architecture shares TileSet")
	assert_eq(renderer.props_layer.tile_set, shared_tile_set, "props share TileSet")
	assert_eq(renderer.canopy_layer.tile_set, shared_tile_set, "canopy shares TileSet")
	assert_true(shared_tile_set.get_source_count() >= 4, "TileSet keeps separate atlas sources")

	var terrain_cells := renderer.terrain_layer.get_used_cells()
	var architecture_cells := renderer.architecture_layer.get_used_cells()
	assert_gt(terrain_cells.size(), 0, "map terrain is composed from atlas cells")
	assert_gt(architecture_cells.size(), 0, "map buildings are composed from atlas cells")
	if not terrain_cells.is_empty():
		assert_not_null(
			renderer.terrain_layer.get_cell_tile_data(terrain_cells[0]),
			"terrain atlas coordinates resolve to tile data"
		)
	if not architecture_cells.is_empty():
		assert_not_null(
			renderer.architecture_layer.get_cell_tile_data(architecture_cells[0]),
			"architecture atlas coordinates resolve to tile data"
		)


func test_runtime_water_cells_use_declared_water_atlas_regions() -> void:
	for map_id in WATER_MAP_IDS:
		var definition := (GameData.get_maps()[map_id] as Dictionary).duplicate(true)
		var layout := MapLayout.new()
		layout.setup(map_id, definition)
		var renderer := MapRenderer.new()
		add_child_autofree(renderer)
		renderer.build(layout, definition, 20261127)
		var tile_set: TileSet = renderer.terrain_layer.tile_set
		var terrain_source_id := int(renderer._source_ids["terrain"])
		var terrain_source := tile_set.get_source(terrain_source_id) as TileSetAtlasSource
		assert_not_null(terrain_source, "%s water cells must use terrain atlas source" % map_id)
		if terrain_source == null:
			continue
		assert_eq(terrain_source.texture_region_size, Vector2i(32, 32), "terrain cell region is 32px")
		assert_eq(terrain_source.texture.get_width(), 256, "terrain atlas imported width")
		assert_eq(terrain_source.texture.get_height(), 160, "terrain atlas imported height")
		var imported_image := terrain_source.texture.get_image()
		var source_image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/tiles/full_sheets/terrain_atlas.png"))
		assert_false(source_image.is_empty(), "terrain source PNG must load")
		assert_eq(imported_image.get_data(), source_image.get_data(), "imported terrain pixels must match the source PNG")
		var terrain_names: Array = (GameData.load_json(INDEX_PATH)["atlases"]["terrain"]["tiles"] as Array)
		var water_count := 0
		for cell in renderer.terrain_layer.get_used_cells():
			if not layout.is_water_cell(cell) or layout.is_bridge_cell(cell) or layout.is_solid_cell(cell):
				continue
			water_count += 1
			var source_id := renderer.terrain_layer.get_cell_source_id(cell)
			var coords := renderer.terrain_layer.get_cell_atlas_coords(cell)
			var tile_index := coords.y * 8 + coords.x
			var tile_name := str(terrain_names[tile_index]) if tile_index >= 0 and tile_index < terrain_names.size() else "<out-of-range>"
			assert_eq(source_id, terrain_source_id, "%s water cell must use terrain atlas source at %s" % [map_id, cell])
			assert_true(
				tile_name in ["water_shallow_a", "water_shallow_b", "water_deep_a", "water_deep_b", "shore_n", "shore_s", "shore_e", "shore_w", "shore_nw", "shore_ne", "shore_sw", "shore_se"],
				"%s water cell %s resolved to %s at atlas %s" % [map_id, cell, tile_name, coords]
			)
		assert_gt(water_count, 0, "%s must render water cells" % map_id)


func test_tile_atlases_match_declared_grid() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	assert_not_null(parsed, "tile index must parse")
	if parsed == null:
		return
	var tile_size: int = parsed["tile_size"]
	for key: String in ["terrain", "architecture", "props"]:
		var atlas: Dictionary = parsed["atlases"][key]
		if key == "architecture":
			assert_eq(
				atlas.get("path", ""),
				"res://assets/tiles/full_sheets/architecture_atlas.png",
				"architecture must use the complete category atlas"
			)
			assert_false(atlas.has("generated_source"), "obsolete layered tile overrides are removed")
			assert_false(atlas.has("generated_overrides"), "obsolete layered tile overrides are removed")
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
	for tile_name in ["water_shallow_b", "water_deep_a", "water_deep_b"]:
		var water_variant := _tile_image(parsed, "terrain", tile_name)
		assert_not_null(water_variant, "%s must load" % tile_name)
		if water_variant == null:
			continue
		var blue_pixels := 0
		for y in 32:
			for x in 32:
				var color := water_variant.get_pixel(x, y)
				if color.b > color.r + 0.1:
					blue_pixels += 1
		assert_gt(blue_pixels, 500, "%s must crop a blue-green water cell, not a bank or ground cell" % tile_name)
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


func test_water_networks_are_continuous_with_finished_shorelines() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	assert_not_null(parsed, "tile index must parse")
	if parsed == null:
		return
	var maps := GameData.get_maps()
	for map_id in WATER_MAP_IDS:
		var definition: Dictionary = (maps[map_id] as Dictionary).duplicate(true)
		var layout := MapLayout.new()
		layout.setup(map_id, definition)
		var renderer := MapRenderer.new()
		renderer.name = "WaterMapRenderer_%s" % map_id
		add_child_autofree(renderer)
		renderer.build(layout, definition, 20261123)
		_assert_water_network(map_id, layout, renderer)
		if not OS.get_environment("WATER_DEBUG").is_empty():
			var used_counts := {}
			var shore_cells := 0
			var shore_on_water := 0
			for cell in renderer.terrain_layer.get_used_cells():
				var tile_name := renderer.terrain_tile_name(cell)
				used_counts[tile_name] = int(used_counts.get(tile_name, 0)) + 1
				if tile_name.begins_with("shore_"):
					shore_cells += 1
					if layout.is_water_cell(cell):
						shore_on_water += 1
			print("TERRAIN_USED %s shore=%d shore_on_water=%d names=%s" % [map_id, shore_cells, shore_on_water, used_counts])
		_maybe_save_water_preview(map_id, layout, renderer, parsed)


func test_directional_bank_names_match_the_land_side() -> void:
	var cases := [
		{"directions": [Vector2i.UP], "expected": "shore_n"},
		{"directions": [Vector2i.DOWN], "expected": "shore_s"},
		{"directions": [Vector2i.LEFT], "expected": "shore_w"},
		{"directions": [Vector2i.RIGHT], "expected": "shore_e"},
		{"directions": [Vector2i.UP, Vector2i.LEFT], "expected": "shore_nw"},
		{"directions": [Vector2i.UP, Vector2i.RIGHT], "expected": "shore_ne"},
		{"directions": [Vector2i.DOWN, Vector2i.LEFT], "expected": "shore_sw"},
		{"directions": [Vector2i.DOWN, Vector2i.RIGHT], "expected": "shore_se"},
	]
	var renderer := MapRenderer.new()
	add_child_autofree(renderer)
	for item in cases:
		var directions: Array[Vector2i] = []
		for direction in item["directions"]:
			directions.append(direction as Vector2i)
		assert_eq(
			renderer._shore_tile_for(directions),
			item["expected"],
			"bank texture direction must match adjacent land: %s" % item
		)


func test_map_builds_place_complete_roof_sprites_and_directional_shorelines() -> void:
	var maps := GameData.get_maps()
	for map_id in maps:
		var definition := (maps[map_id] as Dictionary).duplicate(true)
		var layout := MapLayout.new()
		layout.setup(str(map_id), definition)
		var renderer := MapRenderer.new()
		renderer.name = "BuildValidation_%s" % map_id
		add_child_autofree(renderer)
		renderer.build(layout, definition, 20261128)
		var expected_roofs := 0
		for area in layout.areas:
			if area is Dictionary and str((area as Dictionary).get("kind", "")) == "building":
				expected_roofs += 1
		var placed_roofs := 0
		for child in renderer.architecture_layer.get_children():
			if child is not Sprite2D or not str((child as Sprite2D).name).begins_with("Overhead_"):
				continue
			placed_roofs += 1
			var roof := child as Sprite2D
			assert_not_null(roof.texture, "%s roof sprite texture must resolve" % map_id)
			if roof.texture != null:
				assert_gt(roof.scale.x, 0.0, "%s roof sprite must have positive width" % map_id)
				assert_gt(roof.scale.y, 0.0, "%s roof sprite must have positive height" % map_id)
		assert_eq(placed_roofs, expected_roofs, "%s must place one complete roof image per building" % map_id)
		var terrain_names: Array = GameData.load_json(INDEX_PATH)["atlases"]["terrain"]["tiles"]
		var shore_count := 0
		for cell in renderer.terrain_layer.get_used_cells():
			if not layout.is_water_cell(cell) or layout.is_bridge_cell(cell) or layout.is_solid_cell(cell):
				continue
			var directions: Array[Vector2i] = []
			for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var neighbor: Vector2i = cell + (direction as Vector2i)
				if layout.cell_in_bounds(neighbor) and not layout.is_water_cell(neighbor) and not layout.is_bridge_cell(neighbor) and not layout.is_solid_cell(neighbor):
					directions.append(direction as Vector2i)
			var expected_bank := renderer._shore_tile_for(directions)
			var coords := renderer.terrain_layer.get_cell_atlas_coords(cell)
			var tile_index := coords.y * 8 + coords.x
			var actual_name := str(terrain_names[tile_index]) if tile_index >= 0 and tile_index < terrain_names.size() else "<invalid>"
			if expected_bank.is_empty():
				assert_true(actual_name.begins_with("water_deep"), "%s interior water at %s must use deep water" % [map_id, cell])
			else:
				shore_count += 1
				assert_eq(actual_name, expected_bank, "%s shoreline at %s must face land direction %s" % [map_id, cell, directions])
		assert_gt(shore_count, 0, "%s map build must produce directional shoreline cells" % map_id)


func test_overhead_building_sprites_are_registered_as_complete_images() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	assert_not_null(parsed, "tile index must parse")
	if parsed == null:
		return
	var sprites: Dictionary = parsed.get("building_sprites", {}) as Dictionary
	assert_eq(sprites.size(), 4, "map styles must resolve to complete overhead sprites")
	for style in ["house", "hall", "shop", "watch"]:
		var path := str(sprites.get(style, ""))
		assert_true(not path.is_empty(), "missing overhead sprite path for %s" % style)
		if path.is_empty():
			continue
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path(path))
		assert_eq(error, OK, "overhead sprite must load from %s" % path)
		if error != OK:
			continue
		assert_gte(image.get_width(), 160, "complete roof sprite must keep usable detail")
		assert_gte(image.get_height(), 160, "complete roof sprite must keep usable detail")
		var transparent_pixels := 0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a < 0.1:
					transparent_pixels += 1
		assert_gt(transparent_pixels, 0, "generated roof cutout must discard checkerboard background")

	var shore_names := ["shore_n", "shore_s", "shore_e", "shore_w", "shore_nw", "shore_ne", "shore_sw", "shore_se"]
	var shore_images: Array[Image] = []
	for shore_name in shore_names:
		var shore := _tile_image(parsed, "terrain", shore_name)
		assert_not_null(shore, "directional riverbank tile must load: %s" % shore_name)
		if shore != null:
			shore_images.append(shore)
	assert_eq(shore_images.size(), 8, "all eight shoreline directions must be present")
	for left in range(shore_images.size()):
		for right in range(left + 1, shore_images.size()):
			assert_ne(shore_images[left].get_data(), shore_images[right].get_data(), "riverbank directions must not reuse the same image")


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
	source.convert(Image.FORMAT_RGBA8)
	var tile_size := int(parsed["tile_size"])
	var columns := int(atlas["columns"])
	var cell := Vector2i(index % columns, index / columns) * tile_size
	var image := Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
	image.blit_rect(source, Rect2i(cell, Vector2i.ONE * tile_size), Vector2i.ZERO)
	return image


func _average_opaque_color(image: Image) -> Color:
	var total := Vector3.ZERO
	var pixels := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			total += Vector3(color.r, color.g, color.b)
			pixels += 1
	if pixels == 0:
		return Color(0.0, 0.0, 0.0, 0.0)
	total /= float(pixels)
	return Color(total.x, total.y, total.z, 1.0)


func _assert_water_network(map_id: String, layout: MapLayout, renderer: MapRenderer) -> void:
	var water_cells: Array[Vector2i] = []
	for y in layout.world_tiles.y:
		for x in layout.world_tiles.x:
			var cell := Vector2i(x, y)
			if layout.is_water_cell(cell):
				water_cells.append(cell)
	assert_gte(water_cells.size(), WATER_COMPONENT_MIN_CELLS, "%s must keep real water" % map_id)
	var visited: Dictionary = {}
	var components := 0
	for start in water_cells:
		if visited.has(start):
			continue
		components += 1
		var component_size := 0
		var queue: Array[Vector2i] = [start]
		visited[start] = true
		var head := 0
		while head < queue.size():
			var cell := queue[head]
			head += 1
			component_size += 1
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next := cell + (direction as Vector2i)
				if not layout.is_water_cell(next) or visited.has(next):
					continue
				visited[next] = true
				queue.append(next)
		assert_gte(
			component_size,
			WATER_COMPONENT_MIN_CELLS,
			"%s must not leave tiny isolated water spots" % map_id
		)
	assert_gt(components, 0, "%s needs at least one water network" % map_id)
	var minimap := layout.minimap_texture.get_image()
	var deep_color := layout.minimap_color_for_tile("water_deep_a")
	var shallow_color := layout.minimap_color_for_tile("water_shallow_a")
	var tile_counts := {}
	for cell in water_cells:
		var cardinal_water := 0
		var land_directions: Array[Vector2i] = []
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + (direction as Vector2i)
			if layout.is_water_cell(neighbor):
				cardinal_water += 1
			elif (
				layout.cell_in_bounds(neighbor)
				and not layout.is_bridge_cell(neighbor)
				and not layout.is_solid_cell(neighbor)
			):
				land_directions.append(direction as Vector2i)
		assert_gte(
			cardinal_water,
			2,
			"%s water at %s must not form a one-cell spike" % [map_id, cell]
		)
		if layout.is_bridge_cell(cell):
			continue
		var tile_name := renderer.terrain_tile_name(cell)
		tile_counts[tile_name] = int(tile_counts.get(tile_name, 0)) + 1
		var expected_bank := renderer._shore_tile_for(land_directions)
		if expected_bank.is_empty():
			assert_true(tile_name.begins_with("water_deep"), "%s interior water at %s must use deep-water art, got %s" % [map_id, cell, tile_name])
		else:
			assert_eq(tile_name, expected_bank, "%s bank at %s must face its adjacent land" % [map_id, cell])
		var minimap_color := minimap.get_pixel(cell.x, cell.y)
		assert_true(
			minimap_color.is_equal_approx(deep_color) or minimap_color.is_equal_approx(shallow_color),
			"%s minimap at %s must keep the water color, got %s" % [map_id, cell, minimap_color]
		)
	if not OS.get_environment("WATER_DEBUG").is_empty():
		print("WATER_DEBUG %s %s" % [map_id, tile_counts])


func _maybe_save_water_preview(
	map_id: String,
	layout: MapLayout,
	renderer: MapRenderer,
	parsed: Dictionary
) -> void:
	var preview_dir := OS.get_environment("WATER_PREVIEW_DIR")
	if preview_dir.is_empty():
		return
	assert_eq(DirAccess.make_dir_recursive_absolute(preview_dir), OK, "preview directory")
	var terrain: Dictionary = parsed["atlases"]["terrain"]
	var names: Array = terrain["tiles"]
	var name_to_index := {}
	for index in names.size():
		name_to_index[str(names[index])] = index
	var atlas_image := (load(str(terrain["path"])) as Texture2D).get_image()
	assert_not_null(atlas_image, "terrain atlas image must load")
	if atlas_image == null:
		return
	var tile_size := int(parsed["tile_size"])
	var preview := Image.create(
		layout.world_tiles.x * tile_size,
		layout.world_tiles.y * tile_size,
		false,
		Image.FORMAT_RGBA8
	)
	for y in layout.world_tiles.y:
		for x in layout.world_tiles.x:
			var cell := Vector2i(x, y)
			var tile_name := renderer.terrain_tile_name(cell)
			var tile_index := int(name_to_index.get(tile_name, 0))
			var source := Rect2i(
				Vector2i(tile_index % 8, tile_index / 8) * tile_size,
				Vector2i.ONE * tile_size
			)
			preview.blit_rect(atlas_image, source, cell * tile_size)
	var target_width := mini(1400, preview.get_width())
	var scale := float(target_width) / float(preview.get_width())
	preview.resize(
		target_width,
		roundi(float(preview.get_height()) * scale),
		Image.INTERPOLATE_BILINEAR
	)
	var output := preview_dir.path_join("water_%s.png" % map_id)
	assert_eq(preview.save_png(output), OK, "water preview must save")
