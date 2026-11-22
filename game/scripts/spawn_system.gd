extends Node
class_name SpawnSystem
## 定时出兵系统（Mindustry 式持续波次）。
##
## 与「米拉奇战记」式的三波对推不同：敌人不是一次性刷完就等你清场，
## 而是**永远有下一波在倒计时**——每波按固定间隔（WAVE_INTERVAL）到来，
## 波内再按 SPAWN_SPACING 逐个放出，强度随波次单调上升。
##
## 参考 Mindustry 的 WaveSpawner 设计要点（只借鉴思路，未复制代码）：
## 1. 两个计时器：波间隔（waveInterval）与波内间隔（waveSpacing）；
## 2. 波次难度曲线由波号推导（数量、血量、速度、兵种池逐步解锁）；
## 3. 场上单位数设上限，达到上限时本波顺延到下一波，避免爆量卡顿；
## 4. 开局有准备期（prepare），让玩家先布防再迎敌。
##
## 刷新点由 TileMapBuilder 从网格派生（三门各一处），ladder 轮转分配。

signal enemy_spawn_requested(type_id: StringName, lane: int, hp_scale: float, speed: float)
signal wave_started(index: int, count: int)
signal wave_countdown_changed(seconds_left: float)

## 开局准备时间：够玩家看清地形、放下第一座塔
const PREPARE_SEC: float = 20.0
## 波与波之间的间隔（秒）——这是「定时出敌兵」的主节拍
const WAVE_INTERVAL: float = 26.0
## 波内单个单位的放出间隔（秒）
const SPAWN_SPACING: float = 0.8
## 单波数量上限，防止后期数量爆炸
const MAX_PER_WAVE: int = 26
## 场上存活敌人上限（达到后本波截断，剩余顺延）
const MAX_ALIVE: int = 120

## 基础血量基准（各兵种按 BASE_HP 的比例放大）
const BASE_HP: int = 120

const TYPE_SPEED: Dictionary = {
	&"xiangyong": 38.0,
	&"gongshou": 56.0,
	&"longdeng": 74.0,
}

# 新 class_name 全局缓存不可靠，统一用 preload 引用
const TileMapBuilder = preload("res://scripts/tile_map_builder.gd")

var wave: int = 0                 # 已完成/进行中的波号（1-based）
var countdown: float = PREPARE_SEC  # 距离下一波开始的秒数
var is_spawning: bool = false     # 当前是否处于「波内逐个放出」阶段
var spawned_in_wave: int = 0
var total_spawned: int = 0

var _queue: Array[StringName] = []
var _queue_lane: Array[int] = []
var _spacing_timer: float = 0.0
var _active: bool = false
var _points: Array[Dictionary] = []
var _last_countdown_emit: float = -1.0

func setup() -> void:
	# 派生刷新点：每个 {"id": StringName, "lane": int, "cell": Vector2i, "world": Vector2}
	_points.clear()
	for lane in range(TileMapBuilder.LANE_ROWS.size()):
		_points.append({
			"id": StringName("attack_point_%d" % lane),
			"lane": lane,
			"cell": TileMapBuilder.spawn_cell(lane),
			"world": TileMapBuilder.spawn_world(lane),
		})

func get_points() -> Array[Dictionary]:
	return _points

func reset() -> void:
	wave = 0
	countdown = PREPARE_SEC
	is_spawning = false
	spawned_in_wave = 0
	total_spawned = 0
	_queue.clear()
	_queue_lane.clear()
	_spacing_timer = 0.0
	_active = false
	_last_countdown_emit = -1.0
	wave_countdown_changed.emit(countdown)

## 主循环：非出兵阶段走倒计时，出兵阶段按间隔放人
func tick(delta: float, alive_enemies: int = 0) -> void:
	if _active:
		_tick_spawn(delta, alive_enemies)
		return
	countdown -= delta
	_emit_countdown(delta)
	if countdown <= 0.0:
		begin_wave(wave + 1)

## 立即开始下一波（玩家点「提前迎敌」或准备期结束）
func begin_wave(index: int) -> void:
	wave = index
	is_spawning = true
	_active = true
	spawned_in_wave = 0
	_spacing_timer = 0.0
	_queue = _composition(index)
	_queue_lane = _lane_plan(index, _queue.size())
	var count: int = _queue.size()
	wave_started.emit(index, count)
	print("[WAVE] begin index=%d count=%d hp_scale=%.2f" % [index, count, hp_scale_for(index)])

## 跳过当前倒计时
func rush_next_wave() -> void:
	if not _active:
		countdown = 0.0

func is_wave_finished() -> bool:
	return not _active

func next_wave_in() -> float:
	return maxf(0.0, countdown)

## 距下一波剩余秒数（供 HUD 显示）
func countdown_text() -> String:
	var t: float = maxf(0.0, countdown)
	return "%d:%02d" % [int(t) / 60, int(t) % 60]

# ---------- 难度曲线 ----------

## 波号 → 血量倍率：每波 +15%，第 10 波约 2.35×
func hp_scale_for(index: int) -> float:
	return 1.0 + 0.15 * float(maxi(0, index - 1))

## 波号 → 速度倍率：缓慢上升，避免后期追不上
func speed_scale_for(index: int) -> float:
	return 1.0 + 0.015 * float(maxi(0, index - 1))

## 波号 → 该波兵种池（逐步解锁，形成压力梯度）
func _composition(index: int) -> Array[StringName]:
	var count: int = mini(4 + index * 2, MAX_PER_WAVE)
	var pool: Array[StringName] = [&"xiangyong"]
	if index >= 2:
		pool.append(&"gongshou")
	if index >= 3:
		pool.append(&"longdeng")
	# 兵种按确定性的比例混编：越往后越倾向高威胁兵种
	var out: Array[StringName] = []
	for i in range(count):
		if index >= 3 and i % 5 == 4:
			out.append(&"longdeng")
		elif index >= 2 and i % 3 == 2:
			out.append(&"gongshou")
		else:
			out.append(pool[i % pool.size()])
	return out

## 三门轮转，保证三条驿道压力均衡
func _lane_plan(index: int, count: int) -> Array[int]:
	var lanes: int = TileMapBuilder.LANE_ROWS.size()
	var out: Array[int] = []
	for i in range(count):
		out.append((i + index) % lanes)
	return out

# ---------- 波内放出 ----------

func _tick_spawn(delta: float, alive_enemies: int) -> void:
	_spacing_timer += delta
	while _spacing_timer >= SPAWN_SPACING and not _queue.is_empty():
		_spacing_timer -= SPAWN_SPACING
		if alive_enemies + spawned_in_wave >= MAX_ALIVE:
			# 场上太满：本波截断，剩余不补发（下一波会更强）
			print("[WAVE] capped alive=%d truncated=%d" % [alive_enemies, _queue.size()])
			_queue.clear()
			break
		var type_id: StringName = _queue.pop_front()
		var lane: int = _queue_lane.pop_front() if not _queue_lane.is_empty() else 0
		var hp_scale: float = hp_scale_for(wave)
		var speed: float = float(TYPE_SPEED.get(type_id, 38.0)) * speed_scale_for(wave)
		enemy_spawn_requested.emit(type_id, lane, hp_scale, speed)
		spawned_in_wave += 1
		total_spawned += 1
	if _queue.is_empty():
		_active = false
		is_spawning = false
		countdown = WAVE_INTERVAL
		_emit_countdown(1.0)
		print("[WAVE] dispatched index=%d total=%d next_in=%.0fs" % [wave, total_spawned, WAVE_INTERVAL])

func _emit_countdown(delta: float) -> void:
	# 每 0.25 秒或跨整秒时发一次，够 HUD 刷新又不刷爆信号
	if absf(countdown - _last_countdown_emit) >= 0.25 or delta >= 1.0:
		_last_countdown_emit = countdown
		wave_countdown_changed.emit(maxf(0.0, countdown))

func get_debug_snapshot() -> Dictionary:
	return {
		"wave": wave,
		"countdown": snappedf(countdown, 0.1),
		"is_spawning": is_spawning,
		"queued": _queue.size(),
		"spawned_in_wave": spawned_in_wave,
		"total_spawned": total_spawned,
	}

const GDA_CALLABLE := ["get_debug_snapshot"]
