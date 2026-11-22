extends Node2D
## 主场景：布路、建塔、波次推进、文化事件、自动验证快照。

const LANE_Y := [220.0, 360.0, 500.0]
const LANE_X_START := 60.0
const LANE_X_END := 1220.0
const TOWER_X := [420.0, 700.0, 980.0]
const UNIT_TYPES := ["xiangyong", "gongshou", "longdeng"]
const WAVE_COUNTS := [6, 10, 14]

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
	_build_lanes()
	_build_towers()
	_build_hud()
	GameState.set_phase(GameState.Phase.PREPARE)
	print("[PREFLIGHT] scene=main started=true")
	EventBus.result_decided.connect(_on_result)

func _build_lanes() -> void:
	for i in range(3):
		var path := Path2D.new()
		path.name = "Lane_%d" % i
		var curve := Curve2D.new()
		curve.add_point(Vector2(LANE_X_START, LANE_Y[i]))
		curve.add_point(Vector2(380.0, LANE_Y[i] - 18.0))
		curve.add_point(Vector2(700.0, LANE_Y[i] + 16.0))
		curve.add_point(Vector2(1000.0, LANE_Y[i] - 12.0))
		curve.add_point(Vector2(LANE_X_END, LANE_Y[i]))
		path.curve = curve
		lanes.add_child(path)
		lane_paths.append(path)
		print("[LANE] path=lane_%d points=5 ready=true" % i)

func _build_towers() -> void:
	var scene := load("res://scenes/tower_node.tscn") as PackedScene
	for i in range(3):
		var t := scene.instantiate() as Node2D
		t.position = Vector2(TOWER_X[i], LANE_Y[i] - 44.0)
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
