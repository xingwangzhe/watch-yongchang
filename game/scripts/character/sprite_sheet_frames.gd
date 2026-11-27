class_name SpriteSheetFrames
extends RefCounted

## Extract complete, fixed-size character frames from a row in a categorized atlas.
static func row(texture: Texture2D, columns: int, rows: int, row_index: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if texture == null:
		push_error("Cannot crop character atlas: texture is missing")
		return frames
	if columns <= 0 or rows <= 0 or row_index < 0 or row_index >= rows:
		push_error(
			"Cannot crop character atlas: invalid layout columns=%d rows=%d row=%d"
			% [columns, rows, row_index]
		)
		return frames
	var sheet_size := texture.get_size()
	if int(sheet_size.x) % columns != 0 or int(sheet_size.y) % rows != 0:
		push_error(
			"Cannot crop character atlas %s: dimensions %s do not divide into %d x %d cells"
			% [texture.resource_path, sheet_size, columns, rows]
		)
		return frames
	var cell_size := Vector2(sheet_size.x / columns, sheet_size.y / rows)
	if cell_size != Vector2(128, 128):
		push_error(
			"Cannot crop character atlas %s: expected 128 x 128 cells, got %s"
			% [texture.resource_path, cell_size]
		)
		return frames
	for column in range(columns):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(Vector2(column * cell_size.x, row_index * cell_size.y), cell_size)
		frames.append(frame)
	return frames


static func path_row(path: String, columns: int, rows: int, row_index: int) -> Array[Texture2D]:
	if path.is_empty():
		push_error("Cannot crop character atlas: source path is empty")
		return []
	if not ResourceLoader.exists(path):
		push_error("Cannot crop character atlas: missing source %s" % path)
		return []
	var texture := GameData.texture(path)
	if texture == null:
		push_error("Cannot crop character atlas: failed to load source %s" % path)
		return []
	return row(texture, columns, rows, row_index)
