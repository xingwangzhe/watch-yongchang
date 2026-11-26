extends GutTest


func test_project_smoke_config() -> void:
	assert_eq(Engine.get_version_info().major, 4, "must run on Godot 4")
	assert_eq(
		ProjectSettings.get_setting("application/config/name"),
		ProjectMeta.game_name_zh,
		"project name must match generated metadata"
	)
	assert_eq(
		ProjectSettings.get_setting("application/config/version"),
		ProjectMeta.version,
		"project version must match generated metadata"
	)
	assert_eq(
		ProjectSettings.get_setting("application/config/icon"),
		ProjectMeta.icon_path,
		"project icon must match generated metadata"
	)
	assert_eq(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		1280,
		"base viewport width must be 1280"
	)
	assert_eq(
		ProjectSettings.get_setting("display/window/stretch/scale_mode"),
		"fractional",
		"small mobile screens must scale to fit the game viewport"
	)


func test_mobile_web_requests_landscape_mode() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_string_contains(project, 'window/handheld/orientation="landscape"')
	assert_string_contains(presets, 'progressive_web_app/enabled=true')
	assert_string_contains(presets, 'progressive_web_app/orientation=1')
	assert_string_contains(presets, 'viewport-fit=cover')


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


func test_export_presets_cover_linux_windows_macos_and_web() -> void:
	var text := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_false(text.is_empty(), "export_presets.cfg must exist")
	var project := FileAccess.get_file_as_string("res://project.godot")
	assert_false(project.contains("GdaHarness="), "development harness must not be a release autoload")
	assert_string_contains(text, 'platform="Linux"')
	assert_string_contains(text, 'platform="Windows Desktop"')
	assert_string_contains(text, 'platform="macOS"')
	assert_string_contains(text, 'platform="Web"')
	assert_eq(
		text.count('binary_format/embed_pck=false'),
		3,
		'all desktop presets must use an external PCK'
	)
	assert_string_contains(text, 'variant/thread_support=false')
	assert_string_contains(
		text,
		'progressive_web_app/ensure_cross_origin_isolation_headers=false'
	)
	assert_string_contains(text, 'exclude_filter="build/*,export/*,*.import,')
	assert_string_contains(text, "tests/*,addons/gut/*,addons/gda_harness/*")
	assert_string_contains(text, 'assets/character_forge/*')
	assert_string_contains(text, 'assets/fonts/LXGWWenKai-Regular.ttf')
	assert_string_contains(text, 'scenes/dev/*')
	assert_string_contains(
		project,
		'theme/custom_font="res://assets/fonts/LXGWWenKai-Regular.woff2"'
	)
	assert_string_contains(text, 'application/copyright="Code AGPL-3.0-or-later;')
	assert_string_contains(
		text,
		'application/product_name="%s"' % ProjectMeta.game_name_zh
	)
	assert_string_contains(
		text,
		'application/company_name="%s"' % ProjectMeta.author
	)
	assert_string_contains(
		text,
		'application/bundle_identifier="%s"' % ProjectMeta.bundle_identifier
	)
	assert_string_contains(text, 'application/short_version="%s"' % ProjectMeta.version)
	assert_string_contains(
		text,
		'application/version="%s"' % ProjectMeta.version
	)
	assert_string_contains(text, ProjectMeta.repo_url)
	assert_false(text.contains("Code GPL-3.0-or-later"), "export metadata must use AGPL")
	assert_string_contains(text, 'include_filter="LICENSE,NOTICE,LICENSE-CC-BY-4.0.txt,')
	var code_license := FileAccess.get_file_as_string("res://LICENSE")
	var asset_license := FileAccess.get_file_as_string("res://LICENSE-CC-BY-4.0.txt")
	var notice := FileAccess.get_file_as_string("res://NOTICE")
	assert_string_contains(code_license, "GNU AFFERO GENERAL PUBLIC LICENSE")
	assert_string_contains(asset_license, "Attribution 4.0 International")
	assert_string_contains(notice, "AGPL-3.0-or-later")
	assert_string_contains(notice, "CC BY 4.0")
