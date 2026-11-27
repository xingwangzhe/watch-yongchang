extends Node2D

@export var room_title := "DEBUG ROOM"

var _info_label: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DebugOverlay"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 12)
	panel.custom_minimum_size = Vector2(400, 112)
	layer.add_child(panel)
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 16)
	_info_label.add_theme_color_override("font_color", Color("#f5e5c1"))
	panel.add_child(_info_label)
	var back := Button.new()
	back.text = "返回调试目录 (Esc)"
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.offset_left = -220.0
	back.offset_top = 14.0
	back.offset_right = -14.0
	back.offset_bottom = 54.0
	back.pressed.connect(_return_to_hub)
	layer.add_child(back)
	set_process(true)


func set_debug_text(value: String) -> void:
	if is_instance_valid(_info_label):
		_info_label.text = "%s\n%s" % [room_title, value]


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_hub()


func _return_to_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/debug/debug_hub.tscn")
