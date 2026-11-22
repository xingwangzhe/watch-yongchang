extends Control
class_name MinimapPanel
## 右上角小地图（对齐 OpenHV RADAR 222×222 方形）。
##
## 数据来源：setup(map_result, units_root, camera)
##   map_result 由 tile_map_builder.build() 返回，用到：cols / rows / tile / world_size
##   / zone_map / buildings。zone_map 是 Dictionary: Vector2i(格坐标) -> StringName 区域名
##   （&"city" / &"moat" / &"river" / &"field" / &"road" / &"wall" / &"sea" / &"gate"）。
##   **上色只读 zone_map**，不硬编码任何瓦片/图层常量；zone_map 缺失时退化为单色底图。
##
## 绘制：1px/格 离屏底图（nearest 放大）→ 己方单位青点 / 敌方单位红点
##       → 双方主堡方框 → 当前视口白框 → 金色外框 → 悬停区域 tooltip。
##
## 交互：
##   左键点击 = 摄像机跳转并请求选中（jump_requested(world, true)）
##   左键在视口白框内拖拽 = 直接拖动视口框（等价平移相机）
##   右键 = 只跳转不选中（jump_requested(world, false)）
##   滚轮 = 以鼠标位置为中心缩放 0.5×–2×
##   悬停 = 显示该格 zone_map 区域名

signal jump_requested(world: Vector2, select: bool)
signal zone_hovered(zone: StringName)

const MAP_SIZE := Vector2(222.0, 222.0)
const FONT_PATH: String = "res://assets/fonts/LXGWWenKai-Regular.ttf"

const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 2.0
const ZOOM_STEP: float = 1.25

# 右栏配色一致
const C_BG := Color(0.05, 0.07, 0.08, 0.94)
const C_FRAME := Color(0.84, 0.71, 0.40)
const C_FRAME_DIM := Color(0.42, 0.38, 0.26, 0.9)
const C_FALLBACK := Color(0.24, 0.28, 0.24)
const C_OWN := Color(0.40, 0.85, 0.90)
const C_ENEMY := Color(0.90, 0.36, 0.30)
const C_KEEP_OWN := Color(0.86, 0.74, 0.42)
const C_KEEP_ENEMY := Color(0.80, 0.32, 0.28)
const C_TOWER := Color(0.60, 0.56, 0.36)
const C_VIEW := Color(1.0, 1.0, 1.0, 0.92)
const C_HOVER := Color(1.0, 1.0, 1.0, 0.18)
const C_TIP_BG := Color(0.03, 0.05, 0.05, 0.94)
const C_INK := Color(0.88, 0.85, 0.74)

## zone_map 值 → 颜色（区域语义色，与瓦片常量无关）
const ZONE_COLORS: Dictionary = {
	&"city": Color(0.34, 0.40, 0.30),
	&"moat": Color(0.16, 0.36, 0.46),
	&"river": Color(0.14, 0.32, 0.44),
	&"field": Color(0.30, 0.38, 0.20),
	&"road": Color(0.52, 0.44, 0.30),
	&"wall": Color(0.46, 0.44, 0.40),
	&"sea": Color(0.10, 0.24, 0.36),
	&"gate": Color(0.62, 0.50, 0.24),
}
## zone_map 值 → tooltip 文案
const ZONE_LABELS: Dictionary = {
	&"city": "城内",
	&"moat": "护城河",
	&"river": "河道",
	&"field": "田野",
	&"road": "驿道",
	&"wall": "城墙",
	&"sea": "海面",
	&"gate": "城门",
}

var map_result: Dictionary = {}
var units_root: Node2D = null
var camera: Camera2D = null

var _cols: int = 0
var _rows: int = 0
var _tile: float = 40.0
var _world_size: Vector2 = Vector2.ZERO
var _zone_map: Dictionary = {}
var _buildings: Array = []
var _base_tex: ImageTexture = null
var _has_zone_map: bool = false

var _zoom_level: float = 1.0
var _origin: Vector2 = Vector2.ZERO       # 底图左上角在控件坐标系中的位置
var _origin_inited: bool = false

var _hover_cell: Vector2i = Vector2i(-1, -1)
var _hover_ctrl: Vector2 = Vector2.ZERO
var _hover_zone: StringName = &""

var _dragging: bool = false
var _drag_follow: bool = false            # true=拖动视口框（相对平移），false=持续跳到指针
var _drag_last: Vector2 = Vector2.ZERO

var _font: Font
var _tip_style: StyleBoxFlat
var _smoothing_backup: bool = true
var _draw_count: int = 0

func _ready() -> void:
	_font = load(FONT_PATH) as Font
	custom_minimum_size = MAP_SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tip_style = StyleBoxFlat.new()
	_tip_style.bg_color = C_TIP_BG
	_tip_style.set_border_width_all(1)
	_tip_style.border_color = C_FRAME_DIM
	_tip_style.set_corner_radius_all(3)
	_tip_style.set_content_margin_all(1)
	resized.connect(_on_resized)
	mouse_exited.connect(_on_mouse_exited)
	queue_redraw()

# ---------- 公开 API ----------

func setup(result: Dictionary, units: Node2D, cam: Camera2D) -> void:
	map_result = result
	units_root = units
	camera = cam
	_cols = int(result.get("cols", 0))
	_rows = int(result.get("rows", 0))
	_tile = float(result.get("tile", 40))
	_world_size = result.get("world_size", Vector2.ZERO) as Vector2
	var zm: Variant = result.get("zone_map", {})
	_zone_map = zm as Dictionary if zm is Dictionary else {}
	_has_zone_map = not _zone_map.is_empty()
	var bs: Variant = result.get("buildings", [])
	_buildings = bs as Array if bs is Array else []
	_build_base_image()
	_origin_inited = false
	queue_redraw()

## 供外部在单位大量变化时主动重绘（默认每帧自动重绘）
func refresh() -> void:
	queue_redraw()

func get_zoom() -> float:
	return _zoom_level

# ---------- 底图 ----------

func _build_base_image() -> void:
	_base_tex = null
	if _cols <= 0 or _rows <= 0 or not _has_zone_map:
		return
	var img := Image.create(_cols, _rows, false, Image.FORMAT_RGBA8)
	for r in range(_rows):
		for c in range(_cols):
			var zone: StringName = _zone_of(Vector2i(c, r))
			var col: Color = ZONE_COLORS.get(zone, C_FALLBACK)
			img.set_pixel(c, r, col)
	_base_tex = ImageTexture.create_from_image(img)

func _zone_of(cell: Vector2i) -> StringName:
	if _zone_map.is_empty():
		return &""
	if cell.x < 0 or cell.y < 0 or cell.x >= _cols or cell.y >= _rows:
		return &""
	var v: Variant = _zone_map.get(cell, &"")
	return StringName(str(v))

# ---------- 坐标换算 ----------

## 控件像素 / 格
func _scale() -> float:
	if _cols <= 0 or _rows <= 0:
		return 1.0
	var fit := minf(size.x / float(_cols), size.y / float(_rows))
	return fit * _zoom_level

func _world_to_ctrl(world: Vector2) -> Vector2:
	var s := _scale()
	if s <= 0.0:
		return Vector2.ZERO
	return _origin + world / _tile * s

func _ctrl_to_world(p: Vector2) -> Vector2:
	var s := _scale()
	if s <= 0.0:
		return Vector2.ZERO
	return (p - _origin) / s * _tile

func _ctrl_to_cell(p: Vector2) -> Vector2i:
	var s := _scale()
	if s <= 0.0:
		return Vector2i(-1, -1)
	var t := (p - _origin) / s
	var cell := Vector2i(int(floor(t.x)), int(floor(t.y)))
	if cell.x < 0 or cell.y < 0 or cell.x >= _cols or cell.y >= _rows:
		return Vector2i(-1, -1)
	return cell

func _clamp_origin() -> void:
	var s := _scale()
	if s <= 0.0 or _cols <= 0 or _rows <= 0:
		return
	var map_px := Vector2(float(_cols), float(_rows)) * s
	if map_px.x <= size.x:
		_origin.x = (size.x - map_px.x) * 0.5
	else:
		_origin.x = clampf(_origin.x, size.x - map_px.x, 0.0)
	if map_px.y <= size.y:
		_origin.y = (size.y - map_px.y) * 0.5
	else:
		_origin.y = clampf(_origin.y, size.y - map_px.y, 0.0)

func _ensure_origin() -> void:
	if _origin_inited:
		return
	_origin_inited = true
	_zoom_level = 1.0
	_clamp_origin()

func _on_resized() -> void:
	_clamp_origin()
	queue_redraw()

# ---------- 绘制 ----------

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	_draw_count += 1
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, C_BG)
	if _cols <= 0 or _rows <= 0:
		draw_rect(rect, C_FRAME, false, 2.0)
		_draw_tip(rect)
		return
	_ensure_origin()
	var s := _scale()
	var dest := Rect2(_origin, Vector2(float(_cols), float(_rows)) * s)
	if _base_tex != null:
		draw_texture_rect(_base_tex, dest, false)
	else:
		draw_rect(dest, C_FALLBACK)
		if not _has_zone_map and _font != null:
			draw_string(_font, Vector2(8.0, 18.0), "zone_map 未提供", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.5, 0.4))

	# 悬停格高亮
	if _hover_cell.x >= 0 and s >= 2.0:
		var hp := _world_to_ctrl(Vector2(float(_hover_cell.x), float(_hover_cell.y)) * _tile)
		draw_rect(Rect2(hp, Vector2(s, s)), C_HOVER)

	_draw_buildings()
	_draw_units()
	_draw_viewport()

	# 外框
	draw_rect(rect.grow(-1.0), C_FRAME, false, 2.0)
	_draw_tip(rect)

func _draw_units() -> void:
	if units_root == null:
		return
	var s := _scale()
	var dot := clampf(s * 1.1, 2.0, 4.0)
	var half := Vector2(dot, dot) * 0.5
	for u in units_root.get_children():
		if not (u is Node2D):
			continue
		var n2d := u as Node2D
		if not n2d.is_visible_in_tree():
			continue
		var dead: Variant = n2d.get("is_dead")
		if dead != null and bool(dead):
			continue
		var enemy_v: Variant = n2d.get("is_enemy")
		var is_enemy: bool = enemy_v != null and bool(enemy_v)
		var p := _world_to_ctrl(n2d.global_position)
		draw_rect(Rect2(p - half, Vector2(dot, dot)), C_ENEMY if is_enemy else C_OWN)

func _draw_buildings() -> void:
	for b in _buildings:
		if not (b is Dictionary):
			continue
		var bd := b as Dictionary
		var bid := str(bd.get("id", ""))
		if not (bd.get("anchor") is Vector2i):
			continue
		var anchor := bd["anchor"] as Vector2i
		var bsize := Vector2i(1, 1)
		if bd.get("size") is Vector2i:
			bsize = bd["size"] as Vector2i
		var tl := _world_to_ctrl(Vector2(float(anchor.x), float(anchor.y)) * _tile)
		var sz := Vector2(float(bsize.x), float(bsize.y)) * _scale()
		var r := Rect2(tl, sz)
		if bid == "keep_own":
			draw_rect(r, C_KEEP_OWN, false, 2.0)
		elif bid == "keep_enemy":
			draw_rect(r, C_KEEP_ENEMY, false, 2.0)
		else:
			draw_rect(r, C_TOWER)

func _draw_viewport() -> void:
	if camera == null:
		return
	var r := _camera_rect()
	if r.size == Vector2.ZERO:
		return
	var tl := _world_to_ctrl(r.position)
	var br := _world_to_ctrl(r.position + r.size)
	draw_rect(Rect2(tl, br - tl), C_VIEW, false, 1.5)

func _draw_tip(rect: Rect2) -> void:
	if _hover_zone == &"" or _font == null or _hover_cell.x < 0:
		return
	var text := str(ZONE_LABELS.get(_hover_zone, str(_hover_zone)))
	var fs := 12
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pad := Vector2(6.0, 4.0)
	var box := Vector2(text_size.x, text_size.y) + pad * 2.0
	var pos := _hover_ctrl + Vector2(12.0, 10.0)
	pos.x = clampf(pos.x, rect.position.x + 2.0, rect.end.x - box.x - 2.0)
	pos.y = clampf(pos.y, rect.position.y + 2.0, rect.end.y - box.y - 2.0)
	draw_style_box(_tip_style, Rect2(pos, box))
	draw_string(_font, pos + pad + Vector2(0.0, text_size.y * 0.92), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_INK)

# ---------- 相机 ----------

func _camera_rect() -> Rect2:
	if camera == null:
		return Rect2()
	var zoom_v: Vector2 = camera.zoom
	if zoom_v.x == 0.0 or zoom_v.y == 0.0:
		zoom_v = Vector2.ONE
	var half: Vector2 = get_viewport_rect().size * 0.5 / zoom_v
	var center: Vector2 = camera.global_position
	if camera.has_method("get_screen_center_position"):
		var v: Variant = camera.call("get_screen_center_position")
		if v is Vector2:
			center = v as Vector2
	return Rect2(center - half, half * 2.0)

func _snap_camera(world: Vector2) -> void:
	if camera == null:
		return
	var prev: bool = camera.position_smoothing_enabled
	camera.position_smoothing_enabled = false
	camera.global_position = world
	if camera.has_method("reset_smoothing"):
		camera.call("reset_smoothing")
	camera.position_smoothing_enabled = prev

func _pan_camera(world_delta: Vector2) -> void:
	if camera == null:
		return
	camera.global_position += world_delta

func _jump_to_ctrl(p: Vector2, select: bool) -> void:
	if camera == null:
		return
	var world := _ctrl_to_world(p)
	_snap_camera(world)
	jump_requested.emit(world, select)

# ---------- 交互 ----------

func _gui_input(event: InputEvent) -> void:
	if _cols <= 0 or _rows <= 0:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var factor := ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP
				_zoom_at(_zoom_level * factor, mb.position)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_last = mb.position
				_drag_follow = _viewport_ctrl_rect().has_point(mb.position)
				if _drag_follow and camera != null:
					_smoothing_backup = camera.position_smoothing_enabled
					camera.position_smoothing_enabled = false
				else:
					_jump_to_ctrl(mb.position, true)
			else:
				_dragging = false
				if _drag_follow and camera != null:
					camera.position_smoothing_enabled = _smoothing_backup
				_drag_follow = false
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_jump_to_ctrl(mb.position, false)
			accept_event()
			return
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_update_hover(mm.position)
		if _dragging:
			if _drag_follow:
				var delta_ctrl := mm.position - _drag_last
				_drag_last = mm.position
				_pan_camera(delta_ctrl / _scale() * _tile)
			else:
				_jump_to_ctrl(mm.position, true)
			accept_event()
		return

func _zoom_at(target: float, anchor: Vector2) -> void:
	var nz := clampf(target, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(nz, _zoom_level):
		return
	var world_at := _ctrl_to_world(anchor)
	_zoom_level = nz
	var s := _scale()
	_origin = anchor - world_at / _tile * s
	_clamp_origin()
	queue_redraw()

func _viewport_ctrl_rect() -> Rect2:
	var r := _camera_rect()
	if r.size == Vector2.ZERO:
		return Rect2()
	var tl := _world_to_ctrl(r.position)
	var sz := r.size / _tile * _scale()
	return Rect2(tl, sz)

func _update_hover(p: Vector2) -> void:
	_hover_ctrl = p
	var cell := _ctrl_to_cell(p)
	if cell == _hover_cell:
		return
	_hover_cell = cell
	var zone := _zone_of(cell)
	if zone != _hover_zone:
		_hover_zone = zone
		zone_hovered.emit(zone)
	queue_redraw()

func _on_mouse_exited() -> void:
	_hover_cell = Vector2i(-1, -1)
	if _hover_zone != &"":
		_hover_zone = &""
		zone_hovered.emit(&"")
	queue_redraw()

# ---------- 调试 ----------

const GDA_CALLABLE := ["get_zoom", "refresh", "get_draw_count"]

## 诊断：_draw 实际执行次数（headless 下也可用来确认渲染回调生效）
func get_draw_count() -> int:
	return _draw_count
