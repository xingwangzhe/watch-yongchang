extends Control

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const COMPONENT_LAB := preload("res://scripts/dev/debug_component_lab.gd")
const COMPONENT_SCENE := "res://scenes/debug/component_state_lab.tscn"
const PAPER := Color("#efe1c2")
const MUTED := Color("#aec0bd")
const GOLD := Color("#e1b35a")
const INK := Color("#10191c")

const GROUP_ORDER := ["调试房间", "整屏界面", "覆盖层", "HUD 状态", "文字与图片"]
const ROOMS := [
	{"group": "调试房间", "title": "地形 · 河岸 · 建筑", "hint": "固定种子直接进入地图渲染场景", "path": "res://scenes/debug/terrain_lab.tscn"},
	{"group": "调试房间", "title": "敌兵移动与攻击帧", "hint": "完整敌兵图集，直接切换兵种与动作", "path": "res://scenes/debug/enemy_animation_lab.tscn"},
	{"group": "调试房间", "title": "玩家攻击与反馈", "hint": "独立展示攻击范围、特效和镜头反馈", "path": "res://scenes/debug/attack_feedback_lab.tscn"},
	{"group": "调试房间", "title": "灯下军市", "hint": "独立打开商品、购买、重掷与错误状态", "path": "res://scenes/debug/shop_lab.tscn"},
]


var _margin: MarginContainer
var _scroll: ScrollContainer
var _grids: Array[GridContainer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = INK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_margin.add_child(column)

	var title := Label.new()
	title.text = "DEBUG · 独立场景与状态"
	title.add_theme_font_override("font", UI_FONT)
	title.set_meta("debug_base_font_size", 28)
	title.add_theme_color_override("font_color", PAPER)
	title.add_theme_color_override("font_outline_color", Color("#05090a"))
	title.add_theme_constant_override("outline_size", 3)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "每项直接载入固定状态；不等待升级、军市或战斗进程。Esc 返回主菜单。"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_override("font", UI_FONT)
	subtitle.set_meta("debug_base_font_size", 15)
	subtitle.add_theme_color_override("font_color", MUTED)
	column.add_child(subtitle)

	_scroll = ScrollContainer.new()
	_scroll.name = "DebugScenarioScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(_scroll)

	var groups := VBoxContainer.new()
	groups.name = "DebugScenarioGroups"
	groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	groups.add_theme_constant_override("separation", 14)
	_scroll.add_child(groups)

	for group_name in GROUP_ORDER:
		var scenarios := _scenarios_for_group(group_name)
		if scenarios.is_empty():
			continue
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 6)
		groups.add_child(section)

		var heading := Label.new()
		heading.text = group_name
		heading.add_theme_font_override("font", UI_FONT)
		heading.set_meta("debug_base_font_size", 18)
		heading.add_theme_color_override("font_color", GOLD)
		section.add_child(heading)

		var grid := GridContainer.new()
		grid.name = "ScenarioGrid_%s" % group_name
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		section.add_child(grid)
		_grids.append(grid)

		for scenario in scenarios:
			var button := _scenario_button(scenario)
			grid.add_child(button)

	var footer := Label.new()
	footer.text = "F3 战斗诊断 · F6 隐藏/显示独立预览工具条"
	footer.add_theme_font_override("font", UI_FONT)
	footer.set_meta("debug_base_font_size", 13)
	footer.add_theme_color_override("font_color", Color(MUTED, 0.78))
	column.add_child(footer)


func _scenarios_for_group(group_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for room in ROOMS:
		if str(room.get("group", "")) == group_name:
			result.append(room)
	for scenario in COMPONENT_LAB.SCENARIOS:
		if str(scenario.get("group", "")) == group_name:
			var direct_case: Dictionary = (scenario as Dictionary).duplicate(true)
			direct_case["case_id"] = str(scenario.get("id", ""))
			result.append(direct_case)
	return result


func _scenario_button(scenario: Dictionary) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [scenario.get("title", ""), scenario.get("hint", "独立复现场景")]
	button.tooltip_text = str(scenario.get("hint", scenario.get("title", "")))
	button.custom_minimum_size = Vector2(0, 74)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_override("font", UI_FONT)
	button.set_meta("debug_base_font_size", 15)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", PAPER)
	button.add_theme_stylebox_override("normal", _button_style(Color("#172326"), Color("#526760")))
	button.add_theme_stylebox_override("hover", _button_style(Color("#24342f"), GOLD))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#34291d"), GOLD))
	if scenario.has("case_id"):
		button.pressed.connect(_open_component_case.bind(str(scenario.get("case_id", ""))))
	else:
		button.pressed.connect(_open_scene.bind(str(scenario.get("path", ""))))
	return button


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_top = 7
	style.content_margin_right = 10
	style.content_margin_bottom = 7
	return style


func _apply_responsive_layout() -> void:
	if not is_instance_valid(_margin):
		return
	var size := _display_size()
	_apply_responsive_layout_for(get_viewport_rect().size, size, UILayout.safe_area_insets())


func _apply_responsive_layout_for(viewport_size: Vector2, size: Vector2, safe: Vector4) -> void:
	if not is_instance_valid(_margin):
		return
	var scale := UILayout.display_scale(viewport_size, size)
	var portrait := size.y > size.x
	var inset := 10 if portrait else 18
	_margin.add_theme_constant_override("margin_left", roundi(UILayout.display_units(float(inset) + safe.x, scale)))
	_margin.add_theme_constant_override("margin_right", roundi(UILayout.display_units(float(inset) + safe.z, scale)))
	_margin.add_theme_constant_override("margin_top", roundi(UILayout.display_units(float(inset) + safe.y, scale)))
	_margin.add_theme_constant_override("margin_bottom", roundi(UILayout.display_units(float(inset) + safe.w, scale)))
	for label in _margin.find_children("*", "Label", true, false):
		var base_size := float(label.get_meta("debug_base_font_size", 14))
		label.add_theme_font_size_override("font_size", maxi(12, roundi(base_size / scale)))
	for button in _margin.find_children("*", "Button", true, false):
		button.custom_minimum_size.y = UILayout.display_units(74.0, scale)
		button.add_theme_font_size_override("font_size", maxi(12, roundi(15.0 / scale)))
	for grid in _grids:
		grid.columns = 1 if size.x < 760.0 else 2
		grid.add_theme_constant_override("h_separation", roundi(UILayout.display_units(8.0, scale)))
		grid.add_theme_constant_override("v_separation", roundi(UILayout.display_units(8.0, scale)))
	var groups := _scroll.get_child(0) as VBoxContainer
	groups.add_theme_constant_override("separation", roundi(UILayout.display_units(14.0, scale)))
	for section in groups.get_children():
		if section is VBoxContainer:
			(section as VBoxContainer).add_theme_constant_override("separation", roundi(UILayout.display_units(6.0, scale)))


func _display_size() -> Vector2:
	if OS.has_feature("web"):
		var parsed: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify([window.innerWidth || 0, window.innerHeight || 0])", true)))
		if parsed is Array and (parsed as Array).size() >= 2:
			var css_size := Vector2(float(parsed[0]), float(parsed[1]))
			if css_size.x > 0.0 and css_size.y > 0.0:
				return css_size
	var size := Vector2(DisplayServer.window_get_size())
	if size.x <= 0.0 or size.y <= 0.0:
		size = get_viewport_rect().size
	return size


func _open_scene(path: String) -> void:
	if path.is_empty():
		return
	get_tree().change_scene_to_file(path)


func _open_component_case(case_id: String) -> void:
	var packed := load(COMPONENT_SCENE) as PackedScene
	if packed == null:
		push_error("Missing direct component state lab: %s" % COMPONENT_SCENE)
		return
	var scene := packed.instantiate()
	scene.set("initial_case", case_id)
	var tree := get_tree()
	var previous := tree.current_scene
	tree.root.add_child(scene)
	tree.current_scene = scene
	if is_instance_valid(previous) and previous != scene:
		previous.queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
