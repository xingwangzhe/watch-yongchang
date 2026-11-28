extends GutTest
## 打击反馈系统：对象池复用、分层开关、容量上限、Trauma 衰减、Hitstop 默认关闭。

var _target: Dictionary = {}
var _camera: Camera2D


func before_each() -> void:
	FeedbackManager.reset_runtime()
	_target = {"flash": 0.0, "knockback": Vector2.ZERO}


func after_each() -> void:
	FeedbackManager.reset_runtime()
	if is_instance_valid(_camera):
		_camera.free()
	_camera = null


func test_hit_data_pool_reuses_instances_and_resets_fields() -> void:
	var data := FeedbackManager.acquire_hit_data()
	data.position = Vector2(10.0, 20.0)
	data.damage = 99.0
	data.critical = true
	FeedbackManager.release_hit_data(data)

	var reused := FeedbackManager.acquire_hit_data()
	assert_eq(reused, data, "HitData must come from the pool")
	assert_eq(reused.position, Vector2.ZERO)
	assert_eq(reused.damage, 0.0)
	assert_false(reused.critical)
	FeedbackManager.release_hit_data(reused)


func test_suppressed_hit_only_applies_flash_and_knockback() -> void:
	var numbers_before := _active_count(FeedbackManager.numbers)
	var sparks_before := _active_count(FeedbackManager.sparks)
	FeedbackManager.emit_hit(
		Vector2(100.0, 100.0), Vector2(12.0, 0.0), 8.0, false, 0, _target,
		Color.WHITE, "burn", true
	)
	assert_gt(float(_target["flash"]), 0.0, "flash must apply to suppressed hits")
	assert_eq(_target["knockback"], Vector2(12.0, 0.0), "knockback must apply to suppressed hits")
	assert_eq(_active_count(FeedbackManager.numbers), numbers_before)
	assert_eq(_active_count(FeedbackManager.sparks), sparks_before)


func test_critical_hit_always_spawns_number_and_sparks() -> void:
	var numbers_before := _active_count(FeedbackManager.numbers)
	FeedbackManager.emit_hit(
		Vector2(100.0, 100.0), Vector2(4.0, 0.0), 42.0, true, 0, _target
	)
	assert_eq(_active_count(FeedbackManager.numbers), numbers_before + 1)
	assert_gt(_active_count(FeedbackManager.sparks), 0)


func test_heavy_hit_uses_longer_flash_and_stronger_knockback() -> void:
	FeedbackManager.emit_hit(
		Vector2(0.0, 0.0), Vector2(10.0, 0.0), 40.0, false, 2, _target,
		Color.WHITE, "boss"
	)
	assert_gt(float(_target["flash"]), FeedbackManager.config.flash_duration)
	assert_almost_eq(
		(_target["knockback"] as Vector2).length(),
		10.0 * FeedbackManager.config.knockback_heavy_scale,
		0.001
	)


func test_pools_never_exceed_capacity() -> void:
	var capacity := FeedbackManager.config.number_max
	for _i in range(capacity + 50):
		FeedbackManager.emit_hit(
			Vector2(10.0, 10.0), Vector2(1.0, 0.0), 7.0, true, 0, _target
		)
	assert_eq(_active_count(FeedbackManager.numbers), capacity)
	assert_eq(FeedbackManager.sparks.size(), FeedbackManager.config.spark_max)


func test_flash_and_number_layers_can_be_disabled_independently() -> void:
	var saved_flash := FeedbackManager.config.flash_enabled
	var saved_number := FeedbackManager.config.number_enabled
	FeedbackManager.config.flash_enabled = false
	FeedbackManager.config.number_enabled = false
	var numbers_before := _active_count(FeedbackManager.numbers)

	FeedbackManager.emit_hit(
		Vector2(0.0, 0.0), Vector2(3.0, 0.0), 15.0, true, 0, _target
	)
	assert_eq(float(_target["flash"]), 0.0)
	assert_eq(_active_count(FeedbackManager.numbers), numbers_before)

	FeedbackManager.config.flash_enabled = saved_flash
	FeedbackManager.config.number_enabled = saved_number


func test_hitstop_is_limited_to_heavy_and_boss_hits() -> void:
	assert_true(FeedbackManager.config.hitstop_enabled)
	assert_almost_eq(FeedbackManager.config.hitstop_heavy_duration, 0.012, 0.001)
	assert_almost_eq(FeedbackManager.config.hitstop_boss_duration, 0.024, 0.001)
	assert_false(FeedbackManager.hitstop_active())


func test_trauma_decays_and_offset_is_bounded() -> void:
	var shake := TraumaShake.new()
	shake.configure(1.8, 8.0, 18.0)
	shake.add(5.0)
	assert_almost_eq(shake.trauma, 1.0, 0.001, "trauma must clamp to 1.0")
	var offset := shake.update(0.1)
	assert_lt(shake.trauma, 1.0, "trauma must decay")
	assert_lte(offset.length(), 8.0, "shake offset must stay within configured bound")


func test_normal_and_critical_hits_leave_camera_follow_baseline_static() -> void:
	var base_offset := Vector2(6.0, -4.0)
	var base_zoom := Vector2(0.82, 0.82)
	_camera = Camera2D.new()
	_camera.offset = base_offset
	_camera.zoom = base_zoom
	FeedbackManager.bind_camera(_camera)

	for _i in range(20):
		FeedbackManager.emit_hit(Vector2.ZERO, Vector2.RIGHT, 5.0, false, 1, _target)
		FeedbackManager.emit_hit(Vector2.ZERO, Vector2.RIGHT, 5.0, true, 1, _target)
	FeedbackManager._process(1.0 / 60.0)

	assert_eq(_camera.offset, base_offset, "routine and critical hits must not shake the camera")
	assert_eq(_camera.zoom, base_zoom, "routine and critical hits must not punch camera zoom")
	assert_eq(FeedbackManager.shake.trauma, 0.0)
	assert_eq(FeedbackManager._zoom_target, 1.0)


func test_portrait_rebind_restores_latest_zoom_and_pan_baseline() -> void:
	var saved_hitstop := FeedbackManager.config.hitstop_enabled
	FeedbackManager.config.hitstop_enabled = false
	var original_offset := Vector2(3.0, -2.0)
	var original_zoom := Vector2(0.92, 0.92)
	_camera = Camera2D.new()
	_camera.offset = original_offset
	_camera.zoom = original_zoom
	FeedbackManager.bind_camera(_camera)
	FeedbackManager.emit_hit(
		Vector2.ZERO, Vector2.RIGHT, 50.0, false, 2, _target, Color.WHITE, "boss"
	)
	FeedbackManager._process(1.0 / 60.0)
	assert_gt(FeedbackManager._zoom_current, 1.0, "a heavy hit may use a brief zoom punch")
	assert_lte(FeedbackManager._zoom_current, 1.015, "camera zoom feedback must stay subtle")

	var portrait_offset := Vector2(14.0, -8.0)
	var portrait_zoom := Vector2(0.76, 0.76)
	_camera.offset = portrait_offset
	_camera.zoom = portrait_zoom
	FeedbackManager.bind_camera(_camera)
	assert_eq(FeedbackManager._base_camera_offset, portrait_offset)
	assert_eq(FeedbackManager._base_camera_zoom, portrait_zoom)
	FeedbackManager._process(1.0 / 60.0)
	FeedbackManager.reset_runtime()

	assert_eq(
		_camera.offset, portrait_offset, "feedback restore must keep the resized pan baseline"
	)
	assert_eq(
		_camera.zoom, portrait_zoom, "feedback restore must keep the resized portrait zoom"
	)
	FeedbackManager.config.hitstop_enabled = saved_hitstop


func test_rebinding_same_camera_does_not_promote_feedback_zoom_to_baseline() -> void:
	var saved_hitstop := FeedbackManager.config.hitstop_enabled
	FeedbackManager.config.hitstop_enabled = false
	var base_zoom := Vector2(0.9, 0.9)
	_camera = Camera2D.new()
	_camera.zoom = base_zoom
	FeedbackManager.bind_camera(_camera)
	FeedbackManager.emit_hit(
		Vector2.ZERO, Vector2.RIGHT, 50.0, false, 2, _target, Color.WHITE, "boss"
	)
	FeedbackManager._process(1.0 / 60.0)
	FeedbackManager.bind_camera(_camera)
	FeedbackManager._process(1.0 / 60.0)

	assert_eq(FeedbackManager._base_camera_zoom, base_zoom)
	assert_eq(_camera.zoom, base_zoom, "rebinding must cancel feedback without capturing its zoom")
	FeedbackManager.config.hitstop_enabled = saved_hitstop


func test_sfx_pool_preallocates_voices_once() -> void:
	var voices := FeedbackManager.sfx_pool.voice_count()
	assert_gt(FeedbackManager.config.sfx_volume_jitter_db, 0.0, "repeated impacts need subtle level variation")
	assert_lte(FeedbackManager.config.sfx_volume_jitter_db, 3.0, "impact variation must stay restrained")
	assert_eq(
		voices,
		FeedbackManager.config.sfx_hit_voices + FeedbackManager.config.sfx_thud_voices
	)
	for _i in range(20):
		FeedbackManager.emit_hit(Vector2.ZERO, Vector2.RIGHT, 5.0, false, 1, _target)
	assert_eq(FeedbackManager.sfx_pool.voice_count(), voices, "hits must not create audio nodes")


func test_5000_hits_keep_pools_bounded_and_run_fast() -> void:
	var started := Time.get_ticks_usec()
	for i in range(5000):
		FeedbackManager.emit_hit(
			Vector2(float(i % 1280), float(i % 720)),
			Vector2(1.0, 0.0),
			12.0,
			false,
			0,
			_target
		)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	assert_lte(FeedbackManager.numbers.size(), FeedbackManager.config.number_max)
	assert_lte(FeedbackManager.sparks.size(), FeedbackManager.config.spark_max)
	assert_lte(
		FeedbackManager.sfx_pool.voice_count(),
		FeedbackManager.config.sfx_hit_voices + FeedbackManager.config.sfx_thud_voices
	)
	assert_lte(elapsed_ms, 500.0, "5000 hits must stay within the time budget")


func _active_count(pool: Array[Dictionary]) -> int:
	var count := 0
	for entry in pool:
		if bool(entry["active"]):
			count += 1
	return count
