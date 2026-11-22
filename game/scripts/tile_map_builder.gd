extends Node2D
class_name TileMapBuilder
## 程序化图块地图 —— 借鉴 Mindustry 的 floor / overlay / build 三层模型。
## 瓦片纹理由代码生成（零外部素材依赖），四层 TileMapLayer 分离。
## 调整 LANE_ROWS / TOWER_COLS 即可改地图布局，路径点自动从网格派生。

const TILE := 48
const COLS := 27
const ROWS := 15

# 三路所在瓦片行、塔位所在瓦片列（对齐道路行上方一格）
const LANE_ROWS := [4, 7, 10]
const TOWER_COLS := [8, 14, 20]

const SRC := 0
const T_GRASS_A := Vector2i(0, 0)
const T_GRASS_B := Vector2i(1, 0)
const T_ROAD := Vector2i(2, 0)
const T_ROAD_EDGE := Vector2i(3, 0)
const T_WALL := Vector2i(4, 0)
const T_STONE := Vector2i(5, 0)
const T_FOUNDATION := Vector2i(6, 0)
const T_WATER := Vector2i(7, 0)

# 国风配色
const C_GRASS_A := Color(0.20, 0.24, 0.19)
const C_GRASS_B := Color(0.22, 0.26, 0.21)
const C_ROAD := Color(0.52, 0.43, 0.30)
const C_ROAD_EDGE := Color(0.33, 0.28, 0.20)
const C_WALL := Color(0.24, 0.29, 0.32)
const C_STONE := Color(0.34, 0.35, 0.33)
const C_FOUNDATION := Color(0.42, 0.24, 0.20)
const C_FOUNDATION_LINE := Color(0.26, 0.13, 0.11)
const C_WATER := Color(0.15, 0.26, 0.31)

static func lane_y(row_index: int) -> float:
	return float(LANE_ROWS[row_index] * TILE + TILE / 2)

static func tower_x(col_index: int) -> float:
	return float(TOWER_COLS[col_index] * TILE + TILE / 2)

static func build(parent: Node2D) -> Dictionary:
	var tileset := _make_tileset()
	var ground := _make_layer("GroundLayer", tileset, -40)
	var road := _make_layer("RoadLayer", tileset, -30)
	var structure := _make_layer("StructureLayer", tileset, -20)
	var decor := _make_layer("DecorLayer", tileset, -10)
	parent.add_child(ground)
	parent.add_child(road)
	parent.add_child(structure)
	parent.add_child(decor)

	# floor：棋盘微差的草地 + 两侧城墙
	for r in range(ROWS):
		for c in range(COLS):
			var tile := T_GRASS_A if (c + r) % 2 == 0 else T_GRASS_B
			if c == 0 or c == COLS - 1:
				tile = T_WALL
			ground.set_cell(Vector2i(c, r), SRC, tile)
			# decor：确定性散石，不随机（地图可复现）
			var h := (c * 73856093) ^ (r * 19349663)
			if c > 1 and c < COLS - 2 and absi(h) % 17 == 0:
				decor.set_cell(Vector2i(c, r), SRC, T_STONE)

	# overlay：三条驿道（仅路面瓦片，瓦片内已有 1px 墨线边框）
	# 不再铺满上下边缘行，让草地层次透出来（Mindustry 的 overlay 是单层薄覆盖）
	for row in LANE_ROWS:
		for c in range(1, COLS - 1):
			road.set_cell(Vector2i(c, row), SRC, T_ROAD)
		# 驿道两端的城门缺口
		road.set_cell(Vector2i(0, row), SRC, T_FOUNDATION)
		road.set_cell(Vector2i(COLS - 1, row), SRC, T_FOUNDATION)

	# build：塔基（道路行上方一格）
	for i in range(LANE_ROWS.size()):
		var row: int = LANE_ROWS[i] - 1
		var col: int = TOWER_COLS[i]
		structure.set_cell(Vector2i(col, row), SRC, T_FOUNDATION)

	# 水渠：顶部两行，呼应烽火台冷却设定
	for c in range(2, COLS - 2):
		ground.set_cell(Vector2i(c, 1), SRC, T_WATER)

	return {
		"ground": ground,
		"road": road,
		"structure": structure,
		"decor": decor,
		"cols": COLS,
		"rows": ROWS,
		"tile": TILE,
	}

static func _make_layer(p_name: String, tileset: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = p_name
	layer.tile_set = tileset
	layer.z_index = z
	return layer

static func _make_tileset() -> TileSet:
	var img := Image.create(TILE * 8, TILE, false, Image.FORMAT_RGBA8)
	_fill_tile(img, 0, C_GRASS_A, Color(0.11, 0.14, 0.10))
	_fill_tile(img, 1, C_GRASS_B, Color(0.12, 0.15, 0.11))
	_fill_tile(img, 2, C_ROAD, Color(0.38, 0.31, 0.22))
	_fill_tile(img, 3, C_ROAD_EDGE, Color(0.22, 0.18, 0.13))
	_fill_tile(img, 4, C_WALL, Color(0.14, 0.18, 0.20))
	_fill_tile(img, 5, C_STONE, Color(0.24, 0.25, 0.23))
	_fill_tile(img, 6, C_FOUNDATION, C_FOUNDATION_LINE)
	_fill_tile(img, 7, C_WATER, Color(0.10, 0.18, 0.22))

	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(img)
	atlas.texture_region_size = Vector2i(TILE, TILE)
	for i in range(8):
		atlas.create_tile(Vector2i(i, 0))
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_source(atlas, SRC)
	return tileset

static func _fill_tile(img: Image, index: int, base: Color, line: Color) -> void:
	var ox := index * TILE
	for y in range(TILE):
		for x in range(TILE):
			# 确定性噪点：像素风颗粒感
			var n := float((x * 31 + y * 17 + index * 13) % 11) / 11.0
			var col := base.lerp(line, n * 0.35)
			# 瓦片边框：1px 墨线，强化图块可读性
			if x == 0 or y == 0:
				col = line
			img.set_pixel(ox + x, y, col)
