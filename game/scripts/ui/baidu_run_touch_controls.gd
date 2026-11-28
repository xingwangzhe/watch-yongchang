extends "res://scripts/ui/touch_controls.gd"
## Baidu offline H5 controls. It inherits the gameplay interface, not the Web JS probes.

const WEBVIEW_RESERVED_BOTTOM := 86.0
const NATIVE_BACK_SAFE_LEFT := 60.0
const JOYSTICK_BACK_GAP := 12.0
const BAIDU_JADE := Color("#7fb7a8")

var _move_touch := -1
var _baidu_attack_touch := -1
var _move_center := Vector2.ZERO
var _move_point := Vector2.ZERO


func _ready() -> void:
	name = "TouchControls"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	force_visible = true
	visible = true
	get_viewport().size_changed.connect(_on_baidu_resized)
	_on_baidu_resized()
	set_process_input(true)


func _on_baidu_resized() -> void:
	var viewport_size := size
	ui_scale = clampf(minf(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y), MIN_UI_SCALE, MAX_UI_SCALE)
	joystick_radius = JOYSTICK_RADIUS * ui_scale
	attack_radius = ATTACK_RADIUS * ui_scale
	dash_radius = DASH_RADIUS * ui_scale
	auto_radius = AUTO_RADIUS * ui_scale
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or not enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_handle_touch_down(touch.index, touch.position)
		else:
			_handle_touch_up(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _move_touch:
			_update_move(drag.position)


func _handle_touch_down(index: int, position: Vector2) -> void:
	using_touch = true
	if _button_hit("attack", position):
		if _baidu_attack_touch < 0:
			_baidu_attack_touch = index
			attack_pressed.emit()
	elif _button_hit("dash", position):
		dash_requested.emit()
	elif _button_hit("auto", position):
		auto_toggle_requested.emit()
	elif _move_touch < 0 and position.x < size.x * 0.50 and position.y > size.y * 0.38:
		_move_touch = index
		_move_center = _baidu_joystick_center()
		_update_move(position)
	get_viewport().set_input_as_handled()


func _handle_touch_up(index: int) -> void:
	if index == _move_touch:
		_move_touch = -1
		move_vector = Vector2.ZERO
	if index == _baidu_attack_touch:
		_baidu_attack_touch = -1
		attack_released.emit()
	queue_redraw()


func _update_move(position: Vector2) -> void:
	_move_point = _move_center + (position - _move_center).limit_length(joystick_radius)
	var vector := (_move_point - _move_center) / maxf(1.0, joystick_radius)
	move_vector = vector if vector.length() >= 0.16 else Vector2.ZERO
	queue_redraw()


func _button_center(kind: String) -> Vector2:
	var scale_value := ui_scale
	var bottom := size.y - WEBVIEW_RESERVED_BOTTOM - 24.0 * ui_scale
	match kind:
		"attack":
			return Vector2(size.x - 94.0 * scale_value, bottom - 70.0 * scale_value)
		"dash":
			return Vector2(size.x - 238.0 * scale_value, bottom - 58.0 * scale_value)
		"auto":
			return Vector2(size.x - 68.0 * scale_value, maxf(86.0, bottom - 245.0 * scale_value))
	return Vector2.ZERO


func _button_hit(kind: String, position: Vector2) -> bool:
	var radius := attack_radius if kind == "attack" else dash_radius if kind == "dash" else auto_radius
	return position.distance_to(_button_center(kind)) <= radius


func _baidu_joystick_center() -> Vector2:
	return Vector2(NATIVE_BACK_SAFE_LEFT + JOYSTICK_BACK_GAP + joystick_radius, size.y - WEBVIEW_RESERVED_BOTTOM - 24.0 * ui_scale - joystick_radius)


func _draw() -> void:
	if not visible:
		return
	var rest := _baidu_joystick_center()
	var stick := _move_point if _move_touch >= 0 else rest
	draw_circle(rest, joystick_radius + 8.0 * ui_scale, Color(0.01, 0.02, 0.02, 0.48))
	draw_arc(rest, joystick_radius, 0.0, TAU, 48, Color(GOLD, 0.68), 1.5 * ui_scale, true)
	var knob_radius := 28.0 * ui_scale
	draw_circle(stick, knob_radius, Color(0.03, 0.04, 0.04, 0.96))
	draw_arc(stick, knob_radius, 0.0, TAU, 32, Color(GOLD, 0.96), 2.5 * ui_scale, true)
	_draw_atlas_icon(JOYSTICK_ICON, stick, 30.0 * ui_scale, PAPER)
	_draw_button("attack", attack_radius, Locale.t("touch.attack"), VERMILION, ATTACK_ICON)
	_draw_button("dash", dash_radius, Locale.t("touch.dash"), GOLD, DASH_ICON)
	_draw_button("auto", auto_radius, Locale.t("touch.auto"), BAIDU_JADE, AUTO_ICON)


func _draw_button(kind: String, radius: float, label: String, color: Color, icon: Texture2D) -> void:
	var center := _button_center(kind)
	var scaled_radius := radius
	draw_circle(center, scaled_radius + 7.0 * ui_scale, Color(0.01, 0.02, 0.02, 0.48))
	draw_circle(center, scaled_radius, Color(0.09, 0.06, 0.03, 0.88))
	draw_arc(center, scaled_radius, 0.0, TAU, 40, Color(color, 0.94), 3.0 * ui_scale, true)
	_draw_atlas_icon(icon, center, minf(42.0, scaled_radius * 1.3), PAPER)
	draw_string(UI_FONT, center + Vector2(-scaled_radius, scaled_radius + 23.0 * ui_scale), label, HORIZONTAL_ALIGNMENT_CENTER, scaled_radius * 2.0, maxi(16, roundi(13.0 * ui_scale)), PAPER)


func _draw_atlas_icon(icon: Texture2D, center: Vector2, size_css: float, tint: Color) -> void:
	var icon_size := Vector2.ONE * size_css * ui_scale
	draw_texture_rect(icon, Rect2(center - icon_size * 0.5, icon_size), false, tint)


func release_all() -> void:
	if _baidu_attack_touch >= 0:
		attack_released.emit()
	_move_touch = -1
	_baidu_attack_touch = -1
	move_vector = Vector2.ZERO
	using_touch = false
	queue_redraw()
