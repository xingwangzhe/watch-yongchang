class_name RunHUD
extends CanvasLayer

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.png")
const OIL_METER := preload("res://scripts/ui/oil_meter.gd")
const SCALE_METER := preload("res://scripts/ui/scale_meter.gd")
const MINIMAP := preload("res://scripts/ui/minimap.gd")
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const VERMILION := Color("#c05a41")
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
var _minimap: RunMinimap


func _ready() -> void:
	layer = 5
	_build()


func update_hud(state: Dictionary) -> void:
	var hp := float(state.get("hp", 0.0))
	var max_hp := maxf(1.0, float(state.get("max_hp", 100.0)))
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d / %d" % [ceili(hp), ceili(max_hp)]
	var shield := float(state.get("shield", 0.0))
	_shield_label.visible = shield > 0.1
	_shield_label.text = Locale.t("hud.shield", {"value": "%d" % ceili(shield)})
	var xp := float(state.get("xp", 0.0))
	var xp_need := maxf(1.0, float(state.get("xp_need", 1.0)))
	_xp_bar.max_value = xp_need
	_xp_bar.value = xp
	_level_label.text = Locale.t("hud.level", {"level": int(state.get("level", 1))})
	_timer_label.text = _clock_text(float(state.get("elapsed", 0.0)), float(state.get("duration", 960.0)))
	_clock_label.text = Locale.t("hud.dawn_in", {"time": _clock_text(maxf(0.0, float(state.get("duration", 960.0)) - float(state.get("elapsed", 0.0))), 960.0)})
	_kill_label.text = Locale.t("hud.kills", {"count": int(state.get("kills", 0))})
	_merit_label.text = Locale.t("hud.merit", {"count": int(state.get("merit", 0))})
	_coin_label.text = Locale.t("hud.coin", {"count": int(state.get("coin", 0))})
	_oil_meter.set_values(int(state.get("oil", 0)), int(state.get("oil_max", 6)), bool(state.get("dark", false)))
	_oil_label.text = Locale.t("hud.dark" if bool(state.get("dark", false)) else "hud.oil", {"current": int(state.get("oil", 0)), "max": int(state.get("oil_max", 6))})
	_scale_meter.set_scales(state.get("scales", []) as Array)
	_scale_label.text = Locale.t("hud.scales", {"count": (state.get("scales", []) as Array).size()})
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
	_passive_label.text = passive_text
	_build_label.text = "%s · %s" % [
		str(state.get("build_label", "")),
		Locale.t("hud.build_extra", {
			"skills": int(state.get("skills", 0)),
			"cards": int(state.get("cards", 0)),
		}),
	]
	_move_hint.text = str(state.get("move_hint", ""))
	var boss_active := bool(state.get("boss_active", false))
	_boss_panel.visible = boss_active
	if boss_active:
		_boss_bar.max_value = maxf(1.0, float(state.get("boss_max_hp", 1.0)))
		_boss_bar.value = maxf(0.0, float(state.get("boss_hp", 0.0)))
		_boss_name.text = str(state.get("boss_name", ""))


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

	var top_shade := ColorRect.new()
	top_shade.color = Color(0.01, 0.02, 0.022, 0.62)
	top_shade.position = Vector2(0, 0)
	top_shade.size = Vector2(1280, 92)
	top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_shade)
	var bottom_shade := ColorRect.new()
	bottom_shade.color = Color(0.01, 0.02, 0.022, 0.68)
	bottom_shade.position = Vector2(0, 602)
	bottom_shade.size = Vector2(1280, 118)
	bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom_shade)

	_hp_bar = _make_progress("HpBar", Vector2(34, 22), Vector2(300, 18), Color("#a64535"))
	_root.add_child(_hp_bar)
	_hp_label = _label("HpLabel", "", 14, PAPER)
	_hp_label.position = Vector2(342, 20)
	_root.add_child(_hp_label)
	_shield_label = _label("ShieldLabel", "", 11, Color("#d8b45f"))
	_shield_label.position = Vector2(342, 42)
	_shield_label.size = Vector2(150, 18)
	_shield_label.visible = false
	_root.add_child(_shield_label)

	_level_label = _label("LevelLabel", "", 15, GOLD)
	_level_label.position = Vector2(34, 48)
	_root.add_child(_level_label)
	_xp_bar = _make_progress("XpBar", Vector2(34, 72), Vector2(390, 7), Color("#d8a548"))
	_root.add_child(_xp_bar)

	_timer_label = _label("TimerLabel", "", 31, PAPER)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.position = Vector2(500, 14)
	_timer_label.size = Vector2(280, 38)
	_root.add_child(_timer_label)
	_clock_label = _label("ClockLabel", "", 13, Color(MUTED, 0.82))
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.position = Vector2(500, 52)
	_clock_label.size = Vector2(280, 22)
	_root.add_child(_clock_label)

	_kill_label = _label("KillLabel", "", 16, PAPER)
	_kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kill_label.position = Vector2(782, 18)
	_kill_label.size = Vector2(212, 24)
	_root.add_child(_kill_label)
	_merit_label = _label("MeritLabel", "", 14, GOLD)
	_merit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_merit_label.position = Vector2(782, 45)
	_merit_label.size = Vector2(212, 24)
	_root.add_child(_merit_label)
	_coin_label = _label("CoinLabel", "", 12, Color("#d8b45f"))
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coin_label.position = Vector2(782, 69)
	_coin_label.size = Vector2(212, 20)
	_root.add_child(_coin_label)

	_minimap = MINIMAP.new()
	_minimap.name = "Minimap"
	_minimap.position = Vector2(1014, 14)
	_minimap.size = Vector2(232, 174)
	_root.add_child(_minimap)

	_oil_label = _label("OilLabel", "", 13, Color(MUTED, 0.9))
	_oil_label.position = Vector2(34, 618)
	_root.add_child(_oil_label)
	_oil_meter = OIL_METER.new()
	_oil_meter.name = "OilMeter"
	_oil_meter.position = Vector2(34, 638)
	_oil_meter.size = Vector2(178, 30)
	_root.add_child(_oil_meter)

	_scale_label = _label("ScaleLabel", "", 13, Color(MUTED, 0.9))
	_scale_label.position = Vector2(236, 618)
	_root.add_child(_scale_label)
	_scale_meter = SCALE_METER.new()
	_scale_meter.name = "ScaleMeter"
	_scale_meter.position = Vector2(236, 638)
	_scale_meter.size = Vector2(150, 30)
	_root.add_child(_scale_meter)

	var weapon_row := HBoxContainer.new()
	weapon_row.name = "WeaponRow"
	weapon_row.position = Vector2(430, 618)
	weapon_row.size = Vector2(644, 56)
	weapon_row.add_theme_constant_override("separation", 6)
	_root.add_child(weapon_row)
	for i in range(6):
		var slot := _build_weapon_slot(i)
		weapon_row.add_child(slot["root"] as Control)
		_weapon_slots.append(slot)

	_passive_label = _label("PassiveLabel", "", 12, Color(MUTED, 0.70))
	_passive_label.position = Vector2(430, 681)
	_passive_label.size = Vector2(610, 22)
	_root.add_child(_passive_label)
	_build_label = _label("BuildLabel", "", 11, Color(MUTED, 0.48))
	_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_build_label.position = Vector2(1060, 684)
	_build_label.size = Vector2(184, 20)
	_root.add_child(_build_label)
	_move_hint = _label("MoveHint", "", 10, Color(MUTED, 0.58))
	_move_hint.position = Vector2(34, 690)
	_move_hint.size = Vector2(410, 18)
	_root.add_child(_move_hint)

	_banner_panel = PanelContainer.new()
	_banner_panel.name = "BannerPanel"
	_banner_panel.visible = false
	_banner_panel.position = Vector2(424, 112)
	_banner_panel.size = Vector2(432, 92)
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
	_boss_panel.position = Vector2(390, 96)
	_boss_panel.size = Vector2(500, 62)
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


func _build_weapon_slot(index: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "WeaponSlot%d" % (index + 1)
	panel.custom_minimum_size = Vector2(104, 50)
	panel.size = Vector2(104, 50)
	panel.add_theme_stylebox_override("panel", _slot_style(false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -2)
	row.add_child(column)
	var name_label := _label("Name", "", 12, Color(PAPER, 0.90))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name_label)
	var level_label := _label("Level", "", 11, Color(GOLD, 0.82))
	column.add_child(level_label)
	panel.visible = false
	return {
		"root": panel,
		"icon": icon,
		"name": name_label,
		"level": level_label,
	}


func _update_weapons(weapons: Array) -> void:
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
	bar.position = position
	bar.size = size_value
	bar.custom_minimum_size = size_value
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.08, 0.08, 0.07, 0.86)
	background.border_color = Color(0.82, 0.69, 0.42, 0.25)
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
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.055, 0.068, 0.064, 0.92)
	box.border_color = Color(GOLD, 0.68 if evolved else 0.25)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	box.content_margin_left = 7.0
	box.content_margin_right = 5.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 5.0
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
