extends Control
class_name MiniMap
## 右上角小地图（借鉴 RWX Minimap.java：离屏缩略底图 + 单位点 + 视口框 + 点击跳转）。
## 底图按 tile 网格 1px/格 离屏生成，nearest 拉伸到控件尺寸。

const WIDTH: float = 210.0
const HEIGHT: float = 158.0
const C_BG := Color(0.06, 0.09, 0.10, 0.92)
const C_FRAME := Color(0.82, 0.70, 0.40)
const C_GRASS := Color(0.28, 0.42, 0.22)
const C_LONG := Color(0.24, 0.38, 0.20)
const C_DIRT := Color(0.55, 0.44, 0.30)
const C_STONE := Color(0.38, 0.39, 0.37)
const C_WATER := Color(0.16, 0.32, 0.42)
const C_OWN := Color(0.36, 0.66, 0.58)
const C_ENEMY := Color(0.80, 0.30, 0.26)
const C_VIEW := Color(1, 1, 1, 0.85)

var map_result: Dictionary = {}       # TileMapBuilder.build() 产出
var units_root: Node2D = null         # 单位容器（读子节点位置与 type/team）
var camera: Camera2D = null
var world_size: Vector2 = Vector2.ZERO

var _base_tex: ImageTexture = null

func setup(result: Dictionary, units: Node2D, cam: Camera2D) -> void:
	map_result = result
	units_root = units
	camera = cam
	world_size = result.get("world_size", Vector2.ZERO)
	_build_base_image()
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP

## 按 tile 着色生成 1px/格 缩略底图。
func _build_base_image() -> void:
	var cols: int = int(map_result.get("cols", 0))
	var rows: int = int(map_result.get("rows", 0))
	if cols == 0 or rows == 0:
		return
	var img := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	var ground := map_result.get("ground") as TileMapLayer
	var road := map_result.get("road") as TileMapLayer
	for r in range(rows):
		for c in range(cols):
			var col := C_GRASS
			var cell := ground.get_cell_source_id(Vector2i(c, r))
			if cell == TileMapBuilder.S_WATER:
				col = C_WATER
			elif cell == TileMapBuilder.S_STONE or cell == TileMapBuilder.S_G2S \
				or cell == TileMapBuilder.S_G2M:
				col = C_STONE
			elif cell == TileMapBuilder.S_LONG:
				col = C_LONG
			if road.get_cell_source_id(Vector2i(c, r)) != -1:
				col = C_DIRT
			img.set_pixel(c, r, col)
	_base_tex = ImageTexture.create_from_image(img)
	queue_redraw()

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, C_BG)
	if _base_tex != null:
		draw_texture_rect(_base_tex, rect, false, Color.WHITE, false)
	if units_root != null:
		for u in units_root.get_children():
			if not (u is Node2D) or not u.visible:
				continue
			var pos := _to_map(u.global_position)
			var col := C_OWN
			var team_var = u.get("enemy")
			if team_var != null and bool(team_var):
				col = C_ENEMY
			draw_rect(Rect2(pos - Vector2(1.5, 1.5), Vector2(3, 3)), col)
	# 主堡与视口框
	if world_size != Vector2.ZERO:
		var keep_own = TileMapBuilder.keep_center(false)
		draw_rect(Rect2(_to_map(keep_own) - Vector2(2.5, 2.5), Vector2(5, 5)), C_FRAME, false, 1.5)
	if camera != null and world_size != Vector2.ZERO:
		var vr: Rect2 = camera.visible_world_rect()
		var tl := _to_map(vr.position)
		var br := _to_map(vr.position + vr.size)
		draw_rect(Rect2(tl, br - tl), C_VIEW, false, 1.0)
	draw_rect(rect, C_FRAME, false, 1.5)

func _to_map(world_pos: Vector2) -> Vector2:
	if world_size == Vector2.ZERO:
		return Vector2.ZERO
	return Vector2(world_pos.x / world_size.x * size.x,
		world_pos.y / world_size.y * size.y)

func _map_to_world(m: Vector2) -> Vector2:
	return Vector2(m.x / size.x * world_size.x, m.y / size.y * world_size.y)

func _gui_input(event: InputEvent) -> void:
	if camera == null or world_size == Vector2.ZERO:
		return
	if event is InputEventMouseButton and event.pressed \
		and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		camera.position = _map_to_world(event.position)
		camera.position_smoothing_enabled = false
		camera.reset_smoothing()
		camera.position_smoothing_enabled = true
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		camera.position = _map_to_world(event.position)
		accept_event()
