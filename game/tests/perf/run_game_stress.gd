extends Node

const STRESS_ENEMY_IDS := ["scout", "ronin", "archer", "shield", "gun", "banner", "cavalry", "general"]

var run: Node
var _frame := 0
var _wall_start := 0
var _wall_sum := 0
var _step_sum := 0
var _world_sum := 0
var _flow_sum := 0
var _hud_sum := 0
var _world_part_sum: Dictionary = {}
var _sample_count := 0
var _capture := ""
var _frame_capture_dir := ""
var _target_enemy_count := 0
var _enemy_spawn_index := 0
var _walk_hist: Array[int] = []
var _idle_hist: Array[int] = []
var _enemy_frame_hist: Array[int] = []


func _ready() -> void:
	_capture = OS.get_environment("WATCH_RUN_CAPTURE")
	_frame_capture_dir = OS.get_environment("WATCH_RUN_FRAME_CAPTURE_DIR")
	if not _frame_capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_frame_capture_dir)
	_walk_hist.resize(8)
	_idle_hist.resize(4)
	_enemy_frame_hist.resize(8)
	_walk_hist.fill(0)
	_idle_hist.fill(0)
	_enemy_frame_hist.fill(0)
	run = load("res://scenes/run.tscn").instantiate()
	add_child(run)
	await get_tree().process_frame
	run.debug_prepare_capture("aim")
	run._paused = false
	run.set_invincible_mode(true)
	run.elapsed = 0.0
	run._spawn_accum = -1000.0
	run._boss_spawned = true
	run._scale_event_index = run._scale_events.size()
	# Keep the full battle active without an XP card overlay blocking the visual capture.
	run.battlefield.xp_collected.disconnect(run._on_xp_collected)
	run.touch_controls.force_visible = true
	run.touch_controls._apply_visibility()
	var center: Vector2 = run.player["pos"]
	_target_enemy_count = int(run.battlefield.max_alive_enemies())
	var requested_enemy_count := OS.get_environment("WATCH_RUN_ENEMY_COUNT")
	if not requested_enemy_count.is_empty():
		_target_enemy_count = clampi(int(requested_enemy_count), 1, _target_enemy_count)
	var spawn_count: int = maxi(0, _target_enemy_count - run.battlefield.alive_count())
	for i in range(spawn_count):
		var angle := TAU * float(i) / 460.0
		var ring := 240.0 + float(i % 9) * 52.0
		run.battlefield.spawn_enemy_at(str(STRESS_ENEMY_IDS[i % STRESS_ENEMY_IDS.size()]), center + Vector2.RIGHT.rotated(angle) * ring)
		_enemy_spawn_index += 1
	# Keep every target alive so the renderer stays at the requested enemy cap.
	run._auto_attack = false
	var ally_ids := ["yishi_spear", "yishi_archer", "tengpai_militia", "standard_bearer"]
	var ally_offsets := [Vector2(-72.0, -48.0), Vector2(72.0, -48.0), Vector2(-72.0, 48.0), Vector2(72.0, 48.0)]
	for index in ally_ids.size():
		run.battlefield.spawn_ally(str(ally_ids[index]), center + (ally_offsets[index] as Vector2))
	# Preserve the full enemy load while keeping the visual allies present.
	for ally in run.battlefield.allies:
		ally["damage"] = 0.0
	print("[run_stress] target_enemies=%d spawned_enemies=%d allies=%d invincible=%s auto_attack=%s" % [_target_enemy_count, run.battlefield.alive_count(), run.battlefield.allies.size(), run.debug_invincible, run._auto_attack])
	if run.battlefield.alive_count() != _target_enemy_count:
		push_warning("stress spawn did not reach enemy cap: %d/%d" % [run.battlefield.alive_count(), _target_enemy_count])


func _process(delta: float) -> void:
	if run == null:
		return
	# Enemies that leave the active world are removed by Battlefield; replenish them
	# so the stress case continues measuring the requested maximum population.
	while run.battlefield.alive_count() < _target_enemy_count:
		var angle := TAU * float(_enemy_spawn_index) / 460.0
		var ring := 240.0 + float(_enemy_spawn_index % 9) * 52.0
		var spawned: int = run.battlefield.spawn_enemy_at(
			str(STRESS_ENEMY_IDS[_enemy_spawn_index % STRESS_ENEMY_IDS.size()]),
			run.player["pos"] + Vector2.RIGHT.rotated(angle) * ring
		)
		if spawned < 0:
			break
		_enemy_spawn_index += 1
	var now := Time.get_ticks_usec()
	if _wall_start > 0:
		_wall_sum += now - _wall_start
	_wall_start = now
	# Drive the real touch joystick so RunGame's movement, weapon, animation and collision paths execute.
	var phase := float(_frame) * 0.025
	run.touch_controls.move_vector = Vector2(cos(phase), sin(phase)).normalized()
	_step_sum += int(run._last_step_usec)
	_world_sum += int(run._last_world_usec)
	_flow_sum += int(run._last_flow_usec)
	_hud_sum += int(run._last_hud_usec)
	var battlefield: Battlefield = run.battlefield
	for key in battlefield._world_perf_parts:
		_world_part_sum[key] = int(_world_part_sum.get(key, 0)) + int(battlefield._world_perf_parts[key])
	var moving := battlefield._player_moving
	var animation_fps := battlefield.player_walk_fps if moving else battlefield.player_idle_fps
	var animation_count := battlefield.player_walk_frames.size() if moving else battlefield.player_idle_frames.size()
	if animation_count > 0:
		var animation_frame := posmod(int(battlefield.time * animation_fps), animation_count)
		if moving:
			_walk_hist[animation_frame] += 1
		else:
			_idle_hist[animation_frame] += 1
	if _frame % 10 == 0:
		for enemy in battlefield.enemies:
			if not bool(enemy.get("alive", false)):
				continue
			var draw_id := str(enemy.get("draw_id", enemy.get("id", "")))
			var enemy_frames: Array = battlefield.enemy_sprite_frames.get(draw_id, []) as Array
			if enemy_frames.size() == 8:
				var enemy_frame := posmod(
					int(battlefield.time * maxf(1.0, float(enemy.get("sprite_fps", 10.0))))
						+ posmod(draw_id.hash(), enemy_frames.size()),
					enemy_frames.size()
				)
				_enemy_frame_hist[enemy_frame] += 1
	_sample_count += 1
	if not _frame_capture_dir.is_empty() and _frame % 15 == 0:
		var frame_image := get_viewport().get_texture().get_image()
		if frame_image != null:
			var frame_path := "%s/frame_%03d.png" % [_frame_capture_dir, _frame]
			frame_image.save_png(frame_path)
	_frame += 1
	if _frame % 120 == 0 and _wall_sum > 0:
		var fps := float(_sample_count) * 1000000.0 / float(_wall_sum)
		var ms := float(_wall_sum) / float(_sample_count) / 1000.0
		var step_ms := float(_step_sum) / float(_sample_count) / 1000.0
		var world_ms := float(_world_sum) / float(_sample_count) / 1000.0
		var flow_ms := float(_flow_sum) / float(_sample_count) / 1000.0
		var hud_ms := float(_hud_sum) / float(_sample_count) / 1000.0
		var world_parts_ms: Dictionary = {}
		for key in _world_part_sum:
			world_parts_ms[key] = snappedf(float(_world_part_sum[key]) / float(_sample_count) / 1000.0, 0.01)
		print("[run_stress] frames=%d fps=%.1f frame_ms=%.2f step_ms=%.2f world_ms=%.2f flow_ms=%.2f hud_ms=%.2f engine_fps=%.1f enemies=%d player_frames=%d/%d allies=%d draw_calls=%d primitives=%d" % [
			_frame, fps, ms, step_ms, world_ms, flow_ms, hud_ms, Engine.get_frames_per_second(), run.battlefield.alive_count(),
			run.battlefield.player_walk_frames.size(), run.battlefield.player_idle_frames.size(), run.battlefield.allies.size(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		])
		print("[run_stress] world_parts_ms=%s" % JSON.stringify(world_parts_ms))
		_wall_sum = 0
		_step_sum = 0
		_world_sum = 0
		_flow_sum = 0
		_hud_sum = 0
		_world_part_sum.clear()
		_sample_count = 0
	if _frame >= 120:
		print("[run_stress] walk_frame_hist=%s idle_frame_hist=%s enemy_frame_hist=%s" % [JSON.stringify(_walk_hist), JSON.stringify(_idle_hist), JSON.stringify(_enemy_frame_hist)])
		if not _capture.is_empty():
			var viewport_texture := get_viewport().get_texture()
			if DisplayServer.get_name() != "headless" and viewport_texture != null:
				var image := viewport_texture.get_image()
				if image != null:
					print("[run_stress] capture=%s error=%d" % [_capture, image.save_png(_capture)])
			else:
				push_warning("stress capture unavailable with the active renderer")
		if OS.has_feature("web"):
			# Keep the last frame visible for browser screenshot review; quitting the Web
			# runtime tears down AudioWorklet samples before their nodes finish closing.
			set_process(false)
			run.set_process(false)
			run.set_physics_process(false)
			get_tree().paused = true
		else:
			get_tree().quit()
