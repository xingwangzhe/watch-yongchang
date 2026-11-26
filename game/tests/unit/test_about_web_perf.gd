extends GutTest

const ABOUT_SCENE := preload("res://scenes/about.tscn")
const MENU_SCENE := preload("res://scenes/main_menu.tscn")


func before_each() -> void:
	GameSettings.web_platform_override = 1


func after_each() -> void:
	GameSettings.web_platform_override = -1


func test_web_menu_prewarm_keeps_only_a_stopped_shell() -> void:
	var menu := MENU_SCENE.instantiate()
	menu.web_platform_override = 1
	add_child_autofree(menu)
	await wait_process_frames(2)

	assert_null(menu._about_prewarm_timer, "web menu must not prebuild About in the background")
	menu._prewarm_about_overlay()
	await wait_process_frames(1)

	var about: Control = menu._about_overlay
	assert_not_null(about, "the menu may cache the lightweight overlay shell")
	assert_false(about.visible, "the cached shell must stay hidden")
	assert_false(about.is_processing(), "the cached shell must stop processing")
	assert_eq(about.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_null(about.about_player(), "warming the shell must not start About audio")
	assert_true(AudioBus.menu_enabled, "warming the shell must not interrupt menu music")

	var content := about.find_child("CreditsContent", true, false) as VBoxContainer
	assert_not_null(content)
	assert_eq(content.get_child_count(), 0, "the menu must not prebuild the hidden credits roll")


func test_web_about_uses_bounded_materialization() -> void:
	var about := ABOUT_SCENE.instantiate()
	add_child_autofree(about)
	await wait_process_frames(1)
	assert_false(about.is_content_ready(), "web About must yield its first frame")

	for _frame in range(240):
		if about.is_content_ready():
			break
		await wait_process_frames(1)
	assert_true(about.is_content_ready(), "web About must finish its lightweight skeleton")

	var content := about.find_child("CreditsContent", true, false) as VBoxContainer
	assert_not_null(content)
	assert_gt(content.get_child_count(), 100, "the full roll keeps its slots and ordering")

	var materialized := 0
	for slot in content.get_children():
		if slot.get_child_count() > 0:
			materialized += 1
	assert_gt(materialized, 0, "the first viewport must be readable immediately")
	assert_lt(materialized, 40, "web About must not instantiate every text node up front")
	assert_true(
		materialized < content.get_child_count() / 2,
		"unmaterialized credit slots must stay lightweight"
	)


func test_activating_web_shell_starts_content_on_demand() -> void:
	var about := ABOUT_SCENE.instantiate()
	about.prewarm_mode = true
	about.defer_content = true
	add_child_autofree(about)
	await wait_process_frames(1)

	assert_false(about.is_processing(), "the shell must stay parked before activation")
	assert_false(about.is_content_ready())
	about.activate()
	await wait_process_frames(2)
	assert_true(about.visible)
	assert_true(about.is_processing(), "activation must resume work")

	for _frame in range(240):
		if about.is_content_ready():
			break
		await wait_process_frames(1)
	assert_true(about.is_content_ready(), "activation must build the roll on demand")
	var content := about.find_child("CreditsContent", true, false) as VBoxContainer
	assert_not_null(content)
	assert_gt(content.get_child_count(), 0)
	AudioBus.resume_bgm()


func test_web_about_materializes_the_tail_when_scrolled() -> void:
	var about := ABOUT_SCENE.instantiate()
	add_child_autofree(about)
	for _frame in range(240):
		if about.is_content_ready():
			break
		await wait_process_frames(1)
	assert_true(about.is_content_ready())
	about._take_over_scroll()

	var scroll := about.find_child("CreditsScroll", true, false) as ScrollContainer
	var content := about.find_child("CreditsContent", true, false) as VBoxContainer
	assert_not_null(scroll)
	assert_not_null(content)
	for _frame in range(240):
		var bar := scroll.get_v_scroll_bar()
		scroll.scroll_vertical = int(maxf(0.0, bar.max_value - bar.page))
		var last_slot := content.get_child(content.get_child_count() - 1) as Control
		if last_slot.get_child_count() > 0:
			break
		await wait_process_frames(1)

	var last_slot := content.get_child(content.get_child_count() - 1) as Control
	assert_gt(last_slot.get_child_count(), 0, "the final credit block must materialize")
	assert_not_null(
		about.find_child("AboutAuthor", true, false),
		"deep links and author credits must survive virtualization"
	)


func test_web_menu_backdrop_is_static() -> void:
	var menu := MENU_SCENE.instantiate()
	menu.web_platform_override = 1
	add_child_autofree(menu)
	await wait_process_frames(2)

	var backdrop: Control = menu.find_child("Backdrop", true, false)
	assert_not_null(backdrop)
	assert_true(backdrop.reduced_motion, "web backdrop must use its static composition")
	assert_false(backdrop.is_processing(), "web backdrop must not repaint every frame")
