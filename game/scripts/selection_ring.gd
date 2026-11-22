extends Node2D
## 选中高亮：跟随被选中的单位/建筑画一个角括号环。
## 只负责「画」，不参与选择判定（判定在 main._pick_unit / _pick_building）。

const C_RING := Color(0.95, 0.80, 0.35, 0.95)
const C_RING_SOFT := Color(0.95, 0.80, 0.35, 0.28)
const RADIUS_UNIT: float = 22.0
const RADIUS_BUILDING: float = 52.0

var _target: Node2D = null

func track(obj: Node) -> void:
	_target = obj as Node2D
	visible = _target != null
	queue_redraw()

func _process(_delta: float) -> void:
	if _target == null:
		if visible:
			visible = false
		return
	if not is_instance_valid(_target):
		_target = null
		visible = false
		return
	visible = true
	global_position = _target.global_position
	queue_redraw()

func _draw() -> void:
	if _target == null:
		return
	var r: float = RADIUS_BUILDING if _target.is_in_group("buildings") else RADIUS_UNIT
	var box := Rect2(-r, -r * 0.72, r * 2.0, r * 1.44)
	# 外圈淡描边 + 四角括号
	draw_rect(box.grow(2.0), C_RING_SOFT, false, 1.0)
	var arm := r * 0.42
	var pts: Array[Vector2] = [
		box.position, box.position + Vector2(arm, 0),
		box.position, box.position + Vector2(0, arm * 0.8),
		Vector2(box.end.x, box.position.y), Vector2(box.end.x - arm, box.position.y),
		Vector2(box.end.x, box.position.y), Vector2(box.end.x, box.position.y + arm * 0.8),
		Vector2(box.position.x, box.end.y), Vector2(box.position.x + arm, box.end.y),
		Vector2(box.position.x, box.end.y), Vector2(box.position.x, box.end.y - arm * 0.8),
		box.end, box.end - Vector2(arm, 0),
		box.end, box.end - Vector2(0, arm * 0.8),
	]
	for i in range(0, pts.size(), 2):
		draw_line(pts[i], pts[i + 1], C_RING, 2.0)
