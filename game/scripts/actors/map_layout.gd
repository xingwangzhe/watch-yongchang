class_name MapLayout
extends RefCounted

const TILE_SIZE := 32.0
const CARDINAL_DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var map_id := ""
var world_tiles := Vector2i(120, 84)
var world_size := Vector2(world_tiles) * TILE_SIZE
var start_pos := Vector2.ZERO
var base_tile := "mud_a"
var areas: Array = []
var landmarks: Array[Dictionary] = []
var highland_rects: Array[Rect2i] = []
var spawn_polylines: Array[PackedVector2Array] = []
var spawn_points: PackedVector2Array = PackedVector2Array()
var minimap_texture: ImageTexture
var last_repair_count := 0

var _solid_cells: Dictionary = {}
var _water_cells: Dictionary = {}
var _bridge_cells: Dictionary = {}
var _minimap_colors := PackedColorArray()
var _spawn_samples := PackedVector2Array()
var _flow_distance := PackedInt32Array()
var _flow_target_cell := Vector2i(-1, -1)


func setup(map_key: String, definition: Dictionary) -> void:
	map_id = map_key
	var layout: Dictionary = definition.get("layout", {}) as Dictionary
	var size_data: Array = layout.get("world_tiles", [120, 84]) as Array
	world_tiles = Vector2i(int(size_data[0]), int(size_data[1]))
	world_size = Vector2(world_tiles) * TILE_SIZE
	base_tile = str(layout.get("base_tile", "mud_a"))
	areas = layout.get("areas", []) as Array
	var start_tile: Array = layout.get("start_tile", [world_tiles.x / 2, world_tiles.y / 2]) as Array
	start_pos = _tile_center(Vector2i(int(start_tile[0]), int(start_tile[1])))
	_parse_landmarks(layout.get("landmarks", []) as Array)
	_parse_highlands(layout.get("highlands", []) as Array)
	_parse_spawn_lanes(layout.get("spawn_lanes", []) as Array)
	_minimap_colors.resize(world_tiles.x * world_tiles.y)
	_minimap_colors.fill(minimap_color_for_tile(base_tile))


func finalize() -> void:
	if not is_point_walkable(start_pos, 18.0):
		start_pos = find_walkable_position(start_pos, 18.0)
	# 连通性是硬约束：任何出生带如果到不了玩家出生点，现场开一条可走走廊，
	# 保证不会因为地图数据或生成顺序把关键路径堵死。正式地图应在报告里为 0。
	last_repair_count = 0
	if not connectivity_report().get("ok", true):
		last_repair_count = repair_connectivity()
		push_warning("Map %s connectivity repaired on %d lanes" % [map_id, last_repair_count])
	_build_minimap_texture()


func mark_solid_rect(rect: Rect2i) -> void:
	for cell in _cells_in(rect):
		_solid_cells[cell] = true


func clear_solid_rect(rect: Rect2i) -> void:
	for cell in _cells_in(rect):
		_solid_cells.erase(cell)


func mark_water_rect(rect: Rect2i) -> void:
	for cell in _cells_in(rect):
		_water_cells[cell] = true


func clear_water_rect(rect: Rect2i) -> void:
	for cell in _cells_in(rect):
		_water_cells.erase(cell)


func mark_bridge_rect(rect: Rect2i) -> void:
	for cell in _cells_in(rect):
		_bridge_cells[cell] = true


func set_minimap_color_rect(rect: Rect2i, color: Color) -> void:
	for cell in _cells_in(rect):
		set_minimap_color(cell, color)


func set_minimap_color(cell: Vector2i, color: Color) -> void:
	if not cell_in_bounds(cell):
		return
	_minimap_colors[cell.y * world_tiles.x + cell.x] = color


func is_solid_cell(cell: Vector2i) -> bool:
	return _solid_cells.has(cell)


func is_water_cell(cell: Vector2i) -> bool:
	return _water_cells.has(cell)


func is_bridge_cell(cell: Vector2i) -> bool:
	return _bridge_cells.has(cell)


func is_cell_walkable(cell: Vector2i) -> bool:
	if not cell_in_bounds(cell):
		return false
	if _solid_cells.has(cell):
		return false
	if _water_cells.has(cell) and not _bridge_cells.has(cell):
		return false
	return true


func is_point_walkable(position: Vector2, radius: float = 18.0) -> bool:
	if position.x - radius < 0.0 or position.y - radius < 0.0:
		return false
	if position.x + radius >= world_size.x or position.y + radius >= world_size.y:
		return false
	var min_cell := world_to_cell(position - Vector2.ONE * radius)
	var max_cell := world_to_cell(position + Vector2.ONE * radius)
	for cell_y in range(min_cell.y, max_cell.y + 1):
		for cell_x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(cell_x, cell_y)
			if is_cell_walkable(cell):
				continue
			var rect := Rect2(Vector2(cell) * TILE_SIZE, Vector2.ONE * TILE_SIZE)
			var closest := Vector2(
				clampf(position.x, rect.position.x, rect.end.x),
				clampf(position.y, rect.position.y, rect.end.y)
			)
			if closest.distance_squared_to(position) <= radius * radius + 0.001:
				return false
	return true


func is_segment_walkable(from: Vector2, to: Vector2, radius: float = 18.0) -> bool:
	var distance := from.distance_to(to)
	var steps := maxi(1, ceili(distance / 12.0))
	for index in range(steps + 1):
		if not is_point_walkable(from.lerp(to, float(index) / float(steps)), radius):
			return false
	return true


func is_position_reachable_from(origin: Vector2, target: Vector2) -> bool:
	var reachable := walkable_reachability(origin)
	var target_cell := world_to_cell(target)
	if not cell_in_bounds(target_cell):
		return false
	return reachable[target_cell.y * world_tiles.x + target_cell.x] == 1


func walkable_reachability(origin: Vector2) -> PackedByteArray:
	var total := world_tiles.x * world_tiles.y
	var reachable := PackedByteArray()
	reachable.resize(total)
	reachable.fill(0)
	var start_cell := world_to_cell(origin)
	if not is_cell_walkable(start_cell):
		start_cell = world_to_cell(find_walkable_position(origin))
	if not is_cell_walkable(start_cell):
		return reachable
	var queue := PackedInt32Array()
	var start_index := start_cell.y * world_tiles.x + start_cell.x
	queue.append(start_index)
	reachable[start_index] = 1
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var cell := Vector2i(index % world_tiles.x, index / world_tiles.x)
		for direction in CARDINAL_DIRECTIONS:
			var next := cell + (direction as Vector2i)
			if not cell_in_bounds(next):
				continue
			var next_index := next.y * world_tiles.x + next.x
			if reachable[next_index] == 1 or not is_cell_walkable(next):
				continue
			reachable[next_index] = 1
			queue.append(next_index)
	return reachable


## 连通性报告：玩家出生点必须可走，所有出生带采样点到出生点必须连通。
## 返回 {ok, samples, blocked, start_walkable}，供测试与运行时自检使用。
func connectivity_report() -> Dictionary:
	var start_walkable := is_point_walkable(start_pos, 18.0)
	var reachable := walkable_reachability(start_pos)
	var blocked := 0
	for point in _spawn_samples:
		var cell := world_to_cell(point)
		if not cell_in_bounds(cell) or not is_point_walkable(point, 14.0):
			blocked += 1
			continue
		if reachable[cell.y * world_tiles.x + cell.x] != 1:
			blocked += 1
	return {
		"ok": start_walkable and blocked == 0,
		"samples": _spawn_samples.size(),
		"blocked": blocked,
		"start_walkable": start_walkable,
	}


## 兜底修复：对不可达的出生带，沿直线向玩家出生点清出一条可走走廊。
## 只清障碍、把水格架成桥，不改动已画好的地形贴图；正式地图不应触发。
func repair_connectivity() -> int:
	if not is_point_walkable(start_pos, 18.0):
		start_pos = find_walkable_position(start_pos, 18.0)
	var start_cell := world_to_cell(start_pos)
	var repaired := 0
	for point in _spawn_samples:
		var cell := world_to_cell(point)
		if cell_in_bounds(cell) and is_cell_walkable(cell):
			var reachable := walkable_reachability(start_pos)
			if reachable[cell.y * world_tiles.x + cell.x] == 1:
				continue
		_carve_corridor(cell, start_cell)
		repaired += 1
	return repaired


func _carve_corridor(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var steps := maxi(absi(to_cell.x - from_cell.x), absi(to_cell.y - from_cell.y))
	if steps <= 0:
		steps = 1
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		var center := Vector2i(
			roundi(lerpf(float(from_cell.x), float(to_cell.x), t)),
			roundi(lerpf(float(from_cell.y), float(to_cell.y), t))
		)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var cell := center + Vector2i(dx, dy)
				if not cell_in_bounds(cell):
					continue
				_solid_cells.erase(cell)
				if _water_cells.has(cell):
					_bridge_cells[cell] = true
				set_minimap_color(cell, Color("#c4a06b"))


func ensure_flow_field(target: Vector2) -> void:
	var cell := world_to_cell(target)
	if not cell_in_bounds(cell):
		return
	if not is_cell_walkable(cell):
		cell = world_to_cell(find_walkable_position(target))
	if _flow_distance.size() != world_tiles.x * world_tiles.y:
		_flow_distance.resize(world_tiles.x * world_tiles.y)
		_flow_distance.fill(-1)
		_flow_target_cell = Vector2i(-1, -1)
	if _flow_target_cell == cell:
		return
	_build_flow_field(cell)


func flow_direction(position: Vector2) -> Vector2:
	if _flow_distance.size() != world_tiles.x * world_tiles.y:
		return Vector2.ZERO
	var cell := world_to_cell(position)
	if not cell_in_bounds(cell):
		return Vector2.ZERO
	var best_distance := _flow_distance[cell.y * world_tiles.x + cell.x]
	if best_distance < 0:
		return Vector2.ZERO
	var best_cell := cell
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var next := Vector2i(cell.x + dx, cell.y + dy)
			if not cell_in_bounds(next) or not is_cell_walkable(next):
				continue
			if dx != 0 and dy != 0:
				if not is_cell_walkable(Vector2i(cell.x + dx, cell.y)):
					continue
				if not is_cell_walkable(Vector2i(cell.x, cell.y + dy)):
					continue
			var next_distance := _flow_distance[next.y * world_tiles.x + next.x]
			if next_distance >= 0 and next_distance < best_distance:
				best_distance = next_distance
				best_cell = next
	if best_cell == cell:
		return Vector2.ZERO
	return (_tile_center(best_cell) - position).normalized()


func navigation_direction(from: Vector2, to: Vector2, direct_range: float = 190.0) -> Vector2:
	var direct := to - from
	if direct.length_squared() <= direct_range * direct_range:
		return direct.normalized()
	var flow := flow_direction(from)
	if flow != Vector2.ZERO:
		return flow
	return direct.normalized()


func is_segment_wall_blocked(from: Vector2, to: Vector2, radius: float = 4.0) -> bool:
	var distance := from.distance_to(to)
	var steps := maxi(1, ceili(distance / 12.0))
	var extents := [-radius, 0.0, radius]
	for index in range(steps + 1):
		var point := from.lerp(to, float(index) / float(steps))
		# 只让实心墙/障碍挡箭，水面与地形不挡。沿半径采样 3×3 点，
		# 避免箭贴着墙角飞时穿墙，同时不再把空地格线误判成墙。
		for dx in extents:
			for dy in extents:
				var cell := world_to_cell(point + Vector2(dx, dy))
				if not cell_in_bounds(cell):
					return true
				if is_solid_cell(cell):
					return true
	return false


func move_circle(from: Vector2, to: Vector2, radius: float = 18.0) -> Vector2:
	if not is_point_walkable(from, radius):
		from = find_walkable_position(from, radius)
	var result := from
	var x_candidate := Vector2(to.x, result.y)
	if is_point_walkable(x_candidate, radius):
		result.x = to.x
	var y_candidate := Vector2(result.x, to.y)
	if is_point_walkable(y_candidate, radius):
		result.y = to.y
	return result


func find_walkable_position(origin: Vector2, radius: float = 18.0) -> Vector2:
	var bounded := Vector2(
		clampf(origin.x, radius + 1.0, world_size.x - radius - 1.0),
		clampf(origin.y, radius + 1.0, world_size.y - radius - 1.0)
	)
	if is_point_walkable(bounded, radius):
		return bounded
	for ring in range(1, 49):
		var distance := float(ring) * 24.0
		var samples := 12 + ring * 2
		for index in samples:
			var angle := TAU * float(index) / float(samples)
			var candidate := bounded + Vector2(cos(angle), sin(angle)) * distance
			candidate.x = clampf(candidate.x, radius + 1.0, world_size.x - radius - 1.0)
			candidate.y = clampf(candidate.y, radius + 1.0, world_size.y - radius - 1.0)
			if is_point_walkable(candidate, radius):
				return candidate
	return _tile_center(Vector2i(world_tiles.x / 2, world_tiles.y / 2))


func spawn_candidates(player_position: Vector2, min_distance: float = 720.0, max_distance: float = 1500.0) -> Array[Vector2]:
	ensure_flow_field(player_position)
	var near: Array[Vector2] = []
	var far: Array[Vector2] = []
	for point in _spawn_samples:
		if not is_point_walkable(point, 14.0):
			continue
		var cell := world_to_cell(point)
		if _flow_distance.size() == world_tiles.x * world_tiles.y:
			if _flow_distance[cell.y * world_tiles.x + cell.x] < 0:
				continue
		var distance := player_position.distance_to(point)
		if distance >= min_distance and distance <= max_distance:
			near.append(point)
		elif distance > max_distance:
			far.append(point)
	if not near.is_empty():
		return near
	if not far.is_empty():
		return far
	var fallback: Array[Vector2] = []
	var fallback_pos := find_walkable_position(player_position + Vector2(900, 0), 14.0)
	fallback.append(fallback_pos)
	return fallback


func spawn_sample_points() -> PackedVector2Array:
	return _spawn_samples.duplicate()


func landmark_entries() -> Array[Dictionary]:
	return landmarks


func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / TILE_SIZE), floori(position.y / TILE_SIZE))


func cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < world_tiles.x and cell.y < world_tiles.y


func minimap_color_for_tile(tile_name: String) -> Color:
	if tile_name.begins_with("water_deep"):
		return Color("#163a45")
	if tile_name.begins_with("water_shallow"):
		return Color("#235864")
	if tile_name.begins_with("shore"):
		return Color("#9b8c68")
	if tile_name.begins_with("stone_road") or tile_name.begins_with("wet_stone") or tile_name == "dock_vertical" or tile_name == "dock_horizontal":
		return Color("#9f9275")
	if tile_name.begins_with("earth_road") or tile_name == "gravel":
		return Color("#87785b")
	if tile_name.begins_with("salt_pan") or tile_name.begins_with("sand"):
		return Color("#b8a77d")
	if tile_name.begins_with("reed"):
		return Color("#405d3b")
	if tile_name.begins_with("mud_grass"):
		return Color("#5a6741")
	if tile_name.begins_with("cracked_mud") or tile_name.begins_with("mud"):
		return Color("#72634c")
	return Color("#6f624b")


func _parse_landmarks(entries: Array) -> void:
	landmarks.clear()
	for entry in entries:
		if not entry is Dictionary:
			continue
		var item := entry as Dictionary
		var tile: Array = item.get("tile", [0, 0]) as Array
		landmarks.append({
			"name_zh": str(item.get("name_zh", "")),
			"name_en": str(item.get("name_en", "")),
			"cell": Vector2i(int(tile[0]), int(tile[1])),
			"kind": str(item.get("kind", "place")),
			"color": Color(str(item.get("color", "#e1b35a"))),
		})


func _parse_highlands(entries: Array) -> void:
	highland_rects.clear()
	for entry in entries:
		if not entry is Array:
			continue
		var data := entry as Array
		if data.size() < 4:
			continue
		var rect := Rect2i(int(data[0]), int(data[1]), int(data[2]), int(data[3]))
		if rect.size.x > 0 and rect.size.y > 0:
			highland_rects.append(rect)


func _parse_spawn_lanes(entries: Array) -> void:
	spawn_polylines.clear()
	_spawn_samples.clear()
	for lane_data in entries:
		if not lane_data is Array:
			continue
		var points := PackedVector2Array()
		for point_data in lane_data as Array:
			if point_data is Array and (point_data as Array).size() >= 2:
				points.append(_tile_center(Vector2i(int(point_data[0]), int(point_data[1]))))
		if points.is_empty():
			continue
		spawn_polylines.append(points)
		for index in range(points.size()):
			if index > 0:
				var from := points[index - 1]
				var to := points[index]
				var steps := maxi(1, ceili(from.distance_to(to) / 64.0))
				for step in range(steps):
					_spawn_samples.append(from.lerp(to, float(step) / float(steps)))
			_spawn_samples.append(points[index])


func _build_flow_field(target_cell: Vector2i) -> void:
	var total := world_tiles.x * world_tiles.y
	_flow_distance.resize(total)
	_flow_distance.fill(-1)
	_flow_target_cell = target_cell
	if not is_cell_walkable(target_cell):
		return
	var queue := PackedInt32Array()
	var start_index := target_cell.y * world_tiles.x + target_cell.x
	_flow_distance[start_index] = 0
	queue.append(start_index)
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var cell := Vector2i(index % world_tiles.x, index / world_tiles.x)
		var distance := _flow_distance[index] + 1
		for direction in CARDINAL_DIRECTIONS:
			var next := cell + (direction as Vector2i)
			if not cell_in_bounds(next) or not is_cell_walkable(next):
				continue
			var next_index := next.y * world_tiles.x + next.x
			if _flow_distance[next_index] >= 0:
				continue
			_flow_distance[next_index] = distance
			queue.append(next_index)


func _build_minimap_texture() -> void:
	var image := Image.create(world_tiles.x, world_tiles.y, false, Image.FORMAT_RGBA8)
	for y in world_tiles.y:
		for x in world_tiles.x:
			image.set_pixel(x, y, _minimap_colors[y * world_tiles.x + x])
	minimap_texture = ImageTexture.create_from_image(image)


func _cells_in(rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if cell_in_bounds(cell):
				result.append(cell)
	return result


func _tile_center(tile: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * TILE_SIZE
