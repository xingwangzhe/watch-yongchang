class_name MapRenderer
extends Node2D

const TILE := 32
const TILE_INDEX_PATH := "res://data/yongchang_tiles.json"

var layout: MapLayout
var terrain_layer: TileMapLayer
var architecture_layer: TileMapLayer
var props_layer: TileMapLayer

var _atlas_config: Dictionary = {}
var _indices: Dictionary = {}
var _source_ids: Dictionary = {}
var _water_cells: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func build(map_layout: MapLayout, _map_definition: Dictionary, seed_value: int) -> void:
	layout = map_layout
	_rng.seed = seed_value
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
	architecture_layer = _make_layer("architecture", "ArchitectureLayer", 1)
	props_layer = _make_layer("props", "PropsLayer", 2)


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
			var tile_name := _pick_name(variants, cell)
			_place_terrain(cell, tile_name)
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
			var tile_name := _pick_name(variants, cell)
			_place_terrain(cell, tile_name)
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
			_place_terrain(cell, _pick_name(variants, cell))
			layout.mark_water_rect(Rect2i(cell, Vector2i.ONE))
			_water_cells[cell] = true
			layout.set_minimap_color(cell, Color("#163a45"))


func _paint_bridge_area(_area: Dictionary, rect: Rect2i) -> void:
	var horizontal := rect.size.x >= rect.size.y
	var bridge_tile := "dock_horizontal" if horizontal else "dock_vertical"
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			_place_terrain(cell, bridge_tile)
			layout.mark_bridge_rect(Rect2i(cell, Vector2i.ONE))
			layout.set_minimap_color(cell, Color("#c4a06b"))
	if horizontal:
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_place_architecture(Vector2i(x, rect.position.y), "wood_railing")
			_place_architecture(Vector2i(x, rect.position.y + rect.size.y - 1), "wood_railing")
	else:
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			_place_architecture(Vector2i(rect.position.x, y), "wood_railing")
			_place_architecture(Vector2i(rect.position.x + rect.size.x - 1, y), "wood_railing")


func _paint_wall_area(rect: Rect2i, tower: bool) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			_place_terrain(cell, "gravel")
			var tile_name := "stone_wall_a"
			if (x + y * 3) % 7 == 0:
				tile_name = "stone_wall_b"
			elif (x * 5 + y) % 11 == 0:
				tile_name = "stone_wall_moss"
			if tower and (x == rect.position.x or x == rect.position.x + rect.size.x - 1):
				tile_name = "wall_cap"
			if y == rect.position.y:
				tile_name = "merlon" if not tower else "wall_cap"
			_place_architecture(cell, tile_name)
			cancel_water(cell)
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
			_place_terrain(cell, "wet_stone")
			var local_x := x - rect.position.x
			var local_y := y - rect.position.y
			var tile_name := "roof_slope"
			if local_y == 0:
				tile_name = "roof_ridge"
			elif local_y == rect.size.y - 1:
				tile_name = "roof_eave"
			if local_x == 0 or local_x == rect.size.x - 1:
				tile_name = "roof_corner"
			_place_architecture(cell, tile_name)
			layout.mark_solid_rect(Rect2i(cell, Vector2i.ONE))
			layout.set_minimap_color(cell, Color("#503d35"))
	if rect.size.x >= 5 and rect.size.y >= 3:
		var door_cell := Vector2i(
			rect.position.x + rect.size.x / 2,
			rect.position.y + rect.size.y - 1
		)
		_place_architecture(door_cell, "plaster_door")


func _paint_gate_area(rect: Rect2i, water_gate: bool) -> void:
	layout.clear_solid_rect(rect)
	layout.clear_water_rect(rect)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			if water_gate:
				_place_terrain(cell, "wet_stone")
				layout.mark_bridge_rect(Rect2i(cell, Vector2i.ONE))
				_place_architecture(cell, "water_gate_arch")
			else:
				_place_terrain(cell, "stone_road_a")
				_place_architecture(cell, "land_gate_arch")
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
			var tile_name := _pick_name(variants, cell)
			_place_terrain(cell, tile_name)
			layout.set_minimap_color(cell, layout.minimap_color_for_tile(tile_name))
			if _hash_cell(cell, 97) < density:
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
			if solid:
				layout.mark_solid_rect(Rect2i(cell, Vector2i.ONE))
			if density < 1.0 and _hash_cell(cell, 53) > density:
				continue
			_place_prop(cell, prop_name)
			if solid:
				layout.set_minimap_color(cell, Color("#3b3d32"))


func _beautify_water_edges() -> void:
	for cell in _water_cells.keys():
		var water_cell := cell as Vector2i
		var edge := false
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not _water_cells.has(water_cell + direction):
				edge = true
				break
		if edge:
			_place_terrain(water_cell, "water_shallow_a" if _hash_cell(water_cell, 13) % 2 == 0 else "water_shallow_b")
			layout.set_minimap_color(water_cell, Color("#245965"))


func cancel_water(cell: Vector2i) -> void:
	layout.clear_water_rect(Rect2i(cell, Vector2i.ONE))
	_water_cells.erase(cell)


func _place_terrain(cell: Vector2i, tile_name: String) -> void:
	_place(terrain_layer, "terrain", cell, tile_name)


func _place_architecture(cell: Vector2i, tile_name: String) -> void:
	_place(architecture_layer, "architecture", cell, tile_name)


func _place_prop(cell: Vector2i, tile_name: String) -> void:
	_place(props_layer, "props", cell, tile_name)


func _place(layer: TileMapLayer, atlas_key: String, cell: Vector2i, tile_name: String) -> void:
	if not layer.tile_set or not _indices.has(atlas_key):
		return
	var lookup: Dictionary = _indices[atlas_key] as Dictionary
	if not lookup.has(tile_name):
		return
	var index := int(lookup[tile_name])
	var atlas_coords := Vector2i(index % 8, index / 8)
	layer.set_cell(cell, int(_source_ids[atlas_key]), atlas_coords, 0)


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
