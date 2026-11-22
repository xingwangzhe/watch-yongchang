extends Node2D
## 主场景：《守望·永昌》战斗关。
##
## 玩法骨架（本文件负责编排，不实现具体规则）：
## 1. TileMapBuilder 铺设永昌堡地形（城墙 / 瓮城 / 护城河 / 上河下河 / 农田 / 三门驿道）
## 2. SpawnSystem 按定时波次从三门持续放出敌兵（Mindustry 式 waveInterval + waveSpacing）
## 3. BuildSystem 处理 3×3 多格建造；BuildPreview 只在放置模式显示
## 4. Selection：点空地取消 → 点单位/建筑选中 → 右栏内容随之切换（默认右栏不出现）
## 5. MiniMapPanel 右上角小地图；SidebarPanel 右侧栏（建造 / 生产 / 详情三态）
##
## 交互链路（对齐 OpenHV/OpenRA 的「选择 → 侧栏 → 放置」模型）：
##   左键点选 → _select_object() → sidebar.show_context()
##   右栏点建造项 → build_requested → _begin_build() → 放置模式
##   左键落地 → _try_build_at() → 成功则自动选中新建筑并回到 produce 上下文
##   右键 / Esc → _cancel_build() 或清空选择 → 右栏隐藏

# 显式 preload：新建 class_name 的全局缓存不可靠
const TileMapBuilder = preload("res://scripts/tile_map_builder.gd")
const SpawnSystemScript = preload("res://scripts/spawn_system.gd")
const BuildSystemScript = preload("res://scripts/build_system.gd")
const SidebarScript = preload("res://scripts/ui/sidebar_panel.gd")
const MinimapScript = preload("res://scripts/ui/minimap_panel.gd")

## 兵种定义（id / 名称 / 造价 / 血量 / 速度 / 图标）
const UNIT_DEFS: Array[Dictionary] = [
	{"id": &"xiangyong", "label": "乡勇", "cost": 10, "hp": 120, "speed": 30.0,
		"icon": "res://assets/ui/icon_militia.png", "hotkey": "1", "desc": "持械乡民，便宜耐打"},
	{"id": &"gongshou", "label": "弓手", "cost": 16, "hp": 80, "speed": 45.0,
		"icon": "res://assets/ui/icon_archer.png", "hotkey": "2", "desc": "远程抛射，脆但手长"},
	{"id": &"longdeng", "label": "龙灯队", "cost": 36, "hp": 150, "speed": 60.0,
		"icon": "res://assets/ui/icon_dragon.png", "hotkey": "3", "desc": "拼字龙灯出征，冲阵利器"},
]

## 建筑定义（id / 名称 / 造价 / 图标 / 可生产兵种）
const BUILD_DEFS: Array[Dictionary] = [
	{"id": &"jianta", "label": "箭塔", "cost": 40,
		"icon": "res://assets/ui/icon_tower.png", "hotkey": "Q", "desc": "自动索敌，守驿道",
		"produces": []},
	{"id": &"junxiefang", "label": "军械坊", "cost": 35,
		"icon": "res://assets/ui/icon_armory.png", "hotkey": "E", "desc": "每座每 5 秒额外补给 4 发弹药",
		"produces": [&"xiangyong", &"gongshou"]},
	{"id": &"fenghuotai", "label": "烽火台", "cost": 30,
		"icon": "res://assets/ui/icon_signal.png", "hotkey": "R", "desc": "预警敌情，加快银两产出",
		"produces": [&"longdeng"]},
]

const COL_INK := Color(0.75, 0.72, 0.62)
const COL_OWN := Color(0.24, 0.42, 0.47)
const COL_ENEMY := Color(0.62, 0.28, 0.24)
const COL_SELECT := Color(0.95, 0.80, 0.35)

@onready var lanes: Node2D = $Lanes
@onready var units_layer: Node2D = $Battle/Units
@onready var towers_layer: Node2D = $Battle/Towers
@onready var hud: CanvasLayer = $UI

var lane_paths: Array[Path2D] = []
var auto_mode: bool = true

var spawn_system: Node = null
var build_system: Node = null

## 放置模式：true 时鼠标位置显示 3×3 预览，左键落建筑
var build_mode: bool = false
var selected_build: int = -1
var selected_object: Node = null

var _build_preview: Node2D = null
var _selection_ring: Node2D = null
var _sidebar: Control = null
var _minimap: Control = null
var map_result: Dictionary = {}
var camera_rig: Camera2D = null

var _workshop_bonus_accum: float = 0.0
var _beacon_bonus_accum: float = 0.0

func _ready() -> void:
	randomize()
	GameState.reset_level()
	SupplySystem.reset()
	DataDB.load_all()
	ResourceManager.preload_level("lv_01")
	_build_tilemap()
	_build_lanes()
	_build_bases()
	_setup_systems()
	_build_ui()
	GameState.set_phase(GameState.Phase.BATTLE)
	EventBus.result_decided.connect(_on_result)
	print("[PREFLIGHT] scene=main started=true mode=timed_defense lanes=%d" % lane_paths.size())

# ---------- 地形与坐标 ----------

func _build_tilemap() -> void:
	map_result = TileMapBuilder.build(self)
	var buildings: Array = map_result.get("buildings", [])
	print("[TILEMAP] cols=%d rows=%d tile=%d buildings=%d world=%s" % [
		map_result.get("cols", 0), map_result.get("rows", 0), map_result.get("tile", 32),
		buildings.size(), str(map_result.get("world_size", Vector2.ZERO))])
	var rig := preload("res://scripts/camera_rig.gd").new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.setup(map_result.get("world_size", Vector2(3840, 2880)))
	rig.position = TileMapBuilder.keep_center(false) + Vector2(520.0, 0.0)
	rig.reset_smoothing()
	camera_rig = rig

func _build_lanes() -> void:
	for i in range(TileMapBuilder.LANE_ROWS.size()):
		var path := Path2D.new()
		path.name = "Lane_%d" % i
		var curve := Curve2D.new()
		var pts: PackedVector2Array = _lane_points(i)
		for p in pts:
			curve.add_point(p)
		path.curve = curve
		lanes.add_child(path)
		lane_paths.append(path)
		print("[LANE] lane=%d gate=%s points=%d len=%.0f" % [
			i, _gate_name(i), pts.size(), curve.get_baked_length()])

## 驿道折线：优先用地图脚本给出的「城内主堡 → 穿门 → 城外刷新点」控制点
func _lane_points(lane: int) -> PackedVector2Array:
	var pts: PackedVector2Array = TileMapBuilder.lane_points(lane)
	if pts.size() >= 2:
		# 统一方向为「城内主堡 → 城外刷新点」：unit.gd 的 direction 约定依赖这个顺序
		var spawn_pt: Vector2 = TileMapBuilder.spawn_world(lane)
		if pts[0].distance_to(spawn_pt) < pts[pts.size() - 1].distance_to(spawn_pt):
			pts.reverse()
		return pts
	# 兜底：主堡中心 → 刷新点直线（理论上不会走到）
	return PackedVector2Array([TileMapBuilder.keep_center(false), TileMapBuilder.spawn_world(lane)])

func _gate_name(lane: int) -> String:
	return str(TileMapBuilder.lane_gate_name(lane))

func _build_bases() -> void:
	_make_nameplate(self, "OwnKeepLabel",
		TileMapBuilder.keep_center(false) + Vector2(-40.0, 96.0), "永昌城", COL_OWN, -14)

func _build_spawn_marks() -> void:
	for p in spawn_system.get_points():
		var w: Vector2 = p["world"]
		var mark := _make_rect(self, "SpawnMark_%s" % str(p["id"]),
			w - Vector2(10, 10), Vector2(20, 20), COL_ENEMY, -8)
		mark.modulate.a = 0.35
		_make_nameplate(self, "SpawnLabel_%s" % str(p["id"]),
			w + Vector2(14, -14), "倭", COL_ENEMY, -7)

# ---------- 子系统 ----------

func _setup_systems() -> void:
	spawn_system = SpawnSystemScript.new()
	spawn_system.name = "SpawnSystem"
	add_child(spawn_system)
	spawn_system.setup()
	spawn_system.enemy_spawn_requested.connect(_on_enemy_spawn_requested)
	spawn_system.wave_started.connect(_on_wave_started)
	if spawn_system.has_signal("wave_countdown_changed"):
		spawn_system.wave_countdown_changed.connect(_on_wave_countdown)

	build_system = BuildSystemScript.new()
	build_system.name = "BuildSystem"
	add_child(build_system)
	build_system.blocked = map_result.get("blocked", {})
	build_system.building_placed.connect(_on_building_placed)
	build_system.build_failed.connect(_on_build_failed)
	_build_spawn_marks()

# ---------- UI ----------

func _build_ui() -> void:
	set_process(true)
	hud.build_menu_requested.connect(_open_build_menu)
	_build_minimap()
	_build_sidebar()
	# 建造预览：只在放置模式显示
	_build_preview = preload("res://scripts/build_preview.gd").new() as Node2D
	_build_preview.name = "BuildPreview"
	_build_preview.set("main_ref", self)
	_build_preview.z_index = 15
	_build_preview.visible = false
	add_child(_build_preview)
	# 选中高亮环
	_selection_ring = preload("res://scripts/selection_ring.gd").new() as Node2D
	_selection_ring.name = "SelectionRing"
	_selection_ring.z_index = 14
	add_child(_selection_ring)

func _build_minimap() -> void:
	_minimap = MinimapScript.new()
	_minimap.name = "MiniMapPanel"
	_minimap.call("setup", map_result, units_layer, camera_rig)
	hud.add_child(_minimap)
	# 右上角：从 y=64 起，222×222
	_minimap.anchor_left = 1.0
	_minimap.anchor_right = 1.0
	_minimap.anchor_top = 0.0
	_minimap.anchor_bottom = 0.0
	_minimap.offset_left = -238.0
	_minimap.offset_right = -16.0
	_minimap.offset_top = 64.0
	_minimap.offset_bottom = 286.0

func _build_sidebar() -> void:
	_sidebar = SidebarScript.new()
	_sidebar.name = "SidebarPanel"
	hud.add_child(_sidebar)
	_sidebar.anchor_left = 1.0
	_sidebar.anchor_right = 1.0
	_sidebar.anchor_top = 0.0
	_sidebar.anchor_bottom = 1.0
	_sidebar.offset_left = -261.0
	_sidebar.offset_right = -16.0
	_sidebar.offset_top = 298.0
	_sidebar.offset_bottom = -16.0
	_sidebar.build_requested.connect(_on_build_requested)
	_sidebar.produce_requested.connect(_on_produce_requested)
	_sidebar.closed.connect(_close_sidebar)
	_sidebar.visible = false

# ---------- 输入 ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1: spawn_player_unit(0)
			KEY_2: spawn_player_unit(1)
			KEY_3: spawn_player_unit(2)
			KEY_B: _open_build_menu()
			KEY_Q: _on_build_requested(&"jianta")
			KEY_E: _on_build_requested(&"junxiefang")
			KEY_R:
				if not build_mode:
					GameFlow.restart_battle()
			KEY_SPACE: _rush_wave()
			KEY_ESCAPE:
				if build_mode:
					_cancel_build()
				elif selected_object != null:
					_clear_selection()
				else:
					_toggle_pause()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if build_mode:
				_try_build_at(get_global_mouse_position())
			else:
				_select_at(get_global_mouse_position())
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if build_mode:
				_cancel_build()
			else:
				_clear_selection()

# ---------- 选择链路 ----------

## 点选：先找单位，再找建筑；都没有则清空（右栏随之隐藏）
func _select_at(world_pos: Vector2) -> void:
	var hit := _pick_unit(world_pos)
	if hit == null:
		hit = _pick_building(world_pos)
	if hit == null:
		_clear_selection()
		return
	_select_object(hit)

func _pick_unit(world_pos: Vector2) -> Node:
	var best: Node = null
	var best_d := 34.0
	for node in get_tree().get_nodes_in_group("units"):
		var n2d := node as Node2D
		if n2d == null or not is_instance_valid(n2d):
			continue
		var d: float = n2d.global_position.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = n2d
	return best

func _pick_building(world_pos: Vector2) -> Node:
	var best: Node = null
	var best_d := 72.0
	for node in get_tree().get_nodes_in_group("buildings"):
		var n2d := node as Node2D
		if n2d == null or not is_instance_valid(n2d):
			continue
		var d: float = n2d.global_position.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = n2d
	return best

func _select_object(obj: Node) -> void:
	selected_object = obj
	selection_ring_set(obj)
	_refresh_sidebar_for(obj)

## 右侧栏内容完全由「当前选中对象」驱动；没有选中就隐藏
func _refresh_sidebar_for(obj: Node) -> void:
	if obj == null or _sidebar == null:
		_close_sidebar()
		return
	var kind: StringName = &"inspect"
	var payload: Dictionary = {}

	if obj is Unit:
		var u := obj as Unit
		payload = {
			"title": _unit_label(u.type_id),
			"subtitle": ("倭寇" if u.is_enemy else "永昌守军") + " · 第 %d 路" % (u.lane_index + 1),
			"hp": u.hp, "max_hp": u.max_hp,
			"stats": [
				{"k": "血量", "v": "%d / %d" % [u.hp, u.max_hp]},
				{"k": "速度", "v": "%.0f" % u.speed},
				{"k": "阵营", "v": "敌" if u.is_enemy else "我"},
			],
			"actions": [],
		}
	else:
		var bkind: StringName = obj.get_meta("build_kind", &"")
		var def := _build_def(bkind)
		var produces: Array = def.get("produces", [])
		if not produces.is_empty():
			kind = &"produce"
			payload = {
				"title": str(def.get("label", "建筑")),
				"subtitle": "生产队列 · 点击出兵",
				"building": bkind,
				"items": _produce_items(produces),
			}
		else:
			payload = {
				"title": str(def.get("label", "建筑")),
				"subtitle": str(def.get("desc", "")),
				"hp": int(obj.get("hp")) if obj.get("hp") != null else 0,
				"max_hp": int(obj.get("max_hp")) if obj.get("max_hp") != null else 0,
				"stats": [
					{"k": "造价", "v": "%d 银" % int(def.get("cost", 0))},
					{"k": "占格", "v": "3 × 3"},
				],
				"actions": [],
			}
	_sidebar.call("show_context", kind, payload)
	_sidebar.visible = true

func _produce_items(ids: Array) -> Array:
	var out: Array = []
	for raw in ids:
		var id := StringName(str(raw))
		var def := _unit_def(id)
		out.append({
			"id": id,
			"label": str(def.get("label", str(id))),
			"icon": str(def.get("icon", "")),
			"cost": int(def.get("cost", 0)),
			"hotkey": str(def.get("hotkey", "")),
			"enabled": GameState.silver >= int(def.get("cost", 0)),
			"desc": str(def.get("desc", "")),
		})
	return out

func _clear_selection() -> void:
	selected_object = null
	selection_ring_set(null)
	_close_sidebar()

func _close_sidebar() -> void:
	if _sidebar != null:
		_sidebar.call("close")

# ---------- 建造链路 ----------

## 打开建造菜单（右栏 build 上下文）；已打开同一上下文时再次触发则收起（快捷键 B 的行为）
func _open_build_menu() -> void:
	if _sidebar == null:
		return
	if _sidebar.visible and _sidebar.call("get_context") == &"build":
		_close_sidebar()
		return
	_show_build_menu()

## 强制显示建造菜单（不做 toggle）——取消放置、Esc 回退时用
func _show_build_menu() -> void:
	if _sidebar == null:
		return
	var items: Array = []
	for def in BUILD_DEFS:
		items.append({
			"id": def["id"],
			"label": str(def["label"]),
			"icon": str(def["icon"]),
			"cost": int(def["cost"]),
			"hotkey": str(def["hotkey"]),
			"enabled": GameState.silver >= int(def["cost"]),
			"desc": str(def["desc"]),
		})
	_sidebar.call("show_context", &"build", {
		"title": "营建",
		"subtitle": "选择后左键落位 · 右键取消",
		"items": items,
	})
	_sidebar.visible = true

func _on_build_requested(id: StringName) -> void:
	var idx := _build_index(id)
	if idx < 0:
		return
	selected_build = idx
	build_mode = true
	if _build_preview != null:
		_build_preview.visible = true
	print("[BUILD] mode=place kind=%s cost=%d" % [str(id), int(BUILD_DEFS[idx]["cost"])])

func _cancel_build() -> void:
	build_mode = false
	selected_build = -1
	if _build_preview != null:
		_build_preview.visible = false
	# 取消放置后回到建造菜单（而不是直接消失），符合「侧栏跟随上下文」的预期
	_show_build_menu()

func _try_build_at(world_pos: Vector2) -> void:
	if build_system == null or not build_mode:
		return
	if GameState.phase == GameState.Phase.VICTORY or GameState.phase == GameState.Phase.DEFEAT:
		return
	if selected_build < 0 or selected_build >= BUILD_DEFS.size():
		return
	var anchor: Vector2i = build_system.world_to_cell(world_pos)
	var kind: StringName = BUILD_DEFS[selected_build]["id"]
	var node: Node2D = build_system.place(anchor, kind, towers_layer)
	if node != null:
		build_mode = false
		selected_build = -1
		if _build_preview != null:
			_build_preview.visible = false
		_select_object(node)

func _on_building_placed(kind: StringName, cell: Vector2i, node: Node2D) -> void:
	print("[BUILD] placed kind=%s anchor=%s pos=%s occupied=%d" % [
		str(kind), cell, node.position, build_system.get_occupied_count()])
	if kind == &"jianta":
		node.set("lane_index", _nearest_lane(node.position.y))

func _on_build_failed(reason: String) -> void:
	GameState.last_error = reason
	print("[BUILD] rejected reason=%s silver=%d" % [reason, GameState.silver])

func _nearest_lane(y: float) -> int:
	var best := 0
	var best_d := INF
	for i in range(TileMapBuilder.LANE_ROWS.size()):
		var d: float = absf(y - TileMapBuilder.lane_y(i))
		if d < best_d:
			best_d = d
			best = i
	return best

# ---------- 出兵 ----------

func _on_produce_requested(id: StringName) -> void:
	var idx := _unit_index(id)
	if idx < 0:
		return
	spawn_player_unit(idx)
	# 生产后刷新右栏可用状态（银两变化影响 enabled）
	if selected_object != null:
		_refresh_sidebar_for(selected_object)

func spawn_player_unit(type_index: int) -> void:
	if GameState.phase == GameState.Phase.VICTORY or GameState.phase == GameState.Phase.DEFEAT:
		return
	if type_index < 0 or type_index >= UNIT_DEFS.size():
		return
	var def: Dictionary = UNIT_DEFS[type_index]
	var cost: int = int(def["cost"])
	if GameState.silver < cost:
		GameState.last_error = "silver_not_enough"
		print("[PLAYER] rejected silver=%d need=%d" % [GameState.silver, cost])
		return
	if lane_paths.is_empty():
		return
	GameState.add_silver(-cost)
	var lane: int = randi() % lane_paths.size()
	var scene := load("res://scenes/unit.tscn") as PackedScene
	var unit := scene.instantiate() as Unit
	unit.setup(def["id"], lane, int(def["hp"]), float(def["speed"]), false, 1.0)
	lane_paths[lane].add_child(unit)
	EventBus.unit_spawned.emit(def["id"], lane)
	print("[PLAYER] spawn type=%s lane=%d cost=%d silver=%d" % [def["id"], lane, cost, GameState.silver])

func _on_enemy_spawn_requested(type_id: StringName, lane: int, hp_scale: float, speed: float) -> void:
	if lane < 0 or lane >= lane_paths.size():
		return
	var scene := load("res://scenes/unit.tscn") as PackedScene
	var unit := scene.instantiate() as Unit
	var def := _unit_def(type_id)
	var hp: int = int(float(def.get("hp", 120)) * hp_scale)
	unit.setup(type_id, lane, hp, speed, true, -1.0)
	lane_paths[lane].add_child(unit)
	print("[ENEMY] spawn type=%s lane=%d hp=%d wave=%d" % [type_id, lane, hp, GameState.wave_index])

func _on_wave_started(index: int, count: int) -> void:
	GameState.wave_index = index
	EventBus.wave_started.emit(index, count)
	print("[WAVE] index=%d count=%d gate=%s" % [index, count, _gate_name((index - 1) % 3)])
	if index == 2:
		EventBus.culture_event.emit(&"kangwo", "抗倭：三路坚守，全军伤害提升")
		print("[CULTURE] card=kangwo effect=damage+20%%")
	elif index == 4:
		EventBus.culture_event.emit(&"longdeng", "拼字龙灯出阵：全军士气高涨")
		print("[CULTURE] card=longdeng effect=morale+")

func _on_wave_countdown(seconds: float) -> void:
	if hud != null and hud.has_method("set_wave_countdown"):
		hud.call("set_wave_countdown", seconds)

func _rush_wave() -> void:
	if spawn_system != null and spawn_system.has_method("rush_next_wave"):
		spawn_system.call("rush_next_wave")

# ---------- 每帧 ----------

func _process(delta: float) -> void:
	if GameState.phase == GameState.Phase.VICTORY or GameState.phase == GameState.Phase.DEFEAT:
		return
	GameState.time_sec += delta
	SupplySystem.produce(delta)
	_tick_buildings(delta)
	_tick_waves(delta)
	_update_hud()
	if GameState.time_sec >= GameState.TIME_LIMIT_SEC and GameState.keep_hp > 0:
		GameState.decide(true, "time_survived")

## 建筑增益：军械坊补弹、烽火台产银（按种类计数，5 秒一跳）
func _tick_buildings(delta: float) -> void:
	var workshops := _count_building(&"junxiefang")
	if workshops > 0:
		_workshop_bonus_accum += delta
		if _workshop_bonus_accum >= 5.0:
			_workshop_bonus_accum -= 5.0
			SupplySystem.ammo_stock += 4 * workshops
	var beacons := _count_building(&"fenghuotai")
	if beacons > 0:
		_beacon_bonus_accum += delta
		if _beacon_bonus_accum >= 5.0:
			_beacon_bonus_accum -= 5.0
			GameState.add_silver(2 * beacons)

func _count_building(kind: StringName) -> int:
	if build_system == null:
		return 0
	var n := 0
	for v in build_system.occupied.values():
		if StringName(str(v)) == kind:
			n += 1
	return n

func _tick_waves(delta: float) -> void:
	if spawn_system == null:
		return
	spawn_system.tick(delta, _alive_enemies())
	if GameState.wave_index > 0 and not GameState.phase == GameState.Phase.BATTLE:
		GameState.set_phase(GameState.Phase.BATTLE)

func _alive_enemies() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("units"):
		var u := node as Unit
		if u != null and u.is_enemy and not u.is_dead:
			n += 1
	return n

func _update_hud() -> void:
	if hud != null and hud.has_method("update_stats"):
		hud.call("update_stats", GameState.grain, GameState.silver, SupplySystem.ammo_stock,
			GameState.keep_hp, GameState.wave_index)

func _on_result(_victory: bool, _reason: String) -> void:
	build_mode = false
	if _build_preview != null:
		_build_preview.visible = false

func _toggle_pause() -> void:
	if hud != null and hud.has_method("toggle_pause"):
		hud.toggle_pause(not hud.is_paused())

func selection_ring_set(obj: Node) -> void:
	if _selection_ring != null and _selection_ring.has_method("track"):
		_selection_ring.call("track", obj)

# ---------- 工具 ----------

func _unit_def(id: StringName) -> Dictionary:
	for def in UNIT_DEFS:
		if def["id"] == id:
			return def
	return {"id": id, "label": str(id), "cost": 0, "hp": 120, "speed": 40.0, "icon": ""}

func _unit_label(id: StringName) -> String:
	return str(_unit_def(id).get("label", str(id)))

func _unit_index(id: StringName) -> int:
	for i in range(UNIT_DEFS.size()):
		if UNIT_DEFS[i]["id"] == id:
			return i
	return -1

func _build_def(id: StringName) -> Dictionary:
	for def in BUILD_DEFS:
		if def["id"] == id:
			return def
	return {"id": id, "label": str(id), "cost": 0, "produces": []}

func _build_index(id: StringName) -> int:
	for i in range(BUILD_DEFS.size()):
		if BUILD_DEFS[i]["id"] == id:
			return i
	return -1

func _make_rect(parent: Node, p_name: String, pos: Vector2, size: Vector2, color: Color, z: int) -> ColorRect:
	var r := ColorRect.new()
	r.name = p_name
	r.position = pos
	r.size = size
	r.color = color
	r.z_index = z
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

## 带半透明底的小铭牌：地图内少量必要标注，避免裸文字压在瓦片上难辨
func _make_nameplate(parent: Node, p_name: String, pos: Vector2, text: String, accent: Color, z: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = p_name
	panel.position = pos
	panel.z_index = z
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.07, 0.82)
	sb.set_border_width_all(1)
	sb.border_color = accent
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load("res://assets/fonts/LXGWWenKai-Regular.ttf") as Font)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", accent)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(l)
	parent.add_child(panel)
	return panel

const GDA_CALLABLE := ["get_debug_snapshot", "spawn_player_unit", "teleport_camera",
	"debug_open_build_menu", "debug_demo_produce", "debug_next_wave"]

## gda 调试钩子：打开建造菜单（等价按 B），无输入设备时做 UI 截图验收用
func debug_open_build_menu() -> Dictionary:
	_open_build_menu()
	return get_debug_snapshot()

## gda 调试钩子：主堡旁放一座军械坊并选中，验证「点建筑改右栏」
func debug_demo_produce() -> Dictionary:
	if build_system == null:
		return {"ok": false}
	var base: Vector2i = build_system.world_to_cell(TileMapBuilder.keep_center(false))
	var found := Vector2i(-1, -1)
	for radius in range(2, 14):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var cell := base + Vector2i(dx, dy)
				if build_system.can_place(cell, &"junxiefang"):
					found = cell
					break
			if found.x >= 0:
				break
		if found.x >= 0:
			break
	if found.x < 0:
		return {"ok": false, "reason": "no_legal_cell"}
	var node: Node2D = build_system.place(found, &"junxiefang", towers_layer)
	if node == null:
		return {"ok": false, "reason": "place_failed"}
	_select_object(node)
	return get_debug_snapshot()

## gda 调试钩子：立即开下一波（跳过倒计时）
func debug_next_wave() -> Dictionary:
	_rush_wave()
	return get_debug_snapshot()

func get_debug_snapshot() -> Dictionary:
	return {
		"ok": true,
		"lanes": lane_paths.size(),
		"buildings": build_system.get_occupied_count() if build_system != null else 0,
		"build_mode": build_mode,
		"selected": selected_object.name if selected_object != null else "",
		"sidebar_visible": _sidebar.visible if _sidebar != null else false,
		"enemies_alive": _alive_enemies(),
		"spawn": spawn_system.get_debug_snapshot() if spawn_system != null else {},
	}

func teleport_camera(x: float, y: float) -> void:
	if camera_rig != null and camera_rig.has_method("teleport"):
		camera_rig.call("teleport", x, y)
