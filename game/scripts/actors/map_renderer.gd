class_name MapRenderer
extends Node2D

const TILE := 32
const TILE_INDEX_PATH := "res://data/yongchang_tiles.json"
const WATER_COMPONENT_MIN_CELLS := 16
const DEEP_WATER_VARIANTS := ["water_deep_a", "water_deep_b"]
const SHALLOW_WATER_VARIANTS := ["water_shallow_a", "water_shallow_b"]

## 程序化覆盖层：阴影层在地形与建筑之间，立面层在建筑之上、道具之下。
class OverlayLayer extends Node2D:
	const CIRCLE_TEXTURE_SIZE := 32

	var _pre_quads: Array[Dictionary] = []
	var _post_quads: Array[Dictionary] = []
	var _pre_circles: Array[Dictionary] = []
	var _post_circles: Array[Dictionary] = []
	var _pre_quad_batch: MultiMesh
	var _post_quad_batch: MultiMesh
	var _pre_circle_batch: MultiMesh
	var _post_circle_batch: MultiMesh
	var _white_texture: ImageTexture
	var _circle_texture: ImageTexture
	var _post_phase := false
	var _built := false

	func reset_batches() -> void:
		_pre_quads.clear()
		_post_quads.clear()
		_pre_circles.clear()
		_post_circles.clear()
		_pre_quad_batch = null
		_post_quad_batch = null
		_pre_circle_batch = null
		_post_circle_batch = null
		_post_phase = false
		_built = false

	func begin_post_phase() -> void:
		_post_phase = true

	func add_rect(rect: Rect2, color: Color, filled: bool = true, width: float = 1.0) -> void:
		if filled:
			_append_quad({"rect": rect, "color": color})
			return
		var inset := minf(width, minf(rect.size.x, rect.size.y) * 0.5)
		add_line(rect.position, Vector2(rect.end.x, rect.position.y), color, inset)
		add_line(Vector2(rect.position.x, rect.end.y), rect.end, color, inset)
		add_line(rect.position, Vector2(rect.position.x, rect.end.y), color, inset)
		add_line(Vector2(rect.end.x, rect.position.y), rect.end, color, inset)

	func add_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
		_append_quad({"from": from, "to": to, "color": color, "width": maxf(0.5, width)})

	func add_circle(position: Vector2, radius: float, color: Color) -> void:
		var target := _post_circles if _post_phase else _pre_circles
		target.append({"pos": position, "radius": maxf(0.5, radius), "color": color})

	func build_batches(world_bounds: Rect2) -> void:
		_white_texture = _make_white_texture()
		_circle_texture = _make_circle_texture()
		var bounds := world_bounds.grow(64.0)
		_pre_quad_batch = _make_quad_batch(_pre_quads, bounds)
		_post_quad_batch = _make_quad_batch(_post_quads, bounds)
		_pre_circle_batch = _make_circle_batch(_pre_circles, bounds)
		_post_circle_batch = _make_circle_batch(_post_circles, bounds)
		_built = true
		queue_redraw()

	func _append_quad(item: Dictionary) -> void:
		var target := _post_quads if _post_phase else _pre_quads
		target.append(item)

	func _make_quad_batch(items: Array[Dictionary], bounds: Rect2) -> MultiMesh:
		if items.is_empty():
			return null
		var multimesh := _make_multimesh(items.size(), bounds)
		for index in range(items.size()):
			var item := items[index]
			var color := item["color"] as Color
			var transform := Transform2D.IDENTITY
			if item.has("rect"):
				var rect := item["rect"] as Rect2
				transform = Transform2D(0.0, rect.size, 0.0, rect.get_center())
			else:
				var from := item["from"] as Vector2
				var to := item["to"] as Vector2
				var delta := to - from
				var length := delta.length()
				if length <= 0.001:
					transform = Transform2D(0.0, Vector2.ZERO, 0.0, from)
				else:
					transform = Transform2D(
						delta.angle(),
						Vector2(length, maxf(0.5, float(item["width"]))),
						0.0,
						(from + to) * 0.5
					)
			multimesh.set_instance_transform_2d(index, transform)
			multimesh.set_instance_color(index, color)
		return multimesh

	func _make_circle_batch(items: Array[Dictionary], bounds: Rect2) -> MultiMesh:
		if items.is_empty():
			return null
		var multimesh := _make_multimesh(items.size(), bounds)
		for index in range(items.size()):
			var item := items[index]
			var radius := float(item["radius"])
			multimesh.set_instance_transform_2d(
				index,
				Transform2D(
					0.0,
					Vector2(radius * 2.0, radius * 2.0),
					0.0,
					item["pos"] as Vector2
				)
			)
			multimesh.set_instance_color(index, item["color"] as Color)
		return multimesh

	func _make_multimesh(count: int, bounds: Rect2) -> MultiMesh:
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.use_colors = true
		multimesh.mesh = quad
		multimesh.instance_count = count
		multimesh.visible_instance_count = count
		multimesh.custom_aabb = AABB(
			Vector3(bounds.position.x, bounds.position.y, 0.0),
			Vector3(bounds.size.x, bounds.size.y, 0.0)
		)
		return multimesh

	func _make_white_texture() -> ImageTexture:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		return ImageTexture.create_from_image(image)

	func _make_circle_texture() -> ImageTexture:
		var image := Image.create(
			CIRCLE_TEXTURE_SIZE,
			CIRCLE_TEXTURE_SIZE,
			false,
			Image.FORMAT_RGBA8
		)
		image.fill(Color(1.0, 1.0, 1.0, 0.0))
		var center := Vector2.ONE * (float(CIRCLE_TEXTURE_SIZE) * 0.5)
		var radius := center.x - 0.75
		for y in range(CIRCLE_TEXTURE_SIZE):
			for x in range(CIRCLE_TEXTURE_SIZE):
				var distance := (Vector2(float(x) + 0.5, float(y) + 0.5) - center).length()
				var alpha := clampf(radius - distance + 0.5, 0.0, 1.0)
				if alpha > 0.0:
					image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
		return ImageTexture.create_from_image(image)

	func _draw() -> void:
		if not _built:
			return
		if _pre_quad_batch != null:
			draw_multimesh(_pre_quad_batch, _white_texture)
		if _pre_circle_batch != null:
			draw_multimesh(_pre_circle_batch, _circle_texture)
		if _post_quad_batch != null:
			draw_multimesh(_post_quad_batch, _white_texture)
		if _post_circle_batch != null:
			draw_multimesh(_post_circle_batch, _circle_texture)


var layout: MapLayout
var terrain_layer: TileMapLayer
var architecture_layer: TileMapLayer
var props_layer: TileMapLayer
var canopy_layer: TileMapLayer
var shade_layer: OverlayLayer
var elevation_layer: OverlayLayer

var _atlas_config: Dictionary = {}
var _indices: Dictionary = {}
var _source_ids: Dictionary = {}
var _water_cells: Dictionary = {}
var _road_cells: Dictionary = {}
var _bridge_cells: Dictionary = {}
var _bridge_orientations: Dictionary = {}
var _obstacle_cells: Dictionary = {}
var _tree_cells: Dictionary = {}
var _building_rects: Array[Dictionary] = []
var _bridge_rects: Array[Dictionary] = []
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
	_tree_cells.clear()
	_building_rects.clear()
	_bridge_rects.clear()
	_shading_ready = false
	z_index = -50
	_atlas_config = GameData.load_json(TILE_INDEX_PATH).get("atlases", {}) as Dictionary
	_build_tile_index()
	_make_layers()
	_paint_base()
	_paint_water_system()
	for area in layout.areas:
		if area is Dictionary:
			_paint_area(area as Dictionary)
	_prune_water_network()
	_scatter_ground_details()
	_beautify_water_edges()
	layout.finalize()
	_paint_repair_cells(layout.repaired_cell_list())
	_shading_ready = true
	_build_overlay_batches()


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
	shade_layer = OverlayLayer.new()
	shade_layer.name = "ShadeLayer"
	shade_layer.z_index = 1
	shade_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(shade_layer)
	architecture_layer = _make_layer("architecture", "ArchitectureLayer", 2)
	elevation_layer = OverlayLayer.new()
	elevation_layer.name = "ElevationLayer"
	elevation_layer.z_index = 3
	elevation_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(elevation_layer)
	props_layer = _make_layer("props", "PropsLayer", 4)
	canopy_layer = _make_layer("props", "CanopyLayer", 8)
	# 树冠独立于地图 z 排序，始终遮住从树下经过的单位。
	canopy_layer.z_as_relative = false
	canopy_layer.z_index = 8


func _build_overlay_batches() -> void:
	if shade_layer == null or elevation_layer == null or layout == null:
		return
	var bounds := Rect2(Vector2.ZERO, layout.world_size)
	shade_layer.reset_batches()
	_draw_shading(shade_layer)
	shade_layer.build_batches(bounds)
	elevation_layer.reset_batches()
	_draw_elevation(elevation_layer)
	elevation_layer.build_batches(bounds)


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
			_place_terrain(cell, _pick_clustered_name(variants, cell, 5, 5))


func _paint_area(area: Dictionary) -> void:
	var kind := str(area.get("kind", "terrain"))
	if kind in ["path", "trail"]:
		_paint_path_area(area)
		return
	if kind in ["water_path", "creek", "water"]:
		return
	if kind in ["patch", "organic"]:
		_paint_patch_area(area)
		return
	if kind in ["grove", "trees"]:
		_paint_grove_area(area)
		return
	var rect := _area_rect(area)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	match kind:
		"terrain", "sand", "mud", "grass":
			_paint_terrain_area(area, rect)
		"road", "plaza":
			_paint_road_area(area, rect)
		"bridge":
			_paint_bridge_area(area, rect)
		"wall":
			_paint_wall_area(rect, false)
		"tower":
			_paint_wall_area(rect, true)
		"building":
			_paint_building_area(area, rect)
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
			var tile_name := _pick_clustered_name(variants, cell, 79, 4)
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
			var tile_name := _pick_clustered_name(variants, cell, 73, 3)
			if not _place_terrain(cell, tile_name):
				continue
			_road_cells[cell] = true
			_obstacle_cells.erase(cell)
			layout.set_minimap_color(cell, layout.minimap_color_for_tile(tile_name))


func _paint_path_area(area: Dictionary) -> void:
	var points := _area_points(area)
	if points.size() < 2:
		return
	var variants := _area_tiles(area)
	if variants.is_empty():
		variants = ["earth_road_a", "earth_road_b"]
	var width := float(area.get("width", 4.0))
	var cells := _ribbon_cells(points, width, 71, 0.42)
	for cell in cells:
		if not layout.cell_in_bounds(cell):
			continue
		if layout.is_water_cell(cell) or layout.is_bridge_cell(cell) or layout.is_solid_cell(cell):
			continue
		var tile_name := _pick_clustered_name(variants, cell, 67, 3)
		if not _place_terrain(cell, tile_name):
			continue
		_road_cells[cell] = true
		_obstacle_cells.erase(cell)
		layout.set_minimap_color(cell, layout.minimap_color_for_tile(tile_name))


func _paint_water_system() -> void:
	var raw_water := _collect_water_seed_cells()
	var water_cells := _refine_water_mask(raw_water)
	for value in water_cells.keys():
		var cell := value as Vector2i
		if not layout.cell_in_bounds(cell):
			continue
		var tile_name := _pick_water_variant(DEEP_WATER_VARIANTS, cell, 117, 6)
		if not _place_terrain(cell, tile_name):
			continue
		layout.mark_water_rect(Rect2i(cell, Vector2i.ONE))
		_water_cells[cell] = true
		_road_cells.erase(cell)
		layout.set_minimap_color(cell, layout.minimap_color_for_tile(tile_name))


func _collect_water_seed_cells() -> Dictionary:
	var cells: Dictionary = {}
	for area in layout.areas:
		if not area is Dictionary:
			continue
		var item := area as Dictionary
		var kind := str(item.get("kind", ""))
		if kind == "water":
			for cell in _cells_in_rect(_area_rect(item)):
				cells[cell] = true
			continue
		if kind != "water_path" and kind != "creek":
			continue
		var points := _area_points(item)
		if points.size() < 2:
			continue
		var width := maxf(2.0, float(item.get("width", 6.0)))
		for cell in _ribbon_cells(points, width, 113, 0.0):
			if layout.cell_in_bounds(cell):
				cells[cell] = true
	return cells


func _cells_in_rect(rect: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if layout.cell_in_bounds(cell):
				cells.append(cell)
	return cells


## 先统一水域，再做形态学收边：削掉单格毛刺，填平单格凹槽，最后移除孤立小水件。
## 这样河道、护城河与桥下水体保持连续，岸线不再逐格随机抖动。
func _refine_water_mask(raw_water: Dictionary) -> Dictionary:
	var mask := raw_water.duplicate()
	for _pass in 2:
		var next: Dictionary = {}
		for y in layout.world_tiles.y:
			for x in layout.world_tiles.x:
				var cell := Vector2i(x, y)
				var cardinal := _neighbor_water_count(mask, cell, false)
				var neighbors := _neighbor_water_count(mask, cell, true)
				if mask.has(cell):
					if cardinal >= 2 and neighbors >= 3:
						next[cell] = true
				elif cardinal >= 3 and neighbors >= 6:
					next[cell] = true
		mask = next
	mask = _remove_water_tips(mask)
	return _remove_small_water_components(mask)


func _neighbor_water_count(mask: Dictionary, cell: Vector2i, diagonal: bool) -> int:
	var count := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if not diagonal and dx != 0 and dy != 0:
				continue
			if mask.has(cell + Vector2i(dx, dy)):
				count += 1
	return count


func _remove_water_tips(mask: Dictionary) -> Dictionary:
	var refined := mask.duplicate()
	var changed := true
	while changed:
		changed = false
		var next := refined.duplicate()
		for value in refined.keys():
			var cell := value as Vector2i
			if _neighbor_water_count(refined, cell, false) > 1:
				continue
			next.erase(cell)
			changed = true
		refined = next
	return refined


func _remove_small_water_components(mask: Dictionary) -> Dictionary:
	var remaining := mask.duplicate()
	var visited: Dictionary = {}
	for value in mask.keys():
		var start := value as Vector2i
		if visited.has(start):
			continue
		var component: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start]
		visited[start] = true
		var head := 0
		while head < queue.size():
			var cell := queue[head]
			head += 1
			component.append(cell)
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next := cell + (direction as Vector2i)
				if not mask.has(next) or visited.has(next):
					continue
				visited[next] = true
				queue.append(next)
		if component.size() >= WATER_COMPONENT_MIN_CELLS:
			continue
		for cell in component:
			remaining.erase(cell)
	return remaining


## 城墙、桥墩与水门会从连续水体中切出细碎残水；这里在结构铺完后再次收边。
func _prune_water_network() -> void:
	var mask: Dictionary = {}
	for value in _water_cells.keys():
		mask[value as Vector2i] = true
	mask = _remove_water_tips(mask)
	mask = _remove_small_water_components(mask)
	var removed: Array[Vector2i] = []
	for value in _water_cells.keys():
		var cell := value as Vector2i
		if not mask.has(cell):
			removed.append(cell)
	for cell in removed:
		_restore_water_cell_as_land(cell)


func _restore_water_cell_as_land(cell: Vector2i) -> void:
	layout.clear_water_rect(Rect2i(cell, Vector2i.ONE))
	_water_cells.erase(cell)
	if layout.is_bridge_cell(cell):
		return
	var tile_name := _neighbor_land_tile(cell)
	if _place_terrain(cell, tile_name):
		layout.set_minimap_color(cell, layout.minimap_color_for_tile(tile_name))


func _neighbor_land_tile(cell: Vector2i) -> String:
	for direction in [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1),
	]:
		var neighbor := cell + (direction as Vector2i)
		if not layout.cell_in_bounds(neighbor) or _water_cells.has(neighbor):
			continue
		var tile_name := terrain_tile_name(neighbor)
		if tile_name.is_empty() or tile_name.begins_with("water") or tile_name.begins_with("shore"):
			continue
		if tile_name == "dock_horizontal" or tile_name == "dock_vertical":
			continue
		return tile_name
	var variants := [layout.base_tile]
	if layout.base_tile.ends_with("_a"):
		variants.append(layout.base_tile.trim_suffix("_a") + "_b")
	elif layout.base_tile.ends_with("_b"):
		variants.append(layout.base_tile.trim_suffix("_b") + "_a")
	return _pick_clustered_name(variants, cell, 5, 5)


func _paint_patch_area(area: Dictionary) -> void:
	var center_data: Array = area.get("center", []) as Array
	if center_data.size() < 2:
		return
	var center := Vector2(float(center_data[0]), float(center_data[1]))
	var radius_data: Variant = area.get("radius", 3.0)
	var radius := Vector2(3.0, 3.0)
	if radius_data is Array and (radius_data as Array).size() >= 2:
		radius = Vector2(float((radius_data as Array)[0]), float((radius_data as Array)[1]))
	elif radius_data is float or radius_data is int:
		radius = Vector2.ONE * float(radius_data)
	var variants := _area_tiles(area)
	if variants.is_empty():
		return
	var salt := int(area.get("salt", 19))
	var min_cell := Vector2i(floori(center.x - radius.x), floori(center.y - radius.y))
	var max_cell := Vector2i(ceili(center.x + radius.x), ceili(center.y + radius.y))
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			if layout.is_water_cell(cell) or layout.is_bridge_cell(cell) or layout.is_solid_cell(cell):
				continue
			var normalized := Vector2(
				(float(x) + 0.5 - center.x) / maxf(0.5, radius.x),
				(float(y) + 0.5 - center.y) / maxf(0.5, radius.y)
			)
			var edge := (float(_hash_cell(cell, salt)) / 1000003.0 - 0.5) * 0.22
			if normalized.length_squared() > 1.0 + edge:
				continue
			var tile_name := _pick_clustered_name(variants, cell, salt + 37, 4)
			if _place_terrain(cell, tile_name):
				layout.set_minimap_color(cell, layout.minimap_color_for_tile(tile_name))


func _paint_grove_area(area: Dictionary) -> void:
	var cells: Array[Vector2i] = []
	var rect := _area_rect(area)
	if rect.size.x > 0 and rect.size.y > 0:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				cells.append(Vector2i(x, y))
	else:
		var points := _area_points(area)
		if points.size() >= 2:
			cells = _ribbon_cells(points, float(area.get("width", 5.0)), 131, 0.65)
	var density := float(area.get("density", 0.42))
	var floor_tile := str(area.get("floor_tile", ""))
	for cell in cells:
		if not layout.cell_in_bounds(cell):
			continue
		if layout.is_water_cell(cell) or layout.is_bridge_cell(cell) or layout.is_solid_cell(cell):
			continue
		if float(_hash_cell(cell, 151)) / 1000003.0 > density:
			continue
		if not floor_tile.is_empty() and not _road_cells.has(cell):
			_place_terrain(cell, floor_tile)
		var prop_name := "shrub"
		var roll := _hash_cell(cell, 173) % 10
		if roll < 4:
			prop_name = "tree_a"
		elif roll < 7:
			prop_name = "tree_b"
		elif roll == 7:
			prop_name = "bamboo"
		if not _place_prop(cell, prop_name):
			continue
		layout.mark_solid_rect(Rect2i(cell, Vector2i.ONE))
		_obstacle_cells[cell] = true
		layout.set_minimap_color(cell, Color("#263b27"))
		if prop_name == "tree_a" or prop_name == "tree_b":
			_tree_cells[cell] = prop_name
			_place_canopy(cell, "tree_canopy_a" if prop_name == "tree_a" else "tree_canopy_b")


func _paint_bridge_area(_area: Dictionary, rect: Rect2i) -> void:
	var horizontal := rect.size.x >= rect.size.y
	var bridge_tile := "dock_horizontal" if horizontal else "dock_vertical"
	var railing_tile := "wood_railing" if horizontal else "wood_railing_vertical"
	var crossing_width := rect.size.y if horizontal else rect.size.x
	_bridge_rects.append({"rect": rect, "horizontal": horizontal})
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


func _paint_building_area(area: Dictionary, rect: Rect2i) -> void:
	var style := str(area.get("style", "house"))
	var ridge_count := 1
	if rect.size.y >= 7 and style == "hall":
		ridge_count = 2
	elif rect.size.y >= 8 and _hash_cell(rect.position, 211) % 3 == 0:
		ridge_count = 2
	ridge_count = clampi(int(area.get("ridge_count", ridge_count)), 1, 3)
	var ridge_rows: Array[int] = [0 if rect.size.y < 3 else maxi(1, int((rect.size.y - 1) / 2.0))]
	var roof_variant := _hash_cell(rect.position, 263) % 3
	if style == "shop":
		roof_variant = 1
	elif style == "watch":
		roof_variant = 2
	var slope_tile := "roof_slope"
	var eave_tile := "roof_eave"
	var ridge_tile := "roof_ridge"
	var verge_tile := "roof_verge"
	var hip_left_tile := "roof_hip_left"
	var hip_right_tile := "roof_hip_right"
	var door_tile := "roof_eave_door"
	if style == "hall":
		roof_variant = 0
		slope_tile = "hall_roof_slope"
		eave_tile = "hall_roof_eave"
		ridge_tile = "hall_roof_ridge"
		verge_tile = "hall_roof_verge"
		hip_left_tile = "hall_roof_hip_left"
		hip_right_tile = "hall_roof_hip_right"
		door_tile = "hall_roof_eave"
	elif style == "shop":
		slope_tile = "roof_slope_b"
		eave_tile = "roof_eave_shop"
		verge_tile = "roof_verge_b"
		door_tile = "roof_eave_shop"
	elif roof_variant == 1:
		slope_tile = "roof_slope_b"
		eave_tile = "roof_eave_b"
	elif roof_variant == 2:
		slope_tile = "roof_slope_c"
		eave_tile = "roof_eave_b"
		door_tile = "roof_eave_b"
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not layout.cell_in_bounds(cell):
				continue
			var local_x := x - rect.position.x
			var local_y := y - rect.position.y
			var last_x := rect.size.x - 1
			var last_y := rect.size.y - 1
			var tile_name := slope_tile
			if local_y == 0 and local_x == 0:
				tile_name = hip_left_tile
			elif local_y == 0 and local_x == last_x:
				tile_name = hip_right_tile
			elif local_y == 0:
				tile_name = verge_tile
			elif local_y == last_y:
				tile_name = eave_tile
			elif local_x == 0:
				tile_name = "gable_left"
			elif local_x == last_x:
				tile_name = "gable_right"
			elif ridge_rows.has(local_y):
				tile_name = ridge_tile
			if not _place_architecture(cell, tile_name):
				continue
			cancel_water(cell)
			_place_terrain(cell, "wet_stone")
			_road_cells.erase(cell)
			_obstacle_cells[cell] = true
			layout.mark_solid_rect(Rect2i(cell, Vector2i.ONE))
			layout.set_minimap_color(cell, Color("#503d35"))
	var door_cell := Vector2i(-1, -1)
	if rect.size.x >= 5 and rect.size.y >= 3:
		var door_x := rect.position.x + rect.size.x / 2
		door_cell = Vector2i(
			door_x,
			rect.position.y + rect.size.y - 1
		)
		_place_architecture(door_cell, door_tile)
		var step_cell := door_cell + Vector2i.DOWN
		if (
			layout.cell_in_bounds(step_cell)
			and not layout.is_solid_cell(step_cell)
			and not layout.is_water_cell(step_cell)
		):
			_place_architecture(step_cell, "stone_steps")
	_building_rects.append({
		"rect": rect,
		"style": style,
		"ridge_count": ridge_count,
		"ridge_rows": ridge_rows,
		"roof_variant": roof_variant,
		"door_cell": door_cell,
	})


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
			if prop_name == "tree_a" or prop_name == "tree_b":
				_tree_cells[cell] = prop_name
				_place_canopy(cell, "tree_canopy_a" if prop_name == "tree_a" else "tree_canopy_b")
			if solid:
				layout.mark_solid_rect(Rect2i(cell, Vector2i.ONE))
				_obstacle_cells[cell] = true
				layout.set_minimap_color(cell, Color("#3b3d32"))


## 只补非实心草叶/芦苇，填掉大片空地的重复感；不改变碰撞、路线或小地图。
func _scatter_ground_details() -> void:
	var start_cell := layout.world_to_cell(layout.start_pos)
	for y in layout.world_tiles.y:
		for x in layout.world_tiles.x:
			var cell := Vector2i(x, y)
			if layout.is_water_cell(cell) or layout.is_bridge_cell(cell) or layout.is_solid_cell(cell):
				continue
			if _road_cells.has(cell):
				continue
			if terrain_layer.get_cell_source_id(cell) < 0:
				continue
			if props_layer.get_cell_source_id(cell) >= 0 or architecture_layer.get_cell_source_id(cell) >= 0:
				continue
			if Vector2(cell).distance_to(Vector2(start_cell)) < 4.0:
				continue
			var near_water := false
			var near_tree := false
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if _water_cells.has(cell + direction):
					near_water = true
				if _tree_cells.has(cell + direction):
					near_tree = true
			var roll := _hash_cell(cell, 239) % 1000
			if near_water and roll < 115:
				_place_prop(cell, "reeds" if _hash_cell(cell, 241) % 5 else "grass")
			elif near_tree and roll < 58:
				_place_prop(cell, "shrub" if _hash_cell(cell, 243) % 3 else "grass")
			elif roll < 17:
				_place_prop(cell, "grass")


func _beautify_water_edges() -> void:
	for cell in _water_cells.keys():
		var water_cell := cell as Vector2i
		if layout.is_bridge_cell(water_cell) or layout.is_solid_cell(water_cell):
			continue
		var land_directions: Array[Vector2i] = []
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor := water_cell + (direction as Vector2i)
			if not layout.cell_in_bounds(neighbor):
				continue
			if _water_cells.has(neighbor) or layout.is_bridge_cell(neighbor):
				continue
			land_directions.append(direction as Vector2i)
		var tile_name := ""
		if land_directions.is_empty():
			tile_name = _pick_water_variant(DEEP_WATER_VARIANTS, water_cell, 117, 6)
		else:
			tile_name = _shore_tile_for(land_directions)
			if tile_name.is_empty():
				tile_name = _pick_water_variant(SHALLOW_WATER_VARIANTS, water_cell, 131, 5)
		if not _place_terrain(water_cell, tile_name):
			continue
		var minimap_tile := "water_shallow_a" if tile_name.begins_with("shore") else tile_name
		layout.set_minimap_color(water_cell, layout.minimap_color_for_tile(minimap_tile))


func _shore_tile_for(land_directions: Array[Vector2i]) -> String:
	if land_directions.size() == 1:
		var only := land_directions[0]
		if only == Vector2i.UP:
			return "shore_s"
		if only == Vector2i.DOWN:
			return "shore_n"
		if only == Vector2i.LEFT:
			return "shore_e"
		if only == Vector2i.RIGHT:
			return "shore_w"
		return ""
	if land_directions.size() != 2:
		return ""
	var north := land_directions.has(Vector2i.UP)
	var south := land_directions.has(Vector2i.DOWN)
	var west := land_directions.has(Vector2i.LEFT)
	var east := land_directions.has(Vector2i.RIGHT)
	if north and west:
		return "shore_nw"
	if north and east:
		return "shore_ne"
	if south and west:
		return "shore_sw"
	if south and east:
		return "shore_se"
	return ""


## 水域纹理按大块低频取样，避免岸线出现逐格交替的麻点。
func _pick_water_variant(variants: Array, cell: Vector2i, salt: int, block_size: int) -> String:
	if variants.is_empty():
		return "water_deep_a"
	if variants.size() == 1:
		return str(variants[0])
	var size := maxi(2, block_size)
	var block := Vector2i(floori(float(cell.x) / float(size)), floori(float(cell.y) / float(size)))
	var roll := _hash_cell(block, salt) % 100
	var index := 0
	if roll >= 46:
		index = 1
	if variants.size() >= 3 and roll >= 93:
		index = 2
	return str(variants[index])


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


func _place_canopy(cell: Vector2i, tile_name: String) -> bool:
	if canopy_layer == null:
		return false
	return _place(canopy_layer, "props", cell, tile_name)


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
		if canopy_layer != null:
			canopy_layer.erase_cell(cell)
		_obstacle_cells.erase(cell)
		_tree_cells.erase(cell)
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


func _area_points(area: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for value in area.get("points", []) as Array:
		if not value is Array or (value as Array).size() < 2:
			continue
		var point := value as Array
		result.append(Vector2(float(point[0]), float(point[1])))
	return result


func _ribbon_cells(points: Array[Vector2], width: float, salt: int, wobble: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if points.is_empty():
		return cells
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point = Vector2(minf(min_point.x, point.x), minf(min_point.y, point.y))
		max_point = Vector2(maxf(max_point.x, point.x), maxf(max_point.y, point.y))
	var padding := ceili(width * 0.5 + 1.0)
	var min_cell := Vector2i(floori(min_point.x) - padding, floori(min_point.y) - padding)
	var max_cell := Vector2i(ceili(max_point.x) + padding, ceili(max_point.y) + padding)
	var half_width := maxf(0.75, width * 0.5)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			var center := Vector2(x + 0.5, y + 0.5)
			var distance := _distance_to_polyline(center, points)
			var edge_noise := (float(_hash_cell(cell, salt)) / 1000003.0 - 0.5) * wobble
			if distance <= half_width + edge_noise:
				cells.append(cell)
	return cells


func _distance_to_polyline(point: Vector2, points: Array[Vector2]) -> float:
	var best := INF
	for index in range(1, points.size()):
		var distance := point.distance_to(
			Geometry2D.get_closest_point_to_segment(point, points[index - 1], points[index])
		)
		best = minf(best, distance)
	return best


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


## 大块地表不要逐格掷骰：低频块决定主调，再侵蚀少量边缘，避免棋盘感。
func _pick_clustered_name(variants: Array, cell: Vector2i, salt: int, block_size: int) -> String:
	if variants.is_empty():
		return "mud_a"
	if variants.size() == 1:
		return str(variants[0])
	var size := maxi(1, block_size)
	var block := Vector2i(floori(float(cell.x) / float(size)), floori(float(cell.y) / float(size)))
	var roll := _hash_cell(block, salt + 4099) % 100
	var index := 0
	if roll < 24:
		index = 1
	if variants.size() >= 3 and roll >= 94:
		index = 2
	if variants.size() >= 4 and roll >= 98:
		index = 3
	# 打碎块状边缘，否则会从棋盘退化成大方格。
	if index > 0 and _hash_cell(cell, salt + 4177) % 100 > 82:
		index = 0
	return str(variants[index])


func _hash_cell(cell: Vector2i, salt: int) -> int:
	var value := cell.x * 92837111 + cell.y * 689287499 + salt * 283923481
	return abs(value) % 1000003


## 建筑与桥面的立面层：在建筑贴图之上补屋脊/檐口/投影，在桥面上补栏杆立柱与桥头石沿。
func _draw_elevation(target: OverlayLayer) -> void:
	if not _shading_ready or layout == null:
		return
	var tile := float(TILE)
	for value in _building_rects:
		var entry := value as Dictionary
		var rect: Rect2i = entry["rect"] as Rect2i
		var style := str(entry.get("style", "house"))
		var ridge_rows: Array = entry.get("ridge_rows", [0]) as Array
		var origin := Vector2(rect.position) * tile
		var span := Vector2(rect.size) * tile
		var last_row_y := origin.y + span.y - tile
		# 南/东侧远影、接触影、侧墙厚度三层叠开；屋顶不再像平贴在地表。
		target.add_rect(
			Rect2(origin + Vector2(12.0, span.y + 7.0), Vector2(span.x + 2.0, 19.0)),
			Color(0.0, 0.0, 0.0, 0.15)
		)
		target.add_rect(
			Rect2(origin + Vector2(span.x + 7.0, 13.0), Vector2(17.0, span.y + 1.0)),
			Color(0.0, 0.0, 0.0, 0.14)
		)
		target.add_rect(
			Rect2(origin + Vector2(4.0, span.y + 2.0), Vector2(span.x + 4.0, 8.0)),
			Color(0.0, 0.0, 0.0, 0.30)
		)
		target.add_rect(
			Rect2(origin + Vector2(span.x + 1.0, 9.0), Vector2(7.0, span.y - 3.0)),
			Color(0.0, 0.0, 0.0, 0.24)
		)
		target.add_rect(
			Rect2(origin + Vector2(3.0, span.y + 1.0), Vector2(span.x + 2.0, 3.0)),
			Color(0.0, 0.0, 0.0, 0.26)
		)
		# 每一排屋面向南逐渐压暗，形成连续坡面，而不是逐格重复的平面纹理。
		var roof_rows := maxi(1, rect.size.y - 1)
		for local_y in range(roof_rows):
			var shade_t := float(local_y) / maxf(1.0, float(rect.size.y - 2))
			var max_shade := 0.11 if style == "hall" else 0.16
			var shade := lerpf(0.012, max_shade, shade_t)
			target.add_rect(
				Rect2(
					Vector2(origin.x + 2.0, origin.y + float(local_y) * tile),
					Vector2(span.x - 4.0, tile)
				),
				Color(0.0, 0.0, 0.0, shade)
			)
		# 西/北受光，东侧补出木构墙厚，檐口再压一道深影。
		target.add_rect(
			Rect2(origin + Vector2(span.x - 4.0, 4.0), Vector2(4.0, span.y - tile - 4.0)),
			Color(0.0, 0.0, 0.0, 0.10)
		)
		target.add_rect(
			Rect2(origin + Vector2(1.0, 1.0), span - Vector2(2.0, 2.0)),
			Color(0.62, 0.45, 0.29, 0.58),
			false,
			2.0
		)
		target.add_rect(
			Rect2(origin, Vector2(span.x, 5.0)),
			Color(1.0, 0.88, 0.66, 0.11)
		)
		target.add_line(origin, origin + Vector2(span.x, 0), Color(1.0, 0.91, 0.68, 0.52), 3.0)
		target.add_line(origin, origin + Vector2(0, span.y), Color(1.0, 0.89, 0.66, 0.38), 3.0)
		target.add_line(
			Vector2(origin.x + 3.0, last_row_y + 13.0),
			Vector2(origin.x + span.x - 3.0, last_row_y + 13.0),
			Color(0.0, 0.0, 0.0, 0.30),
			6.0
		)
		target.add_line(
			origin + Vector2(span.x - 1.0, 0),
			origin + Vector2(span.x - 1.0, span.y),
			Color(0.0, 0.0, 0.0, 0.28),
			5.0
		)
		if rect.size.y >= 5:
			var window_row := 1 + (_hash_cell(rect.position, 283) % maxi(1, rect.size.y - 3))
			var window_y := origin.y + (float(window_row) + 0.31) * tile
			for side in range(2):
				var window_x := origin.x + 6.0
				if side == 1:
					window_x = origin.x + span.x - 12.0
				target.add_rect(
					Rect2(Vector2(window_x, window_y), Vector2(7.0, 9.0)),
					Color(0.12, 0.07, 0.04, 0.92)
				)
				target.add_rect(
					Rect2(Vector2(window_x + 1.0, window_y + 1.0), Vector2(5.0, 6.0)),
					Color(0.60, 0.50, 0.32, 0.88)
				)
				target.add_line(
					Vector2(window_x + 3.5, window_y + 1.0),
					Vector2(window_x + 3.5, window_y + 7.0),
					Color(0.18, 0.10, 0.05, 0.86),
					1.0
				)
				target.add_line(
					Vector2(window_x, window_y + 9.0),
					Vector2(window_x + 7.0, window_y + 9.0),
					Color(0.0, 0.0, 0.0, 0.24),
					2.0
				)
		for ridge_row in ridge_rows:
			var ridge_y := origin.y + (float(ridge_row) + 0.22) * tile
			target.add_line(
				Vector2(origin.x + 2.0, ridge_y - 2.0),
				Vector2(origin.x + span.x - 2.0, ridge_y - 2.0),
				Color(1.0, 0.83, 0.52, 0.42),
				3.0
			)
			target.add_line(
				Vector2(origin.x + 2.0, ridge_y + 1.0),
				Vector2(origin.x + span.x - 2.0, ridge_y + 1.0),
				Color(0.0, 0.0, 0.0, 0.34),
				4.0
			)
		target.add_line(
			Vector2(origin.x + 4.0, last_row_y + 10.0),
			Vector2(origin.x + span.x - 4.0, last_row_y + 10.0),
			Color(1.0, 0.84, 0.60, 0.24),
			2.0
		)
		if style == "shop":
			target.add_rect(
				Rect2(
					Vector2(origin.x + 4.0, last_row_y + 20.0),
					Vector2(span.x - 8.0, 4.0)
				),
				Color(0.62, 0.18, 0.09, 0.64)
			)
			target.add_line(
				Vector2(origin.x + 4.0, last_row_y + 20.0),
				Vector2(origin.x + span.x - 4.0, last_row_y + 20.0),
				Color(1.0, 0.70, 0.28, 0.46),
				2.0
			)
			target.add_line(
				Vector2(origin.x + 4.0, last_row_y + 25.0),
				Vector2(origin.x + span.x - 4.0, last_row_y + 25.0),
				Color(0.0, 0.0, 0.0, 0.28),
				3.0
			)
			# 侧挑招牌给店铺一个脱离墙面的轮廓，远景也能识别商业街坊。
			target.add_line(
				Vector2(origin.x + span.x - 13.0, last_row_y + 6.0),
				Vector2(origin.x + span.x + 3.0, last_row_y + 7.0),
				Color(0.18, 0.10, 0.05, 0.92),
				2.0
			)
			target.add_rect(
				Rect2(
					Vector2(origin.x + span.x + 1.0, last_row_y + 8.0),
					Vector2(10.0, 13.0)
				),
				Color(0.55, 0.14, 0.07, 0.94)
			)
			target.add_rect(
				Rect2(
					Vector2(origin.x + span.x + 3.0, last_row_y + 10.0),
					Vector2(6.0, 9.0)
				),
				Color(0.94, 0.63, 0.24, 0.88)
			)
		if style == "hall":
			var ornament_x := origin.x + span.x * 0.5
			target.add_rect(
				Rect2(Vector2(origin.x + 3.0, last_row_y + 32.0), Vector2(span.x - 6.0, 5.0)),
				Color(0.0, 0.0, 0.0, 0.28)
			)
			for ridge_row in ridge_rows:
				var ornament_y := origin.y + (float(ridge_row) + 0.22) * tile
				target.add_line(
					Vector2(ornament_x - 10.0, ornament_y - 2.0),
					Vector2(ornament_x + 10.0, ornament_y - 2.0),
					Color(1.0, 0.82, 0.42, 0.78),
					2.0
				)
				target.add_circle(
					Vector2(ornament_x - 10.0, ornament_y - 2.0),
					2.0,
					Color(1.0, 0.86, 0.48, 0.92)
				)
				target.add_circle(
					Vector2(ornament_x + 10.0, ornament_y - 2.0),
					2.0,
					Color(1.0, 0.86, 0.48, 0.92)
				)

		var door_cell: Vector2i = entry.get("door_cell", Vector2i(-1, -1)) as Vector2i
		if door_cell.x < 0:
			continue
		var door_origin := Vector2(door_cell) * tile
		if style == "hall":
			target.add_rect(
				Rect2(door_origin + Vector2(10.0, 20.0), Vector2(12.0, 12.0)),
				Color(0.04, 0.02, 0.02, 0.88)
			)
			target.add_rect(
				Rect2(door_origin + Vector2(11.0, 21.0), Vector2(10.0, 11.0)),
				Color(0.64, 0.12, 0.08, 0.94)
			)
			target.add_line(
				door_origin + Vector2(16.0, 22.0),
				door_origin + Vector2(16.0, 30.0),
				Color(0.12, 0.04, 0.03, 0.9),
				1.0
			)
			for x in [13.0, 19.0]:
				for y in [24.0, 27.0]:
					target.add_circle(door_origin + Vector2(x, y), 1.0, Color(1.0, 0.78, 0.34, 0.9))
		# 灯笼挂在门洞两侧。保留完整檐口，不再用透明灯笼瓦替换整格建筑边缘。
		for direction in [-1.0, 1.0]:
			var lantern := door_origin + Vector2(tile * 0.5 + direction * tile, tile * 0.56)
			target.add_circle(lantern, 8.0, Color(1.0, 0.55, 0.14, 0.08))
			target.add_circle(lantern, 4.0, Color(1.0, 0.70, 0.24, 0.12))
			target.add_line(
				lantern + Vector2(0.0, -6.0),
				lantern + Vector2(0.0, -2.0),
				Color(0.22, 0.12, 0.06, 0.9),
				1.0
			)
			target.add_rect(
				Rect2(lantern + Vector2(-2.0, -2.0), Vector2(4.0, 7.0)),
				Color(0.74, 0.16, 0.09, 0.92)
			)
			target.add_rect(
				Rect2(lantern + Vector2(-1.0, 0.0), Vector2(2.0, 4.0)),
				Color(1.0, 0.66, 0.20, 0.96)
			)

	target.begin_post_phase()
	for value in _bridge_rects:
		var entry := value as Dictionary
		var rect: Rect2i = entry["rect"] as Rect2i
		var horizontal := bool(entry.get("horizontal", true))
		var origin := Vector2(rect.position) * tile
		var span := Vector2(rect.size) * tile
		if horizontal:
			target.add_line(
				Vector2(origin.x, origin.y + 2.0),
				Vector2(origin.x + span.x, origin.y + 2.0),
				Color(1.0, 0.84, 0.54, 0.24),
				2.0
			)
			target.add_line(
				Vector2(origin.x, origin.y + span.y - 2.0),
				Vector2(origin.x + span.x, origin.y + span.y - 2.0),
				Color(0.0, 0.0, 0.0, 0.30),
				3.0
			)
			target.add_line(
				Vector2(origin.x + 2.0, origin.y + 3.0),
				Vector2(origin.x + 2.0, origin.y + span.y - 3.0),
				Color(0.84, 0.73, 0.48, 0.18),
				2.0
			)
			target.add_line(
				Vector2(origin.x + span.x - 2.0, origin.y + 3.0),
				Vector2(origin.x + span.x - 2.0, origin.y + span.y - 3.0),
				Color(0.0, 0.0, 0.0, 0.22),
				2.0
			)
		else:
			target.add_line(
				Vector2(origin.x + 2.0, origin.y),
				Vector2(origin.x + 2.0, origin.y + span.y),
				Color(1.0, 0.84, 0.54, 0.22),
				2.0
			)
			target.add_line(
				Vector2(origin.x + span.x - 2.0, origin.y),
				Vector2(origin.x + span.x - 2.0, origin.y + span.y),
				Color(0.0, 0.0, 0.0, 0.28),
				3.0
			)
			target.add_line(
				Vector2(origin.x + 3.0, origin.y + 2.0),
				Vector2(origin.x + span.x - 3.0, origin.y + 2.0),
				Color(0.84, 0.73, 0.48, 0.18),
				2.0
			)
			target.add_line(
				Vector2(origin.x + 3.0, origin.y + span.y - 2.0),
				Vector2(origin.x + span.x - 3.0, origin.y + span.y - 2.0),
				Color(0.0, 0.0, 0.0, 0.22),
				2.0
			)
		var along := rect.size.x if horizontal else rect.size.y
		for offset in range(0, along, 2):
			for side in [0, 1]:
				var post := Vector2.ZERO
				if horizontal:
					post = Vector2(
						origin.x + (float(offset) + 0.5) * tile,
						origin.y + (0.5 if side == 0 else float(rect.size.y) - 0.5) * tile
					)
				else:
					post = Vector2(
						origin.x + (0.5 if side == 0 else float(rect.size.x) - 0.5) * tile,
						origin.y + (float(offset) + 0.5) * tile
					)
				if not layout.is_bridge_cell(layout.world_to_cell(post)):
					continue
				target.add_circle(post, 4.0, Color(0.13, 0.08, 0.05, 0.76))
				target.add_circle(post + Vector2(-1.0, -1.0), 2.0, Color(0.86, 0.68, 0.38, 0.52))


func _draw_shading(target: OverlayLayer) -> void:
	if not _shading_ready or layout == null:
		return
	var tile := float(TILE)
	# 1) 高地：暖色薄染 + 北/西受光边 + 南侧投影，让台地一眼可辨。
	for rect in layout.highland_rects:
		var origin := Vector2(rect.position) * tile
		var size := Vector2(rect.size) * tile
		target.add_rect(Rect2(origin + Vector2(0, size.y), Vector2(size.x, 8)), Color(0.0, 0.0, 0.0, 0.16))
		target.add_rect(Rect2(origin, size), Color(1.0, 0.86, 0.55, 0.045))
		target.add_line(origin, origin + Vector2(size.x, 0), Color(1.0, 0.94, 0.72, 0.16), 2.0)
		target.add_line(origin, origin + Vector2(0, size.y), Color(1.0, 0.94, 0.72, 0.10), 2.0)
		target.add_line(
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
			target.add_line(Vector2(x0, y0), Vector2(x0 + tile, y0), edge, 2.0)
			target.add_line(Vector2(x0 + 3.0, y0 + 3.0), Vector2(x0 + tile - 3.0, y0 + 3.0), Color(0.86, 0.76, 0.55, 0.10), 1.0)
		if not _is_road_like(road_cell + Vector2i.DOWN):
			target.add_line(Vector2(x0, y0 + tile), Vector2(x0 + tile, y0 + tile), edge, 2.0)
			target.add_line(Vector2(x0 + 2.0, y0 + tile - 2.0), Vector2(x0 + tile - 2.0, y0 + tile - 2.0), Color(0.0, 0.0, 0.0, 0.15), 2.0)
		if not _is_road_like(road_cell + Vector2i.LEFT):
			target.add_line(Vector2(x0, y0), Vector2(x0, y0 + tile), edge, 2.0)
		if not _is_road_like(road_cell + Vector2i.RIGHT):
			target.add_line(Vector2(x0 + tile, y0), Vector2(x0 + tile, y0 + tile), edge, 2.0)

	# 3) 桥面：只在朝水的一侧描连续投影，不在每块甲板上切出黑缝。
	for cell in _bridge_cells.keys():
		var bridge_cell := cell as Vector2i
		var horizontal := bool(_bridge_orientations.get(bridge_cell, true))
		var x0 := float(bridge_cell.x) * tile
		var y0 := float(bridge_cell.y) * tile
		if horizontal and not _bridge_cells.has(bridge_cell + Vector2i.DOWN):
			target.add_line(Vector2(x0, y0 + tile), Vector2(x0 + tile, y0 + tile), Color(0.03, 0.07, 0.06, 0.42), 3.0)
		elif not horizontal and not _bridge_cells.has(bridge_cell + Vector2i.RIGHT):
			target.add_line(Vector2(x0 + tile, y0), Vector2(x0 + tile, y0 + tile), Color(0.03, 0.07, 0.06, 0.42), 3.0)

	# 4) 水岸：深色岸线 + 外侧浅滩高光；桥头接缝不画成阻断水岸。
	for cell in _water_cells.keys():
		var water_cell := cell as Vector2i
		if layout.is_bridge_cell(water_cell):
			continue
		if terrain_tile_name(water_cell).begins_with("shore_"):
			# 岸线瓦片自带半格水陆过渡，不要再叠整格矩形描边。
			continue
		var x0 := float(water_cell.x) * tile
		var y0 := float(water_cell.y) * tile
		var x1 := x0 + tile
		var y1 := y0 + tile
		if not _water_cells.has(water_cell + Vector2i.UP) and not layout.is_bridge_cell(water_cell + Vector2i.UP):
			target.add_line(Vector2(x0, y0), Vector2(x1, y0), Color(0.03, 0.11, 0.13, 0.55), 2.0)
			target.add_line(Vector2(x0, y0 - 3.0), Vector2(x1, y0 - 3.0), Color(0.74, 0.66, 0.47, 0.16), 2.0)
		if not _water_cells.has(water_cell + Vector2i.DOWN) and not layout.is_bridge_cell(water_cell + Vector2i.DOWN):
			target.add_line(Vector2(x0, y1), Vector2(x1, y1), Color(0.03, 0.11, 0.13, 0.55), 2.0)
		if not _water_cells.has(water_cell + Vector2i.LEFT) and not layout.is_bridge_cell(water_cell + Vector2i.LEFT):
			target.add_line(Vector2(x0, y0), Vector2(x0, y1), Color(0.03, 0.11, 0.13, 0.55), 2.0)
			target.add_line(Vector2(x0 - 3.0, y0), Vector2(x0 - 3.0, y1), Color(0.74, 0.66, 0.47, 0.14), 2.0)
		if not _water_cells.has(water_cell + Vector2i.RIGHT) and not layout.is_bridge_cell(water_cell + Vector2i.RIGHT):
			target.add_line(Vector2(x1, y0), Vector2(x1, y1), Color(0.03, 0.11, 0.13, 0.55), 2.0)

	# 5) 树影：树冠在主层之上，影子先落在水岸/道路上，形成林下遮挡。
	for cell in _tree_cells.keys():
		var tree_cell := cell as Vector2i
		var center := (Vector2(tree_cell) + Vector2(0.62, 0.72)) * tile
		target.add_circle(center + Vector2(5.0, 5.0), tile * 0.48, Color(0.02, 0.06, 0.03, 0.18))
		target.add_circle(center + Vector2(-6.0, 4.0), tile * 0.30, Color(0.02, 0.06, 0.03, 0.12))
		target.add_circle(center + Vector2(10.0, 9.0), tile * 0.18, Color(0.02, 0.06, 0.03, 0.10))

	# 6) 障碍物：南/东侧落影，北/西侧受光，墙体、栏杆与屋顶不再与地面糊在一起。
	target.begin_post_phase()
	for cell in _obstacle_cells.keys():
		var solid_cell := cell as Vector2i
		var x0 := float(solid_cell.x) * tile
		var y0 := float(solid_cell.y) * tile
		var x1 := x0 + tile
		var y1 := y0 + tile
		var architecture_name := _tile_name_at(architecture_layer, "architecture", solid_cell)
		if (
			architecture_name.begins_with("roof")
			or architecture_name.begins_with("hall_roof")
			or architecture_name.begins_with("gable")
		):
			target.add_rect(
				Rect2(x0 + 5.0, y0 + 7.0, tile, tile),
				Color(0.0, 0.0, 0.0, 0.10)
			)
		if not _obstacle_cells.has(solid_cell + Vector2i.DOWN):
			target.add_line(Vector2(x0, y1 + 3.0), Vector2(x1, y1 + 3.0), Color(0.0, 0.0, 0.0, 0.22), 4.0)
		if not _obstacle_cells.has(solid_cell + Vector2i.RIGHT):
			target.add_line(Vector2(x1 + 3.0, y0), Vector2(x1 + 3.0, y1), Color(0.0, 0.0, 0.0, 0.18), 4.0)
		if not _obstacle_cells.has(solid_cell + Vector2i.UP):
			target.add_line(Vector2(x0, y0), Vector2(x1, y0), Color(1.0, 0.93, 0.78, 0.16), 1.0)
		if not _obstacle_cells.has(solid_cell + Vector2i.LEFT):
			target.add_line(Vector2(x0, y0), Vector2(x0, y1), Color(1.0, 0.93, 0.78, 0.10), 1.0)


func _is_road_like(cell: Vector2i) -> bool:
	if _road_cells.has(cell):
		return true
	if layout != null and layout.is_bridge_cell(cell):
		return true
	return false
