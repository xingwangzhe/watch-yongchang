extends Control
class_name MinimapPanel
## 右上角小地图（对齐 OpenHV RADAR 222×222 方形）。
##
## 数据来源：setup(map_result, units_root, camera)
##   map_result 由 tile_map_builder.build() 返回，用到：cols / rows / tile / world_size
##   / zone_map / buildings / ground / road / structure / decor。
##   底图逐格读取 TileMapLayer 的真实图块，按图块纹理均色合成；不维护第二套手绘色表。
##   zone_map 只用于悬停文案，不参与上色。
##
## 历史依据（docs/06-资料文本化/文档文本/永昌堡-十三进士与抗倭纪略-全文.txt）：
##   L544-559：东临东海、西倚大罗山；城门四座、水门四座、敌台十二、铺舍二十；
##             城外护城河、城内上河/下河与十条河浃、堡内水田二百余亩。
##   L14530-14614：宅中向东、坐山面海；东门环海楼附瓮城；四门名与城内水系走向。
##   因此小地图标签使用“堡内水田 / 上河下河 / 环海楼等四门 / 东海 / 盐场 / 大罗山麓”，
##   不使用现代道路或现代行政地名。
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

const TileMapBuilder = preload("res://scripts/tile_map_builder.gd")
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

## zone_map 值 → tooltip 文案
const ZONE_LABELS: Dictionary = {
	&"city": "堡内",
	&"moat": "护城河",
	&"river": "上河 / 下河 / 河浃",
	&"field": "堡内水田（二百余亩）",
	&"road": "驿道",
	&"wall": "城墙",
	&"sea": "东海",
	&"gate": "城门",
	&"beach": "滩涂",
	&"salt": "盐场",
	&"mountain": "大罗山麓",
	&"wild": "荒野",
}

var map_result: Dictionary = {}
var units_root: Node2D = null
var towers_root: Node2D = null
var camera: Camera2D = null

var _cols: int = 0
var _rows: int = 0
var _tile: float = 32.0
var _world_size: Vector2 = Vector2.ZERO
var _zone_map: Dictionary = {}
var _buildings: Array = []
var _layers: Array[TileMapLayer] = []
var _tile_avg_cache: Dictionary = {}
var _base_img: Image = null
var _base_tex: ImageTexture = null
var _base_from_tilemap: bool = false
var _base_dirty: bool = true
var _base_dirty_frames: int = 0
var _layer_change_count: int = 0

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

func setup(result: Dictionary, units: Node2D, cam: Camera2D, towers: Node2D = null) -> void:
	map_result = result
	units_root = units
	towers_root = towers
	camera = cam
	_cols = int(result.get("cols", 0))
	_rows = int(result.get("rows", 0))
	_tile = float(result.get("tile", 32))
	_world_size = result.get("world_size", Vector2.ZERO) as Vector2
	var zm: Variant = result.get("zone_map", {})
	_zone_map = zm as Dictionary if zm is Dictionary else {}
	var bs: Variant = result.get("buildings", [])
	_buildings = bs as Array if bs is Array else []
	_bind_layers()
	_base_dirty = true
	_base_dirty_frames = 0
	_rebuild_base_image()
	_origin_inited = false
	queue_redraw()

## 供外部在单位大量变化时主动重绘（默认每帧自动重绘）
func refresh() -> void:
	queue_redraw()

## 地形层变动后强制下一帧重采样（供 TileMapLayer.changed 或调试调用）
func refresh_terrain() -> void:
	_base_dirty = true
	_base_dirty_frames = 1
	queue_redraw()

func get_zoom() -> float:
	return _zoom_level

# ---------- 底图 ----------

func _bind_layers() -> void:
	_layers.clear()
	for key in ["ground", "road", "structure", "decor"]:
		var v: Variant = map_result.get(key)
		if not (v is TileMapLayer):
			continue
		var layer := v as TileMapLayer
		_layers.append(layer)
		if layer.has_signal("changed") and not layer.changed.is_connected(_on_layer_changed):
			layer.changed.connect(_on_layer_changed)

func _on_layer_changed() -> void:
	_layer_change_count += 1
	_base_dirty = true
	_base_dirty_frames = 1
	queue_redraw()

## 从真实 TileMapLayer 取样。顺序与绘制层一致：ground → road → structure → decor。
## 每个图块只在首次遇到时求一次均色，后续逐格查缓存。
func _rebuild_base_image() -> void:
	_base_dirty = false
	_base_dirty_frames = 0
	_base_tex = null
	_base_img = null
	_base_from_tilemap = false
	if _cols <= 0 or _rows <= 0:
		return
	var img := Image.create(_cols, _rows, false, Image.FORMAT_RGBA8)
	for r in range(_rows):
		for c in range(_cols):
			img.set_pixel(c, r, _sample_terrain_cell(Vector2i(c, r)))
	_base_img = img
	_base_tex = ImageTexture.create_from_image(img)
	_base_from_tilemap = not _layers.is_empty()

func _sample_terrain_cell(cell: Vector2i) -> Color:
	var out := Color(0.0, 0.0, 0.0, 0.0)
	for layer in _layers:
		var sid := layer.get_cell_source_id(cell)
		if sid < 0:
			continue
		var coords := layer.get_cell_atlas_coords(cell)
		var top := _tile_avg_color(layer, sid, coords)
		if top.a <= 0.001:
			continue
		out = _over(out, top)
	if out.a <= 0.001:
		return C_FALLBACK
	return out

func _over(bottom: Color, top: Color) -> Color:
	var a := top.a
	if a >= 0.999:
		return top
	var out_a := a + bottom.a * (1.0 - a)
	if out_a <= 0.0001:
		return Color(0.0, 0.0, 0.0, 0.0)
	return Color(
		(top.r * a + bottom.r * bottom.a * (1.0 - a)) / out_a,
		(top.g * a + bottom.g * bottom.a * (1.0 - a)) / out_a,
		(top.b * a + bottom.b * bottom.a * (1.0 - a)) / out_a,
		out_a)

func _tile_avg_color(layer: TileMapLayer, sid: int, coords: Vector2i) -> Color:
	if layer.tile_set == null:
		return C_FALLBACK
	var src := layer.tile_set.get_source(sid)
	if not (src is TileSetAtlasSource):
		return C_FALLBACK
	var atlas := src as TileSetAtlasSource
	var cache: Dictionary = _tile_avg_cache.get(atlas, {})
	if cache.has(coords):
		return cache[coords]
	var tex := atlas.texture
	if tex == null:
		return C_FALLBACK
	var region := atlas.texture_region_size
	if region.x <= 0 or region.y <= 0:
		return C_FALLBACK
	var img := tex.get_image()
	if img == null:
		return C_FALLBACK
	var px := coords.x * region.x
	var py := coords.y * region.y
	if px < 0 or py < 0 or px + region.x > img.get_width() or py + region.y > img.get_height():
		return C_FALLBACK
	var sr := 0.0
	var sg := 0.0
	var sb := 0.0
	var sa := 0.0
	var n := 0
	for y in range(py, py + region.y):
		for x in range(px, px + region.x):
			var p := img.get_pixel(x, y)
			sr += p.r * p.a
			sg += p.g * p.a
			sb += p.b * p.a
			sa += p.a
			n += 1
	if sa <= 0.0001 or n == 0:
		var empty := Color(0.0, 0.0, 0.0, 0.0)
		cache[coords] = empty
		_tile_avg_cache[atlas] = cache
		return empty
	var avg := Color(sr / sa, sg / sa, sb / sa, sa / float(n))
	cache[coords] = avg
	_tile_avg_cache[atlas] = cache
	return avg

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
		if _base_dirty:
			if _base_dirty_frames > 0:
				_base_dirty_frames -= 1
			else:
				_rebuild_base_image()
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
		if not _base_from_tilemap and _font != null:
			draw_string(_font, Vector2(8.0, 18.0), "地形取样未就绪", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.5, 0.4))

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
	var seen: Dictionary = {}
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
		seen[anchor] = true
		if bid == "keep_own":
			draw_rect(r, C_KEEP_OWN, false, 2.0)
		elif bid == "keep_enemy":
			draw_rect(r, C_KEEP_ENEMY, false, 2.0)
		else:
			draw_rect(r, C_TOWER)
	# 玩家新建建筑由 BuildSystem 挂到 Battle/Towers；每帧从节点元数据取样，
	# 不依赖 map_result 里的静态建筑清单。
	if towers_root != null:
		for child in towers_root.get_children():
			if not (child is Node2D):
				continue
			var node := child as Node2D
			var av: Variant = node.get_meta("anchor", Vector2i(-1, -1))
			if not (av is Vector2i):
				continue
			var anchor := av as Vector2i
			if anchor.x < 0 or seen.has(anchor):
				continue
			var tl := _world_to_ctrl(Vector2(float(anchor.x), float(anchor.y)) * _tile)
			var sz := Vector2(3.0, 3.0) * _scale()
			draw_rect(Rect2(tl, sz), C_TOWER)

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
	var text := _label_of(_hover_cell, _hover_zone)
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

func _label_of(cell: Vector2i, zone: StringName) -> String:
	if zone == &"gate" or zone == &"wall":
		var landmark := TileMapBuilder.landmark_label_at(cell)
		if landmark != "":
			return landmark
	if zone == &"road":
		return TileMapBuilder.road_label_at(cell)
	return str(ZONE_LABELS.get(zone, str(zone)))

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

## 小地图跳转/平移一律走摄像机的 center_on / scroll，
## 由摄像机自己按地图边界钳制（直接写 global_position 会绕过边界，把镜头推出地图）。
func _snap_camera(world: Vector2) -> void:
	if camera == null:
		return
	if camera.has_method("center_on"):
		camera.call("center_on", world)
	else:
		camera.global_position = world

func _pan_camera(world_delta: Vector2) -> void:
	if camera == null:
		return
	if camera.has_method("scroll"):
		# scroll 接收屏幕像素，这里换算回屏幕位移再交给摄像机
		camera.call("scroll", world_delta * camera.zoom.x)
	else:
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

const GDA_CALLABLE := [
	"get_zoom", "refresh", "refresh_terrain", "get_draw_count",
	"get_base_pixel", "get_sampled_color", "is_sampled_from_tilemap", "get_layer_change_count",
]

## 诊断：_draw 实际执行次数（headless 下也可用来确认渲染回调生效）
func get_draw_count() -> int:
	return _draw_count

## 诊断/测试：底图某个格的实际像素，来自真实图块均色，而不是 zone_map 色表。
func get_base_pixel(cell: Vector2i) -> Color:
	if _base_img == null or cell.x < 0 or cell.y < 0 or cell.x >= _cols or cell.y >= _rows:
		return C_FALLBACK
	return _base_img.get_pixelv(cell)

## 诊断/测试：绕过底图，直接重算一格的图层合成颜色。
func get_sampled_color(cell: Vector2i) -> Color:
	return _sample_terrain_cell(cell)

func is_sampled_from_tilemap() -> bool:
	return _base_from_tilemap

func get_layer_change_count() -> int:
	return _layer_change_count
