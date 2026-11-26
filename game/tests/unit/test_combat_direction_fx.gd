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


func test_jeff_fx_catalog_covers_player_and_enemy_combinations() -> void:
	var data := GameData.load_json("res://data/attack_fx.json")
	var animations: Dictionary = data.get("animations", {}) as Dictionary
	var player_weapons: Dictionary = data.get("player_weapons", {}) as Dictionary
	var enemy_attacks: Dictionary = data.get("enemy_attacks", {}) as Dictionary
	var ally_attacks: Dictionary = data.get("ally_attacks", {}) as Dictionary
	assert_eq(animations.size(), 16)
	assert_eq(player_weapons.size(), 8)
	assert_eq(enemy_attacks.size(), 9)
	assert_eq(ally_attacks.size(), 10)
	assert_eq(int(data.get("player_combo_count", 0)), 24)
	assert_eq(int(data.get("enemy_combo_count", 0)), 18)
	assert_eq(int(data.get("ally_combo_count", 0)), 10)
	assert_eq(int(data.get("combination_count", 0)), 52)

	for animation_id in animations.keys():
		var animation: Dictionary = animations[animation_id] as Dictionary
		var texture_path := str(animation.get("texture", ""))
		assert_true(ResourceLoader.exists(texture_path), "%s texture is missing" % animation_id)
		assert_eq((animation.get("rects", []) as Array).size(), int(animation.get("frames", 0)))
		assert_eq((animation.get("durations", []) as Array).size(), int(animation.get("frames", 0)))
		assert_true(str(animation.get("source_recipe", "")).contains("Jeff FX"))
		var texture := load(texture_path) as Texture2D
		for rect in animation.get("rects", []) as Array:
			var frame: Array = rect as Array
			assert_true(float(frame[0]) + float(frame[2]) <= float(texture.get_width()), "%s frame exceeds atlas width" % animation_id)
			assert_true(float(frame[1]) + float(frame[3]) <= float(texture.get_height()), "%s frame exceeds atlas height" % animation_id)

	for weapon_id in GameData.get_weapons().keys():
		assert_true(player_weapons.has(weapon_id), "%s needs a Jeff FX profile" % weapon_id)
		var profile: Dictionary = player_weapons[weapon_id] as Dictionary
		assert_true(animations.has(str(profile.get("primary", ""))))
		assert_true(animations.has(str(profile.get("evolved", ""))))

	for enemy_id in GameData.get_enemies().keys():
		assert_true(enemy_attacks.has(enemy_id), "%s needs an enemy FX profile" % enemy_id)
		var profile: Dictionary = enemy_attacks[enemy_id] as Dictionary
		assert_true(animations.has(str(profile.get("muzzle", ""))))

	for mercenary_id in GameData.get_mercenaries().keys():
		assert_true(ally_attacks.has(mercenary_id), "%s needs an ally FX profile" % mercenary_id)
		var profile: Dictionary = ally_attacks[mercenary_id] as Dictionary
		assert_true(animations.has(str(profile.get("muzzle", ""))))

	for impact_id in (data.get("impacts", {}) as Dictionary).keys():
		var impact: Dictionary = data["impacts"][impact_id] as Dictionary
		assert_true(animations.has(str(impact.get("animation", ""))))


func test_enemy_sprites_mirror_horizontal_facing() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(42)
	var right_facing := field._enemy_instance_transform(Vector2(24, 36), 64.0, false, 1.0)
	var left_facing := field._enemy_instance_transform(Vector2(24, 36), 64.0, false, -1.0)
	assert_gt(right_facing.x.x, 0.0)
	assert_lt(left_facing.x.x, 0.0)
	assert_lt(left_facing.y.y, 0.0, "enemy UV correction must stay upright")


func test_jeff_fx_rotates_toward_mouse_and_stacks_impact_layers() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(42)
	field.play_player_attack_fx("saber", Vector2(100, 100), Vector2.LEFT, false)
	assert_eq(field.jeff_effects.size(), 1)
	assert_almost_eq(absf(float(field.jeff_effects[0]["rotation"])), PI, 0.01)
	field.play_impact_fx(Vector2(120, 100), "critical", 1.1)
	assert_eq(field.jeff_effects.size(), 2)
	assert_eq(str(field.jeff_effects[1]["animation_id"]), "hit_crit")
	assert_eq(field._enemy_instance_transform(Vector2.ZERO, 64.0, false, -1.0).x.x < 0.0, true)


func test_player_faces_left_movement_and_manual_hold_controls_attacks() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	await wait_process_frames(2)

	Input.action_press("move_left")
	run._update_player(1.0 / 60.0)
	Input.action_release("move_left")
	assert_lt((run.player["facing"] as Vector2).x, 0.0, "left movement must face left")

	var effects_before: int = run.battlefield.jeff_effects.size()
	run._attack_held = false
	for i in range(12):
		run._update_weapons(0.05)
	assert_eq(run.battlefield.jeff_effects.size(), effects_before, "release must stop attacks")

	run._attack_held = true
	run._aim_direction = Vector2.LEFT
	run._update_weapons(0.05)
	assert_gt(run.battlefield.jeff_effects.size(), effects_before, "holding the mouse must attack")
	assert_almost_eq(absf(float(run.battlefield.jeff_effects[-1]["rotation"])), PI, 0.01)


func test_attack_action_holds_fire_and_pause_clears_it() -> void:
	InputSetup.ensure_defaults()
	var has_mouse_bind := false
	for event in InputMap.action_get_events("attack"):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			has_mouse_bind = true
	assert_true(has_mouse_bind, "default attack action must bind the left mouse button")

	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	await wait_process_frames(2)

	Input.action_press("attack")
	run._update_player(1.0 / 60.0)
	assert_true(run._attack_held, "held attack action must set the attack flag")

	Input.action_release("attack")
	run._update_player(1.0 / 60.0)
	assert_false(run._attack_held, "releasing the attack action must stop the attack")

	Input.action_press("attack")
	run._update_player(1.0 / 60.0)
	run._set_pause(true)
	assert_false(run._attack_held, "pause must clear a held attack")
	Input.action_release("attack")


func test_mouse_motion_event_sets_aim_direction_from_screen_space() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	await wait_process_frames(2)

	var player_screen := run.get_viewport().get_canvas_transform() * (run.player["pos"] as Vector2)
	run._unhandled_input(_mouse_motion_event(player_screen + Vector2(120, 0)))
	run._update_player(1.0 / 60.0)
	assert_gt(run._aim_direction.x, 0.9, "mouse right of the player must aim right")

	run._unhandled_input(_mouse_motion_event(player_screen + Vector2(-120, 0)))
	run._update_player(1.0 / 60.0)
	assert_lt(run._aim_direction.x, -0.9, "mouse left of the player must aim left")


func _mouse_motion_event(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event
