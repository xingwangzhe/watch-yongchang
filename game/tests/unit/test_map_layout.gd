extends GutTest

const TEST_SAVE := "user://test_map_layout_save.json"


func before_each() -> void:
	SaveSystem.save_path = TEST_SAVE
	SaveSystem.reset_memory()
	Locale.set_language("zh", false)


func after_each() -> void:
	SaveSystem.save_path = SaveSystem.SAVE_PATH
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func test_three_maps_have_real_spatial_structure() -> void:
	var maps := GameData.get_maps()
	for map_id in maps.keys():
		var definition: Dictionary = maps[map_id]
		var layout_data: Dictionary = definition.get("layout", {}) as Dictionary
		var tiles: Array = layout_data.get("world_tiles", []) as Array
		assert_eq(tiles.size(), 2, "%s needs a fixed world size" % map_id)
		assert_gte(int(tiles[0]), 84, "%s must be wider than one screen" % map_id)
		assert_gte(int(tiles[1]), 84, "%s must be taller than one screen" % map_id)
		var areas: Array = layout_data.get("areas", []) as Array
		assert_gte(areas.size(), 20, "%s needs layered terrain, roads and structures" % map_id)
		var kinds := {}
		for area in areas:
			var kind := str((area as Dictionary).get("kind", ""))
			kinds[kind] = int(kinds.get(kind, 0)) + 1
		for kind in ["terrain", "road", "water", "bridge", "wall", "building"]:
			assert_gte(int(kinds.get(kind, 0)), 1, "%s needs %s structure" % [map_id, kind])
		assert_gte((layout_data.get("landmarks", []) as Array).size(), 5)
		assert_gte((layout_data.get("spawn_lanes", []) as Array).size(), 7)

	var watergate: Dictionary = maps["watergate"] as Dictionary
	var watergate_layout: Dictionary = watergate.get("layout", {}) as Dictionary
	assert_eq(_count_kind(watergate_layout, "gate"), 4)
	assert_eq(_count_kind(watergate_layout, "water_gate"), 4)
	assert_eq(_count_kind(watergate_layout, "tower"), 12)
	assert_eq(_count_canals(watergate_layout), 2, "the fort needs two north-south canals")

	var crossstreet: Dictionary = maps["crossstreet"] as Dictionary
	var crossstreet_layout: Dictionary = crossstreet.get("layout", {}) as Dictionary
	assert_eq(_count_kind(crossstreet_layout, "gate"), 4)
	assert_eq(_count_kind(crossstreet_layout, "water_gate"), 4)
	assert_eq(_count_canals(crossstreet_layout), 2)
	assert_gte(_count_kind(crossstreet_layout, "building"), 60)


func test_watergate_blocks_water_and_opens_bridges_and_gates() -> void:
	var built := _build_map("watergate")
	var layout: MapLayout = built["layout"] as MapLayout
	assert_true(layout.is_solid_cell(Vector2i(20, 28)), "outer wall must block movement")
	assert_true(layout.is_water_cell(Vector2i(36, 72)), "upper canal must be water")
	assert_false(layout.is_cell_walkable(Vector2i(36, 72)), "canal must not be walkable")
	assert_true(layout.is_bridge_cell(Vector2i(36, 47)), "bridge must cover the canal")
	assert_true(layout.is_cell_walkable(Vector2i(36, 47)), "bridge must be walkable")
	assert_true(layout.is_cell_walkable(Vector2i(47, 29)), "south gate passage must be open")
	assert_true(layout.is_point_walkable(layout.start_pos), "player spawn must be walkable")
	assert_eq(layout.landmark_entries().size(), 8)
	assert_eq((built["renderer"] as MapRenderer).terrain_layer.get_used_cells().size(), 96 * 160)
	assert_true((built["renderer"] as MapRenderer).architecture_layer.get_used_cells().size() > 0)
	assert_eq(layout.minimap_texture.get_width(), 96)
	assert_eq(layout.minimap_texture.get_height(), 160)


func test_crossstreet_buildings_avoid_the_cross_and_canals() -> void:
	var built := _build_map("crossstreet")
	var layout: MapLayout = built["layout"] as MapLayout
	assert_true(layout.is_solid_cell(Vector2i(40, 10)), "street block must be solid")
	assert_true(layout.is_water_cell(Vector2i(30, 70)), "west canal must be water")
	assert_false(layout.is_cell_walkable(Vector2i(30, 70)), "canal must not be walkable")
	assert_true(layout.is_cell_walkable(Vector2i(30, 79)), "canal bridge must be walkable")
	assert_true(layout.is_cell_walkable(Vector2i(5, 80)), "west land gate must be open")
	assert_true(layout.is_point_walkable(layout.start_pos), "crossroads spawn must be walkable")
	assert_eq(layout.minimap_texture.get_width(), 96)
	assert_eq(layout.minimap_texture.get_height(), 160)


func test_tideland_creeks_are_crossed_by_bridges() -> void:
	var built := _build_map("tideland")
	var layout: MapLayout = built["layout"] as MapLayout
	assert_true(layout.is_water_cell(Vector2i(30, 45)), "tide creek must be water")
	assert_false(layout.is_cell_walkable(Vector2i(30, 45)), "tide creek must not be walkable")
	assert_true(layout.is_cell_walkable(Vector2i(30, 63)), "creek bridge must be walkable")
	assert_true(layout.is_solid_cell(Vector2i(64, 10)), "salt shed must block movement")
	assert_true(layout.is_point_walkable(layout.start_pos), "tideland spawn must be walkable")
	assert_eq(layout.minimap_texture.get_width(), 120)
	assert_eq(layout.minimap_texture.get_height(), 84)


func test_buildings_stay_off_roads_and_water() -> void:
	var maps := GameData.get_maps()
	for map_id in maps.keys():
		var layout_data: Dictionary = (maps[map_id] as Dictionary).get("layout", {}) as Dictionary
		var roads: Array[Rect2i] = []
		var buildings: Array[Rect2i] = []
		var waters: Array[Rect2i] = []
		for area in layout_data.get("areas", []) as Array:
			var item := area as Dictionary
			var kind := str(item.get("kind", ""))
			if kind == "road" or kind == "plaza":
				roads.append(_area_rect(item))
			elif kind == "building":
				buildings.append(_area_rect(item))
			elif kind == "water":
				waters.append(_area_rect(item))
		for road in roads:
			for building in buildings:
				assert_false(
					_rects_overlap(road, building),
					"%s building %s covers road %s" % [map_id, building, road]
				)
		for water in waters:
			for building in buildings:
				assert_false(
					_rects_overlap(water, building),
					"%s building %s covers water %s" % [map_id, building, water]
				)


func test_spawn_lanes_are_walkable_and_connected_to_player_spawn() -> void:
	for map_id in ["tideland", "watergate", "crossstreet"]:
		var built := _build_map(map_id)
		var layout: MapLayout = built["layout"] as MapLayout
		var reachable := layout.walkable_reachability(layout.start_pos)
		var samples := layout.spawn_sample_points()
		assert_gt(samples.size(), 20, "%s needs real spawn-band samples" % map_id)
		for point in samples:
			var cell := layout.world_to_cell(point)
			assert_true(
				layout.is_point_walkable(point, 14.0),
				"%s spawn sample %s is blocked" % [map_id, point]
			)
			assert_eq(
				reachable[cell.y * layout.world_tiles.x + cell.x],
				1,
				"%s spawn sample %s is disconnected" % [map_id, point]
			)
		var candidates := layout.spawn_candidates(layout.start_pos, 300.0, 1400.0)
		assert_gt(candidates.size(), 0, "%s must offer spawn candidates" % map_id)
		for candidate in candidates:
			assert_true(layout.is_point_walkable(candidate, 14.0))
			var candidate_cell := layout.world_to_cell(candidate)
			assert_eq(reachable[candidate_cell.y * layout.world_tiles.x + candidate_cell.x], 1)


func test_flow_field_routes_outer_spawns_through_fort_gates() -> void:
	var built := _build_map("watergate")
	var layout: MapLayout = built["layout"] as MapLayout
	var target := layout.start_pos
	layout.ensure_flow_field(target)
	for spawn_tile in [Vector2i(48, 148), Vector2i(3, 81), Vector2i(93, 81)]:
		var position := (Vector2(spawn_tile) + Vector2(0.5, 0.5)) * MapLayout.TILE_SIZE
		var start_distance := position.distance_to(target)
		for _step in range(1200):
			var direction := layout.navigation_direction(position, target)
			if direction == Vector2.ZERO:
				break
			var next := position + direction * 5.0
			position = layout.move_circle(position, next, 14.0)
			if position.distance_to(target) < 48.0:
				break
		assert_lt(
			position.distance_to(target),
			start_distance * 0.2,
			"outer spawn %s must route through a gate toward the player" % spawn_tile
		)


func test_run_camera_is_bounded_and_minimap_avoids_score_panels() -> void:
	SaveSystem.data["total_merit"] = 2000
	SaveSystem.data["selected_map"] = "watergate"
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(4)
	var world_size: Vector2 = run.battlefield.map_layout.world_size
	assert_eq(run.camera.limit_left, 0)
	assert_eq(run.camera.limit_top, 0)
	assert_eq(run.camera.limit_right, int(world_size.x))
	assert_eq(run.camera.limit_bottom, int(world_size.y))
	var minimap := run.hud.find_child("Minimap", true, false) as RunMinimap
	assert_not_null(minimap, "HUD must expose the live minimap")
	assert_not_null(minimap.layout)
	assert_not_null(minimap._base_texture)
	var minimap_rect := Rect2(minimap.position, minimap.size)
	assert_lte(minimap_rect.end.x, 1280.0)
	assert_lte(minimap_rect.end.y, 720.0)
	for label_name in ["KillLabel", "MeritLabel"]:
		var label := run.hud.find_child(label_name, true, false) as Label
		assert_not_null(label)
		assert_false(
			Rect2(label.position, label.size).intersects(minimap_rect),
			"%s must not overlap the minimap" % label_name
		)


func _build_map(map_id: String) -> Dictionary:
	var definition: Dictionary = (GameData.get_maps()[map_id] as Dictionary).duplicate(true)
	var layout := MapLayout.new()
	layout.setup(map_id, definition)
	var renderer := MapRenderer.new()
	renderer.name = "TestMapRenderer_%s" % map_id
	add_child_autofree(renderer)
	renderer.build(layout, definition, 20261123)
	return {"layout": layout, "renderer": renderer, "definition": definition}


func _count_kind(layout_data: Dictionary, kind: String) -> int:
	var count := 0
	for area in layout_data.get("areas", []) as Array:
		if str((area as Dictionary).get("kind", "")) == kind:
			count += 1
	return count


func _count_canals(layout_data: Dictionary) -> int:
	var count := 0
	var size_data: Array = layout_data.get("world_tiles", [0, 0]) as Array
	var world_width := int(size_data[0])
	for area in layout_data.get("areas", []) as Array:
		var item := area as Dictionary
		if str(item.get("kind", "")) != "water":
			continue
		var rect := _area_rect(item)
		if (
			rect.size.y >= 150
			and rect.size.x >= 4
			and rect.position.x > 0
			and rect.end.x < world_width
		):
			count += 1
	return count


func _area_rect(area: Dictionary) -> Rect2i:
	var data: Array = area.get("rect", [0, 0, 0, 0]) as Array
	return Rect2i(int(data[0]), int(data[1]), int(data[2]), int(data[3]))


func _rects_overlap(a: Rect2i, b: Rect2i) -> bool:
	return (
		a.position.x < b.end.x
		and b.position.x < a.end.x
		and a.position.y < b.end.y
		and b.position.y < a.end.y
	)
