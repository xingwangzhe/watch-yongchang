extends Node2D

const TILE := 32
const TERRAIN_PATH := "res://assets/tiles/yongchang/terrain_atlas.png"
const ARCHITECTURE_PATH := "res://assets/tiles/yongchang/architecture_atlas.png"
const PROPS_PATH := "res://assets/tiles/yongchang/props_atlas.png"
const WaterShimmer = preload("res://scripts/dev/water_shimmer.gd")
const AmbientProps = preload("res://scripts/dev/ambient_props.gd")


func _ready() -> void:
	var terrain := _make_layer(TERRAIN_PATH, Vector2i(8, 5), -10)
	var architecture := _make_layer(ARCHITECTURE_PATH, Vector2i(8, 4), 0)
	var props := _make_layer(PROPS_PATH, Vector2i(8, 2), 10)
	_paint_terrain(terrain)
	_paint_architecture(architecture)
	_paint_props(props)
	var shimmer := WaterShimmer.new()
	shimmer.z_index = -5
	add_child(shimmer)
	add_child(AmbientProps.new())
	scale = Vector2(2, 2)
	position = Vector2(0, 8)


func _make_layer(path: String, grid: Vector2i, z: int) -> TileMapLayer:
	var texture := load(path) as Texture2D
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	for y in grid.y:
		for x in grid.x:
			source.create_tile(Vector2i(x, y))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	var source_id := tile_set.add_source(source)
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	layer.z_index = z
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(layer)
	layer.set_meta("source_id", source_id)
	return layer


func _paint_terrain(layer: TileMapLayer) -> void:
	var source_id: int = layer.get_meta("source_id")
	for ty in 11:
		for tx in 20:
			var index := 0
			if ty >= 10:
				index = 6
				if (tx + ty) % 8 == 0:
					index = 7
			elif ty == 9:
				index = 2 if tx < 12 else 6
			elif ty >= 8:
				index = 6
				if (tx + ty) % 8 == 0:
					index = 7
			elif ty >= 5:
				index = 6 if ty != 5 else 4
			elif ty == 4:
				index = 17
			elif ty <= 1:
				index = 16 if (tx * 3 + ty) % 7 == 0 else 0
				if (tx * 5 + ty) % 11 == 0:
					index = 1
			else:
				index = 24 if (tx + ty) % 9 == 0 else 8 if (tx * 2 + ty) % 7 == 0 else 0
			_place(layer, source_id, tx, ty, index)
	for tx in range(1, 8):
		for ty in range(6, 9):
			_place(layer, source_id, tx, ty, 15)
	for ty in range(8, 11):
		for tx in range(13, 19):
			_place(layer, source_id, tx, ty, 32 + ((tx * 3 + ty * 5) % 8))
	for tx in range(1, 6):
		_place(layer, source_id, tx, 2, 9)
	_place(layer, source_id, 0, 7, 26)


func _paint_architecture(layer: TileMapLayer) -> void:
	var source_id: int = layer.get_meta("source_id")
	for tx in range(8, 20):
		_place(layer, source_id, tx, 4, 5)
		_place(layer, source_id, tx, 5, 3 if tx % 6 == 3 else 0)
		_place(layer, source_id, tx, 6, 4)
	for x0: int in [8, 16]:
		var x1 := x0 + 3 if x0 == 8 else 19
		for tx in range(x0, x1 + 1):
			_place(layer, source_id, tx, 0, 12)
			_place(layer, source_id, tx, 1, 13)
			_place(layer, source_id, tx, 2, 14)
			_place(layer, source_id, tx, 3, 9 if tx % 2 else 8)
	for tx in range(13, 16):
		_place(layer, source_id, tx, 2, 12)
		_place(layer, source_id, tx, 3, 13)
		_place(layer, source_id, tx, 4, 14)
	for tx in range(13, 16):
		_place(layer, source_id, tx, 5, 16 + (tx - 13))
		_place(layer, source_id, tx, 6, 19 + (tx - 13))
	_place(layer, source_id, 7, 5, 29)
	_place(layer, source_id, 20, 5, 30)
	_place(layer, source_id, 12, 6, 25)
	_place(layer, source_id, 16, 4, 24)
	for tx in range(1, 8):
		_place(layer, source_id, tx, 6, 24)
		_place(layer, source_id, tx, 8, 24)


func _paint_props(layer: TileMapLayer) -> void:
	var source_id: int = layer.get_meta("source_id")
	for tx in range(1, 6):
		_place(layer, source_id, tx, 1, 0)
	_place(layer, source_id, 0, 3, 2)
	_place(layer, source_id, 5, 3, 4)
	_place(layer, source_id, 6, 6, 12)
	_place(layer, source_id, 1, 3, 13)
	_place(layer, source_id, 17, 3, 14)
	_place(layer, source_id, 18, 3, 15)
	_place(layer, source_id, 2, 3, 5)
	_place(layer, source_id, 3, 3, 6)
	_place(layer, source_id, 4, 3, 7)
	_place(layer, source_id, 19, 3, 11)


func _place(layer: TileMapLayer, source_id: int, tx: int, ty: int, index: int) -> void:
	layer.set_cell(Vector2i(tx, ty), source_id, Vector2i(index % 8, index >> 3), 0)
