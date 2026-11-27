extends GutTest


func test_baidu_touch_layout_keeps_back_gesture_and_webview_reserved_area() -> void:
	var controls: Control = preload("res://scenes/components/baidu_run_touch_controls.tscn").instantiate()
	add_child_autofree(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	controls.size = Vector2(390.0, 844.0)
	controls.call("_on_baidu_resized")

	var center: Vector2 = controls.call("_baidu_joystick_center")
	var joystick_radius := float(controls.get("joystick_radius"))
	var ui_scale := float(controls.get("ui_scale"))
	assert_gte(center.x - joystick_radius, 71.99, "Joystick must leave 60px back zone plus 12px gap.")
	assert_almost_eq(
		controls.size.y - center.y - joystick_radius,
		86.0 + 24.0 * ui_scale,
		0.01,
		"Joystick must remain above the WebView reserved strip."
	)
