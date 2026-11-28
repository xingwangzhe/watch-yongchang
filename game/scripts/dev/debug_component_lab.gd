extends Control

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const INK := Color("#081114")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.webp")

const SCENARIOS := [
	{"id": "main_menu", "group": "整屏界面", "title": "主菜单", "kind": "scene", "path": "res://scenes/main_menu.tscn"},
	{"id": "menu_settings", "group": "整屏界面", "title": "设置面板", "kind": "scene_method", "path": "res://scenes/main_menu.tscn", "method": "open_settings"},
	{"id": "menu_controls", "group": "整屏界面", "title": "按键设置", "kind": "scene_method", "path": "res://scenes/main_menu.tscn", "method": "open_controls"},
	{"id": "character_select", "group": "整屏界面", "title": "角色与地图选择", "kind": "scene", "path": "res://scenes/character_select.tscn"},
	{"id": "codex", "group": "整屏界面", "title": "守望图鉴", "kind": "scene", "path": "res://scenes/codex.tscn"},
	{"id": "about", "group": "整屏界面", "title": "关于与署名", "kind": "scene", "path": "res://scenes/about.tscn"},
	{"id": "prologue", "group": "整屏界面", "title": "1386 序章", "kind": "scene", "path": "res://scenes/prologue.tscn"},
	{"id": "shop", "group": "覆盖层", "title": "灯下军市", "kind": "scene", "path": "res://scenes/debug/shop_lab.tscn"},
	{"id": "pause", "group": "覆盖层", "title": "暂停菜单", "kind": "run_overlay", "state": "pause"},
	{"id": "result_victory", "group": "覆盖层", "title": "胜利结算", "kind": "run_overlay", "state": "result_victory"},
	{"id": "result_defeat", "group": "覆盖层", "title": "失败结算", "kind": "run_overlay", "state": "result_defeat"},
	{"id": "hud_standard", "group": "HUD 状态", "title": "标准战斗 HUD", "kind": "hud", "state": {"hp": 100, "max_hp": 100, "xp": 45, "xp_need": 120, "level": 8, "elapsed": 265, "duration": 960, "kills": 74, "merit": 18, "coin": 60, "oil": 4, "oil_max": 6, "scales": [], "weapons": [], "build_label": "守灯阵 · 雁翎刀", "skills": 2, "cards": 5, "auto_attack": false}},
	{"id": "hud_critical", "group": "HUD 状态", "title": "残血与补给", "kind": "hud", "state": {"hp": 7, "max_hp": 100, "shield": 12, "xp": 115, "xp_need": 120, "level": 12, "elapsed": 652, "duration": 960, "kills": 311, "merit": 68, "coin": 95, "oil": 1, "oil_max": 6, "scales": ["red"], "weapons": [], "build_label": "潮汐将尽", "skills": 4, "cards": 12, "auto_attack": true}},
	{"id": "hud_dark", "group": "HUD 状态", "title": "灯油耗尽 · 摸黑", "kind": "hud", "state": {"hp": 52, "max_hp": 100, "xp": 88, "xp_need": 160, "level": 16, "elapsed": 721, "duration": 960, "kills": 420, "merit": 94, "coin": 130, "oil": 0, "oil_max": 6, "dark": true, "scales": [], "weapons": [], "build_label": "摸黑守夜", "skills": 5, "cards": 16, "auto_attack": true}},
	{"id": "hud_boss", "group": "HUD 状态", "title": "Boss 与自动攻击", "kind": "hud", "state": {"hp": 61, "max_hp": 100, "xp": 62, "xp_need": 180, "level": 20, "elapsed": 846, "duration": 960, "kills": 682, "merit": 144, "coin": 180, "oil": 2, "oil_max": 6, "scales": ["gold", "blue"], "weapons": [], "build_label": "龙灯阵 · Boss 来袭", "skills": 7, "cards": 21, "auto_attack": true, "boss_active": true, "boss_name": "倭寇头目", "boss_hp": 380, "boss_max_hp": 1000}},
	{"id": "banner_upgrade", "group": "HUD 状态", "title": "升级后提示横幅", "kind": "banner", "title_text": "守夜阵位已强化", "subtitle": "灯火照亮前路 · 下一场潮汐即将抵达"},
	{"id": "banner_long", "group": "HUD 状态", "title": "长文本提示横幅", "kind": "banner", "title_text": "沿海烽火示警：北侧潮汐与城墙缺口同时出现", "subtitle": "验证长标题、双语文本、背景边框与按钮安全区"},
	{"id": "upgrade_choices", "group": "覆盖层", "title": "升级 · 三选一卡片", "kind": "levelup"},
	{"id": "upgrade_long", "group": "覆盖层", "title": "升级 · 长标题与长说明", "kind": "levelup_long"},
	{"id": "tutorial_page_1", "group": "覆盖层", "title": "教程 · 第 1 页", "kind": "tutorial", "page": 0},
	{"id": "tutorial_page_4", "group": "覆盖层", "title": "教程 · 第 4 页", "kind": "tutorial", "page": 3},
	{"id": "story_subtitle", "group": "覆盖层", "title": "剧情字幕与文字底板", "kind": "story"},
	{"id": "typography", "group": "文字与图片", "title": "文字轮廓 / 背景 / 阴影", "kind": "typography"},
	{"id": "sprite_atlases", "group": "文字与图片", "title": "角色与敌兵完整图集", "kind": "sprites"},
]

@export var initial_case := "hud_standard"

var _preview_host: Control
var _selector: OptionButton
var _toolbar: PanelContainer
var _reopen_button: Button
var _case_caption: Label
var _current_preview: Node
var _current_case := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_load_case.call_deferred(initial_case)


func scenario_ids() -> Array[String]:
	var ids: Array[String] = []
	for scenario in SCENARIOS:
		ids.append(str(scenario.get("id", "")))
	return ids


func scenario_manifest() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for scenario in SCENARIOS:
		result.append((scenario as Dictionary).duplicate(true))
	return result


func _build_shell() -> void:
	var background := ColorRect.new()
	background.name = "DebugStateBackground"
	background.color = Color("#10191c")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_preview_host = Control.new()
	_preview_host.name = "PreviewHost"
	_preview_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_preview_host)

	var toolbar_layer := CanvasLayer.new()
	toolbar_layer.name = "DebugStateToolbar"
	toolbar_layer.layer = 100
	add_child(toolbar_layer)

	_toolbar = PanelContainer.new()
	_toolbar.name = "Toolbar"
	_toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toolbar.offset_left = 8.0
	_toolbar.offset_top = 8.0
	_toolbar.offset_right = -8.0
	_toolbar.offset_bottom = 54.0
	_toolbar.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.038, 0.041, 0.94), GOLD, 1))
	toolbar_layer.add_child(_toolbar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_toolbar.add_child(row)

	var back := Button.new()
	back.text = "‹ 目录"
	back.add_theme_font_override("font", UI_FONT)
	back.pressed.connect(_return_to_hub)
	row.add_child(back)

	_selector = OptionButton.new()
	_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selector.add_theme_font_override("font", UI_FONT)
	for scenario in SCENARIOS:
		_selector.add_item("%s · %s" % [scenario.get("group", ""), scenario.get("title", "")])
		_selector.set_item_metadata(_selector.item_count - 1, str(scenario.get("id", "")))
	_selector.item_selected.connect(_on_case_selected)
	row.add_child(_selector)

	var hide_button := Button.new()
	hide_button.text = "收起"
	hide_button.add_theme_font_override("font", UI_FONT)
	hide_button.pressed.connect(_hide_toolbar)
	row.add_child(hide_button)

	_reopen_button = Button.new()
	_reopen_button.text = "调试目录"
	_reopen_button.anchor_left = 1.0
	_reopen_button.anchor_right = 1.0
	_reopen_button.visible = false
	_reopen_button.add_theme_font_override("font", UI_FONT)
	_reopen_button.pressed.connect(_show_toolbar)
	toolbar_layer.add_child(_reopen_button)

	var caption_layer := CanvasLayer.new()
	caption_layer.name = "DebugStateCaption"
	caption_layer.layer = 99
	add_child(caption_layer)
	_case_caption = Label.new()
	_case_caption.name = "ScenarioCaption"
	_case_caption.anchor_left = 0.0
	_case_caption.anchor_right = 1.0
	_case_caption.anchor_top = 1.0
	_case_caption.anchor_bottom = 1.0
	_case_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_case_caption.add_theme_font_override("font", UI_FONT)
	_case_caption.add_theme_color_override("font_color", Color(PAPER, 0.86))
	_case_caption.add_theme_color_override("font_outline_color", INK)
	_case_caption.add_theme_constant_override("outline_size", 3)
	caption_layer.add_child(_case_caption)
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	_apply_responsive_layout_for(
		get_viewport_rect().size,
		_display_size(),
		UILayout.safe_area_insets()
	)


func _apply_responsive_layout_for(viewport_size: Vector2, screen_size: Vector2, safe: Vector4) -> void:
	if _toolbar == null or _reopen_button == null or _case_caption == null:
		return
	var scale := UILayout.display_scale(viewport_size, screen_size)
	var horizontal_margin := UILayout.display_units(8.0, scale)
	_toolbar.offset_left = horizontal_margin + UILayout.display_units(safe.x, scale)
	_toolbar.offset_top = UILayout.display_units(8.0 + safe.y, scale)
	_toolbar.offset_right = -horizontal_margin - UILayout.display_units(safe.z, scale)
	_toolbar.offset_bottom = UILayout.display_units(72.0 + safe.y, scale)
	var button_height := UILayout.display_units(44.0, scale)
	var font_size := maxi(12, roundi(14.0 / scale))
	var row := _toolbar.get_child(0) as HBoxContainer
	var back := row.get_child(0) as Button
	var selector := row.get_child(1) as OptionButton
	var hide_button := row.get_child(2) as Button
	back.custom_minimum_size = Vector2(UILayout.display_units(72.0, scale), button_height)
	selector.custom_minimum_size = Vector2(UILayout.display_units(112.0, scale), button_height)
	hide_button.custom_minimum_size = Vector2(UILayout.display_units(64.0, scale), button_height)
	for control in [back, selector, hide_button]:
		control.add_theme_font_size_override("font_size", font_size)
	_reopen_button.custom_minimum_size = Vector2(UILayout.display_units(88.0, scale), button_height)
	_reopen_button.offset_left = -UILayout.display_units(96.0 + safe.z, scale)
	_reopen_button.offset_top = UILayout.display_units(8.0 + safe.y, scale)
	_reopen_button.offset_right = -UILayout.display_units(8.0 + safe.z, scale)
	_reopen_button.offset_bottom = _reopen_button.offset_top + button_height
	_case_caption.offset_left = UILayout.display_units(10.0 + safe.x, scale)
	_case_caption.offset_top = -UILayout.display_units(36.0 + safe.w, scale)
	_case_caption.offset_right = -UILayout.display_units(10.0 + safe.z, scale)
	_case_caption.offset_bottom = -UILayout.display_units(8.0 + safe.w, scale)
	_case_caption.add_theme_font_size_override("font_size", maxi(12, roundi(13.0 / scale)))


func _display_size() -> Vector2:
	if OS.has_feature("web"):
		var parsed: Variant = JSON.parse_string(str(JavaScriptBridge.eval(
			"JSON.stringify([window.innerWidth || 0, window.innerHeight || 0])", true
		)))
		if parsed is Array and (parsed as Array).size() >= 2:
			var css_size := Vector2(float(parsed[0]), float(parsed[1]))
			if css_size.x > 0.0 and css_size.y > 0.0:
				return css_size
	var size := Vector2(DisplayServer.window_get_size())
	return size if size.x > 0.0 and size.y > 0.0 else get_viewport_rect().size


func _on_case_selected(index: int) -> void:
	var id := str(_selector.get_item_metadata(index))
	_load_case(id)


func _load_case(case_id: String) -> void:
	var scenario := _scenario(case_id)
	if scenario.is_empty():
		push_error("Unknown debug UI state: %s" % case_id)
		return
	_current_case = case_id
	_update_selector()
	_case_caption.text = "%s · %s" % [scenario.get("group", ""), scenario.get("title", "")]
	_clear_preview()
	await get_tree().process_frame

	var kind := str(scenario.get("kind", ""))
	match kind:
		"scene", "scene_method":
			await _preview_scene(scenario)
		"run_overlay":
			await _preview_run_overlay(scenario)
		"hud", "banner":
			await _preview_hud(scenario)
		"levelup", "levelup_long":
			await _preview_levelup(scenario, kind == "levelup_long")
		"tutorial":
			await _preview_tutorial(scenario)
		"story":
			await _preview_story()
		"typography":
			_preview_typography()
		"sprites":
			_preview_sprites()
		_:
			push_error("Unsupported debug state kind: %s" % kind)


func _scenario(case_id: String) -> Dictionary:
	for scenario in SCENARIOS:
		if str(scenario.get("id", "")) == case_id:
			return scenario
	return {}


func _update_selector() -> void:
	for index in range(_selector.item_count):
		if str(_selector.get_item_metadata(index)) == _current_case:
			_selector.select(index)
			return


func _clear_preview() -> void:
	if is_instance_valid(_current_preview):
		if _current_preview.get_parent() != null:
			_current_preview.get_parent().remove_child(_current_preview)
		_current_preview.queue_free()
	_current_preview = null
	for child in _preview_host.get_children():
		_preview_host.remove_child(child)
		child.queue_free()


func _preview_scene(scenario: Dictionary) -> void:
	var packed := load(str(scenario.get("path", ""))) as PackedScene
	if packed == null:
		push_error("Missing debug preview scene: %s" % scenario.get("path", ""))
		return
	_current_preview = packed.instantiate()
	_preview_host.add_child(_current_preview)
	if str(scenario.get("kind", "")) == "scene_method":
		await get_tree().process_frame
		var method := str(scenario.get("method", ""))
		if _current_preview.has_method(method):
			_current_preview.call(method)
		else:
			push_error("Debug preview scene has no method: %s" % method)


func _preview_run_overlay(scenario: Dictionary) -> void:
	var packed := load("res://scenes/run.tscn") as PackedScene
	if packed == null:
		push_error("Missing direct gameplay overlay preview scene")
		return
	_current_preview = packed.instantiate()
	_current_preview.set("debug_preview_only", true)
	_preview_host.add_child(_current_preview)
	await get_tree().process_frame
	_current_preview.call("debug_preview_state", str(scenario.get("state", "pause")))


func _preview_hud(scenario: Dictionary) -> void:
	var hud := RunHUD.new()
	_preview_host.add_child(hud)
	_current_preview = hud
	await get_tree().process_frame
	var fallback_state := _scenario("hud_standard").get("state", {}) as Dictionary
	var state: Dictionary = scenario.get("state", fallback_state) as Dictionary
	hud.update_hud(state)
	if str(scenario.get("kind", "")) == "banner":
		hud.show_banner(str(scenario.get("title_text", "")), str(scenario.get("subtitle", "")), 3600.0)


func _preview_levelup(scenario: Dictionary, long_copy: bool) -> void:
	var overlay := LevelUpOverlay.new()
	_preview_host.add_child(overlay)
	_current_preview = overlay
	await get_tree().process_frame
	var options := _upgrade_options()
	if long_copy and options.size() >= 3:
		options[0]["title"] = "守望烽火连营 · 卫所器械全面整备"
		options[0]["description"] = "提升长枪与弩矢的命中距离，改善连续出手后的收招间隔，并让每次攻击保持清晰方向。此卡用于检查长文在手机窄屏上的折行、卡片高度、间距和触控命中区域。"
		options[0]["culture"] = "永昌堡沿海守望依赖烽火、巡夜与乡兵协作。此段仅展示文本布局，不新增史实陈述。"
		options[0]["effect_summary"] = "射程 +18% · 冷却 -10% · 额外箭矢 +1"
		options[2]["title"] = "灯火绵延"
		options[2]["description"] = "灯油消耗减缓，摸黑时经验收益提高，守夜阵位仍能保持清晰可辨。"
	overlay.show_options(options, 12, {"pool": UpgradeCatalog.total_offer_count(), "taken": 6})


func _upgrade_options() -> Array[Dictionary]:
	var pool := UpgradeCatalog.build_card_pool({}, {}, 0.8)
	var result: Array[Dictionary] = []
	for family in ["attribute", "skill", "event"]:
		for option in pool:
			if str(option.get("family", "")) == family:
				result.append((option as Dictionary).duplicate(true))
				break
	if result.size() < 3:
		result.clear()
		for option in pool:
			if result.size() >= 3:
				break
			result.append((option as Dictionary).duplicate(true))
	return result


func _preview_tutorial(scenario: Dictionary) -> void:
	var overlay := TutorialOverlay.new()
	_preview_host.add_child(overlay)
	_current_preview = overlay
	await get_tree().process_frame
	overlay.open(false)
	overlay.call("_go_page", clampi(int(scenario.get("page", 0)), 0, 3))


func _preview_story() -> void:
	var overlay := StoryOverlay.new()
	_preview_host.add_child(overlay)
	_current_preview = overlay
	await get_tree().process_frame
	var lines: Array = [
		{
			"speaker_zh": "守灯人",
			"speaker_en": "Lamp Keeper",
			"zh": "这是独立调试样例，不属于史料剧情。",
			"en": "This is an isolated debug sample, not historical dialogue.",
			"category": "演绎",
			"source_ref": "调试预览自拟文本，不作为正式游戏剧情。",
			"audio_enabled": false,
		},
		{
			"speaker_zh": "旁白",
			"speaker_en": "Narrator",
			"zh": "竖屏状态下检查字幕底板、轮廓、来源标签与下一页按钮。",
			"en": "Check the subtitle backdrop, outline, source label, and next button in portrait.",
			"category": "演绎",
			"source_ref": "调试预览自拟文本，不作为正式游戏剧情。",
			"audio_enabled": false,
		},
	]
	overlay.start(lines, "Debug · 字幕状态独立预览")


func _preview_typography() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 58.0
	scroll.offset_bottom = -38.0
	_preview_host.add_child(scroll)
	_current_preview = scroll
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	column.add_child(_text_sample("霞鹜文楷 · 轮廓与阴影", "海上月明，守望永昌。", 32, Color("#f3d28e"), Color("#071013")))
	column.add_child(_text_sample("剧情字幕底板", "潮声近了。添灯油，巡堡墙。\nThe tide is close. Refill the lantern and walk the wall.", 22, PAPER, INK))
	column.add_child(_text_sample("HUD 小字与高对比", "生命 12 / 100 · 灯油 1 / 6 · Auto Attack", 16, Color("#d9e5dc"), Color("#061012")))
	column.add_child(_text_sample("宽背景与多行文字", "守夜阵位已强化\n下一场潮汐即将抵达", 24, GOLD, INK))


func _text_sample(heading: String, value: String, size: int, color: Color, outline: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 100
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.052, 0.055, 0.96), Color(GOLD, 0.62), 2))
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var title := Label.new()
	title.text = heading
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", MUTED)
	column.add_child(title)
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", 3)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.y = 48
	column.add_child(label)
	return panel


func _preview_sprites() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 58.0
	scroll.offset_bottom = -38.0
	_preview_host.add_child(scroll)
	_current_preview = scroll
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var sheets := [
		["主角动作 · 完整帧", "res://assets/units/full_sheets/player_actions.webp", 3],
		["明军友军 · 完整帧", "res://assets/units/full_sheets/allies_walk.webp", 4],
		["倭寇敌军 · 完整帧", "res://assets/units/full_sheets/enemies_walk.webp", 5],
		["骑兵与骑手 · 完整帧", "res://assets/units/full_sheets/cavalry_walk.webp", 4],
		["完整攻击动作", "res://assets/units/full_sheets/unit_attacks.webp", 8],
		["王陆守夜阵位", "res://assets/units/full_sheets/wanglu_watchposts.webp", 1],
	]
	for entry in sheets:
		var texture := load(str(entry[1])) as Texture2D
		if texture == null:
			push_error("Missing debug sprite atlas: %s" % entry[1])
			continue
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.038, 0.041, 0.96), Color(GOLD, 0.44), 1))
		column.add_child(card)
		var margin := MarginContainer.new()
		for side in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 8)
		card.add_child(margin)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 4)
		margin.add_child(content)
		var caption := Label.new()
		caption.text = "%s · %d × %d px" % [entry[0], int(texture.get_width()), int(texture.get_height())]
		caption.add_theme_font_override("font", UI_FONT)
		caption.add_theme_font_size_override("font_size", 14)
		caption.add_theme_color_override("font_color", PAPER)
		content.add_child(caption)
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var ratio := float(texture.get_height()) / maxf(1.0, float(texture.get_width()))
		image.custom_minimum_size = Vector2(0.0, clampf(300.0 * ratio, 64.0, 170.0))
		image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(image)


func _panel_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style


func _hide_toolbar() -> void:
	_toolbar.visible = false
	_case_caption.visible = false
	_reopen_button.visible = true


func _show_toolbar() -> void:
	_toolbar.visible = true
	_case_caption.visible = true
	_reopen_button.visible = false


func _return_to_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/debug/debug_hub.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F6:
		if _toolbar.visible:
			_hide_toolbar()
		else:
			_show_toolbar()
	elif event.is_action_pressed("ui_cancel"):
		_return_to_hub()
