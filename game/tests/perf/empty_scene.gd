extends Node2D

var _elapsed := 0.0
var _last_frame_us := 0
var _wall_usec := 0
var _wall_frames := 0


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_frame_us > 0:
		_wall_usec += now - _last_frame_us
		_wall_frames += 1
	_last_frame_us = now
	_elapsed += delta
	if _elapsed >= 1.0 and _wall_usec > 0:
		print("[empty] wall_fps=%.1f wall_frame_ms=%.2f engine_fps=%.1f" % [
			float(_wall_frames) * 1000000.0 / float(_wall_usec),
			float(_wall_usec) / 1000.0 / float(maxi(1, _wall_frames)),
			Engine.get_frames_per_second(),
		])
		_elapsed = 0.0
		_wall_usec = 0
		_wall_frames = 0
