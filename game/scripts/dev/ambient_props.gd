extends Node2D

const DATA_PATH := "res://data/yongchang_tiles.json"

var sprites: Array[Sprite2D] = []
var clip_rows: Array[int] = []
var elapsed := 0.0
var frame := 0
var frame_step := 0.125
var cell := 32
var columns := 4


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed == null:
		return
	var data: Dictionary = parsed["atlases"]["animated_props"]
	cell = int(data["cell"])
	columns = int(data["columns"])
	frame_step = 1.0 / maxf(1.0, float(data["fps"]))
	var clips: Dictionary = data["clips"]
	var texture := load(str(data["path"])) as Texture2D
	if texture == null:
		return
	for placement: Dictionary in data["placements"]:
		var clip := str(placement["clip"])
		if not clips.has(clip):
			continue
		var row := int(clips[clip])
		var tile: Array = placement["tile"]
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, row * cell, cell, cell)
		sprite.position = Vector2(
			(float(tile[0]) + 0.5) * cell,
			(float(tile[1]) + 0.5) * cell
		)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = 20
		add_child(sprite)
		sprites.append(sprite)
		clip_rows.append(row)


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < frame_step:
		return
	elapsed = fmod(elapsed, frame_step)
	frame = (frame + 1) % columns
	for i in sprites.size():
		sprites[i].region_rect = Rect2(
			frame * cell,
			clip_rows[i] * cell,
			cell,
			cell
		)
