class_name SpriteSheetFrames
extends RefCounted

## Extract complete, fixed-size character frames from a row in a categorized atlas.
static func row(texture: Texture2D, columns: int, rows: int, row_index: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if texture == null or columns <= 0 or rows <= 0 or row_index < 0 or row_index >= rows:
		return frames
	var sheet_size := texture.get_size()
	if int(sheet_size.x) % columns != 0 or int(sheet_size.y) % rows != 0:
		push_error("Sprite sheet dimensions must divide evenly into cells")
		return frames
	var cell_size := Vector2(sheet_size.x / columns, sheet_size.y / rows)
	for column in range(columns):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(Vector2(column * cell_size.x, row_index * cell_size.y), cell_size)
		frames.append(frame)
	return frames


static func path_row(path: String, columns: int, rows: int, row_index: int) -> Array[Texture2D]:
	if path.is_empty():
		return []
	return row(GameData.texture(path), columns, rows, row_index)
