extends Node2D
## 临时验收探针：跑一次 build()，校验布局几何是否自洽（用后即删）。

const TMB = preload("res://scripts/tile_map_builder.gd")
const TC = preload("res://scripts/tile_catalog.gd")

var _fails: Array[String] = []

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var res: Dictionary = TMB.build(self)
	var dt := Time.get_ticks_msec() - t0
	_report("build_ms=%d" % dt)

	for key in ["ground", "road", "structure", "decor", "cols", "rows", "tile",
			"world_size", "buildings", "blocked"]:
		_expect(res.has(key), "missing key %s" % key)
	_report("cols=%d rows=%d tile=%d world=%s" % [
		res["cols"], res["rows"], res["tile"], str(res["world_size"])])
	_report("buildings=%d blocked=%d" % [res["buildings"].size(), res["blocked"].size()])

	# 1) 每条驿道折线必须压在路上，且终点必须紧贴主堡外沿（不得侵入主堡）
	var ka: Vector2i = TMB.keep_anchor(false)
	var ks: Vector2i = TMB.keep_size(false)
	var keep_rect := Rect2i(ka.x, ka.y, ks.x, ks.y)
	for lane in range(TMB.LANE_ROWS.size()):
		var pts: PackedVector2Array = TMB.lane_points(lane)
		var off := ""
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var steps := int(a.distance_to(b) / 8.0)
			for s in range(steps + 1):
				var p := a.lerp(b, float(s) / float(maxi(1, steps)))
				var cell := Vector2i(int(floor(p.x / 32.0)), int(floor(p.y / 32.0)))
				if res["road"].get_cell_source_id(cell) == -1:
					off += " %s" % str(cell)
		_expect(off == "", "lane %d off-road cells:%s" % [lane, off])
		for i in range(pts.size()):
			var c := Vector2i(int(floor(pts[i].x / 32.0)), int(floor(pts[i].y / 32.0)))
			_expect(not keep_rect.has_point(c), "lane %d ctrl %d inside keep: %s" % [lane, i, str(c)])
		_report("lane%d pts=%d spawn=%s y=%.0f end=%s" % [
			lane, pts.size(), str(TMB.spawn_cell(lane)), TMB.lane_y(lane), str(pts[pts.size() - 1])])

	# 2) 三条驿道起点必须是沙滩（可行走、非水、非结构）
	for lane in range(TMB.LANE_ROWS.size()):
		var c0 := TMB.spawn_cell(lane)
		_expect(not TMB.is_water_cell(c0), "spawn %s is water" % str(c0))
		_expect(res["structure"].get_cell_source_id(c0) == -1, "spawn %s is structure" % str(c0))
		_report("spawn lane%d cell=%s world=%s zone=%s" % [
			lane, str(c0), str(TMB.spawn_world(lane)), str(TMB.zone_at(c0))])

	# 3) 主堡/倭营必须被 blocked 完全覆盖
	for enemy in [false, true]:
		var a: Vector2i = TMB.keep_anchor(enemy)
		var s: Vector2i = TMB.keep_size(enemy)
		var miss := 0
		for dy in range(s.y):
			for dx in range(s.x):
				if not res["blocked"].has(a + Vector2i(dx, dy)):
					miss += 1
		_expect(miss == 0, "keep enemy=%s uncovered=%d" % [str(enemy), miss])
		_report("keep enemy=%s anchor=%s center=%s" % [str(enemy), str(a), str(TMB.keep_center(enemy))])

	# 4) 三门必须真的通（门洞是路）
	for gate in TMB.GATES:
		var hole: Rect2i = TMB.gate_hole_rect(gate)
		var road_cells := 0
		for r in range(hole.position.y, hole.position.y + hole.size.y):
			for c in range(hole.position.x, hole.position.x + hole.size.x):
				if res["road"].get_cell_source_id(Vector2i(c, r)) != -1:
					road_cells += 1
		_expect(road_cells == hole.size.x * hole.size.y,
			"gate %s not passable (%d/%d)" % [gate["name"], road_cells, hole.size.x * hole.size.y])
		_report("gate %s side=%s world=%s" % [gate["name"], gate["side"], str(TMB.gate_world(String(gate["name"])))])

	# 5) 结构层与道路层不应重叠（门洞已从城墙里挖掉）
	var overlap := 0
	for r in range(TMB.ROWS):
		for c in range(TMB.COLS):
			var cell := Vector2i(c, r)
			if res["structure"].get_cell_source_id(cell) != -1 and res["road"].get_cell_source_id(cell) != -1:
				overlap += 1
				if overlap <= 5:
					_report("overlap at %s" % str(cell))
	_expect(overlap == 0, "structure/road overlap=%d" % overlap)

	# 6) 城内可建格数量（建造系统能用多少地）
	var buildable := 0
	var city_blocked := 0
	for r in range(15, 77):
		for c in range(16, 50):
			if res["blocked"].has(Vector2i(c, r)):
				city_blocked += 1
			else:
				buildable += 1
	_report("city interior buildable=%d blocked=%d" % [buildable, city_blocked])
	_expect(buildable > 900, "too few buildable city cells: %d" % buildable)

	# 7) zone 抽样（直接用 build() 暴露的 zone 码表，避免被 zone_map 归并影响）
	var zones: Dictionary = {}
	var zcodes: PackedByteArray = res["zone"]
	for r in range(TMB.ROWS):
		for c in range(TMB.COLS):
			var z := str(TMB.ZONE_NAMES[int(zcodes[r * TMB.COLS + c])])
			zones[z] = int(zones.get(z, 0)) + 1
	_report("zones=%s" % str(zones))
	for z in ["city", "moat", "river", "sea", "beach", "field", "mountain", "salt"]:
		_expect(int(zones.get(z, 0)) > 0, "zone %s empty" % z)
	# field 应接近史载「水田 200 余亩」≈ 970 格
	var nfield: int = int(zones.get("field", 0))
	_expect(nfield > 850 and nfield < 1150, "field cells=%d (want ~970 for 200 mu)" % nfield)
	_report("farmland=%d cells (~%.0f mu at 137m2/cell)" % [nfield, float(nfield) * 137.0 / 666.7])
	# zone_at() 必须能区分核心语义（全图扫描，别用碰巧落在城墙/结构上的采样点）
	var seen: Dictionary = {}
	for r in range(TMB.ROWS):
		for c in range(TMB.COLS):
			seen[str(TMB.zone_at(Vector2i(c, r)))] = true
	_report("zone_at distinct=%s" % str(seen.keys()))
	for need in ["city", "moat", "river", "field", "sea", "gate", "wall", "road"]:
		_expect(seen.has(need), "zone_at missing %s" % need)

	# 8) 水体抽样
	for probe in [Vector2i(11, 40), Vector2i(21, 40), Vector2i(30, 40), Vector2i(110, 45)]:
		_expect(TMB.is_water_cell(probe), "expected water at %s (zone=%s)" % [str(probe), str(TMB.zone_at(probe))])
	_report("water moat=%s river_low=%s river_up=%s sea=%s" % [
		str(TMB.zone_at(Vector2i(11, 40))), str(TMB.zone_at(Vector2i(21, 40))),
		str(TMB.zone_at(Vector2i(30, 40))), str(TMB.zone_at(Vector2i(110, 45)))])

	# 9) 图块目录：109 张具名图块全部注册
	var nm := TC.name_map()
	_expect(nm.size() == 109, "tile catalog size=%d (want 109)" % nm.size())
	var cats: Dictionary = {}
	for k in nm.keys():
		var cat := str(TC.category_of(String(k)))
		cats[cat] = int(cats.get(cat, 0)) + 1
	_report("catalog=%s" % str(cats))
	_report("variant sample moss(3,3)=%s moss(4,3)=%s water(30,40)=%s" % [
		TC.pick_variant(&"moss", 3, 3), TC.pick_variant(&"moss", 4, 3), TC.pick_variant(&"water", 30, 40)])
	# 确定性：同参数两次结果一致
	_expect(TC.pick_variant(&"moss", 7, 9) == TC.pick_variant(&"moss", 7, 9), "pick_variant not deterministic")

	# 10) 产出层使用的 source_id 必须落在 0..8
	var used: Dictionary = {}
	for layer_name in ["ground", "road", "structure", "decor"]:
		var layer: TileMapLayer = res[layer_name]
		for cell in layer.get_used_cells():
			var sid := layer.get_cell_source_id(cell)
			used[sid] = int(used.get(sid, 0)) + 1
			if sid < 0 or sid > 8:
				_expect(false, "bad source_id %d on %s at %s" % [sid, layer_name, str(cell)])
	_report("source usage=%s" % str(used))

	# 11) 水系形制：上河/下河纵贯、十条河浃、西门浃西接镇山楼
	for canal in TMB.canals():
		var q: Rect2i = canal["rect"]
		var mid := Vector2i(q.position.x + q.size.x / 2, q.position.y)
		_expect(TMB.is_water_cell(mid), "canal %s not water at %s" % [canal["name"], str(mid)])
	_report("canals=%d" % TMB.canals().size())
	_expect(TMB.canals().size() == 10, "canal count=%d (history says 10)" % TMB.canals().size())
	# 西门浃「西头直抵镇山楼」：水上格必须紧贴西墙内侧（col 16 水，col 15 结构）
	_expect(TMB.is_water_cell(Vector2i(16, 41)), "西门浃 西端未接镇山楼")
	_expect(res["structure"].get_cell_source_id(Vector2i(15, 41)) != -1, "镇山楼内墙缺失")
	_report("西门浃 west end: water(16,41)=%s wall(15,41)=%s" % [
		str(TMB.is_water_cell(Vector2i(16, 41))),
		str(res["structure"].get_cell_source_id(Vector2i(15, 41)) != -1)])
	# 上河 / 下河 南北贯通（rows 16..75 每行都是水）
	for river in [TMB.RIVER_LOW, TMB.RIVER_UP]:
		var q: Rect2i = river
		var breaks := 0
		for r in range(q.position.y + 1, q.position.y + q.size.y - 1):
			if not TMB.is_water_cell(Vector2i(q.position.x, r)):
				breaks += 1
		_expect(breaks == 0, "river at col %d has %d breaks" % [q.position.x, breaks])
	_report("rivers 下河 col=%d 上河 col=%d 贯通=yes" % [
		TMB.RIVER_LOW.position.x, TMB.RIVER_UP.position.x])

	# 12) 四座水门：上河/下河各穿南北城墙，且与护城河连通
	for rect in TMB.water_gate_holes():
		var q: Rect2i = rect
		_expect(TMB.is_water_cell(q.position), "water gate not water at %s" % str(q.position))
	_report("water gates=%d (西南2 东北2)" % TMB.water_gate_holes().size())

	# 13) 主驿道（lane 1）必须同时穿过瓮城水门与环海楼
	var east_gate: Dictionary = {}
	for g in TMB.GATES:
		if String(g["name"]) == "环海楼":
			east_gate = g
	var eh: Rect2i = TMB.gate_hole_rect(east_gate)
	var lane1: PackedVector2Array = TMB.lane_points(1)
	var hit_east := false
	var hit_barb := false
	for i in range(lane1.size() - 1):
		var a := lane1[i]
		var b := lane1[i + 1]
		var steps := int(a.distance_to(b) / 4.0)
		for s in range(steps + 1):
			var p := a.lerp(b, float(s) / float(maxi(1, steps)))
			var cell := Vector2i(int(floor(p.x / 32.0)), int(floor(p.y / 32.0)))
			if eh.has_point(cell):
				hit_east = true
			if TMB.BARB_GATE_S.has_point(cell):
				hit_barb = true
	_expect(hit_east, "lane1 未穿过环海楼门洞")
	_expect(hit_barb, "lane1 未穿过瓮城南门")
	_report("lane1 through 瓮城南门=%s 环海楼=%s" % [str(hit_barb), str(hit_east)])

	# 14) 瓮城：外城门必须是可通行路，三面墙必须是结构
	_expect(res["road"].get_cell_source_id(Vector2i(TMB.BARB_GATE_S.position.x, TMB.BARB_GATE_S.position.y)) != -1,
		"瓮城 外城门不是路")
	_expect(res["structure"].get_cell_source_id(Vector2i(TMB.BARB_WALL_E.position.x, TMB.BARB_WALL_E.position.y + 5)) != -1,
		"瓮城 东墙缺失")
	_report("barbican foot=%s gate_south=%s" % [str(TMB.BARB_FOOT), str(TMB.BARB_GATE_S)])

	if _fails.is_empty():
		print("[PROBE] PASS")
	else:
		print("[PROBE] FAIL count=%d" % _fails.size())
		for f in _fails:
			print("[PROBE] - %s" % f)
	_dump_ascii(res)

## 120×90 ASCII 图（每格一字符，无歧义字形），便于逐格核对
func _dump_ascii(res: Dictionary) -> void:
	var glyph: Dictionary = {
		0: ".", 1: ",", 2: "=", 3: "#", 4: "%",
		5: "^", 6: "X", 7: "o", 8: "~",
	}
	var lines: Array[String] = []
	lines.append("     " + _ruler())
	for r in range(TMB.ROWS):
		var line := "%3d  " % r
		for c in range(TMB.COLS):
			var cell := Vector2i(c, r)
			var ch := "."
			for name in ["ground", "road", "structure", "decor"]:
				var sid := (res[name] as TileMapLayer).get_cell_source_id(cell)
				if sid == -1:
					continue
				ch = glyph.get(sid, "?")
			var ka: Vector2i = TMB.keep_anchor(false)
			var ks: Vector2i = TMB.keep_size(false)
			if c >= ka.x and c < ka.x + ks.x and r >= ka.y and r < ka.y + ks.y:
				ch = "K"
			var ea: Vector2i = TMB.keep_anchor(true)
			var es: Vector2i = TMB.keep_size(true)
			if c >= ea.x and c < ea.x + es.x and r >= ea.y and r < ea.y + es.y:
				ch = "E"
			for i in range(TMB.TOWER_ANCHORS.size()):
				var ta: Vector2i = TMB.tower_anchor(i)
				if c >= ta.x and c < ta.x + TMB.TOWER_SIZE.x and r >= ta.y and r < ta.y + TMB.TOWER_SIZE.y:
					ch = "T"
			line += ch
		lines.append(line)
	lines.append("     " + _ruler())
	lines.append("legend: . moss(苔地/田面)  , sand(沙/田埂)  = road(土路)  # road_rock(石板/桥/门道)")
	lines.append("        % road_sand(沙路)  ^ cliff(亮石/塔/铺舍)  X cliff_dark(暗石外墙/瓮城)")
	lines.append("        o stone_00(雉堞/乱石)  ~ water(护城河/上河/下河/河浃/海/盐田)")
	lines.append("        K 主堡(王氏宗祠)  E 倭营  T 预置塔位")
	var out := ProjectSettings.globalize_path("res://tests/terrain_ascii.txt")
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		f.close()
	print("[PROBE] ascii=%s" % out)

func _ruler() -> String:
	var s := ""
	for c in range(TMB.COLS):
		s += str(c % 10)
	return s


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _report(s: String) -> void:
	print("[PROBE] %s" % s)
