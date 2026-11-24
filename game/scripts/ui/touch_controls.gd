class_name TouchControls
extends Control

signal dash_requested

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const GOLD := Color("#e1b35a")
const PAPER := Color("#efe1c2")
const VERMILION := Color("#c05a41")

var move_vector := Vector2.ZERO
var enabled := true
var force_visible := false

var _joystick_touch := -1
var _dash_touch := -1
var _joystick_center := Vector2.ZERO
var _dash_center := Vector2.ZERO
var _joystick_radius := 62.0
var _dash_radius := 48.0
var _patrol_label: Label
var _dash_label: Label


func _ready() -> void:
	name = "TouchControls"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = force_visible or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	_build_labels()
	_layout()
	resized.connect(_layout)
	set_process_input(visible)


func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	_joystick_center = Vector2(viewport_size.x * 0.12, viewport_size.y * 0.72)
	_dash_center = Vector2(viewport_size.x * 0.88, viewport_size.y * 0.72)
	if _patrol_label != null:
		UILayout.place(
			_patrol_label,
			_joystick_center.x - 72.0, _joystick_center.y + _joystick_radius + 10.0,
			144.0, 22.0
		)
	if _dash_label != null:
		UILayout.place(
			_dash_label,
			_dash_center.x - 62.0, _dash_center.y + _dash_radius + 10.0,
			124.0, 22.0
		)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or not enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var local := make_input_local(touch) as InputEventScreenTouch
		var position := local.position
		if touch.pressed:
			if _joystick_touch < 0 and position.distance_to(_joystick_center) <= _joystick_radius * 1.32:
				_joystick_touch = touch.index
				_update_joystick(position)
				get_viewport().set_input_as_handled()
			elif _dash_touch < 0 and position.distance_to(_dash_center) <= _dash_radius * 1.24:
				_dash_touch = touch.index
				dash_requested.emit()
				queue_redraw()
				get_viewport().set_input_as_handled()
		else:
			if touch.index == _joystick_touch:
				_joystick_touch = -1
				move_vector = Vector2.ZERO
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif touch.index == _dash_touch:
				_dash_touch = -1
				queue_redraw()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _joystick_touch:
			return
		var local := make_input_local(drag) as InputEventScreenDrag
		_update_joystick(local.position)
		get_viewport().set_input_as_handled()


func release_all() -> void:
	_joystick_touch = -1
	_dash_touch = -1
	move_vector = Vector2.ZERO
	queue_redraw()


func _update_joystick(position: Vector2) -> void:
	move_vector = (position - _joystick_center) / _joystick_radius
	move_vector = move_vector.limit_length(1.0)
	if move_vector.length() < 0.12:
		move_vector = Vector2.ZERO
	queue_redraw()


func _build_labels() -> void:
	_patrol_label = _label(Locale.t("touch.patrol"), 13, Color(PAPER, 0.88))
	_patrol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_patrol_label)
	_dash_label = _label(Locale.t("touch.dash"), 12, Color(GOLD, 0.92))
	_dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_dash_label)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _draw() -> void:
	if not visible:
		return
	_draw_joystick()
	_draw_dash()


func _draw_joystick() -> void:
	draw_circle(_joystick_center, _joystick_radius + 8.0, Color(0.01, 0.02, 0.02, 0.48))
	draw_arc(_joystick_center, _joystick_radius, 0.0, TAU, 48, Color(GOLD, 0.42), 1.5)
	draw_arc(_joystick_center, _joystick_radius * 0.52, 0.0, TAU, 32, Color(GOLD, 0.20), 1.0)
	for i in range(8):
		var direction := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
		draw_line(
			_joystick_center + direction * (_joystick_radius * 0.70),
			_joystick_center + direction * (_joystick_radius * 0.86),
			Color(GOLD, 0.26),
			1.0
		)
	var knob := _joystick_center + move_vector * _joystick_radius * 0.56
	draw_circle(knob, 24.0, Color(0.10, 0.07, 0.03, 0.94))
	draw_arc(knob, 24.0, 0.0, TAU, 32, Color(GOLD, 0.88), 2.0)
	draw_circle(knob, 6.0, Color(VERMILION, 0.92))


func _draw_dash() -> void:
	draw_circle(_dash_center, _dash_radius + 8.0, Color(0.01, 0.02, 0.02, 0.48))
	draw_arc(_dash_center, _dash_radius, 0.0, TAU, 40, Color(GOLD, 0.70), 2.0)
	draw_arc(_dash_center, _dash_radius - 8.0, -PI * 0.72, PI * 0.72, 24, Color(VERMILION, 0.72), 3.0)
	var forward := Vector2.RIGHT.rotated(-0.35)
	draw_line(_dash_center - forward * 18.0, _dash_center + forward * 18.0, Color(GOLD, 0.96), 3.0)
	draw_line(_dash_center + forward * 18.0, _dash_center + forward * 8.0 + Vector2(-4, -8), Color(GOLD, 0.96), 2.0)
	draw_line(_dash_center + forward * 18.0, _dash_center + forward * 8.0 + Vector2(-4, 8), Color(GOLD, 0.96), 2.0)
