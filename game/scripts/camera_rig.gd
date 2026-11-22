extends Camera2D
class_name CameraRig
## RWX 式自由摄像机（借鉴 RWX GameEngine viewpointX/Y + GameLogic 平滑滚动/指针中心缩放）：
## - 屏幕边缘滚动 + WASD/方向键 + 中键拖拽
## - 滚轮缩放以指针世界坐标为中心（缩放前后指针下的世界点不动）
## - limit_* 限制在地图范围内（等价 RWX clampCameraPosition）
## - 按像素对齐视点（viewpointXSnapped），避免像素画抖动

const EDGE_MARGIN: float = 24.0
const EDGE_SPEED: float = 1000.0      # 边缘滚动 px/s（世界坐标）
const KEY_SPEED: float = 1100.0
const ZOOM_LEVELS: Array[float] = [0.5, 0.75, 1.0, 1.5, 2.0]

var _zoom_idx: int = 2                # 默认 1.0
var _dragging: bool = false

func _ready() -> void:
	make_current()
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	_apply_limits()

func setup(world_size: Vector2) -> void:
	limit_left = 0
	limit_top = 0
	limit_right = int(world_size.x)
	limit_bottom = int(world_size.y)
	var vp := get_viewport_rect().size
	position = world_size * 0.5
	if world_size.y * zoom.y < vp.y:
		position.y = minf(world_size.y, vp.y * 0.5)

func _apply_limits() -> void:
	pass  # limits 在 setup() 设置；保留钩子

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_step(1, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_step(-1, event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
	if event is InputEventMouseMotion and _dragging:
		position -= event.relative / zoom

func _zoom_step(dir: int, screen_pos: Vector2) -> void:
	var new_idx := clampi(_zoom_idx + dir, 0, ZOOM_LEVELS.size() - 1)
	if new_idx == _zoom_idx:
		return
	# RWX 指针中心缩放：缩放前后鼠标指向同一世界点
	var world_before := get_global_mouse_position()
	_zoom_idx = new_idx
	zoom = Vector2(ZOOM_LEVELS[_zoom_idx], ZOOM_LEVELS[_zoom_idx])
	position += world_before - _screen_to_world(screen_pos)
	_clamp_position()

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - get_viewport_rect().size * 0.5) / zoom + position

func _clamp_position() -> void:
	# Camera2D limit_* 已约束视口；此处再把位置钳制在地图内（双重保险）
	var half := get_viewport_rect().size * 0.5 / zoom
	position.x = clampf(position.x, minf(half.x, limit_right * 0.5), maxf(limit_right - half.x, limit_right * 0.5))
	position.y = clampf(position.y, minf(half.y, limit_bottom * 0.5), maxf(limit_bottom - half.y, limit_bottom * 0.5))

func _physics_process(delta: float) -> void:
	var move := Vector2.ZERO
	var vp_size := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()

	# 屏幕边缘滚动（指针在窗口内才生效）
	if mouse.x >= 0 and mouse.y >= 0 and mouse.x <= vp_size.x and mouse.y <= vp_size.y:
		if mouse.x < EDGE_MARGIN:
			move.x -= 1
		elif mouse.x > vp_size.x - EDGE_MARGIN:
			move.x += 1
		if mouse.y < EDGE_MARGIN:
			move.y -= 1
		elif mouse.y > vp_size.y - EDGE_MARGIN:
			move.y += 1

	# WASD / 方向键
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1

	if move != Vector2.ZERO:
		position += move.normalized() * KEY_SPEED * delta / zoom.x
		_clamp_position()

## 当前视口覆盖的世界矩形（小地图用）
func visible_world_rect() -> Rect2:
	var half := get_viewport_rect().size * 0.5 / zoom
	return Rect2(position - half, half * 2.0)

const GDA_CALLABLE := ["teleport"]

# gda: game call main/CameraRig teleport --args-json '{"x":3200,"y":2500}'
func teleport(x: float, y: float) -> void:
	position = Vector2(x, y)
	position_smoothing_enabled = false
	reset_smoothing()
	position_smoothing_enabled = true
	_clamp_position()
