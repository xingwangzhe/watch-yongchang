extends Control
class_name CreditsRoll
## 电影片尾滚幕：黑底 + 居中排版，章节金色标题、条目名称浅色、副信息灰色。
##
## 数据：res://data/credits.json
##   {"license": "...",
##    "sections": [{"title": "章节名",
##                  "entries": [{"name","role","author","license","url","note"}]}]}
##   条目 url 非空 → 名称渲染为可点击链接，点击 OS.shell_open(url)。
##
## 行为：
##   - 默认自然匀速向上滚动（AUTO_SPEED px/s），不循环；滚到尾部停在「感谢观看」处。
##   - 鼠标滚轮 / 按住左键上下拖 / ↑↓ / PgUp PgDn / Home End 均可自由操控。
##   - 手动操作后自动滚动暂停 RESUME_DELAY 秒，然后继续自然滚动（不打断整体节奏）。
##   - Esc 或「返回主菜单」按钮 → GameFlow.goto_main_menu()。
## 性能：所有 Label 一次性生成，滚动只改 RollBox.position.y，不逐帧重建控件。

const FONT_PATH: String = "res://assets/fonts/LXGWWenKai-Regular.ttf"
const CREDITS_PATH: String = "res://data/credits.json"

const AUTO_SPEED: float = 28.0        # px/s 自然滚速
const RESUME_DELAY: float = 2.5       # 手动操作后恢复自然滚动的秒数
const WHEEL_STEP: float = 90.0
const KEY_STEP: float = 64.0
const PAGE_STEP_FACTOR: float = 0.8   # PgUp/PgDn 步长 = 可视高度 × 0.8
const TAIL_ANCHOR: float = 0.55       # 滚完时「感谢观看」块停在可视区 55% 处
const BOTTOM_BAR_H: float = 56.0
const FADE_H: float = 72.0

const C_BG := Color(0.02, 0.02, 0.02)
const C_BAR := Color(0.05, 0.06, 0.06, 0.96)
const C_INK := Color(0.88, 0.85, 0.74)
const C_SUB := Color(0.60, 0.60, 0.54)
const C_DIM := Color(0.42, 0.42, 0.38)
const C_GOLD := Color(0.84, 0.71, 0.40)
const C_LINK := Color(0.58, 0.76, 0.90)
const C_WARN := Color(0.72, 0.44, 0.34)
const C_LINE := Color(0.30, 0.27, 0.20)
const C_BTN := Color(0.14, 0.20, 0.22, 0.96)
const C_BTN_HOVER := Color(0.24, 0.32, 0.34, 0.98)

var _font: Font
var _clip: Control
var _box: VBoxContainer
## 自然滚速（px/s）。默认 28；条目多时可调 40–50 缩短片尾时长（32 条约 4812px）
@export_range(10.0, 90.0, 1.0) var auto_speed: float = AUTO_SPEED
var _scroll: float = 0.0          # 等价 RollBox.position.y
var _min_scroll: float = 0.0      # 最远（内容尾部停在可视区下半）
var _max_scroll: float = 0.0      # 起点（内容整体在可视区下方）
var _content_height: float = 0.0
var _auto_resume_left: float = 0.0
var _finished: bool = false
var _dragging: bool = false
var _content_width: float = 720.0
var _ready_done: bool = false
var _entry_count: int = 0

func _ready() -> void:
	_font = load(FONT_PATH) as Font
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_build_content()
	resized.connect(_on_resized)
	# 等布局稳定后再量高（自动换行的 Label 需要先有宽度）
	await get_tree().process_frame
	_layout_content()
	await get_tree().process_frame
	_layout_content()
	_measure_content()
	_scroll = _max_scroll
	_apply_scroll()
	_ready_done = true
	print("[CREDITS] ready entries=%d content_h=%.0f" % [_entry_count, _content_height])

# ---------- 界面骨架 ----------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_clip = Control.new()
	_clip.name = "RollClip"
	_clip.anchor_left = 0.0
	_clip.anchor_right = 1.0
	_clip.anchor_top = 0.0
	_clip.anchor_bottom = 1.0
	_clip.offset_left = 0.0
	_clip.offset_right = 0.0
	_clip.offset_top = 0.0
	_clip.offset_bottom = -BOTTOM_BAR_H
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)

	# 顶/底淡出（GradientTexture2D，无外部资源）
	var top_fade := _make_fade(false)
	top_fade.name = "FadeTop"
	top_fade.anchor_left = 0.0
	top_fade.anchor_right = 1.0
	top_fade.anchor_top = 0.0
	top_fade.offset_left = 0.0
	top_fade.offset_right = 0.0
	top_fade.offset_top = 0.0
	top_fade.offset_bottom = FADE_H
	add_child(top_fade)

	var bottom_fade := _make_fade(true)
	bottom_fade.name = "FadeBottom"
	bottom_fade.anchor_left = 0.0
	bottom_fade.anchor_right = 1.0
	bottom_fade.anchor_top = 1.0
	bottom_fade.anchor_bottom = 1.0
	bottom_fade.offset_left = 0.0
	bottom_fade.offset_right = 0.0
	bottom_fade.offset_top = -BOTTOM_BAR_H - FADE_H
	bottom_fade.offset_bottom = -BOTTOM_BAR_H
	add_child(bottom_fade)

	_build_bottom_bar()

func _build_bottom_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "BottomBar"
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 0.0
	bar.offset_right = 0.0
	bar.offset_top = -BOTTOM_BAR_H
	bar.offset_bottom = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BAR
	sb.border_width_top = 1
	sb.border_color = C_LINE
	sb.set_content_margin_all(0)
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var hint := _label("滚轮 / 拖拽 / ↑↓ / PgUp·PgDn / Home·End 自由浏览    ·    Esc 返回", 14, C_DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hint)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "返回主菜单"
	back.custom_minimum_size = Vector2(150, 38)
	back.focus_mode = Control.FOCUS_ALL
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.add_theme_font_override("font", _font)
	back.add_theme_font_size_override("font_size", 17)
	back.add_theme_color_override("font_color", C_INK)
	back.add_theme_color_override("font_hover_color", C_GOLD)
	back.add_theme_stylebox_override("normal", _btn_style(C_BTN, C_GOLD))
	back.add_theme_stylebox_override("hover", _btn_style(C_BTN_HOVER, C_GOLD))
	back.add_theme_stylebox_override("pressed", _btn_style(C_BTN_HOVER, C_GOLD))
	back.pressed.connect(_back_to_menu)
	row.add_child(back)

func _make_fade(flip: bool) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.95))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(0.0, 1.0)
	t.width = 8
	t.height = 64
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.flip_v = flip
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

# ---------- 内容 ----------

func _build_content() -> void:
	_box = VBoxContainer.new()
	_box.name = "RollBox"
	_box.add_theme_constant_override("separation", 6)
	_clip.add_child(_box)

	_box.add_child(_spacer(48))

	var data := _load_credits()
	# project / subtitle 为可选键（credits.json 顶层），缺省时用固定抬头
	var project_name := str(data.get("project", "守望 · 永昌"))
	var project_sub := str(data.get("subtitle", "SHOUWANG · YONGCHANG"))
	_box.add_child(_label(project_name, 46, C_GOLD))
	_box.add_child(_label(project_sub, 14, C_DIM))
	_box.add_child(_label("片 尾 字 幕", 18, C_SUB))
	_box.add_child(_spacer(24))
	_box.add_child(_hairline())
	_box.add_child(_spacer(12))

	var license_text := str(data.get("license", ""))
	if license_text != "":
		_box.add_child(_label(license_text, 13, C_DIM, true))
		_box.add_child(_spacer(10))

	var sections_v: Variant = data.get("sections", [])
	if data.is_empty() or not (sections_v is Array) or (sections_v as Array).is_empty():
		_box.add_child(_spacer(18))
		_box.add_child(_label("片尾数据缺失：%s" % CREDITS_PATH, 18, C_WARN, true))
		_box.add_child(_label("请确认该文件存在且为合法 JSON（schema 见 design/UI-侧栏与滚幕规格.md）。", 13, C_DIM, true))
	elif sections_v is Array:
		for sec_v in (sections_v as Array):
			if sec_v is Dictionary:
				_build_section(sec_v as Dictionary)

	# 尾块
	_box.add_child(_spacer(48))
	_box.add_child(_hairline())
	_box.add_child(_spacer(24))
	_box.add_child(_label("感 谢 观 看", 40, C_GOLD))
	_box.add_child(_label("Archived by 永昌守军  ·  Godot 4.7", 13, C_DIM))
	_box.add_child(_spacer(96))

func _build_section(sec: Dictionary) -> void:
	var title := str(sec.get("title", ""))
	_box.add_child(_spacer(26))
	if title != "":
		_box.add_child(_label(title, 36, C_GOLD))
		_box.add_child(_spacer(4))
		_box.add_child(_hairline())
		_box.add_child(_spacer(10))
	var entries_v: Variant = sec.get("entries", [])
	if not (entries_v is Array):
		return
	for e_v in (entries_v as Array):
		if e_v is Dictionary:
			_build_entry(e_v as Dictionary)

func _build_entry(entry: Dictionary) -> void:
	_entry_count += 1
	var name_text := str(entry.get("name", ""))
	var url := str(entry.get("url", ""))
	if url != "":
		_box.add_child(_link(name_text, url))
	elif name_text != "":
		_box.add_child(_label(name_text, 22, C_INK))

	var meta_parts: Array[String] = []
	for key in ["role", "author", "license"]:
		var v := str(entry.get(key, ""))
		if v != "":
			meta_parts.append(v)
	if not meta_parts.is_empty():
		_box.add_child(_label(" · ".join(meta_parts), 15, C_SUB))

	var note := str(entry.get("note", ""))
	if note != "":
		_box.add_child(_label(note, 13, C_DIM, true))

	_box.add_child(_spacer(14))

func _load_credits() -> Dictionary:
	if not FileAccess.file_exists(CREDITS_PATH):
		push_warning("[CREDITS] 缺少 %s" % CREDITS_PATH)
		return {}
	var text := FileAccess.get_file_as_string(CREDITS_PATH)
	if text.is_empty():
		push_warning("[CREDITS] %s 为空" % CREDITS_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("[CREDITS] %s 不是合法 JSON 对象" % CREDITS_PATH)
		return {}
	return parsed as Dictionary

# ---------- 布局 / 滚动 ----------

func _layout_content() -> void:
	if _box == null or _clip == null:
		return
	_content_width = clampf(_clip.size.x - 160.0, 320.0, 900.0)
	_box.size = Vector2(_content_width, 0.0)
	_box.position = Vector2((_clip.size.x - _content_width) * 0.5, _box.position.y)

func _measure_content() -> void:
	if _box == null or _clip == null:
		return
	var sep := float(_box.get_theme_constant("separation"))
	var h := 0.0
	for c in _box.get_children():
		var ctl := c as Control
		if ctl == null:
			continue
		h += ctl.get_combined_minimum_size().y + sep
	_content_height = h
	var clip_h: float = _clip.size.y
	_max_scroll = clip_h
	_min_scroll = clip_h * TAIL_ANCHOR - h
	if _min_scroll > _max_scroll:
		_min_scroll = _max_scroll

func _apply_scroll() -> void:
	if _box != null:
		_box.position.y = _scroll

func _manual(delta_scroll: float) -> void:
	if not _ready_done:
		return
	_auto_resume_left = RESUME_DELAY
	_scroll = clampf(_scroll + delta_scroll, _min_scroll, _max_scroll)
	# 手动顶到尾部即视为看完（不再自动滚）；留在别处则继续自然滚动
	_finished = _scroll <= _min_scroll + 0.5
	_apply_scroll()

func _process(delta: float) -> void:
	if not _ready_done or _finished:
		return
	if _auto_resume_left > 0.0:
		_auto_resume_left -= delta
		return
	_scroll -= auto_speed * delta
	if _scroll <= _min_scroll:
		_scroll = _min_scroll
		_finished = true
	_apply_scroll()

func _on_resized() -> void:
	if not _ready_done:
		return
	_layout_content()
	_measure_content()
	_scroll = clampf(_scroll, _min_scroll, _max_scroll)
	_apply_scroll()

# ---------- 输入 ----------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_manual(-WHEEL_STEP)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_manual(WHEEL_STEP)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_manual(mm.relative.y)
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	var page: float = _clip.size.y * PAGE_STEP_FACTOR if _clip != null else 400.0
	match k.keycode:
		KEY_ESCAPE:
			_back_to_menu()
		KEY_UP:
			_manual(-KEY_STEP)
		KEY_DOWN:
			_manual(KEY_STEP)
		KEY_PAGEUP:
			_manual(-page)
		KEY_PAGEDOWN, KEY_SPACE:
			_manual(page)
		KEY_HOME:
			_manual(_max_scroll - _scroll)
		KEY_END:
			_manual(_min_scroll - _scroll)
		_:
			return
	get_viewport().set_input_as_handled()

# ---------- 链接 / 返回 ----------

func _open_url(url: String) -> void:
	if url.is_empty():
		return
	# Godot 4：web 导出的 OS.shell_open 内部走 window.open；桌面直接交给系统浏览器。
	var err: int = OS.shell_open(url)
	if err != OK:
		push_warning("[CREDITS] shell_open 失败 url=%s err=%d" % [url, err])

func _back_to_menu() -> void:
	# 优先走 autoload GameFlow（与 hud.gd 一致），取不到时退回直接切场景
	var flow := get_node_or_null("/root/GameFlow")
	if flow != null and flow.has_method("goto_main_menu"):
		flow.call("goto_main_menu")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ---------- 控件工厂 ----------

func _label(text: String, font_size: int, color: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _link(text: String, url: String) -> Control:
	var holder := HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	var btn := LinkButton.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", C_LINK)
	btn.add_theme_color_override("font_hover_color", C_GOLD)
	btn.add_theme_color_override("font_pressed_color", C_GOLD)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = url
	btn.pressed.connect(_open_url.bind(url))
	holder.add_child(btn)
	return holder

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _hairline() -> ColorRect:
	var r := ColorRect.new()
	r.color = C_LINE
	r.custom_minimum_size = Vector2(0.0, 1.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	return sb

# ---------- 调试 ----------

const GDA_CALLABLE := ["get_scroll_state", "get_entry_count"]

func get_scroll_state() -> Dictionary:
	return {
		"scroll": _scroll,
		"min": _min_scroll,
		"max": _max_scroll,
		"content_height": _content_height,
		"finished": _finished,
		"auto_resume_left": _auto_resume_left,
	}

func get_entry_count() -> int:
	return _entry_count
