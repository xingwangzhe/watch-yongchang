extends RefCounted
class_name TileCatalog
## 具名图块目录（Hard Vacuum 32×32 RGBA，一图一义，文件名即语义）。
##
## 目录结构（res://assets/tiles/hardvacuum/）：
##   ground/  moss_00..moss_12  苔地/草地（13 变体）
##            sand_00..sand_12  沙地（13 变体）
##   road/    road_00..road_13        土路（14 变体）
##            road_rock_00..13        石板路（14 变体）
##            road_sand_00..13        沙路（14 变体）
##   rock/    cliff_00..cliff_12      亮石崖/墙石（13 变体）
##            cliff_dark_00..12       暗石崖/墙阴面（13 变体）
##            stone_00                单块石（1）
##   water/   water_00..water_13      水面（14 变体）
##
## 设计约束：
## 1) **绝不跨语义取块**。变体只允许在同一语义内做「确定性轮换」——变体号由
##    (col, row) 的算术式 + 每类固定盐值得出，同一格永远得到同一张图，
##    同一片区域永远拼出同一图案（可复现、可截图验收）。
## 2) 归并为 9 个 TileSetAtlasSource（每个语义一条横条贴图），source_id 即语义，
##    既省 draw call，又让 minimap 之类的脚本能用 source_id 直接判语义。
## 3) TileSet 只构建一次（shared_tileset() 缓存），运行期不再创建。

const ROOT := "res://assets/tiles/hardvacuum/"
const TILE_SIZE := 32

## 语义常量（其它脚本比较用，与 CATEGORIES 的键同名）
const MOSS := &"moss"
const SAND := &"sand"
const ROAD := &"road"
const ROAD_ROCK := &"road_rock"
const ROAD_SAND := &"road_sand"
const CLIFF := &"cliff"
const CLIFF_DARK := &"cliff_dark"
const STONE := &"stone"
const WATER := &"water"

## 类别顺序 = TileSet 内的 source_id 顺序，改动必须同步 TileMapBuilder 的 S_* 常量
const CAT_ORDER: Array[StringName] = [
	&"moss", &"sand", &"road", &"road_rock", &"road_sand",
	&"cliff", &"cliff_dark", &"stone", &"water",
]

## dir：所在子目录；variants：变体数；salt：轮换盐值（避免不同语义图案对齐）
const CATEGORIES: Dictionary = {
	&"moss": {"dir": "ground", "variants": 13, "salt": 0},
	&"sand": {"dir": "ground", "variants": 13, "salt": 5},
	&"road": {"dir": "road", "variants": 14, "salt": 2},
	&"road_rock": {"dir": "road", "variants": 14, "salt": 7},
	&"road_sand": {"dir": "road", "variants": 14, "salt": 11},
	&"cliff": {"dir": "rock", "variants": 13, "salt": 3},
	&"cliff_dark": {"dir": "rock", "variants": 13, "salt": 9},
	&"stone": {"dir": "rock", "variants": 1, "salt": 0},
	&"water": {"dir": "water", "variants": 14, "salt": 4},
}

static var _tileset: TileSet = null
static var _name_source: Dictionary = {}   # String -> int（source_id）
static var _name_coord: Dictionary = {}    # String -> Vector2i（图集内坐标）

# ---------- 名称 / 变体 ----------

## 语义 → source_id（等价于 CAT_ORDER 下标）
static func category_index(category: StringName) -> int:
	return CAT_ORDER.find(category)

static func variant_count(category: StringName) -> int:
	if not CATEGORIES.has(category):
		return 0
	return int(CATEGORIES[category]["variants"])

## 确定性变体号：同一 (语义, col, row) 永远同号；相邻格错开，不出现条带
static func variant_index(category: StringName, c: int, r: int) -> int:
	var n: int = variant_count(category)
	if n <= 1:
		return 0
	var salt: int = int(CATEGORIES[category]["salt"])
	return posmod(c * 7 + r * 3 + salt, n)

## 语义 + 网格坐标 → 具名图块名（如 &"moss" + (12,7) → "moss_09"）
static func pick_variant(category: StringName, c: int, r: int) -> String:
	return "%s_%02d" % [String(category), variant_index(category, c, r)]

static func tile_name(category: StringName, variant: int) -> String:
	return "%s_%02d" % [String(category), variant]

## 图块名 → res:// 路径
static func tile_path(tile_name_str: String) -> String:
	var cut: int = tile_name_str.rfind("_")
	var category := StringName(tile_name_str.substr(0, cut))
	var dir := "ground"
	if CATEGORIES.has(category):
		dir = String(CATEGORIES[category]["dir"])
	return "%s%s/%s.png" % [ROOT, dir, tile_name_str]

## 图块名 → 语义
static func category_of(tile_name_str: String) -> StringName:
	var cut: int = tile_name_str.rfind("_")
	return StringName(tile_name_str.substr(0, cut))

# ---------- TileSet 构建 ----------

## 单例 TileSet（首次调用时构建，之后复用）
static func shared_tileset() -> TileSet:
	if _tileset == null:
		_tileset = build_tileset()
	return _tileset

## 每个语义一条 32px 横条贴图 → 一个 TileSetAtlasSource。
## 图集不存在的格子也 create_tile（透明），避免 set_cell 静默失败露底。
static func build_tileset() -> TileSet:
	_name_source.clear()
	_name_coord.clear()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.uv_clipping = true
	var sid := 0
	for category in CAT_ORDER:
		var n: int = int(CATEGORIES[category]["variants"])
		var strip := Image.create(n * TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		strip.fill(Color(0, 0, 0, 0))
		for i in range(n):
			var tname := tile_name(category, i)
			var img := _load_tile_image(tname)
			if img == null:
				push_warning("TileCatalog: 缺少图块 %s（路径 %s）" % [tname, tile_path(tname)])
				continue
			strip.blit_rect(img, Rect2i(0, 0, TILE_SIZE, TILE_SIZE),
				Vector2i(i * TILE_SIZE, 0))
		var atlas := TileSetAtlasSource.new()
		atlas.texture = ImageTexture.create_from_image(strip)
		atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		for i in range(n):
			atlas.create_tile(Vector2i(i, 0))
			var tname := tile_name(category, i)
			_name_source[tname] = sid
			_name_coord[tname] = Vector2i(i, 0)
		ts.add_source(atlas, sid)
		sid += 1
	_tileset = ts
	return ts

## 图块名 → source_id（未构建时按需构建；未知名返回 -1）
static func source_of(tile_name_str: String) -> int:
	if _tileset == null:
		build_tileset()
	if _name_source.has(tile_name_str):
		return int(_name_source[tile_name_str])
	return -1

## 图块名 → 图集坐标
static func coord_of(tile_name_str: String) -> Vector2i:
	if _tileset == null:
		build_tileset()
	if _name_coord.has(tile_name_str):
		return _name_coord[tile_name_str]
	return Vector2i.ZERO

## 供验收/调试：全部具名图块 → (source_id, 图集坐标)
static func name_map() -> Dictionary:
	if _tileset == null:
		build_tileset()
	var out: Dictionary = {}
	for k in _name_source.keys():
		out[k] = {"source": int(_name_source[k]), "coord": _name_coord[k]}
	return out

static func _load_tile_image(tile_name_str: String) -> Image:
	var path := tile_path(tile_name_str)
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
