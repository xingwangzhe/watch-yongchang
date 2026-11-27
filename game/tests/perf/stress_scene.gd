extends Node2D

var field: Battlefield
var player := {
	"pos": Vector2.ZERO,
	"radius": 18.0,
	"pickup_radius": 96.0,
}
var _t := 0.0
var _sample_time := 0.0
var _sample_frames := 0
var _sample_wall_frames := 0
var _sample_wall_usec := 0
var _sample_update_usec := 0
var _last_frame_us := 0
var _enemy_count := 460
var _debug := false
var _debug_frames := 0
var _perf_log: FileAccess
var _capture_path := ""
var _capture_done := false
var _frame_count := 0


func _ready() -> void:
	_debug = OS.has_environment("WATCH_STRESS_DEBUG")
	var log_path := OS.get_environment("WATCH_STRESS_LOG")
	if not log_path.is_empty():
		_perf_log = FileAccess.open(log_path, FileAccess.WRITE)
	_capture_path = OS.get_environment("WATCH_STRESS_CAPTURE")
	var requested := OS.get_environment("WATCH_STRESS_COUNT")
	if not requested.is_empty():
		_enemy_count = clampi(int(requested), 1, 460)
	field = Battlefield.new()
	field.name = "Battlefield"
	add_child(field)
	field.setup(20261123)
	# Keep the requested population in a bounded combat ring during capacity runs.
	# The gameplay culler intentionally removes enemies over 2,100 px from the player;
	# this benchmark isolates the 460-enemy update workload instead of measuring culling.
	if OS.has_environment("WATCH_STRESS_PIN_ENEMIES"):
		field.allies.clear()
	var characters := GameData.get_characters()
	field.set_player_sprites(characters.get("wanglu", {}) as Dictionary)
	field.set_meta("player_tint", Color.WHITE)
	field.set_meta("draw_enemies", OS.get_environment("WATCH_STRESS_DRAW_ENEMIES") != "0")
	if OS.get_environment("WATCH_STRESS_HIDE_OVERLAYS") == "1":
		field.map_renderer.shade_layer.visible = false
		field.map_renderer.elevation_layer.visible = false
	if OS.get_environment("WATCH_STRESS_HIDE_TILEMAPS") == "1":
		field.map_renderer.terrain_layer.visible = false
		field.map_renderer.architecture_layer.visible = false
		field.map_renderer.props_layer.visible = false
		field.map_renderer.canopy_layer.visible = false
	for i in range(_enemy_count):
		var angle := TAU * float(i) / float(_enemy_count)
		var ring := 120.0 + float(i % 7) * 72.0
		field.spawn_enemy_at(
			"scout" if i % 5 else "ronin",
			Vector2(cos(angle), sin(angle)) * ring
		)
	if not OS.has_environment("WATCH_STRESS_PIN_ENEMIES"):
		var ally_ids := ["yishi_spear", "yishi_archer", "tengpai_militia", "standard_bearer"]
		for index in ally_ids.size():
			field.spawn_ally(str(ally_ids[index]), Vector2(-100.0 + float(index) * 64.0, 90.0))
	var pickup_count := clampi(int(OS.get_environment("WATCH_STRESS_PICKUPS")), 0, 2000)
	for i in range(pickup_count):
		var angle := TAU * float(i) / float(maxi(1, pickup_count))
		var ring := 300.0 + float(i % 5) * 70.0
		field.orbs.append({
			"pos": Vector2(cos(angle), sin(angle)) * ring,
			"value": 1.0,
			"taken": false,
			"magnet": false,
		})
	var shot_count := clampi(int(OS.get_environment("WATCH_STRESS_SHOTS")), 0, 2000)
	for i in range(shot_count):
		var angle := TAU * float(i) / float(maxi(1, shot_count))
		var ring := 220.0 + float(i % 6) * 55.0
		field.fire_player_projectile(
			Vector2(cos(angle), sin(angle)) * ring,
			Vector2.RIGHT.rotated(angle),
			1.0,
			1.0,
			99,
			Color("#e1b35a")
		)
		var shot := field.player_shots[field.player_shots.size() - 1]
		shot["ttl"] = 999.0
		shot["vel"] = Vector2.ZERO
	var enemy_shot_count := clampi(int(OS.get_environment("WATCH_STRESS_ENEMY_SHOTS")), 0, 2000)
	for i in range(enemy_shot_count):
		var angle := TAU * float(i) / float(maxi(1, enemy_shot_count))
		var ring := 250.0 + float(i % 5) * 60.0
		field.enemy_shots.append({
			"pos": Vector2(cos(angle), sin(angle)) * ring,
			"vel": Vector2.ZERO,
			"damage": 0.0,
			"ttl": 999.0,
		})
	print("[stress] enemies=%d" % _enemy_count)
	_log("[stress] enemies=%d" % _enemy_count)


func _process(delta: float) -> void:
	var frame_started := Time.get_ticks_usec()
	if _last_frame_us > 0:
		_sample_wall_usec += frame_started - _last_frame_us
		_sample_wall_frames += 1
	_last_frame_us = frame_started
	if _debug and _debug_frames < 8:
		print("[stress] process start frame=%d delta=%.6f" % [_debug_frames, delta])
		_log("[stress] process start frame=%d delta=%.6f" % [_debug_frames, delta])
	_t += delta
	player["pos"] = Vector2(cos(_t * 0.35), sin(_t * 0.35)) * 150.0
	if OS.has_environment("WATCH_STRESS_PIN_ENEMIES"):
		for index in field.enemies.size():
			var enemy := field.enemies[index]
			var angle := TAU * float(index) / float(maxi(1, field.enemies.size()))
			var radius := 420.0 + float(index % 7) * 24.0
			enemy["alive"] = true
			enemy["pos"] = player["pos"] + Vector2.RIGHT.rotated(angle) * radius
	field.player_facing = (player["pos"] as Vector2) - field.player_pos
	field.player_aim = Vector2.RIGHT.rotated(_t * 0.8)
	var update_started := Time.get_ticks_usec()
	if OS.get_environment("WATCH_STRESS_SKIP_UPDATE") != "1":
		field.update_world(delta, player)
	_sample_update_usec += Time.get_ticks_usec() - update_started
	if _debug and _debug_frames < 8:
		print("[stress] process updated frame=%d" % _debug_frames)
		_log("[stress] process updated frame=%d" % _debug_frames)
		_debug_frames += 1
	_frame_count += 1
	if not _capture_done and not _capture_path.is_empty() and _frame_count >= 120:
		_capture_done = true
		var image := get_viewport().get_texture().get_image()
		if image != null:
			var error := image.save_png(_capture_path)
			print("[stress] capture=%s error=%d" % [_capture_path, error])
		get_tree().quit()
	_sample_time += delta
	_sample_frames += 1
	if _sample_time >= 2.0 and _sample_wall_usec > 0:
		var wall_ms := float(_sample_wall_usec) / 1000.0 / float(maxi(1, _sample_wall_frames))
		var logic_ms := float(_sample_update_usec) / 1000.0 / float(maxi(1, _sample_frames))
		var line := "[stress] wall_fps=%.1f wall_frame_ms=%.2f logic_ms=%.3f engine_fps=%.1f enemies=%d allies=%d player_walk_frames=%d player_idle_frames=%d draw_calls=%d primitives=%d" % [
			float(_sample_wall_frames) * 1000000.0 / float(_sample_wall_usec),
			wall_ms,
			logic_ms,
			Engine.get_frames_per_second(),
			field.alive_count(),
			field.allies.size(),
			field.player_walk_frames.size(),
			field.player_idle_frames.size(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		]
		print(line)
		_log(line)
		_sample_time = 0.0
		_sample_frames = 0
		_sample_wall_frames = 0
		_sample_wall_usec = 0
		_sample_update_usec = 0


func _log(line: String) -> void:
	if _perf_log == null:
		return
	_perf_log.store_line(line)
	_perf_log.flush()
