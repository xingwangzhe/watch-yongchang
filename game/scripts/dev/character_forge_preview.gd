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

	_label("角色锻造验收 · 明 / 倭 / 通用阵营隔离", Vector2(36, 20), 24, Color("#e5d8bd"))
	_label(
		"明军专属与倭寇专属不混装；通用装备可供双方自由搭配 · 5 段武器动作 · 48 帧",
		Vector2(36, 54),
		15,
		Color("#9fb8b4")
	)

	var specs := [
		{"label": "[明] 狼筅 · 戚家军甲", "preset": "ming_wolf_brush"},
		{"label": "[明] 戚家刀 + 藤牌", "preset": "ming_qijia_saber"},
		{"label": "[明] 镋钯 · 青罩甲", "preset": "ming_tangpa"},
		{"label": "[明] 通用腰刀 + 藤牌", "recipe": _recipe(
			"dao", "tengpai", "ming_lamellar_red", "ming_helmet_iron", "none", "ming"
		)},
		{"label": "[明] 主将 刀 + 盾", "preset": "hero"},
		{"label": "[倭] 倭刀 · 胴丸 · 阵笠", "preset": "wokou_swordsman_domaru"},
		{"label": "[倭] 倭刀 · 腹卷", "preset": "wokou_swordsman_haramaki"},
		{"label": "[倭] 手铳 · 阵笠", "preset": "wokou_gunner"},
		{"label": "[通用] 弓 · 皮札背心", "preset": "common_villager"},
		{"label": "[通用] 长剑 + 盾", "recipe": _recipe(
			"jian", "dun", "common_leather_vest", "common_headwrap", "none", "neutral"
		)},
	]
	var positions := [
		Vector2(155, 180), Vector2(395, 180), Vector2(635, 180), Vector2(875, 180),
		Vector2(1115, 180),
		Vector2(155, 480), Vector2(395, 480), Vector2(635, 480), Vector2(875, 480),
		Vector2(1115, 480),
	]
	for index in specs.size():
		var forge := ForgeScript.new() as Node2D
		forge.position = positions[index]
		forge.scale = Vector2(1.32, 1.32)
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
			positions[index] + Vector2(-82, 132),
			13,
			Color("#d6c8ad")
		)

	_label("循环：待机 4 · 行走 8 · 攻击 30 · 受击 2 · 戒备 4", Vector2(36, 684), 14, Color("#829c98"))


func _recipe(
	main: String,
	offhand: String,
	outfit: String,
	headgear: String,
	backgear: String,
	faction: String,
) -> Dictionary:
	return {
		"faction": faction,
		"skin": "tan",
		"outfit": outfit,
		"headgear": headgear,
		"backgear": backgear,
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
