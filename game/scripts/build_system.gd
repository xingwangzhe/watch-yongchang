extends Node
class_name BuildSystem
## Mindustry/RWX 式多格建造：锚点 + 3x3 占格，校验资源与占用后放置建筑。
## 借鉴 Mindustry 的 multiblock（一个建筑占多格）与 RWX 的 Rect 占格模型：
## 以锚点为左上角，用 FOOTPRINT 展开所有格子，逐格校验边界/道路/占用。

signal building_placed(kind: StringName, cell: Vector2i, node: Node2D)
signal build_failed(reason: String)

const TILE: int = 32
const FOOTPRINT: Vector2i = Vector2i(3, 3)
const COSTS: Dictionary = {&"jianta": 40, &"junxiefang": 35, &"fenghuotai": 30}
const BUILDABLE: Array[StringName] = [&"jianta", &"junxiefang", &"fenghuotai"]

var occupied: Dictionary = {}   # 键 "c,r" -> String（建筑 id）

const TileMapBuilder = preload("res://scripts/tile_map_builder.gd")

## 世界坐标 → 瓦片坐标反算（复用 TileMapBuilder.TILE，保证与地图派生同一套网格）
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / TILE)), int(floor(world_pos.y / TILE)))

## 可建造格：在网格内、非道路行、非主堡区、非边缘墙
func is_buildable_cell(cell: Vector2i) -> bool:
	var c: int = cell.x
	var r: int = cell.y
	# 避开两侧城墙（c=0/COLS-1）与顶部水渠（r=1）
	if c < 2 or c > TileMapBuilder.COLS - 3:
		return false
	if r < 2 or r > TileMapBuilder.ROWS - 3:
		return false
	# 三条驿道（每条 ROAD_THICKNESS 行）不可占格
	for row in TileMapBuilder.LANE_ROWS:
		if r >= int(row) and r < int(row) + TileMapBuilder.ROAD_THICKNESS:
			return false
	# 双方主堡 3x8 区域不可占格
	for enemy in [false, true]:
		var a: Vector2i = TileMapBuilder.keep_anchor(enemy)
		if (c >= a.x and c < a.x + TileMapBuilder.KEEP_SIZE.x
			and r >= a.y and r < a.y + TileMapBuilder.KEEP_SIZE.y):
			return false
	return true

## 锚点为左上角，展开 FOOTPRINT 覆盖的所有格
func cells_for(anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy in range(FOOTPRINT.y):
		for dx in range(FOOTPRINT.x):
			cells.append(anchor + Vector2i(dx, dy))
	return cells

## 全格校验：类型合法 + 每格可建且未占用 + 银两足额
func can_place(anchor: Vector2i, kind: StringName) -> bool:
	if not BUILDABLE.has(kind):
		return false
	for cell in cells_for(anchor):
		if not is_buildable_cell(cell):
			return false
		if occupied.has(_key(cell)):
			return false
	return GameState.silver >= COSTS[kind]

## 放置建筑：失败发 build_failed 并 return null，成功扣银、记账、实例化、挂到 parent
func place(anchor: Vector2i, kind: StringName, parent: Node2D) -> Node2D:
	if not can_place(anchor, kind):
		build_failed.emit(_reject_reason(anchor, kind))
		return null

	GameState.add_silver(-int(COSTS[kind]))
	for cell in cells_for(anchor):
		occupied[_key(cell)] = str(kind)

	var node: Node2D
	if kind == &"jianta":
		# 箭塔用场景（tower.gd 负责索敌开火与攻击动画）
		var scene := load("res://scenes/tower_node.tscn") as PackedScene
		node = scene.instantiate() as Node2D
	else:
		# 军械坊/烽火台暂无独立场景：通用 Node2D + Sprite2D 显示 96px static.png
		node = Node2D.new()
		var sprite := Sprite2D.new()
		sprite.texture = ResourceManager.get_texture("res://assets/buildings/%s/static.png" % str(kind))
		node.add_child(sprite)

	# 3x3 锚点中心：(anchor + FOOTPRINT/2) * TILE
	node.position = (Vector2(anchor) + Vector2(FOOTPRINT) / 2.0) * TILE
	parent.add_child(node)
	building_placed.emit(kind, anchor, node)
	return node

func reset() -> void:
	occupied.clear()

func get_occupied_count() -> int:
	return occupied.size()

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

## 失败原因（交给 main.gd 写入 GameState.last_error / 打印）
func _reject_reason(anchor: Vector2i, kind: StringName) -> String:
	if not BUILDABLE.has(kind):
		return "未知建筑类型: %s" % str(kind)
	for cell in cells_for(anchor):
		if not is_buildable_cell(cell):
			return "不可建造的瓦片: %s" % str(cell)
		if occupied.has(_key(cell)):
			return "瓦片已被占用: %s" % str(cell)
	return "银两不足: 需要 %d" % int(COSTS[kind])
