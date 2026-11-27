class_name PrologueTouchControls
extends Control
## 序章专用轻量触控：移动摇杆与交互键，不显示正篇攻击按钮。

signal interact_pressed

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const GOLD := Color("#e1b35a")
const PAPER := Color("#efe1c2")
const JOYSTICK_RADIUS := 68.0
const INTERACT_SIZE := Vector2(156.0, 82.0)

var enabled := false
var move_vector := Vector2.ZERO
var _move_touch := -1
var _move_center := Vector2.ZERO
var _move_point := Vector2.ZERO
var _scale_x := 1.0
var _scale_y := 1.0
var _joystick_radius := JOYSTICK_RADIUS


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process_input(true)
	resized.connect(_refresh_layout)
	get_viewport().size_changed.connect(_refresh_layout)
	_refresh_layout()


func _refresh_layout() -> void:
	var css_size := _css_view_size()
	_apply_layout(size, css_size)


func _apply_layout(view_size: Vector2, css_size: Vector2) -> void:
	if css_size.x <= 0.0 or css_size.y <= 0.0:
		return
	_scale_x = view_size.x / css_size.x
	_scale_y = view_size.y / css_size.y
	_joystick_radius = JOYSTICK_RADIUS * minf(_scale_x, _scale_y)
	if _move_touch < 0:
		_move_center = _joystick_rest_position()
		_move_point = _move_center
	queue_redraw()


func _css_view_size() -> Vector2:
	if OS.has_feature("web"):
		var parsed: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify([window.innerWidth, window.innerHeight])", true)))
		if parsed is Array and (parsed as Array).size() >= 2:
			return Vector2(float(parsed[0]), float(parsed[1]))
	var window_size := DisplayServer.window_get_size()
	return Vector2(window_size.x, window_size.y)


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _interact_rect().has_point(touch.position):
				interact_pressed.emit()
				get_viewport().set_input_as_handled()
			elif _move_touch < 0 and touch.position.x < size.x * 0.48 and touch.position.y > size.y * 0.42:
				_move_touch = touch.index
				_move_center = _joystick_rest_position()
				_update_move(touch.position)
		else:
			if touch.index == _move_touch:
				_move_touch = -1
				move_vector = Vector2.ZERO
				queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _move_touch:
			_update_move(drag.position)


func _update_move(position: Vector2) -> void:
	_move_point = _move_center + (position - _move_center).limit_length(_joystick_radius)
	var vector := (_move_point - _move_center) / _joystick_radius
	move_vector = vector if vector.length() >= 0.16 else Vector2.ZERO
	queue_redraw()


func _interact_rect() -> Rect2:
	var size_value := _interact_size()
	return Rect2(
		Vector2(size.x - size_value.x - 18.0 * _scale_x, size.y - size_value.y - _bottom_inset() * _scale_y),
		size_value
	)


func _interact_size() -> Vector2:
	return INTERACT_SIZE * Vector2(_scale_x, _scale_y)


func _joystick_rest_position() -> Vector2:
	return Vector2(18.0 * _scale_x + _joystick_radius, size.y - _bottom_inset() * _scale_y - _joystick_radius)


func _bottom_inset() -> float:
	# Baidu's embedded WebView reserves a fixed 86 px strip for its own controls.
	return 86.0 if OS.has_feature("baidu_h5") else 34.0


func _draw() -> void:
	if not enabled:
		return
	var rest := _joystick_rest_position()
	var stick := _move_point if _move_touch >= 0 else rest
	draw_circle(rest, _joystick_radius, Color(0.02, 0.03, 0.03, 0.34))
	draw_arc(rest, _joystick_radius, 0.0, TAU, 40, Color(GOLD, 0.72), 2.0, true)
	draw_circle(stick, 27.0 * minf(_scale_x, _scale_y), Color(GOLD, 0.34))
	draw_arc(stick, 27.0 * minf(_scale_x, _scale_y), 0.0, TAU, 24, Color(PAPER, 0.9), 2.0, true)
	var button := _interact_rect()
	draw_rect(button, Color(0.04, 0.05, 0.05, 0.76), true)
	draw_rect(button, Color(GOLD, 0.9), false, 2.0)
	var text_scale := minf(_scale_x, _scale_y)
	draw_string(UI_FONT, button.position + Vector2(0.0, button.size.y * 0.60), Locale.t("prologue.touch_interact"), HORIZONTAL_ALIGNMENT_CENTER, button.size.x, maxi(16, roundi(20.0 * text_scale)), PAPER)
	draw_string(UI_FONT, rest + Vector2(-_joystick_radius, _joystick_radius + 21.0 * text_scale), Locale.t("prologue.touch_move"), HORIZONTAL_ALIGNMENT_CENTER, _joystick_radius * 2.0, maxi(14, roundi(15.0 * text_scale)), PAPER)
