class_name OilMeter
extends Control

var current := 6
var maximum := 6
var dark := false


func set_values(value: int, max_value: int, is_dark: bool) -> void:
	current = value
	maximum = max_value
	dark = is_dark
	queue_redraw()


func _draw() -> void:
	var segments := maxi(maximum, 1)
	var gap := 4.0
	var width := minf(22.0, (size.x - gap * float(segments - 1)) / float(segments))
	for i in range(segments):
		var rect := Rect2(Vector2(i * (width + gap), 8.0), Vector2(width, 13.0))
		var filled := i < current
		var color := Color("#d8a548") if filled else Color(0.27, 0.24, 0.18, 0.9)
		if dark and not filled:
			color = Color(0.20, 0.20, 0.24, 0.9)
		draw_rect(rect, color)
		draw_rect(rect, Color(0.95, 0.82, 0.53, 0.38 if filled else 0.15), false, 1.0)
	if dark:
		draw_circle(Vector2(size.x + 10.0, 15.0), 5.0, Color(0.55, 0.59, 0.72, 0.75))
