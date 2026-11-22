extends Control
## 国风背景组件：宣纸底色 + 远山水墨 + 城墙剪影，供主菜单/设置复用。
## 纯 _draw 绘制，零外部素材依赖（除字体）。

const C_PAPER_TOP := Color(0.11, 0.15, 0.17)
const C_PAPER_BOT := Color(0.20, 0.21, 0.17)
const C_INK_FAR := Color(0.16, 0.22, 0.24, 0.55)
const C_INK_MID := Color(0.13, 0.18, 0.20, 0.75)
const C_WALL := Color(0.10, 0.14, 0.16, 0.92)
const C_GOLD := Color(0.72, 0.60, 0.36)
const C_RED := Color(0.55, 0.20, 0.17)

func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	# 宣纸渐变底
	for y in range(int(s.y)):
		var t := float(y) / s.y
		draw_line(Vector2(0, y), Vector2(s.x, y), C_PAPER_TOP.lerp(C_PAPER_BOT, t))
	# 远山（两层水墨三角）
	_draw_mountains(s, C_INK_FAR, 0.46, 0.10, 0.20)
	_draw_mountains(s, C_INK_MID, 0.56, 0.14, 0.13)
	# 城墙剪影
	var wall_top := s.y * 0.72
	draw_rect(Rect2(0, wall_top, s.x, s.y - wall_top), C_WALL)
	for i in range(9):
		var x := float(i) * s.x / 8.0
		draw_rect(Rect2(x - 22.0, wall_top - 26.0, 44.0, 26.0), C_WALL)
	# 城门
	var gate_w := 150.0
	var gate_h := s.y * 0.28
	draw_rect(Rect2(s.x * 0.5 - gate_w * 0.5, s.y - gate_h, gate_w, gate_h), C_PAPER_BOT)
	# 门洞红色描边
	draw_rect(Rect2(s.x * 0.5 - gate_w * 0.5, s.y - gate_h, gate_w, 6.0), C_RED)
	# 顶部朱砂细线
	draw_rect(Rect2(0, 0, s.x, 5.0), C_RED)
	draw_rect(Rect2(0, 5.0, s.x, 2.0), C_GOLD)

func _draw_mountains(s: Vector2, color: Color, base_y_ratio: float, amp: float, freq: float) -> void:
	var base_y := s.y * base_y_ratio
	var pts := PackedVector2Array()
	pts.append(Vector2(0, s.y))
	pts.append(Vector2(0, base_y))
	var steps := 16
	for i in range(steps + 1):
		var x := s.x * float(i) / float(steps)
		var y := base_y - sin(float(i) * freq * 3.14159) * s.y * amp - cos(float(i) * 0.7) * s.y * amp * 0.4
		pts.append(Vector2(x, y))
	pts.append(Vector2(s.x, s.y))
	draw_colored_polygon(pts, color)
