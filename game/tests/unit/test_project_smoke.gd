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


func test_engine_version_matches_pinned_version() -> void:
	var version_file := FileAccess.open("res://.godot-version", FileAccess.READ)
	assert_not_null(version_file, "res://.godot-version must exist")
	if version_file == null:
		return
	var pinned := version_file.get_as_text().strip_edges()
	assert_false(pinned.is_empty(), "res://.godot-version must not be empty")
	var pinned_parts := pinned.split("-", true, 1)
	var info := Engine.get_version_info()
	var actual_version := "%d.%d.%d" % [
		int(info.get("major", 0)),
		int(info.get("minor", 0)),
		int(info.get("patch", 0)),
	]
	assert_eq(actual_version, pinned_parts[0], "engine patch version must match the pin")
	if pinned_parts.size() > 1:
		assert_eq(
			str(info.get("status", "")).to_lower(),
			pinned_parts[1].to_lower(),
			"engine release status must match the pin"
		)


func test_export_presets_cover_linux_windows_and_macos() -> void:
	var text := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_false(text.is_empty(), "export_presets.cfg must exist")
	assert_string_contains(text, 'platform="Linux"')
	assert_string_contains(text, 'platform="Windows Desktop"')
	assert_string_contains(text, 'platform="macOS"')
	assert_string_contains(text, 'exclude_filter="tests/*,addons/gut/*"')
