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

## 以 1280×720 为设计基准。窄窗口 / Web 窄屏自动显示；桌面宽屏默认隐藏。
const REFERENCE_SIZE := Vector2(1280.0, 720.0)
const MIN_UI_SCALE := 0.72
const MAX_UI_SCALE := 1.3
const NARROW_WIDTH := 900.0
const WEB_NARROW_WIDTH := 1100.0

var move_vector := Vector2.ZERO
var enabled := true
## 设为 true 强制显示；run_game.gd 的 touch 模式会设置此项。
var force_visible := false
var using_touch := false
var auto_active := false

## 相对 1280×720 的缩放系数与实际半径，供命中判定、绘制与标签共用。
var ui_scale := 1.0
var joystick_radius := JOYSTICK_RADIUS
var attack_radius := ATTACK_RADIUS
var dash_radius := DASH_RADIUS
var auto_radius := AUTO_RADIUS

var _joystick_touch := -1
var _attack_touch := -1
var _dash_touch := -1
var _auto_touch := -1
var _orientation_touch := -1
var _joystick_center := Vector2.ZERO
var _attack_center := Vector2.ZERO
var _dash_center := Vector2.ZERO
var _auto_center := Vector2.ZERO
var _orientation_center := Vector2.ZERO
var _patrol_label: Label
var _attack_label: Label
var _dash_label: Label
var _auto_label: Label
var _label_specs: Array[Dictionary] = []

## Mobile web: safe area insets (notch, home indicator)
var _safe_left := 0.0
var _safe_top := 0.0
var _safe_right := 0.0
var _safe_bottom := 0.0
var _is_mobile_web := false
var _rotate_prompt: Label


func _ready() -> void:
	name = "TouchControls"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_is_mobile_web = OS.has_feature("web") and bool(GameSettings.web_capabilities.get("touch", false))
	if _is_mobile_web and not DisplayServer.orientation_changed.is_connected(_on_orientation_changed):
		DisplayServer.orientation_changed.connect(_on_orientation_changed)

	# Listen for safe area changes (mobile web + native)
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		_update_safe_area()
	get_viewport().size_changed.connect(_on_resized)

	_apply_visibility()
	_build_labels()
	_build_rotate_prompt()
	_layout()
	resized.connect(_on_resized)
	set_process_input(visible)


func _default_visible() -> bool:
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		return true
	var width := get_viewport_rect().size.x
	if width < NARROW_WIDTH:
		return true
	return OS.has_feature("web") and width < WEB_NARROW_WIDTH


func _apply_visibility() -> void:
	var should_show := force_visible or _default_visible()
	visible = should_show
	set_process_input(should_show)


func _on_resized() -> void:
	_apply_visibility()
	_update_safe_area()
	_layout()
	_update_rotate_prompt()


func _update_safe_area() -> void:
	if not (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
		_safe_left = 0.0
		_safe_top = 0.0
		_safe_right = 0.0
		_safe_bottom = 0.0
		return
	# Browser CSS env() insets are needed for phones with a notch or home indicator.
	if OS.has_feature("web"):
		var raw_insets: Variant = JavaScriptBridge.eval(
			"""(() => {
				const probe = document.createElement('div');
				probe.style.cssText = 'position:fixed;inset:0;visibility:hidden;pointer-events:none;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);box-sizing:border-box';
				document.body.appendChild(probe);
				const style = getComputedStyle(probe);
				const values = [style.paddingLeft, style.paddingTop, style.paddingRight, style.paddingBottom, window.innerWidth, window.innerHeight].map(value => parseFloat(value));
				probe.remove();
				return JSON.stringify(values);
			})()""",
			true
		)
		var parsed: Variant = JSON.parse_string(str(raw_insets))
		if parsed is Array and parsed.size() >= 6:
			var values: Array = parsed
			var viewport_size := get_viewport_rect().size
			var scale_x := viewport_size.x / maxf(1.0, float(values[4]))
			var scale_y := viewport_size.y / maxf(1.0, float(values[5]))
			_safe_left = float(values[0]) * scale_x
			_safe_top = float(values[1]) * scale_y
			_safe_right = float(values[2]) * scale_x
			_safe_bottom = float(values[3]) * scale_y
		else:
			_safe_left = 0.0
			_safe_top = 0.0
			_safe_right = 0.0
			_safe_bottom = 0.0
		return
	var safe_area := DisplayServer.get_display_safe_area()
	var viewport_size := get_viewport_rect().size
	var win_size := Vector2(DisplayServer.window_get_size().x, DisplayServer.window_get_size().y)

	# Convert screen pixels to UI units
	var scale_x := viewport_size.x / win_size.x if win_size.x > 0 else 1.0
	var scale_y := viewport_size.y / win_size.y if win_size.y > 0 else 1.0

	_safe_left = safe_area.position.x * scale_x
	_safe_top = safe_area.position.y * scale_y
	_safe_right = (win_size.x - safe_area.end.x) * scale_x
	_safe_bottom = (win_size.y - safe_area.end.y) * scale_y


func _on_orientation_changed(orientation: int) -> void:
	_update_safe_area()
	_layout()
	_update_rotate_prompt()


func _build_rotate_prompt() -> void:
	if not OS.has_feature("web"):
		return
	_rotate_prompt = Label.new()
	_rotate_prompt.text = "点击右上角切换横竖屏 / Tap top right to rotate"
	_rotate_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotate_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotate_prompt.add_theme_font_override("font", UI_FONT)
	_rotate_prompt.add_theme_font_size_override("font_size", 28)
	_rotate_prompt.add_theme_color_override("font_color", PAPER)
	_rotate_prompt.add_theme_color_override("font_outline_color", Color("#071216"))
	_rotate_prompt.add_theme_constant_override("outline_size", 4)
	_rotate_prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotate_prompt.z_index = 100
	add_child(_rotate_prompt)
	_update_rotate_prompt()


func _update_rotate_prompt() -> void:
	if not is_instance_valid(_rotate_prompt):
		return
	var viewport_size := get_viewport_rect().size
	_rotate_prompt.visible = false


func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	var scale_x := viewport_size.x / REFERENCE_SIZE.x
	var scale_y := viewport_size.y / REFERENCE_SIZE.y
	ui_scale = clampf(minf(scale_x, scale_y), MIN_UI_SCALE, MAX_UI_SCALE)
	joystick_radius = JOYSTICK_RADIUS * ui_scale
	attack_radius = ATTACK_RADIUS * ui_scale
	dash_radius = DASH_RADIUS * ui_scale
	auto_radius = AUTO_RADIUS * ui_scale

	# Layout with safe area insets
	var safe_w := viewport_size.x - _safe_left - _safe_right
	var safe_h := viewport_size.y - _safe_top - _safe_bottom

	var portrait := viewport_size.y > viewport_size.x
	if portrait:
		_joystick_center = Vector2(_safe_left + safe_w * 0.18, _safe_top + safe_h * 0.82)
		_attack_center = Vector2(_safe_left + safe_w * 0.81, _safe_top + safe_h * 0.82)
		_dash_center = Vector2(_safe_left + safe_w * 0.84, _safe_top + safe_h * 0.64)
		_auto_center = Vector2(_safe_left + safe_w * 0.63, _safe_top + safe_h * 0.61)
	else:
		_joystick_center = Vector2(_safe_left + safe_w * 0.12, _safe_top + safe_h * 0.72)
		_attack_center = Vector2(_safe_left + safe_w * 0.85, _safe_top + safe_h * 0.70)
		_dash_center = Vector2(_safe_left + safe_w * 0.92, _safe_top + safe_h * 0.80)
		_auto_center = Vector2(_safe_left + safe_w * 0.73, _safe_top + safe_h * 0.60)
	_orientation_center = Vector2(_safe_left + safe_w - 34.0 * ui_scale, _safe_top + 34.0 * ui_scale)

	# Ensure minimum distance from edges
	_joystick_center.x = maxf(_joystick_center.x, _safe_left + joystick_radius + 12.0 * ui_scale)
	_joystick_center.y = minf(_joystick_center.y, _safe_top + safe_h - joystick_radius - 12.0 * ui_scale)
	_attack_center.x = minf(_attack_center.x, _safe_left + safe_w - attack_radius - 12.0 * ui_scale)
	_attack_center.y = minf(_attack_center.y, _safe_top + safe_h - attack_radius - 12.0 * ui_scale)
	_dash_center.x = minf(_dash_center.x, _safe_left + safe_w - dash_radius - 12.0 * ui_scale)
	_dash_center.y = minf(_dash_center.y, _safe_top + safe_h - dash_radius - 12.0 * ui_scale)
	_auto_center.x = minf(_auto_center.x, _safe_left + safe_w - auto_radius - 12.0 * ui_scale)
	_auto_center.y = maxf(_auto_center.y, _safe_top + auto_radius + 12.0 * ui_scale)

	_layout_labels(viewport_size)
	queue_redraw()


func _layout_labels(viewport_size: Vector2) -> void:
	var max_width_cap := viewport_size.x * (0.42 if viewport_size.y > viewport_size.x else 0.26)
	for spec in _label_specs:
		var label: Label = spec["label"]
		var max_width := minf(float(spec["max_width"]) * ui_scale, max_width_cap)
		var font_size := _fit_font_size(label, int(spec["size"]), max_width)
		var height := maxf(20.0 * ui_scale, float(font_size) + 8.0)
		var x := 0.0
		var y := 0.0
		if label == _patrol_label:
			x = _joystick_center.x - max_width * 0.5
			y = _joystick_center.y + joystick_radius + 10.0 * ui_scale
		elif label == _attack_label:
			x = _attack_center.x - max_width * 0.5
			y = _attack_center.y + attack_radius + 10.0 * ui_scale
		elif label == _dash_label:
			x = _dash_center.x - max_width * 0.5
			y = _dash_center.y + dash_radius + 8.0 * ui_scale
		else:
			x = _auto_center.x - max_width * 0.5
			y = _auto_center.y + auto_radius + 6.0 * ui_scale
		UILayout.place(label, x, y, max_width, height)


## 按可用宽度收缩字号，保证英文长标签不溢出按钮下方区域。
func _fit_font_size(label: Label, base_size: int, max_width: float) -> int:
	var size := maxi(8, int(round(float(base_size) * ui_scale)))
	var font: Font = label.get_theme_font("font")
	if font == null:
		return size
	while size > 8:
		if font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_width:
			break
		size -= 1
	label.add_theme_font_size_override("font_size", size)
	return size


func _input(event: InputEvent) -> void:
	if not visible or not enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var local := make_input_local(touch) as InputEventScreenTouch
		var position := local.position
		if touch.pressed:
			using_touch = true
			if _is_mobile_web and position.distance_to(_orientation_center) <= 25.0 * ui_scale:
				_orientation_touch = touch.index
				_toggle_mobile_web_orientation()
				get_viewport().set_input_as_handled()
			elif _joystick_touch < 0 and position.distance_to(_joystick_center) <= joystick_radius * 1.32:
				_joystick_touch = touch.index
				_update_joystick(position)
				get_viewport().set_input_as_handled()
			elif _attack_touch < 0 and position.distance_to(_attack_center) <= attack_radius * 1.2:
				_attack_touch = touch.index
				attack_pressed.emit()
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif _auto_touch < 0 and position.distance_to(_auto_center) <= auto_radius * 1.25:
				_auto_touch = touch.index
				auto_active = not auto_active
				auto_toggle_requested.emit()
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif _dash_touch < 0 and position.distance_to(_dash_center) <= dash_radius * 1.25:
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
			elif touch.index == _orientation_touch:
				_orientation_touch = -1
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _joystick_touch:
			return
		var local := make_input_local(drag) as InputEventScreenDrag
		_update_joystick(local.position)
		get_viewport().set_input_as_handled()


func _toggle_mobile_web_orientation() -> void:
	if not _is_mobile_web:
		return
	GameSettings.set_web_orientation(
		"landscape" if GameSettings.web_orientation == "portrait" else "portrait"
	)


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
	move_vector = (position - _joystick_center) / joystick_radius
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
	_label_specs = [
		{"label": _patrol_label, "size": 13, "max_width": 168.0},
		{"label": _attack_label, "size": 13, "max_width": 136.0},
		{"label": _dash_label, "size": 11, "max_width": 160.0},
		{"label": _auto_label, "size": 11, "max_width": 104.0},
	]


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
	if _is_mobile_web:
		var radius := 19.0 * ui_scale
		draw_circle(_orientation_center, radius + 4.0 * ui_scale, Color(0.01, 0.02, 0.02, 0.68))
		draw_arc(_orientation_center, radius, 0.0, TAU, 32, Color(GOLD, 0.9), 2.0 * ui_scale)
		var viewport_size := get_viewport_rect().size
		var icon_size := Vector2(9, 14) if viewport_size.y >= viewport_size.x else Vector2(14, 9)
		draw_rect(Rect2(_orientation_center - icon_size * ui_scale * 0.5, icon_size * ui_scale), Color(PAPER, 0.95), false, 2.0 * ui_scale)


func _draw_joystick() -> void:
	draw_circle(_joystick_center, joystick_radius + 8.0 * ui_scale, Color(0.01, 0.02, 0.02, 0.48))
	draw_arc(_joystick_center, joystick_radius, 0.0, TAU, 48, Color(GOLD, 0.42), 1.5 * ui_scale)
	draw_arc(_joystick_center, joystick_radius * 0.52, 0.0, TAU, 32, Color(GOLD, 0.20), 1.0 * ui_scale)
	for i in range(8):
		var direction := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
		draw_line(
			_joystick_center + direction * (joystick_radius * 0.70),
			_joystick_center + direction * (joystick_radius * 0.86),
			Color(GOLD, 0.26),
			1.0 * ui_scale
		)
	var knob := _joystick_center + move_vector * joystick_radius * 0.56
	var knob_radius := 24.0 * ui_scale
	draw_circle(knob, knob_radius, Color(0.10, 0.07, 0.03, 0.94))
	draw_arc(knob, knob_radius, 0.0, TAU, 32, Color(GOLD, 0.88), 2.0 * ui_scale)
	draw_circle(knob, 6.0 * ui_scale, Color(VERMILION, 0.92))


func _draw_attack() -> void:
	var active := _attack_touch >= 0
	draw_circle(_attack_center, attack_radius + 8.0 * ui_scale, Color(0.01, 0.02, 0.02, 0.52))
	draw_circle(
		_attack_center,
		attack_radius,
		Color(0.16, 0.08, 0.04, 0.92) if active else Color(0.09, 0.06, 0.03, 0.86)
	)
	draw_arc(
		_attack_center,
		attack_radius,
		0.0,
		TAU,
		40,
		Color(VERMILION, 1.0 if active else 0.82),
		3.0 * ui_scale
	)
	var blade_dir := Vector2.RIGHT.rotated(-0.62)
	draw_line(
		_attack_center - blade_dir * 18.0 * ui_scale,
		_attack_center + blade_dir * 18.0 * ui_scale,
		Color(PAPER, 0.98),
		4.0 * ui_scale
	)
	draw_line(
		_attack_center + blade_dir * 18.0 * ui_scale,
		_attack_center + blade_dir * 6.0 * ui_scale + Vector2(-7, -8) * ui_scale,
		Color(GOLD, 0.98),
		2.0 * ui_scale
	)


func _draw_auto() -> void:
	draw_circle(_auto_center, auto_radius + 6.0 * ui_scale, Color(0.01, 0.02, 0.02, 0.48))
	draw_arc(
		_auto_center,
		auto_radius,
		0.0,
		TAU,
		32,
		Color(GOLD, 0.96 if auto_active else 0.58),
		(2.0 if auto_active else 1.2) * ui_scale
	)
	if auto_active:
		draw_circle(_auto_center, auto_radius - 6.0 * ui_scale, Color(GOLD, 0.20))
	draw_line(
		_auto_center + Vector2(-9, -7) * ui_scale,
		_auto_center + Vector2(9, 0) * ui_scale,
		Color(PAPER, 0.96),
		2.0 * ui_scale
	)
	draw_line(
		_auto_center + Vector2(9, 0) * ui_scale,
		_auto_center + Vector2(-9, 7) * ui_scale,
		Color(PAPER, 0.96),
		2.0 * ui_scale
	)


func _draw_dash() -> void:
	draw_circle(_dash_center, dash_radius + 8.0 * ui_scale, Color(0.01, 0.02, 0.02, 0.48))
	draw_arc(_dash_center, dash_radius, 0.0, TAU, 40, Color(GOLD, 0.70), 2.0 * ui_scale)
	draw_arc(
		_dash_center,
		dash_radius - 8.0 * ui_scale,
		-PI * 0.72,
		PI * 0.72,
		24,
		Color(VERMILION, 0.72),
		3.0 * ui_scale
	)
	var forward := Vector2.RIGHT.rotated(-0.35)
	draw_line(
		_dash_center - forward * 14.0 * ui_scale,
		_dash_center + forward * 14.0 * ui_scale,
		Color(GOLD, 0.96),
		3.0 * ui_scale
	)
	draw_line(
		_dash_center + forward * 14.0 * ui_scale,
		_dash_center + forward * 6.0 * ui_scale + Vector2(-4, -6) * ui_scale,
		Color(GOLD, 0.96),
		2.0 * ui_scale
	)
	draw_line(
		_dash_center + forward * 14.0 * ui_scale,
		_dash_center + forward * 6.0 * ui_scale + Vector2(-4, 6) * ui_scale,
		Color(GOLD, 0.96),
		2.0 * ui_scale
	)
