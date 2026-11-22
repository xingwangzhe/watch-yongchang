extends Control
class_name SelectionBox
## 框选矩形 —— 复刻 OpenRA `WorldInteractionControllerWidget.Draw()` 的拖选反馈。
##
## OpenRA 依据（WorldInteractionControllerWidget.cs:38、59-77）：
##   bool IsValidDragbox => isDragging && (dragStart - mousePos).Length > SelectionDeadzone;
##   只有超过 deadzone 才画框，否则视为单击点选。
##   Alt → altSelectionColor，Ctrl → ctrlSelectionColor，否则 normalSelectionColor。
##
## 这里用 Control + _draw 画屏幕空间矩形：框选属于 UI 反馈，不该受世界缩放影响。

const C_FILL := Color(0.36, 0.72, 0.42, 0.18)
const C_LINE := Color(0.55, 0.90, 0.58, 0.90)
const C_FILL_ADD := Color(0.90, 0.78, 0.36, 0.18)
const C_LINE_ADD := Color(0.95, 0.84, 0.42, 0.90)

var _active: bool = false
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _additive: bool = false          ## Shift/Ctrl 加选时换色（对应 alt/ctrlSelectionColor）
var _cover: Rect2 = Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

## 开始拖选（from 为屏幕坐标）
func begin(from: Vector2, additive: bool = false) -> void:
	_from = from
	_to = from
	_additive = additive
	_active = true
	visible = false     # 未超 deadzone 前不显示（等价 IsValidDragbox）
	queue_redraw()

## 更新终点
func update_to(to: Vector2, deadzone: float) -> void:
	_to = to
	visible = _active and _from.distance_to(_to) > deadzone
	queue_redraw()

## 结束并返回屏幕矩形（未成框时返回空 Rect2）
func finish() -> Rect2:
	var had := _active and visible
	_active = false
	visible = false
	# 不能依赖 _cover：它只在 _draw 里更新，若本帧尚未绘制就是旧值
	var r := _rect_now() if had else Rect2()
	_cover = r
	queue_redraw()
	return r

func _rect_now() -> Rect2:
	var tl := Vector2(minf(_from.x, _to.x), minf(_from.y, _to.y))
	var br := Vector2(maxf(_from.x, _to.x), maxf(_from.y, _to.y))
	return Rect2(tl, br - tl)

func cancel() -> void:
	_active = false
	visible = false
	queue_redraw()

func is_active() -> bool:
	return _active

func _draw() -> void:
	if not _active or not visible:
		return
	_cover = _rect_now()
	draw_rect(_cover, C_FILL_ADD if _additive else C_FILL)
	draw_rect(_cover, C_LINE_ADD if _additive else C_LINE, false, 1.5)

## 供 main 读取当前框（世界坐标换算用）
func cover_rect() -> Rect2:
	return _cover

const GDA_CALLABLE := ["is_active", "cover_rect"]
