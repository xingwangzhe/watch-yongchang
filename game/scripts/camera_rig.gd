extends Camera2D
class_name CameraRig
## RTS 摄像机 —— 逐条复刻 OpenRA `Viewport` + `ViewportControllerWidget` 的模型。
##
## 复刻依据（OpenRA 源码，均为行号可查）：
##   Viewport.cs:102  AdjustZoom(dz)          → Zoom = zoom * exp(dz)  指数缩放
##   Viewport.cs:108  AdjustZoom(dz, center)  → 缩放后补偿 CenterLocation，
##                                              使指针下的世界点保持不动
##   Viewport.cs:364  Scroll(delta)           → CenterLocation += 1/Zoom * delta
##   Viewport.cs:137  GetBlockedDirections()  → 触到地图边时报告方向
##   ViewportControllerWidget.cs:186 UpdateCameraTick()
##        · 边缘滚动：鼠标距边 < margin 时滚动
##        · 速率按 25ms 归一化：deltaScale = min(dt,25)，
##          scroll *= deltaScale/(25*length) —— 归一化对角线，斜向不加速
##        · ViewportEdgeScroll 开关 + 窗口失去焦点时不滚
##   ViewportControllerWidget.cs:310 HandleMouseInput()
##        · 滚轮 + ZoomModifier → AdjustZoom(Δy*ZoomSpeed, 指针位置)
##        · 中键（或 Classic 风格下右键）按下 → 进入拖拽滚动，有 deadzone
##
## 与 Godot 的对应关系：
##   Godot 屏幕像素 → 世界像素的换算因子是 `1/zoom`，因此
##   OpenRA 的 `1/Zoom * delta` 在这里就是 `delta / zoom`。
##   OpenRA 的 Zoom 语义是「视野倍数」（越大看到越多），
##   Godot 的 zoom 是「放大倍数」（越大看到越少），故两者互为倒数。

# ---------- 可调参数（对应 OpenRA Game.Settings.Game）----------
@export var edge_scroll_enabled: bool = true
@export var edge_scroll_margin: float = 20.0     ## ViewportEdgeScrollMargin
@export var edge_scroll_step: float = 34.0       ## ViewportEdgeScrollStep（每 25ms 的世界像素基数）
@export var key_scroll_step: float = 34.0        ## 键盘滚动沿用同一速率
@export var zoom_speed: float = 0.22             ## ZoomSpeed：滚轮一格的 exp 指数
@export var min_zoom: float = 0.34
@export var max_zoom: float = 2.0
@export var mouse_scroll_deadzone: float = 6.0   ## MouseScrollDeadzone
@export var drag_scroll_button: int = MOUSE_BUTTON_MIDDLE
@export var smoothing_speed: float = 9.0
## OpenRA 的 Scroll/Center 都是直接赋值、无插值（Viewport.cs:364、350）。
## 开启 Godot 的 position_smoothing 会让「指针锚定缩放」失真：
## position 是逻辑值，而渲染中心被平滑拖后，screen_to_world 与实际画面不一致。
## 因此默认关闭；要弹性跟随再打开，但要接受锚点偏移。
@export var smoothing_enabled: bool = false

# ---------- 内部状态 ----------
var _drag_scrolling: bool = false
## 鼠标是否真的进过窗口。
## headless / 自动化截图环境下 get_mouse_position() 恒为 (0,0)，
## 那正好落在左上边缘带内，会导致「一启动就被边缘滚动推到地图角落」。
## OpenRA 用 Game.Renderer.WindowHasInputFocus 做同等保护（ViewportControllerWidget.cs:199）。
var _mouse_seen: bool = false
var _drag_start_screen: Vector2 = Vector2.ZERO
var _last_scroll_ms: int = 0
var _bounds: Rect2 = Rect2()                     ## 世界像素边界（= mapBounds）
var _edge_directions: int = 0                    ## 当前边缘滚动方向位
var _key_directions: int = 0

## 方向位（对应 OpenRA ScrollDirection 枚举）
const DIR_UP := 1
const DIR_DOWN := 2
const DIR_LEFT := 4
const DIR_RIGHT := 8

func _ready() -> void:
	make_current()
	position_smoothing_enabled = smoothing_enabled
	position_smoothing_speed = smoothing_speed
	# 边界由 _clamp_center() 手动钳制，关掉 Camera2D 自带的 limit 以免双重钳制抖动
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000

## 设定世界边界并把镜头放到指定中心（世界像素坐标）
func setup(world_size: Vector2, center: Vector2 = Vector2.INF) -> void:
	_bounds = Rect2(Vector2.ZERO, world_size)
	var target: Vector2 = center if center != Vector2.INF else world_size * 0.5
	_center_on(target, true)

func set_bounds(world_size: Vector2) -> void:
	_bounds = Rect2(Vector2.ZERO, world_size)
	_clamp_center()

# =====================================================================
# 核心：Scroll / AdjustZoom / Center —— 与 OpenRA 同名同义
# =====================================================================

## Viewport.Scroll(delta, ignoreBorders)：delta 为**屏幕像素**位移。
## OpenRA 是 `CenterLocation += 1/Zoom * delta`，这里即 `delta / zoom`。
func scroll(delta_screen: Vector2, ignore_borders: bool = false) -> void:
	position += delta_screen / zoom.x
	if not ignore_borders:
		_clamp_center()

## Viewport.AdjustZoom(dz)：指数缩放，保证 +/- 等量步长视觉对称
func adjust_zoom(dz: float) -> void:
	var z: float = zoom.x * exp(dz)
	z = clampf(z, min_zoom, max_zoom)
	zoom = Vector2(z, z)

## Viewport.AdjustZoom(dz, center)：以屏幕上某点为锚缩放。
## 先取锚点世界坐标 → 缩放 → 再取一次 → 把差值补回镜头中心，
## 于是缩放前后「鼠标指向的那个世界点」在屏幕上不动。
func adjust_zoom_at(dz: float, anchor_screen: Vector2) -> void:
	var before: Vector2 = screen_to_world(anchor_screen)
	var z: float = zoom.x * exp(dz)
	z = clampf(z, min_zoom, max_zoom)
	if is_equal_approx(z, zoom.x):
		return
	zoom = Vector2(z, z)
	var after: Vector2 = screen_to_world(anchor_screen)
	position += before - after
	_clamp_center()

## Viewport.Center(Vector2)：把镜头中心移到世界点（会钳制到边界内）
func center_on(world_pos: Vector2) -> void:
	_center_on(world_pos, false)

func _center_on(world_pos: Vector2, instant: bool) -> void:
	position = world_pos
	_clamp_center()
	if instant and smoothing_enabled:
		reset_smoothing()

# =====================================================================
# 坐标换算
# =====================================================================

## 屏幕坐标 → 世界坐标（Viewport.ViewToWorldPx 的等价）
func screen_to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - get_viewport_rect().size * 0.5) / zoom.x + position

## 世界坐标 → 屏幕坐标（WorldToViewPx 的等价）
func world_to_screen(world_pos: Vector2) -> Vector2:
	return (world_pos - position) * zoom.x + get_viewport_rect().size * 0.5

## 鼠标当前指向的世界坐标
func mouse_world() -> Vector2:
	return screen_to_world(get_viewport().get_mouse_position())

## 当前视口覆盖的世界矩形（小地图用）
func visible_world_rect() -> Rect2:
	var half := get_viewport_rect().size * 0.5 / zoom.x
	return Rect2(position - half, half * 2.0)

# =====================================================================
# 边界钳制 + 触边方向
# =====================================================================

func _clamp_center() -> void:
	if _bounds.size == Vector2.ZERO:
		return
	var half := get_viewport_rect().size * 0.5 / zoom.x
	# 视野比地图还大时，居中显示（等价 OpenRA mapBounds.Clamp 的退化行为）
	if _bounds.size.x <= half.x * 2.0:
		position.x = _bounds.get_center().x
	else:
		position.x = clampf(position.x, _bounds.position.x + half.x, _bounds.end.x - half.x)
	if _bounds.size.y <= half.y * 2.0:
		position.y = _bounds.get_center().y
	else:
		position.y = clampf(position.y, _bounds.position.y + half.y, _bounds.end.y - half.y)

## Viewport.GetBlockedDirections()：中心触到边界时返回对应方向位。
## 摄像机已在该方向顶死时，边缘滚动 / 键盘滚动都不再继续推（避免抖动）。
func blocked_directions() -> int:
	if _bounds.size == Vector2.ZERO:
		return 0
	var half := get_viewport_rect().size * 0.5 / zoom.x
	var out := 0
	if position.y <= _bounds.position.y + half.y + 0.5:
		out |= DIR_UP
	if position.x <= _bounds.position.x + half.x + 0.5:
		out |= DIR_LEFT
	if position.y >= _bounds.end.y - half.y - 0.5:
		out |= DIR_DOWN
	if position.x >= _bounds.end.x - half.x - 0.5:
		out |= DIR_RIGHT
	return out

# =====================================================================
# 输入
# =====================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_seen = true
	if event is InputEventMouseButton:
		_mouse_seen = true
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			adjust_zoom_at(zoom_speed, mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			adjust_zoom_at(-zoom_speed, mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == drag_scroll_button:
			if mb.pressed:
				_drag_start_screen = mb.position
				_drag_scrolling = true
			else:
				_drag_scrolling = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag_scrolling:
		var mm := event as InputEventMouseMotion
		# MouseScrollDeadzone：起手移动量不足阈值时不动，避免轻微抖动就漂移
		if (mm.position - _drag_start_screen).length() < mouse_scroll_deadzone:
			return
		scroll(-mm.relative)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# 中心被小地图/外部直接改动后，仍要保证不越界
	_clamp_center()
	_tick_scroll(delta)

## ViewportControllerWidget.UpdateCameraTick() 的等价：合并「边缘」与「键盘」两个方向位，
## 速率按 25ms 归一化并除以向量长度（对角线不加速）。
func _tick_scroll(delta: float) -> void:
	if _drag_scrolling:
		return

	_edge_directions = 0
	if edge_scroll_enabled and _mouse_seen and not _viewport_hidden():
		_edge_directions = _check_edge_directions()

	_key_directions = _check_key_directions()

	var merged: int = _edge_directions | _key_directions
	if merged == 0:
		_last_scroll_ms = 0
		return

	var dir_vec := Vector2.ZERO
	if merged & DIR_UP:
		dir_vec.y -= 1.0
	if merged & DIR_DOWN:
		dir_vec.y += 1.0
	if merged & DIR_LEFT:
		dir_vec.x -= 1.0
	if merged & DIR_RIGHT:
		dir_vec.x += 1.0
	if dir_vec == Vector2.ZERO:
		return

	# 顶死方向不再施加该轴推力
	var blocked := blocked_directions()
	if blocked & DIR_UP and dir_vec.y < 0:
		dir_vec.y = 0
	if blocked & DIR_DOWN and dir_vec.y > 0:
		dir_vec.y = 0
	if blocked & DIR_LEFT and dir_vec.x < 0:
		dir_vec.x = 0
	if blocked & DIR_RIGHT and dir_vec.x > 0:
		dir_vec.x = 0
	if dir_vec == Vector2.ZERO:
		return

	# OpenRA 原文（ViewportControllerWidget.cs:213-219）：
	#   var deltaScale = Math.Min(Game.RunTime - lastScrollTime, 25f);
	#   var length = Math.Max(1, scroll.Length());
	#   scroll *= deltaScale / (25 * length) * Game.Settings.Game.ViewportEdgeScrollStep;
	#   worldRenderer.Viewport.Scroll(scroll, false);
	# 即「每 25ms 走 step 个世界像素」，且除以向量长度使斜向不加速。
	# 这里的 dir_vec.normalized() 就是 length 归一化；delta*1000 是 ms，封顶 25。
	var base_step: float = edge_scroll_step if _edge_directions != 0 else key_scroll_step
	var unit := dir_vec.normalized()
	var step_px: float = base_step * (minf(delta * 1000.0, 25.0) / 25.0)
	scroll(unit * step_px)

## 边缘方向检测（ViewportControllerWidget.CheckForDirections 的等价）
func _check_edge_directions() -> int:
	var vp := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()
	# 指针在窗口外（含 UI 遮挡导致越界）时不触发
	if mouse.x < 0 or mouse.y < 0 or mouse.x > vp.x or mouse.y > vp.y:
		return 0
	var d := 0
	if mouse.x < edge_scroll_margin:
		d |= DIR_LEFT
	if mouse.y < edge_scroll_margin:
		d |= DIR_UP
	if mouse.x >= vp.x - edge_scroll_margin:
		d |= DIR_RIGHT
	if mouse.y >= vp.y - edge_scroll_margin:
		d |= DIR_DOWN
	return d

## 键盘方向（对应 ScrollUpKey 等四个 HotkeyReference 的按下状态）
func _check_key_directions() -> int:
	var d := 0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d |= DIR_UP
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d |= DIR_DOWN
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d |= DIR_LEFT
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d |= DIR_RIGHT
	return d

## 窗口失去焦点时不该继续边缘滚动（OpenRA: Game.Renderer.WindowHasInputFocus）
func _viewport_hidden() -> bool:
	return DisplayServer.window_is_focused() == false

# =====================================================================
# 调试 / 验收接口
# =====================================================================

const GDA_CALLABLE := ["teleport", "get_camera_state", "debug_scroll", "debug_zoom_at",
	"debug_set_zoom", "debug_frame_all"]

func teleport(x: float, y: float) -> void:
	_center_on(Vector2(x, y), true)

func debug_scroll(dx: float, dy: float) -> void:
	scroll(Vector2(dx, dy))

func debug_zoom_at(dz: float, ax: float, ay: float) -> void:
	adjust_zoom_at(dz, Vector2(ax, ay))

## 直接设定缩放倍数（gda 的 Vector2 强转不可靠，故用标量入口）
func debug_set_zoom(z: float) -> void:
	zoom = Vector2(clampf(z, min_zoom, max_zoom), clampf(z, min_zoom, max_zoom))
	_clamp_center()

## 把整张地图框进视口（截图验收全图用）
func debug_frame_all() -> void:
	if _bounds.size == Vector2.ZERO:
		return
	var vp := get_viewport_rect().size
	var z: float = minf(vp.x / _bounds.size.x, vp.y / _bounds.size.y)
	zoom = Vector2(z, z)
	position = _bounds.get_center()

func get_camera_state() -> Dictionary:
	return {
		"position": position,
		"zoom": zoom.x,
		"bounds": _bounds,
		"visible_rect": visible_world_rect(),
		"blocked": blocked_directions(),
		"edge": _edge_directions,
		"keys": _key_directions,
		"drag": _drag_scrolling,
	}
