extends Node2D

var time := 0.0


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	for i in 48:
		var x := fmod(i * 97.0 + time * 22.0, 640.0)
		var y := 168.0 + fmod(i * 53.0, 176.0)
		var alpha := 0.14 + 0.12 * sin(time * 2.2 + i * 0.7)
		var length := 5.0 + float(i % 4) * 2.0
		draw_line(
			Vector2(x, y),
			Vector2(x + length, y),
			Color(0.42, 0.78, 0.78, alpha),
			1.0
		)
