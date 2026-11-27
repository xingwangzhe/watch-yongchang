## UI 相对定位工具
##
## 以 1280×720 设计基准，把「设计坐标 + 锚点比例」转换为 Godot Control 的
## anchor + offset。这样组件随视口边缘自适应，而不是钉死在左上角绝对像素上。
##
## 用法：
##   UILayout.place(node, x, y, w, h, ax, ay)
## 其中 ax/ay 取值 0（左/上）、0.5（中）、1（右/下）：
##   - 左上元素  ax=0,   ay=0
##   - 顶部居中  ax=0.5, ay=0
##   - 右上元素  ax=1,   ay=0
##   - 左下元素  ax=0,   ay=1
##   - 底部居中  ax=0.5, ay=1
##   - 右下元素  ax=1,   ay=1
##   - 正中弹窗  ax=0.5, ay=0.5
##
## 注意：只用于 UI（Control）节点定位。世界坐标（Node2D / _draw）保持原样。
class_name UILayout
extends RefCounted

const DESIGN_W := 1280.0
const DESIGN_H := 720.0


## 按设计坐标与锚点放置控件，并显式设置尺寸。
static func place(
	node: Control,
	x: float, y: float,
	w: float, h: float,
	ax: float = 0.0, ay: float = 0.0
) -> void:
	place_in(node, x, y, w, h, DESIGN_W, DESIGN_H, ax, ay)


## 在固定尺寸的父容器内按设计坐标放置（base_w/base_h 为父容器设计尺寸）。
## 用于升级卡、商店卡等内部固定画布：坐标仍按设计稿书写，但落点是 anchor + offset，
## 卡片尺寸变化时内部元素会按比例跟随，而不是钉死在左上角像素上。
static func place_in(
	node: Control,
	x: float, y: float,
	w: float, h: float,
	base_w: float, base_h: float,
	ax: float = 0.0, ay: float = 0.0
) -> void:
	node.anchor_left = ax
	node.anchor_top = ay
	node.anchor_right = ax
	node.anchor_bottom = ay
	node.offset_left = x - base_w * ax
	node.offset_top = y - base_h * ay
	node.offset_right = node.offset_left + w
	node.offset_bottom = node.offset_top + h


## 仅重设尺寸（保持已有锚点/左上偏移）。
static func set_size(node: Control, w: float, h: float) -> void:
	node.offset_right = node.offset_left + w
	node.offset_bottom = node.offset_top + h


## 设置相对锚点但保留当前左上角位置对应的设计坐标。
static func anchor(node: Control, ax: float, ay: float) -> void:
	var design_x := node.offset_left + DESIGN_W * node.anchor_left
	var design_y := node.offset_top + DESIGN_H * node.anchor_top
	place(
		node,
		design_x, design_y,
		node.offset_right - node.offset_left,
		node.offset_bottom - node.offset_top,
		ax, ay
	)


## Convert CSS/display pixel measurements to the project's logical 1280x720 design units.
## Godot canvas stretch scales the logical viewport down on narrow portrait screens.
static func display_scale(viewport_size: Vector2, screen_size: Vector2) -> float:
	return maxf(0.05, screen_size.x / maxf(1.0, viewport_size.x))


static func display_units(value: float, scale: float) -> float:
	return value / maxf(0.05, scale)


## Apply a device-pixel font scale while retaining the unscaled theme values.
static func scale_theme_fonts(root: Control, factor: float) -> void:
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		var base_sizes: Dictionary = control.get_meta("layout_base_font_sizes", {}) as Dictionary
		for theme_key in ["font_size", "font_size_hbox"]:
			if not base_sizes.has(theme_key):
				var original := control.get_theme_font_size(theme_key)
				if original > 0:
					base_sizes[theme_key] = original
		control.set_meta("layout_base_font_sizes", base_sizes)
		for theme_key in base_sizes.keys():
			control.add_theme_font_size_override(str(theme_key), maxi(8, int(round(float(base_sizes[theme_key]) * factor))))
