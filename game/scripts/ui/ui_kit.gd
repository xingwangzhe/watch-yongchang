extends RefCounted
## 通用 UI 装饰套件。
##
## 统一出口第三方 CC0 装饰素材（见 generated/ui_thirdparty/LICENSES.md）：
## - panel_gold.png：golden-ui by buch 裁切面板（琥珀金像素边框 + 深色芯）
## - icon_*.png：Free UI Asset Pack 1 by ctatz 白色符号染色为金色
##
## 使用：const UIKit := preload("res://scripts/ui/ui_kit.gd")
##       panel.add_theme_stylebox_override("panel", UIKit.gold_panel_style())

const PANEL_GOLD_PATH: String = "res://assets/ui/panel_gold.png"

## 金框面板九宫格样式（可复用于任意尺寸 PanelContainer）。
static func gold_panel_style(content_margin: float = 12.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(PANEL_GOLD_PATH) as Texture2D
	sb.texture_margin_left = 8.0
	sb.texture_margin_right = 8.0
	sb.texture_margin_top = 8.0
	sb.texture_margin_bottom = 8.0
	sb.draw_center = true
	sb.content_margin_left = content_margin + 2.0
	sb.content_margin_right = content_margin + 2.0
	sb.content_margin_top = content_margin
	sb.content_margin_bottom = content_margin
	return sb

## 通用金色图标。
static func icon(icon_name: String) -> Texture2D:
	return load("res://assets/ui/icon_%s.png" % icon_name) as Texture2D
