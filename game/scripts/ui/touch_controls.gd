class_name TouchControls
extends Control

signal dash_requested
signal attack_pressed
signal attack_released
signal auto_toggle_requested

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const GOLD := Color("#e1b35a")
const PAPER := Color("#efe1c2")
const VERMILION := Color("#c05a41")

const JOYSTICK_RADIUS := 62.0
const ATTACK_RADIUS := 58.0
const DASH_RADIUS := 38.0
const AUTO_RADIUS := 32.0

var move_vector := Vector2.ZERO
var enabled := true
var force_visible := false
var using_touch := false
var auto_active := false

var _joystick_touch := -1
var _attack_touch := -1
var _dash_touch := -1
var _auto_touch := -1
var _joystick_center := Vector2.ZERO
var _attack_center := Vector2.ZERO
var _dash_center := Vector2.ZERO
var _auto_center := Vector2.ZERO
var _patrol_label: Label
var _attack_label: Label
var _dash_label: Label
var _auto_label: Label


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
	_attack_center = Vector2(viewport_size.x * 0.85, viewport_size.y * 0.70)
	_dash_center = Vector2(viewport_size.x * 0.92, viewport_size.y * 0.80)
	_auto_center = Vector2(viewport_size.x * 0.73, viewport_size.y * 0.60)
	if _patrol_label != null:
		UILayout.place(
			_patrol_label,
			_joystick_center.x - 72.0, _joystick_center.y + JOYSTICK_RADIUS + 10.0,
			144.0, 22.0
		)
	if _attack_label != null:
		UILayout.place(
			_attack_label,
			_attack_center.x - 56.0, _attack_center.y + ATTACK_RADIUS + 10.0,
			112.0, 22.0
		)
	if _dash_label != null:
		UILayout.place(
			_dash_label,
			_dash_center.x - 52.0, _dash_center.y + DASH_RADIUS + 8.0,
			104.0, 20.0
		)
	if _auto_label != null:
		UILayout.place(
			_auto_label,
			_auto_center.x - 42.0, _auto_center.y + AUTO_RADIUS + 6.0,
			84.0, 20.0
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
			using_touch = true
			if _joystick_touch < 0 and position.distance_to(_joystick_center) <= JOYSTICK_RADIUS * 1.32:
				_joystick_touch = touch.index
				_update_joystick(position)
				get_viewport().set_input_as_handled()
			elif _attack_touch < 0 and position.distance_to(_attack_center) <= ATTACK_RADIUS * 1.2:
				_attack_touch = touch.index
				attack_pressed.emit()
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif _auto_touch < 0 and position.distance_to(_auto_center) <= AUTO_RADIUS * 1.25:
				_auto_touch = touch.index
				auto_active = not auto_active
				auto_toggle_requested.emit()
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif _dash_touch < 0 and position.distance_to(_dash_center) <= DASH_RADIUS * 1.25:
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
			elif touch.index == _attack_touch:
				_attack_touch = -1
				attack_released.emit()
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif touch.index == _auto_touch:
				_auto_touch = -1
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
	var was_attacking := _attack_touch >= 0
	_joystick_touch = -1
	_attack_touch = -1
	_dash_touch = -1
	_auto_touch = -1
	move_vector = Vector2.ZERO
	if was_attacking:
		attack_released.emit()
	queue_redraw()


func set_auto_active(active: bool) -> void:
	auto_active = active
	queue_redraw()


func _update_joystick(position: Vector2) -> void:
	move_vector = (position - _joystick_center) / JOYSTICK_RADIUS
	move_vector = move_vector.limit_length(1.0)
	if move_vector.length() < 0.12:
		move_vector = Vector2.ZERO
	queue_redraw()


func _build_labels() -> void:
	_patrol_label = _label(Locale.t("touch.patrol"), 13, Color(PAPER, 0.88))
	_patrol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_patrol_label)
	_attack_label = _label(Locale.t("touch.attack"), 13, Color(PAPER, 0.92))
	_attack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_attack_label)
	_dash_label = _label(Locale.t("touch.dash"), 11, Color(GOLD, 0.92))
	_dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_dash_label)
	_auto_label = _label(Locale.t("touch.auto"), 11, Color(GOLD, 0.92))
	_auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_auto_label)


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
	_draw_auto()
	_draw_attack()
	_draw_dash()


func _draw_joystick() -> void:
	draw_circle(_joystick_center, JOYSTICK_RADIUS + 8.0, Color(0.01, 0.02, 0.02, 0.48))
	draw_arc(_joystick_center, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(GOLD, 0.42), 1.5)
	draw_arc(_joystick_center, JOYSTICK_RADIUS * 0.52, 0.0, TAU, 32, Color(GOLD, 0.20), 1.0)
	for i in range(8):
		var direction := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
		draw_line(
			_joystick_center + direction * (JOYSTICK_RADIUS * 0.70),
			_joystick_center + direction * (JOYSTICK_RADIUS * 0.86),
			Color(GOLD, 0.26),
			1.0
		)
	var knob := _joystick_center + move_vector * JOYSTICK_RADIUS * 0.56
	draw_circle(knob, 24.0, Color(0.10, 0.07, 0.03, 0.94))
	draw_arc(knob, 24.0, 0.0, TAU, 32, Color(GOLD, 0.88), 2.0)
	draw_circle(knob, 6.0, Color(VERMILION, 0.92))


func _draw_attack() -> void:
	var active := _attack_touch >= 0
	draw_circle(_attack_center, ATTACK_RADIUS + 8.0, Color(0.01, 0.02, 0.02, 0.52))
	draw_circle(
		_attack_center,
		ATTACK_RADIUS,
		Color(0.16, 0.08, 0.04, 0.92) if active else Color(0.09, 0.06, 0.03, 0.86)
	)
	draw_arc(
		_attack_center,
		ATTACK_RADIUS,
		0.0,
		TAU,
		40,
		Color(VERMILION, 1.0 if active else 0.82),
		3.0
	)
	var blade_dir := Vector2.RIGHT.rotated(-0.62)
	draw_line(
		_attack_center - blade_dir * 18.0,
		_attack_center + blade_dir * 18.0,
		Color(PAPER, 0.98),
		4.0
	)
	draw_line(
		_attack_center + blade_dir * 18.0,
		_attack_center + blade_dir * 6.0 + Vector2(-7, -8),
		Color(GOLD, 0.98),
		2.0
	)


func _draw_auto() -> void:
	draw_circle(_auto_center, AUTO_RADIUS + 6.0, Color(0.01, 0.02, 0.02, 0.48))
	draw_arc(
		_auto_center,
		AUTO_RADIUS,
		0.0,
		TAU,
		32,
		Color(GOLD, 0.96 if auto_active else 0.58),
		2.0 if auto_active else 1.2
	)
	if auto_active:
		draw_circle(_auto_center, AUTO_RADIUS - 6.0, Color(GOLD, 0.20))
	draw_line(_auto_center + Vector2(-9, -7), _auto_center + Vector2(9, 0), Color(PAPER, 0.96), 2.0)
	draw_line(_auto_center + Vector2(9, 0), _auto_center + Vector2(-9, 7), Color(PAPER, 0.96), 2.0)


func _draw_dash() -> void:
	draw_circle(_dash_center, DASH_RADIUS + 8.0, Color(0.01, 0.02, 0.02, 0.48))
	draw_arc(_dash_center, DASH_RADIUS, 0.0, TAU, 40, Color(GOLD, 0.70), 2.0)
	draw_arc(_dash_center, DASH_RADIUS - 8.0, -PI * 0.72, PI * 0.72, 24, Color(VERMILION, 0.72), 3.0)
	var forward := Vector2.RIGHT.rotated(-0.35)
	draw_line(_dash_center - forward * 14.0, _dash_center + forward * 14.0, Color(GOLD, 0.96), 3.0)
	draw_line(_dash_center + forward * 14.0, _dash_center + forward * 6.0 + Vector2(-4, -6), Color(GOLD, 0.96), 2.0)
	draw_line(_dash_center + forward * 14.0, _dash_center + forward * 6.0 + Vector2(-4, 6), Color(GOLD, 0.96), 2.0)
