extends Control

const BackdropScript := preload("res://scripts/ui/menu_backdrop.gd")
const UIControls := preload("res://scripts/ui/ui_control_theme.gd")
const IconChips := preload("res://scripts/ui/icon_chip.gd")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.webp")
const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const ICON_KATANA := preload("res://assets/icons/game_icons/wpn_katana.svg")
const ICON_SPEAR := preload("res://assets/icons/game_icons/wpn_spear.svg")
const ICON_BOW := preload("res://assets/icons/game_icons/wpn_bow.svg")
const ICON_MUSKET := preload("res://assets/icons/game_icons/wpn_musket.svg")
const ICON_DRAGON := preload("res://assets/icons/game_icons/wpn_dragon_lantern.svg")
const ICON_CANNON := preload("res://assets/icons/game_icons/wpn_cannon.svg")
const ICON_BANNER := preload("res://assets/icons/game_icons/wpn_banner.svg")

const PAPER := Color("#e8d8b6")
const MUTED := Color("#a99778")
const GOLD := Color("#d8a548")

var _title: Label
var _body: Label
var _saved: Label
var _back: Button
var _hint: Label
var _arsenal_heading: Label
var _arsenal_labels: Array[Dictionary] = []


func _ready() -> void:
	var run_theme := Theme.new()
	run_theme.default_font = UI_FONT
	run_theme.default_font_size = 20
	UIControls.install(run_theme)
	theme = run_theme

	var backdrop := BackdropScript.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "RunPanel"
	UILayout.place(panel, 230.0, 110.0, 820.0, 500.0, 0.5, 0.5)
	panel.custom_minimum_size = Vector2(820.0, 500.0)
	var panel_box := StyleBoxTexture.new()
	panel_box.texture = PANEL_TEXTURE
	panel_box.texture_margin_left = 28.0
	panel_box.texture_margin_top = 28.0
	panel_box.texture_margin_right = 28.0
	panel_box.texture_margin_bottom = 28.0
	panel_box.content_margin_left = 34.0
	panel_box.content_margin_top = 30.0
	panel_box.content_margin_right = 34.0
	panel_box.content_margin_bottom = 30.0
	panel.add_theme_stylebox_override("panel", panel_box)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)

	_title = Label.new()
	_title.name = "RunTitle"
	_title.add_theme_font_override("font", UI_FONT)
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", GOLD)
	column.add_child(_title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.color = Color(GOLD, 0.35)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	_body = Label.new()
	_body.name = "RunBody"
	_body.add_theme_font_override("font", UI_FONT)
	_body.add_theme_font_size_override("font_size", 21)
	_body.add_theme_color_override("font_color", Color(PAPER, 0.9))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(0.0, 92.0)
	column.add_child(_body)

	_arsenal_heading = Label.new()
	_arsenal_heading.name = "ArsenalHeading"
	_arsenal_heading.add_theme_font_override("font", UI_FONT)
	_arsenal_heading.add_theme_font_size_override("font_size", 17)
	_arsenal_heading.add_theme_color_override("font_color", Color(GOLD, 0.92))
	column.add_child(_arsenal_heading)
	_build_arsenal(column)

	_saved = Label.new()
	_saved.name = "RunSaved"
	_saved.add_theme_font_override("font", UI_FONT)
	_saved.add_theme_font_size_override("font_size", 15)
	_saved.add_theme_color_override("font_color", Color(GOLD, 0.78))
	column.add_child(_saved)

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grow)

	var footer := HBoxContainer.new()
	column.add_child(footer)
	_hint = Label.new()
	_hint.name = "RunHint"
	_hint.add_theme_font_override("font", UI_FONT)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(MUTED, 0.7))
	footer.add_child(_hint)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	_back = Button.new()
	_back.name = "RunBackButton"
	_back.custom_minimum_size = Vector2(190.0, 44.0)
	_back.add_theme_font_override("font", UI_FONT)
	_back.add_theme_font_size_override("font_size", 17)
	_back.add_theme_color_override("font_color", PAPER)
	UIControls.apply_compact(_back)
	_back.pressed.connect(_return_to_menu)
	footer.add_child(_back)

	Locale.language_changed.connect(_on_language_changed)
	SaveSystem.saved.connect(_refresh_saved)
	_refresh_texts()
	SaveSystem.autosave({"last_mode": "run"})
	_refresh_saved()
	_back.grab_focus()

	var timer := Timer.new()
	timer.name = "AutosaveTimer"
	timer.wait_time = 20.0
	timer.autostart = true
	timer.timeout.connect(_on_autosave_timeout)
	add_child(timer)


func _build_arsenal(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "ArsenalRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var items := [
		{"name": "ArsenalKatana", "key": "weapon.katana", "icon": ICON_KATANA},
		{"name": "ArsenalSpear", "key": "weapon.spear", "icon": ICON_SPEAR},
		{"name": "ArsenalBow", "key": "weapon.bow", "icon": ICON_BOW},
		{"name": "ArsenalMusket", "key": "weapon.musket", "icon": ICON_MUSKET},
		{"name": "ArsenalDragonLantern", "key": "weapon.dragon_lantern", "icon": ICON_DRAGON},
		{"name": "ArsenalCannon", "key": "weapon.cannon", "icon": ICON_CANNON},
		{"name": "ArsenalBanner", "key": "weapon.banner", "icon": ICON_BANNER},
	]
	for spec in items:
		var key := str(spec["key"])
		var chip: Dictionary = IconChips.make_tile(
			spec["icon"] as Texture2D,
			Locale.t(key),
			42
		)
		var chip_root: Control = chip["root"]
		chip_root.name = str(spec["name"])
		row.add_child(chip_root)
		_arsenal_labels.append({"label": chip["label"] as Label, "key": key})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_menu()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveSystem.autosave({"last_mode": "run"})
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		SaveSystem.autosave({"last_mode": "run"})


func _refresh_texts() -> void:
	_title.text = Locale.t("run.title")
	_body.text = Locale.t("run.body")
	_back.text = Locale.t("run.back")
	_hint.text = Locale.t("run.hint")
	_arsenal_heading.text = Locale.t("run.arsenal")
	for entry in _arsenal_labels:
		var label: Label = entry["label"]
		if is_instance_valid(label):
			label.text = Locale.t(str(entry["key"]))
	_refresh_saved()


func _on_language_changed(_code: String) -> void:
	_refresh_texts()


func _refresh_saved() -> void:
	var stamp := SaveSystem.last_saved_text()
	var suffix := "" if stamp.is_empty() else " · %s" % stamp
	_saved.text = "%s%s" % [Locale.t("run.autosaved"), suffix]


func _on_autosave_timeout() -> void:
	SaveSystem.autosave({"last_mode": "run"})


func _return_to_menu() -> void:
	SaveSystem.autosave({"last_mode": "menu"})
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
