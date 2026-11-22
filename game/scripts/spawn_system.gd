extends Node
class_name SpawnSystem
## 借鉴 RWX attack_point：敌人只在固定刷新点按波次生成，再沿 Path2D 向玩家城镇推进。
## 刷新点由 TileMapBuilder 从网格派生（地图右侧边缘，每条驿道一个）。

signal enemy_spawn_requested(type_id: StringName, lane: int, hp_scale: float, speed: float)
signal wave_started(index: int, count: int)

## 波次表（index 为 1-based）：数量 / 兵种池 / 生成间隔（秒）
const WAVE_TABLE: Array = [
	{"count": 6, "types": ["xiangyong", "gongshou"], "interval": 1.4},
	{"count": 10, "types": ["xiangyong", "gongshou", "longdeng"], "interval": 1.1},
	{"count": 14, "types": ["xiangyong", "gongshou", "longdeng"], "interval": 0.9},
]

var current_wave: int = 0
var spawned: int = 0
var _accum: float = 0.0
var _active: bool = false
var _points: Array[Dictionary] = []

# 新 class_name 全局缓存不可靠，统一用 preload 引用
const TileMapBuilder = preload("res://scripts/tile_map_builder.gd")


func setup() -> void:
	# 派生 3 个刷新点：每个 {"id": StringName, "lane": int, "cell": Vector2i, "world": Vector2}
	_points.clear()
	for lane in range(3):
		_points.append({
			"id": StringName("attack_point_%d" % lane),
			"lane": lane,
			"cell": TileMapBuilder.spawn_cell(lane),
			"world": TileMapBuilder.spawn_world(lane),
		})


func get_points() -> Array[Dictionary]:
	return _points


func reset() -> void:
	current_wave = 0
	spawned = 0
	_accum = 0.0
	_active = false


func begin_wave(index: int) -> void:
	# index 为 1-based；越界忽略
	if index < 1 or index > WAVE_TABLE.size():
		return
	current_wave = index
	spawned = 0
	_accum = 0.0
	_active = true
	wave_started.emit(index, int(WAVE_TABLE[index - 1]["count"]))


func tick(delta: float) -> void:
	# _active 时按 interval 累积并发射生成请求，数量满后自动停止
	if not _active:
		return
	var wave: Dictionary = WAVE_TABLE[current_wave - 1]
	var count: int = int(wave["count"])
	var interval: float = float(wave["interval"])
	var types: Array = wave["types"]
	_accum += delta
	while _accum >= interval and spawned < count:
		_accum -= interval
		var lane: int = spawned % 3
		var type_str: String = String(types[spawned % types.size()])
		var hp_scale: float = 1.0 + 0.25 * float(current_wave - 1)
		var speed: float = _speed_for(type_str)
		enemy_spawn_requested.emit(StringName(type_str), lane, hp_scale, speed)
		spawned += 1
	if spawned >= count:
		_active = false


func is_wave_finished() -> bool:
	return (not _active) and current_wave > 0


func wave_count(index: int) -> int:
	if index < 1 or index > WAVE_TABLE.size():
		return 0
	return int(WAVE_TABLE[index - 1]["count"])


func _speed_for(type_str: String) -> float:
	match type_str:
		"xiangyong":
			return 30.0
		"gongshou":
			return 45.0
		"longdeng":
			return 60.0
	return 30.0
