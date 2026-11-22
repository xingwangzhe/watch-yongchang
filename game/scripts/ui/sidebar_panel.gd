extends Control
class_name SidebarPanel
## 右侧栏（复刻 OpenHV/OpenRA 右栏结构 + Mindustry 风格内容）：
##   顶部标题行（上下文名 + 副标题 + 关闭按钮）
##   左侧竖排页签列（29px 宽，页签由 payload 内容驱动，不是固定死列表）
##   内容区（ScrollContainer，列表项 = 图标 + 名称 + 价格/进度 + 快捷键角标）
##
## 默认完全隐藏：仅当「选中对象」或「打开建造/生产菜单」时由调用方 show_context() 打开。
## 关闭途径：关闭按钮 / Esc / 点击面板外空地 → close() 并清空上下文。
##
## 尺寸参考 OpenHV mods/hv/chrome/ingame-player.yaml：
##   右栏宽 245、页签列宽 29、图标格 63×47（本实现行高 47、图标 32 以适应 245 宽）。
##
## 信号契约：
##   build_requested(id)     — 建造菜单点了某项
##   produce_requested(id)   — 生产菜单点了某项（当前建筑见 context_id 属性）
##   closed()                — 面板已隐藏并清空
##   context_changed(kind)   — 上下文切换完成（&"build" / &"produce" / &"inspect"）

signal build_requested(id: StringName)
signal produce_requested(id: StringName)
signal closed()
signal context_changed(kind: StringName)

const FONT_PATH: String = "res://assets/fonts/LXGWWenKai-Regular.ttf"
const UIKit := preload("res://scripts/ui/ui_kit.gd")

# ---------- 尺寸/锚点常量（规格表见 design/UI-侧栏与滚幕规格.md）----------
const PANEL_W: float = 245.0
const MARGIN_RIGHT: float = 12.0
const TOP_Y: float = 300.0     # 小地图在上方独立，右栏从 y=300 起
const BOTTOM_GAP: float = 12.0
const TAB_COL_W: float = 29.0
const ROW_H: float = 47.0
const ICON_SIZE: float = 32.0

# ---------- 配色（与 hud.gd 完全一致）----------
const C_PANEL := Color(0.07, 0.10, 0.11, 0.90)
const C_PANEL_SOLID := Color(0.07, 0.10, 0.11, 0.98)
const C_INK := Color(0.88, 0.85, 0.74)
const C_SUB := Color(0.62, 0.62, 0.54)
const C_GOLD := Color(0.84, 0.71, 0.40)
const C_RED := Color(0.66, 0.26, 0.22)
const C_GREEN := Color(0.36, 0.58, 0.44)
const C_BTN := Color(0.14, 0.20, 0.22, 0.96)
const C_BTN_HOVER := Color(0.24, 0.32, 0.34, 0.98)
const C_BTN_SELECTED := Color(0.36, 0.28, 0.14, 0.98)
const C_LINE := Color(0.42, 0.38, 0.26, 0.55)

const KIND_BUILD := &"build"
const KIND_PRODUCE := &"produce"
const KIND_INSPECT := &"inspect"

## 点击面板外空地是否自动关闭（默认开；调用方若自行管理可关掉）
var close_on_outside_click: bool = true

var _font: Font
var _context: StringName = &""
var _payload: Dictionary = {}
var _context_id: StringName = &""      # produce: 建筑 id；inspect: 被选中对象 id
var _tabs: Array[Dictionary] = []
var _active_tab: StringName = &""

var _title_label: Label
var _subtitle_label: Label
var _tab_col: VBoxContainer
var _scroll: ScrollContainer
var _content_box: VBoxContainer
var _footer: Label

# 行内控件引用：id -> {button, progress, right, name}
var _row_refs: Dictionary = {}

# ---------- 生命周期 ----------

func _ready() -> void:
	_font = load(FONT_PATH) as Font
	_apply_layout()
	_build_ui()
	visible = false

func _apply_layout() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -(PANEL_W + MARGIN_RIGHT)
	offset_right = -MARGIN_RIGHT
	offset_top = TOP_Y
	offset_bottom = -BOTTOM_GAP
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(PANEL_W, 0.0)

# ---------- UI 构建 ----------

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "Frame"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_GOLD, 2, 6))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.name = "RootVBox"
	root_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(root_vbox)

	# --- a) 顶部标题行 ---
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 6)
	root_vbox.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.name = "TitleBox"
	title_box.add_theme_constant_override("separation", 0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	_title_label = _mk_label("", 19, C_GOLD)
	_title_label.name = "Title"
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_box.add_child(_title_label)

	_subtitle_label = _mk_label("", 12, C_SUB)
	_subtitle_label.name = "Subtitle"
	_subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_box.add_child(_subtitle_label)

	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.custom_minimum_size = Vector2(26, 26)
	close_btn.focus_mode = Control.FOCUS_ALL
	close_btn.tooltip_text = "关闭 (Esc)"
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var close_tex := UIKit.icon("close")
	if close_tex != null:
		close_btn.icon = close_tex
		close_btn.expand_icon = true
		close_btn.add_theme_constant_override("icon_max_width", 14)
	else:
		close_btn.text = "×"
		close_btn.add_theme_font_override("font", _font)
		close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("icon_normal_color", C_SUB)
	close_btn.add_theme_color_override("icon_hover_color", C_GOLD)
	close_btn.add_theme_color_override("font_color", C_SUB)
	close_btn.add_theme_color_override("font_hover_color", C_GOLD)
	close_btn.add_theme_stylebox_override("normal", _btn_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	close_btn.add_theme_stylebox_override("hover", _btn_style(C_BTN_HOVER, C_GOLD))
	close_btn.add_theme_stylebox_override("pressed", _btn_style(C_BTN_SELECTED, C_GOLD))
	close_btn.add_theme_stylebox_override("focus", _focus_style())
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	root_vbox.add_child(_hsep())

	# --- b) 页签列 + c) 内容区 ---
	var body := HBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(body)

	_tab_col = VBoxContainer.new()
	_tab_col.name = "TabColumn"
	_tab_col.custom_minimum_size = Vector2(TAB_COL_W, 0.0)
	_tab_col.add_theme_constant_override("separation", 3)
	body.add_child(_tab_col)

	_scroll = ScrollContainer.new()
	_scroll.name = "ContentScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(_scroll)

	_content_box = VBoxContainer.new()
	_content_box.name = "Content"
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 4)
	_scroll.add_child(_content_box)

	_footer = _mk_label("Esc 关闭  ·  点击空地收起", 11, C_SUB)
	_footer.name = "Footer"
	root_vbox.add_child(_footer)

# ---------- 公开 API ----------

## 打开/切换上下文。kind: &"build" / &"produce" / &"inspect"
func show_context(kind: StringName, payload: Dictionary = {}) -> void:
	_context = kind
	_payload = payload.duplicate(true)
	_context_id = StringName(str(_payload.get("building", _payload.get("id", ""))))
	_collect_tabs()
	_rebuild()
	visible = true
	context_changed.emit(kind)

## 关闭并清空上下文（不发 closed 之外的状态残留）
func close() -> void:
	var was_open := visible or _context != &""
	visible = false
	_context = &""
	_payload.clear()
	_context_id = &""
	_tabs.clear()
	_active_tab = &""
	_clear_node(_content_box)
	_clear_node(_tab_col)
	_row_refs.clear()
	if was_open:
		closed.emit()

func is_open() -> bool:
	return visible

func get_context() -> StringName:
	return _context

## 生产中的建筑 / 被选中对象 id
func get_context_id() -> StringName:
	return _context_id

## 局部刷新某一行的进度与队列数（避免每帧重建控件）
## fields 可含：progress(float 0..1)、queued(int)、cost(int)、enabled(bool)、label_progress(String)
func update_item(id: StringName, fields: Dictionary) -> void:
	var ref: Variant = _row_refs.get(id, null)
	if ref == null:
		return
	var row: Dictionary = ref as Dictionary
	var bar: Variant = row.get("progress", null)
	if bar != null and fields.has("progress"):
		var pb := bar as ProgressBar
		pb.value = clampf(float(fields["progress"]), 0.0, 1.0)
		pb.visible = float(fields["progress"]) > 0.0
	var right: Variant = row.get("right", null)
	if right != null and (fields.has("queued") or fields.has("cost")):
		var lbl := right as Label
		if fields.has("queued"):
			lbl.text = "×%d" % int(fields["queued"])
		elif fields.has("cost"):
			lbl.text = "%d 银" % int(fields["cost"])
	var btn: Variant = row.get("button", null)
	if btn != null and fields.has("enabled"):
		(btn as Button).disabled = not bool(fields["enabled"])

# ---------- 输入：Esc / 点空地关闭 ----------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		return
	if close_on_outside_click and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var local := get_global_transform_with_canvas().affine_inverse() * mb.position
			if not Rect2(Vector2.ZERO, size).has_point(local):
				close()

# ---------- 页签（内容驱动）----------

func _items() -> Array:
	var v: Variant = _payload.get("items", [])
	if v is Array:
		return v as Array
	return []

func _collect_tabs() -> void:
	_tabs.clear()
	if _context == KIND_INSPECT:
		_active_tab = &""
		return
	var declared: Variant = _payload.get("tabs", [])
	if declared is Array:
		for t in (declared as Array):
			if t is Dictionary:
				var td := t as Dictionary
				_tabs.append({
					"id": StringName(str(td.get("id", ""))),
					"label": str(td.get("label", "")),
					"icon": str(td.get("icon", "")),
				})
	if _tabs.is_empty():
		var seen: Array = []
		for it in _items():
			if not (it is Dictionary):
				continue
			var tid := StringName(str((it as Dictionary).get("tab", "")))
			if tid == &"" or seen.has(tid):
				continue
			seen.append(tid)
			var label := str((it as Dictionary).get("tab_label", str(tid)))
			_tabs.append({"id": tid, "label": label, "icon": ""})
	if _tabs.is_empty():
		var only_label := "建造" if _context == KIND_BUILD else "生产"
		_tabs.append({"id": &"", "label": only_label, "icon": ""})
	_active_tab = StringName(str(_tabs[0]["id"]))

func _build_tabs() -> void:
	_clear_node(_tab_col)
	var show_tabs := _context != KIND_INSPECT and _tabs.size() > 1
	_tab_col.visible = show_tabs
	if not show_tabs:
		return
	for i in range(_tabs.size()):
		var tab: Dictionary = _tabs[i]
		var tid := StringName(str(tab["id"]))
		var btn := Button.new()
		btn.name = "Tab_%s" % str(tid)
		btn.custom_minimum_size = Vector2(TAB_COL_W, ROW_H)
		btn.focus_mode = Control.FOCUS_ALL
		btn.tooltip_text = str(tab["label"])
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var icon_path := str(tab["icon"])
		var tex: Texture2D = null
		if icon_path != "":
			tex = load(icon_path) as Texture2D
		if tex != null:
			btn.icon = tex
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 16)
		else:
			var label := str(tab["label"])
			btn.text = label.substr(0, 1) if label.length() > 0 else "·"
			btn.add_theme_font_override("font", _font)
			btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", C_SUB)
		btn.add_theme_color_override("font_hover_color", C_GOLD)
		btn.add_theme_color_override("icon_normal_color", C_SUB)
		btn.add_theme_color_override("icon_hover_color", C_GOLD)
		_style_tab(btn, tid == _active_tab)
		btn.pressed.connect(_on_tab_pressed.bind(tid))
		_tab_col.add_child(btn)
	# 视觉补齐：页签列纵向留白由 VBox 自然分布
	var tail := Control.new()
	tail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_col.add_child(tail)

func _on_tab_pressed(tid: StringName) -> void:
	if tid == _active_tab:
		return
	_active_tab = tid
	_rebuild()

func _style_tab(btn: Button, active: bool) -> void:
	var bg := C_BTN_SELECTED if active else Color(0.10, 0.14, 0.15, 0.9)
	var border := C_GOLD if active else Color(0.28, 0.30, 0.26)
	btn.add_theme_stylebox_override("normal", _btn_style(bg, border))
	btn.add_theme_stylebox_override("hover", _btn_style(C_BTN_HOVER, C_GOLD))
	btn.add_theme_stylebox_override("pressed", _btn_style(C_BTN_SELECTED, C_GOLD))
	btn.add_theme_stylebox_override("focus", _focus_style())

# ---------- 内容重建 ----------

func _rebuild() -> void:
	_title_label.text = str(_payload.get("title", _default_title()))
	_subtitle_label.text = str(_payload.get("subtitle", ""))
	_subtitle_label.visible = _subtitle_label.text != ""
	_build_tabs()
	_clear_node(_content_box)
	_row_refs.clear()
	if _context == KIND_INSPECT:
		_build_inspect()
	else:
		_build_list()
	_footer.visible = _context != KIND_INSPECT

func _default_title() -> String:
	match _context:
		KIND_BUILD:
			return "建造"
		KIND_PRODUCE:
			return "生产队列"
		KIND_INSPECT:
			return "详情"
		_:
			return ""

func _build_list() -> void:
	var shown := 0
	for it in _items():
		if not (it is Dictionary):
			continue
		var item := it as Dictionary
		var item_tab := StringName(str(item.get("tab", "")))
		if item_tab != &"" and item_tab != _active_tab:
			continue
		_content_box.add_child(_make_item_row(item))
		shown += 1
	if shown == 0:
		_content_box.add_child(_mk_label("（暂无可选项）", 13, C_SUB))

func _make_item_row(item: Dictionary) -> Button:
	var id := StringName(str(item.get("id", "")))
	var btn := Button.new()
	btn.name = "Item_%s" % str(id)
	btn.custom_minimum_size = Vector2(0, ROW_H)
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var enabled := bool(item.get("enabled", true))
	btn.disabled = not enabled
	btn.tooltip_text = str(item.get("tooltip", item.get("label", "")))
	btn.add_theme_stylebox_override("normal", _btn_style(C_BTN, Color(0.30, 0.30, 0.26)))
	btn.add_theme_stylebox_override("hover", _btn_style(C_BTN_HOVER, C_GOLD))
	btn.add_theme_stylebox_override("pressed", _btn_style(C_BTN_SELECTED, C_GOLD))
	btn.add_theme_stylebox_override("focus", _focus_style())
	btn.add_theme_stylebox_override("disabled", _btn_style(Color(0.10, 0.12, 0.12, 0.72), Color(0.22, 0.22, 0.20)))

	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 4)
	pad.add_theme_constant_override("margin_right", 4)
	pad.add_theme_constant_override("margin_top", 3)
	pad.add_theme_constant_override("margin_bottom", 3)
	btn.add_child(pad)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	pad.add_child(row)

	# 图标（OpenHV 63×47 图标格 → 245 宽下取 32×32）
	var icon_path := str(item.get("icon", ""))
	var tex: Texture2D = null
	if icon_path != "":
		tex = load(icon_path) as Texture2D
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.45)
		row.add_child(icon)
	else:
		var ph := Control.new()
		ph.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ph)

	# 名称 + （生产模式）进度条
	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)

	var name_label := _mk_label(str(item.get("label", str(id))), 15, C_INK if enabled else C_SUB)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(name_label)

	var progress := float(item.get("progress", 0.0))
	var is_produce := _context == KIND_PRODUCE
	var bar: ProgressBar = null
	if is_produce:
		bar = ProgressBar.new()
		bar.max_value = 1.0
		bar.value = clampf(progress, 0.0, 1.0)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 5)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _flat_style(Color(0.02, 0.03, 0.03), Color(0.26, 0.26, 0.22)))
		bar.add_theme_stylebox_override("fill", _flat_style(C_GREEN, C_GREEN))
		bar.visible = progress > 0.0
		text_box.add_child(bar)
		var sub_text := str(item.get("sub", ""))
		if sub_text != "":
			var sub := _mk_label(sub_text, 11, C_SUB)
			sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			text_box.add_child(sub)
	else:
		var cost := int(item.get("cost", 0))
		if cost > 0:
			var cost_label := _mk_label("%d 银" % cost, 11, C_GOLD if enabled else C_SUB)
			text_box.add_child(cost_label)

	# 右列：价格/队列 + 快捷键角标
	var right_col := VBoxContainer.new()
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right_col.add_theme_constant_override("separation", 2)
	row.add_child(right_col)

	var right_label := _mk_label("", 12, C_GOLD if enabled else C_SUB)
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if is_produce:
		right_label.text = "×%d" % int(item.get("queued", 0))
	else:
		right_label.text = "%d" % int(item.get("cost", 0))
	right_col.add_child(right_label)

	var hotkey := str(item.get("hotkey", ""))
	var key_label := _mk_label("[%s]" % hotkey if hotkey != "" else "", 11, C_SUB)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_col.add_child(key_label)

	var bound_id := id
	if _context == KIND_BUILD:
		btn.pressed.connect(func() -> void: build_requested.emit(bound_id))
	else:
		btn.pressed.connect(func() -> void: produce_requested.emit(bound_id))

	_row_refs[id] = {"button": btn, "progress": bar, "right": right_label, "name": name_label}
	return btn

func _build_inspect() -> void:
	var hp := int(_payload.get("hp", 0))
	var max_hp := int(_payload.get("max_hp", 0))
	if max_hp > 0:
		var hp_row := HBoxContainer.new()
		hp_row.add_theme_constant_override("separation", 6)
		_content_box.add_child(hp_row)
		var cap := _mk_label("耐久", 12, C_SUB)
		hp_row.add_child(cap)
		var bar := ProgressBar.new()
		bar.max_value = float(max_hp)
		bar.value = float(hp)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("background", _flat_style(Color(0.02, 0.03, 0.03), Color(0.30, 0.30, 0.26)))
		var ratio := float(hp) / float(max_hp)
		var fill := C_GREEN
		if ratio <= 0.3:
			fill = C_RED
		elif ratio <= 0.6:
			fill = C_GOLD
		bar.add_theme_stylebox_override("fill", _flat_style(fill, fill))
		hp_row.add_child(bar)
		var num := _mk_label("%d/%d" % [hp, max_hp], 12, C_INK)
		num.custom_minimum_size = Vector2(64, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hp_row.add_child(num)
		_content_box.add_child(_hsep())

	var stats: Variant = _payload.get("stats", [])
	if stats is Array:
		for s in (stats as Array):
			if not (s is Dictionary):
				continue
			var sd := s as Dictionary
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 6)
			var k_label := _mk_label(str(sd.get("k", "")), 13, C_SUB)
			k_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(k_label)
			var v_label := _mk_label(str(sd.get("v", "")), 13, C_INK)
			v_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			line.add_child(v_label)
			_content_box.add_child(line)
	if _content_box.get_child_count() == 0:
		_content_box.add_child(_mk_label("（无信息）", 13, C_SUB))

# ---------- 控件工厂 ----------

func _mk_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _flat_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = border
	return sb

func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(2)
	return sb

func _focus_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(2)
	sb.border_color = C_GOLD
	sb.set_corner_radius_all(4)
	return sb

func _panel_style(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(0)
	return sb

func _hsep() -> ColorRect:
	var sep := ColorRect.new()
	sep.color = C_LINE
	sep.custom_minimum_size = Vector2(0, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep

func _clear_node(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

# ---------- 调试 ----------

const GDA_CALLABLE := ["show_context", "close", "is_open", "get_context", "get_context_id", "update_item"]
