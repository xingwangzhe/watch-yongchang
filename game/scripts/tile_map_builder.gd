extends Node2D
class_name TileMapBuilder
## Mindustry 式图块地图：小块瓦片 + 多格建筑（multiblock）。
## - 32px 瓦片，40×22 网格
## - 建筑按 size×size 占据多个瓦片（塔 3×3、主堡 3×8）
## - 四层 TileMapLayer：Ground / Road / Structure / Decor
## - 路径点从网格派生，Path2D 仅作不可见运动骨架

const TILE := 32
const COLS := 40
const ROWS := 22

# 三条驿道的起始行（每条路占 2 行高）；整体居中避开顶部标题区
const LANE_ROWS := [7, 11, 15]
const ROAD_THICKNESS := 2

# 塔锚点列；塔尺寸 3×3 格（96px）
const TOWER_COLS := [10, 20, 30]
const TOWER_SIZE := Vector2i(3, 3)
# 主堡尺寸 3×8 格
const KEEP_SIZE := Vector2i(3, 8)
const KEEP_ROW := 7

const SRC := 0
const T_GRASS_A := Vector2i(0, 0)
const T_GRASS_B := Vector2i(1, 0)
const T_ROAD := Vector2i(2, 0)
const T_ROAD_EDGE := Vector2i(3, 0)
const T_WALL := Vector2i(4, 0)
const T_STONE := Vector2i(5, 0)
const T_FOUNDATION := Vector2i(6, 0)
const T_WATER := Vector2i(7, 0)
const T_KEEP_OWN := Vector2i(8, 0)
const T_KEEP_ENEMY := Vector2i(9, 0)

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
const C_KEEP_OWN := Color(0.22, 0.40, 0.44)
const C_KEEP_ENEMY := Color(0.52, 0.20, 0.18)

# ---------- 网格 → 世界坐标派生 ----------

static func lane_y(row_index: int) -> float:
	# 道路占 row..row+THICKNESS-1，中心落在两行之间
	var row: int = LANE_ROWS[row_index]
	return float((row + ROAD_THICKNESS) * TILE / 2.0)

static func tower_anchor(row_index: int) -> Vector2i:
	# 塔基贴在道路上方，底边与道路行相邻
	return Vector2i(TOWER_COLS[row_index], LANE_ROWS[row_index] - TOWER_SIZE.y)

static func tower_center(row_index: int) -> Vector2:
	var a := tower_anchor(row_index)
	return Vector2(float(a.x + TOWER_SIZE.x) * TILE / 2.0,
		float(a.y + TOWER_SIZE.y) * TILE / 2.0)

static func keep_anchor(enemy: bool) -> Vector2i:
	var col: int = 0 if not enemy else COLS - KEEP_SIZE.x
	return Vector2i(col, KEEP_ROW)

static func keep_center(enemy: bool) -> Vector2:
	var a := keep_anchor(enemy)
	return Vector2(float(a.x + KEEP_SIZE.x) * TILE / 2.0,
		float(a.y + KEEP_SIZE.y) * TILE / 2.0)

# ---------- 构建 ----------

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

	# floor：棋盘微差草地 + 两侧城墙 + 顶部水渠
	for r in range(ROWS):
		for c in range(COLS):
			var tile := T_GRASS_A if (c + r) % 2 == 0 else T_GRASS_B
			if c == 0 or c == COLS - 1:
				tile = T_WALL
			ground.set_cell(Vector2i(c, r), SRC, tile)
			var h := (c * 73856093) ^ (r * 19349663)
			if c > 2 and c < COLS - 3 and r > 2 and absi(h) % 29 == 0:
				decor.set_cell(Vector2i(c, r), SRC, T_STONE)
	for c in range(2, COLS - 2):
		ground.set_cell(Vector2i(c, 1), SRC, T_WATER)

	# overlay：三条驿道（每条 2 行厚）
	for row in LANE_ROWS:
		for c in range(1, COLS - 1):
			for t in range(ROAD_THICKNESS):
				road.set_cell(Vector2i(c, row + t), SRC, T_ROAD)

	# build：多格建筑 —— 塔 3×3，主堡 3×8
	var buildings: Array[Dictionary] = []
	for i in range(TOWER_COLS.size()):
		var a := tower_anchor(i)
		_place_building(structure, a, TOWER_SIZE, T_FOUNDATION)
		buildings.append({"id": "tower_%d" % i, "anchor": a, "size": TOWER_SIZE})
	for enemy in [false, true]:
		var a := keep_anchor(enemy)
		var tile := T_KEEP_OWN if not enemy else T_KEEP_ENEMY
		_place_building(structure, a, KEEP_SIZE, tile)
		buildings.append({"id": "keep_enemy" if enemy else "keep_own", "anchor": a, "size": KEEP_SIZE})

	return {
		"ground": ground, "road": road, "structure": structure, "decor": decor,
		"cols": COLS, "rows": ROWS, "tile": TILE, "buildings": buildings,
	}

static func _place_building(layer: TileMapLayer, anchor: Vector2i, size: Vector2i, tile: Vector2i) -> void:
	for dy in range(size.y):
		for dx in range(size.x):
			layer.set_cell(anchor + Vector2i(dx, dy), SRC, tile)

static func _make_layer(p_name: String, tileset: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = p_name
	layer.tile_set = tileset
	layer.z_index = z
	return layer

static func _make_tileset() -> TileSet:
	var img := Image.create(TILE * 10, TILE, false, Image.FORMAT_RGBA8)
	_fill_tile(img, 0, C_GRASS_A, Color(0.11, 0.14, 0.10))
	_fill_tile(img, 1, C_GRASS_B, Color(0.12, 0.15, 0.11))
	_fill_tile(img, 2, C_ROAD, Color(0.38, 0.31, 0.22))
	_fill_tile(img, 3, C_ROAD_EDGE, Color(0.22, 0.18, 0.13))
	_fill_tile(img, 4, C_WALL, Color(0.14, 0.18, 0.20))
	_fill_tile(img, 5, C_STONE, Color(0.24, 0.25, 0.23))
	_fill_tile(img, 6, C_FOUNDATION, C_FOUNDATION_LINE)
	_fill_tile(img, 7, C_WATER, Color(0.10, 0.18, 0.22))
	_fill_tile(img, 8, C_KEEP_OWN, Color(0.12, 0.24, 0.26))
	_fill_tile(img, 9, C_KEEP_ENEMY, Color(0.30, 0.10, 0.09))

	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(img)
	atlas.texture_region_size = Vector2i(TILE, TILE)
	for i in range(10):
		atlas.create_tile(Vector2i(i, 0))
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_source(atlas, SRC)
	return tileset

static func _fill_tile(img: Image, index: int, base: Color, line: Color) -> void:
	var ox := index * TILE
	for y in range(TILE):
		for x in range(TILE):
			var n := float((x * 31 + y * 17 + index * 13) % 11) / 11.0
			var col := base.lerp(line, n * 0.35)
			if x == 0 or y == 0:
				col = line
			img.set_pixel(ox + x, y, col)
