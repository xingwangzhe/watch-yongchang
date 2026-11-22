extends Node2D
class_name TileMapBuilder
## Hard Vacuum (Tiled 标准 20px 图块) 大地图：96×72 格，显示 40px（源 ×2）。
## - 多 TileSetAtlasSource：每个 png 一个图块集（与 assets/tiles/hv/*.tsx 一一对应）
## - 色键块（trans 008a76 teal）自动跳过
## - 布局：三条驿道横贯、左主堡右刷新点、左中/右下山石区、左上水池、草地变体与树点缀
## - 生成确定性（固定种子），blocked 集合供建造系统查询
## - 自由摄像机：地图远大于屏幕，配合 camera_rig.gd 平移缩放

const TILE := 40            # 显示尺寸（源 20px，TileMapLayer scale=2）
const SRC := 20             # Tiled 标准源瓦片尺寸
const COLS := 96
const ROWS := 72
const WORLD_SIZE := Vector2(COLS * TILE, ROWS * TILE)  # 3840×2880

const LANE_ROWS := [18, 36, 54]
const ROAD_THICKNESS := 2
const SPAWN_COL: int = 92
const TOWER_COLS := [12, 40, 68]
const TOWER_SIZE := Vector2i(3, 3)
const KEEP_SIZE := Vector2i(3, 8)
const KEEP_ROW := 32        # (ROWS - KEEP_SIZE.y) / 2
const GEN_SEED := 20260322

const TRANS := Color8(0, 138, 118)  # Hard Vacuum / RWX 共用色键

# decoration.png 中的灰石组成块：RWX 里用作山体/城墙的组成部分，作独立草地点缀会像"灰方块"，排除
const DECOR_EXCLUDE: Array = [Vector2i(0, 3), Vector2i(0, 4), Vector2i(1, 3), Vector2i(2, 1)]

# 源图 → id（与 assets/tiles/hv/*.tsx 对应）
const S_GRASS := 0
const S_LONG := 1
const S_DIRT := 2
const S_STONE := 3
const S_WATER := 4
const S_DECOR := 5
const S_G2W := 6   # longgrass2shallowwater（上草下水）
const S_G2S := 7   # longgrass2stone（上草下石）
const S_G2M := 8   # longgrass2mountain（上草下山）

const SOURCES: Array = [
	["res://assets/tiles/hv/bitmaps/shortgrass.png"],
	["res://assets/tiles/hv/bitmaps/longgrass.png"],
	["res://assets/tiles/hv/bitmaps/dirt.png"],
	["res://assets/tiles/hv/bitmaps/stone.png"],
	["res://assets/tiles/hv/bitmaps/water.png"],
	["res://assets/tiles/hv/bitmaps/decoration.png"],
	["res://assets/tiles/hv/bitmaps/longgrass2shallowwater_flat.png"],
	["res://assets/tiles/hv/bitmaps/longgrass2stone_flat.png"],
	["res://assets/tiles/hv/bitmaps/longgrass2mountain_flat.png"],
]

# 水池 / 山石区（含上边缘过渡行）
const WATER_RECT := Rect2i(2, 3, 11, 8)      # 水面块（row 2 为过渡行）
const STONE_RECT_R := Rect2i(58, 58, 33, 11) # 右下山石（row 57 过渡）
const STONE_RECT_L := Rect2i(6, 44, 21, 9)   # 左中石山（row 43 过渡）

static var _rng := RandomNumberGenerator.new()

# ---------- 网格 → 世界坐标派生 ----------

static func lane_y(row_index: int) -> float:
	var row: int = LANE_ROWS[row_index]
	return float((row + ROAD_THICKNESS) * TILE / 2.0)

static func spawn_cell(lane: int) -> Vector2i:
	return Vector2i(SPAWN_COL, LANE_ROWS[lane])

static func spawn_world(lane: int) -> Vector2:
	var c := spawn_cell(lane)
	return Vector2(float(c.x * TILE) + TILE * 0.5, lane_y(lane))

static func tower_anchor(row_index: int) -> Vector2i:
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
	_rng.seed = GEN_SEED
	# tileset: TileSet；valid: {source_id: Array[Vector2i]} 各源已注册的合法块坐标
	# （越界坐标与色键占位块均未注册，随机取块必须只从 valid 取，否则 set_cell 静默失败露出背景）
	var ts := _make_tileset()
	var tileset: TileSet = ts["tileset"]
	var valid: Dictionary = ts["valid"]
	var ground := _make_layer("GroundLayer", tileset, -40)
	var road := _make_layer("RoadLayer", tileset, -30)
	var structure := _make_layer("StructureLayer", tileset, -20)
	var decor := _make_layer("DecorLayer", tileset, -10)
	parent.add_child(ground)
	parent.add_child(road)
	parent.add_child(structure)
	parent.add_child(decor)

	var blocked: Dictionary = {}  # "c,r" -> true

	for r in range(ROWS):
		for c in range(COLS):
			ground.set_cell(Vector2i(c, r), S_GRASS, Vector2i(0, 0))
			# 草地变体与树点缀（避开边缘与车道区）
			if c > 1 and c < COLS - 2 and r > 1 and r < ROWS - 2:
				var roll := _rng.randf()
				if roll < 0.055:
					ground.set_cell(Vector2i(c, r), S_LONG, _pick(S_LONG, valid))
				elif roll < 0.075:
					decor.set_cell(Vector2i(c, r), S_DECOR, _pick(S_DECOR, valid))

	# 水池（上边缘用 草→水 过渡行）
	_fill_ground(ground, WATER_RECT, S_WATER, blocked, valid)
	var wt := Vector2i(int(WATER_RECT.position.x) - 1, int(WATER_RECT.position.y) - 1)
	for dx in range(int(WATER_RECT.size.x) + 2):
		ground.set_cell(wt + Vector2i(dx, 0), S_G2W, Vector2i(0, 0))

	# 山石区（上边缘 草→石 / 草→山 过渡行）
	_fill_ground(ground, STONE_RECT_R, S_STONE, blocked, valid)
	var st := Vector2i(int(STONE_RECT_R.position.x) - 1, int(STONE_RECT_R.position.y) - 1)
	for dx in range(int(STONE_RECT_R.size.x) + 2):
		ground.set_cell(st + Vector2i(dx, 0), S_G2S, Vector2i(0, 0))
	_fill_ground(ground, STONE_RECT_L, S_STONE, blocked, valid)
	var mt := Vector2i(int(STONE_RECT_L.position.x) - 1, int(STONE_RECT_L.position.y) - 1)
	for dx in range(int(STONE_RECT_L.size.x) + 2):
		ground.set_cell(mt + Vector2i(dx, 0), S_G2M, Vector2i(0, 0))

	# 三条驿道（dirt 平铺）
	for row in LANE_ROWS:
		for c in range(3, COLS - 3):
			for t in range(ROAD_THICKNESS):
				road.set_cell(Vector2i(c, row + t), S_DIRT, _pick(S_DIRT, valid))
				blocked[Vector2i(c, row + t)] = true

	# 刷新区平台（右缘 5 列）
	for row in LANE_ROWS:
		for c in range(SPAWN_COL - 2, COLS):
			for t in range(ROAD_THICKNESS + 2):
				road.set_cell(Vector2i(c, row - 2 + t), S_DIRT, _pick(S_DIRT, valid))
				blocked[Vector2i(c, row - 2 + t)] = true

	# 多格建筑：塔 3×3（地基）、双方主堡 3×8
	var buildings: Array[Dictionary] = []
	for i in range(TOWER_COLS.size()):
		var a := tower_anchor(i)
		_place_foundation(structure, a, TOWER_SIZE, blocked, valid)
		buildings.append({"id": "tower_%d" % i, "anchor": a, "size": TOWER_SIZE})
	for enemy in [false, true]:
		var a := keep_anchor(enemy)
		_place_foundation(structure, a, KEEP_SIZE, blocked, valid)
		buildings.append({"id": "keep_enemy" if enemy else "keep_own", "anchor": a, "size": KEEP_SIZE})

	# 外圈边界禁建
	for c in range(COLS):
		blocked[Vector2i(c, 0)] = true
		blocked[Vector2i(c, 1)] = true
		blocked[Vector2i(c, ROWS - 1)] = true
		blocked[Vector2i(c, ROWS - 2)] = true
	for r in range(ROWS):
		blocked[Vector2i(0, r)] = true
		blocked[Vector2i(1, r)] = true
		blocked[Vector2i(COLS - 1, r)] = true
		blocked[Vector2i(COLS - 2, r)] = true

	return {
		"ground": ground, "road": road, "structure": structure, "decor": decor,
		"cols": COLS, "rows": ROWS, "tile": TILE,
		"world_size": WORLD_SIZE, "buildings": buildings, "blocked": blocked,
	}

static func _fill_ground(layer: TileMapLayer, rect: Rect2i, source: int, blocked: Dictionary, valid: Dictionary) -> void:
	for r in range(int(rect.position.y), int(rect.position.y) + int(rect.size.y)):
		for c in range(int(rect.position.x), int(rect.position.x) + int(rect.size.x)):
			layer.set_cell(Vector2i(c, r), source, _pick(source, valid))
			blocked[Vector2i(c, r)] = true

static func _place_foundation(layer: TileMapLayer, anchor: Vector2i, size: Vector2i, blocked: Dictionary, valid: Dictionary) -> void:
	for dy in range(size.y):
		for dx in range(size.x):
			layer.set_cell(anchor + Vector2i(dx, dy), S_DIRT, _pick(S_DIRT, valid))
			blocked[anchor + Vector2i(dx, dy)] = true

## 从某源已注册的合法块坐标中随机取一个（避开色键块与越界坐标）
static func _pick(source: int, valid: Dictionary) -> Vector2i:
	var list: Array = valid.get(source, [Vector2i.ZERO])
	return list[_rng.randi_range(0, list.size() - 1)]

static func _make_layer(p_name: String, tileset: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = p_name
	layer.tile_set = tileset
	layer.z_index = z
	layer.scale = Vector2(2, 2)  # 源 20px → 显示 40px
	return layer

## 每个源 png 一个 AtlasSource；色键块（teal）不注册为瓦片。
## 返回 {"tileset": TileSet, "valid": {source_id: Array[Vector2i] 合法块坐标}}
static func _make_tileset() -> Dictionary:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(SRC, SRC)
	var valid: Dictionary = {}
	for i in range(SOURCES.size()):
		var tex := load(SOURCES[i][0]) as Texture2D
		var img := tex.get_image()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var atlas := TileSetAtlasSource.new()
		atlas.texture = tex
		atlas.texture_region_size = Vector2i(SRC, SRC)
		var cols := int(img.get_width() / float(SRC))
		var rows := int(img.get_height() / float(SRC))
		var coords: Array = []
		for r in range(rows):
			for c in range(cols):
				if _is_trans_key(img, c, r):
					continue
				if i == S_DECOR and Vector2i(c, r) in DECOR_EXCLUDE:
					continue
				atlas.create_tile(Vector2i(c, r))
				coords.append(Vector2i(c, r))
		tileset.add_source(atlas, i)
		valid[i] = coords
	return {"tileset": tileset, "valid": valid}

static func _is_trans_key(img: Image, col: int, row: int) -> bool:
	# 全块扫描：任一像素命中色键即视为色键占位块（teal 008a76）
	var ox := col * SRC
	var oy := row * SRC
	var key := Color(TRANS, 1.0)
	for y in range(SRC):
		for x in range(SRC):
			if img.get_pixel(ox + x, oy + y).is_equal_approx(key):
				return true
	return false
