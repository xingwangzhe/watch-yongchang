extends GutTest

var _tutorial_seen_before := false


func before_each() -> void:
	_tutorial_seen_before = bool(SaveSystem.data.get("tutorial_seen", false))
	SaveSystem.data["tutorial_seen"] = true
	InputSetup.ensure_defaults()


func after_each() -> void:
	SaveSystem.data["tutorial_seen"] = _tutorial_seen_before
	for action in InputSetup.ORDER:
		if Input.is_action_pressed(action):
			Input.action_release(action)
	Input.flush_buffered_events()


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


func test_joypad_axis_event_moves_the_live_player() -> void:
	InputSetup.reset_to_defaults()
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	await wait_process_frames(2)
	var start := run.player["pos"] as Vector2
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.85
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	assert_true(Input.is_action_pressed("move_right"), "physical left-stick motion must reach move_right")
	run._update_player(0.25)
	assert_gt(
		(run.player["pos"] as Vector2).x,
		start.x,
		"the same mapped controller input must move the live player"
	)
	var release_stick := InputEventJoypadMotion.new()
	release_stick.device = 0
	release_stick.axis = JOY_AXIS_LEFT_X
	release_stick.axis_value = 0.0
	Input.parse_input_event(release_stick)
	Input.flush_buffered_events()
	assert_false(Input.is_action_pressed("move_right"), "neutral stick must stop movement")


func test_android_touch_swipe_moves_the_live_player_and_attack_button_reaches_run() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	await wait_process_frames(2)
	var controls := run.touch_controls as TouchControls
	controls.force_visible = true
	controls._apply_visibility()
	controls._layout_for(Vector2(1280.0, 720.0), Vector2(1920.0, 1280.0))
	var start := run.player["pos"] as Vector2
	var center := controls._joystick_center
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = center
	controls._input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = center + Vector2(controls.joystick_radius * 0.8, 0.0)
	drag.relative = drag.position - center
	controls._input(drag)
	assert_gt(controls.move_vector.x, 0.0, "swipe from the virtual stick must create rightward input")
	run._update_player(0.25)
	assert_gt((run.player["pos"] as Vector2).x, start.x, "virtual stick input must move the live player")
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = drag.position
	controls._input(release)
	var attack := InputEventScreenTouch.new()
	attack.index = 1
	attack.pressed = true
	attack.position = controls._attack_center
	controls._input(attack)
	assert_true(run._touch_attack_held, "touch attack control must reach the live run scene")


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
