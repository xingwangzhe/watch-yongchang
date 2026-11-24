class_name MapRenderer
extends Node2D

const TILE := 32
const TILE_INDEX_PATH := "res://data/yongchang_tiles.json"

## 阴影/描边层：画在地形之上、建筑与道具之下，用来强化路径、水岸和高低地层次。
class ShadeLayer extends Node2D:
	var draw_callback: Callable

	func _draw() -> void:
		if draw_callback.is_valid():
			draw_callback.call(self)
		else:
			queue_redraw()


var layout: MapLayout
var terrain_layer: TileMapLayer
var architecture_layer: TileMapLayer
var props_layer: TileMapLayer
var shade_layer: ShadeLayer

var _atlas_config: Dictionary = {}
var _indices: Dictionary = {}
var _source_ids: Dictionary = {}
var _water_cells: Dictionary = {}
var _road_cells: Dictionary = {}
var _bridge_cells: Dictionary = {}
var _bridge_orientations: Dictionary = {}
var _obstacle_cells: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _shading_ready := false


func build(map_layout: MapLayout, _map_definition: Dictionary, seed_value: int) -> void:
	layout = map_layout
	if not layout.connectivity_repaired.is_connected(_on_connectivity_repaired):
		layout.connectivity_repaired.connect(_on_connectivity_repaired)
	_rng.seed = seed_value
	_water_cells.clear()
	_road_cells.clear()
	_bridge_cells.clear()
	_bridge_orientations.clear()
	_obstacle_cells.clear()
	_shading_ready = false
	z_index = -50
	_atlas_config = GameData.load_json(TILE_INDEX_PATH).get("atlases", {}) as Dictionary
	_build_tile_index()
	_make_layers()
	_paint_base()
	for area in layout.areas:
		if area is Dictionary:
			_paint_area(area as Dictionary)
	_beautify_water_edges()
	layout.finalize()
	_paint_repair_cells(layout.repaired_cell_list())
	_shading_ready = true
	if shade_layer != null:
		shade_layer.queue_redraw()


func _build_tile_index() -> void:
	_indices.clear()
	for atlas_key in _atlas_config.keys():
		var atlas: Dictionary = _atlas_config[atlas_key] as Dictionary
		var lookup: Dictionary = {}
		var names: Array = atlas.get("tiles", []) as Array
		for index in range(names.size()):
			lookup[str(names[index])] = index
		_indices[atlas_key] = lookup


func _make_layers() -> void:
	terrain_layer = _make_layer("terrain", "TerrainLayer", 0)
	shade_layer = ShadeLayer.new()
	shade_layer.name = "ShadeLayer"
	shade_layer.z_index = 1
	shade_layer.draw_callback = _draw_shading
	add_child(shade_layer)
	architecture_layer = _make_layer("architecture", "ArchitectureLayer", 2)
	props_layer = _make_layer("props", "PropsLayer", 3)


func _make_layer(atlas_key: String, node_name: String, z: int) -> TileMapLayer:
	var atlas: Dictionary = _atlas_config[atlas_key] as Dictionary
	var texture := load(str(atlas["path"])) as Texture2D
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	var columns := int(atlas.get("columns", 8))
	var rows := int(atlas.get("rows", 4))
	for y in rows:
		for x in columns:
			source.create_tile(Vector2i(x, y))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	var source_id := tile_set.add_source(source)
	var layer := TileMapLayer.new()
	layer.name = node_name
	layer.tile_set = tile_set
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_index = z
	add_child(layer)
	_source_ids[atlas_key] = source_id
	return layer


func _paint_base() -> void:
	var variants := [layout.base_tile]
	if layout.base_tile.ends_with("_a"):
		variants.append(layout.base_tile.trim_suffix("_a") + "_b")
	elif layout.base_tile.ends_with("_b"):
		variants.append(layout.base_tile.trim_suffix("_b") + "_a")
	for y in layout.world_tiles.y:
		for x in layout.world_tiles.x:
			var cell := Vector2i(x, y)
			_place_terrain(cell, _pick_name(variants, cell))


func _paint_area(area: Dictionary) -> void:
	var rect := _area_rect(area)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	match str(area.get("kind", "terrain")):
		"terrain", "sand", "mud", "grass":
			_paint_terrain_area(area, rect)
		"road", "plaza":
			_paint_road_area(area, rect)
		"water":
			_paint_water_area(area, rect)
		"bridge":
			_paint_bridge_area(area, rect)
		"wall":
			_paint_wall_area(rect, false)
		"tower":
			_paint_wall_area(rect, true)
		"building":
			_paint_building_area(rect)
		"mountain":
			_paint_mountain_area(area, rect)
		"gate":
			_paint_gate_area(rect, false)
		"water_gate":
			_paint_gate_area(rect, true)
		"reeds":
			_paint_reeds_area(area, rect)
		"props":
			_paint_props_area(area, rect)


func _paint_terrain_area(area: Dictionary, rect: Rect2i) -> void:
	var variants := _area_tiles(area)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			if layout.is_water_cell(cell) or layout.is_bridge_cell(cell) or layout.is_solid_cell(cell):
				continue
			var tile_name := _pick_name(variants, cell)
			if _place_terrain(cell, tile_name):
				layout.set_minimap_color(cell, layout.minimap_color_for_tile(tile_name))


func _paint_road_area(area: Dictionary, rect: Rect2i) -> void:
	var variants := _area_tiles(area)
	if variants.is_empty():
		variants = ["stone_road_a", "stone_road_b"]
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			if layout.is_water_cell(cell) or layout.is_bridge_cell(cell) or layout.is_solid_cell(cell):
				continue
			var tile_name := _pick_name(variants, cell)
			if not _place_terrain(cell, tile_name):
				continue
			_road_cells[cell] = true
			_obstacle_cells.erase(cell)
			layout.set_minimap_color(cell, layout.minimap_color_for_tile(tile_name))


func _paint_water_area(area: Dictionary, rect: Rect2i) -> void:
	var variants := _area_tiles(area)
	if variants.is_empty():
		variants = ["water_deep_a", "water_deep_b"]
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			var tile_name := _pick_name(variants, cell)
			if not _place_terrain(cell, tile_name):
				continue
			layout.mark_water_rect(Rect2i(cell, Vector2i.ONE))
			_water_cells[cell] = true
			_road_cells.erase(cell)
			layout.set_minimap_color(cell, layout.minimap_color_for_tile(tile_name))


func _paint_bridge_area(_area: Dictionary, rect: Rect2i) -> void:
	var horizontal := rect.size.x >= rect.size.y
	var bridge_tile := "dock_horizontal" if horizontal else "dock_vertical"
	var railing_tile := "wood_railing" if horizontal else "wood_railing_vertical"
	var crossing_width := rect.size.y if horizontal else rect.size.x
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			if not _place_terrain(cell, bridge_tile):
				continue
			layout.mark_bridge_rect(Rect2i(cell, Vector2i.ONE))
			_bridge_cells[cell] = true
			_bridge_orientations[cell] = horizontal
			_road_cells.erase(cell)
			if not layout.is_solid_cell(cell):
				_obstacle_cells.erase(cell)
				layout.set_minimap_color(cell, MapLayout.MINIMAP_BRIDGE)
	# 栏杆只挡真正跨水的边缘；陆上的桥头保持开放，避免封住相接的街道。
	if crossing_width < 3:
		return
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell) or not layout.is_water_cell(cell):
				continue
			var is_railing := false
			if horizontal:
				is_railing = y == rect.position.y or y == rect.position.y + rect.size.y - 1
			else:
				is_railing = x == rect.position.x or x == rect.position.x + rect.size.x - 1
			if not is_railing or not _bridge_cells.has(cell):
				continue
			if not _place_architecture(cell, railing_tile):
				continue
			layout.mark_solid_rect(Rect2i(cell, Vector2i.ONE))
			_obstacle_cells[cell] = true
			layout.set_minimap_color(cell, MapLayout.MINIMAP_BRIDGE_RAILING)


func _paint_wall_area(rect: Rect2i, tower: bool) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			var tile_name := "stone_wall_a"
			if (x + y * 3) % 7 == 0:
				tile_name = "stone_wall_b"
			elif (x * 5 + y) % 11 == 0:
				tile_name = "stone_wall_moss"
			if tower and (x == rect.position.x or x == rect.position.x + rect.size.x - 1):
				tile_name = "wall_cap"
			if y == rect.position.y:
				tile_name = "merlon" if not tower else "wall_cap"
			if not _place_architecture(cell, tile_name):
				continue
			_place_terrain(cell, "gravel")
			cancel_water(cell)
			_road_cells.erase(cell)
			_obstacle_cells[cell] = true
			layout.mark_solid_rect(Rect2i(cell, Vector2i.ONE))
			layout.set_minimap_color(cell, Color("#243333") if not tower else Color("#354947"))
	if tower:
		_place_architecture(rect.position, "wall_corner")
		_place_architecture(Vector2i(rect.end.x - 1, rect.position.y), "wall_corner")
		_place_architecture(Vector2i(rect.position.x, rect.end.y - 1), "wall_corner")
		_place_architecture(Vector2i(rect.end.x - 1, rect.end.y - 1), "wall_corner")


func _paint_building_area(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			var local_x := x - rect.position.x
			var local_y := y - rect.position.y
			var tile_name := "roof_slope"
			if local_y == 0:
				tile_name = "roof_ridge"
			elif local_y == rect.size.y - 1:
				tile_name = "roof_eave"
			if local_x == 0 or local_x == rect.size.x - 1:
				tile_name = "roof_corner"
			if not _place_architecture(cell, tile_name):
				continue
			cancel_water(cell)
			_place_terrain(cell, "wet_stone")
			_road_cells.erase(cell)
			_obstacle_cells[cell] = true
			layout.mark_solid_rect(Rect2i(cell, Vector2i.ONE))
			layout.set_minimap_color(cell, Color("#503d35"))
	if rect.size.x >= 5 and rect.size.y >= 3:
		var door_cell := Vector2i(
			rect.position.x + rect.size.x / 2,
			rect.position.y + rect.size.y - 1
		)
		_place_architecture(door_cell, "plaster_door")


func _paint_mountain_area(area: Dictionary, rect: Rect2i) -> void:
	var variants := _area_tiles(area)
	if variants.is_empty():
		variants = ["mountain_a", "mountain_b", "mountain_c", "mountain_d"]
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			var tile_name := _pick_name(variants, cell)
			if not _place_terrain(cell, tile_name):
				continue
			cancel_water(cell)
			_road_cells.erase(cell)
			_obstacle_cells[cell] = true
			layout.mark_solid_rect(Rect2i(cell, Vector2i.ONE))
			layout.set_minimap_color(cell, layout.minimap_color_for_tile(tile_name))


func _paint_gate_area(rect: Rect2i, water_gate: bool) -> void:
	var horizontal := rect.size.x >= rect.size.y
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			var was_bridge := layout.is_bridge_cell(cell)
			var bridge_horizontal := horizontal
			if was_bridge:
				bridge_horizontal = bool(_bridge_orientations.get(cell, horizontal))
			var terrain_name := "wet_stone" if water_gate else "stone_road_a"
			var architecture_name := "water_gate_arch" if water_gate else "land_gate_arch"
			if not _place_terrain(cell, terrain_name) or not _place_architecture(cell, architecture_name):
				continue
			cancel_water(cell)
			layout.clear_solid_rect(Rect2i(cell, Vector2i.ONE))
			if water_gate:
				_road_cells.erase(cell)
			else:
				_road_cells[cell] = true
			if water_gate or was_bridge:
				layout.mark_bridge_rect(Rect2i(cell, Vector2i.ONE))
				_bridge_cells[cell] = true
				_bridge_orientations[cell] = bridge_horizontal
			_obstacle_cells.erase(cell)
			layout.set_minimap_color(cell, Color("#d8b15e"))


func _paint_reeds_area(area: Dictionary, rect: Rect2i) -> void:
	var variants := _area_tiles(area)
	if variants.is_empty():
		variants = ["reed_bed"]
	var density := float(area.get("density", 0.22))
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			if layout.is_bridge_cell(cell) or layout.is_solid_cell(cell):
				continue
			if not layout.is_water_cell(cell):
				var tile_name := _pick_name(variants, cell)
				if _place_terrain(cell, tile_name):
					layout.set_minimap_color(cell, layout.minimap_color_for_tile(tile_name))
			if float(_hash_cell(cell, 97)) / 1000003.0 < density:
				_place_prop(cell, "reeds" if _hash_cell(cell, 31) % 3 else "grass")


func _paint_props_area(area: Dictionary, rect: Rect2i) -> void:
	var prop_name := str(area.get("prop", "reeds"))
	var density := float(area.get("density", 0.50))
	var solid := bool(area.get("solid", false))
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			if layout.is_solid_cell(cell) or layout.is_bridge_cell(cell):
				continue
			if density < 1.0 and float(_hash_cell(cell, 53)) / 1000003.0 > density:
				continue
			if not _place_prop(cell, prop_name):
				continue
			if solid:
				layout.mark_solid_rect(Rect2i(cell, Vector2i.ONE))
				_obstacle_cells[cell] = true
				layout.set_minimap_color(cell, Color("#3b3d32"))


func _beautify_water_edges() -> void:
	for cell in _water_cells.keys():
		var water_cell := cell as Vector2i
		if layout.is_bridge_cell(water_cell) or layout.is_solid_cell(water_cell):
			continue
		var edge := false
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not _water_cells.has(water_cell + direction) and not layout.is_bridge_cell(water_cell + direction):
				edge = true
				break
		if edge:
			var tile_name := "water_shallow_a" if _hash_cell(water_cell, 13) % 2 == 0 else "water_shallow_b"
			if _place_terrain(water_cell, tile_name):
				layout.set_minimap_color(water_cell, layout.minimap_color_for_tile(tile_name))


func cancel_water(cell: Vector2i) -> void:
	layout.clear_water_rect(Rect2i(cell, Vector2i.ONE))
	layout.clear_bridge_rect(Rect2i(cell, Vector2i.ONE))
	_water_cells.erase(cell)
	_bridge_cells.erase(cell)
	_bridge_orientations.erase(cell)


func _place_terrain(cell: Vector2i, tile_name: String) -> bool:
	return _place(terrain_layer, "terrain", cell, tile_name)


func _place_architecture(cell: Vector2i, tile_name: String) -> bool:
	return _place(architecture_layer, "architecture", cell, tile_name)


func _place_prop(cell: Vector2i, tile_name: String) -> bool:
	return _place(props_layer, "props", cell, tile_name)


func _place(layer: TileMapLayer, atlas_key: String, cell: Vector2i, tile_name: String) -> bool:
	if not layer.tile_set or not _indices.has(atlas_key):
		return false
	var lookup: Dictionary = _indices[atlas_key] as Dictionary
	if not lookup.has(tile_name):
		return false
	var index := int(lookup[tile_name])
	var atlas_coords := Vector2i(index % 8, index / 8)
	layer.set_cell(cell, int(_source_ids[atlas_key]), atlas_coords, 0)
	return true


func _on_connectivity_repaired(cells: Array) -> void:
	_paint_repair_cells(cells)


func _paint_repair_cells(cells: Array) -> void:
	if cells.is_empty():
		return
	for value in cells:
		var cell := value as Vector2i
		if not layout.cell_in_bounds(cell):
			continue
		architecture_layer.erase_cell(cell)
		props_layer.erase_cell(cell)
		_obstacle_cells.erase(cell)
		var tile_name := "earth_road_a" if _hash_cell(cell, 7) % 2 == 0 else "earth_road_b"
		if layout.is_bridge_cell(cell):
			tile_name = "dock_horizontal"
			_bridge_cells[cell] = true
			_bridge_orientations[cell] = true
			_road_cells.erase(cell)
		else:
			_bridge_cells.erase(cell)
			_bridge_orientations.erase(cell)
			_road_cells[cell] = true
		if layout.is_water_cell(cell):
			_water_cells[cell] = true
		else:
			_water_cells.erase(cell)
		if _place_terrain(cell, tile_name):
			layout.set_minimap_color(cell, layout.minimap_color_for_tile(tile_name))
	if shade_layer != null:
		shade_layer.queue_redraw()


func terrain_tile_name(cell: Vector2i) -> String:
	return _tile_name_at(terrain_layer, "terrain", cell)


func architecture_tile_name(cell: Vector2i) -> String:
	return _tile_name_at(architecture_layer, "architecture", cell)


func prop_tile_name(cell: Vector2i) -> String:
	return _tile_name_at(props_layer, "props", cell)


func _tile_name_at(layer: TileMapLayer, atlas_key: String, cell: Vector2i) -> String:
	if layer == null or layer.get_cell_source_id(cell) < 0:
		return ""
	var coords := layer.get_cell_atlas_coords(cell)
	var atlas: Dictionary = _atlas_config.get(atlas_key, {}) as Dictionary
	var columns := int(atlas.get("columns", 8))
	var index := coords.x + coords.y * columns
	var names: Array = atlas.get("tiles", []) as Array
	if index < 0 or index >= names.size():
		return ""
	return str(names[index])


func _area_rect(area: Dictionary) -> Rect2i:
	var data: Array = area.get("rect", [0, 0, 0, 0]) as Array
	return Rect2i(int(data[0]), int(data[1]), int(data[2]), int(data[3]))


func _area_tiles(area: Dictionary) -> Array:
	if area.has("tiles"):
		return area.get("tiles", []) as Array
	if area.has("tile"):
		return [str(area.get("tile", ""))]
	return []


func _pick_name(variants: Array, cell: Vector2i) -> String:
	if variants.is_empty():
		return "mud_a"
	return str(variants[_hash_cell(cell, 7) % variants.size()])


func _hash_cell(cell: Vector2i, salt: int) -> int:
	var value := cell.x * 92837111 + cell.y * 689287499 + salt * 283923481
	return abs(value) % 1000003


func _draw_shading(target: CanvasItem) -> void:
	if not _shading_ready or layout == null:
		return
	var tile := float(TILE)
	# 1) 高地：暖色薄染 + 北/西受光边 + 南侧投影，让台地一眼可辨。
	for rect in layout.highland_rects:
		var origin := Vector2(rect.position) * tile
		var size := Vector2(rect.size) * tile
		target.draw_rect(Rect2(origin + Vector2(0, size.y), Vector2(size.x, 8)), Color(0.0, 0.0, 0.0, 0.16))
		target.draw_rect(Rect2(origin, size), Color(1.0, 0.86, 0.55, 0.045))
		target.draw_line(origin, origin + Vector2(size.x, 0), Color(1.0, 0.94, 0.72, 0.16), 2.0)
		target.draw_line(origin, origin + Vector2(0, size.y), Color(1.0, 0.94, 0.72, 0.10), 2.0)
		target.draw_line(
			origin + Vector2(0, size.y),
			origin + Vector2(size.x, size.y),
			Color(0.0, 0.0, 0.0, 0.14),
			5.0
		)

	# 2) 道路：只描外轮廓，让路径从地表里跳出来；桥面视为路面，不描边。
	for cell in _road_cells.keys():
		var road_cell := cell as Vector2i
		if _water_cells.has(road_cell) and not layout.is_bridge_cell(road_cell):
			continue
		var x0 := float(road_cell.x) * tile
		var y0 := float(road_cell.y) * tile
		var edge := Color(0.11, 0.09, 0.06, 0.55)
		if not _is_road_like(road_cell + Vector2i.UP):
			target.draw_line(Vector2(x0, y0), Vector2(x0 + tile, y0), edge, 2.0)
		if not _is_road_like(road_cell + Vector2i.DOWN):
			target.draw_line(Vector2(x0, y0 + tile), Vector2(x0 + tile, y0 + tile), edge, 2.0)
		if not _is_road_like(road_cell + Vector2i.LEFT):
			target.draw_line(Vector2(x0, y0), Vector2(x0, y0 + tile), edge, 2.0)
		if not _is_road_like(road_cell + Vector2i.RIGHT):
			target.draw_line(Vector2(x0 + tile, y0), Vector2(x0 + tile, y0 + tile), edge, 2.0)

	# 3) 桥面：只在朝水的一侧描连续投影，不在每块甲板上切出黑缝。
	for cell in _bridge_cells.keys():
		var bridge_cell := cell as Vector2i
		var horizontal := bool(_bridge_orientations.get(bridge_cell, true))
		var x0 := float(bridge_cell.x) * tile
		var y0 := float(bridge_cell.y) * tile
		if horizontal and not _bridge_cells.has(bridge_cell + Vector2i.DOWN):
			target.draw_line(Vector2(x0, y0 + tile), Vector2(x0 + tile, y0 + tile), Color(0.03, 0.07, 0.06, 0.42), 3.0)
		elif not horizontal and not _bridge_cells.has(bridge_cell + Vector2i.RIGHT):
			target.draw_line(Vector2(x0 + tile, y0), Vector2(x0 + tile, y0 + tile), Color(0.03, 0.07, 0.06, 0.42), 3.0)

	# 4) 水岸：深色岸线 + 外侧浅滩高光；桥头接缝不画成阻断水岸。
	for cell in _water_cells.keys():
		var water_cell := cell as Vector2i
		if layout.is_bridge_cell(water_cell):
			continue
		var x0 := float(water_cell.x) * tile
		var y0 := float(water_cell.y) * tile
		var x1 := x0 + tile
		var y1 := y0 + tile
		if not _water_cells.has(water_cell + Vector2i.UP) and not layout.is_bridge_cell(water_cell + Vector2i.UP):
			target.draw_line(Vector2(x0, y0), Vector2(x1, y0), Color(0.03, 0.11, 0.13, 0.55), 2.0)
			target.draw_line(Vector2(x0, y0 - 3.0), Vector2(x1, y0 - 3.0), Color(0.74, 0.66, 0.47, 0.16), 2.0)
		if not _water_cells.has(water_cell + Vector2i.DOWN) and not layout.is_bridge_cell(water_cell + Vector2i.DOWN):
			target.draw_line(Vector2(x0, y1), Vector2(x1, y1), Color(0.03, 0.11, 0.13, 0.55), 2.0)
		if not _water_cells.has(water_cell + Vector2i.LEFT) and not layout.is_bridge_cell(water_cell + Vector2i.LEFT):
			target.draw_line(Vector2(x0, y0), Vector2(x0, y1), Color(0.03, 0.11, 0.13, 0.55), 2.0)
			target.draw_line(Vector2(x0 - 3.0, y0), Vector2(x0 - 3.0, y1), Color(0.74, 0.66, 0.47, 0.14), 2.0)
		if not _water_cells.has(water_cell + Vector2i.RIGHT) and not layout.is_bridge_cell(water_cell + Vector2i.RIGHT):
			target.draw_line(Vector2(x1, y0), Vector2(x1, y1), Color(0.03, 0.11, 0.13, 0.55), 2.0)

	# 5) 障碍物：南/东侧落影，北/西侧受光，墙体、栏杆与屋顶不再与地面糊在一起。
	for cell in _obstacle_cells.keys():
		var solid_cell := cell as Vector2i
		var x0 := float(solid_cell.x) * tile
		var y0 := float(solid_cell.y) * tile
		var x1 := x0 + tile
		var y1 := y0 + tile
		if not _obstacle_cells.has(solid_cell + Vector2i.DOWN):
			target.draw_line(Vector2(x0, y1 + 3.0), Vector2(x1, y1 + 3.0), Color(0.0, 0.0, 0.0, 0.22), 4.0)
		if not _obstacle_cells.has(solid_cell + Vector2i.RIGHT):
			target.draw_line(Vector2(x1 + 3.0, y0), Vector2(x1 + 3.0, y1), Color(0.0, 0.0, 0.0, 0.18), 4.0)
		if not _obstacle_cells.has(solid_cell + Vector2i.UP):
			target.draw_line(Vector2(x0, y0), Vector2(x1, y0), Color(1.0, 0.93, 0.78, 0.16), 1.0)
		if not _obstacle_cells.has(solid_cell + Vector2i.LEFT):
			target.draw_line(Vector2(x0, y0), Vector2(x0, y1), Color(1.0, 0.93, 0.78, 0.10), 1.0)


func _is_road_like(cell: Vector2i) -> bool:
	if _road_cells.has(cell):
		return true
	if layout != null and layout.is_bridge_cell(cell):
		return true
	return false
