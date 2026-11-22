extends Area2D
class_name Projectile
## 弹道：直线飞向目标，命中后结算伤害。

var target: Unit = null
var damage: int = 10
var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 2.0

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	if sprite.texture == null:
		var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		for x in range(12):
			for y in range(12):
				var d := Vector2(x - 5.5, y - 5.5).length()
				img.set_pixel(x, y, Color(1.0, 0.86, 0.32, 1.0) if d <= 5.5 else Color(0, 0, 0, 0))
		sprite.texture = ImageTexture.create_from_image(img)

func launch(from: Vector2, p_target: Unit, p_damage: int) -> void:
	global_position = from
	target = p_target
	damage = p_damage
	velocity = (p_target.global_position - from).normalized() * 420.0

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	if target != null and is_instance_valid(target) and not target.is_dead:
		velocity = (target.global_position - global_position).normalized() * 420.0
		if global_position.distance_to(target.global_position) < 12.0:
			target.take_damage(damage)
			queue_free()
			return
	global_position += velocity * delta
