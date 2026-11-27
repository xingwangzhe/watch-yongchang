extends Control

const ROOMS := [
	{"title": "地表与河岸", "path": "res://scenes/debug/terrain_lab.tscn", "hint": "固定地图种子 · 地形 / 河岸 / 建筑"},
	{"title": "敌人移动与攻击", "path": "res://scenes/debug/enemy_animation_lab.tscn", "hint": "完整敌人帧 · 图集行 / 帧号 / 攻击反馈"},
	{"title": "玩家攻击反馈", "path": "res://scenes/debug/attack_feedback_lab.tscn", "hint": "真实 Battlefield · 特效 / 范围 / 镜头反馈"},
]


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#10191c")
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "DEBUG ROOM SELECTOR"
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color("#f4dfb0"))
	column.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "每个问题独立复现 · Esc 返回主菜单"
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color("#aec0bd"))
	column.add_child(subtitle)
	for room in ROOMS:
		var button := Button.new()
		button.text = "%s\n%s" % [room.title, room.hint]
		button.custom_minimum_size = Vector2(0, 96)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 21)
		button.pressed.connect(_open_room.bind(str(room.path)))
		column.add_child(button)
	var menu_button := Button.new()
	menu_button.text = "返回主菜单"
	menu_button.custom_minimum_size = Vector2(0, 48)
	menu_button.pressed.connect(_return_to_menu)
	column.add_child(menu_button)
	var footnote := Label.new()
	footnote.text = "F3 游戏内诊断面板仍可用 · 此目录场景不会进入发行菜单"
	footnote.add_theme_font_size_override("font_size", 14)
	footnote.add_theme_color_override("font_color", Color("#849995"))
	column.add_child(footnote)


func _open_room(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_menu()
