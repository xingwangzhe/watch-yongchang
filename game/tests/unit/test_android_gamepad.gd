extends GutTest


func test_android_gamepad_defaults_cover_movement_combat_and_actions() -> void:
	InputSetup.reset_to_defaults()
	assert_true(_has_axis("move_left", JOY_AXIS_LEFT_X, -1.0))
	assert_true(_has_axis("move_right", JOY_AXIS_LEFT_X, 1.0))
	assert_true(_has_axis("move_up", JOY_AXIS_LEFT_Y, -1.0))
	assert_true(_has_axis("move_down", JOY_AXIS_LEFT_Y, 1.0))
	assert_true(_has_button("move_left", JOY_BUTTON_DPAD_LEFT))
	assert_true(_has_button("move_right", JOY_BUTTON_DPAD_RIGHT))
	assert_true(_has_button("move_up", JOY_BUTTON_DPAD_UP))
	assert_true(_has_button("move_down", JOY_BUTTON_DPAD_DOWN))
	assert_true(_has_button("attack", JOY_BUTTON_A))
	assert_true(_has_button("dash", JOY_BUTTON_B))
	assert_true(_has_button("interact", JOY_BUTTON_X))
	assert_true(_has_button("toggle_codex", JOY_BUTTON_Y))
	assert_true(_has_button("toggle_auto_attack", JOY_BUTTON_BACK))


func _has_axis(action: String, axis: int, value: float) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			if motion.axis == axis and is_equal_approx(motion.axis_value, value):
				return true
	return false


func _has_button(action: String, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false
