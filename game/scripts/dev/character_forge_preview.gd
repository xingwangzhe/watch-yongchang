extends Node2D

const ForgeScript = preload("res://scripts/character/character_forge.gd")

var forges: Array[Node2D] = []
var elapsed := 0.0
var frame := 0


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("#081014")
	background.size = Vector2(1280, 720)
	add_child(background)

	_label("角色锻造验收 · 明式抗倭", Vector2(36, 20), 24, Color("#e5d8bd"))
	_label(
		"同一骨架 · 双臂前层 · 副手独立层 · 32 帧",
		Vector2(36, 54),
		15,
		Color("#9fb8b4")
	)

	var recipes := [
		{"label": "主将 刀 + 盾", "recipe": "hero"},
		{"label": "明军 长枪", "recipe": "ming_guard"},
		{"label": "倭寇 腰刀", "recipe": "wokou_raider"},
		{"label": "鬼面 双钩", "recipe": "oni_duelist"},
	]
	var positions := [
		Vector2(190, 330),
		Vector2(490, 330),
		Vector2(790, 330),
		Vector2(1090, 330),
	]
	for index in recipes.size():
		var forge := ForgeScript.new() as Node2D
		forge.position = positions[index]
		forge.scale = Vector2(2.15, 2.15)
		add_child(forge)
		if not forge.load_data():
			continue
		var data: Dictionary = forge.data
		forge.set_recipe(data["recipes"][recipes[index]["recipe"]])
		forges.append(forge)
		_label(
			str(recipes[index]["label"]),
			positions[index] + Vector2(-92, 172),
			15,
			Color("#d6c8ad")
		)

	_label("循环：待机 4 · 行走 8 · 攻击 18 · 受击 2", Vector2(36, 684), 14, Color("#829c98"))


func _label(text: String, position: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _process(delta: float) -> void:
	elapsed += delta
	var next_frame := int(elapsed * 8.0) % 32
	if next_frame == frame:
		return
	frame = next_frame
	for forge in forges:
		forge.set_frame(frame)
