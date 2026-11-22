extends Node2D
## 主场景：布路、建塔、波次推进、文化事件、自动验证快照。

# 显式 preload，避免新建 class_name 的全局缓存尚未刷新
const TileMapBuilder = preload("res://scripts/tile_map_builder.gd")

# 路径几何已迁移到 TileMapBuilder（瓦片网格派生），不再硬编码像素坐标
const UNIT_TYPES := ["xiangyong", "gongshou", "longdeng"]
const WAVE_COUNTS := [6, 10, 14]

# 战场视觉配色（国风：宣纸地、墨线、朱砂/青黛阵营色）
const COL_SKY_TOP := Color(0.09, 0.13, 0.18)
const COL_SKY_BOT := Color(0.16, 0.22, 0.27)
const COL_GROUND := Color(0.20, 0.21, 0.17)
const COL_ROAD := Color(0.55, 0.46, 0.32)
const COL_ROAD_EDGE := Color(0.35, 0.30, 0.21)
const COL_OWN := Color(0.24, 0.42, 0.47)
const COL_ENEMY := Color(0.52, 0.22, 0.20)
const COL_INK := Color(0.75, 0.72, 0.62)

@onready var lanes: Node2D = $Lanes
@onready var units_layer: Node2D = $Battle/Units
@onready var towers_layer: Node2D = $Battle/Towers
@onready var hud: CanvasLayer = $UI

var lane_paths: Array[Path2D] = []
var wave_timer: float = 0.0
var spawn_accum: float = 0.0
var spawned_this_wave: int = 0
var auto_mode: bool = true

func _ready() -> void:
	randomize()
	GameState.reset_level()
	SupplySystem.reset()
	DataDB.load_all()
	ResourceManager.preload_level("lv_01")
	_build_tilemap()
	_build_lanes()
	_build_bases()
	_build_towers()
	_build_hud()
	GameState.set_phase(GameState.Phase.PREPARE)
	print("[PREFLIGHT] scene=main started=true")
	EventBus.result_decided.connect(_on_result)

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
	# Mindustry 式分层瓦片地图：floor / overlay / build / decor 四层 TileMapLayer
	var layers := TileMapBuilder.build(self)
	print("[TILEMAP] layers=%d cols=%d rows=%d tile=%d" % [
		layers.size() - 3, layers["cols"], layers["rows"], layers["tile"]])
	# 标题叠在瓦片之上（z=-9，仍在单位/塔之下）
	_make_label(self, "Banner", Vector2(40, 28), "守望 · 永昌", COL_INK, 40, -9)
	_make_label(self, "Subtitle", Vector2(42, 76), "三路驿道 · 烽火传薪 · 众志成城", COL_ROAD, 20, -9)

func _build_bases() -> void:
	# 城门已由瓦片层（T_FOUNDATION）绘出；此处只叠加阵营色标与文字。
	var y := TileMapBuilder.lane_y(1)
	_make_rect(self, "OwnKeep", Vector2(2, y - 96), Vector2(14, 192), COL_OWN, -15)
	_make_rect(self, "EnemyKeep", Vector2(1264, y - 96), Vector2(14, 192), COL_ENEMY, -15)
	_make_label(self, "OwnKeepLabel", Vector2(2, y + 100), "永昌", COL_INK, 22, -14)
	_make_label(self, "EnemyKeepLabel", Vector2(1220, y + 100), "倭营", COL_INK, 22, -14)

func _build_lanes() -> void:
	# 路径点从瓦片网格派生：直线沿道路行中心，起点/终点在城门格。
	# Path2D 仅作 PathFollow2D 的运动骨架，视觉完全由 TileMapLayer 承担。
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

func _build_towers() -> void:
	var scene := load("res://scenes/tower_node.tscn") as PackedScene
	for i in range(TileMapBuilder.TOWER_COLS.size()):
		var t := scene.instantiate() as Node2D
		# 塔基瓦片在 (TOWER_COLS[i], LANE_ROWS[i]-1)，塔精灵落在道路行中心上方半格
		t.position = Vector2(TileMapBuilder.tower_x(i), TileMapBuilder.lane_y(i) - 24.0)
		t.set("lane_index", i)
		towers_layer.add_child(t)

func _build_hud() -> void:
	set_process(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1: spawn_player_unit(0)
			KEY_2: spawn_player_unit(1)
			KEY_3: spawn_player_unit(2)
			KEY_R: get_tree().reload_current_scene()

func spawn_player_unit(type_index: int) -> void:
	if GameState.phase == GameState.Phase.VICTORY or GameState.phase == GameState.Phase.DEFEAT:
		return
	if type_index < 0 or type_index >= UNIT_TYPES.size():
		return
	var costs: Array[int] = [10, 16, 36]
	var cost: int = costs[type_index]
	if GameState.silver < cost:
		GameState.last_error = "silver_not_enough"
		return
	GameState.add_silver(-cost)
	var lane: int = randi() % 3
	var type_id: String = UNIT_TYPES[type_index]
	var hp_list: Array[int] = [120, 80, 150]
	var speed_list: Array[float] = [30.0, 45.0, 60.0]
	var hp: int = hp_list[type_index]
	var speed: float = speed_list[type_index]
	var scene := load("res://scenes/unit.tscn") as PackedScene
	var unit := scene.instantiate() as Unit
	unit.setup(StringName(type_id), lane, hp, speed, false)
	lane_paths[lane].add_child(unit)
	EventBus.unit_spawned.emit(StringName(type_id), lane)
	print("[PLAYER] spawn type=%s lane=%d cost=%d silver=%d" % [type_id, lane, cost, GameState.silver])

func _process(delta: float) -> void:
	if GameState.phase == GameState.Phase.VICTORY or GameState.phase == GameState.Phase.DEFEAT:
		return
	GameState.time_sec += delta
	SupplySystem.produce(delta)
	_update_hud()
	_tick_waves(delta)
	if GameState.time_sec >= GameState.TIME_LIMIT_SEC:
		var win := GameState.enemy_keep_hp > GameState.keep_hp
		GameState.decide(win, "time_limit")

func _tick_waves(delta: float) -> void:
	if GameState.phase == GameState.Phase.PREPARE:
		wave_timer += delta
		if wave_timer >= 12.0:
			_start_wave(1)
		return
	if GameState.phase != GameState.Phase.BATTLE:
		return
	spawn_accum += delta
	if spawn_accum >= 1.4 and spawned_this_wave < WAVE_COUNTS[GameState.wave_index - 1]:
		spawn_accum = 0.0
		_spawn_enemy()
		return
	if spawned_this_wave >= WAVE_COUNTS[GameState.wave_index - 1]:
		spawn_accum += delta
		if spawn_accum >= 18.0:
			if GameState.wave_index >= GameState.TOTAL_WAVES:
				var win := GameState.keep_hp > GameState.enemy_keep_hp
				GameState.decide(win, "all_waves_cleared")
			else:
				_start_wave(GameState.wave_index + 1)

func _start_wave(index: int) -> void:
	GameState.wave_index = index
	GameState.set_phase(GameState.Phase.BATTLE)
	spawned_this_wave = 0
	spawn_accum = 0.0
	EventBus.wave_started.emit(index, WAVE_COUNTS[index - 1])
	print("[WAVE] index=%d/%d spawned=%d" % [index, GameState.TOTAL_WAVES, WAVE_COUNTS[index - 1]])
	if index == 2:
		EventBus.culture_event.emit(&"kangwo", "抗倭：三路坚守，全军伤害提升")
		print("[CULTURE] card=kangwo effect=damage+20%%")

func _spawn_enemy() -> void:
	var lane: int = spawned_this_wave % 3
	var type_id: String = UNIT_TYPES[(spawned_this_wave / 3) % UNIT_TYPES.size()]
	var hp_scale := 1.0 + 0.25 * float(GameState.wave_index - 1)
	var hp := int(120 * hp_scale)
	var speed := 30.0
	match type_id:
		"gongshou": speed = 45.0
		"longdeng": speed = 60.0
	var scene := load("res://scenes/unit.tscn") as PackedScene
	var unit := scene.instantiate() as Unit
	unit.setup(StringName(type_id), lane, hp, speed, true)
	lane_paths[lane].add_child(unit)
	spawned_this_wave += 1

func _update_hud() -> void:
	hud.update_stats(GameState.grain, GameState.silver, SupplySystem.ammo_stock,
		GameState.keep_hp, GameState.wave_index)

func _on_result(_victory: bool, _reason: String) -> void:
	pass
