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
		"裸体骨架 · 5 段武器动作 · 同/异种双持组合 · 48 帧",
		Vector2(36, 54),
		15,
		Color("#9fb8b4")
	)

	var specs := [
		{"label": "主将 刀 + 盾", "preset": "hero"},
		{"label": "明军 长枪", "preset": "ming_guard"},
		{"label": "弓手 弓", "recipe": _recipe("gong", "none", "ming_navy_green")},
		{"label": "手铳", "preset": "wokou_gunner"},
		{"label": "双刀 同种", "recipe": _recipe("dao", "dao", "ming_lamellar_red")},
		{"label": "刀 + 剑 异种", "recipe": _recipe("dao", "jian", "ming_guard_iron")},
		{"label": "双钩 同种", "preset": "oni_duelist"},
		{"label": "钩 + 盾", "recipe": _recipe("gou", "dun", "wokou_ragged_brown")},
	]
	var positions := [
		Vector2(180, 175), Vector2(490, 175), Vector2(800, 175), Vector2(1110, 175),
		Vector2(180, 475), Vector2(490, 475), Vector2(800, 475), Vector2(1110, 475),
	]
	for index in specs.size():
		var forge := ForgeScript.new() as Node2D
		forge.position = positions[index]
		forge.scale = Vector2(1.45, 1.45)
		add_child(forge)
		if not forge.load_data():
			continue
		var data: Dictionary = forge.data
		var recipe: Dictionary = (
			data["recipes"][specs[index]["preset"]]
			if specs[index].has("preset")
			else specs[index]["recipe"]
		)
		forge.set_recipe(recipe)
		forges.append(forge)
		_label(
			str(specs[index]["label"]),
			positions[index] + Vector2(-88, 128),
			13,
			Color("#d6c8ad")
		)

	_label("循环：待机 4 · 行走 8 · 攻击 30 · 受击 2 · 戒备 4", Vector2(36, 684), 14, Color("#829c98"))


func _recipe(main: String, offhand: String, outfit: String) -> Dictionary:
	return {
		"skin": "tan",
		"outfit": outfit,
		"headgear": "none",
		"backgear": "none",
		"weapon": main,
		"offhand": offhand,
	}


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
	var next_frame := int(elapsed * 8.0) % 48
	if next_frame == frame:
		return
	frame = next_frame
	for forge in forges:
		forge.set_frame(frame)
