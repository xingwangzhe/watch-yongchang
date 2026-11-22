extends Control
## 主菜单：进入游戏的第一个界面。开始守城 / 设置 / 关于与声明 / 退出。
## 全部控件代码构建，避免 tscn 手工布局与注释坑。

const BackgroundArt = preload("res://scripts/ui/background_art.gd")
const FONT_PATH := "res://assets/fonts/LXGWWenKai-Regular.ttf"

const C_INK := Color(0.86, 0.83, 0.72)
const C_GOLD := Color(0.82, 0.70, 0.40)
const C_RED := Color(0.62, 0.24, 0.20)
const C_BTN := Color(0.16, 0.22, 0.24, 0.92)
const C_BTN_HOVER := Color(0.26, 0.34, 0.34, 0.98)

var _font: Font
var _about_panel: PanelContainer

func _ready() -> void:
	_font = load(FONT_PATH) as Font
	_build_ui()
	AudioManager.play_bgm()
	print("[MENU] main menu ready")

func _build_ui() -> void:
	# 背景
	var bg := Control.new()
	bg.name = "BackgroundArt"
	bg.set_script(BackgroundArt)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 主内容区（居中）
	var center := VBoxContainer.new()
	center.name = "CenterBox"
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.anchor_left = 0.5
	center.anchor_top = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -230.0
	center.offset_top = -250.0
	center.offset_right = 230.0
	center.offset_bottom = 200.0
	center.alignment = BoxContainer.ALIGNMENT_BEGIN
	center.add_theme_constant_override("separation", 14)
	add_child(center)

	# 标题
	var title := Label.new()
	title.name = "Title"
	title.text = "守望 · 永昌"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 62)
	title.add_theme_color_override("font_color", C_GOLD)
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "三路驿道 · 烽火传薪 · 众志成城"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", _font)
	subtitle.add_theme_font_size_override("font_size", 19)
	subtitle.add_theme_color_override("font_color", C_INK)
	center.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 34)
	center.add_child(spacer)

	# 按钮（图标取自通用 UI 装饰套件，CC0，见 generated/ui_thirdparty/LICENSES.md）
	_add_button(center, "开始守城", _on_start, "play")
	_add_button(center, "设置", _on_settings, "settings")
	_add_button(center, "关于与声明", _on_about, "info")
	_add_button(center, "制作名单（片尾滚幕）", _on_credits, "award")
	_add_button(center, "退出游戏", _on_quit, "close")

	# 底部提示
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "定时波次来袭 · 点选建筑切换右栏 · 守住永昌城"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", _font)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.62, 0.60, 0.52))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -54.0
	hint.offset_bottom = -16.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	# 关于面板（默认隐藏）
	_build_about_panel()

func _add_button(parent: Node, text: String, callback: Callable, icon_name: String = "") -> void:
	var btn := Button.new()
	btn.name = "Btn_" + text
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 58)
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", C_INK)
	btn.add_theme_color_override("font_hover_color", C_GOLD)
	if icon_name != "":
		var UIKit := preload("res://scripts/ui/ui_kit.gd")
		btn.icon = UIKit.icon(icon_name)
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 26)
	btn.add_theme_stylebox_override("normal", _make_style(C_BTN, C_GOLD))
	btn.add_theme_stylebox_override("hover", _make_style(C_BTN_HOVER, C_RED))
	btn.add_theme_stylebox_override("pressed", _make_style(C_RED, C_GOLD))
	btn.pressed.connect(callback)
	parent.add_child(btn)
	if parent.get_child_count() == 4:
		btn.grab_focus()

func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	return sb

func _build_about_panel() -> void:
	_about_panel = PanelContainer.new()
	_about_panel.name = "AboutPanel"
	_about_panel.set_anchors_preset(Control.PRESET_CENTER)
	_about_panel.anchor_left = 0.5
	_about_panel.anchor_top = 0.5
	_about_panel.anchor_right = 0.5
	_about_panel.anchor_bottom = 0.5
	_about_panel.offset_left = -320.0
	_about_panel.offset_top = -264.0
	_about_panel.offset_right = 320.0
	_about_panel.offset_bottom = 264.0
	var UIKit := preload("res://scripts/ui/ui_kit.gd")
	_about_panel.add_theme_stylebox_override("panel", UIKit.gold_panel_style(16.0))
	_about_panel.visible = false
	add_child(_about_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_about_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var h := Label.new()
	h.text = "关于与声明"
	h.add_theme_font_override("font", _font)
	h.add_theme_font_size_override("font_size", 30)
	h.add_theme_color_override("font_color", C_GOLD)
	vbox.add_child(h)

	var body_text := """
《守望·永昌》—— 2026 开源游戏开发大赛参赛作品。

主题「守·望」：以明代永昌堡抗倭史为骨，城墙、护城河、上河下河皆依史料复原，
敌军按定时波次自三门来袭，玩家建塔布防、出兵迎击、经营补给。

【AI 使用声明】
本作美术素材由 WorkBuddy ImageGen 生成并经人工后处理；
设计文档、数值表与代码由会话助手辅助编写、人工审校。
地形使用 Dungeon Crawl Stone Soup 具名图块（DCSS contributors, CC0 1.0）。
BGM「Samurai Nights」by majadroid（CC BY 3.0，opengameart.org）；音效取自 OpenGameArt（CC0）。
代码 GPL-3.0-or-later；原创非代码资产 CC BY 4.0；字体 OFL-1.1。
完整清单见「制作名单」片尾滚幕（来源可点击），或仓库 AI使用与素材声明.md 与 素材授权清单.csv。
"""
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(560, 340)
	body.add_theme_font_override("font", _font)
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", C_INK)
	vbox.add_child(body)

	var credits_btn := Button.new()
	credits_btn.text = "查看完整制作名单"
	credits_btn.custom_minimum_size = Vector2(200, 44)
	credits_btn.add_theme_font_override("font", _font)
	credits_btn.add_theme_font_size_override("font_size", 19)
	credits_btn.add_theme_stylebox_override("normal", _make_style(C_BTN, C_GOLD))
	credits_btn.add_theme_stylebox_override("hover", _make_style(C_BTN_HOVER, C_RED))
	credits_btn.pressed.connect(_on_credits)
	vbox.add_child(credits_btn)

	var close := Button.new()
	close.text = "关闭"
	close.custom_minimum_size = Vector2(140, 46)
	close.add_theme_font_override("font", _font)
	close.add_theme_font_size_override("font_size", 20)
	close.add_theme_stylebox_override("normal", _make_style(C_BTN, C_GOLD))
	close.add_theme_stylebox_override("hover", _make_style(C_BTN_HOVER, C_RED))
	close.pressed.connect(func():
		_about_panel.visible = false
		# 关闭后把焦点还给"关于与声明"按钮
		var about_btn := get_node_or_null("CenterBox/Btn_关于与声明") as Button
		if about_btn != null:
			about_btn.grab_focus()
	)
	vbox.add_child(close)

func _on_credits() -> void:
	GameFlow.goto_credits()

func _on_start() -> void:
	GameFlow.goto_battle()

func _on_settings() -> void:
	GameFlow.goto_settings(GameFlow.SCENE_MAIN_MENU)

func _on_about() -> void:
	_about_panel.visible = true
	# 面板显示后才把焦点交给关闭按钮
	var close := _about_panel.get_node_or_null("MarginContainer/VBoxContainer/Button") as Button
	if close == null:
		var vbox := _about_panel.get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
		if vbox != null and vbox.get_child_count() > 0:
			close = vbox.get_child(vbox.get_child_count() - 1) as Button
	if close != null:
		close.grab_focus()

func _on_quit() -> void:
	GameFlow.quit_game()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE and _about_panel.visible:
			_about_panel.visible = false
