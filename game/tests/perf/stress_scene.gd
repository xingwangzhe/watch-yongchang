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


func _ready() -> void:
	_debug = OS.has_environment("WATCH_STRESS_DEBUG")
	var log_path := OS.get_environment("WATCH_STRESS_LOG")
	if not log_path.is_empty():
		_perf_log = FileAccess.open(log_path, FileAccess.WRITE)
	var requested := OS.get_environment("WATCH_STRESS_COUNT")
	if not requested.is_empty():
		_enemy_count = clampi(int(requested), 1, 460)
	field = Battlefield.new()
	field.name = "Battlefield"
	add_child(field)
	field.setup(20261123)
	field.set_meta("draw_enemies", OS.get_environment("WATCH_STRESS_DRAW_ENEMIES") != "0")
	for i in range(_enemy_count):
		var angle := TAU * float(i) / float(_enemy_count)
		var ring := 120.0 + float(i % 7) * 72.0
		field.spawn_enemy_at(
			"scout" if i % 5 else "ronin",
			Vector2(cos(angle), sin(angle)) * ring
		)
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
	var update_started := Time.get_ticks_usec()
	if OS.get_environment("WATCH_STRESS_SKIP_UPDATE") != "1":
		field.update_world(delta, player)
	_sample_update_usec += Time.get_ticks_usec() - update_started
	if _debug and _debug_frames < 8:
		print("[stress] process updated frame=%d" % _debug_frames)
		_log("[stress] process updated frame=%d" % _debug_frames)
		_debug_frames += 1
	_sample_time += delta
	_sample_frames += 1
	if _sample_time >= 2.0 and _sample_wall_usec > 0:
		var wall_ms := float(_sample_wall_usec) / 1000.0 / float(maxi(1, _sample_wall_frames))
		var logic_ms := float(_sample_update_usec) / 1000.0 / float(maxi(1, _sample_frames))
		var line := "[stress] wall_fps=%.1f wall_frame_ms=%.2f logic_ms=%.3f engine_fps=%.1f enemies=%d draw_calls=%d" % [
			float(_sample_wall_frames) * 1000000.0 / float(_sample_wall_usec),
			wall_ms,
			logic_ms,
			Engine.get_frames_per_second(),
			field.alive_count(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
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
