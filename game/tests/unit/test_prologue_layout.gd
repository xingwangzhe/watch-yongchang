extends GutTest

const PrologueScript := preload("res://scripts/actors/prologue.gd")

var _prologue: Object


func before_each() -> void:
	_prologue = PrologueScript.new()


func after_each() -> void:
	_prologue.free()


func test_wide_viewport_ground_and_water_fill_the_whole_width() -> void:
	var view_size := Vector2(1920.0, 962.0)
	var ground: Rect2 = _prologue.ground_rect(view_size)
	var water: Rect2 = _prologue.water_rect(view_size)
	assert_eq(ground.position.x, 0.0)
	assert_eq(ground.size.x, view_size.x)
	assert_eq(ground.end.y, view_size.y)
	assert_eq(water.position.x, 0.0)
	assert_eq(water.size.x, view_size.x)


func test_wide_viewport_centers_the_1280_stage_and_its_markers() -> void:
	assert_eq(_prologue.stage_offset_for_width(1280.0), 0.0)
	assert_eq(_prologue.stage_offset_for_width(1920.0), 320.0)
	assert_eq(_prologue.stage_offset_for_width(2560.0), 640.0)
	var lamp: Vector2 = _prologue.marker_position("lamp", 1920.0)
	var stake: Vector2 = _prologue.marker_position("stake", 1920.0)
	var banner: Vector2 = _prologue.marker_position("banner", 1920.0)
	assert_eq(lamp, Vector2(1206.0, 218.0))
	assert_eq(stake, Vector2(1378.0, 410.0))
	assert_eq(banner, Vector2(824.0, 486.0))
	for point in [lamp, stake, banner]:
		assert_true(point.x > 0.0 and point.x < 1920.0)


func test_stage_does_not_shift_left_on_narrow_viewports() -> void:
	assert_eq(_prologue.stage_offset_for_width(960.0), 0.0)
	assert_eq(_prologue.marker_position("banner", 960.0), Vector2(504.0, 486.0))


func test_player_follows_stage_when_viewport_becomes_wider() -> void:
	assert_eq(
		_prologue.shift_player_x_for_view_change(640.0, 1280.0, 1920.0),
		960.0
	)
	assert_eq(
		_prologue.shift_player_x_for_view_change(960.0, 1920.0, 1280.0),
		640.0
	)


func test_interacting_outside_marker_range_gives_recoverable_bilingual_feedback() -> void:
	var scene := load("res://scenes/prologue.tscn") as PackedScene
	var prologue := scene.instantiate()
	add_child_autofree(prologue)
	await wait_process_frames(2)
	prologue.story._skip_all()
	await wait_process_frames(1)

	var objective := prologue.get("_objective") as Label
	var player_pos: Vector2 = prologue.get("_player_pos")
	var marker_pos: Vector2 = prologue.call("_marker_position", "lamp")
	var done: Dictionary = prologue.get("_done")
	assert_gt(player_pos.distance_to(marker_pos), 70.0)
	prologue.call("_try_interact")
	assert_eq(objective.text, Locale.t("prologue.too_far"))
	assert_false(bool(done["lamp"]), "a rejected interaction must keep the objective pending")
	prologue.get("_interaction_hint_timer").stop()
	prologue.call("_restore_objective_after_interaction_hint")
	assert_eq(objective.text, Locale.t("prologue.goal_lamp"))

	var original_language := Locale.current
	Locale.set_language("en", false)
	assert_false(Locale.t("prologue.too_far").is_empty())
	Locale.set_language(original_language, false)
