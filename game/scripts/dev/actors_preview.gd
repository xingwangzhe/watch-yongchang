extends Node2D

const DATA_PATH := "res://data/actors.json"
const STEP := 0.12
const FRAME_ORDER := [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0, 1]

var hero: Sprite2D
var wokou: Array[Sprite2D] = []
var rows: Array[int] = []
var elapsed := 0.0
var cycle := 0
var hero_cell := 128
var wokou_cell := 128


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed == null:
		return
	var data: Dictionary = parsed
	var bg := ColorRect.new()
	bg.color = Color("#081014")
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var hero_data: Dictionary = data["hero"]
	hero_cell = int(hero_data["cell"])
	var hero_texture := load(hero_data["path"]) as Texture2D
	hero = _sprite(hero_texture, Vector2(158, 188), 1.0)
	hero.region_rect = Rect2(FRAME_ORDER[0] * hero_cell, 0, hero_cell, hero_cell)
	_label(str(hero_data["name_zh"]), Vector2(110, 263), 20)

	var atlas: Dictionary = data["wokou_atlas"]
	var wokou_texture := load(atlas["path"]) as Texture2D
	var cell: int = int(atlas["cell"])
	wokou_cell = cell
	for i in (data["wokou"] as Array).size():
		var entry: Dictionary = data["wokou"][i]
		var row_index: int = int(entry["row"])
		rows.append(row_index)
		var col := i % 4
		var row := i / 4
		var sprite := _sprite(
			wokou_texture,
			Vector2(400 + col * 215, 135 + row * 148),
			1.0
		)
		sprite.region_rect = Rect2(FRAME_ORDER[0] * cell, row_index * cell, cell, cell)
		wokou.append(sprite)
		_label(str(entry["name_zh"]), Vector2(346 + col * 215, 197 + row * 148), 13)

	_label("原创角色图集 · 戚继光与十六类倭寇", Vector2(400, 18), 24)
	_label("16 帧连续动作：行走 8 · 攻击 6 · 待机 2", Vector2(400, 50), 14)


func _sprite(texture: Texture2D, pos: Vector2, size_scale: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.position = pos
	sprite.scale = Vector2(size_scale, size_scale)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	return sprite


func _label(text: String, pos: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = Vector2(150, 24)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("#d8d0c0"))
	add_child(label)


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < STEP:
		return
	elapsed = 0.0
	cycle = (cycle + 1) % FRAME_ORDER.size()
	var pose: int = FRAME_ORDER[cycle]
	hero.region_rect = Rect2(pose * hero_cell, 0, hero_cell, hero_cell)
	for i in wokou.size():
		wokou[i].region_rect = Rect2(
			pose * wokou_cell,
			rows[i] * wokou_cell,
			wokou_cell,
			wokou_cell
		)
