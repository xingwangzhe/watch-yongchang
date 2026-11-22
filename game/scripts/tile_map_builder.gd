extends Node2D
class_name TileMapBuilder
## 守望·永昌 —— 永昌堡城池地形（一次性烘焙 4 层 TileMapLayer）
##
## 一、坐标系
##   网格 120×90 格，每格 32px → 世界 3840×2880；col=+X（东），row=+Y（南）。
##
## 二、形制依史（《永昌堡十三进士与抗倭纪略》下篇·城堡志）
##   南北长 778m / 东西宽 445m（≈1.75:1）→ 城墙取 66 行 × 38 列（66/38≈1.74）。
##   四门：东环海楼、南通川楼、西镇山楼、北通市楼；东门附瓮城（外城门在南）。
##   四水门（上河/下河各南北一座）；敌台十二（东西各四、南北各二）；
##   城外四周护城河；城内上河、下河两水南北纵贯 + 十条河浃；城内水田 200 余亩。
##
## 三、图块纪律
##   只用 assets/tiles/dcss 下文件名即语义的 32×32 具名图块，
##   同一语义内由 (col,row) 确定性轮换，不允许跨语义随机取块。
##
## 四、视觉分层（顶视读法）
##   城墙 3 格厚：d0 外墙面（CLIFF 中灰）→ d1 墙顶马道（ROAD_ROCK 亮砌石）
##   → d2 内墙阴面（CLIFF_DARK 深），外沿再叠 stone_00 作雉堞，形成垛口节奏。
##   水体四周 1 格 SAND 作驳岸；近城草地取亮苔变体，远处取暗苔 + 沙交错。
##
## 五、一次构建
##   build() 内完成全部 set_cell，运行期不再改瓦片；布局经 _compute_layout() 缓存，
##   因此 is_water_cell() / zone_at() 可在 build() 前后任意调用。

const TileCatalogScript = preload("res://scripts/tile_catalog.gd")

# ---------- 网格 ----------
## 像素尺寸只有一个来源：TileCatalog.TILE_SIZE（当前 40 = 原生 20px × 2）。
## 任何脚本都不要再硬编码 32/40，一律引用这里或 TileCatalog.TILE_SIZE，
## 否则改一次尺寸就要全库追着改（历史上 32 切 20px 图集正是"碎石感"的根因）。
const TILE: int = TileCatalogScript.TILE_SIZE
const COLS := 120
const ROWS := 90
const WORLD_SIZE := Vector2(COLS * TILE, ROWS * TILE)   # 3840×2880 @32px

## 三条驿道的「城外横向来路」行号：北路、东路（主路，走瓮城）、南路
const LANE_ROWS := [4, 46, 84]
const ROAD_THICKNESS := 2
## 倭寇登陆点所在的沙滩列
const SPAWN_COL := 96

# ---------- 瓦片语义 source_id（顺序与 TileCatalog.CAT_ORDER 一致）----------
## 语义码 —— **每个语义一个唯一编号**，不再等于图集 source_id。
##
## 旧实现把「语义码」和「图集 source_id」混为一谈，导致多个语义共用同一编号时
## 字典键冲突（GDScript 常量字典不允许重复键）。现在分开：
##   语义码 = 绘制代码写的标记（唯一）
##   SEM_OF = 语义码 → 语义组名
##   语义组名 → TileCatalog 里的块名单 → 块 → 图集 (source, coord)
const S_FIELD := 0          # 城外田野（苔地）
const S_SOIL := 1           # 土路 / 场院（暖褐泥地）
const S_STREET := 2         # 城内街巷（卵石铺面）
const S_WALL_STONE := 3     # 城墙（灰石砌体）
const S_WALL_BRICK := 4     # 民居院墙（褐砖）
const S_WATER_DEEP := 5     # 护城河 / 外海（深水）
const S_WATER_SHALLOW := 6  # 上河 / 下河 / 河浃（浅水）
const S_DOOR := 7           # 城门 / 木门
const S_TREE := 8           # 植被点缀
const S_SAND := 9           # 沙地 / 滩涂 / 驳岸
const S_CITY := 10          # 城内大面（平滑沙褐）
const S_ROAD_ROCK := 11     # 门道 / 石桥（灰色砌石）
const S_ROAD_SAND := 12     # 沙滩车道（沙褐）

## 语义码 → 语义组名（组名定义在 TileCatalog.SEMANTIC_GROUPS）
const SEM_OF: Dictionary = {
	S_FIELD: &"field",
	S_SOIL: &"soil",
	S_STREET: &"street",
	S_WALL_STONE: &"wall_stone",
	S_WALL_BRICK: &"wall_brick",
	S_WATER_DEEP: &"water_deep",
	S_WATER_SHALLOW: &"water_shallow",
	S_DOOR: &"door_wood",
	S_TREE: &"mangrove",
	S_SAND: &"sand",
	S_CITY: &"city_ground",
	S_ROAD_ROCK: &"road_rock",
	S_ROAD_SAND: &"road_sand",
}

## 兼容别名：旧代码里散落的老名字统一指向新语义码，
## 避免逐处改 _put() 调用（历史语义含义按最接近的映射）。
const S_MOSS := S_FIELD
const S_ROAD := S_STREET
const S_CLIFF := S_WALL_STONE
const S_CLIFF_DARK := S_WALL_STONE
const S_STONE_TILE := S_WALL_STONE
const S_WATER := S_WATER_DEEP
const S_GRASS := S_FIELD
const S_LONG := S_FIELD
const S_DIRT := S_SOIL
const S_STONE := S_WALL_STONE
const S_G2W := S_WATER_SHALLOW
const S_G2S := S_SOIL
const S_G2M := S_WALL_STONE
const S_DECOR := S_WALL_STONE

# ---------- 城池外廓 ----------
## 史载「城墙高8米，基宽约4米，上宽3.8米」（全文 14576-14578 行）。
## 3.9m ≈ 3 格 @11.7m/格，故墙厚取 3 格（WALL_T）。
const CITY_X0 := 14          # 城墙外沿最西列
const CITY_Y0 := 13          # 城墙外沿最北行
const CITY_X1 := 51          # 城墙外沿最东列
const CITY_Y1 := 78          # 城墙外沿最南行
const WALL_T := 3            # 墙厚 3 格：外墙面 + 墙顶马道 + 内墙阴面
const IN_X0 := 17            # 城内可用区（含）
const IN_Y0 := 16
const IN_X1 := 48
const IN_Y1 := 75

# ---------- 主堡（王氏宗祠）与倭营 ----------
const KEEP_SIZE := Vector2i(3, 7)
const KEEP_ANCHOR := Vector2i(25, 37)      # 城中心偏西
const ENEMY_KEEP_SIZE := Vector2i(3, 7)
const ENEMY_KEEP_ANCHOR := Vector2i(96, 60)  # 东南海滩倭营

# ---------- 预置塔位 ----------
const TOWER_SIZE := Vector2i(3, 3)
const TOWER_ANCHORS: Array[Vector2i] = [
	Vector2i(35, 17),   # 通市楼内箭台
	Vector2i(44, 43),   # 环海楼内箭台
	Vector2i(34, 71),   # 迎川楼内箭台
]

# ---------- 四门 ----------
## cx/cy/w/h 为门洞矩形（贯穿整段墙厚的缺口），barbican 标记是否附瓮城。
## 东西门的洞沿 X 贯穿 3 格墙厚；南北门的洞沿 Y 贯穿 3 格墙厚。
const GATES: Array = [
	{"name": "环海楼", "side": &"east", "cx": 49, "cy": 46, "w": 3, "h": 2, "barbican": true},
	{"name": "迎川楼", "side": &"south", "cx": 32, "cy": 76, "w": 2, "h": 3, "barbican": false},
	{"name": "镇山楼", "side": &"west", "cx": 14, "cy": 46, "w": 3, "h": 2, "barbican": false},
	{"name": "通市楼", "side": &"north", "cx": 32, "cy": 13, "w": 2, "h": 3, "barbican": false},
]

# ---------- 瓮城（附环海楼，外城门在南侧）----------
## 占地 6×12 格，横压东护城河：护城河自瓮城北、东、南三面绕行
## （MOAT_BYPASS + 南北连通段），成「瓮城环水」形制，
## 与环海楼「环海为池，适揽朝宗之会」得名相合（全文 14702 行）。
const BARB_WALL_N := Rect2i(52, 41, 6, 1)     # 北墙 cols 52..57 row 41
const BARB_WALL_E := Rect2i(57, 41, 1, 12)    # 东墙 col 57 rows 41..52
const BARB_WALL_S1 := Rect2i(52, 52, 2, 1)    # 南墙西段 cols 52..53
const BARB_WALL_S2 := Rect2i(56, 52, 2, 1)    # 南墙东段 cols 56..57
const BARB_GATE_S := Rect2i(54, 52, 2, 1)     # 外城门（南）cols 54..55
const BARB_YARD := Rect2i(52, 42, 5, 10)      # 庭院石铺 cols 52..56 rows 42..51
const BARB_FOOT := Rect2i(52, 41, 6, 12)      # 瓮城总占地（用于从护城河挖出）

# 护城河绕瓮城：东侧旁道 + 南北连通段
const MOAT_BYPASS := Rect2i(58, 41, 3, 12)    # 东旁道 cols 58..60 rows 41..52
const MOAT_LINK_N := Rect2i(56, 40, 5, 1)     # 北连通 cols 56..60 row 40
const MOAT_LINK_S := Rect2i(56, 53, 5, 1)     # 南连通 cols 56..60 row 53

# ---------- 水系 ----------
const MOAT_N := Rect2i(10, 9, 46, 3)      # 北护城河 cols 10..55 rows 9..11
const MOAT_S := Rect2i(10, 80, 46, 3)     # 南护城河 cols 10..55 rows 80..82
const MOAT_W := Rect2i(10, 9, 3, 74)      # 西护城河 cols 10..12 rows 9..82
const MOAT_E := Rect2i(53, 9, 3, 74)      # 东护城河 cols 53..55 rows 9..82
const RIVER_LOW := Rect2i(21, 16, 2, 60)  # 下河 cols 21..22 rows 16..75
const RIVER_UP := Rect2i(30, 16, 2, 60)   # 上河 cols 30..31 rows 16..75

# ---------- 城内街网（稀疏：两纵一横一广场）----------
## 史载「上河东岸为新城街……沿街店铺林立，是永昌堡最繁华的商业街」（全文 14656-14658）；
## 「都堂第坐落在永昌堡下河西岸御史巷一号」（全文 2452 行）。故只保留这两条南北主街。
const STREET_NS := Rect2i(32, 16, 2, 60)     # 新城街（上河东岸主街）cols 32..33 rows 16..75
const RIVERSIDE := Rect2i(20, 16, 1, 60)     # 御史巷（下河西岸）col 20 rows 16..75
const STREET_EW := Rect2i(20, 46, 29, 2)     # 东西大街（连东西门）cols 20..48 rows 46..47
const PLAZA := Rect2i(23, 44, 7, 2)          # 王氏宗祠前石板广场 cols 23..29 rows 44..45
const WEST_EXIT := Rect2i(10, 46, 7, 2)      # 镇山楼外跨护城河石桥 cols 10..16 rows 46..47

## 三条驿道在城外的折线段（[x, y, w, h]，瓦片格）
const LANE_RECTS: Array = [
	# 0 北路 → 通市楼
	[[32, 4, 65, 2], [32, 4, 2, 13]],
	# 1 东路（主路）→ 沿堡东滩涂南下，折西跨护城河，入瓮城南门，再穿环海楼
	[[61, 46, 36, 2], [61, 46, 2, 11], [54, 56, 8, 2], [54, 52, 2, 5]],
	# 2 南路 → 迎川楼
	[[32, 84, 65, 2], [32, 76, 2, 10]],
]

## 驿道折线控制点（格边界坐标；首点由 spawn_world 补上，末点在宗祠广场内）
## 三条路都沿「主街 + 东西大街」行进，不再另辟小巷，街网因此稀疏。
const LANE_CTRL: Array = [
	[[33, 5], [33, 47], [26, 47], [26, 44]],
	[[61, 47], [61, 57], [55, 57], [55, 47], [27, 47], [27, 44]],
	[[33, 85], [33, 47], [26, 47], [26, 44]],
]

# ---------- 区域（zone）编码 ----------
const Z_VOID := 0
const Z_SEA := 1
const Z_BEACH := 2
const Z_MOAT := 3
const Z_RIVER := 4
const Z_CITY := 5
const Z_FIELD := 6
const Z_MOUNTAIN := 7
const Z_SALT := 8
const Z_WILD := 9
const ZONE_NAMES: Array[StringName] = [
	&"void", &"sea", &"beach", &"moat", &"river", &"city",
	&"field", &"mountain", &"salt", &"wild",
]

## 堡内水田矩形：留出主街、东西大街与宗祠广场，其余成片为田。
static func farmland_rects() -> Array:
	return [
		Rect2i(36, 17, 13, 28),   # 东片北段 cols 36..48 rows 17..44
		Rect2i(36, 62, 13, 14),   # 东片南段 cols 36..48 rows 62..75
		Rect2i(23, 17, 7, 27),    # 中片北段 cols 23..29 rows 17..43
		Rect2i(23, 50, 7, 25),    # 中片南段 cols 23..29 rows 50..74
		Rect2i(17, 50, 3, 25),    # 西片南段 cols 17..19 rows 50..74
	]

## 民居院落（明清民居 26 座的代表性几组：石板院落 + 结构层地基）
## 全部锚点避开了街巷、河浃、河渠与塔位。
static func houses() -> Array:
	return [
		{"id": "dutangdi", "anchor": Vector2i(17, 17), "size": Vector2i(3, 3), "name": "都堂第"},
		{"id": "shengzhimen", "anchor": Vector2i(23, 17), "size": Vector2i(2, 2), "name": "圣旨门"},
		{"id": "shangcangtan", "anchor": Vector2i(36, 25), "size": Vector2i(3, 3), "name": "上仓坦"},
		{"id": "junxiefang", "anchor": Vector2i(40, 52), "size": Vector2i(3, 3), "name": "军械坊"},
		{"id": "zhuangyuanfu", "anchor": Vector2i(36, 63), "size": Vector2i(2, 2), "name": "状元府第"},
		{"id": "fucitang", "anchor": Vector2i(17, 22), "size": Vector2i(3, 4), "name": "王氏宗祠附祠"},
		{"id": "shuyuan", "anchor": Vector2i(23, 50), "size": Vector2i(4, 3), "name": "贞义书院"},
		{"id": "dianpu_a", "anchor": Vector2i(34, 32), "size": Vector2i(2, 2), "name": "新城街店铺"},
		{"id": "dianpu_b", "anchor": Vector2i(34, 56), "size": Vector2i(2, 2), "name": "新城街店铺"},
		{"id": "minju_a", "anchor": Vector2i(23, 66), "size": Vector2i(3, 2), "name": "河浃民居"},
		{"id": "minju_b", "anchor": Vector2i(17, 37), "size": Vector2i(2, 3), "name": "御史巷民居"},
	]

static var _layout: Dictionary = {}

# =====================================================================
# 一、派生坐标 API（供 main / spawn_system / minimap / build_system 调用）
# =====================================================================

## 第 lane 条驿道「城外横向来路」的中心 y
static func lane_y(lane_index: int) -> float:
	return float((int(LANE_ROWS[lane_index]) + 1) * TILE)

## 第 lane 条驿道上倭寇的登陆格（东侧沙滩）
static func spawn_cell(lane: int) -> Vector2i:
	return Vector2i(SPAWN_COL, int(LANE_ROWS[lane]))

static func spawn_world(lane: int) -> Vector2:
	var c := spawn_cell(lane)
	return Vector2(float(c.x * TILE) + TILE * 0.5, lane_y(lane))

## 第 lane 条驿道的完整折线（世界坐标，含登陆点）——供 Path2D.Curve2D 使用
static func lane_points(lane: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(spawn_world(lane))
	for p in LANE_CTRL[lane]:
		pts.append(Vector2(float(int(p[0]) * TILE), float(int(p[1]) * TILE)))
	return pts

static func lane_gate_name(lane: int) -> StringName:
	match lane:
		0: return &"通市楼"
		1: return &"环海楼"
		2: return &"迎川楼"
		_: return &""

## 四门中按名取门洞中心的世界坐标
static func gate_world(gate_name: String) -> Vector2:
	for g in GATES:
		if String(g["name"]) == gate_name:
			return _gate_center(g)
	return Vector2.ZERO

static func gate_hole_rect(g: Dictionary) -> Rect2i:
	return Rect2i(int(g["cx"]), int(g["cy"]), int(g["w"]), int(g["h"]))

## 小地图悬停文案：四座城门按《永昌堡十三进士与抗倭纪略》L14595-14614 命名；
## 水门不冒充城门，按 L14605“西南和东北城墙各 2 个”标注。
static func gate_label_at(cell: Vector2i) -> String:
	for g in GATES:
		if gate_hole_rect(g).has_point(cell):
			var side := ""
			match StringName(g["side"]):
				&"east": side = "东"
				&"south": side = "南"
				&"west": side = "西"
				&"north": side = "北"
			return "%s（%s门）" % [String(g["name"]), side]
	if _in_rects(cell.x, cell.y, water_gate_holes()):
		return "水门"
	return ""

## 小地图悬停文案：结构层优先显示具体建筑，而不是一律写「城墙」。
## 依据《永昌堡十三进士与抗倭纪略》的城门、敌台、铺舍与民居记载。
static func landmark_label_at(cell: Vector2i) -> String:
	var gate := gate_label_at(cell)
	if gate != "":
		return gate
	for spec in building_specs():
		var a: Vector2i = spec["anchor"]
		var s: Vector2i = spec["size"]
		if Rect2i(a, s).has_point(cell):
			return String(spec["name"])
	if _in_rects(cell.x, cell.y, enemy_tower_rects()):
		return "敌台"
	if _in_rects(cell.x, cell.y, post_houses()):
		return "铺舍"
	return ""

## 小地图悬停文案：道路层区分新城街、御史巷、东西大街、石桥与驿道。
## 史载「上河东岸为新城街……沿街店铺林立」「都堂第……下河西岸御史巷一号」。
static func road_label_at(cell: Vector2i) -> String:
	if STREET_NS.has_point(cell):
		return "新城街"
	if RIVERSIDE.has_point(cell):
		return "御史巷"
	if STREET_EW.has_point(cell) or PLAZA.has_point(cell):
		return "东西大街"
	if WEST_EXIT.has_point(cell):
		return "镇山楼石桥"
	if BARB_YARD.has_point(cell) or BARB_GATE_S.has_point(cell):
		return "环海楼瓮城"
	for lane in range(LANE_RECTS.size()):
		if _in_rects(cell.x, cell.y, lane_rects(lane)):
			return "驿道"
	return "道路"

static func _gate_center(g: Dictionary) -> Vector2:
	var r := gate_hole_rect(g)
	return Vector2(float(r.position.x + r.size.x) * TILE * 0.5,
		float(r.position.y + r.size.y) * TILE * 0.5)

static func tower_anchor(i: int) -> Vector2i:
	return TOWER_ANCHORS[i]

static func tower_center(i: int) -> Vector2:
	var a := tower_anchor(i)
	return Vector2(float(a.x + TOWER_SIZE.x) * TILE, float(a.y + TOWER_SIZE.y) * TILE) * 0.5

static func keep_anchor(enemy: bool) -> Vector2i:
	return ENEMY_KEEP_ANCHOR if enemy else KEEP_ANCHOR

static func keep_center(enemy: bool) -> Vector2:
	var a := keep_anchor(enemy)
	var s := ENEMY_KEEP_SIZE if enemy else KEEP_SIZE
	return Vector2(float(a.x + s.x) * TILE, float(a.y + s.y) * TILE) * 0.5

static func keep_size(enemy: bool) -> Vector2i:
	return ENEMY_KEEP_SIZE if enemy else KEEP_SIZE

## 是否可见水面（护城河 / 上河 / 下河 / 河浃 / 海）
static func is_water_cell(cell: Vector2i) -> bool:
	var lay := _ensure_layout()
	var w: PackedByteArray = lay["water"]
	if cell.x < 0 or cell.x >= COLS or cell.y < 0 or cell.y >= ROWS:
		return false
	return w[cell.y * COLS + cell.x] == 1

## 区域查询（**细分语义**）：区分城墙内外与地形性质，不做 UI 归并。
## 返回 &"city" / &"field" / &"moat" / &"river" / &"salt" / &"beach" / &"sea"
##     / &"mountain" / &"wild" / &"wall" / &"road" / &"gate" / &"void"
## UI 若只需粗色块，用 zone_group() 归并，别在这里丢信息。
static func zone_at(cell: Vector2i) -> StringName:
	if cell.x < 0 or cell.x >= COLS or cell.y < 0 or cell.y >= ROWS:
		return &"void"
	var lay := _ensure_layout()
	var zm: Variant = lay.get("zone_map", null)
	if zm is Dictionary:
		var d := zm as Dictionary
		if d.has(cell):
			return StringName(str(d[cell]))
		return &"void"
	var z: PackedByteArray = lay["zone"]
	return ZONE_NAMES[int(z[cell.y * COLS + cell.x])]

## 细分语义 → UI 粗色组（小地图 / tooltip 用；不改变 zone_at 的信息量）
static func zone_group(zone: StringName) -> StringName:
	match zone:
		&"city", &"field", &"road", &"wall", &"gate", &"moat", &"river", &"sea":
			return zone
		&"salt", &"beach", &"mountain", &"wild":
			return &"field"
		_:
			return &"void"

## 格 → 世界坐标（格中心）
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x * TILE) + TILE * 0.5, float(cell.y * TILE) + TILE * 0.5)

# =====================================================================
# 二、几何清单
# =====================================================================

## 十条河浃：上河东岸四浃 + 下河东岸五浃 + 西门浃（堡西，东西走向）。
## 史载「沿上河开凿五浃，由南向北依次排列为：四宅浃、状元浃、三房浃、西门浃、上仓浃」
## 「沿河由南向北开五浃，依次排列为朴树浃、经魁浃、御史浃、板桥浃、圣旨门浃」
## 「西门浃……西头直抵永昌堡镇山楼……该浃东西走向」（全文 14659-14671）。
static func canals() -> Array:
	return [
		{"name": "四宅浃", "rect": Rect2i(32, 70, 5, 1)},
		{"name": "状元浃", "rect": Rect2i(32, 64, 7, 1)},
		{"name": "三房浃", "rect": Rect2i(32, 52, 3, 1)},
		{"name": "上仓浃", "rect": Rect2i(32, 22, 5, 1)},
		{"name": "西门浃", "rect": Rect2i(17, 41, 4, 1)},
		{"name": "朴树浃", "rect": Rect2i(23, 68, 4, 1)},
		{"name": "经魁浃", "rect": Rect2i(23, 56, 4, 1)},
		{"name": "御史浃", "rect": Rect2i(23, 33, 2, 1)},
		{"name": "板桥浃", "rect": Rect2i(23, 25, 5, 1)},
		{"name": "圣旨门浃", "rect": Rect2i(23, 18, 4, 1)},
	]

## 城外盐田（永嘉盐场，堡东滩涂晒盐区）：矩形为晒场范围，西缘开引水沟。
## 依资料「明代初期，永嘉盐场（龙湾永强片区古称）因地处海防前沿，屡有倭匪侵袭」。
static func salt_pans() -> Array:
	return [
		Rect2i(66, 14, 10, 7), Rect2i(79, 14, 10, 7),
		Rect2i(66, 25, 10, 7), Rect2i(79, 25, 10, 7),
		Rect2i(66, 34, 10, 7), Rect2i(80, 34, 10, 7),
		Rect2i(66, 56, 10, 7), Rect2i(80, 56, 10, 7),
		Rect2i(66, 68, 10, 7), Rect2i(80, 68, 10, 7),
	]

## 庙上河：自南引水入堡，与《水系网络》「护城河外接双岙溪而来的庙上河，
## 自南引河水入堡内」对应（全文 14617-14621）。选址在南岭以东，避开南山体。
static func feeder_streams() -> Array:
	return [
		Rect2i(52, 83, 2, 7),    # 庙上河：rows 83..89 抵南护城河（row 82）
	]

static func street_rects() -> Array:
	return [STREET_NS, RIVERSIDE, STREET_EW, PLAZA, WEST_EXIT]

static func lane_rects(lane: int) -> Array:
	var out: Array = []
	for q in LANE_RECTS[lane]:
		out.append(Rect2i(int(q[0]), int(q[1]), int(q[2]), int(q[3])))
	return out

## 四门门洞（贯穿整段墙厚）
static func gate_holes() -> Array:
	var out: Array = []
	for g in GATES:
		out.append(gate_hole_rect(g))
	return out

## 四座水门：上河/下河在北南城墙上各穿一洞（东北 2、西南 2），
## 洞高取整段墙厚 3 行，与史载「水门4座，西南和东北城墙各2个」对应（全文 14605 行）。
static func water_gate_holes() -> Array:
	return [
		Rect2i(21, 13, 2, 3), Rect2i(30, 13, 2, 3),   # 北墙（东北）
		Rect2i(21, 76, 2, 3), Rect2i(30, 76, 2, 3),   # 南墙（西南）
	]

## 水门与护城河之间的连通段（城墙与护城河之间的空档行/列）
static func water_gate_links() -> Array:
	return [
		Rect2i(21, 12, 2, 1), Rect2i(30, 12, 2, 1),
		Rect2i(21, 79, 2, 1), Rect2i(30, 79, 2, 1),
	]

## 十二敌台（东西各四、南北各二），每座 2×2 直出墙体、压过护城河内岸
## 史载「敌台12座，东西两面的城墙各筑有4座，南北两面各有2座」、
## 「一般直出墙体约5米，横长8米左右，通高5.6米，平面方形」（全文 14581-14591）。
static func enemy_tower_rects() -> Array:
	var out: Array = []
	for r in [24, 37, 56, 68]:
		out.append(Rect2i(52, r, 2, 2))   # 东墙外（col 52 为墙外空档）
		out.append(Rect2i(12, r, 2, 2))   # 西墙外（col 13 为墙外空档）
	for c in [24, 44]:
		out.append(Rect2i(c, 12, 2, 2))   # 北墙外（row 12 为墙外空档）
		out.append(Rect2i(c, 79, 2, 2))   # 南墙外（row 79 为墙外空档）
	return out

## 二十铺舍（城上守铺，2×1/1×2）。沿城墙内侧四边布置：东西各 6、南北各 4。
## 史载「铺舍20个」（全文 555-556 行）。
static func post_houses() -> Array:
	var out: Array = []
	for r in [18, 27, 43, 55, 64, 73]:
		out.append(Rect2i(IN_X0, r, 1, 2))       # 西墙内侧
		out.append(Rect2i(IN_X1, r, 1, 2))       # 东墙内侧
	for c in [18, 28, 40, 47]:
		out.append(Rect2i(c, IN_Y0, 2, 1))       # 北墙内侧
		out.append(Rect2i(c, IN_Y1, 2, 1))       # 南墙内侧
	return out

## 多格建筑（id / anchor / size / name）：主堡、倭营、预置塔位 + 民居院落
static func building_specs() -> Array:
	var out: Array = [
		{"id": "keep_own", "anchor": KEEP_ANCHOR, "size": KEEP_SIZE, "name": "王氏宗祠"},
		{"id": "keep_enemy", "anchor": ENEMY_KEEP_ANCHOR, "size": ENEMY_KEEP_SIZE, "name": "倭营"},
		{"id": "tower_0", "anchor": TOWER_ANCHORS[0], "size": TOWER_SIZE, "name": "通市楼箭台"},
		{"id": "tower_1", "anchor": TOWER_ANCHORS[1], "size": TOWER_SIZE, "name": "环海楼箭台"},
		{"id": "tower_2", "anchor": TOWER_ANCHORS[2], "size": TOWER_SIZE, "name": "迎川楼箭台"},
	]
	for h in houses():
		out.append(h)
	return out

# =====================================================================
# 三、地形曲线（确定性、无随机数）
# =====================================================================

## 东侧海岸线所在列（cols >= 此值即纯海）
static func _shore_col(r: int) -> int:
	# 每 3 行取同一岸线，避免逐行 ±1 的单格锯齿；3 行一段仍保留自然弧度。
	var band := int(floor(float(r) / 3.0))
	return 101 + int(round(2.0 * sin(float(band) * 0.63)))

## 西侧山体东缘（cols < 此值即山）
static func _ridge_right(r: int) -> int:
	return 6 + int(round(2.0 * sin(float(r) * 0.17 + 1.0)))

static func _idx(c: int, r: int) -> int:
	return r * COLS + c

static func _inb(c: int, r: int) -> bool:
	return c >= 0 and c < COLS and r >= 0 and r < ROWS

static func _put(arr: Array, c: int, r: int, cat: int) -> void:
	if c < 0 or c >= COLS or r < 0 or r >= ROWS:
		return
	arr[r * COLS + c] = cat

static func _put_rect(arr: Array, rect: Rect2i, cat: int) -> void:
	for r in range(rect.position.y, rect.position.y + rect.size.y):
		for c in range(rect.position.x, rect.position.x + rect.size.x):
			_put(arr, c, r, cat)

static func _in_rects(c: int, r: int, rects: Array) -> bool:
	for rect in rects:
		var q: Rect2i = rect
		if c >= q.position.x and c < q.position.x + q.size.x \
			and r >= q.position.y and r < q.position.y + q.size.y:
			return true
	return false

# =====================================================================
# 四、布局计算（缓存）
# =====================================================================

static func _ensure_layout() -> Dictionary:
	if _layout.is_empty():
		_layout = _compute_layout()
	return _layout

static func _compute_layout() -> Dictionary:
	var n := COLS * ROWS
	var g: Array[int] = []
	g.resize(n)
	g.fill(S_MOSS)
	## 地面图块的变体覆盖：-1 = 走默认确定性轮换，>=0 = 指定变体号
	var gv: Array[int] = []
	gv.resize(n)
	gv.fill(-1)
	var rd: Array[int] = []
	rd.resize(n)
	rd.fill(-1)
	var st: Array[int] = []
	st.resize(n)
	st.fill(-1)
	var dc: Array[int] = []
	dc.resize(n)
	dc.fill(-1)
	var wet: Array[int] = []
	wet.resize(n)
	wet.fill(0)

	_paint_grass(g, gv)
	_paint_city_ground(g, gv)
	_paint_fields(g, gv)
	_paint_mountains(st)
	_paint_coast(g, gv, wet)
	_paint_water(g, wet)
	_paint_banks(g, wet)
	_paint_walls(st)
	_paint_barbican(st, rd)
	_paint_enemy_towers(st)
	_paint_roads(rd, g, wet)
	_paint_buildings(st)
	_paint_decor(dc, rd, st, wet)

	# —— 汇总 water / blocked / zone ——
	var wmask := PackedByteArray()
	wmask.resize(n)
	var zone := PackedByteArray()
	zone.resize(n)
	var blocked: Dictionary = {}
	for r in range(ROWS):
		for c in range(COLS):
			var i := _idx(c, r)
			wmask[i] = wet[i]
			var in_city := _in_city(c, r)
			# 水面被结构盖住的（如敌台压护城河）不算可见水面
			if wet[i] == 1 and st[i] >= 0:
				wmask[i] = 0
			# 禁建：水、路、结构、边界
			if wmask[i] == 1 or rd[i] >= 0 or st[i] >= 0:
				blocked[Vector2i(c, r)] = true
			if c < 2 or c > COLS - 3 or r < 2 or r > ROWS - 3:
				blocked[Vector2i(c, r)] = true
			# 分区：field = 堡内水田（200 余亩，战时自给），wild = 城外荒野
			var z := Z_WILD
			if wmask[i] == 1:
				if c >= _shore_col(r):
					z = Z_SEA
				elif in_city:
					z = Z_RIVER
				elif _in_salt_pan(c, r):
					z = Z_SALT
				else:
					z = Z_MOAT
			elif in_city:
				z = Z_FIELD if _is_farmland(c, r) else Z_CITY
			elif st[i] == S_CLIFF or st[i] == S_CLIFF_DARK:
				z = Z_MOUNTAIN
			elif _in_salt_pan(c, r):
				z = Z_SALT
			else:
				var shore := _shore_col(r)
				if c >= shore - 7 and c < shore:
					z = Z_BEACH
			zone[i] = z

	var buildings: Array[Dictionary] = []
	for spec in building_specs():
		buildings.append({
			"id": String(spec["id"]),
			"anchor": spec["anchor"],
			"size": spec["size"],
			"name": String(spec["name"]),
		})

	return {
		"ground": g, "ground_var": gv, "road": rd, "structure": st, "decor": dc,
		"water": wmask, "zone": zone,
		"blocked": blocked, "buildings": buildings,
	}

static func _in_city(c: int, r: int) -> bool:
	if c >= CITY_X0 and c <= CITY_X1 and r >= CITY_Y0 and r <= CITY_Y1:
		return true
	# 瓮城亦属城池
	if c >= BARB_FOOT.position.x and c < BARB_FOOT.position.x + BARB_FOOT.size.x \
		and r >= BARB_FOOT.position.y and r < BARB_FOOT.position.y + BARB_FOOT.size.y:
		return true
	return false

## 距城池外廓的切比雪夫距离（城内为 0）
static func _city_dist(c: int, r: int) -> int:
	var dx := 0
	if c < CITY_X0:
		dx = CITY_X0 - c
	elif c > CITY_X1:
		dx = c - CITY_X1
	var dy := 0
	if r < CITY_Y0:
		dy = CITY_Y0 - r
	elif r > CITY_Y1:
		dy = r - CITY_Y1
	return maxi(dx, dy)

# ---------- 各分区绘制 ----------

## 城外地面：**整片一个语义**（田野），具体图块由 pick_variant 按格确定性选取。
##
## 这里刻意不做「距城远近换材质 + 稀疏穿插沙地」：
## 逐格随机换语义会在画面上产生噪点，正是要避免的"胡乱拼凑"。
## 要让远处看起来不同，应该换**区域**（如整片滩涂用 soil），
## 而不是在同一个区域里一格一格掷骰子。
static func _paint_grass(g: Array, gv: Array) -> void:
	for r in range(ROWS):
		for c in range(COLS):
			if _in_city(c, r):
				continue
			var i := _idx(c, r)
			g[i] = S_FIELD
			gv[i] = -1

## 堡内水田：田面一个语义，田埂用 soil 走**规则线**。
## 田埂模数按田块尺寸自适应：宽/高小于 6 格时不在该方向画埂，
## 否则小田块（如 3 格宽的西片）会几乎整块变成田埂。
static func _paint_fields(g: Array, gv: Array) -> void:
	for rect in farmland_rects():
		var q: Rect2i = rect
		var ridge_x: bool = q.size.x >= 6
		var ridge_y: bool = q.size.y >= 6
		for r in range(q.position.y, q.position.y + q.size.y):
			for c in range(q.position.x, q.position.x + q.size.x):
				if not _inb(c, r):
					continue
				var i := _idx(c, r)
				var dy := r - q.position.y
				var dx := c - q.position.x
				if (ridge_y and dy % 10 == 9) or (ridge_x and dx % 8 == 7):
					g[i] = S_SOIL          # 田埂
				else:
					g[i] = S_FIELD         # 田面
				gv[i] = -1

## 城内地面：**夯土院落**（soil），街道由 _paint_roads 覆盖成石板（street）。
##
## 为什么城内不铺田野绿：这是城墙围起来的居住区，主色应是夯土/铺地，
## 绿色只留在城外农田与城内零星园圃。整片铺草会让城看起来像荒地。
static func _paint_city_ground(g: Array, gv: Array) -> void:
	for r in range(CITY_Y0, CITY_Y1 + 1):
		for c in range(CITY_X0, CITY_X1 + 1):
			if not _inb(c, r):
				continue
			var i := _idx(c, r)
			g[i] = S_CITY
			gv[i] = -1
	# 瓮城内院同样夯土
	for r in range(BARB_FOOT.position.y, BARB_FOOT.position.y + BARB_FOOT.size.y):
		for c in range(BARB_FOOT.position.x, BARB_FOOT.position.x + BARB_FOOT.size.x):
			if not _inb(c, r):
				continue
			g[_idx(c, r)] = S_CITY
			gv[_idx(c, r)] = -1

static func _is_farmland(c: int, r: int) -> bool:
	for rect in farmland_rects():
		var q: Rect2i = rect
		if c >= q.position.x and c < q.position.x + q.size.x \
			and r >= q.position.y and r < q.position.y + q.size.y:
			return true
	return false

static func _in_salt_pan(c: int, r: int) -> bool:
	for rect in salt_pans():
		var q: Rect2i = rect
		if c >= q.position.x and c < q.position.x + q.size.x \
			and r >= q.position.y and r < q.position.y + q.size.y:
			return true
	return false

## 东侧海与沙滩：7 格沙带 → 固定 2 格沙 + 1 格浅水 → 纯海。
## 三条驿道登陆点各开一道 3 格高、向东延伸的沙滩豁口，读作上岸滩头。
static func _paint_coast(g: Array, gv: Array, wet: Array) -> void:
	var lane_r: Array = LANE_ROWS
	for r in range(ROWS):
		var shore := _shore_col(r)
		# 登陆滩头：在驿道行 ±1 上把沙带向东延长 3 格
		var spit := 0
		for lr in lane_r:
			if absi(r - int(lr)) <= 1:
				spit = 3
				break
		for c in range(maxi(0, shore - 7), shore):
			if not _inb(c, r):
				continue
			var i := _idx(c, r)
			g[i] = S_SAND
			gv[i] = -1
		# 滩涂渐变：按离岸距离固定分层，不逐格掷骰子。
		# shore-1 浅水，shore-2 / shore-3 沙地；同一行材质连续，避免单格杂点。
		for k in range(1, 4):
			var c2 := shore - k
			if not _inb(c2, r):
				continue
			var i2 := _idx(c2, r)
			if k == 1:
				g[i2] = S_WATER_SHALLOW
				wet[i2] = 1
			else:
				g[i2] = S_SAND
				gv[i2] = -1
				wet[i2] = 0
		# 纯海
		for c in range(shore, COLS):
			var i3 := _idx(c, r)
			g[i3] = S_WATER_DEEP
			wet[i3] = 1
		# 登陆豁口：滩头向东多铺 spit 格沙
		for k in range(0, spit):
			var c4 := shore + k
			if _inb(c4, r):
				var i4 := _idx(c4, r)
				g[i4] = S_SAND
				gv[i4] = -1
				wet[i4] = 0

## 山体：西侧主山（镇山楼所倚）、北岭、南岭
## 史载选址「坐山面海，天马山峙其南，黄石山屏其北」（全文 14555-14557）。
static func _paint_mountains(st: Array) -> void:
	for r in range(ROWS):
		var right := _ridge_right(r)
		for c in range(0, right):
			_put(st, c, r, S_CLIFF if (c * 3 + r * 5) % 4 != 0 else S_CLIFF_DARK)
	for r in range(0, 3):
		for c in range(0, 63):
			_put(st, c, r, S_CLIFF if (c * 5 + r * 3) % 5 != 0 else S_CLIFF_DARK)
	for r in range(86, ROWS):
		for c in range(0, 51):
			_put(st, c, r, S_CLIFF if (c * 7 + r * 3) % 5 != 0 else S_CLIFF_DARK)

## 护城河 + 上河/下河 + 十条河浃 + 四座水门
static func _paint_water(g: Array, wet: Array) -> void:
	for rect in [MOAT_N, MOAT_S, MOAT_W, MOAT_E]:
		_water_rect(g, wet, rect, S_WATER_DEEP)
	for rect in [RIVER_LOW, RIVER_UP]:
		_water_rect(g, wet, rect, S_WATER_SHALLOW)
	for canal in canals():
		_water_rect(g, wet, canal["rect"], S_WATER_SHALLOW)
	# 护城河绕瓮城：先挖出瓮城台基，再补东旁道与南北连通段
	for r in range(BARB_FOOT.position.y, BARB_FOOT.position.y + BARB_FOOT.size.y):
		for c in range(BARB_FOOT.position.x, BARB_FOOT.position.x + BARB_FOOT.size.x):
			if _inb(c, r):
				g[_idx(c, r)] = S_MOSS
				wet[_idx(c, r)] = 0
	for rect in [MOAT_BYPASS, MOAT_LINK_N, MOAT_LINK_S]:
		_water_rect(g, wet, rect, S_WATER_DEEP)
	# 城外盐田：沙埂晒盐 —— 田面铺沙（晒场），西侧一条引水沟（water）接海。
	for pan in salt_pans():
		var r: Rect2i = pan
		for rr in range(r.position.y, r.position.y + r.size.y):
			for cc in range(r.position.x, r.position.x + r.size.x):
				if not _inb(cc, rr):
					continue
				var dy := rr - r.position.y
				var dx := cc - r.position.x
				var ridge := (r.size.y >= 6 and dy % 4 == 3) \
					or (r.size.x >= 6 and dx % 5 == 4)
				g[_idx(cc, rr)] = S_SOIL if ridge else S_CITY
		for rr in range(r.position.y, r.position.y + r.size.y):
			if _inb(r.position.x, rr):
				g[_idx(r.position.x, rr)] = S_WATER_SHALLOW
				wet[_idx(r.position.x, rr)] = 1
	# 庙上河（南引水）
	for rect in feeder_streams():
		_water_rect(g, wet, rect, S_WATER_SHALLOW)
	# 水门洞 + 与护城河的连通段
	for rect in water_gate_holes():
		_water_rect(g, wet, rect, S_WATER_SHALLOW)
	for rect in water_gate_links():
		_water_rect(g, wet, rect, S_WATER_SHALLOW)

static func _water_rect(g: Array, wet: Array, rect: Rect2i, sem: int = S_WATER_DEEP) -> void:
	for r in range(rect.position.y, rect.position.y + rect.size.y):
		for c in range(rect.position.x, rect.position.x + rect.size.x):
			if _inb(c, r):
				g[_idx(c, r)] = sem
				wet[_idx(c, r)] = 1

## 驳岸：所有与内陆水面 4 邻接的陆地格铺 1 格沙，读作滩地/石砌驳岸。
## 史载「河两岸以方块花岗石斜筑，以利水陆交通、灌溉、浣洗」（全文 558-559）。
## 海水岸线由 _paint_coast 的渐变带处理，这里只补内陆水体（护城河/河/浃）。
static func _paint_banks(g: Array, wet: Array) -> void:
	var shore_cache: Array[int] = []
	shore_cache.resize(ROWS)
	for r in range(ROWS):
		shore_cache[r] = _shore_col(r)
	var stamp: Array[int] = []
	stamp.resize(COLS * ROWS)
	stamp.fill(0)
	for r in range(ROWS):
		var shore: int = shore_cache[r]
		for c in range(COLS):
			var i := _idx(c, r)
			if wet[i] != 1:
				continue
			if c >= shore:
				continue          # 海面不铺驳岸（由滩涂渐变负责）
			# 四邻陆地
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nv: Vector2i = d
				var nc := c + nv.x
				var nr := r + nv.y
				if not _inb(nc, nr):
					continue
				var ni := _idx(nc, nr)
				if wet[ni] == 1:
					continue
				stamp[ni] = 1
	for i in range(COLS * ROWS):
		if stamp[i] == 1 and g[i] != S_WATER_DEEP and g[i] != S_WATER_SHALLOW:
			g[i] = S_SAND

## 城墙：3 格厚连续实心，不夹草。DCSS 的 gray brick 是专门的砌体纹理，
## 城墙三格统一用 wall_stone，不再混用卵石街面或暗石。
## 史载「城墙高8米，基宽约4米」（全文 14576 行）→ 3.9m ≈ 3 格 @11.7m/格。
static func _paint_walls(st: Array) -> void:
	var holes := gate_holes()
	var wh := water_gate_holes()
	for r in range(CITY_Y0, CITY_Y1 + 1):
		for c in range(CITY_X0, CITY_X1 + 1):
			var d: int = mini(mini(c - CITY_X0, CITY_X1 - c), mini(r - CITY_Y0, CITY_Y1 - r))
			if d >= WALL_T:
				continue
			if _in_rects(c, r, holes) or _in_rects(c, r, wh):
				continue
			_put(st, c, r, S_WALL_STONE)

## 瓮城：北墙 + 东墙 + 南墙（外城门开在南墙中段 cols 54..55）+ 庭院石铺
## 墙体与主城墙同构：外沿 CLIFF、内沿 CLIFF_DARK。
static func _paint_barbican(st: Array, rd: Array) -> void:
	for rect in [BARB_WALL_N, BARB_WALL_E, BARB_WALL_S1, BARB_WALL_S2]:
		_put_rect(st, rect, S_CLIFF)
	_put_rect(rd, BARB_YARD, S_ROAD_ROCK)
	_put_rect(rd, BARB_GATE_S, S_ROAD_ROCK)

## 十二敌台 + 二十铺舍
static func _paint_enemy_towers(st: Array) -> void:
	for rect in enemy_tower_rects():
		_put_rect(st, rect, S_CLIFF_DARK)
	for rect in post_houses():
		_put_rect(st, rect, S_ROAD_ROCK)

## 街巷 + 三条驿道；跨水处自动改铺石板（桥）
static func _paint_roads(rd: Array, g: Array, wet: Array) -> void:
	for rect in street_rects():
		_paint_road_rect(rd, g, wet, rect)
	for lane in range(LANE_RECTS.size()):
		for rect in lane_rects(lane):
			_paint_road_rect(rd, g, wet, rect)
	# 四个门洞铺石板，读作门道
	for rect in gate_holes():
		_put_rect(rd, rect, S_ROAD_ROCK)
	_put_rect(rd, PLAZA, S_ROAD_ROCK)
	_put_rect(rd, BARB_YARD, S_ROAD_ROCK)
	_put_rect(rd, BARB_GATE_S, S_ROAD_ROCK)

static func _paint_road_rect(rd: Array, g: Array, wet: Array, rect: Rect2i) -> void:
	for r in range(rect.position.y, rect.position.y + rect.size.y):
		for c in range(rect.position.x, rect.position.x + rect.size.x):
			if not _inb(c, r):
				continue
			var i := _idx(c, r)
			var cat := S_ROAD
			if wet[i] == 1:
				cat = S_ROAD_ROCK        # 跨水 → 石桥
			elif g[i] == S_SAND:
				cat = S_ROAD_SAND        # 沙滩 → 沙路
			rd[i] = cat

## 建筑地基：主堡/倭营/塔位用砌石与暗石砌成「实体建筑体块」，
## 其余民居（都堂第、上仓坦等）铺石板院落。地基同时压入 blocked。
static func _paint_buildings(st: Array) -> void:
	for spec in building_specs():
		var a: Vector2i = spec["anchor"]
		var s: Vector2i = spec["size"]
		var rect := Rect2i(a.x, a.y, s.x, s.y)
		var id := String(spec["id"])
		if id == "keep_own":
			_put_rect(st, rect, S_WALL_BRICK)
		elif id == "keep_enemy":
			_put_rect(st, rect, S_WALL_STONE)
		elif id.begins_with("tower_"):
			_put_rect(st, rect, S_WALL_STONE)
		else:
			_put_rect(st, rect, S_WALL_BRICK)

## 装饰：雉堞（外沿每 2 格一堞，形成垛口节奏）+ 主堡台基压边 + 山野乱石
## 史载「城墙外侧筑女儿墙，高2.4米，其上雉堞高0.62米」（全文 14577-14579）。
## 装饰层：只放**有明确位置理由**的东西，不做全图随机撒点。
##
## 历史教训：这里曾用 `_hash(c,r,41) % 41 == 0` 每隔 3 格撒一块 stone 当"山野乱石"，
## 还在城墙外沿隔格叠了一层 stone。32px 下这些块是带高光的碎石图案，混在草地里
## 就是满屏灰色噪点 —— 这正是用户说的"胡乱拼凑"。已全部删除：
## 城墙的砌石质感由 _paint_walls 在 structure 层连续完成，不需要再叠。
static func _paint_decor(dc: Array, rd: Array, st: Array, wet: Array) -> void:
	# 主堡/倭营台基压边：外扩一圈，让建筑体块从草地/石面上读得出来（位置确定、非随机）
	for enemy in [false, true]:
		var a := keep_anchor(enemy)
		var s := keep_size(enemy)
		for c in range(a.x - 1, a.x + s.x + 1):
			_put(dc, c, a.y - 1, S_STONE_TILE)
			_put(dc, c, a.y + s.y, S_STONE_TILE)
		for r in range(a.y - 1, a.y + s.y + 1):
			_put(dc, a.x - 1, r, S_STONE_TILE)
			_put(dc, a.x + s.x, r, S_STONE_TILE)

# =====================================================================
# 五、构建
# =====================================================================

static func build(parent: Node2D) -> Dictionary:
	var lay := _ensure_layout()
	var tileset := TileCatalogScript.shared_tileset()
	var ground := _make_layer("GroundLayer", tileset, -40)
	var road := _make_layer("RoadLayer", tileset, -30)
	var structure := _make_layer("StructureLayer", tileset, -20)
	var decor := _make_layer("DecorLayer", tileset, -10)
	parent.add_child(ground)
	parent.add_child(road)
	parent.add_child(structure)
	parent.add_child(decor)

	_paint_layer(ground, lay["ground"], lay["ground_var"])
	_paint_layer(road, lay["road"], null)
	_paint_layer(structure, lay["structure"], null)
	_paint_layer(decor, lay["decor"], null)

	var zmap := _build_zone_map(lay, road, structure)
	lay["zone_map"] = zmap

	return {
		"ground": ground, "road": road, "structure": structure, "decor": decor,
		"cols": COLS, "rows": ROWS, "tile": TILE, "world_size": WORLD_SIZE,
		"buildings": lay["buildings"], "blocked": lay["blocked"],
		# 追加（可选消费）：区域图与水体掩码，供 UI / 建造提示使用
		"water": lay["water"], "zone": lay["zone"], "zone_map": zmap,
	}

## 区域语义图（供 MinimapPanel 上色）：Vector2i → 细分语义名。
## 在 ZONE_NAMES 基础上叠加「结构层 = 城墙 / 道路层 = 驿道 / 门洞 = 城门」三层覆盖。
static func _build_zone_map(lay: Dictionary, road: TileMapLayer, structure: TileMapLayer) -> Dictionary:
	var zmap: Dictionary = {}
	var codes: Array = lay["zone"]
	var holes := gate_holes()
	var wholes := water_gate_holes()
	var fort_rects: Array = []
	fort_rects.append_array(enemy_tower_rects())
	fort_rects.append_array(post_houses())
	for spec in building_specs():
		var a: Vector2i = spec["anchor"]
		var s: Vector2i = spec["size"]
		fort_rects.append(Rect2i(a, s))
	for r in range(ROWS):
		var base := r * COLS
		for c in range(COLS):
			var z: StringName = ZONE_NAMES[int(codes[base + c])]
			var cell := Vector2i(c, r)
			if structure.get_cell_source_id(cell) != -1:
				# 山体也是 structure 层，不能一律改成「城墙」。
				# 城墙环、瓮城、敌台、铺舍与建筑才是城防结构。
				if _is_wall_ring(c, r, holes, wholes) or _in_rects(c, r, fort_rects):
					z = &"wall"
			if road.get_cell_source_id(cell) != -1:
				z = &"road"
			if _in_rects(c, r, holes) or _in_rects(c, r, wholes):
				z = &"gate"
			zmap[cell] = z
	return zmap

static func _is_wall_ring(c: int, r: int, holes: Array, water_holes: Array) -> bool:
	if c < CITY_X0 or c > CITY_X1 or r < CITY_Y0 or r > CITY_Y1:
		# 瓮城墙体在主城环之外
		for rect in [BARB_WALL_N, BARB_WALL_E, BARB_WALL_S1, BARB_WALL_S2]:
			if (rect as Rect2i).has_point(Vector2i(c, r)):
				return true
		return false
	var d: int = mini(mini(c - CITY_X0, CITY_X1 - c), mini(r - CITY_Y0, CITY_Y1 - r))
	if d >= WALL_T:
		return false
	return not _in_rects(c, r, holes) and not _in_rects(c, r, water_holes)

## 逐格写瓦片：语义 = 数组里的类别码；变体 = 显式覆盖（overrides >= 0）或确定性轮换。
## salt 由语义在 CAT_ORDER 的下标派生 —— 只为了错开不同材质的轮换相位，
## 避免草地/沙地/水面在同一 (c,r) 上取到同号变体而产生对齐条纹。
## 逐格落瓦：语义码 → 语义组 → 具体图块 → 图集 (source, coord)。
##
## 关键点（也是与旧「随便取一块」的根本区别）：
## 1. 语义码先经 SEM_OF 映射到**语义组名**（如 wall_stone），
##    组内只含 tileable 的块（TileCatalog 已按图像量过四边透明度）。
## 2. 具体取哪一块由 TileCatalog.pick_variant 用 (c,r) 确定性散列决定，
##    同一格永远同一块，重跑构建结果一致。
## 3. 再用 atlas_coord 查到该块在图集中的真实坐标——**不能**用
##    「组内下标」直接当图集坐标，因为语义组是图集的子集，下标会错位。
static func _paint_layer(layer: TileMapLayer, cats: Array, overrides: Variant) -> void:
	var has_ov: bool = overrides is Array
	for r in range(ROWS):
		var base := r * COLS
		for c in range(COLS):
			var sem_code: int = cats[base + c]
			if sem_code < 0:
				continue
			var sem: StringName = SEM_OF.get(sem_code, &"")
			if sem == &"":
				continue
			# 显式覆盖：调用方直接给了「组内第几块」，用于门洞/垛口等需要固定的位置
			var path := ""
			if has_ov:
				var ov := int((overrides as Array)[base + c])
				if ov >= 0:
					var arr := TileCatalogScript.palette_of(sem)
					if not arr.is_empty():
						path = String((arr[posmod(ov, arr.size())] as Dictionary)["file"])
			if path.is_empty():
				path = TileCatalogScript.pick_variant(sem, c, r)
			if path.is_empty():
				continue
			var loc := TileCatalogScript.atlas_coord(path)
			if loc.is_empty():
				continue
			layer.set_cell(Vector2i(c, r), int(loc["source"]), loc["coord"] as Vector2i)

static func _make_layer(p_name: String, tileset: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = p_name
	layer.tile_set = tileset
	layer.z_index = z
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return layer
