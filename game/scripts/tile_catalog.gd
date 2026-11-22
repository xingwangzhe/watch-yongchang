extends RefCounted
class_name TileCatalog
## 具名图块目录 —— 由 `native/manifest.csv` 驱动（Hard Vacuum，40×40 RGBA）。
##
## 数据源：res://assets/tiles/hardvacuum/native/manifest.csv
##   列：file, semantic, source, col, row, grid_index, partial
##   571 个 PNG = 571 条记录，一格一文件，文件名形如
##   `<语义>_<源表>_<grid>_c<列>_r<行>.png`，例如
##   `stone_stone_055_c0_r5.png`、`cliff_dark_mntcliff_000_c0_r0.png`。
##
## 两套取块方式，用途严格分开：
##   1) `pick_variant(sem, c, r)` —— **地面/纹理轮换**。同语义内按 (c,r) 确定性
##      散列取模，同一格永远同一张图。只允许用于 moss / sand / road /
##      road_rock / road_sand / water 这类"铺满即正确"的材质。
##   2) `block_at(sem, source, col, row)` —— **结构块按坐标精确取**。用于城墙、
##      城门道、敌台、垛口等需要"指定某一格就是某一图案"的场合。
##
## 绝不跨语义取块：`pick_variant(&"moss", ...)` 只会返回 moss_*。

const MANIFEST_PATH := "res://assets/tiles/hardvacuum/native/manifest.csv"
const TILE_DIR := "res://assets/tiles/hardvacuum/native/"
const TILE_SIZE := 40

## 语义常量（= manifest.csv 的 semantic 列取值）
const MOSS := &"moss"
const SAND := &"sand"
const ROAD := &"road"
const ROAD_ROCK := &"road_rock"
const ROAD_SAND := &"road_sand"
const CLIFF := &"cliff"
const CLIFF_DARK := &"cliff_dark"
const STONE := &"stone"
const WATER := &"water"
const MOUNTAIN := &"mountain"
const TREE := &"tree"

## 地面/纹理类语义（可整片轮换）
const GROUND_SEMANTICS: Array[StringName] = [
	&"moss", &"sand", &"road", &"road_rock", &"road_sand", &"water",
]
## 结构/点缀类语义（必须按坐标精确取，不可整片轮换当纹理铺）
const STRUCTURE_SEMANTICS: Array[StringName] = [
	&"cliff", &"cliff_dark", &"stone", &"mountain", &"tree",
]
## TileSet 内 source_id 的顺序（= 本数组下标），改动需同步 TileMapBuilder 的 S_* 常量
const CAT_ORDER: Array[StringName] = [
	&"moss", &"sand", &"road", &"road_rock", &"road_sand",
	&"cliff", &"cliff_dark", &"stone", &"water", &"mountain", &"tree",
]

## 合成图集时的 RGB 增益（1.0 = 原色）。water_* 原始亮度仅 32-38，
## 铺成河面会读成"沥青沟"，1.35 增益后成为可辨的水蓝；确定性调色，不改语义。
const CAT_GAIN: Dictionary = {
	&"water": 1.35,
}

static var _blocks: Dictionary = {}     # StringName -> Array[Dictionary]
static var _by_key: Dictionary = {}     # "sem|src|col|row" -> Dictionary
static var _locate: Dictionary = {}     # 文件名 -> {source, coord, semantic}（O(1)）
static var _loaded: bool = false
static var _tileset: TileSet = null

# =====================================================================
# manifest 解析
# =====================================================================

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_blocks.clear()
	_by_key.clear()
	_locate.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("TileCatalog: 缺少 manifest %s" % MANIFEST_PATH)
		return
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		push_error("TileCatalog: 无法打开 manifest %s" % MANIFEST_PATH)
		return
	var header := f.get_csv_line()
	var col_idx: Dictionary = {}
	for i in range(header.size()):
		col_idx[header[i].strip_edges()] = i
	for key in ["file", "semantic", "source", "col", "row", "grid_index", "partial"]:
		if not col_idx.has(key):
			push_error("TileCatalog: manifest 缺列 %s" % key)
			f.close()
			return
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < header.size():
			continue
		var rec := {
			"file": line[int(col_idx["file"])],
			"semantic": StringName(line[int(col_idx["semantic"])]),
			"source": line[int(col_idx["source"])],
			"col": int(line[int(col_idx["col"])]),
			"row": int(line[int(col_idx["row"])]),
			"grid_index": int(line[int(col_idx["grid_index"])]),
			"partial": int(line[int(col_idx["partial"])]),
		}
		if String(rec["file"]).is_empty():
			continue
		var sem: StringName = rec["semantic"]
		if not _blocks.has(sem):
			_blocks[sem] = []
		(_blocks[sem] as Array).append(rec)
		_by_key[_key(sem, String(rec["source"]), int(rec["col"]), int(rec["row"]))] = rec
	f.close()
	# grid_index 升序，保证轮换顺序确定
	for sem in _blocks.keys():
		var arr: Array = _blocks[sem]
		arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["grid_index"]) < int(b["grid_index"]))
	# 文件名 → (source, coord, semantic) 的 O(1) 索引（_paint_layer 逐格查，不能线性扫）
	for sem in CAT_ORDER:
		var arr2: Array = _blocks.get(sem, [])
		var sid: int = CAT_ORDER.find(sem)
		for i in range(arr2.size()):
			_locate[String((arr2[i] as Dictionary)["file"])] = {
				"source": sid, "coord": Vector2i(i, 0), "semantic": sem,
			}

static func _key(sem: StringName, source: String, col: int, row: int) -> String:
	return "%s|%s|%d|%d" % [String(sem), source, col, row]

## 语义 → 该语义下所有 block（按 grid_index 排序）
static func tiles_of(semantic: StringName) -> Array:
	_ensure_loaded()
	return _blocks.get(semantic, [])

## 全部语义名 → 数量（供验收/调试）
static func semantic_counts() -> Dictionary:
	_ensure_loaded()
	var out: Dictionary = {}
	for sem in _blocks.keys():
		out[sem] = (_blocks[sem] as Array).size()
	return out

## 语义 → source_id（= CAT_ORDER 下标）
static func category_index(semantic: StringName) -> int:
	return CAT_ORDER.find(semantic)

static func variant_count(semantic: StringName) -> int:
	_ensure_loaded()
	return (_blocks.get(semantic, []) as Array).size()

# =====================================================================
# 两套取块 API
# =====================================================================

## 地面纹理确定性轮换：同一 (语义, col, row) 永远得到同一张图。
## 仅用于 GROUND_SEMANTICS；对结构语义调用会落回该语义的第一个 block（并在 DEBUG 下告警）。
static func pick_variant(semantic: StringName, c: int, r: int) -> String:
	_ensure_loaded()
	var arr: Array = _blocks.get(semantic, [])
	if arr.is_empty():
		return ""
	if not GROUND_SEMANTICS.has(semantic):
		if OS.is_debug_build():
			push_warning("TileCatalog: pick_variant 用于结构语义 %s，请改用 block_at" % semantic)
		return String((arr[0] as Dictionary)["file"])
	# 用 (c,r) 的位混合散列取模，避免线性式产生斜向条纹
	var h: int = (c * 0x1f1f1f1f) ^ (r * 0x85ebca6b)
	h = h ^ (h >> 15)
	h = (h * 0x2545f491) & 0x7fffffff
	h = h ^ (h >> 13)
	return String((arr[h % arr.size()] as Dictionary)["file"])

## 结构块精确取：按 (语义, 源表, 列, 行) 定位唯一一张图。
## 找不到时返回空串（调用方须判定）。
static func block_at(semantic: StringName, source: String, col: int, row: int) -> String:
	_ensure_loaded()
	var rec: Variant = _by_key.get(_key(semantic, source, col, row))
	if rec == null:
		return ""
	return String((rec as Dictionary)["file"])

## 结构块精确取（只给语义 + 列行，取该语义下匹配的第一个）。
static func block_any(semantic: StringName, col: int, row: int) -> String:
	_ensure_loaded()
	for rec in _blocks.get(semantic, []):
		if int(rec["col"]) == col and int(rec["row"]) == row:
			return String(rec["file"])
	return ""

## 图块文件名 → 完整 res:// 路径
static func tile_path(file_name: String) -> String:
	return TILE_DIR + file_name

## 图块文件名 → 语义
static func semantic_of(file_name: String) -> StringName:
	_ensure_loaded()
	for sem in _blocks.keys():
		for rec in _blocks[sem]:
			if String(rec["file"]) == file_name:
				return sem
	var stem := file_name.get_basename()
	if stem.begins_with("cliff_dark"):
		return &"cliff_dark"
	if stem.begins_with("road_rock"):
		return &"road_rock"
	if stem.begins_with("road_sand"):
		return &"road_sand"
	return StringName(stem.split("_")[0])

## 文件名 → (source_id, 图集坐标, 语义)
static func locate(file_name: String) -> Dictionary:
	_ensure_loaded()
	for sem in CAT_ORDER:
		var arr: Array = _blocks.get(sem, [])
		for i in range(arr.size()):
			if String((arr[i] as Dictionary)["file"]) == file_name:
				return {"source": category_index(sem), "coord": Vector2i(i, 0), "semantic": sem}
	return {}

## 语义 + grid 序号 → 图集内坐标
static func atlas_coord_of_index(semantic: StringName, grid_idx: int) -> Vector2i:
	var n: int = variant_count(semantic)
	if n <= 0:
		return Vector2i.ZERO
	return Vector2i(posmod(grid_idx, n), 0)

# =====================================================================
# 结构块别名 —— 城墙/垛口/马道的语义化选取
# =====================================================================
## 选取依据（实测：不透明覆盖率与平均亮度）
##   stone 行 0 / 2 / 4 = 灰石大块，95% 不透明，可成片铺
##   stone 行 1 / 3     = 空行（覆盖率仅 5%），**不可取**
##   road_rock / StneRoad = 灰色条石铺面与箭孔，可作墙顶马道
##   团队原指定的 stone (0,5)/(2,5)/(4,5)：除 (0,5)(2,5) 外 partial=1，
##   (4,5) 平均亮度仅 25（近黑），(6,5)/(8,5) 为空块 → 该组合成片铺会露底，已弃用。
const WALL_BOULDER_COLS: Array = [0, 2, 4, 6, 8, 10]   # stone 行 0：灰石大块
const WALL_BOULDER_ROW := 0
const WALL_MERLON_COLS: Array = [0, 2, 4, 6, 8]        # stone 行 4：更亮，垛口
const WALL_MERLON_ROW := 4
const WALL_INNER_COLS: Array = [0, 2, 4, 6, 8]         # stone 行 2：内墙
const WALL_INNER_ROW := 2

## 墙顶马道候选（road_rock / StneRoad 的条石与转角）
const PAVE_TOP_CELLS: Array = [[0, 0], [2, 0], [4, 0], [0, 4], [2, 4], [4, 4]]
## 箭孔（垛口点缀）
const ARROW_SLIT_CELL: Array = [6, 0]

static func wall_boulder(idx: int) -> String:
	var cols := WALL_BOULDER_COLS
	return block_at(&"stone", "Stone.bmp", int(cols[posmod(idx, cols.size())]), WALL_BOULDER_ROW)

static func wall_merlon(idx: int) -> String:
	var cols := WALL_MERLON_COLS
	return block_at(&"stone", "Stone.bmp", int(cols[posmod(idx, cols.size())]), WALL_MERLON_ROW)

static func wall_inner(idx: int) -> String:
	var cols := WALL_INNER_COLS
	return block_at(&"stone", "Stone.bmp", int(cols[posmod(idx, cols.size())]), WALL_INNER_ROW)

static func wall_pave(idx: int) -> String:
	var cells := PAVE_TOP_CELLS
	var cc: Array = cells[posmod(idx, cells.size())]
	return block_at(&"road_rock", "StneRoad.bmp", int(cc[0]), int(cc[1]))

static func wall_arrow_slit() -> String:
	return block_at(&"road_rock", "StneRoad.bmp", int(ARROW_SLIT_CELL[0]), int(ARROW_SLIT_CELL[1]))

# =====================================================================
# TileSet 构建：571 张图块 → 每语义一条横条图集
# =====================================================================

static func shared_tileset() -> TileSet:
	if _tileset == null:
		_tileset = build_tileset()
	return _tileset

static func build_tileset() -> TileSet:
	_ensure_loaded()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.uv_clipping = true
	var sid := 0
	for sem in CAT_ORDER:
		var arr: Array = _blocks.get(sem, [])
		var n: int = arr.size()
		var gain: float = float(CAT_GAIN.get(sem, 1.0))
		var strip := Image.create(maxi(1, n) * TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		strip.fill(Color(0, 0, 0, 0))
		for i in range(n):
			var img := _load_tile_image(String((arr[i] as Dictionary)["file"]))
			if img == null:
				continue
			if not is_equal_approx(gain, 1.0):
				_apply_gain(img, gain)
			strip.blit_rect(img, Rect2i(0, 0, TILE_SIZE, TILE_SIZE),
				Vector2i(i * TILE_SIZE, 0))
		var atlas := TileSetAtlasSource.new()
		atlas.texture = ImageTexture.create_from_image(strip)
		atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		for i in range(n):
			atlas.create_tile(Vector2i(i, 0))
		ts.add_source(atlas, sid)
		sid += 1
	_tileset = ts
	return ts

static func _load_tile_image(file_name: String) -> Image:
	var path := tile_path(file_name)
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != TILE_SIZE or img.get_height() != TILE_SIZE:
		img.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
	return img

## RGB 增益（alpha 不变）
static func _apply_gain(img: Image, gain: float) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(
				clampf(c.r * gain, 0.0, 1.0),
				clampf(c.g * gain, 0.0, 1.0),
				clampf(c.b * gain, 0.0, 1.0),
				c.a))
