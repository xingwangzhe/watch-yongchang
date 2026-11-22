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
##   只用 assets/tiles/hardvacuum 下文件名即语义的 32×32 具名图块，
##   同一语义内由 (col,row) 确定性轮换（TileCatalog.pick_variant），
##   不允许跨语义随机取块 —— 草地不取石、石不取水。
##
## 四、一次构建
##   build() 内完成全部 set_cell，运行期不再改瓦片；布局经 _compute_layout() 缓存，
##   因此 is_water_cell() / zone_at() 可在 build() 前后任意调用。

const TileCatalogScript = preload("res://scripts/tile_catalog.gd")

# ---------- 网格 ----------
const TILE := 32
const COLS := 120
const ROWS := 90
const WORLD_SIZE := Vector2(COLS * TILE, ROWS * TILE)   # 3840×2880

## 固定种子（布局本身无随机数；保留给装饰散布的确定性散列盐）
const GEN_SEED := 20260322

## 三条驿道的「城外横向来路」行号：北路、东路（主路，走瓮城）、南路
const LANE_ROWS := [4, 46, 84]
const ROAD_THICKNESS := 2
## 倭寇登陆点所在的沙滩列
const SPAWN_COL := 96

# ---------- 瓦片语义 source_id（顺序与 TileCatalog.CAT_ORDER 一致）----------
const S_MOSS := 0
const S_SAND := 1
const S_ROAD := 2
const S_ROAD_ROCK := 3
const S_ROAD_SAND := 4
const S_CLIFF := 5
const S_CLIFF_DARK := 6
const S_STONE_TILE := 7
const S_WATER := 8

# —— 为兼容既有 minimap.gd 的源 id 别名（新代码请直接用上面的 S_* 或 zone_at）——
const S_GRASS := S_MOSS
const S_LONG := S_SAND
const S_DIRT := S_ROAD
const S_STONE := S_CLIFF
const S_G2W := S_ROAD_SAND
const S_G2S := S_CLIFF_DARK
const S_G2M := S_ROAD_ROCK
const S_DECOR := S_STONE_TILE

# ---------- 城池外廓 ----------
const CITY_X0 := 14          # 城墙外沿最西列
const CITY_Y0 := 13          # 城墙外沿最北行
const CITY_X1 := 51          # 城墙外沿最东列
const CITY_Y1 := 78          # 城墙外沿最南行
const WALL_T := 2            # 墙厚 2 格（基宽 4m / 上宽 3.8m 的示意）
const IN_X0 := 16            # 城内可用区（含）
const IN_Y0 := 15
const IN_X1 := 49
const IN_Y1 := 76

# ---------- 主堡（王氏宗祠）与倭营 ----------
const KEEP_SIZE := Vector2i(3, 7)
const KEEP_ANCHOR := Vector2i(25, 37)      # 城中心偏西
const ENEMY_KEEP_SIZE := Vector2i(3, 7)
const ENEMY_KEEP_ANCHOR := Vector2i(96, 60)  # 东南海滩倭营

# ---------- 预置塔位 ----------
const TOWER_SIZE := Vector2i(3, 3)
const TOWER_ANCHORS: Array[Vector2i] = [
	Vector2i(35, 16),   # 通市楼内箭台
	Vector2i(45, 43),   # 环海楼内箭台
	Vector2i(34, 72),   # 迎川楼内箭台
]

# ---------- 四门 ----------
## cx/cy/w/h 为门洞矩形（城墙缺口），barbican 标记是否附瓮城
const GATES: Array = [
	{"name": "环海楼", "side": &"east", "cx": 50, "cy": 46, "w": 2, "h": 2, "barbican": true},
	{"name": "迎川楼", "side": &"south", "cx": 32, "cy": 77, "w": 2, "h": 2, "barbican": false},
	{"name": "镇山楼", "side": &"west", "cx": 14, "cy": 46, "w": 2, "h": 2, "barbican": false},
	{"name": "通市楼", "side": &"north", "cx": 32, "cy": 13, "w": 2, "h": 2, "barbican": false},
]

# ---------- 瓮城（附环海楼，外城门在南侧）----------
## 占地 6×12 格，横压东护城河：护城河自瓮城北、东、南三面绕行
## （MOAT_BYPASS + 南北连通段），成「瓮城环水」形制，
## 与环海楼「环海为池，适揽朝宗之会」得名相合。
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
const RIVER_LOW := Rect2i(21, 15, 2, 62)  # 下河 cols 21..22 rows 15..76
const RIVER_UP := Rect2i(30, 15, 2, 62)   # 上河 cols 30..31 rows 15..76

## 城内街巷（都是「可走不可建」）
const STREET_NS := Rect2i(32, 15, 2, 62)     # 新城街（上河东岸主街）cols 32..33 rows 15..76
const STREET_EW := Rect2i(16, 46, 34, 2)     # 东西大街 cols 16..49 rows 46..47
const STREET_N := Rect2i(23, 30, 27, 2)      # 上仓街 cols 23..49 rows 30..31
const STREET_S := Rect2i(23, 60, 27, 2)      # 仓前街 cols 23..49 rows 60..61
const RIVERSIDE := Rect2i(20, 15, 1, 62)     # 御史巷（下河西岸）col 20 rows 15..76
const PLAZA := Rect2i(23, 44, 7, 2)          # 王氏宗祠前石板广场 cols 23..29 rows 44..45
const CORRIDOR := Rect2i(23, 38, 2, 23)      # 都堂巷（下河东岸小街）cols 23..24 rows 38..60
const SPUR_KEEP := Rect2i(25, 32, 2, 5)      # 上仓街南折入宗祠 cols 25..26 rows 32..36
const WEST_EXIT := Rect2i(10, 46, 6, 2)      # 镇山楼外跨护城河石桥 cols 10..15 rows 46..47

## 三条驿道在城外的折线段（[x, y, w, h]，瓦片格）
const LANE_RECTS: Array = [
	# 0 北路 → 通市楼（自北滩横来，折南穿北水门西侧的城门）
	[[32, 4, 65, 2], [32, 4, 2, 13]],
	# 1 东路（主路）→ 沿堡东滩涂南下，折西跨护城河，入瓮城南门，再穿环海楼
	[[61, 46, 36, 2], [61, 46, 2, 11], [54, 56, 8, 2], [54, 52, 2, 5]],
	# 2 南路 → 迎川楼
	[[32, 84, 65, 2], [32, 76, 2, 10]],
]

## 驿道折线控制点（格边界坐标；首点由 spawn_world 补上，末点为主堡门阶外沿）
const LANE_CTRL: Array = [
	[[33, 5], [33, 31], [26, 31], [26, 36]],
	[[61, 47], [61, 57], [55, 57], [55, 47], [27, 47], [27, 44]],
	[[33, 85], [33, 61], [24, 61], [24, 44], [26, 44]],
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

## 堡内水田矩形（东片为主，中片、西片各两块）。
## 折算依据：古城东西 445m / 38 列 ≈ 11.7m/格 → 一格 ≈ 137m²；
## 「堡内原有水田 200 多亩」≈ 13.3 万 m² ≈ 970 格，故水田名义占地取 ~1000 格
## （约 940 格净田面，被民居/河浃/街巷压掉的部分不计）。
static func farmland_rects() -> Array:
	return [
		Rect2i(34, 17, 16, 29),   # 东片北段 cols 34..49 rows 17..45
		Rect2i(34, 62, 16, 15),   # 东片南段 cols 34..49 rows 62..76
		Rect2i(25, 15, 5, 14),    # 中片北段 cols 25..29 rows 15..28
		Rect2i(25, 33, 5, 27),    # 中片南段 cols 25..29 rows 33..59
		Rect2i(16, 24, 4, 8),     # 西片北段 cols 16..19 rows 24..31
		Rect2i(16, 62, 4, 15),    # 西片南段 cols 16..19 rows 62..76
	]

## 民居院落（明清民居 26 座的代表性几组：石板院落 + 结构层地基）
## 全部锚点均已避开街巷、河浃、水田埂与塔位（probe 校验 structure/road 零重叠）
static func houses() -> Array:
	return [
		{"id": "dutangdi", "anchor": Vector2i(16, 20), "size": Vector2i(3, 3), "name": "都堂第"},
		{"id": "shengzhimen", "anchor": Vector2i(25, 15), "size": Vector2i(2, 2), "name": "圣旨门"},
		{"id": "shangcangtan", "anchor": Vector2i(44, 26), "size": Vector2i(3, 3), "name": "上仓坦"},
		{"id": "junxiefang", "anchor": Vector2i(38, 41), "size": Vector2i(3, 3), "name": "军械坊"},
		{"id": "zhuangyuanfu", "anchor": Vector2i(34, 66), "size": Vector2i(2, 2), "name": "状元府第"},
		{"id": "fucitang", "anchor": Vector2i(16, 34), "size": Vector2i(3, 4), "name": "王氏宗祠附祠"},
		{"id": "shuyuan", "anchor": Vector2i(25, 49), "size": Vector2i(4, 3), "name": "贞义书院"},
		{"id": "dianpu_a", "anchor": Vector2i(34, 32), "size": Vector2i(2, 2), "name": "新城街店铺"},
		{"id": "dianpu_b", "anchor": Vector2i(34, 50), "size": Vector2i(2, 2), "name": "新城街店铺"},
		{"id": "minju_a", "anchor": Vector2i(25, 53), "size": Vector2i(3, 2), "name": "河浃民居"},
		{"id": "minju_b", "anchor": Vector2i(16, 52), "size": Vector2i(2, 3), "name": "御史巷民居"},
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

## 十条河浃：上河东岸五浃 + 下河东岸五浃（除西门浃外，均由西向东伸）
## 注：史载「西门浃…东西走向…西头直抵永昌堡镇山楼」，故西门浃布在堡西、
##     西端接镇山楼内侧，东端接御史巷与下河；上河东岸实存四浃。
static func canals() -> Array:
	return [
		{"name": "四宅浃", "rect": Rect2i(32, 70, 5, 1)},
		{"name": "状元浃", "rect": Rect2i(32, 64, 7, 1)},
		{"name": "三房浃", "rect": Rect2i(32, 52, 3, 1)},
		{"name": "上仓浃", "rect": Rect2i(32, 22, 5, 1)},
		{"name": "西门浃", "rect": Rect2i(16, 41, 6, 1)},
		{"name": "朴树浃", "rect": Rect2i(23, 68, 4, 1)},
		{"name": "经魁浃", "rect": Rect2i(23, 56, 4, 1)},
		{"name": "御史浃", "rect": Rect2i(23, 33, 2, 1)},
		{"name": "板桥浃", "rect": Rect2i(23, 25, 5, 1)},
		{"name": "圣旨门浃", "rect": Rect2i(23, 18, 4, 1)},
	]

## 城外盐田（永嘉盐场，堡东滩涂晒盐区）：每块「沙埂围水」的矩形
## 依资料「明代初期永嘉盐场因地处海防前沿屡有倭匪侵袭」，盐场在堡东沿海。
static func salt_pans() -> Array:
	return [
		# 北片（通市楼与环海楼之间）
		Rect2i(64, 12, 11, 8), Rect2i(77, 12, 11, 8),
		Rect2i(64, 24, 11, 8), Rect2i(77, 24, 11, 8),
		# 中片（主驿道两侧）
		Rect2i(64, 34, 11, 8), Rect2i(78, 34, 11, 8),
		# 南片
		Rect2i(64, 56, 11, 8), Rect2i(78, 56, 11, 8),
		Rect2i(64, 68, 11, 8), Rect2i(78, 68, 11, 8),
	]

## 庙上河：自南引水入堡（接南护城河），与《水系网络》一节「护城河外接双岙溪
## 而来的庙上河，自南引河水入堡内」对应。选址在南岭以东，避开南山体。
static func feeder_streams() -> Array:
	return [
		Rect2i(52, 83, 2, 7),    # 庙上河：rows 83..89 抵南护城河（row 82）
	]

static func street_rects() -> Array:
	return [STREET_NS, STREET_EW, STREET_N, STREET_S,
		RIVERSIDE, PLAZA, CORRIDOR, SPUR_KEEP, WEST_EXIT]

static func lane_rects(lane: int) -> Array:
	var out: Array = []
	for q in LANE_RECTS[lane]:
		out.append(Rect2i(int(q[0]), int(q[1]), int(q[2]), int(q[3])))
	return out

## 门前后的墙洞（城墙不铺石，让门道透出来）
static func gate_holes() -> Array:
	var out: Array = []
	for g in GATES:
		out.append(gate_hole_rect(g))
	return out

## 四座水门：上河/下河在各城墙上各穿一洞（西南 2、东北 2）
static func water_gate_holes() -> Array:
	return [
		Rect2i(21, 13, 2, 2), Rect2i(30, 13, 2, 2),   # 北墙（东北、北中）
		Rect2i(21, 77, 2, 2), Rect2i(30, 77, 2, 2),   # 南墙（西南）
	]

## 水门与护城河之间的连通段（城墙与护城河之间的空档行）
static func water_gate_links() -> Array:
	return [
		Rect2i(21, 12, 2, 1), Rect2i(30, 12, 2, 1),
		Rect2i(21, 79, 2, 1), Rect2i(30, 79, 2, 1),
	]

## 十二敌台（东西各四、南北各二），每座 2×2 直出墙外
static func enemy_tower_rects() -> Array:
	var out: Array = []
	for r in [24, 37, 56, 68]:
		out.append(Rect2i(52, r, 2, 2))   # 东墙外
		out.append(Rect2i(12, r, 2, 2))   # 西墙外
	for c in [24, 44]:
		out.append(Rect2i(c, 11, 2, 2))   # 北墙外
		out.append(Rect2i(c, 79, 2, 2))   # 南墙外
	return out

## 二十铺舍（城上守铺，2×2）。沿城墙内侧四边布置：东西各 6、南北各 4。
## 锚点已避开民居、河浃与城门洞。
static func post_houses() -> Array:
	var out: Array = []
	for r in [18, 27, 43, 55, 64, 73]:
		out.append(Rect2i(IN_X0, r, 1, 2))       # 西墙内侧
		out.append(Rect2i(IN_X1, r, 1, 2))       # 东墙内侧
	for c in [17, 28, 40, 48]:
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

## 东侧海岸线所在列（cols >= 此值即海）
static func _shore_col(r: int) -> int:
	return 101 + int(round(2.0 * sin(float(r) * 0.21)))

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

	_paint_fields(g)
	_paint_coast(g, wet)
	_paint_mountains(st)
	_paint_water(g, wet)
	_paint_walls(st)
	_paint_barbican(st, rd)
	_paint_enemy_towers(st)
	_paint_roads(rd, g, wet)
	_paint_stone_plaza(rd)
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
			# 水面被墙/建筑盖住的（如敌台压护城河）不算可见水面
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
				if c >= shore - 6 and c < shore:
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
		"ground": g, "road": rd, "structure": st, "decor": dc,
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

# ---------- 各分区绘制 ----------

## 城内水田：按 farmland_rects 铺「田面苔 + 田埂沙」的经纬格，读作水田。
static func _paint_fields(g: Array) -> void:
	for rect in farmland_rects():
		var q: Rect2i = rect
		for r in range(q.position.y, q.position.y + q.size.y):
			for c in range(q.position.x, q.position.x + q.size.x):
				if not _inb(c, r):
					continue
				# 田埂：每 4 行一条横埂，每 5 列一条纵埂 → 约 4×5 格一块田
				var ridge: bool = (r - q.position.y) % 4 == 3 or (c - q.position.x) % 5 == 4
				g[_idx(c, r)] = S_SAND if ridge else S_MOSS

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

## 东侧海与沙滩
static func _paint_coast(g: Array, wet: Array) -> void:
	for r in range(ROWS):
		var shore := _shore_col(r)
		for c in range(maxi(0, shore - 6), shore):
			if _inb(c, r):
				g[_idx(c, r)] = S_SAND
		for c in range(shore, COLS):
			g[_idx(c, r)] = S_WATER
			wet[_idx(c, r)] = 1

## 山体：西侧主山（镇山楼所倚）、北岭、南岭
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
	for rect in [MOAT_N, MOAT_S, MOAT_W, MOAT_E, RIVER_LOW, RIVER_UP]:
		_water_rect(g, wet, rect)
	for canal in canals():
		_water_rect(g, wet, canal["rect"])
	# 护城河绕瓮城：先挖出瓮城台基，再补东旁道与南北连通段
	for r in range(BARB_FOOT.position.y, BARB_FOOT.position.y + BARB_FOOT.size.y):
		for c in range(BARB_FOOT.position.x, BARB_FOOT.position.x + BARB_FOOT.size.x):
			if _inb(c, r):
				g[_idx(c, r)] = S_MOSS
				wet[_idx(c, r)] = 0
	for rect in [MOAT_BYPASS, MOAT_LINK_N, MOAT_LINK_S]:
		_water_rect(g, wet, rect)
	# 城外盐田：中心蓄水（水），四周沙埂（沙）
	for pan in salt_pans():
		var r: Rect2i = pan
		for rr in range(r.position.y, r.position.y + r.size.y):
			for cc in range(r.position.x, r.position.x + r.size.x):
				if not _inb(cc, rr):
					continue
				var edge: bool = cc == r.position.x or cc == r.position.x + r.size.x - 1 \
					or rr == r.position.y or rr == r.position.y + r.size.y - 1
				if edge:
					g[_idx(cc, rr)] = S_SAND
				else:
					g[_idx(cc, rr)] = S_WATER
					wet[_idx(cc, rr)] = 1
	# 庙上河（南引水 / 北出水）
	for rect in feeder_streams():
		_water_rect(g, wet, rect)
	# 水门洞 + 与护城河的连通段
	for rect in water_gate_holes():
		_water_rect(g, wet, rect)
	for rect in water_gate_links():
		_water_rect(g, wet, rect)

static func _water_rect(g: Array, wet: Array, rect: Rect2i) -> void:
	for r in range(rect.position.y, rect.position.y + rect.size.y):
		for c in range(rect.position.x, rect.position.x + rect.size.x):
			if _inb(c, r):
				g[_idx(c, r)] = S_WATER
				wet[_idx(c, r)] = 1

## 城墙：外圈暗石（外侧墙面），内圈亮石（墙顶走道）；门洞与水门处留空
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
			_put(st, c, r, S_CLIFF_DARK if d == 0 else S_CLIFF)

## 瓮城：北墙 + 东墙 + 南墙（外城门开在南墙中段 cols 54..55）+ 庭院石铺
static func _paint_barbican(st: Array, rd: Array) -> void:
	_put_rect(st, BARB_WALL_N, S_CLIFF_DARK)
	_put_rect(st, BARB_WALL_E, S_CLIFF_DARK)
	_put_rect(st, BARB_WALL_S1, S_CLIFF_DARK)
	_put_rect(st, BARB_WALL_S2, S_CLIFF_DARK)
	_put_rect(rd, BARB_YARD, S_ROAD_ROCK)
	_put_rect(rd, BARB_GATE_S, S_ROAD_ROCK)

## 十二敌台 + 二十铺舍
static func _paint_enemy_towers(st: Array) -> void:
	for rect in enemy_tower_rects():
		_put_rect(st, rect, S_CLIFF_DARK)
	for rect in post_houses():
		_put_rect(st, rect, S_CLIFF)

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

## 石板广场/门道：宗祠前广场 + 瓮城庭院 + 瓮城南门（在道路之后铺，覆盖土路）
static func _paint_stone_plaza(rd: Array) -> void:
	_put_rect(rd, BARB_YARD, S_ROAD_ROCK)
	_put_rect(rd, BARB_GATE_S, S_ROAD_ROCK)
	_put_rect(rd, PLAZA, S_ROAD_ROCK)

## 建筑地基：主堡/敌方营垒/塔位用亮石与暗石砌成「实体建筑体块」，
## 其余民居（都堂第、上仓坦等）铺石板院落。地基同时压入 blocked。
static func _paint_buildings(st: Array) -> void:
	for spec in building_specs():
		var a: Vector2i = spec["anchor"]
		var s: Vector2i = spec["size"]
		var rect := Rect2i(a.x, a.y, s.x, s.y)
		var id := String(spec["id"])
		if id == "keep_own":
			_put_rect(st, rect, S_CLIFF)
		elif id == "keep_enemy":
			_put_rect(st, rect, S_CLIFF_DARK)
		elif id.begins_with("tower_"):
			_put_rect(st, rect, S_CLIFF)
		else:
			_put_rect(st, rect, S_ROAD_ROCK)

## 装饰：城墙外沿雉堞（每 2 格一堞）+ 主堡台基压边 + 山野乱石
static func _paint_decor(dc: Array, rd: Array, st: Array, wet: Array) -> void:
	var holes := gate_holes()
	var wh := water_gate_holes()
	for c in range(CITY_X0, CITY_X1 + 1, 2):
		for r in [CITY_Y0, CITY_Y1]:
			if _in_rects(c, r, holes) or _in_rects(c, r, wh):
				continue
			_put(dc, c, r, S_STONE_TILE)
	for r in range(CITY_Y0, CITY_Y1 + 1, 2):
		for c in [CITY_X0, CITY_X1]:
			if _in_rects(c, r, holes) or _in_rects(c, r, wh):
				continue
			_put(dc, c, r, S_STONE_TILE)
	# 主堡/倭营台基压边：外扩一圈 stone_00，让建筑体块从草地/石面上读得出来
	for enemy in [false, true]:
		var a := keep_anchor(enemy)
		var s := keep_size(enemy)
		for c in range(a.x - 1, a.x + s.x + 1):
			_put(dc, c, a.y - 1, S_STONE_TILE)
			_put(dc, c, a.y + s.y, S_STONE_TILE)
		for r in range(a.y - 1, a.y + s.y + 1):
			_put(dc, a.x - 1, r, S_STONE_TILE)
			_put(dc, a.x + s.x, r, S_STONE_TILE)
	# 山野与滩涂乱石（确定性散列，只落在空地上）
	for r in range(0, ROWS, 3):
		for c in range(0, COLS, 3):
			if (c * 13 + r * 29 + GEN_SEED) % 41 != 0:
				continue
			var i := _idx(c, r)
			if st[i] < 0 and rd[i] < 0 and wet[i] == 0:
				dc[i] = S_STONE_TILE

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

	_paint_layer(ground, lay["ground"])
	_paint_layer(road, lay["road"])
	_paint_layer(structure, lay["structure"])
	_paint_layer(decor, lay["decor"])

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
## UI 只读这张图，不依赖任何瓦片 source_id 常量；图块语义变了也不影响 UI。
static func _build_zone_map(lay: Dictionary, road: TileMapLayer, structure: TileMapLayer) -> Dictionary:
	var zmap: Dictionary = {}
	var codes: Array = lay["zone"]
	var holes := gate_holes()
	var wholes := water_gate_holes()
	for r in range(ROWS):
		var base := r * COLS
		for c in range(COLS):
			var z: StringName = ZONE_NAMES[int(codes[base + c])]
			var cell := Vector2i(c, r)
			if structure.get_cell_source_id(cell) != -1:
				z = &"wall"
			if road.get_cell_source_id(cell) != -1:
				z = &"road"
			if _in_rects(c, r, holes) or _in_rects(c, r, wholes):
				z = &"gate"
			zmap[cell] = z
	return zmap

## 逐格写瓦片：语义 = 数组里的类别码，变体 = 确定性轮换（同一格永远同一张图）
static func _paint_layer(layer: TileMapLayer, cats: Array) -> void:
	var counts := PackedInt32Array()
	var salts := PackedInt32Array()
	for category in TileCatalogScript.CAT_ORDER:
		counts.append(TileCatalogScript.variant_count(category))
		salts.append(int(TileCatalogScript.CATEGORIES[category]["salt"]))
	for r in range(ROWS):
		var base := r * COLS
		for c in range(COLS):
			var cat: int = cats[base + c]
			if cat < 0:
				continue
			var n: int = counts[cat]
			var v := 0
			if n > 1:
				v = posmod(c * 7 + r * 3 + salts[cat], n)
			layer.set_cell(Vector2i(c, r), cat, Vector2i(v, 0))

static func _make_layer(p_name: String, tileset: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = p_name
	layer.tile_set = tileset
	layer.z_index = z
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return layer
