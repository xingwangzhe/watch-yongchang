extends Node2D
class_name Tower
## 箭塔：冷却结束时遍历单位索敌，弹药不足立即停火。

@export var tower_id: StringName = &"jianta"
@export var damage: int = 25
@export var interval: float = 1.5
@export var attack_range: float = 150.0
@export var lane_index: int = 0

@onready var muzzle: Marker2D = $Muzzle
@onready var sprite: AnimatedSprite2D = $Sprite

var cooldown: float = 0.0
var shots: int = 0

func _ready() -> void:
	# 借鉴 Mindustry/RWX：建筑用动画帧表达攻击状态，帧由资源层统一缓存构建
	sprite.sprite_frames = ResourceManager.get_building_frames(str(tower_id), "attack")
	sprite.play("default")
	print("[TOWER] ready type=%s damage=%d interval=%.1f" % [tower_id, damage, interval])

func _physics_process(delta: float) -> void:
	if GameState.phase == GameState.Phase.VICTORY or GameState.phase == GameState.Phase.DEFEAT:
		return
	cooldown -= delta
	if cooldown > 0.0: return
	if not SupplySystem.can_fire():
		return
	var target := _find_target()
	if target == null: return
	if not SupplySystem.consume_ammo(1):
		return
	_fire(target)
	cooldown = interval

func _find_target() -> Unit:
	var best: Unit = null
	var best_d2: float = attack_range * attack_range
	for node in get_tree().get_nodes_in_group("units"):
		var u := node as Unit
		if u == null or u.is_dead or not u.is_enemy: continue
		var d2: float = global_position.distance_squared_to(u.global_position)
		if d2 <= best_d2:
			best_d2 = d2
			best = u
	return best

func _fire(target: Unit) -> void:
	shots += 1
	EventBus.tower_fired.emit(tower_id, target.type_id)
	print("[TOWER] fire target=%s damage=%d ammo=%d" % [target.type_id, damage, SupplySystem.ammo_stock])
	var scene := load("res://scenes/projectile.tscn") as PackedScene
	var p := scene.instantiate() as Projectile
	var layer := get_tree().current_scene.get_node_or_null("Projectiles")
	if layer == null:
		layer = get_parent().get_parent().get_parent()
	layer.add_child(p)
	p.launch(muzzle.global_position, target, damage)
