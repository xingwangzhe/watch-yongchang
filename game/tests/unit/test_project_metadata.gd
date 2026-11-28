extends GutTest

const WebExitBridge := preload("res://scripts/ui/web_exit.gd")


func test_generated_metadata_is_runtime_readable() -> void:
	assert_true(ProjectMeta.loaded_from_file, "project_meta.json must load")
	assert_true(FileAccess.file_exists("res://data/project_meta.json"))
	assert_eq(
		ProjectMeta.version,
		str(ProjectSettings.get_setting("application/config/version", ""))
	)
	assert_eq(
		ProjectMeta.game_name_zh,
		str(ProjectSettings.get_setting("application/config/name", ""))
	)
	assert_false(ProjectMeta.godot_version.is_empty())
	assert_eq(
		ProjectMeta.godot_version,
		FileAccess.get_file_as_string("res://.godot-version").strip_edges()
	)
	assert_false(ProjectMeta.author.is_empty())
	assert_string_contains(ProjectMeta.author_email, "@")
	assert_true(ProjectMeta.repo_url.begins_with("https://"))
	assert_true(ProjectMeta.web_url.begins_with("https://"))
	assert_false(ProjectMeta.cloudflare_pages_project.is_empty())
	assert_eq(_url_host(ProjectMeta.web_url), ProjectMeta.cloudflare_pages_domain)
	assert_true(ProjectMeta.icon_path.begins_with("res://"))
	assert_true(ResourceLoader.exists(ProjectMeta.icon_path), "project icon must exist")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_string_contains(
		presets,
		'application/icon="%s"' % ProjectMeta.icon_path,
		"Windows/macOS export presets must use the generated app icon"
	)
	assert_string_contains(
		presets,
		'application/console_wrapper_icon="%s"' % ProjectMeta.icon_path,
		"Windows console wrapper must use the generated app icon"
	)


func test_about_page_displays_author_and_source_links() -> void:
	var about := (load("res://scenes/about.tscn") as PackedScene).instantiate()
	add_child_autofree(about)
	await wait_process_frames(3)
	var author := about.find_child("AboutAuthor", true, false) as Label
	var repository := about.find_child("AboutRepositoryLink", true, false) as Control
	var web := about.find_child("AboutWebLink", true, false) as Control
	assert_not_null(author)
	assert_string_contains(author.text, ProjectMeta.author)
	assert_string_contains(author.text, ProjectMeta.author_email)
	assert_not_null(repository)
	assert_eq(repository.tooltip_text, ProjectMeta.repo_url)
	assert_not_null(web)
	assert_eq(web.tooltip_text, ProjectMeta.web_url)


func test_web_quit_uses_notice_instead_of_native_quit() -> void:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_process_frames(3)
	menu.web_platform_override = 1
	menu._refresh_texts()
	var quit := menu.find_child("QuitButton", true, false) as Button
	assert_not_null(quit)
	assert_eq(quit.text, Locale.t("menu.quit_web"))
	assert_ne(quit.text, Locale.t("menu.quit"))
	assert_eq(menu.quit_route(), "web")
	menu._on_quit_pressed()
	await wait_process_frames(1)
	var notice := menu.find_child("WebExitNotice", true, false) as Control
	assert_not_null(notice)
	assert_true(notice.visible, "web quit must show a usable browser fallback")
	assert_not_null(menu.find_child("WebExitReloadButton", true, false))
	assert_not_null(menu.find_child("WebExitRepositoryButton", true, false))
	assert_not_null(menu.find_child("WebExitDismissButton", true, false))
	menu.hide_web_exit_notice()
	assert_false(notice.visible, "the fallback notice must be dismissible")


func test_native_quit_route_keeps_plain_quit_label() -> void:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_process_frames(3)
	menu.web_platform_override = 0
	menu._refresh_texts()
	assert_eq(menu.quit_route(), "native")
	var quit := menu.find_child("QuitButton", true, false) as Button
	assert_not_null(quit)
	assert_eq(quit.text, Locale.t("menu.quit"))


func test_web_exit_bridge_is_native_safe() -> void:
	assert_true(WebExitBridge.is_web_platform(1))
	assert_false(WebExitBridge.is_web_platform(0))
	assert_false(WebExitBridge.request_close())
	assert_false(WebExitBridge.reload_page())


func _url_host(url: String) -> String:
	var slash := url.find("://")
	if slash < 0:
		return ""
	var rest := url.substr(slash + 3)
	var end := rest.find("/")
	return rest if end < 0 else rest.substr(0, end)
