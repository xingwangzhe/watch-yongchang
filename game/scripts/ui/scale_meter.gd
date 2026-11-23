class_name ScaleMeter
extends Control

const COLORS := {
	"red": Color("#d65342"),
	"yellow": Color("#d8b64d"),
	"blue": Color("#4c8fbf"),
	"green": Color("#5b9b61"),
	"black": Color("#34313e"),
}

var collected: Array[String] = []


func set_scales(values: Array) -> void:
	collected.clear()
	for value in values:
		collected.append(str(value))
	queue_redraw()


func _draw() -> void:
	var order := ["red", "yellow", "blue", "green", "black"]
	for i in range(order.size()):
		var color_name: String = order[i]
		var center := Vector2(12.0 + i * 26.0, 14.0)
		var unlocked := collected.has(color_name)
		var color: Color = COLORS[color_name]
		if unlocked:
			draw_circle(center, 9.0, Color(color, 0.24))
			draw_circle(center, 6.0, color)
			draw_arc(center, 10.0, 0.0, TAU, 18, Color(color, 0.88), 2.0, true)
		else:
			draw_circle(center, 7.0, Color(0.15, 0.15, 0.16, 0.9))
			draw_arc(center, 8.0, 0.0, TAU, 16, Color(0.55, 0.49, 0.37, 0.28), 1.0, true)
