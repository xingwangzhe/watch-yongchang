extends RefCounted
class_name TileCatalog
## DCSS 图块目录（Dungeon Crawl Stone Soup，CC0，32×32 3/4 俯视）。
##
## 数据源：res://assets/tiles/dcss/manifest.csv
##   列：file, category, name, opaque, edge_opaque, tileable
##   共 106 块，按 category 分 5 组：wall 12 / floor 54 / water 26 / door 5 / tree 9
##
## 为什么能从"乱拼"变成"确定性拼接"
## --------------------------------
## 1. **单文件单块**：`wall/brick_gray_0.png` 就是一整块 32×32 图，没有稀疏槽位、
##    没有 1px 分隔线、不需要猜节距。旧图集那些坑（20px 内容 / 40px 稀疏 /
##    顶部偏移 1px）在 DCSS 上根本不存在。
## 2. **tileable 由图像本身量出来**：manifest 里 opaque≈1 且 edge_opaque≈1 的块
##    才允许在大片区域整片轮换；其余（浪花、树、门）是 overlay，只能按位置放。
## 3. **方位写在文件名里**：DCSS 自带 `dirt_north` / `dirt_northeast` /
##    `shallow_water_wave_corner_northeast` 这类命名，方位是数据不是猜测，
##    由 `tiles_with_azimuth()` 解析。
##
## 两套取块 API：
##   pick_variant(semantic, c, r)  —— 地面/墙面整片轮换，确定性散列
##   named(path)                   —— 按路径精确取（方位块、门、树）

const MANIFEST_PATH := "res://assets/tiles/dcss/manifest.csv"
const TILE_DIR := "res://assets/tiles/dcss/"
const TILE_SIZE := 32

# ---------- 语义常量（= manifest.csv 的 category 列）----------
const WALL := &"wall"
const FLOOR := &"floor"
const WATER := &"water"
const DOOR := &"door"
const TREE := &"tree"

## TileSet source_id 顺序：改动必须同步 TileMapBuilder 的 S_* 常量
const CAT_ORDER: Array[StringName] = [&"floor", &"wall", &"water", &"door", &"tree"]

# =====================================================================
# 永昌堡功能语义 → 具体图块
# =====================================================================
## 这是**设计语义表**，不是文件夹清单。程序只按这里的名字取块，
## 换素材时只改这张表，不用动 tile_map_builder。
## 组内候选会经 manifest 的 tileable 过滤（见 _build_palettes）。
const SEMANTIC_GROUPS: Dictionary = {
	# —— 城外地面 ——
	# 大面积地面只选**无边框、可无缝平铺**的块。
	# limestone/cobble/dirt 的多数变体自带深色边线，逐格轮换会形成棋盘噪点；
	# 同一语义固定一块，才能保持整片连续。需要变化时换区域，不换单格。
	&"field": ["floor/sand_1"],       # 田野/菜畦：亮沙褐，无边框
	&"soil": ["floor/dirt_1_old"],    # 田埂/晒场隔埂：叠在半透明覆盖层上，弱化对比
	&"sand": ["floor/sand_2"],        # 滩涂/驳岸：比田野略亮，仍无边框
	&"city_ground": ["floor/sand_3"],  # 城内大面：平滑沙褐，避免 dirt 的碎噪点
	&"street": ["floor/sand_4"],      # 城内街巷：同族沙面，靠道路层压暗读路
	&"road_rock": ["wall/brick_gray_1"], # 门道/石桥：灰色砌石，接缝比 0.94
	&"road_sand": ["floor/sand_4"],   # 沙滩车道：与街道同族，避免橙色土带
	# —— 墙体 ——
	&"wall_stone": ["wall/brick_gray_0"],  # 城墙：灰石砌体
	&"wall_brick": ["wall/brick_brown_0"], # 院内民居：褐砖
	# —— 水系 ——
	# 深水原图亮度仅 33，大面积会低于验收下限；用浅水扰流图作深水替身，
	# 实测亮度 53、接缝比 0.75，仍保留水波层次。
	&"water_deep": ["water/shallow_water_disturbance"],
	&"water_shallow": ["water/shallow_water"],
	# —— 点缀（overlay，不参与整片轮换）——
	&"door_gate": [
		"door/gate_closed_left", "door/gate_closed_middle", "door/gate_closed_right",
	],
	&"door_wood": ["door/closed_door", "door/open_door"],
	&"mangrove": [
		"tree/mangrove_1", "tree/mangrove_2", "tree/mangrove_3",
	],
}

## 方位词 → 位掩码（与 tile_map_builder 的 DIR_* 一致）
const AZIMUTH_BITS: Dictionary = {
	"north": 1, "east": 2, "south": 4, "west": 8,
	"northeast": 1 | 2, "southeast": 4 | 2,
	"southwest": 4 | 8, "northwest": 1 | 8,
}

static var _by_file: Dictionary = {}      # "cat/name" -> rec
static var _by_cat: Dictionary = {}       # cat -> Array[rec]（= 图集排布顺序）
static var _palettes: Dictionary = {}     # semantic -> Array[rec]
static var _loaded: bool = false
static var _tileset: TileSet = null

# =====================================================================
# manifest 解析
# =====================================================================

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_by_file.clear()
	_by_cat.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("TileCatalog: 缺少 manifest %s" % MANIFEST_PATH)
		return
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		push_error("TileCatalog: 无法打开 manifest %s" % MANIFEST_PATH)
		return
	var header := f.get_csv_line()
	# 首列可能带 UTF-8 BOM，必须显式剥掉，否则 "file" 匹配不上（曾因此整张图集全透明）
	if header.size() > 0:
		header[0] = String(header[0]).lstrip("\ufeff")
	var idx: Dictionary = {}
	for i in range(header.size()):
		idx[header[i].strip_edges()] = i
	for key in ["file", "category", "name", "opaque", "edge_opaque", "tileable"]:
		if not idx.has(key):
			push_error("TileCatalog: manifest 缺列 %s（表头 %s）" % [key, str(header)])
			f.close()
			return
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < header.size():
			continue
		var rec := {
			"file": String(line[int(idx["file"])]),
			"category": StringName(line[int(idx["category"])]),
			"name": String(line[int(idx["name"])]),
			"opaque": float(line[int(idx["opaque"])]),
			"edge_opaque": float(line[int(idx["edge_opaque"])]),
			"tileable": int(line[int(idx["tileable"])]),
		}
		if rec["file"].is_empty():
			continue
		# 统一用「无扩展名」做键：语义组里写 "wall/brick_gray_0" 比带 .png 好读，
		# 而 manifest 的 file 列带 .png（上游生成时就这么写）。此处剥掉扩展名。
		rec["file"] = String(rec["file"]).get_basename()
		_by_file[rec["file"]] = rec
		var cat: StringName = rec["category"]
		if not _by_cat.has(cat):
			_by_cat[cat] = []
		(_by_cat[cat] as Array).append(rec)
	f.close()
	_build_palettes()

## 把 SEMANTIC_GROUPS 展开成「可用块名单」，只保留 tileable==1；
## 整组都不可平铺（树/门等 overlay）时保留全部，由调用方按名精确摆放。
static func _build_palettes() -> void:
	_palettes.clear()
	for sem in SEMANTIC_GROUPS.keys():
		var ok_arr: Array = []
		var all_arr: Array = []
		for path in SEMANTIC_GROUPS[sem]:
			var rec: Variant = _by_file.get(String(path))
			if rec == null:
				push_warning("TileCatalog: 语义 %s 引用了不存在的块 %s" % [sem, path])
				continue
			all_arr.append(rec)
			if int((rec as Dictionary)["tileable"]) == 1:
				ok_arr.append(rec)
		_palettes[sem] = ok_arr if not ok_arr.is_empty() else all_arr

# =====================================================================
# 取块 API
# =====================================================================

static func palette_of(semantic: StringName) -> Array:
	_ensure_loaded()
	return _palettes.get(semantic, [])

static func variant_count(semantic: StringName) -> int:
	return palette_of(semantic).size()

## 地面/墙面整片轮换：同一 (语义, c, r) 永远同一张。
## 用位混合散列而非线性式，避免斜向条纹。
static func pick_variant(semantic: StringName, c: int, r: int) -> String:
	var arr := palette_of(semantic)
	if arr.is_empty():
		return ""
	var h: int = (c * 0x1f1f1f1f) ^ (r * 0x85ebca6b)
	h = h ^ (h >> 15)
	h = (h * 0x2545f491) & 0x7fffffff
	h = h ^ (h >> 13)
	return String((arr[h % arr.size()] as Dictionary)["file"])

## 按相对路径精确取（"wall/brick_gray_0"）；不存在返回空串
static func named(path: String) -> String:
	_ensure_loaded()
	return path if _by_file.has(path) else ""

## 文件名里带方位的块（DCSS 原生支持）：{位掩码: "cat/name"}
## 例：dirt_northeast_new → {3: "floor/dirt_northeast_new"}
static func tiles_with_azimuth(category: StringName) -> Dictionary:
	_ensure_loaded()
	var out: Dictionary = {}
	for rec in _by_cat.get(category, []):
		var nm := String((rec as Dictionary)["name"])
		for word in AZIMUTH_BITS.keys():
			if nm.ends_with("_" + String(word)):
				out[int(AZIMUTH_BITS[word])] = String((rec as Dictionary)["file"])
				break
	return out

static func category_index(category: StringName) -> int:
	return CAT_ORDER.find(category)

## 相对路径（无扩展名）→ res:// 完整路径。
## manifest 的 file 列在加载时已剥掉 .png 做键，这里必须补回来 ——
## 漏了这一步会让 ResourceLoader.exists() 全部为 false，_load_image 返回 null，
## 图集整条变成全透明，画面一片空白（排查了很久的一个坑）。
static func tile_path(file: String) -> String:
	return TILE_DIR + file + ".png"

static func semantic_counts() -> Dictionary:
	_ensure_loaded()
	var out: Dictionary = {}
	for sem in _palettes.keys():
		out[sem] = (_palettes[sem] as Array).size()
	return out

# =====================================================================
# TileSet 构建：每个 category 拼成一条横条图集
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
	for cat in CAT_ORDER:
		var arr: Array = _by_cat.get(cat, [])
		var n: int = arr.size()
		var strip := Image.create(maxi(1, n) * TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		strip.fill(Color(0, 0, 0, 0))
		for i in range(n):
			var img := _load_image(String((arr[i] as Dictionary)["file"]))
			if img == null:
				continue
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

## 图块相对路径 → (source_id, 图集坐标)，与 build_tileset 的排布严格一致
static func atlas_coord(file: String) -> Dictionary:
	_ensure_loaded()
	var rec: Variant = _by_file.get(file)
	if rec == null:
		return {}
	var cat: StringName = (rec as Dictionary)["category"]
	var arr: Array = _by_cat.get(cat, [])
	for i in range(arr.size()):
		if String((arr[i] as Dictionary)["file"]) == file:
			return {"source": category_index(cat), "coord": Vector2i(i, 0)}
	return {}

static func _load_image(file: String) -> Image:
	var path := tile_path(file)
	if not ResourceLoader.exists(path):
		push_warning("TileCatalog: 图块不存在 %s" % path)
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
