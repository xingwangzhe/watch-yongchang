extends GutTest


func test_project_smoke_config() -> void:
	assert_eq(Engine.get_version_info().major, 4, "must run on Godot 4")
	assert_eq(
		ProjectSettings.get_setting("application/config/name"),
		"守望·永昌",
		"project name must match the game"
	)
	assert_eq(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		1280,
		"base viewport width must be 1280"
	)
