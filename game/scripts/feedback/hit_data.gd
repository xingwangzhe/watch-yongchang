class_name HitData
extends RefCounted
## 单次命中的反馈数据载体。由 FeedbackManager 池化复用，禁止长期持有引用。

var position: Vector2 = Vector2.ZERO
var impulse: Vector2 = Vector2.ZERO
var damage: float = 0.0
var critical: bool = false
var weight: int = 0            ## 0 轻击 / 1 普通 / 2 重击·精英·Boss
var target: Variant = null     ## Battlefield 敌人 Dictionary 的引用（非拷贝）
var color: Color = Color.WHITE
var kind: String = "normal"
var suppress_fx: bool = false  ## true 仅闪白 + 击退，用于持续伤害等高频来源


func reset() -> void:
	position = Vector2.ZERO
	impulse = Vector2.ZERO
	damage = 0.0
	critical = false
	weight = 0
	target = null
	color = Color.WHITE
	kind = "normal"
	suppress_fx = false


func direction() -> Vector2:
	if impulse.length_squared() > 0.0001:
		return impulse.normalized()
	return Vector2.RIGHT
