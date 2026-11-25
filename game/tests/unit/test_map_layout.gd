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
		assert_gte(
			int(kinds.get("road", 0)) + int(kinds.get("plaza", 0)) + int(kinds.get("path", 0)),
			1,
			"%s needs a traversable road or path" % map_id
		)
		assert_gte(
			int(kinds.get("water", 0)) + int(kinds.get("water_path", 0)) + int(kinds.get("creek", 0)),
			1,
			"%s needs water" % map_id
		)
		for kind in ["terrain", "bridge", "wall", "building"]:
			assert_gte(int(kinds.get(kind, 0)), 1, "%s needs %s structure" % [map_id, kind])
		assert_gte((layout_data.get("landmarks", []) as Array).size(), 5)
		assert_gte((layout_data.get("spawn_lanes", []) as Array).size(), 7)
		var highlands := layout_data.get("highlands", []) as Array
		assert_gte(highlands.size(), 2, "%s must mark raised ground" % map_id)
		for entry in highlands:
			var rect_data := entry as Array
			assert_eq(rect_data.size(), 4, "%s highland needs [x,y,w,h]" % map_id)
			assert_gt(int(rect_data[2]), 0)
			assert_gt(int(rect_data[3]), 0)
			assert_lte(int(rect_data[0]) + int(rect_data[2]), int(tiles[0]))
			assert_lte(int(rect_data[1]) + int(rect_data[3]), int(tiles[1]))

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
	assert_gte(_count_kind(watergate_layout, "building"), 24, "水门城必须有连续城内聚落")
	assert_gte(
		_count_kind(maps["tideland"].get("layout", {}) as Dictionary, "building"),
		30,
		"滩涂必须有盐仓、渔舍与海塘聚落"
	)


func test_watergate_opens_water_as_wade_and_keeps_bridges_dry() -> void:
	var built := _build_map("watergate")
	var layout: MapLayout = built["layout"] as MapLayout
	assert_true(layout.is_solid_cell(Vector2i(20, 28)), "outer wall must block movement")
	assert_true(layout.is_water_cell(Vector2i(36, 72)), "upper canal must be water")
	assert_true(layout.is_cell_walkable(Vector2i(36, 72)), "canal must be wadeable")
	assert_true(layout.is_wade_position(Vector2(36 * 32.0 + 16.0, 72 * 32.0 + 16.0)), "canal cell must count as wading")
	assert_true(layout.is_bridge_cell(Vector2i(36, 47)), "bridge must cover the canal")
	assert_true(layout.is_cell_walkable(Vector2i(36, 47)), "bridge must be walkable")
	assert_false(layout.is_wade_position(Vector2(36 * 32.0 + 16.0, 47 * 32.0 + 16.0)), "bridge deck must stay dry")
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
	assert_true(layout.is_solid_cell(Vector2i(8, 10)), "street block must be solid")
	assert_true(layout.is_water_cell(Vector2i(30, 70)), "west canal must be water")
	assert_true(layout.is_cell_walkable(Vector2i(30, 70)), "west canal must be wadeable")
	assert_true(layout.is_cell_walkable(Vector2i(30, 79)), "canal bridge must be walkable")
	assert_true(layout.is_cell_walkable(Vector2i(5, 80)), "west land gate must be open")
	assert_true(layout.is_point_walkable(layout.start_pos), "crossroads spawn must be walkable")
	assert_eq(layout.minimap_texture.get_width(), 96)
	assert_eq(layout.minimap_texture.get_height(), 160)


func test_crossstreet_lots_are_courtyard_scale_and_keep_visible_eaves() -> void:
	var definition: Dictionary = GameData.get_maps()["crossstreet"] as Dictionary
	var layout_data: Dictionary = definition["layout"] as Dictionary
	var buildings: Array[Rect2i] = []
	var max_height := 0
	var max_width := 0
	for area in layout_data.get("areas", []) as Array:
		var item := area as Dictionary
		if str(item.get("kind", "")) != "building":
			continue
		var rect := _area_rect(item)
		buildings.append(rect)
		max_height = maxi(max_height, rect.size.y)
		max_width = maxi(max_width, rect.size.x)
	assert_gte(buildings.size(), 90, "十字街应拆成院落尺度街坊，而不是少量长条屋顶")
	assert_lte(max_height, 7, "街坊不应再出现 15–17 格长、没有檐口节奏的巨屋顶")
	assert_lte(max_width, 9, "街坊宽度应保持院落尺度")

	var built := _build_map("crossstreet")
	var renderer: MapRenderer = built["renderer"] as MapRenderer
	var eave_rows := 0
	var verge_rows := 0
	var ridge_rows := 0
	var shop_eaves := 0
	for rect in buildings:
		var bottom_y := rect.end.y - 1
		for x in range(rect.position.x, rect.end.x):
			var tile_name := renderer.architecture_tile_name(Vector2i(x, bottom_y))
			assert_true(
				tile_name.contains("roof_eave"),
				"building bottom row must expose a roof eave/facade, got %s at %s" % [tile_name, Vector2i(x, bottom_y)]
			)
			eave_rows += 1
		var center_x := rect.position.x + rect.size.x / 2
		var verge_name := renderer.architecture_tile_name(Vector2i(center_x, rect.position.y))
		assert_true(
			verge_name.begins_with("roof_verge") or verge_name.begins_with("hall_roof_verge"),
			"building must have a raised north roof verge, got %s at %s" % [
				verge_name,
				Vector2i(center_x, rect.position.y),
			]
		)
		verge_rows += 1
		var ridge_row := maxi(1, int((rect.size.y - 1) / 2.0))
		var ridge_name := renderer.architecture_tile_name(
			Vector2i(center_x, rect.position.y + ridge_row)
		)
		assert_true(
			ridge_name.begins_with("roof_ridge") or ridge_name.begins_with("hall_roof_ridge"),
			"building must separate its roof plane with a ridge band, got %s at %s" % [
				ridge_name,
				Vector2i(center_x, rect.position.y + ridge_row),
			]
		)
		ridge_rows += 1
	assert_gt(eave_rows, 300, "每排街坊都应形成连续可见的檐口和白墙立面")
	assert_gte(verge_rows, 90, "每栋院落都应有独立的北檐，而不是共用一块巨屋顶")
	assert_gte(ridge_rows, 90, "每栋院落都应有一条可读的屋脊分面")

	var definition_areas: Array = layout_data.get("areas", []) as Array
	for area in definition_areas:
		var item := area as Dictionary
		if str(item.get("kind", "")) != "building" or str(item.get("style", "")) != "shop":
			continue
		var rect := _area_rect(item)
		if rect.size.x < 5:
			continue
		var door_cell := Vector2i(rect.position.x + rect.size.x / 2, rect.end.y - 1)
		var door_tile := renderer.architecture_tile_name(door_cell)
		assert_eq(door_tile, "roof_eave_shop", "storefronts need their own awning eave at %s" % door_cell)
		shop_eaves += 1
	assert_gt(shop_eaves, 10, "十字街必须保留可识别的店铺门面")


func test_watergate_and_tideland_lots_keep_visible_roof_depth() -> void:
	var expected_minimum := {
		"tideland": 30,
		"watergate": 24,
	}
	for map_id in expected_minimum.keys():
		var definition: Dictionary = GameData.get_maps()[map_id] as Dictionary
		var layout_data: Dictionary = definition["layout"] as Dictionary
		var buildings: Array[Rect2i] = []
		var styles := {}
		var max_height := 0
		var max_width := 0
		for area in layout_data.get("areas", []) as Array:
			var item := area as Dictionary
			if str(item.get("kind", "")) != "building":
				continue
			var rect := _area_rect(item)
			buildings.append(rect)
			styles[str(item.get("style", "house"))] = true
			max_height = maxi(max_height, rect.size.y)
			max_width = maxi(max_width, rect.size.x)
		assert_gte(
			buildings.size(),
			int(expected_minimum[map_id]),
			"%s must contain a settlement, not isolated landmark sheds" % map_id
		)
		assert_lte(max_height, 7, "%s hamlets must keep courtyard-scale depth" % map_id)
		assert_lte(max_width, 9, "%s hamlets must keep courtyard-scale frontage" % map_id)
		assert_gte(styles.size(), 2, "%s needs varied building silhouettes" % map_id)

		var built := _build_map(map_id)
		var renderer: MapRenderer = built["renderer"] as MapRenderer
		var eave_cells := 0
		var ridge_count := 0
		for rect in buildings:
			var bottom_y := rect.end.y - 1
			for x in range(rect.position.x, rect.end.x):
				var tile_name := renderer.architecture_tile_name(Vector2i(x, bottom_y))
				assert_true(
					tile_name.contains("roof_eave"),
					"%s bottom row must show an eave/facade, got %s" % [map_id, tile_name]
				)
				eave_cells += 1
			var center_x := rect.position.x + rect.size.x / 2
			var verge_name := renderer.architecture_tile_name(
				Vector2i(center_x, rect.position.y)
			)
			assert_true(
				verge_name.begins_with("roof_verge") or verge_name.begins_with("hall_roof_verge"),
				"%s must give each lot a raised north verge, got %s" % [map_id, verge_name]
			)
			var ridge_row := maxi(1, int((rect.size.y - 1) / 2.0))
			var ridge_name := renderer.architecture_tile_name(
				Vector2i(center_x, rect.position.y + ridge_row)
			)
			assert_true(
				ridge_name.begins_with("roof_ridge") or ridge_name.begins_with("hall_roof_ridge"),
				"%s must separate each roof plane with a central ridge, got %s" % [map_id, ridge_name]
			)
			ridge_count += 1
		assert_gt(eave_cells, 80, "%s needs visible eaves along every hamlet frontage" % map_id)
		assert_eq(ridge_count, buildings.size(), "%s every lot needs its own ridge band" % map_id)


func test_tideland_creeks_are_crossed_by_bridges() -> void:
	var built := _build_map("tideland")
	var layout: MapLayout = built["layout"] as MapLayout
	assert_true(layout.is_water_cell(Vector2i(35, 40)), "tide creek must be water")
	assert_true(layout.is_cell_walkable(Vector2i(35, 40)), "tide creek must be wadeable")
	assert_true(layout.is_cell_walkable(Vector2i(30, 63)), "creek bridge must be walkable")
	assert_true(layout.is_solid_cell(Vector2i(65, 10)), "salt shed must block movement")
	assert_true(layout.is_point_walkable(layout.start_pos), "tideland spawn must be walkable")
	assert_eq(layout.minimap_texture.get_width(), 120)
	assert_eq(layout.minimap_texture.get_height(), 84)


func test_all_maps_keep_water_walkable_and_minimap_synced() -> void:
	for map_id in ["tideland", "watergate", "crossstreet"]:
		var built := _build_map(map_id)
		var layout: MapLayout = built["layout"] as MapLayout
		var renderer: MapRenderer = built["renderer"] as MapRenderer
		var minimap := layout.minimap_texture.get_image()
		var water_count := 0
		var wading_count := 0
		var bridge_water_count := 0
		var blocked_water_count := 0
		var walkability_mismatches := 0
		var visual_mismatches := 0
		var minimap_mismatches := 0
		var invisible_blockers := 0
		for y in layout.world_tiles.y:
			for x in layout.world_tiles.x:
				var cell := Vector2i(x, y)
				if not layout.is_water_cell(cell):
					continue
				water_count += 1
				if layout.is_solid_cell(cell):
					blocked_water_count += 1
					if renderer.architecture_tile_name(cell).is_empty() and renderer.prop_tile_name(cell).is_empty():
						invisible_blockers += 1
					continue
				if not layout.is_cell_walkable(cell):
					walkability_mismatches += 1
				var tile_name := renderer.terrain_tile_name(cell)
				var center := (Vector2(cell) + Vector2.ONE * 0.5) * MapLayout.TILE_SIZE
				var expected_color: Color
				if layout.is_bridge_cell(cell):
					bridge_water_count += 1
					if layout.is_wade_position(center) or (tile_name != "dock_horizontal" and tile_name != "dock_vertical"):
						visual_mismatches += 1
					expected_color = MapLayout.MINIMAP_BRIDGE
				else:
					wading_count += 1
					if not layout.is_wade_position(center) or not tile_name.begins_with("water_"):
						visual_mismatches += 1
					expected_color = layout.minimap_color_for_tile(tile_name)
				if not minimap.get_pixel(cell.x, cell.y).is_equal_approx(expected_color):
					minimap_mismatches += 1
		assert_gt(water_count, 100, "%s must contain real water" % map_id)
		assert_gt(wading_count, 100, "%s must keep ordinary water wadeable" % map_id)
		assert_gt(bridge_water_count, 10, "%s must keep bridge decks dry over water" % map_id)
		assert_gt(blocked_water_count, 0, "%s railings must still block their water cells" % map_id)
		assert_eq(walkability_mismatches, 0, "%s unblocked water must remain walkable" % map_id)
		assert_eq(visual_mismatches, 0, "%s water and bridge visuals must match movement semantics" % map_id)
		assert_eq(minimap_mismatches, 0, "%s water minimap colors must match rendered tiles" % map_id)
		assert_eq(invisible_blockers, 0, "%s blocked water must show a railing or solid prop" % map_id)


func test_all_maps_have_visible_blockers_for_every_solid_cell() -> void:
	for map_id in ["tideland", "watergate", "crossstreet"]:
		var built := _build_map(map_id)
		var layout: MapLayout = built["layout"] as MapLayout
		var renderer: MapRenderer = built["renderer"] as MapRenderer
		var minimap := layout.minimap_texture.get_image()
		var solid_count := 0
		var invisible_blockers := 0
		var mountain_minimap_mismatches := 0
		var railing_minimap_mismatches := 0
		for y in layout.world_tiles.y:
			for x in layout.world_tiles.x:
				var cell := Vector2i(x, y)
				if not layout.is_solid_cell(cell):
					continue
				solid_count += 1
				var terrain_name := renderer.terrain_tile_name(cell)
				var architecture_name := renderer.architecture_tile_name(cell)
				var prop_name := renderer.prop_tile_name(cell)
				if not terrain_name.begins_with("mountain_") and architecture_name.is_empty() and prop_name.is_empty():
					invisible_blockers += 1
				if terrain_name.begins_with("mountain_") and not minimap.get_pixel(cell.x, cell.y).is_equal_approx(
					layout.minimap_color_for_tile(terrain_name)
				):
					mountain_minimap_mismatches += 1
				if architecture_name == "wood_railing" or architecture_name == "wood_railing_vertical":
					if not minimap.get_pixel(cell.x, cell.y).is_equal_approx(MapLayout.MINIMAP_BRIDGE_RAILING):
						railing_minimap_mismatches += 1
		assert_gt(solid_count, 100, "%s must contain real blocked structures" % map_id)
		assert_eq(invisible_blockers, 0, "%s collision must never exist without visible geometry" % map_id)
		assert_eq(mountain_minimap_mismatches, 0, "%s mountain minimap must match rock tiles" % map_id)
		assert_eq(railing_minimap_mismatches, 0, "%s railing minimap must read as blocked wood" % map_id)


func test_all_map_bridges_have_continuous_decks_and_water_railings() -> void:
	for map_id in ["tideland", "watergate", "crossstreet"]:
		var built := _build_map(map_id)
		var layout: MapLayout = built["layout"] as MapLayout
		var renderer: MapRenderer = built["renderer"] as MapRenderer
		var bridge_count := 0
		var railing_count := 0
		var centerline_gaps := 0
		var blocked_centerlines := 0
		var blocked_player_clearance := 0
		var wet_centerlines := 0
		var deck_mismatches := 0
		var blocked_landings := 0
		var railing_mismatches := 0
		var areas: Array = ((built["definition"] as Dictionary)["layout"] as Dictionary).get("areas", []) as Array
		for area in areas:
			if str((area as Dictionary).get("kind", "")) != "bridge":
				continue
			bridge_count += 1
			var rect := _area_rect(area as Dictionary)
			var horizontal := rect.size.x >= rect.size.y
			var expected_deck := "dock_horizontal" if horizontal else "dock_vertical"
			var expected_railing := "wood_railing" if horizontal else "wood_railing_vertical"
			var center_fixed := rect.position.y + rect.size.y / 2 if horizontal else rect.position.x + rect.size.x / 2
			var center_length := rect.size.x if horizontal else rect.size.y
			for index in center_length:
				var cell := Vector2i(rect.position.x + index, center_fixed) if horizontal else Vector2i(center_fixed, rect.position.y + index)
				if not layout.is_bridge_cell(cell):
					centerline_gaps += 1
				if not layout.is_cell_walkable(cell):
					blocked_centerlines += 1
				if layout.is_wade_position((Vector2(cell) + Vector2.ONE * 0.5) * MapLayout.TILE_SIZE):
					wet_centerlines += 1
				if index > 0 and index < center_length - 1:
					var center_position := Vector2(
						float(rect.position.x + index) + 0.5,
						float(rect.position.y) + float(rect.size.y) * 0.5
					) * MapLayout.TILE_SIZE
					if not horizontal:
						center_position = Vector2(
							float(rect.position.x) + float(rect.size.x) * 0.5,
							float(rect.position.y + index) + 0.5
						) * MapLayout.TILE_SIZE
					if not layout.is_point_walkable(center_position, 18.0):
						blocked_player_clearance += 1
				var tile_name := renderer.terrain_tile_name(cell)
				var architecture_name := renderer.architecture_tile_name(cell)
				var is_gate := architecture_name == "land_gate_arch" or architecture_name == "water_gate_arch"
				if tile_name != expected_deck and not is_gate:
					deck_mismatches += 1
			for y in rect.size.y:
				for x in rect.size.x:
					var cell := rect.position + Vector2i(x, y)
					var is_edge := false
					if horizontal:
						is_edge = y == 0 or y == rect.size.y - 1
					else:
						is_edge = x == 0 or x == rect.size.x - 1
					if layout.is_water_cell(cell) and is_edge:
						railing_count += 1
						if not layout.is_solid_cell(cell) or renderer.architecture_tile_name(cell) != expected_railing:
							railing_mismatches += 1
					elif not layout.is_water_cell(cell) and not layout.is_cell_walkable(cell):
						blocked_landings += 1
		assert_gt(bridge_count, 5, "%s must exercise multiple crossings" % map_id)
		assert_gt(railing_count, 10, "%s must expose water-span railings" % map_id)
		assert_eq(centerline_gaps, 0, "%s bridge centerlines must be continuous" % map_id)
		assert_eq(blocked_centerlines, 0, "%s bridge centerlines must stay open" % map_id)
		assert_eq(blocked_player_clearance, 0, "%s bridge interiors must clear the player collision radius" % map_id)
		assert_eq(wet_centerlines, 0, "%s bridge centerlines must stay dry" % map_id)
		assert_eq(deck_mismatches, 0, "%s bridge centerlines must show matching deck tiles" % map_id)
		assert_eq(blocked_landings, 0, "%s bridge landings must stay open" % map_id)
		assert_eq(railing_mismatches, 0, "%s water edges must show solid orientation-correct railings" % map_id)


func test_synthetic_mountain_building_and_wall_are_visibly_blocked() -> void:
	var definition := {
		"layout": {
			"world_tiles": [24, 16],
			"base_tile": "mud_a",
			"start_tile": [2, 8],
			"highlands": [],
			"landmarks": [],
			"spawn_lanes": [[[2, 6], [22, 6]]],
			"areas": [
				{"kind": "water", "rect": [8, 4, 4, 8]},
				{"kind": "bridge", "rect": [8, 7, 4, 3]},
				{"kind": "mountain", "rect": [18, 2, 3, 3]},
				{"kind": "building", "rect": [2, 2, 4, 3]},
				{"kind": "wall", "rect": [6, 12, 8, 2]},
				{"kind": "props", "prop": "crate", "rect": [10, 5, 1, 1], "density": 1.0, "solid": true}
			]
		}
	}
	var built := _build_definition("semantic_fixture", definition)
	var layout: MapLayout = built["layout"] as MapLayout
	var renderer: MapRenderer = built["renderer"] as MapRenderer
	assert_eq(layout.last_repair_count, 0, "semantic fixture must remain unrepaired")
	for y in range(2, 5):
		for x in range(18, 21):
			var cell := Vector2i(x, y)
			assert_true(layout.is_solid_cell(cell), "mountain %s must block movement" % cell)
			assert_true(renderer.terrain_tile_name(cell).begins_with("mountain_"), "mountain must show opaque rock")
			assert_true(
				layout.minimap_texture.get_image().get_pixel(cell.x, cell.y).is_equal_approx(
					layout.minimap_color_for_tile(renderer.terrain_tile_name(cell))
				),
				"mountain minimap must use the rock color"
			)
	for y in range(2, 5):
		for x in range(2, 6):
			var cell := Vector2i(x, y)
			assert_true(layout.is_solid_cell(cell), "building %s must block movement" % cell)
			assert_false(renderer.architecture_tile_name(cell).is_empty(), "building must show walls or roof")
	for y in range(12, 14):
		for x in range(6, 14):
			var cell := Vector2i(x, y)
			assert_true(layout.is_solid_cell(cell), "wall %s must block movement" % cell)
			assert_false(renderer.architecture_tile_name(cell).is_empty(), "wall must show masonry")
	assert_true(layout.is_cell_walkable(Vector2i(9, 5)), "ordinary water must remain wadeable")
	assert_true(layout.is_wade_position((Vector2(9, 5) + Vector2.ONE * 0.5) * MapLayout.TILE_SIZE))
	assert_true(layout.is_cell_walkable(Vector2i(9, 8)), "bridge center must remain open")
	assert_false(layout.is_wade_position((Vector2(9, 8) + Vector2.ONE * 0.5) * MapLayout.TILE_SIZE))
	assert_true(layout.is_solid_cell(Vector2i(8, 7)), "water-span railing must block movement")
	assert_eq(renderer.architecture_tile_name(Vector2i(8, 7)), "wood_railing")
	assert_true(layout.is_cell_walkable(Vector2i(7, 8)), "west bridge landing must remain open")
	assert_true(layout.is_cell_walkable(Vector2i(12, 8)), "east bridge landing must remain open")
	assert_true(layout.is_solid_cell(Vector2i(10, 5)), "solid prop in water must block movement")
	assert_eq(renderer.prop_tile_name(Vector2i(10, 5)), "crate")
	assert_false(layout.is_wade_position((Vector2(10, 5) + Vector2.ONE * 0.5) * MapLayout.TILE_SIZE), "solid water obstacles must not count as wading")


func test_wading_slows_units_and_bridge_stays_dry() -> void:
	var built := _build_map("watergate")
	var layout: MapLayout = built["layout"] as MapLayout
	var field := Battlefield.new()
	field.map_layout = layout
	var canal := Vector2(36 * 32.0 + 16.0, 72 * 32.0 + 16.0)
	var bridge := Vector2(36 * 32.0 + 16.0, 47 * 32.0 + 16.0)
	assert_almost_eq(field.wade_speed_factor(canal), 0.62, 0.001, "plain water must slow every unit")
	assert_almost_eq(field.wade_speed_factor(canal, 0.4), 0.772, 0.002, "wade upgrade must restore speed")
	assert_almost_eq(field.wade_speed_factor(bridge), 1.0, 0.001, "bridge deck must not slow units")
	field.free()


func test_every_map_reports_full_spawn_connectivity_and_needs_no_repair() -> void:
	for map_id in ["tideland", "watergate", "crossstreet"]:
		var built := _build_map(map_id)
		var layout: MapLayout = built["layout"] as MapLayout
		var report := layout.connectivity_report()
		assert_true(bool(report["start_walkable"]), "%s start must be walkable" % map_id)
		assert_eq(int(report["blocked"]), 0, "%s must have no blocked spawn lane" % map_id)
		assert_true(bool(report["ok"]), "%s connectivity report must pass" % map_id)
		assert_gt(int(report["samples"]), 20)
		assert_eq((report["blocked_points"] as Array).size(), 0, "%s report must expose no blocked points" % map_id)
		assert_eq(layout.last_repair_count, 0, "%s must already be connected before repair" % map_id)
		assert_eq(layout.initial_blocked_points.size(), 0, "%s must never need a repair pass" % map_id)
		var reachable := layout.walkable_reachability(layout.start_pos)
		var walkable := 0
		for index in range(reachable.size()):
			if reachable[index] == 1:
				walkable += 1
		assert_gt(walkable, 2000, "%s must expose a large connected playable area" % map_id)


func test_each_map_start_landmarks_and_bridgeheads_are_walkable() -> void:
	for map_id in ["tideland", "watergate", "crossstreet"]:
		var built := _build_map(map_id)
		var layout: MapLayout = built["layout"] as MapLayout
		var renderer: MapRenderer = built["renderer"] as MapRenderer
		var definition: Dictionary = built["definition"] as Dictionary
		assert_true(layout.is_point_walkable(layout.start_pos), "%s start must be walkable" % map_id)
		var start_tile := renderer.terrain_tile_name(layout.world_to_cell(layout.start_pos))
		assert_true(
			start_tile.begins_with("stone_road")
			or start_tile.begins_with("earth_road")
			or start_tile.begins_with("wet_stone"),
			"%s start must stand on a real road, got %s" % [map_id, start_tile]
		)
		for landmark in layout.landmark_entries():
			var cell: Vector2i = landmark["cell"] as Vector2i
			assert_true(layout.cell_in_bounds(cell), "%s landmark %s must stay in bounds" % [map_id, landmark["name_zh"]])
			assert_true(
				layout.is_point_walkable((Vector2(cell) + Vector2.ONE * 0.5) * MapLayout.TILE_SIZE, 14.0),
				"%s landmark %s must be reachable ground" % [map_id, landmark["name_zh"]]
			)
		var layout_data: Dictionary = definition["layout"] as Dictionary
		var bridge_count := 0
		for area in layout_data.get("areas", []) as Array:
			if not area is Dictionary or str((area as Dictionary).get("kind", "")) != "bridge":
				continue
			bridge_count += 1
			var rect := _area_rect(area as Dictionary)
			var horizontal := rect.size.x >= rect.size.y
			var fixed := rect.position.y + rect.size.y / 2 if horizontal else rect.position.x + rect.size.x / 2
			var endpoints: Array[Vector2i] = []
			if horizontal:
				endpoints = [
					Vector2i(rect.position.x - 1, fixed),
					Vector2i(rect.end.x, fixed),
				]
			else:
				endpoints = [
					Vector2i(fixed, rect.position.y - 1),
					Vector2i(fixed, rect.end.y),
				]
			for endpoint in endpoints:
				if not layout.cell_in_bounds(endpoint):
					continue
				assert_true(
					layout.is_point_walkable((Vector2(endpoint) + Vector2.ONE * 0.5) * MapLayout.TILE_SIZE, 14.0),
					"%s bridge %s landing %s must be walkable" % [map_id, rect, endpoint]
				)
		assert_gt(bridge_count, 5, "%s must expose several real bridgeheads" % map_id)


func test_map_paths_groves_and_buildings_are_data_complete() -> void:
	var maps := GameData.get_maps()
	for map_id in ["tideland", "watergate", "crossstreet"]:
		var definition: Dictionary = maps[map_id] as Dictionary
		var layout_data: Dictionary = definition["layout"] as Dictionary
		var size_data: Array = layout_data.get("world_tiles", [0, 0]) as Array
		var world_size := Vector2i(int(size_data[0]), int(size_data[1]))
		var counts := {
			"path": 0,
			"water_path": 0,
			"grove": 0,
			"bridge": 0,
		}
		var building_sizes := {}
		var building_styles := {}
		for area in layout_data.get("areas", []) as Array:
			var item := area as Dictionary
			var kind := str(item.get("kind", ""))
			if counts.has(kind):
				counts[kind] = int(counts[kind]) + 1
			if kind == "path" or kind == "water_path":
				var points: Array = item.get("points", []) as Array
				assert_gte(points.size(), 2, "%s %s needs a polyline" % [map_id, kind])
				assert_gte(float(item.get("width", 0.0)), 3.0, "%s %s needs real width" % [map_id, kind])
				for point_value in points:
					var point: Array = point_value as Array
					assert_true(
						float(point[0]) >= 0.0 and float(point[0]) <= float(world_size.x)
						and float(point[1]) >= 0.0 and float(point[1]) <= float(world_size.y),
						"%s %s point %s must stay in bounds" % [map_id, kind, point]
					)
			if kind == "grove":
				var density := float(item.get("density", -1.0))
				assert_true(density > 0.0 and density <= 1.0, "%s grove density must be bounded" % map_id)
			if kind == "building":
				var rect := _area_rect(item)
				assert_gt(rect.size.x, 0)
				assert_gt(rect.size.y, 0)
				building_sizes["%dx%d" % [rect.size.x, rect.size.y]] = true
				building_styles[str(item.get("style", "house"))] = true
		assert_gte(int(counts["path"]), 5, "%s needs a connected path network" % map_id)
		assert_gte(int(counts["water_path"]), 2, "%s needs organic creeks/canals" % map_id)
		assert_gte(int(counts["grove"]), 4, "%s needs planted courtyards or groves" % map_id)
		assert_gte(int(counts["bridge"]), 6, "%s needs real crossings" % map_id)
		assert_gte(building_sizes.size(), 4, "%s buildings need varied footprints" % map_id)
		assert_gte(building_styles.size(), 2, "%s buildings need varied facades" % map_id)


func test_connectivity_repair_opens_a_blocked_spawn_lane() -> void:
	var built := _build_map("tideland")
	var layout: MapLayout = built["layout"] as MapLayout
	var renderer: MapRenderer = built["renderer"] as MapRenderer
	# 人为用有可见墙体的实心带把整张图横向切断，模拟布局/生成把关键路径堵死。
	var wall_x := int(layout.world_tiles.x / 2)
	var painted_wall_cells: Array[Vector2i] = []
	for y in layout.world_tiles.y:
		for x in range(wall_x, wall_x + 2):
			var cell := Vector2i(x, y)
			renderer._place_architecture(cell, "stone_wall_a")
			if y % 5 == 0:
				renderer._place_prop(cell, "crate")
			layout.mark_solid_rect(Rect2i(cell, Vector2i.ONE))
			painted_wall_cells.append(cell)
	assert_false(bool(layout.connectivity_report()["ok"]), "artificial wall must break connectivity")
	var repaired := layout.repair_connectivity()
	assert_gt(repaired, 0, "repair must report the lanes it opened")
	assert_true(bool(layout.connectivity_report()["ok"]), "repair must restore full connectivity")
	var repaired_cells := layout.repaired_cell_list()
	assert_gt(repaired_cells.size(), 0, "repair must expose every carved cell to the renderer")
	var minimap := layout.minimap_texture.get_image()
	var erased_wall_cells := 0
	for cell in repaired_cells:
		assert_true(layout.is_cell_walkable(cell), "repaired cell %s must be walkable" % cell)
		assert_eq(renderer.architecture_tile_name(cell), "", "repair must erase stale architecture at %s" % cell)
		assert_eq(renderer.prop_tile_name(cell), "", "repair must erase stale props at %s" % cell)
		var tile_name := renderer.terrain_tile_name(cell)
		if layout.is_water_cell(cell):
			assert_true(layout.is_bridge_cell(cell), "repaired water must become a dry bridge")
			assert_false(layout.is_wade_position((Vector2(cell) + Vector2.ONE * 0.5) * MapLayout.TILE_SIZE))
			assert_eq(tile_name, "dock_horizontal", "repaired water must show bridge planking")
		else:
			assert_false(layout.is_bridge_cell(cell), "repaired land must not be marked as bridge")
			assert_true(tile_name == "earth_road_a" or tile_name == "earth_road_b", "repaired land must show a road")
		assert_true(
			minimap.get_pixel(cell.x, cell.y).is_equal_approx(layout.minimap_color_for_tile(tile_name)),
			"repair minimap must match visible terrain at %s" % cell
		)
		if painted_wall_cells.has(cell) and renderer.architecture_tile_name(cell).is_empty():
			erased_wall_cells += 1
	assert_gt(erased_wall_cells, 0, "repair must visibly remove the blocking wall where it cuts through")


func test_buildings_stay_off_roads_and_water() -> void:
	var maps := GameData.get_maps()
	for map_id in maps.keys():
		var built := _build_map(map_id)
		var renderer: MapRenderer = built["renderer"] as MapRenderer
		var layout_data: Dictionary = (maps[map_id] as Dictionary).get("layout", {}) as Dictionary
		var roads: Array[Rect2i] = []
		var buildings: Array[Rect2i] = []
		var waters: Array[Rect2i] = []
		var street_cells := {}
		var water_cells := {}
		for area in layout_data.get("areas", []) as Array:
			var item := area as Dictionary
			var kind := str(item.get("kind", ""))
			if kind == "road" or kind == "plaza":
				roads.append(_area_rect(item))
			elif kind == "building":
				buildings.append(_area_rect(item))
			elif kind == "water":
				waters.append(_area_rect(item))
			elif kind == "path":
				for cell in renderer._ribbon_cells(renderer._area_points(item), float(item.get("width", 4.0)), 71, 0.42):
					street_cells[cell] = true
			elif kind == "water_path" or kind == "creek":
				for cell in renderer._ribbon_cells(renderer._area_points(item), float(item.get("width", 6.0)), 113, 0.55):
					water_cells[cell] = true
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
		for building in buildings:
			for y in range(building.position.y, building.end.y):
				for x in range(building.position.x, building.end.x):
					var cell := Vector2i(x, y)
					assert_false(street_cells.has(cell), "%s building %s covers live path at %s" % [map_id, building, cell])
					assert_false(water_cells.has(cell), "%s building %s covers water_path at %s" % [map_id, building, cell])


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


func test_incremental_flow_field_matches_synchronous_build() -> void:
	var definition: Dictionary = (GameData.get_maps()["watergate"] as Dictionary).duplicate(true)
	var synchronous: MapLayout = MapLayout.new()
	synchronous.setup("watergate", definition)
	synchronous.finalize()
	var incremental: MapLayout = MapLayout.new()
	incremental.setup("watergate", definition)
	incremental.finalize()
	var target := synchronous.start_pos + Vector2(320.0, -160.0)
	synchronous.ensure_flow_field(target)
	incremental.request_flow_field(target)
	var completed := false
	for _frame in range(256):
		if incremental.advance_flow_field(256):
			completed = true
			break
	assert_true(completed, "incremental flow field must finish within its cell budget")
	assert_eq(
		incremental._flow_next_cells,
		synchronous._flow_next_cells,
		"incremental 8-neighbor BFS must match the synchronous reference"
	)
	assert_eq(incremental.flow_direction(incremental.start_pos), synchronous.flow_direction(synchronous.start_pos))


func test_flow_request_during_build_starts_after_swap() -> void:
	var built := _build_map("crossstreet")
	var layout: MapLayout = built["layout"] as MapLayout
	layout.request_flow_field(layout.start_pos + Vector2(320.0, -160.0))
	assert_true(layout._flow_build_active, "the first flow build must be active")
	var second_target := layout.start_pos + Vector2(640.0, 320.0)
	var second_cell := layout.world_to_cell(layout.find_walkable_position(second_target))
	layout.request_flow_field(second_target)
	var completed := 0
	for _frame in range(2048):
		if not layout.advance_flow_field(256):
			continue
		completed += 1
		if completed == 1:
			assert_true(layout._flow_build_active, "the latest target must start immediately")
			assert_eq(layout._flow_build_target_cell, second_cell)
		elif completed >= 2:
			break
	assert_eq(completed, 2, "both queued flow builds must complete")
	assert_eq(layout._flow_target_cell, second_cell)


func test_spawn_candidates_remain_available_during_incremental_build() -> void:
	var built := _build_map("crossstreet")
	var layout: MapLayout = built["layout"] as MapLayout
	layout.request_flow_field(layout.start_pos + Vector2(480.0, 320.0))
	assert_true(layout._flow_build_active, "the incremental build must be active")
	var candidates := layout.spawn_candidates(layout.start_pos, 300.0, 1400.0)
	assert_gt(candidates.size(), 0, "spawning must not wait for the next flow-field build")
	assert_true(layout._flow_build_active, "spawning must not force the incremental build to finish")


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
	assert_false(
		run.camera.position_smoothing_enabled,
		"the run camera must use the single explicit smoothing path"
	)
	GameSettings.web_platform_override = 1
	assert_eq(
		run.max_catchup_steps(),
		2,
		"Web must catch up to real time down to 30 FPS without unbounded step spikes"
	)
	GameSettings.web_platform_override = 0
	assert_eq(run.max_catchup_steps(), 6, "native builds keep the existing catch-up budget")
	GameSettings.web_platform_override = -1
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


func test_minimap_camera_window_tracks_expanded_viewport_and_zoom() -> void:
	var minimap := RunMinimap.new()
	assert_eq(minimap.camera_half_view(Vector2(1526.0, 720.0)), Vector2(763.0, 360.0))
	assert_eq(
		minimap.camera_half_view(Vector2(1526.0, 720.0), Vector2(2.0, 2.0)),
		Vector2(381.5, 180.0)
	)
	minimap.free()


func _build_map(map_id: String) -> Dictionary:
	var definition: Dictionary = (GameData.get_maps()[map_id] as Dictionary).duplicate(true)
	return _build_definition(map_id, definition)


func _build_definition(map_id: String, definition: Dictionary) -> Dictionary:
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
		var kind := str(item.get("kind", ""))
		if kind == "water_path" or kind == "creek":
			var points: Array = item.get("points", []) as Array
			if points.size() < 2:
				continue
			var min_y := 1000000.0
			var max_y := -1000000.0
			var average_x := 0.0
			var width := float(item.get("width", 0.0))
			for point_value in points:
				var point: Array = point_value as Array
				var y := float(point[1])
				min_y = minf(min_y, y)
				max_y = maxf(max_y, y)
				average_x += float(point[0])
			average_x /= float(points.size())
			if max_y - min_y >= 150.0 and width >= 4.0 and average_x > 4.0 and average_x < float(world_width - 4):
				count += 1
			continue
		if kind != "water":
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
