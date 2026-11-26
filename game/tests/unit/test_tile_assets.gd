extends GutTest

const INDEX_PATH := "res://data/yongchang_tiles.json"
const WATER_MAP_IDS := ["tideland", "watergate", "crossstreet"]
const WATER_COMPONENT_MIN_CELLS := 16


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
		_maybe_save_water_preview(map_id, layout, renderer, parsed)


func test_roofs_read_warm_and_eaves_expose_a_visible_facade() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	assert_not_null(parsed, "tile index must parse")
	if parsed == null:
		return
	var roof := _tile_image(parsed, "architecture", "roof_slope")
	var eave := _tile_image(parsed, "architecture", "roof_eave")
	var street := _tile_image(parsed, "terrain", "stone_road_a")
	assert_not_null(roof, "roof slope must load")
	assert_not_null(eave, "roof eave must load")
	assert_not_null(street, "stone street must load")
	if roof == null or eave == null or street == null:
		return
	var roof_average := _average_opaque_color(roof)
	var street_average := _average_opaque_color(street)
	assert_gt(
		roof_average.r - roof_average.b,
		0.015,
		"roof tiles must stay warm instead of matching the cool stone street"
	)
	assert_gt(
		street_average.b - street_average.r,
		0.015,
		"stone streets must stay cool so roofs separate at a glance"
	)
	var facade_pixels := 0
	for y in range(23, 32):
		for x in 32:
			var color := eave.get_pixel(x, y)
			if color.a > 0.9 and color.get_luminance() > 0.42:
				facade_pixels += 1
	assert_gt(facade_pixels, 48, "eave tile must expose a light plaster facade below the roof")


func test_roof_variants_and_door_eave_keep_distinct_silhouettes() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	assert_not_null(parsed, "tile index must parse")
	if parsed == null:
		return
	var architecture: Dictionary = parsed["atlases"]["architecture"]
	var names: Array = architecture["tiles"]
	for tile_name in [
		"roof_slope_b", "roof_slope_c", "roof_eave_b", "roof_eave_door",
		"hall_roof_ridge", "hall_roof_slope", "hall_roof_eave", "hall_roof_corner",
		"roof_verge", "roof_hip_left", "roof_hip_right",
		"hall_roof_verge", "hall_roof_hip_left", "hall_roof_hip_right",
		"roof_eave_shop", "roof_verge_b",
	]:
		assert_true(names.has(tile_name), "architecture atlas must expose %s" % tile_name)
	var slope_a := _tile_image(parsed, "architecture", "roof_slope")
	var slope_b := _tile_image(parsed, "architecture", "roof_slope_b")
	var slope_c := _tile_image(parsed, "architecture", "roof_slope_c")
	var door_eave := _tile_image(parsed, "architecture", "roof_eave_door")
	var hall_eave := _tile_image(parsed, "architecture", "hall_roof_eave")
	for image: Image in [slope_a, slope_b, slope_c, door_eave, hall_eave]:
		assert_not_null(image, "roof variant tile must load")
	if slope_a == null or slope_b == null or slope_c == null or door_eave == null or hall_eave == null:
		return
	assert_ne(slope_a.get_data(), slope_b.get_data(), "roof variants must not be duplicates")
	assert_ne(slope_a.get_data(), slope_c.get_data(), "weathered roof variant must differ")
	var red_door_pixels := 0
	for y in range(22, 32):
		for x in range(10, 22):
			var color := door_eave.get_pixel(x, y)
			if color.r > color.g * 1.45 and color.r > color.b * 1.45:
				red_door_pixels += 1
	assert_gt(red_door_pixels, 24, "door eave must keep a readable red door below its roof")
	var hall_red_pixels := 0
	for y in 32:
		for x in 32:
			var color := hall_eave.get_pixel(x, y)
			if color.r > color.g * 1.35 and color.r > color.b * 1.30:
				hall_red_pixels += 1
	assert_gt(hall_red_pixels, 12, "hall eave must expose red timber columns")


func test_roof_verge_side_wall_and_shop_eave_create_depth() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	assert_not_null(parsed, "tile index must parse")
	if parsed == null:
		return
	var verge := _tile_image(parsed, "architecture", "roof_verge")
	var hip_left := _tile_image(parsed, "architecture", "roof_hip_left")
	var hip_right := _tile_image(parsed, "architecture", "roof_hip_right")
	var side_wall := _tile_image(parsed, "architecture", "gable_left")
	var shop_eave := _tile_image(parsed, "architecture", "roof_eave_shop")
	for image: Image in [verge, hip_left, hip_right, side_wall, shop_eave]:
		assert_not_null(image, "depth roof tile must load")
	if verge == null or hip_left == null or hip_right == null or side_wall == null or shop_eave == null:
		return
	assert_ne(hip_left.get_data(), hip_right.get_data(), "roof hips must be mirrored, not duplicated")
	var verge_plaster := 0
	for y in range(20, 32):
		for x in 32:
			var color := verge.get_pixel(x, y)
			if color.a > 0.9 and color.g > 0.62 and color.b > 0.47:
				verge_plaster += 1
	assert_lt(verge_plaster, 12, "north roof verge must not read as another white facade")
	var side_wall_plaster := 0
	for y in 32:
		for x in 32:
			var color := side_wall.get_pixel(x, y)
			if color.a > 0.9 and color.get_luminance() > 0.48:
				side_wall_plaster += 1
	assert_gt(side_wall_plaster, 48, "side wall must keep a readable plaster reveal")
	assert_lt(side_wall_plaster, 450, "side wall reveal must leave most of the cell as roof volume")
	var awning_pixels := 0
	for y in range(18, 25):
		for x in 32:
			var color := shop_eave.get_pixel(x, y)
			if color.r > color.g * 1.25 and color.r > color.b * 1.2:
				awning_pixels += 1
	assert_gt(awning_pixels, 28, "shop eave must expose a warm awning above the storefront")


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
		var shoreline := false
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor := cell + (direction as Vector2i)
			if layout.is_water_cell(neighbor):
				cardinal_water += 1
			elif (
				layout.cell_in_bounds(neighbor)
				and not layout.is_bridge_cell(neighbor)
			):
				shoreline = true
		assert_gte(
			cardinal_water,
			2,
			"%s water at %s must not form a one-cell spike" % [map_id, cell]
		)
		if layout.is_bridge_cell(cell):
			continue
		var tile_name := renderer.terrain_tile_name(cell)
		tile_counts[tile_name] = int(tile_counts.get(tile_name, 0)) + 1
		if shoreline:
			assert_true(
				tile_name.begins_with("shore_") or tile_name.begins_with("water_shallow"),
				"%s shoreline at %s must use shallow/shore art, got %s" % [map_id, cell, tile_name]
			)
		else:
			assert_true(
				tile_name.begins_with("water_deep"),
				"%s water interior at %s must stay deep, got %s" % [map_id, cell, tile_name]
			)
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
