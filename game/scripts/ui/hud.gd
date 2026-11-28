class_name RunHUD
extends CanvasLayer

signal pause_requested

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
const HUD_ICON_HEART := preload("res://assets/icons/game_icons/hud_heart.svg")
const HUD_ICON_LEVEL := preload("res://assets/icons/game_icons/hud_level.svg")
const HUD_ICON_KILLS := preload("res://assets/icons/game_icons/hud_kills.svg")
const HUD_ICON_MERIT := preload("res://assets/icons/game_icons/hud_merit.svg")
const HUD_ICON_COIN := preload("res://assets/icons/game_icons/hud_coin.svg")
const HUD_ICON_LANTERN := preload("res://assets/icons/game_icons/hud_lantern.svg")
const HUD_ICON_SCALE := preload("res://assets/icons/game_icons/hud_scale.svg")

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
var _pause_button: Button
var _portrait_layout := false
var _score_box: VBoxContainer
var _score_stats_row: HBoxContainer
var _portrait_resources_row: HBoxContainer
var _oil_info_row: HBoxContainer
var _scale_info_row: HBoxContainer
var _oil_compact_row: HBoxContainer
var _scale_compact_row: HBoxContainer
var _oil_box: VBoxContainer
var _scale_box: VBoxContainer
var _health_rows_box: BoxContainer
var _hp_row: HBoxContainer
var _xp_row: HBoxContainer
var _portrait_notice_layout := Vector4.ZERO
var _portrait_notice_scale := 1.0
var _portrait_safe_bottom := 0.0


func _ready() -> void:
	layer = 5
	_build()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if not is_instance_valid(_root) or not _root.is_inside_tree():
		return
	var viewport_size := _root.get_viewport_rect().size
	var size := _display_size()
	_apply_responsive_layout_for(viewport_size, size, UILayout.safe_area_insets())


func _display_size() -> Vector2:
	if GameSettings.is_web_platform():
		var raw := str(JavaScriptBridge.eval("JSON.stringify([window.innerWidth || 0, window.innerHeight || 0])", true))
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Array and (parsed as Array).size() >= 2:
			var values: Array = parsed
			if float(values[0]) > 0.0 and float(values[1]) > 0.0:
				return Vector2(float(values[0]), float(values[1]))
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x > 0.0 and window_size.y > 0.0:
		return window_size
	return _root.get_viewport_rect().size


func _apply_responsive_layout_for(
	viewport_size: Vector2,
	size: Vector2,
	safe_insets: Vector4 = Vector4.ZERO
) -> void:
	if viewport_size.x >= viewport_size.y:
		_portrait_layout = false
		_set_portrait_health_layout(false)
		_set_portrait_resource_layout(false)
		UILayout.scale_theme_fonts(_root, 1.0)
		_pause_button.visible = false
		_hp_bar.custom_minimum_size = Vector2(196, 12)
		_xp_bar.custom_minimum_size = Vector2(120, 5)
		_oil_meter.custom_minimum_size = Vector2(168, 18)
		_scale_meter.custom_minimum_size = Vector2(150, 18)
		_set_portrait_icon_size("HealthIcon", 14.0, 1.0)
		_set_portrait_icon_size("LevelIcon", 13.0, 1.0)
		_set_portrait_icon_size("KillIcon", 12.0, 1.0)
		_set_portrait_icon_size("MeritIcon", 12.0, 1.0)
		_set_portrait_icon_size("CoinIcon", 12.0, 1.0)
		_set_portrait_icon_size("OilIcon", 12.0, 1.0)
		_set_portrait_icon_size("ScaleIcon", 12.0, 1.0)
		UILayout.place(_root.get_node("TopLeftChip"), 14, 10, 292, 54)
		UILayout.place(_root.get_node("AttackModeChip"), 14, 72, 292, 42)
		UILayout.place(_root.get_node("TimerChip"), 520, 10, 240, 50, 0.5, 0.0)
		UILayout.place(_root.get_node("ScoreChip"), 846, 10, 198, 52)
		_minimap.visible = true
		UILayout.place(_minimap, 1054, 10, 212, 144, 1.0, 0.0)
		UILayout.place(_root.get_node("OilChip"), 14, 658, 182, 44, 0.0, 1.0)
		UILayout.place(_root.get_node("ScaleChip"), 202, 658, 168, 44, 0.0, 1.0)
		var landscape_weapon_row := _root.get_node("WeaponRow") as Control
		landscape_weapon_row.scale = Vector2.ONE
		UILayout.place(landscape_weapon_row, 377.5, 650, 625, 48, 0.5, 1.0)
		UILayout.place(_passive_label, 190, 624, 900, 20, 0.5, 1.0)
		_root.get_node("BuildChip").visible = true
		UILayout.place(_root.get_node("BuildChip"), 1036, 660, 230, 38, 1.0, 1.0)
		_move_hint.visible = true
		UILayout.place(_move_hint, 14, 704, 420, 16, 0.0, 1.0)
		UILayout.place(_banner_panel, 424, 112, 432, 92, 0.5, 0.0)
		UILayout.place(_boss_panel, 390, 96, 500, 62, 0.5, 0.0)
		_banner_panel.custom_minimum_size = Vector2.ZERO
		_boss_bar.custom_minimum_size = Vector2(456.0, 10.0)
		return
	# Portrait layout uses a single readable column above the playfield.
	# Keep the lower area clear for the joystick and action controls.
	_portrait_layout = true
	_set_portrait_health_layout(true)
	_set_portrait_resource_layout(true)
	var scale := UILayout.display_scale(viewport_size, size)
	UILayout.scale_theme_fonts(_root, 1.0 / scale)
	_apply_portrait_hud_fonts(scale)
	_hp_bar.custom_minimum_size = Vector2(110.0, UILayout.display_units(7.0, scale))
	_xp_bar.custom_minimum_size = Vector2(80.0, UILayout.display_units(5.0, scale))
	_oil_meter.custom_minimum_size = Vector2(168.0, UILayout.display_units(10.0, scale))
	_scale_meter.custom_minimum_size = Vector2(150.0, UILayout.display_units(10.0, scale))
	var side_x := UILayout.display_units(8.0 + safe_insets.x, scale)
	var content_width := UILayout.display_units(size.x - 16.0 - safe_insets.x - safe_insets.z, scale)
	var row_gap := UILayout.display_units(2.0, scale)
	var pause_height := UILayout.display_units(38.0, scale)
	var pause_width := UILayout.display_units(88.0, scale)
	var health_height := UILayout.display_units(38.0, scale)
	var status_height := UILayout.display_units(38.0, scale)
	var score_height := UILayout.display_units(38.0, scale)
	var y := UILayout.display_units(6.0 + safe_insets.y, scale)
	_pause_button.visible = true
	var health_width := content_width - pause_width - row_gap
	UILayout.place(
		_pause_button,
		UILayout.display_units(size.x - 12.0 - safe_insets.z, scale) - pause_width,
		y,
		pause_width,
		pause_height
	)
	var actual_health_height := _place_portrait_row(_root.get_node("TopLeftChip"), side_x, y, health_width, health_height)
	y += maxf(actual_health_height, pause_height) + row_gap
	var status_gap := UILayout.display_units(4.0, scale)
	var timer_width := (content_width - status_gap) * 0.48
	var attack_width := content_width - timer_width - status_gap
	var timer_actual_height := _place_portrait_row(_root.get_node("TimerChip"), side_x, y, timer_width, status_height)
	var attack_actual_height := _place_portrait_row(_root.get_node("AttackModeChip"), side_x + timer_width + status_gap, y, attack_width, status_height)
	y += maxf(timer_actual_height, attack_actual_height) + row_gap
	var resource_height := _place_portrait_row(_root.get_node("ScoreChip"), side_x, y, content_width, score_height)
	_minimap.visible = false
	_root.get_node("OilChip").visible = false
	_root.get_node("ScaleChip").visible = false
	var hud_bottom_css := (y + resource_height) * scale
	var weapon_row := _root.get_node("WeaponRow") as Control
	weapon_row.visible = false
	_passive_label.visible = false
	_root.get_node("BuildChip").visible = false
	_move_hint.visible = false
	var center_width := content_width
	# Notices stay below the compact HUD and stack when the boss panel is visible.
	var notice_top := hud_bottom_css + 6.0
	var notice_x := side_x
	var boss_y := UILayout.display_units(notice_top, scale)
	var boss_height := UILayout.display_units(58.0, scale)
	_portrait_notice_layout = Vector4(notice_x, boss_y, center_width, boss_height)
	_portrait_notice_scale = scale
	_portrait_safe_bottom = safe_insets.w
	_boss_bar.custom_minimum_size = Vector2(
		maxf(80.0, center_width - UILayout.display_units(40.0, scale)),
		UILayout.display_units(10.0, scale)
	)
	_layout_portrait_notices()
	if _banner_panel.visible:
		call_deferred("_layout_portrait_notices")


func _layout_portrait_notices() -> void:
	if not _portrait_layout or _root == null or _boss_panel == null or _banner_panel == null:
		return
	var notice_x := _portrait_notice_layout.x
	var notice_y := _portrait_notice_layout.y
	var notice_width := _portrait_notice_layout.z
	var boss_height := _portrait_notice_layout.w
	var scale := _portrait_notice_scale
	UILayout.place(_boss_panel, notice_x, notice_y, notice_width, boss_height)
	if not _banner_panel.visible:
		_banner_panel.custom_minimum_size = Vector2.ZERO
		return
	var banner_y := notice_y
	if _boss_panel.visible:
		banner_y += boss_height + UILayout.display_units(6.0, scale)
	var viewport_height := _root.get_viewport_rect().size.y
	var bottom_margin := UILayout.display_units(8.0 + _portrait_safe_bottom, scale)
	var available_height := maxf(1.0, viewport_height - banner_y - bottom_margin)
	# Apply the new width before measuring wrapped lines; the previous orientation
	# may have left the banner at its landscape width for one frame.
	UILayout.place(_banner_panel, notice_x, banner_y, notice_width, available_height)
	var title_font := _banner_title.get_theme_font("font")
	var title_size := _banner_title.get_theme_font_size("font_size")
	var banner_height := title_font.get_height(title_size) * maxi(1, _banner_title.get_line_count())
	if _banner_subtitle.visible:
		var subtitle_font := _banner_subtitle.get_theme_font("font")
		var subtitle_size := _banner_subtitle.get_theme_font_size("font_size")
		banner_height += UILayout.display_units(4.0, scale)
		banner_height += subtitle_font.get_height(subtitle_size) * maxi(1, _banner_subtitle.get_line_count())
	var panel_style := _banner_panel.get_theme_stylebox("panel")
	banner_height += panel_style.get_content_margin(SIDE_TOP) + panel_style.get_content_margin(SIDE_BOTTOM)
	banner_height += UILayout.display_units(4.0, scale)
	banner_height = minf(
		available_height,
		maxf(banner_height, UILayout.display_units(44.0, scale))
	)
	_banner_panel.custom_minimum_size = Vector2(0.0, banner_height)
	UILayout.place(_banner_panel, notice_x, banner_y, notice_width, banner_height)


func _place_portrait_row(control: Control, x: float, y: float, width: float, preferred_height: float) -> float:
	var height := maxf(preferred_height, control.get_combined_minimum_size().y)
	UILayout.place(control, x, y, width, height)
	return height


func _set_portrait_health_layout(portrait: bool) -> void:
	if _health_rows_box == null or _hp_row == null or _xp_row == null:
		return
	var is_horizontal := _health_rows_box is HBoxContainer
	if is_horizontal == portrait:
		return
	var parent := _root.get_node("TopLeftChip") as PanelContainer
	var old_box := _health_rows_box
	old_box.remove_child(_hp_row)
	old_box.remove_child(_xp_row)
	parent.remove_child(old_box)
	var replacement: BoxContainer = HBoxContainer.new() if portrait else VBoxContainer.new()
	replacement.add_theme_constant_override("separation", 6 if portrait else 4)
	replacement.add_child(_hp_row)
	replacement.add_child(_xp_row)
	parent.add_child(replacement)
	_health_rows_box = replacement
	old_box.queue_free()


func _set_portrait_resource_layout(portrait: bool) -> void:
	if _score_box == null or _oil_box == null or _scale_box == null:
		return
	var oil_chip := _root.get_node("OilChip") as PanelContainer
	var scale_chip := _root.get_node("ScaleChip") as PanelContainer
	if portrait:
		if _oil_info_row.get_parent() == _oil_box:
			_oil_box.remove_child(_oil_info_row)
			_oil_box.remove_child(_oil_meter)
			_scale_box.remove_child(_scale_info_row)
			_scale_box.remove_child(_scale_meter)
			_oil_compact_row.add_child(_oil_info_row)
			_oil_compact_row.add_child(_oil_meter)
			_scale_compact_row.add_child(_scale_info_row)
			_scale_compact_row.add_child(_scale_meter)
		_portrait_resources_row.visible = true
		_oil_info_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scale_info_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_oil_compact_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scale_compact_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_oil_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scale_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		oil_chip.visible = false
		scale_chip.visible = false
	else:
		if _oil_info_row.get_parent() == _oil_compact_row:
			_oil_compact_row.remove_child(_oil_info_row)
			_oil_compact_row.remove_child(_oil_meter)
			_scale_compact_row.remove_child(_scale_info_row)
			_scale_compact_row.remove_child(_scale_meter)
			_oil_box.add_child(_oil_info_row)
			_oil_box.add_child(_oil_meter)
			_scale_box.add_child(_scale_info_row)
			_scale_box.add_child(_scale_meter)
		_portrait_resources_row.visible = false
		_oil_info_row.size_flags_horizontal = Control.SIZE_FILL
		_scale_info_row.size_flags_horizontal = Control.SIZE_FILL
		_oil_compact_row.size_flags_horizontal = Control.SIZE_FILL
		_scale_compact_row.size_flags_horizontal = Control.SIZE_FILL
		_oil_meter.size_flags_horizontal = Control.SIZE_FILL
		_scale_meter.size_flags_horizontal = Control.SIZE_FILL
		oil_chip.visible = true
		scale_chip.visible = true


func _apply_portrait_hud_fonts(scale: float) -> void:
	# Keep the three compact top bands on one type scale. Only the timer gets a
	# small emphasis; its digits must not dominate the health and resource values.
	_set_portrait_font_size(_hp_label, 15.0, scale)
	_set_portrait_font_size(_shield_label, 14.0, scale)
	_set_portrait_font_size(_level_label, 15.0, scale)
	_set_portrait_font_size(_attack_mode_label, 15.0, scale)
	_set_portrait_font_size(_attack_toggle_label, 11.0, scale)
	_set_portrait_font_size(_timer_label, 18.0, scale)
	_set_portrait_font_size(_clock_label, 11.0, scale)
	_set_portrait_font_size(_kill_label, 15.0, scale)
	_set_portrait_font_size(_merit_label, 15.0, scale)
	_set_portrait_font_size(_coin_label, 15.0, scale)
	_set_portrait_font_size(_oil_label, 15.0, scale)
	_set_portrait_font_size(_scale_label, 15.0, scale)
	_set_portrait_font_size(_pause_button, 16.0, scale)
	_set_portrait_font_size(_banner_title, 24.0, scale)
	_set_portrait_font_size(_banner_subtitle, 16.0, scale)
	_set_portrait_font_size(_boss_name, 18.0, scale)
	_set_portrait_icon_size("HealthIcon", 14.0, scale)
	_set_portrait_icon_size("LevelIcon", 14.0, scale)
	_set_portrait_icon_size("KillIcon", 14.0, scale)
	_set_portrait_icon_size("MeritIcon", 14.0, scale)
	_set_portrait_icon_size("CoinIcon", 14.0, scale)
	_set_portrait_icon_size("OilIcon", 14.0, scale)
	_set_portrait_icon_size("ScaleIcon", 14.0, scale)


func _set_portrait_font_size(control: Control, display_pixels: float, scale: float) -> void:
	control.add_theme_font_size_override("font_size", roundi(UILayout.display_units(display_pixels, scale)))


func _set_portrait_icon_size(node_name: String, display_pixels: float, scale: float) -> void:
	var icon := _root.find_child(node_name, true, false) as TextureRect
	if icon == null:
		return
	var dimension := UILayout.display_units(display_pixels, scale)
	icon.custom_minimum_size = Vector2.ONE * dimension


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
	var kills := int(state.get("kills", 0))
	var merit := int(state.get("merit", 0))
	var coins := int(state.get("coin", 0))
	_set_label_text(_kill_label, str(kills) if _portrait_layout else Locale.t("hud.kills", {"count": kills}))
	_set_label_text(_merit_label, str(merit) if _portrait_layout else Locale.t("hud.merit", {"count": merit}))
	_set_label_text(_coin_label, str(coins) if _portrait_layout else Locale.t("hud.coin", {"count": coins}))
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
		_layout_portrait_notices()
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
	_layout_portrait_notices()
	if _portrait_layout:
		call_deferred("_layout_portrait_notices")
	_banner_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_banner_panel, "modulate", Color.WHITE, 0.22)
	_banner_timer.start(duration)


func hide_banner() -> void:
	_banner_panel.visible = false
	_banner_panel.custom_minimum_size = Vector2.ZERO
	_banner_timer.stop()


func set_boss(enemy_name: String, hp: float, max_hp: float) -> void:
	_boss_panel.visible = true
	_layout_portrait_notices()
	_boss_name.text = enemy_name
	_boss_bar.max_value = maxf(1.0, max_hp)
	_boss_bar.value = maxf(0.0, hp)


func _build() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_pause_button = Button.new()
	_pause_button.name = "MobilePauseButton"
	_pause_button.text = "菜单"
	_pause_button.visible = false
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_button.add_theme_font_override("font", UI_FONT)
	_pause_button.add_theme_font_size_override("font_size", 16)
	_pause_button.add_theme_color_override("font_color", PAPER)
	_pause_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_pause_button.add_theme_stylebox_override("normal", _mobile_pause_style())
	_pause_button.add_theme_stylebox_override("hover", _mobile_pause_style(true))
	_pause_button.add_theme_stylebox_override("pressed", _mobile_pause_style(true))
	_pause_button.add_theme_stylebox_override("focus", _mobile_pause_style())
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	_root.add_child(_pause_button)

	# 紧凑小组件：不再使用铺满屏幕的上下遮罩，只给每组信息一块半透明小底板，
	# 让战场尽量完整露出。所有坐标仍按 1280×720 设计基准。
	var top_left := _chip("TopLeftChip", 14, 10, 292, 54, 0, 0)
	# In portrait, put health and level/XP on one compact line. The old stacked
	# bars consumed most of the first screenful before the battlefield began.
	var hp_box := HBoxContainer.new()
	_health_rows_box = hp_box
	hp_box.add_theme_constant_override("separation", 6)
	top_left.add_child(hp_box)
	var hp_row := HBoxContainer.new()
	_hp_row = hp_row
	hp_row.add_theme_constant_override("separation", 8)
	hp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_box.add_child(hp_row)
	var hp_icon := _hud_icon("HealthIcon", HUD_ICON_HEART, Color("#d88370"), 14)
	hp_row.add_child(hp_icon)
	_hp_bar = _make_progress("HpBar", Vector2.ZERO, Vector2(196, 12), Color("#a64535"))
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(_hp_bar)
	_hp_label = _label("HpLabel", "", 13, PAPER)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_label.custom_minimum_size = Vector2(66, 16)
	hp_row.add_child(_hp_label)
	var xp_row := HBoxContainer.new()
	_xp_row = xp_row
	xp_row.add_theme_constant_override("separation", 6)
	xp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_box.add_child(xp_row)
	_level_label = _label("LevelLabel", "", 12, GOLD)
	_level_label.custom_minimum_size = Vector2(46, 15)
	var level_icon := _hud_icon("LevelIcon", HUD_ICON_LEVEL, GOLD, 13)
	xp_row.add_child(level_icon)
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
	_score_box = VBoxContainer.new()
	_score_box.add_theme_constant_override("separation", 3)
	score_chip.add_child(_score_box)
	_score_stats_row = HBoxContainer.new()
	_score_stats_row.add_theme_constant_override("separation", 2)
	_score_box.add_child(_score_stats_row)
	_kill_label = _add_icon_stat_row(_score_stats_row, "Kill", HUD_ICON_KILLS, 12, PAPER)
	_merit_label = _add_icon_stat_row(_score_stats_row, "Merit", HUD_ICON_MERIT, 11, GOLD)
	_coin_label = _add_icon_stat_row(_score_stats_row, "Coin", HUD_ICON_COIN, 10, Color("#d8b45f"))
	_portrait_resources_row = HBoxContainer.new()
	_portrait_resources_row.add_theme_constant_override("separation", 6)
	_oil_compact_row = HBoxContainer.new()
	_oil_compact_row.add_theme_constant_override("separation", 4)
	_scale_compact_row = HBoxContainer.new()
	_scale_compact_row.add_theme_constant_override("separation", 4)
	_portrait_resources_row.add_child(_oil_compact_row)
	_portrait_resources_row.add_child(_scale_compact_row)
	_portrait_resources_row.visible = false
	_score_box.add_child(_portrait_resources_row)

	_minimap = MINIMAP.new()
	_minimap.name = "Minimap"
	_minimap.custom_minimum_size = Vector2(212, 144)
	UILayout.place(_minimap, 1054, 10, 212, 144, 1.0, 0.0)
	_root.add_child(_minimap)

	# 左下：灯火 / 阵法小条
	var oil_chip := _chip("OilChip", 14, 658, 182, 44, 0, 1)
	_oil_box = VBoxContainer.new()
	_oil_box.add_theme_constant_override("separation", 2)
	oil_chip.add_child(_oil_box)
	_oil_label = _label("OilLabel", "", 10, Color(MUTED, 0.9))
	_oil_info_row = HBoxContainer.new()
	_oil_info_row.add_theme_constant_override("separation", 4)
	_oil_info_row.add_child(_hud_icon("OilIcon", HUD_ICON_LANTERN, GOLD, 12))
	_oil_info_row.add_child(_oil_label)
	_oil_box.add_child(_oil_info_row)
	_oil_meter = OIL_METER.new()
	_oil_meter.name = "OilMeter"
	_oil_meter.custom_minimum_size = Vector2(168, 18)
	_oil_box.add_child(_oil_meter)

	var scale_chip := _chip("ScaleChip", 202, 658, 168, 44, 0, 1)
	_scale_box = VBoxContainer.new()
	_scale_box.add_theme_constant_override("separation", 2)
	scale_chip.add_child(_scale_box)
	_scale_label = _label("ScaleLabel", "", 10, Color(MUTED, 0.9))
	_scale_info_row = HBoxContainer.new()
	_scale_info_row.add_theme_constant_override("separation", 4)
	_scale_info_row.add_child(_hud_icon("ScaleIcon", HUD_ICON_SCALE, JADE, 12))
	_scale_info_row.add_child(_scale_label)
	_scale_box.add_child(_scale_info_row)
	_scale_meter = SCALE_METER.new()
	_scale_meter.name = "ScaleMeter"
	_scale_meter.custom_minimum_size = Vector2(150, 18)
	_scale_box.add_child(_scale_meter)

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
	_banner_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_box.add_child(_banner_title)
	_banner_subtitle = _label("BannerSubtitle", "", 14, Color(PAPER, 0.84))
	_banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_boss_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


func _mobile_pause_style(hovered: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.36, 0.12, 0.08, 0.97) if hovered else Color(0.20, 0.08, 0.06, 0.94)
	box.border_color = Color(GOLD, 0.95)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


func _add_icon_stat_row(parent: Container, label_name: String, texture: Texture2D, font_size: int, color: Color) -> Label:
	var row := HBoxContainer.new()
	row.name = "%sRow" % label_name
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	row.add_child(_hud_icon("%sIcon" % label_name, texture, color, 12))
	var value := _label("%sLabel" % label_name, "", font_size, color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return value


func _hud_icon(node_name: String, texture: Texture2D, tint: Color, dimension: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.texture = texture
	icon.custom_minimum_size = Vector2(dimension, dimension)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


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
