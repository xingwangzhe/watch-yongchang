class_name RunHUD
extends CanvasLayer

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.webp")
const OIL_METER := preload("res://scripts/ui/oil_meter.gd")
const SCALE_METER := preload("res://scripts/ui/scale_meter.gd")
const MINIMAP := preload("res://scripts/ui/minimap.gd")
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const VERMILION := Color("#c05a41")
const JADE := Color("#7fb7a8")
const INK := Color(0.018, 0.028, 0.031, 0.88)

var _root: Control
var _hp_bar: ProgressBar
var _hp_label: Label
var _shield_label: Label
var _xp_bar: ProgressBar
var _level_label: Label
var _timer_label: Label
var _clock_label: Label
var _kill_label: Label
var _merit_label: Label
var _coin_label: Label
var _oil_meter: OilMeter
var _scale_meter: ScaleMeter
var _oil_label: Label
var _scale_label: Label
var _weapon_slots: Array[Dictionary] = []
var _passive_label: Label
var _banner_panel: PanelContainer
var _banner_title: Label
var _banner_subtitle: Label
var _banner_timer: Timer
var _boss_panel: PanelContainer
var _boss_bar: ProgressBar
var _boss_name: Label
var _build_label: Label
var _move_hint: Label
var _attack_mode_label: Label
var _attack_toggle_label: Label
var _minimap: RunMinimap
var _slot_style_normal: StyleBoxFlat
var _slot_style_evolved: StyleBoxFlat
var _weapon_signature := ""
var _last_boss_visible := false


func _ready() -> void:
	layer = 5
	_build()


func update_hud(state: Dictionary) -> void:
	var hp := float(state.get("hp", 0.0))
	var max_hp := maxf(1.0, float(state.get("max_hp", 100.0)))
	if not is_equal_approx(_hp_bar.max_value, max_hp):
		_hp_bar.max_value = max_hp
	if not is_equal_approx(_hp_bar.value, hp):
		_hp_bar.value = hp
	_set_label_text(_hp_label, "%d / %d" % [ceili(hp), ceili(max_hp)])
	var shield := float(state.get("shield", 0.0))
	_shield_label.visible = shield > 0.1
	_set_label_text(_shield_label, Locale.t("hud.shield", {"value": "%d" % ceili(shield)}))
	var xp := float(state.get("xp", 0.0))
	var xp_need := maxf(1.0, float(state.get("xp_need", 1.0)))
	if not is_equal_approx(_xp_bar.max_value, xp_need):
		_xp_bar.max_value = xp_need
	if not is_equal_approx(_xp_bar.value, xp):
		_xp_bar.value = xp
	_set_label_text(_level_label, Locale.t("hud.level", {"level": int(state.get("level", 1))}))
	_set_label_text(_timer_label, _clock_text(float(state.get("elapsed", 0.0)), float(state.get("duration", 960.0))))
	_set_label_text(_clock_label, Locale.t("hud.dawn_in", {"time": _clock_text(maxf(0.0, float(state.get("duration", 960.0)) - float(state.get("elapsed", 0.0))), 960.0)}))
	_set_label_text(_kill_label, Locale.t("hud.kills", {"count": int(state.get("kills", 0))}))
	_set_label_text(_merit_label, Locale.t("hud.merit", {"count": int(state.get("merit", 0))}))
	_set_label_text(_coin_label, Locale.t("hud.coin", {"count": int(state.get("coin", 0))}))
	_oil_meter.set_values(int(state.get("oil", 0)), int(state.get("oil_max", 6)), bool(state.get("dark", false)))
	_set_label_text(_oil_label, Locale.t("hud.dark" if bool(state.get("dark", false)) else "hud.oil", {"current": int(state.get("oil", 0)), "max": int(state.get("oil_max", 6))}))
	_scale_meter.set_scales(state.get("scales", []) as Array)
	_set_label_text(_scale_label, Locale.t("hud.scales", {"count": (state.get("scales", []) as Array).size()}))
	_update_weapons(state.get("weapons", []) as Array)
	var mercenary_summary := str(state.get("mercenary_summary", ""))
	var passive_text := str(state.get("passive_summary", ""))
	if int(state.get("mercenary_count", 0)) > 0:
		var mercenary_text := Locale.t("hud.mercenary", {
			"count": int(state.get("mercenary_count", 0)),
			"max": int(state.get("mercenary_max", 3)),
			"names": mercenary_summary,
		})
		passive_text = "%s · %s" % [passive_text, mercenary_text]
	_set_label_text(_passive_label, passive_text)
	_set_label_text(_build_label, "%s · %s" % [
		str(state.get("build_label", "")),
		Locale.t("hud.build_extra", {
			"skills": int(state.get("skills", 0)),
			"cards": int(state.get("cards", 0)),
		}),
	])
	_set_label_text(_move_hint, str(state.get("move_hint", "")))
	var auto_attack := bool(state.get("auto_attack", false))
	_set_label_text(_attack_mode_label, str(state.get("attack_mode", Locale.t("hud.attack_auto" if auto_attack else "hud.attack_manual"))))
	_attack_mode_label.add_theme_color_override("font_color", JADE if auto_attack else GOLD)
	_set_label_text(_attack_toggle_label, str(state.get("attack_toggle", "")))
	var boss_active := bool(state.get("boss_active", false))
	if _last_boss_visible != boss_active:
		_boss_panel.visible = boss_active
		_last_boss_visible = boss_active
	if boss_active:
		_boss_bar.max_value = maxf(1.0, float(state.get("boss_max_hp", 1.0)))
		_boss_bar.value = maxf(0.0, float(state.get("boss_hp", 0.0)))
		_set_label_text(_boss_name, str(state.get("boss_name", "")))


func bind_world(field: Battlefield, definition: Dictionary, camera: Camera2D) -> void:
	if _minimap == null:
		return
	_minimap.bind(field, definition, camera)


func show_banner(title: String, subtitle: String = "", duration: float = 3.0) -> void:
	_banner_title.text = title
	_banner_subtitle.text = subtitle
	_banner_subtitle.visible = not subtitle.is_empty()
	_banner_panel.visible = true
	_banner_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_banner_panel, "modulate", Color.WHITE, 0.22)
	_banner_timer.start(duration)


func hide_banner() -> void:
	_banner_panel.visible = false
	_banner_timer.stop()


func set_boss(enemy_name: String, hp: float, max_hp: float) -> void:
	_boss_panel.visible = true
	_boss_name.text = enemy_name
	_boss_bar.max_value = maxf(1.0, max_hp)
	_boss_bar.value = maxf(0.0, hp)


func _build() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# 紧凑小组件：不再使用铺满屏幕的上下遮罩，只给每组信息一块半透明小底板，
	# 让战场尽量完整露出。所有坐标仍按 1280×720 设计基准。
	var top_left := _chip("TopLeftChip", 14, 10, 292, 54, 0, 0)
	var hp_box := VBoxContainer.new()
	hp_box.add_theme_constant_override("separation", 4)
	top_left.add_child(hp_box)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	hp_box.add_child(hp_row)
	_hp_bar = _make_progress("HpBar", Vector2.ZERO, Vector2(196, 12), Color("#a64535"))
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(_hp_bar)
	_hp_label = _label("HpLabel", "", 13, PAPER)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_label.custom_minimum_size = Vector2(66, 16)
	hp_row.add_child(_hp_label)
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 6)
	hp_box.add_child(xp_row)
	_level_label = _label("LevelLabel", "", 12, GOLD)
	_level_label.custom_minimum_size = Vector2(58, 15)
	xp_row.add_child(_level_label)
	_xp_bar = _make_progress("XpBar", Vector2.ZERO, Vector2(120, 5), Color("#d8a548"))
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_row.add_child(_xp_bar)
	_shield_label = _label("ShieldLabel", "", 10, Color("#d8b45f"))
	_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shield_label.custom_minimum_size = Vector2(58, 14)
	_shield_label.visible = false
	xp_row.add_child(_shield_label)

	# 左上第二行：明确显示手动／自动攻击状态与可重绑的切换键。
	var attack_chip := _chip("AttackModeChip", 14, 72, 292, 42, 0, 0)
	var attack_box := VBoxContainer.new()
	attack_box.add_theme_constant_override("separation", 0)
	attack_chip.add_child(attack_box)
	_attack_mode_label = _label("AttackModeLabel", Locale.t("hud.attack_manual"), 13, GOLD)
	attack_box.add_child(_attack_mode_label)
	_attack_toggle_label = _label("AttackToggleLabel", "", 10, Color(MUTED, 0.86))
	attack_box.add_child(_attack_toggle_label)

	# 顶部居中：倒计时
	var timer_chip := _chip("TimerChip", 520, 10, 240, 50, 0.5, 0)
	var timer_box := VBoxContainer.new()
	timer_box.add_theme_constant_override("separation", 0)
	timer_chip.add_child(timer_box)
	_timer_label = _label("TimerLabel", "", 26, PAPER)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_box.add_child(_timer_label)
	_clock_label = _label("ClockLabel", "", 10, Color(MUTED, 0.82))
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_box.add_child(_clock_label)

	# 右上：战绩小条 + 小地图；二者不重叠，也不压住战场中心。
	var score_chip := _chip("ScoreChip", 846, 10, 198, 52, 0, 0)
	var score_box := VBoxContainer.new()
	score_box.add_theme_constant_override("separation", 0)
	score_chip.add_child(score_box)
	_kill_label = _label("KillLabel", "", 12, PAPER)
	_kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_box.add_child(_kill_label)
	_merit_label = _label("MeritLabel", "", 11, GOLD)
	_merit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_box.add_child(_merit_label)
	_coin_label = _label("CoinLabel", "", 10, Color("#d8b45f"))
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_box.add_child(_coin_label)

	_minimap = MINIMAP.new()
	_minimap.name = "Minimap"
	_minimap.custom_minimum_size = Vector2(212, 144)
	UILayout.place(_minimap, 1054, 10, 212, 144, 1.0, 0.0)
	_root.add_child(_minimap)

	# 左下：灯火 / 阵法小条
	var oil_chip := _chip("OilChip", 14, 658, 182, 44, 0, 1)
	var oil_box := VBoxContainer.new()
	oil_box.add_theme_constant_override("separation", 2)
	oil_chip.add_child(oil_box)
	_oil_label = _label("OilLabel", "", 10, Color(MUTED, 0.9))
	oil_box.add_child(_oil_label)
	_oil_meter = OIL_METER.new()
	_oil_meter.name = "OilMeter"
	_oil_meter.custom_minimum_size = Vector2(168, 18)
	oil_box.add_child(_oil_meter)

	var scale_chip := _chip("ScaleChip", 202, 658, 168, 44, 0, 1)
	var scale_box := VBoxContainer.new()
	scale_box.add_theme_constant_override("separation", 2)
	scale_chip.add_child(scale_box)
	_scale_label = _label("ScaleLabel", "", 10, Color(MUTED, 0.9))
	scale_box.add_child(_scale_label)
	_scale_meter = SCALE_METER.new()
	_scale_meter.name = "ScaleMeter"
	_scale_meter.custom_minimum_size = Vector2(150, 18)
	scale_box.add_child(_scale_meter)

	# 底部居中：兵器槽 / 被动
	var weapon_row := HBoxContainer.new()
	weapon_row.name = "WeaponRow"
	UILayout.place(weapon_row, 377.5, 650, 625, 48, 0.5, 1.0)
	weapon_row.add_theme_constant_override("separation", 5)
	_root.add_child(weapon_row)
	for i in range(6):
		var slot := _build_weapon_slot(i)
		weapon_row.add_child(slot["root"] as Control)
		_weapon_slots.append(slot)

	_passive_label = _label("PassiveLabel", "", 10, Color(MUTED, 0.72))
	_passive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UILayout.place(_passive_label, 190, 624, 900, 20, 0.5, 1.0)
	_root.add_child(_passive_label)

	var build_chip := _chip("BuildChip", 1036, 660, 230, 38, 1, 1)
	_build_label = _label("BuildLabel", "", 9, Color(MUTED, 0.62))
	_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_build_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_build_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_chip.add_child(_build_label)

	_move_hint = _label("MoveHint", "", 9, Color(MUTED, 0.52))
	_move_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_move_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UILayout.place(_move_hint, 14, 704, 420, 16, 0.0, 1.0)
	_root.add_child(_move_hint)

	# 顶部居中弹窗：横幅 / Boss 条
	_banner_panel = PanelContainer.new()
	_banner_panel.name = "BannerPanel"
	_banner_panel.visible = false
	UILayout.place(_banner_panel, 424, 112, 432, 92, 0.5, 0.0)
	_banner_panel.add_theme_stylebox_override("panel", _banner_style())
	_root.add_child(_banner_panel)
	var banner_box := VBoxContainer.new()
	banner_box.add_theme_constant_override("separation", 4)
	_banner_panel.add_child(banner_box)
	_banner_title = _label("BannerTitle", "", 24, GOLD)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(_banner_title)
	_banner_subtitle = _label("BannerSubtitle", "", 14, Color(PAPER, 0.84))
	_banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(_banner_subtitle)
	_banner_timer = Timer.new()
	_banner_timer.one_shot = true
	_banner_timer.timeout.connect(hide_banner)
	add_child(_banner_timer)

	_boss_panel = PanelContainer.new()
	_boss_panel.name = "BossPanel"
	_boss_panel.visible = false
	UILayout.place(_boss_panel, 390, 96, 500, 62, 0.5, 0.0)
	_boss_panel.add_theme_stylebox_override("panel", _banner_style())
	_root.add_child(_boss_panel)
	var boss_box := VBoxContainer.new()
	boss_box.add_theme_constant_override("separation", 4)
	_boss_panel.add_child(boss_box)
	_boss_name = _label("BossName", "", 16, VERMILION)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(_boss_name)
	_boss_bar = _make_progress("BossBar", Vector2.ZERO, Vector2(456, 10), Color("#b94a37"))
	boss_box.add_child(_boss_bar)


func _chip(node_name: String, x: float, y: float, w: float, h: float, ax: float, ay: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _chip_style())
	UILayout.place(panel, x, y, w, h, ax, ay)
	_root.add_child(panel)
	return panel


func _chip_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.012, 0.022, 0.024, 0.50)
	box.border_color = Color(GOLD, 0.16)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 5
	box.corner_radius_top_right = 5
	box.corner_radius_bottom_left = 5
	box.corner_radius_bottom_right = 5
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 5.0
	return box


func _build_weapon_slot(index: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "WeaponSlot%d" % (index + 1)
	panel.custom_minimum_size = Vector2(100, 48)
	panel.add_theme_stylebox_override("panel", _slot_style(false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -3)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var name_label := _label("Name", "", 10, Color(PAPER, 0.90))
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.custom_minimum_size = Vector2(0, 24)
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(name_label)
	var level_label := _label("Level", "", 9, Color(GOLD, 0.82))
	column.add_child(level_label)
	panel.visible = false
	return {
		"root": panel,
		"icon": icon,
		"name": name_label,
		"level": level_label,
	}


func _update_weapons(weapons: Array) -> void:
	var signature_parts: Array[String] = []
	for weapon in weapons:
		var item := weapon as Dictionary
		signature_parts.append("%s:%s:%s:%s" % [
			str(item.get("id", "")),
			str(item.get("icon", "")),
			int(item.get("level", 1)),
			bool(item.get("evolved", false)),
		])
	var signature := "|".join(signature_parts)
	if signature == _weapon_signature:
		return
	_weapon_signature = signature
	for i in range(_weapon_slots.size()):
		var slot := _weapon_slots[i]
		var panel := slot["root"] as PanelContainer
		if i >= weapons.size():
			panel.visible = false
			continue
		var weapon := weapons[i] as Dictionary
		panel.visible = true
		var icon := slot["icon"] as TextureRect
		var texture := GameData.texture(str(weapon.get("icon", "")))
		icon.texture = texture
		icon.visible = texture != null
		(slot["name"] as Label).text = str(weapon.get("name", ""))
		var level := int(weapon.get("level", 1))
		var max_level := int(weapon.get("max_level", 5))
		(slot["level"] as Label).text = Locale.t("hud.max") if bool(weapon.get("evolved", false)) else "Lv %d/%d" % [level, max_level]
		panel.add_theme_stylebox_override("panel", _slot_style(bool(weapon.get("evolved", false))))


func _set_label_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


func _clock_text(seconds: float, _duration: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d" % [int(total / 60), total % 60]


func _label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_progress(node_name: String, position: Vector2, size_value: Vector2, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = node_name
	UILayout.place(bar, position.x, position.y, size_value.x, size_value.y, 0.0, 0.0)
	bar.custom_minimum_size = size_value
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.05, 0.045, 0.62)
	background.border_color = Color(0.82, 0.69, 0.42, 0.20)
	background.border_width_left = 1
	background.border_width_top = 1
	background.border_width_right = 1
	background.border_width_bottom = 1
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _slot_style(evolved: bool) -> StyleBoxFlat:
	var cached := _slot_style_evolved if evolved else _slot_style_normal
	if cached != null:
		return cached
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.048, 0.045, 0.72)
	box.border_color = Color(GOLD, 0.62 if evolved else 0.20)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 3
	box.corner_radius_top_right = 3
	box.corner_radius_bottom_left = 3
	box.corner_radius_bottom_right = 3
	box.content_margin_left = 5.0
	box.content_margin_right = 4.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	if evolved:
		_slot_style_evolved = box
	else:
		_slot_style_normal = box
	return box


func _banner_style() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = PANEL_TEXTURE
	box.texture_margin_left = 28.0
	box.texture_margin_top = 28.0
	box.texture_margin_right = 28.0
	box.texture_margin_bottom = 28.0
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box
