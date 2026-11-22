extends Node2D
## 临时截图工具：把 4 层 TileMapLayer 烘焙成 1:1 PNG（用后即删）。

const TMB = preload("res://scripts/tile_map_builder.gd")
const TC = preload("res://scripts/tile_catalog.gd")

func _ready() -> void:
	var res: Dictionary = TMB.build(self)
	# 等一帧，确保 TileSet 纹理可用
	await get_tree().process_frame
	var cols: int = res["cols"]
	var rows: int = res["rows"]
	var ts: TileSet = (res["ground"] as TileMapLayer).tile_set
	var img := Image.create(cols * 32, rows * 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	var layers := ["ground", "road", "structure", "decor"]
	for name in layers:
		var layer: TileMapLayer = res[name]
		for cell in layer.get_used_cells():
			var sid := layer.get_cell_source_id(cell)
			var coord := layer.get_cell_atlas_coords(cell)
			var src := ts.get_source(sid) as TileSetAtlasSource
			if src == null:
				continue
			var atlas_img := src.texture.get_image()
			if atlas_img.get_format() != Image.FORMAT_RGBA8:
				atlas_img.convert(Image.FORMAT_RGBA8)
			var rect := Rect2i(coord.x * 32, coord.y * 32, 32, 32)
			var tile := atlas_img.get_region(rect)
			img.blend_rect(tile, Rect2i(0, 0, 32, 32), Vector2i(cell.x * 32, cell.y * 32))
	var out := ProjectSettings.globalize_path("res://tests/terrain_render.png")
	print("[RENDER] %s err=%d size=%dx%d" % [out, img.save_png(out), img.get_width(), img.get_height()])
