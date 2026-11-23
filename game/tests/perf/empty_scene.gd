extends Node2D

var _elapsed := 0.0
var _frames := 0


func _process(delta: float) -> void:
	_elapsed += delta
	_frames += 1
	if _elapsed >= 1.0:
		print("[empty] fps=%.1f frame_ms=%.2f" % [
			float(_frames) / _elapsed,
			_elapsed * 1000.0 / float(maxi(1, _frames)),
		])
		_elapsed = 0.0
		_frames = 0
