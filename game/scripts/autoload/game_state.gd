extends Node
## 关卡状态：资源、阶段、波次、主堡血量、终局判定与调试快照。

enum Phase { PREPARE, BATTLE, VICTORY, DEFEAT }

const START_GRAIN := 200
const START_SILVER := 120
const START_AMMO := 60
const KEEP_HP := 1000
const ENEMY_KEEP_HP := 1000
const TOTAL_WAVES := 3
const TIME_LIMIT_SEC := 480.0

var phase: Phase = Phase.PREPARE
var grain: int = START_GRAIN
var silver: int = START_SILVER
var ammo: int = START_AMMO
var keep_hp: int = KEEP_HP
var enemy_keep_hp: int = ENEMY_KEEP_HP
var wave_index: int = 0
var time_sec: float = 0.0
var kills: int = 0
var last_error: String = ""
var result: String = ""
var seed_value: int = 20261122

func reset_level(_level_id: String = "lv_01") -> void:
	phase = Phase.PREPARE
	grain = START_GRAIN
	silver = START_SILVER
	ammo = START_AMMO
	keep_hp = KEEP_HP
	enemy_keep_hp = ENEMY_KEEP_HP
	wave_index = 0
	time_sec = 0.0
	kills = 0
	last_error = ""
	result = ""
	print("[STATE] grain=%d silver=%d ammo=%d keep_hp=%d" % [grain, silver, ammo, keep_hp])

func set_phase(p: Phase) -> void:
	phase = p

func add_silver(v: int) -> void:
	silver = maxi(0, silver + v)

func add_grain(v: int) -> void:
	grain = maxi(0, grain + v)

func damage_enemy_keep(v: int) -> void:
	enemy_keep_hp = maxi(0, enemy_keep_hp - v)
	if enemy_keep_hp <= 0 and phase != Phase.DEFEAT:
		decide(true, "enemy_keep_destroyed")

func damage_own_keep(v: int) -> void:
	keep_hp = maxi(0, keep_hp - v)
	EventBus.base_hit.emit(v, keep_hp)
	print("[KEEP] hit=%d hp=%d" % [v, keep_hp])
	if keep_hp <= 0 and phase != Phase.VICTORY:
		decide(false, "own_keep_destroyed")

func decide(victory: bool, reason: String) -> void:
	if phase == Phase.VICTORY or phase == Phase.DEFEAT:
		return
	phase = Phase.VICTORY if victory else Phase.DEFEAT
	result = "victory" if victory else "defeat"
	EventBus.result_decided.emit(victory, reason)
	print("[RESULT] victory=%s reason=%s" % [str(victory).to_lower(), reason])

const GDA_CALLABLE := ["get_debug_snapshot"]

func get_debug_snapshot() -> Dictionary:
	return {
		"ok": true,
		"scene": "main",
		"phase": Phase.keys()[phase],
		"wave": wave_index,
		"time_sec": snappedf(time_sec, 0.1),
		"grain": grain,
		"silver": silver,
		"ammo": ammo,
		"keep_hp": keep_hp,
		"enemy_keep_hp": enemy_keep_hp,
		"kills": kills,
		"result": result,
		"last_error": last_error,
		"towers": 3,
		"data_counts": {"units": DataDB.units.size(), "towers": DataDB.towers.size()},
	}
