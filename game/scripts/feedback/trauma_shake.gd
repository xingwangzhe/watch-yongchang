class_name TraumaShake
extends RefCounted
## trauma 平方驱动 + 平滑噪声的 2D 震动计算器。
## 只产出 offset，不修改节点 transform；由 FeedbackManager 写入 Camera2D.offset。

var trauma: float = 0.0
var decay: float = 1.8
var offset_max: float = 8.0
var noise_frequency: float = 18.0

var _noise: FastNoiseLite
var _time: float = 0.0
var _offset: Vector2 = Vector2.ZERO


func _init() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0
	_noise.seed = 20261124


func configure(p_decay: float, p_offset_max: float, p_noise_frequency: float) -> void:
	decay = maxf(0.01, p_decay)
	offset_max = maxf(0.0, p_offset_max)
	noise_frequency = maxf(0.1, p_noise_frequency)


func add(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func reset() -> void:
	trauma = 0.0
	_time = 0.0
	_offset = Vector2.ZERO


func update(delta: float) -> Vector2:
	if trauma <= 0.0:
		_offset = Vector2.ZERO
		return _offset
	trauma = maxf(0.0, trauma - decay * delta)
	var shake := trauma * trauma
	_time += delta * noise_frequency
	_offset = Vector2(
		_noise.get_noise_2d(_time, 0.0),
		_noise.get_noise_2d(0.0, _time + 41.7)
	) * offset_max * shake
	if trauma <= 0.0:
		_offset = Vector2.ZERO
	return _offset


func get_offset() -> Vector2:
	return _offset
