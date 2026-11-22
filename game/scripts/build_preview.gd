extends Node2D
## 建造预览：跟随鼠标显示 3×3 占格，合法绿框 / 非法红框（放置模式下始终可见）。
## main_ref 由 main.gd 注入（避免循环 preload）。

const TILE: int = 32
const FOOTPRINT: Vector2i = Vector2i(3, 3)
const C_OK := Color(0.36, 0.72, 0.42, 0.30)
const C_BAD := Color(0.75, 0.22, 0.18, 0.30)
const C_LINE_OK := Color(0.55, 0.90, 0.58, 0.85)
const C_LINE_BAD := Color(0.92, 0.40, 0.34, 0.85)

var main_ref: Node2D = null
var _ok: bool = false

# 与 main.gd BUILD_TYPES 保持一致（Object.get() 对脚本常量不可靠，故本地副本）
const BUILD_TYPES: Array[StringName] = [&"jianta", &"junxiefang", &"fenghuotai"]

func _process(_delta: float) -> void:
	if main_ref == null:
		visible = false
		return
	var bs: Node = main_ref.get("build_system")
	if bs == null:
		visible = false
		return
	var sel: int = int(main_ref.get("selected_build"))
	if sel < 0 or sel >= BUILD_TYPES.size():
		visible = false
		return
	var mouse: Vector2 = main_ref.get_global_mouse_position()
	var anchor: Vector2i = bs.call("world_to_cell", mouse)
	# 鼠标在地图范围外时隐藏
	if anchor.x < 0 or anchor.y < 0:
		visible = false
		return
	visible = true
	global_position = Vector2(anchor) * TILE
	_ok = bool(bs.call("can_place", anchor, BUILD_TYPES[sel]))
	queue_redraw()

func _draw() -> void:
	var fill := C_OK if _ok else C_BAD
	var line := C_LINE_OK if _ok else C_LINE_BAD
	var size := Vector2(FOOTPRINT) * TILE
	draw_rect(Rect2(Vector2.ZERO, size), fill)
	for i in range(FOOTPRINT.x + 1):
		var x := float(i) * TILE
		draw_line(Vector2(x, 0), Vector2(x, size.y), line, 1.5)
	for j in range(FOOTPRINT.y + 1):
		var y := float(j) * TILE
		draw_line(Vector2(0, y), Vector2(size.x, y), line, 1.5)
