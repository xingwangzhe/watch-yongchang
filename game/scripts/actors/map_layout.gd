class_name MapLayout
extends RefCounted

const TILE_SIZE := 32.0
const CARDINAL_DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const FLOW_MIN_REQUEST_CELLS := 2
const PATH_CACHE_LIMIT := 96
const MINIMAP_BRIDGE := Color("#c4a06b")
const MINIMAP_BRIDGE_RAILING := Color("#4e3527")

signal connectivity_repaired(cells: Array)

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
var initial_blocked_points: Array[Vector2] = []

var _solid_cells: Dictionary = {}
var _solid_flags := PackedByteArray()
var _open3x3_flags := PackedByteArray()
var _walkable_summary_ready := false
var _water_cells: Dictionary = {}
var _water_flags := PackedByteArray()
var _bridge_cells: Dictionary = {}
var _bridge_flags := PackedByteArray()
var _repaired_cells: Dictionary = {}
var _minimap_colors := PackedColorArray()
var _spawn_samples := PackedVector2Array()
var _flow_distance := PackedInt32Array()
var _flow_next_cells := PackedInt32Array()
var _flow_queue := PackedInt32Array()
var _flow_target_cell := Vector2i(-1, -1)
var _flow_build_distance := PackedInt32Array()
var _flow_build_next_cells := PackedInt32Array()
var _flow_build_queue := PackedInt32Array()
var _flow_build_target_cell := Vector2i(-1, -1)
var _flow_pending_target_cell := Vector2i(-1, -1)
var _flow_build_head := 0
var _flow_build_tail := 0
var _flow_build_active := false
var _path_cache: Dictionary = {}
var _path_cache_order: Array[int] = []
var path_queries := 0
var path_cache_hits := 0


func setup(map_key: String, definition: Dictionary) -> void:
	map_id = map_key
	_solid_cells.clear()
	_water_cells.clear()
	_bridge_cells.clear()
	_repaired_cells.clear()
	_flow_distance.clear()
	_flow_next_cells.clear()
	_flow_build_distance.clear()
	_flow_build_next_cells.clear()
	_flow_build_active = false
	_flow_target_cell = Vector2i(-1, -1)
	_flow_build_target_cell = Vector2i(-1, -1)
	_flow_pending_target_cell = Vector2i(-1, -1)
	_path_cache.clear()
	_path_cache_order.clear()
	path_queries = 0
	path_cache_hits = 0
	minimap_texture = null
	initial_blocked_points.clear()
	var layout: Dictionary = definition.get("layout", {}) as Dictionary
	var size_data: Array = layout.get("world_tiles", [120, 84]) as Array
	world_tiles = Vector2i(int(size_data[0]), int(size_data[1]))
	world_size = Vector2(world_tiles) * TILE_SIZE
	_solid_flags.resize(world_tiles.x * world_tiles.y)
	_solid_flags.fill(0)
	_open3x3_flags.resize(world_tiles.x * world_tiles.y)
	_open3x3_flags.fill(0)
	_walkable_summary_ready = false
	_water_flags.resize(world_tiles.x * world_tiles.y)
	_water_flags.fill(0)
	_bridge_flags.resize(world_tiles.x * world_tiles.y)
	_bridge_flags.fill(0)
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
	# 并通过 connectivity_repaired 通知渲染器同步重画。正式地图应在报告里为 0。
	last_repair_count = 0
	var report := connectivity_report()
	if not report.get("ok", true):
		initial_blocked_points.assign(report.get("blocked_points", []))
		last_repair_count = repair_connectivity()
		push_warning("Map %s connectivity repaired on %d lanes" % [map_id, last_repair_count])
	_rebuild_walkable_summary()
	_build_minimap_texture()


func mark_solid_rect(rect: Rect2i) -> void:
	for cell in _cells_in(rect):
		_solid_cells[cell] = true
		_solid_flags[cell.y * world_tiles.x + cell.x] = 1
	_walkable_summary_ready = false


func clear_solid_rect(rect: Rect2i) -> void:
	for cell in _cells_in(rect):
		_solid_cells.erase(cell)
		_solid_flags[cell.y * world_tiles.x + cell.x] = 0
	_walkable_summary_ready = false


func mark_water_rect(rect: Rect2i) -> void:
	for cell in _cells_in(rect):
		_water_cells[cell] = true
		_water_flags[cell.y * world_tiles.x + cell.x] = 1


func clear_water_rect(rect: Rect2i) -> void:
	for cell in _cells_in(rect):
		_water_cells.erase(cell)
		_water_flags[cell.y * world_tiles.x + cell.x] = 0


func mark_bridge_rect(rect: Rect2i) -> void:
	for cell in _cells_in(rect):
		_bridge_cells[cell] = true
		_bridge_flags[cell.y * world_tiles.x + cell.x] = 1
		set_minimap_color(cell, MINIMAP_BRIDGE)


func clear_bridge_rect(rect: Rect2i) -> void:
	for cell in _cells_in(rect):
		_bridge_cells.erase(cell)
		_bridge_flags[cell.y * world_tiles.x + cell.x] = 0


func set_minimap_color_rect(rect: Rect2i, color: Color) -> void:
	for cell in _cells_in(rect):
		set_minimap_color(cell, color)


func set_minimap_color(cell: Vector2i, color: Color) -> void:
	if not cell_in_bounds(cell):
		return
	_minimap_colors[cell.y * world_tiles.x + cell.x] = color


func is_solid_cell(cell: Vector2i) -> bool:
	if not cell_in_bounds(cell):
		return false
	return _solid_flags[cell.y * world_tiles.x + cell.x] != 0


func is_water_cell(cell: Vector2i) -> bool:
	if not cell_in_bounds(cell):
		return false
	return _water_flags[cell.y * world_tiles.x + cell.x] != 0


func is_bridge_cell(cell: Vector2i) -> bool:
	if not cell_in_bounds(cell):
		return false
	return _bridge_flags[cell.y * world_tiles.x + cell.x] != 0


func is_cell_walkable(cell: Vector2i) -> bool:
	if not cell_in_bounds(cell):
		return false
	if _solid_flags[cell.y * world_tiles.x + cell.x] != 0:
		return false
	# 水面可以通行，但会减速并溅起水花；桥面不受涉水影响。
	return true


## 涉水判定：水面且不在桥上、不是实心障碍。涉水减速对所有单位生效。
func is_wade_position(position: Vector2) -> bool:
	var cell := world_to_cell(position)
	if not cell_in_bounds(cell):
		return false
	var index := cell.y * world_tiles.x + cell.x
	return _water_flags[index] != 0 and _bridge_flags[index] == 0 and _solid_flags[index] == 0


func is_point_walkable(position: Vector2, radius: float = 18.0) -> bool:
	if position.x - radius < 0.0 or position.y - radius < 0.0:
		return false
	if position.x + radius >= world_size.x or position.y + radius >= world_size.y:
		return false
	var min_cell := world_to_cell(position - Vector2.ONE * radius)
	var max_cell := world_to_cell(position + Vector2.ONE * radius)
	if _walkable_summary_ready and max_cell.x - min_cell.x <= 2 and max_cell.y - min_cell.y <= 2:
		var center_cell := world_to_cell(position)
		if _open3x3_flags[center_cell.y * world_tiles.x + center_cell.x] != 0:
			return true
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


func _rebuild_walkable_summary() -> void:
	var total := world_tiles.x * world_tiles.y
	_open3x3_flags.resize(total)
	_open3x3_flags.fill(0)
	for y in range(world_tiles.y):
		for x in range(world_tiles.x):
			var index := y * world_tiles.x + x
			var clear := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= world_tiles.x or ny >= world_tiles.y:
						clear = false
						break
					if _solid_flags[ny * world_tiles.x + nx] != 0:
						clear = false
						break
				if not clear:
					break
			_open3x3_flags[index] = 1 if clear else 0
	_walkable_summary_ready = true


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
	var blocked_points: Array[Vector2] = []
	for point in _spawn_samples:
		var cell := world_to_cell(point)
		if not cell_in_bounds(cell) or not is_point_walkable(point, 14.0):
			blocked += 1
			blocked_points.append(point)
			continue
		if reachable[cell.y * world_tiles.x + cell.x] != 1:
			blocked += 1
			blocked_points.append(point)
	return {
		"ok": start_walkable and blocked == 0,
		"samples": _spawn_samples.size(),
		"blocked": blocked,
		"start_walkable": start_walkable,
		"blocked_points": blocked_points,
	}


## 兜底修复：对不可达的出生带，沿直线向玩家出生点清出一条可走走廊。
## 记录每个被开路的格子；渲染器收到信号后必须同步重画，不能留下隐形通路。
func repair_connectivity() -> int:
	if not is_point_walkable(start_pos, 18.0):
		start_pos = find_walkable_position(start_pos, 18.0)
	_repaired_cells.clear()
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
	_build_minimap_texture()
	if repaired > 0:
		connectivity_repaired.emit(repaired_cell_list())
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
				_solid_flags[cell.y * world_tiles.x + cell.x] = 0
				if _water_cells.has(cell):
					_bridge_cells[cell] = true
					_bridge_flags[cell.y * world_tiles.x + cell.x] = 1
					set_minimap_color(cell, MINIMAP_BRIDGE)
				else:
					_bridge_cells.erase(cell)
					_bridge_flags[cell.y * world_tiles.x + cell.x] = 0
					set_minimap_color(cell, minimap_color_for_tile("earth_road_a"))
				_repaired_cells[cell] = true


func ensure_flow_field(target: Vector2) -> void:
	_flow_build_active = false
	_flow_pending_target_cell = Vector2i(-1, -1)
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


## 请求在后台增量更新流场。旧流场在构建完成前继续可用，避免移动穿格时卡顿。
## 目标只跨一格时不重建，单格误差由敌人朝向与碰撞滑动吸收。
func request_flow_field(target: Vector2) -> void:
	var cell := world_to_cell(target)
	if not cell_in_bounds(cell):
		return
	if not is_cell_walkable(cell):
		cell = world_to_cell(find_walkable_position(target))
	if _flow_build_active:
		_flow_pending_target_cell = (
			Vector2i(-1, -1)
			if _cell_near(cell, _flow_build_target_cell)
			else cell
		)
		return
	if (
		_flow_target_cell.x >= 0
		and _cell_near(cell, _flow_target_cell)
	):
		return
	_start_flow_build(cell)


func _cell_near(left: Vector2i, right: Vector2i) -> bool:
	return (
		absi(left.x - right.x) < FLOW_MIN_REQUEST_CELLS
		and absi(left.y - right.y) < FLOW_MIN_REQUEST_CELLS
	)


func _start_flow_build(cell: Vector2i) -> void:
	_flow_build_active = false
	var width := world_tiles.x
	var total := width * world_tiles.y
	_flow_build_distance.resize(total)
	_flow_build_distance.fill(-1)
	_flow_build_next_cells.resize(total)
	_flow_build_next_cells.fill(-1)
	_flow_build_queue.resize(total)
	_flow_build_target_cell = cell
	_flow_pending_target_cell = Vector2i(-1, -1)
	_flow_build_head = 0
	_flow_build_tail = 0
	var start_index := cell.y * width + cell.x
	if _solid_flags[start_index] != 0:
		return
	_flow_build_distance[start_index] = 0
	_flow_build_queue[0] = start_index
	_flow_build_tail = 1
	_flow_build_active = true


## 每帧推进固定格数；完成后交换双缓冲。返回值表示本轮是否完成一次构建。
func advance_flow_field(max_cells: int = 256) -> bool:
	if not _flow_build_active:
		return false
	var width := world_tiles.x
	var height := world_tiles.y
	var processed := 0
	while _flow_build_head < _flow_build_tail and processed < max_cells:
		var index := _flow_build_queue[_flow_build_head]
		_flow_build_head += 1
		processed += 1
		var cell_x := index % width
		var cell_y := index / width
		var distance := _flow_build_distance[index] + 1
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var next_x := cell_x + dx
				var next_y := cell_y + dy
				if next_x < 0 or next_y < 0 or next_x >= width or next_y >= height:
					continue
				var next_index := next_y * width + next_x
				if _solid_flags[next_index] != 0 or _flow_build_distance[next_index] >= 0:
					continue
				if dx != 0 and dy != 0:
					if _solid_flags[cell_y * width + next_x] != 0:
						continue
					if _solid_flags[next_y * width + cell_x] != 0:
						continue
				_flow_build_distance[next_index] = distance
				_flow_build_next_cells[next_index] = index
				_flow_build_queue[_flow_build_tail] = next_index
				_flow_build_tail += 1
	if _flow_build_head < _flow_build_tail:
		return false
	var old_distance := _flow_distance
	var old_next := _flow_next_cells
	var old_queue := _flow_queue
	_flow_distance = _flow_build_distance
	_flow_next_cells = _flow_build_next_cells
	_flow_queue = _flow_build_queue
	_flow_target_cell = _flow_build_target_cell
	_flow_build_distance = old_distance
	_flow_build_next_cells = old_next
	_flow_build_queue = old_queue
	_flow_build_active = false
	_flow_build_head = 0
	_flow_build_tail = 0
	var pending := _flow_pending_target_cell
	_flow_pending_target_cell = Vector2i(-1, -1)
	if pending.x >= 0 and not _cell_near(pending, _flow_target_cell):
		_start_flow_build(pending)
	return true


func flow_direction(position: Vector2) -> Vector2:
	var total := world_tiles.x * world_tiles.y
	if _flow_distance.size() != total or _flow_next_cells.size() != total:
		return Vector2.ZERO
	var cell := world_to_cell(position)
	if not cell_in_bounds(cell):
		return Vector2.ZERO
	var next_index := _flow_next_cells[cell.y * world_tiles.x + cell.x]
	if next_index < 0:
		return Vector2.ZERO
	var next_cell := Vector2i(next_index % world_tiles.x, next_index / world_tiles.x)
	return (_tile_center(next_cell) - position).normalized()


func navigation_direction(
	from: Vector2,
	to: Vector2,
	direct_range: float = 190.0,
	clearance_radius: float = 10.0
) -> Vector2:
	var direct := to - from
	if direct.length_squared() <= direct_range * direct_range:
		if (
			direct.length_squared() <= 48.0 * 48.0
			or is_segment_walkable(from, to, clearance_radius)
		):
			return direct.normalized()
	# 长距离追击只做一次粗粒度通视判定：开阔地直接切向目标，
	# 避免单位明明看得见却沿流场走折线；被建筑挡住时才回到共享流场。
	if (
		direct.length_squared() <= 360.0 * 360.0
		and is_segment_walkable(from, to, clearance_radius)
	):
		return direct.normalized()
	var flow := flow_direction(from)
	if flow != Vector2.ZERO:
		return flow
	return direct.normalized()


## RTS 式路径请求：A* 只在友军、少量特殊单位或重寻路时使用，
## 大群敌人继续共享流场，避免 460 个单位各自搜索。
## 返回经过视线简化的世界坐标路点；空数组表示不可达。
func find_path(from: Vector2, to: Vector2, radius: float = 14.0) -> PackedVector2Array:
	var start_cell := world_to_cell(from)
	var goal_cell := world_to_cell(to)
	if not cell_in_bounds(start_cell) or not cell_in_bounds(goal_cell):
		return PackedVector2Array()
	if not is_cell_walkable(start_cell):
		start_cell = world_to_cell(find_walkable_position(from, radius))
	if not is_cell_walkable(goal_cell):
		goal_cell = world_to_cell(find_walkable_position(to, radius))
	var cache_key := _path_key(start_cell, goal_cell, radius)
	if _path_cache.has(cache_key):
		path_cache_hits += 1
		return _path_cache[cache_key] as PackedVector2Array
	path_queries += 1
	var cells := _astar_cells(start_cell, goal_cell)
	var path := PackedVector2Array()
	if cells.is_empty():
		return path
	var raw := PackedVector2Array()
	for cell in cells:
		raw.append(_tile_center(cell))
	# 视线简化（string pulling）：只保留能相互直达的关键路点。
	var anchor := 0
	path.append(from)
	while anchor < raw.size() - 1:
		var farthest := anchor + 1
		for probe in range(raw.size() - 1, anchor, -1):
			if is_segment_walkable(raw[anchor], raw[probe], radius):
				farthest = probe
				break
		path.append(raw[farthest])
		anchor = farthest
	if path.size() > 1 and path[path.size() - 1].distance_squared_to(from) < 4.0:
		path.remove_at(path.size() - 1)
	_path_cache[cache_key] = path
	_path_cache_order.append(cache_key)
	while _path_cache_order.size() > PATH_CACHE_LIMIT:
		var stale: int = _path_cache_order.pop_front()
		_path_cache.erase(stale)
	return path


func _path_key(start_cell: Vector2i, goal_cell: Vector2i, radius: float) -> int:
	var bucket := clampi(roundi(radius), 0, 63)
	return (((start_cell.y * world_tiles.x + start_cell.x) * world_tiles.x * world_tiles.y
		+ goal_cell.y * world_tiles.x + goal_cell.x) << 6) | bucket


func _astar_cells(start_cell: Vector2i, goal_cell: Vector2i) -> Array[Vector2i]:
	var width := world_tiles.x
	var total := width * world_tiles.y
	var start_index := start_cell.y * width + start_cell.x
	var goal_index := goal_cell.y * width + goal_cell.x
	var g_score := PackedInt32Array()
	g_score.resize(total)
	g_score.fill(1_000_000_000)
	var came_from := PackedInt32Array()
	came_from.resize(total)
	came_from.fill(-1)
	var closed := PackedByteArray()
	closed.resize(total)
	closed.fill(0)
	var heap_indices := PackedInt32Array()
	var heap_f := PackedInt32Array()
	g_score[start_index] = 0
	_heap_push(heap_indices, heap_f, start_index, _octile_heuristic(start_cell, goal_cell))
	var found := false
	var guard := 0
	while not heap_indices.is_empty() and guard < total:
		guard += 1
		var current := _heap_pop(heap_indices, heap_f)
		if closed[current] != 0:
			continue
		closed[current] = 1
		if current == goal_index:
			found = true
			break
		var cell := Vector2i(current % width, current / width)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var next := cell + Vector2i(dx, dy)
				if not cell_in_bounds(next) or not is_cell_walkable(next):
					continue
				if dx != 0 and dy != 0:
					# 禁止穿墙角：两个正交邻格都必须是空的。
					if not is_cell_walkable(cell + Vector2i(dx, 0)):
						continue
					if not is_cell_walkable(cell + Vector2i(0, dy)):
						continue
				var next_index := next.y * width + next.x
				if closed[next_index] != 0:
					continue
				var step_cost := 10 if dx == 0 or dy == 0 else 14
				# 贴近墙体的格子增加代价，单位自然走通道中心。
				step_cost += _wall_pressure_cost(next) * 3
				var tentative := g_score[current] + step_cost
				if tentative >= g_score[next_index]:
					continue
				came_from[next_index] = current
				g_score[next_index] = tentative
				_heap_push(
					heap_indices,
					heap_f,
					next_index,
					tentative + _octile_heuristic(next, goal_cell)
				)
	var result: Array[Vector2i] = []
	if not found:
		return result
	var cursor := goal_index
	while cursor >= 0:
		result.append(Vector2i(cursor % width, cursor / width))
		if cursor == start_index:
			break
		cursor = came_from[cursor]
	result.reverse()
	return result


func _octile_heuristic(from: Vector2i, to: Vector2i) -> int:
	var dx := absi(from.x - to.x)
	var dy := absi(from.y - to.y)
	return 10 * maxi(dx, dy) + 4 * mini(dx, dy)


func _wall_pressure_cost(cell: Vector2i) -> int:
	var pressure := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if is_solid_cell(cell + Vector2i(dx, dy)):
				pressure += 1
	return pressure


func _heap_push(indices: PackedInt32Array, costs: PackedInt32Array, index: int, cost: int) -> void:
	indices.append(index)
	costs.append(cost)
	var cursor := indices.size() - 1
	while cursor > 0:
		var parent := (cursor - 1) / 2
		if costs[parent] <= costs[cursor]:
			break
		var tmp_i := indices[parent]
		var tmp_c := costs[parent]
		indices[parent] = indices[cursor]
		costs[parent] = costs[cursor]
		indices[cursor] = tmp_i
		costs[cursor] = tmp_c
		cursor = parent


func _heap_pop(indices: PackedInt32Array, costs: PackedInt32Array) -> int:
	var result := indices[0]
	var last_index := indices.size() - 1
	indices[0] = indices[last_index]
	costs[0] = costs[last_index]
	indices.resize(last_index)
	costs.resize(last_index)
	var cursor := 0
	while true:
		var left := cursor * 2 + 1
		var right := left + 1
		var smallest := cursor
		if left < indices.size() and costs[left] < costs[smallest]:
			smallest = left
		if right < indices.size() and costs[right] < costs[smallest]:
			smallest = right
		if smallest == cursor:
			break
		var tmp_i := indices[cursor]
		var tmp_c := costs[cursor]
		indices[cursor] = indices[smallest]
		costs[cursor] = costs[smallest]
		indices[smallest] = tmp_i
		costs[smallest] = tmp_c
		cursor = smallest
	return result


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
	return move_circle_known_walkable(from, to, radius)


## 调用方保证 from 可走时使用：先尝试直达，只有终点被挡才退化为轴向滑动。
## 每帧位移远小于一格，直达检查不会让单位穿过 32px 实心格。
func move_circle_known_walkable(from: Vector2, to: Vector2, radius: float = 18.0) -> Vector2:
	if is_point_walkable(to, radius):
		return to
	var result := from
	var x_candidate := Vector2(to.x, result.y)
	if is_point_walkable(x_candidate, radius):
		result.x = to.x
	var y_candidate := Vector2(result.x, to.y)
	if is_point_walkable(y_candidate, radius):
		result.y = to.y
	# 凹角/塔基边缘：轴向滑动失败时沿墙面切向探步，避免原地卡死。
	if result.distance_squared_to(from) < 0.01:
		var desired := to - from
		var step := desired.length()
		if step > 0.01:
			var base := desired / step
			for angle in [30.0, -30.0, 60.0, -60.0, 90.0, -90.0]:
				var candidate := from + base.rotated(deg_to_rad(angle)) * step
				if is_point_walkable(candidate, radius):
					return candidate
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
	request_flow_field(player_position)
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


func repaired_cell_list() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _repaired_cells.keys():
		cells.append(cell as Vector2i)
	return cells


func landmark_entries() -> Array[Dictionary]:
	return landmarks


func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / TILE_SIZE), floori(position.y / TILE_SIZE))


func cell_center(cell: Vector2i) -> Vector2:
	return _tile_center(cell)


func cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < world_tiles.x and cell.y < world_tiles.y


func minimap_color_for_tile(tile_name: String) -> Color:
	if tile_name.begins_with("water_deep"):
		return Color("#163a45")
	if tile_name.begins_with("water_shallow"):
		return Color("#235864")
	if tile_name.begins_with("shore"):
		# 岸线瓦片本质仍是可涉水水体；小地图必须按水色绘制，不能变成沙地色块。
		return Color("#235864")
	if tile_name == "dock_vertical" or tile_name == "dock_horizontal":
		return MINIMAP_BRIDGE
	if tile_name.begins_with("stone_road") or tile_name.begins_with("wet_stone"):
		return Color("#9f9275")
	if tile_name.begins_with("earth_road") or tile_name == "gravel":
		return Color("#87785b")
	if tile_name.begins_with("mountain"):
		return Color("#293331")
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
	_flow_build_active = false
	var width := world_tiles.x
	var height := world_tiles.y
	var total := width * height
	_flow_distance.resize(total)
	_flow_distance.fill(-1)
	_flow_next_cells.resize(total)
	_flow_next_cells.fill(-1)
	_flow_queue.resize(total)
	_flow_target_cell = target_cell
	var start_index := target_cell.y * width + target_cell.x
	if start_index < 0 or start_index >= total or _solid_flags[start_index] != 0:
		return
	_flow_distance[start_index] = 0
	_flow_queue[0] = start_index
	var head := 0
	var tail := 1
	while head < tail:
		var index := _flow_queue[head]
		head += 1
		var cell_x := index % width
		var cell_y := index / width
		var distance := _flow_distance[index] + 1
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var next_x := cell_x + dx
				var next_y := cell_y + dy
				if next_x < 0 or next_y < 0 or next_x >= width or next_y >= height:
					continue
				var next_index := next_y * width + next_x
				if _solid_flags[next_index] != 0 or _flow_distance[next_index] >= 0:
					continue
				if dx != 0 and dy != 0:
					if _solid_flags[cell_y * width + next_x] != 0:
						continue
					if _solid_flags[next_y * width + cell_x] != 0:
						continue
				_flow_distance[next_index] = distance
				_flow_next_cells[next_index] = index
				_flow_queue[tail] = next_index
				tail += 1


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
