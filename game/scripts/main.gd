extends Node2D
## 主场景：玩家建塔守城、建兵迎敌；敌人只在刷新点按波次出现。
## 借鉴 RWX 的 attack_point 刷新点 + Mindustry 的多格建造（3x3 锚点占格）。

# 显式 preload：新建 class_name 的全局缓存不可靠
const TileMapBuilder = preload("res://scripts/tile_map_builder.gd")
const SpawnSystemScript = preload("res://scripts/spawn_system.gd")
const BuildSystemScript = preload("res://scripts/build_system.gd")

const UNIT_TYPES: Array[StringName] = [&"xiangyong", &"gongshou", &"longdeng"]
const UNIT_COSTS: Array[int] = [10, 16, 36]
const UNIT_HP: Array[int] = [120, 80, 150]
const UNIT_SPEED: Array[float] = [30.0, 45.0, 60.0]

const BUILD_TYPES: Array[StringName] = [&"jianta", &"junxiefang", &"fenghuotai"]
const BUILD_LABELS: Array[String] = ["箭塔(40银)", "军械坊(35银)", "烽火台(30银)"]

const PREPARE_SEC := 12.0
const INTER_WAVE_SEC := 8.0

# 战场视觉配色
const COL_INK := Color(0.75, 0.72, 0.62)
const COL_ROAD := Color(0.55, 0.46, 0.32)
const COL_OWN := Color(0.24, 0.42, 0.47)
const COL_ENEMY := Color(0.62, 0.28, 0.24)

@onready var lanes: Node2D = $Lanes
@onready var units_layer: Node2D = $Battle/Units
@onready var towers_layer: Node2D = $Battle/Towers
@onready var hud: CanvasLayer = $UI

var lane_paths: Array[Path2D] = []
var wave_timer: float = 0.0
var auto_mode: bool = true

var spawn_system: Node = null
var build_system: Node = null
var selected_build: int = 0
var _build_preview: Node2D = null
var map_result: Dictionary = {}
var camera_rig: Camera2D = null

var _workshop_bonus_accum: float = 0.0

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
	_build_hud()
	GameState.set_phase(GameState.Phase.PREPARE)
	EventBus.result_decided.connect(_on_result)
	print("[PREFLIGHT] scene=main started=true mode=defend")

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

func _make_label(parent: Node, p_name: String, pos: Vector2, text: String, color: Color, size: int, z: int) -> Label:
	var l := Label.new()
	l.name = p_name
	l.position = pos
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.z_index = z
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## 带半透明底的小铭牌：用于地图内少量必要标注，避免裸文字压在瓦片上难辨。
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

func _build_tilemap() -> void:
	map_result = TileMapBuilder.build(self)
	var buildings: Array = map_result["buildings"]
	print("[TILEMAP] cols=%d rows=%d tile=%d buildings=%d world=%s" % [
		map_result["cols"], map_result["rows"], map_result["tile"], buildings.size(),
		str(map_result["world_size"])])
	# 自由摄像机（RWX 式）：边缘滚动/拖拽/缩放，初始视角在己方主堡附近
	var rig := preload("res://scripts/camera_rig.gd").new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.setup(map_result["world_size"])
	var own_c: Vector2 = TileMapBuilder.keep_center(false)
	rig.position = own_c + Vector2(600.0, 640.0)  # 主堡 + 中央车道同框
	rig.reset_smoothing()
	camera_rig = rig

func _build_bases() -> void:
	var own_a := TileMapBuilder.keep_anchor(false)
	var enemy_a := TileMapBuilder.keep_anchor(true)
	var label_y := float((own_a.y + TileMapBuilder.KEEP_SIZE.y) * TileMapBuilder.TILE) + 8.0
	_make_nameplate(self, "OwnKeepLabel", Vector2(float(own_a.x * TileMapBuilder.TILE) - 6.0, label_y), "永昌城", COL_OWN, -14)
	_make_nameplate(self, "EnemyKeepLabel", Vector2(float(enemy_a.x * TileMapBuilder.TILE) - 6.0, label_y), "倭营", COL_ENEMY, -14)

func _build_lanes() -> void:
	for i in range(TileMapBuilder.LANE_ROWS.size()):
		var path := Path2D.new()
		path.name = "Lane_%d" % i
		var curve := Curve2D.new()
		var y := TileMapBuilder.lane_y(i)
		# 从己方主堡出口到敌方刷新点（大地图端点按瓦片网格派生）
		var x_start := float(4 * TileMapBuilder.TILE)
		var x_end := float(TileMapBuilder.SPAWN_COL * TileMapBuilder.TILE)
		curve.add_point(Vector2(x_start, y))
		curve.add_point(Vector2(x_end, y))
		path.curve = curve
		lanes.add_child(path)
		lane_paths.append(path)
		print("[LANE] path=lane_%d row=%d y=%.0f x=%.0f..%.0f" % [
			i, TileMapBuilder.LANE_ROWS[i], y, x_start, x_end])

func _setup_systems() -> void:
	spawn_system = SpawnSystemScript.new()
	spawn_system.name = "SpawnSystem"
	add_child(spawn_system)
	spawn_system.setup()
	spawn_system.enemy_spawn_requested.connect(_on_enemy_spawn_requested)
	spawn_system.wave_started.connect(_on_wave_started)

	build_system = BuildSystemScript.new()
	build_system.name = "BuildSystem"
	add_child(build_system)
	build_system.blocked = map_result.get("blocked", {})
	build_system.building_placed.connect(_on_building_placed)
	build_system.build_failed.connect(_on_build_failed)

	# 刷新点标注依赖 spawn_system，需在系统建立后补建
	_build_spawn_marks()

func _build_spawn_marks() -> void:
	for p in spawn_system.get_points():
		var w: Vector2 = p["world"]
		var mark := _make_rect(self, "SpawnMark_%s" % str(p["id"]),
			w - Vector2(10, 10), Vector2(20, 20), COL_ENEMY, -8)
		mark.modulate.a = 0.35
		_make_nameplate(self, "SpawnLabel_%s" % str(p["id"]),
			w + Vector2(14, -14), "敌", COL_ENEMY, -7)

func _build_hud() -> void:
	set_process(true)
	# HUD 按钮 → 游戏逻辑（解耦，HUD 不直接调用 main）
	if hud != null:
		hud.build_selected.connect(_select_build)
		hud.unit_spawn_requested.connect(_on_unit_requested)
	hud.set_selected_build(selected_build)
	_add_minimap()

## 右上角小地图（RWX Minimap 式：缩略底图 + 单位点 + 视口框 + 点击跳转）
func _add_minimap() -> void:
	if map_result.is_empty() or camera_rig == null:
		return
	var mini := preload("res://scripts/minimap.gd").new()
	mini.name = "MiniMap"
	mini.setup(map_result, units_layer, camera_rig)
	mini.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mini.anchor_left = 1.0
	mini.anchor_right = 1.0
	mini.offset_left = -222.0
	mini.offset_right = -12.0
	mini.offset_top = 68.0
	mini.offset_bottom = 226.0
	hud.add_child(mini)
	# RWX BuildPreview 式建造占格预览
	var preview := preload("res://scripts/build_preview.gd").new() as Node2D
	preview.name = "BuildPreview"
	preview.set("main_ref", self)
	preview.z_index = 15
	add_child(preview)

func _on_unit_requested(index: int) -> void:
	spawn_player_unit(index)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1: spawn_player_unit(0)
			KEY_2: spawn_player_unit(1)
			KEY_3: spawn_player_unit(2)
			KEY_Q: _select_build((selected_build - 1 + BUILD_TYPES.size()) % BUILD_TYPES.size())
			KEY_E: _select_build((selected_build + 1) % BUILD_TYPES.size())
			KEY_SPACE: _skip_prepare()
			KEY_R: GameFlow.restart_battle()
			KEY_ESCAPE: _toggle_pause()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		_try_build_at(get_global_mouse_position(), mb.position)

func _select_build(index: int) -> void:
	selected_build = index
	if hud != null:
		hud.set_selected_build(index)

func _skip_prepare() -> void:
	if GameState.phase == GameState.Phase.PREPARE:
		wave_timer = PREPARE_SEC

func _toggle_pause() -> void:
	if hud != null and hud.has_method("toggle_pause"):
		hud.toggle_pause(not hud.is_paused())

func _try_build_at(world_pos: Vector2, _screen_pos: Vector2) -> void:
	if build_system == null: return
	if GameState.phase == GameState.Phase.VICTORY or GameState.phase == GameState.Phase.DEFEAT:
		return
	var anchor: Vector2i = build_system.world_to_cell(world_pos)
	build_system.place(anchor, BUILD_TYPES[selected_build], towers_layer)

func _on_building_placed(kind: StringName, cell: Vector2i, node: Node2D) -> void:
	print("[BUILD] kind=%s anchor=%s pos=%s occupied=%d" % [
		kind, cell, node.position, build_system.get_occupied_count()])
	if kind == &"jianta":
		# 塔按最近驿道绑定 lane，便于索敌朝向提示
		var lane := _nearest_lane(node.position.y)
		node.set("lane_index", lane)

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

func spawn_player_unit(type_index: int) -> void:
	if GameState.phase == GameState.Phase.VICTORY or GameState.phase == GameState.Phase.DEFEAT:
		return
	if type_index < 0 or type_index >= UNIT_TYPES.size(): return
	var cost: int = UNIT_COSTS[type_index]
	if GameState.silver < cost:
		GameState.last_error = "silver_not_enough"
		return
	GameState.add_silver(-cost)
	var lane: int = randi() % lane_paths.size()
	var type_id: StringName = UNIT_TYPES[type_index]
	var scene := load("res://scenes/unit.tscn") as PackedScene
	var unit := scene.instantiate() as Unit
	# 玩家兵从城镇端（路径起点）向右推进，迎击从右侧刷新点来的敌人
	unit.setup(type_id, lane, UNIT_HP[type_index], UNIT_SPEED[type_index], false, 1.0)
	lane_paths[lane].add_child(unit)
	EventBus.unit_spawned.emit(type_id, lane)
	print("[PLAYER] spawn type=%s lane=%d cost=%d silver=%d" % [type_id, lane, cost, GameState.silver])

func _on_enemy_spawn_requested(type_id: StringName, lane: int, hp_scale: float, speed: float) -> void:
	if lane < 0 or lane >= lane_paths.size(): return
	var scene := load("res://scenes/unit.tscn") as PackedScene
	var unit := scene.instantiate() as Unit
	var hp: int = int(120.0 * hp_scale)
	# 敌人从刷新点（路径末端）向左推进，直取永昌城
	unit.setup(type_id, lane, hp, speed, true, -1.0)
	lane_paths[lane].add_child(unit)
	var p := TileMapBuilder.spawn_world(lane)
	print("[ENEMY] spawn type=%s lane=%d hp=%d from=%s dir=-1" % [type_id, lane, hp, p])

func _on_wave_started(index: int, count: int) -> void:
	GameState.wave_index = index
	GameState.set_phase(GameState.Phase.BATTLE)
	EventBus.wave_started.emit(index, count)
	print("[WAVE] index=%d/%d count=%d" % [index, GameState.TOTAL_WAVES, count])
	if index == 2:
		EventBus.culture_event.emit(&"kangwo", "抗倭：三路坚守，全军伤害提升")
		print("[CULTURE] card=kangwo effect=damage+20%%")

func _process(delta: float) -> void:
	if GameState.phase == GameState.Phase.VICTORY or GameState.phase == GameState.Phase.DEFEAT:
		return
	GameState.time_sec += delta
	SupplySystem.produce(delta)
	_tick_workshop(delta)
	_update_hud()
	_tick_waves(delta)
	if GameState.time_sec >= GameState.TIME_LIMIT_SEC and GameState.phase != GameState.Phase.VICTORY:
		# 防守玩法：撑到时限且城镇未破即胜
		if GameState.keep_hp > 0:
			GameState.decide(true, "time_survived")

func _tick_workshop(delta: float) -> void:
	# 军械坊增益：每座每 5 秒额外补给 4 发弹药
	var workshops := _count_building(&"junxiefang")
	if workshops <= 0: return
	_workshop_bonus_accum += delta
	if _workshop_bonus_accum >= 5.0:
		_workshop_bonus_accum -= 5.0
		SupplySystem.ammo_stock += 4 * workshops

func _count_building(kind: StringName) -> int:
	if build_system == null: return 0
	var n := 0
	for v in build_system.occupied.values():
		if str(v) == str(kind): n += 1
	return n

func _tick_waves(delta: float) -> void:
	if spawn_system == null: return
	match GameState.phase:
		GameState.Phase.PREPARE:
			wave_timer += delta
			if wave_timer >= PREPARE_SEC:
				wave_timer = 0.0
				var next := GameState.wave_index + 1
				if next > GameState.TOTAL_WAVES:
					GameState.decide(true, "all_waves_cleared")
				else:
					spawn_system.begin_wave(next)
			return
		GameState.Phase.BATTLE:
			spawn_system.tick(delta)
			if spawn_system.is_wave_finished() and _alive_enemies() == 0:
				if GameState.wave_index >= GameState.TOTAL_WAVES:
					GameState.decide(true, "all_waves_cleared")
				else:
					GameState.set_phase(GameState.Phase.PREPARE)
					wave_timer = 0.0
					print("[WAVE] cleared=%d -> prepare next" % GameState.wave_index)
			return
		_:
			return

func _alive_enemies() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("units"):
		var u := node as Unit
		if u != null and u.is_enemy and not u.is_dead: n += 1
	return n

func _update_hud() -> void:
	hud.update_stats(GameState.grain, GameState.silver, SupplySystem.ammo_stock,
		GameState.keep_hp, GameState.wave_index)

func _on_result(_victory: bool, _reason: String) -> void:
	pass
