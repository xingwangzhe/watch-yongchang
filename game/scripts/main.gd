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

func _build_tilemap() -> void:
	var layers := TileMapBuilder.build(self)
	var buildings: Array = layers["buildings"]
	print("[TILEMAP] cols=%d rows=%d tile=%d buildings=%d" % [
		layers["cols"], layers["rows"], layers["tile"], buildings.size()])
	_make_label(self, "Banner", Vector2(30, 24), "守望 · 永昌", COL_INK, 36, -9)
	_make_label(self, "Subtitle", Vector2(32, 68), "建造布防 · 烽火传薪 · 众志成城", COL_ROAD, 18, -9)

func _build_bases() -> void:
	var own_a := TileMapBuilder.keep_anchor(false)
	var enemy_a := TileMapBuilder.keep_anchor(true)
	var label_y := float((own_a.y + TileMapBuilder.KEEP_SIZE.y) * TileMapBuilder.TILE) + 6.0
	_make_label(self, "OwnKeepLabel", Vector2(float(own_a.x * TileMapBuilder.TILE) - 4.0, label_y), "永昌城", COL_OWN, 22, -14)
	_make_label(self, "EnemyKeepLabel", Vector2(float(enemy_a.x * TileMapBuilder.TILE) - 4.0, label_y), "倭营", COL_ENEMY, 22, -14)

func _build_lanes() -> void:
	for i in range(TileMapBuilder.LANE_ROWS.size()):
		var path := Path2D.new()
		path.name = "Lane_%d" % i
		var curve := Curve2D.new()
		var y := TileMapBuilder.lane_y(i)
		curve.add_point(Vector2(0.0, y))
		curve.add_point(Vector2(1280.0, y))
		path.curve = curve
		lanes.add_child(path)
		lane_paths.append(path)
		print("[LANE] path=lane_%d row=%d y=%.0f derived_from_tilegrid=true" % [
			i, TileMapBuilder.LANE_ROWS[i], y])

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
	build_system.building_placed.connect(_on_building_placed)
	build_system.build_failed.connect(_on_build_failed)

	# 刷新点标注依赖 spawn_system，需在系统建立后补建
	_build_spawn_marks()

func _build_spawn_marks() -> void:
	for p in spawn_system.get_points():
		var w: Vector2 = p["world"]
		var mark := _make_rect(self, "SpawnMark_%s" % str(p["id"]),
			w - Vector2(10, 10), Vector2(20, 20), COL_ENEMY, -8)
		mark.modulate.a = 0.45
		_make_label(self, "SpawnLabel_%s" % str(p["id"]),
			w + Vector2(14, -12), "刷新点", COL_ENEMY, 14, -7)

func _build_hud() -> void:
	set_process(true)
	_make_label(self, "BuildHint", Vector2(24, 636), "", COL_INK, 16, 30)
	_update_build_hint()

func _update_build_hint() -> void:
	var node := get_node_or_null("BuildHint") as Label
	if node == null: return
	node.text = "建造[Q/E切换]: %s  |  鼠标左键放置  |  1/2/3出兵  |  空格提前开波  |  R重开" % BUILD_LABELS[selected_build]

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
	_update_build_hint()

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
