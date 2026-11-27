extends Node
## 统一命中反馈入口（Autoload 单例名 FeedbackManager）。
## 分层：闪白 / 伤害数字 / 音效 / 击退 / 粒子火花 / Trauma 震动 / Hitstop / Squash-Stretch / Screen Zoom。
## 性能约定：全部视觉层用预分配 Dictionary 池，由 Battlefield._draw() 委托绘制；
## 命中时零节点创建、零材质创建、零资源加载。HitData 也走池。

const UI_FONT = preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const MAX_CACHED_HIT_DATA := 256

signal hit_processed(position: Vector2, damage: float, critical: bool, weight: int)

var config := FeedbackConfig.new()
var shake := TraumaShake.new()
var sfx_pool: ImpactSfxPool

var numbers: Array[Dictionary] = []
var sparks: Array[Dictionary] = []

## Squash-stretch pop effects
var pops: Array[Dictionary] = []
var _pop_cursor: int = 0

var _hit_data_pool: Array[HitData] = []
var _rng := RandomNumberGenerator.new()
var _number_cursor: int = 0
var _spark_cursor: int = 0
var _camera: Camera2D
var _hitstop_until_usec: int = 0
var _saved_time_scale: float = 1.0
var _hitstop_active: bool = false

## Screen zoom (for heavy hits / explosions)
var _zoom_target: float = 1.0
var _zoom_current: float = 1.0
var _base_camera_zoom: Vector2 = Vector2.ONE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	# 策划可在编辑器里另存 FeedbackConfig 为 res://data/feedback.tres，存在时自动接管默认值。
	if ResourceLoader.exists("res://data/feedback.tres"):
		var authored := load("res://data/feedback.tres") as FeedbackConfig
		if authored != null:
			config = authored
	sfx_pool = ImpactSfxPool.new()
	sfx_pool.name = "ImpactSfxPool"
	add_child(sfx_pool)
	reload_config()


## 策划改完参数后调用；池容量变化会重建池。
func reload_config() -> void:
	shake.configure(config.shake_decay, config.shake_offset_max, config.shake_noise_frequency)
	if sfx_pool != null:
		sfx_pool.configure(
			config.sfx_hit_voices,
			config.sfx_thud_voices,
			config.sfx_hit_volume,
			config.sfx_thud_volume,
			config.sfx_pitch_jitter,
			config.sfx_volume_jitter_db
		)
	_prefill_pools()


func set_config(next_config: FeedbackConfig) -> void:
	if next_config == null:
		return
	config = next_config
	reload_config()


func bind_camera(camera: Camera2D) -> void:
	_camera = camera
	if _camera != null and is_instance_valid(_camera):
		_base_camera_zoom = _camera.zoom
	else:
		_base_camera_zoom = Vector2.ONE
	_zoom_target = 1.0
	_zoom_current = 1.0


func acquire_hit_data() -> HitData:
	if _hit_data_pool.is_empty():
		return HitData.new()
	var data := _hit_data_pool.pop_back() as HitData
	data.reset()
	return data


func release_hit_data(data: HitData) -> void:
	if data == null:
		return
	data.reset()
	if _hit_data_pool.size() < MAX_CACHED_HIT_DATA:
		_hit_data_pool.append(data)


## 无分配便捷入口：内部复用池化 HitData，命中热路径推荐用这个。
func emit_hit(
	position: Vector2,
	impulse: Vector2,
	damage: float,
	critical: bool,
	weight: int,
	target: Variant,
	color: Color = Color.WHITE,
	kind: String = "normal",
	suppress_fx: bool = false
) -> void:
	var data := acquire_hit_data()
	data.position = position
	data.impulse = impulse
	data.damage = damage
	data.critical = critical
	data.weight = weight
	data.target = target
	data.color = color
	data.kind = kind
	data.suppress_fx = suppress_fx
	on_hit(data)


func on_hit(data: HitData) -> void:
	if data == null or not config.enabled:
		return
	_apply_flash(data)
	_apply_knockback(data)
	if not data.suppress_fx:
		_push_number(data)
		_emit_sparks(data)
		_push_pop(data)
		if config.sfx_enabled and sfx_pool != null:
			sfx_pool.play(data.weight)
		if config.shake_enabled:
			var amount := config.shake_heavy_trauma if data.weight >= 2 else config.shake_light_trauma
			if data.critical:
				amount = maxf(amount, config.shake_light_trauma * 2.0)
			shake.add(amount)
		if config.zoom_enabled:
			_add_zoom(data)
		_maybe_hitstop(data)
	hit_processed.emit(data.position, data.damage, data.critical, data.weight)
	release_hit_data(data)


## 持续伤害等低价值命中：只写闪白，不产生数字/音效/火花/震动。
func apply_flash_only(target: Variant, duration: float = -1.0) -> void:
	if not config.flash_enabled or target is not Dictionary:
		return
	var target_dict := target as Dictionary
	if not target_dict.has("flash"):
		return
	var flash_time := duration if duration > 0.0 else config.flash_duration
	target_dict["flash"] = maxf(float(target_dict["flash"]), flash_time)


func _apply_flash(data: HitData) -> void:
	if not config.flash_enabled or data.target is not Dictionary:
		return
	var target := data.target as Dictionary
	if not target.has("flash"):
		return
	var duration := config.flash_heavy_duration if data.weight >= 2 else config.flash_duration
	target["flash"] = maxf(float(target["flash"]), duration)


func _apply_knockback(data: HitData) -> void:
	if not config.knockback_enabled or data.target is not Dictionary:
		return
	var target := data.target as Dictionary
	if not target.has("knockback"):
		return
	var scale := config.knockback_heavy_scale if data.weight >= 2 else config.knockback_light_scale
	target["knockback"] = (target["knockback"] as Vector2) + data.impulse * scale


func _push_number(data: HitData) -> void:
	if not config.number_enabled or numbers.is_empty() or data.damage <= 0.0:
		return
	if not data.critical and str(data.kind) != "kill" and _rng.randi_range(1, 100) > config.number_show_chance:
		return
	var entry := numbers[_number_cursor]
	_number_cursor = (_number_cursor + 1) % numbers.size()
	entry["active"] = true
	entry["pos"] = data.position + Vector2(_rng.randf_range(-8.0, 8.0), -20.0)
	entry["text"] = str(int(round(data.damage)))
	entry["color"] = config.number_crit_color if data.critical else data.color
	entry["critical"] = data.critical
	entry["ttl"] = config.number_lifetime
	entry["max_ttl"] = config.number_lifetime


func _emit_sparks(data: HitData) -> void:
	if not config.spark_enabled or sparks.is_empty():
		return
	var count := config.spark_heavy_per_hit if data.weight >= 2 else config.spark_per_hit
	if data.critical:
		count = maxi(count, config.spark_per_hit + 3)
	var base_dir := data.direction()
	for _i in range(count):
		var entry := sparks[_spark_cursor]
		_spark_cursor = (_spark_cursor + 1) % sparks.size()
		var angle := base_dir.angle() + _rng.randf_range(-config.spark_spread, config.spark_spread)
		var speed := config.spark_speed * _rng.randf_range(0.6, 1.25)
		entry["active"] = true
		entry["pos"] = data.position
		entry["vel"] = Vector2(cos(angle), sin(angle)) * speed
		entry["ttl"] = config.spark_lifetime
		entry["max_ttl"] = config.spark_lifetime


func _push_pop(data: HitData) -> void:
	if not config.pop_enabled or pops.is_empty():
		return
	if data.weight < 2 and not data.critical:
		return
	var entry := pops[_pop_cursor]
	_pop_cursor = (_pop_cursor + 1) % pops.size()
	entry["active"] = true
	entry["pos"] = data.position
	entry["scale"] = Vector2(1.35, 0.72)  # squash X, stretch Y (overshoot)
	entry["ttl"] = 0.18
	entry["max_ttl"] = 0.18


func _add_zoom(data: HitData) -> void:
	if data.weight >= 2 or data.critical:
		_zoom_target = maxf(_zoom_target, config.zoom_heavy_amount)


func _maybe_hitstop(data: HitData) -> void:
	if not config.hitstop_enabled or data.weight < 2:
		return
	var duration := config.hitstop_boss_duration if str(data.kind) == "boss" else config.hitstop_heavy_duration
	duration = clampf(duration, 0.0, 0.03)
	if duration <= 0.0:
		return
	if not _hitstop_active:
		if is_equal_approx(Engine.time_scale, 0.0):
			return
		_saved_time_scale = Engine.time_scale
		_hitstop_active = true
	var target_end := Time.get_ticks_usec() + int(duration * 1000000.0)
	_hitstop_until_usec = maxi(_hitstop_until_usec, target_end)
	Engine.time_scale = 0.05


func _prefill_pools() -> void:
	numbers.clear()
	for _i in range(maxi(1, config.number_max)):
		numbers.append({
			"active": false,
			"pos": Vector2.ZERO,
			"text": "",
			"color": Color.WHITE,
			"critical": false,
			"ttl": 0.0,
			"max_ttl": config.number_lifetime,
		})
	_number_cursor = 0
	sparks.clear()
	for _i in range(maxi(1, config.spark_max)):
		sparks.append({
			"active": false,
			"pos": Vector2.ZERO,
			"vel": Vector2.ZERO,
			"ttl": 0.0,
			"max_ttl": config.spark_lifetime,
		})
	_spark_cursor = 0

	# Squash-stretch pop pool
	pops.clear()
	for _i in range(maxi(1, config.number_max)):
		pops.append({
			"active": false,
			"pos": Vector2.ZERO,
			"scale": Vector2.ONE,
			"ttl": 0.0,
			"max_ttl": 0.18,
		})
	_pop_cursor = 0


func _process(delta: float) -> void:
	if _hitstop_active and Time.get_ticks_usec() >= _hitstop_until_usec:
		Engine.time_scale = _saved_time_scale
		_hitstop_active = false
		_hitstop_until_usec = 0

	var real_delta := delta / maxf(0.05, Engine.time_scale) if _hitstop_active else delta
	_zoom_target = lerpf(_zoom_target, 1.0, clampf(config.zoom_recovery_speed * real_delta, 0.0, 1.0))
	_zoom_current = lerpf(_zoom_current, _zoom_target, clampf(16.0 * real_delta, 0.0, 1.0))
	if absf(_zoom_target - 1.0) < 0.002 and absf(_zoom_current - 1.0) < 0.002:
		_zoom_target = 1.0
		_zoom_current = 1.0

	for entry in numbers:
		if not bool(entry["active"]):
			continue
		entry["ttl"] = float(entry["ttl"]) - delta
		if float(entry["ttl"]) <= 0.0:
			entry["active"] = false
		else:
			entry["pos"] = (entry["pos"] as Vector2) + Vector2(0.0, -config.number_rise_speed * delta)

	var friction := clampf(1.0 - 4.0 * delta, 0.0, 1.0)
	for entry in sparks:
		if not bool(entry["active"]):
			continue
		entry["ttl"] = float(entry["ttl"]) - delta
		if float(entry["ttl"]) <= 0.0:
			entry["active"] = false
		else:
			entry["pos"] = (entry["pos"] as Vector2) + (entry["vel"] as Vector2) * delta
			entry["vel"] = (entry["vel"] as Vector2) * friction

	# Squash-stretch pops (back ease out)
	for entry in pops:
		if not bool(entry["active"]):
			continue
		entry["ttl"] = float(entry["ttl"]) - delta
		if float(entry["ttl"]) <= 0.0:
			entry["active"] = false
			entry["scale"] = Vector2.ONE
		else:
			var t := 1.0 - float(entry["ttl"]) / float(entry["max_ttl"])
			# Back ease out: overshoots past 1.0 then settles
			var eased := 1.0 + (1.0 - t) * (1.0 - t) * (2.7 * t - 1.7)
			entry["scale"] = Vector2(lerp(1.35, 1.0, eased), lerp(0.72, 1.0, eased))

	if _camera != null and is_instance_valid(_camera):
		_camera.offset = shake.update(real_delta) * config.shake_strength
		_camera.zoom = _base_camera_zoom * _zoom_current
	else:
		shake.update(real_delta)


## 由 Battlefield._draw() 末尾调用，字段与战场共用同一坐标系与 draw transform。
func draw(canvas: Node2D) -> void:
	if not config.enabled:
		return
	if config.spark_enabled:
		_draw_sparks(canvas)
	if config.number_enabled:
		_draw_numbers(canvas)
	if config.pop_enabled:
		_draw_pops(canvas)


func _draw_numbers(canvas: Node2D) -> void:
	for entry in numbers:
		if not bool(entry["active"]):
			continue
		var alpha := clampf(float(entry["ttl"]) / maxf(0.001, float(entry["max_ttl"])), 0.0, 1.0)
		var size := config.number_crit_font_size if bool(entry["critical"]) else config.number_font_size
		var color := entry["color"] as Color
		canvas.draw_string(
			UI_FONT,
			entry["pos"] as Vector2,
			str(entry["text"]),
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			size,
			Color(color, alpha)
		)


func _draw_sparks(canvas: Node2D) -> void:
	for entry in sparks:
		if not bool(entry["active"]):
			continue
		var alpha := clampf(float(entry["ttl"]) / maxf(0.001, float(entry["max_ttl"])), 0.0, 1.0)
		var start := entry["pos"] as Vector2
		var tail := (entry["vel"] as Vector2).normalized() * -8.0
		canvas.draw_line(start, start + tail, Color(config.spark_color, alpha), 2.0, true)


func _draw_pops(canvas: Node2D) -> void:
	for entry in pops:
		if not bool(entry["active"]):
			continue
		var scale := entry["scale"] as Vector2
		var max_ttl := maxf(0.001, float(entry["max_ttl"]))
		var progress := 1.0 - clampf(float(entry["ttl"]) / max_ttl, 0.0, 1.0)
		var alpha := (1.0 - progress) * config.pop_color.a
		var radius := lerpf(8.0, 26.0, progress) * ((scale.x + scale.y) * 0.5)
		canvas.draw_arc(entry["pos"] as Vector2, radius, 0.0, TAU, 20, Color(config.pop_color, alpha), 1.8, true)


## 场景切换 / 暂停时清理运行态，避免 Hitstop 跨场景残留。
func reset_runtime() -> void:
	for entry in numbers:
		entry["active"] = false
	for entry in sparks:
		entry["active"] = false
	for entry in pops:
		entry["active"] = false
	shake.reset()
	_zoom_target = 1.0
	_zoom_current = 1.0
	if _hitstop_active:
		Engine.time_scale = _saved_time_scale
		_hitstop_active = false
		_hitstop_until_usec = 0
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO
		_camera.zoom = _base_camera_zoom
	_camera = null


func hitstop_active() -> bool:
	return _hitstop_active
