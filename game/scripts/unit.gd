extends PathFollow2D
class_name Unit
## 沿 Path2D 行进的单位：移动、动画、受击、死亡。

signal died(unit: Unit)

@export var type_id: StringName = &"xiangyong"
@export var max_hp: int = 120
@export var speed: float = 32.0
@export var lane_index: int = 0
@export var is_enemy: bool = false
# 行进方向：1.0 左→右（玩家兵），-1.0 右→左（敌方兵，从右侧刷新点进入）
@export var direction: float = 1.0

@onready var sprite: AnimatedSprite2D = $Sprite

var hp: int = 0
var is_dead: bool = false

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
	progress += speed * delta * direction
	if direction > 0.0 and progress_ratio >= 1.0:
		_reach_base()
	elif direction < 0.0 and progress_ratio <= 0.0:
		_reach_base()

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
	if hp <= 0:
		die()

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
