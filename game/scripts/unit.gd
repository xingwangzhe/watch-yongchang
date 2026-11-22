extends PathFollow2D
class_name Unit
## 沿 Path2D 行进的单位：移动、动画、受击、死亡。

signal died(unit: Unit)

@export var type_id: StringName = &"xiangyong"
@export var max_hp: int = 120
@export var speed: float = 40.0
@export var lane_index: int = 0
@export var is_enemy: bool = false
# 行进方向：1.0 左→右（玩家兵），-1.0 右→左（敌方兵，从右侧刷新点进入）
@export var direction: float = 1.0

@onready var sprite: AnimatedSprite2D = $Sprite

var hp: int = 0
var is_dead: bool = false

# 交战规则：近距离索敌 → 停止行进 → 攻击硬直 → 继续推进（塔防/RTS 通用）
const DMG_TABLE: Dictionary = {"xiangyong": 15, "gongshou": 10, "longdeng": 25}
const RANGE_TABLE: Dictionary = {"xiangyong": 42.0, "gongshou": 138.0, "longdeng": 55.0}
const ATK_INTERVAL_TABLE: Dictionary = {"xiangyong": 0.9, "gongshou": 1.1, "longdeng": 1.3}

var _atk_cd: float = 0.0

func setup(p_type: StringName, p_lane: int, p_hp: int, p_speed: float, p_enemy: bool, p_direction: float = 1.0) -> void:
	type_id = p_type
	lane_index = p_lane
	max_hp = p_hp
	hp = p_hp
	speed = p_speed
	is_enemy = p_enemy
	direction = p_direction

func _ready() -> void:
	loop = false
	rotates = false
	progress = 0.0
	# 敌方单位从路径末端（右侧）出发，需把 progress 置于末端
	if direction < 0.0:
		var path := get_parent() as Path2D
		if path != null and path.curve != null:
			progress = path.curve.get_baked_length()
		else:
			# 父节点异常时兜底：直接把行进比例拉到末端
			progress_ratio = 1.0
	if hp <= 0: hp = max_hp
	sprite.sprite_frames = ResourceManager.get_frames(str(type_id))
	sprite.modulate = Color(1.0, 0.68, 0.68) if is_enemy else Color(0.78, 0.95, 1.0)
	sprite.play("run")
	add_to_group("units")
	print("[UNIT] spawn type=%s lane=%d hp=%d" % [type_id, lane_index, hp])

func _physics_process(delta: float) -> void:
	if is_dead or GameState.phase == GameState.Phase.VICTORY or GameState.phase == GameState.Phase.DEFEAT:
		return
	# 攻击硬直中：站定不移动
	if _atk_cd > 0.0:
		_atk_cd -= delta
		return
	var target := _find_enemy_in_range()
	if target != null:
		_attack(target)
		_atk_cd = float(ATK_INTERVAL_TABLE.get(str(type_id), 1.0))
		return
	progress += speed * delta * direction
	if direction > 0.0 and progress_ratio >= 1.0:
		_reach_base()
	elif direction < 0.0 and progress_ratio <= 0.0:
		_reach_base()

func _find_enemy_in_range() -> Unit:
	var rng: float = float(RANGE_TABLE.get(str(type_id), 42.0))
	var best: Unit = null
	var best_d := rng
	for node in get_tree().get_nodes_in_group("units"):
		var u := node as Unit
		if u == null or u.is_dead or u.is_enemy == is_enemy:
			continue
		var d: float = global_position.distance_to(u.global_position)
		if d <= best_d:
			best_d = d
			best = u
	return best

func _attack(target: Unit) -> void:
	var dmg: int = int(DMG_TABLE.get(str(type_id), 10))
	play_attack()
	target.take_damage(dmg)

func play_attack() -> void:
	if is_dead: return
	sprite.play("attack")
	if not sprite.animation_finished.is_connected(_on_attack_done):
		sprite.animation_finished.connect(_on_attack_done, CONNECT_ONE_SHOT)

func _on_attack_done() -> void:
	if not is_dead: sprite.play("run")

func take_damage(amount: int) -> void:
	if is_dead: return
	hp -= amount
	EventBus.unit_hit.emit(type_id, amount)
	queue_redraw()
	if hp <= 0:
		die()

## 塔防标配：单位头顶迷你血条（敌红我青），满血隐藏
func _draw() -> void:
	if is_dead or hp >= max_hp:
		return
	var w := 26.0
	var h := 3.0
	var y := -24.0
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	draw_rect(Rect2(-w * 0.5 - 1.0, y - 1.0, w + 2.0, h + 2.0), Color(0.03, 0.04, 0.04, 0.8))
	var fill := Color(0.80, 0.30, 0.26) if is_enemy else Color(0.36, 0.66, 0.58)
	draw_rect(Rect2(-w * 0.5, y, w * ratio, h), fill)

func die() -> void:
	if is_dead: return
	is_dead = true
	set_physics_process(false)
	GameState.kills += 1
	EventBus.unit_died.emit(type_id, lane_index)
	died.emit(self)
	sprite.play("attack")
	await sprite.animation_finished
	queue_free()

func _reach_base() -> void:
	is_dead = true
	var dmg := 10
	if is_enemy:
		GameState.damage_own_keep(dmg)
	else:
		GameState.damage_enemy_keep(dmg)
	queue_free()
