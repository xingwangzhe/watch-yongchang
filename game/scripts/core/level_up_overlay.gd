class_name LevelUpOverlay
extends Control

signal chosen(index: int)

const INPUT_LOCK_MSEC := 200

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const VERMILION := Color("#c05a41")

var _title: Label
var _subtitle: Label
var _pool_label: Label
var _hint: Label
var _unlock_at_msec := 0
var _input_locked := false
var _cards: Array[Button] = []
var _options: Array[Dictionary] = []
var _hint_pool := 0
var _column: VBoxContainer
var _card_row: HBoxContainer
var _mobile_scroll: ScrollContainer
var _mobile_stack: VBoxContainer
var _card_slots: Array[Control] = []
var _portrait_layout := false
var _display_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "LevelUpOverlay"
	z_index = 50
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	visible = false


func show_options(options: Array[Dictionary], level: int, info: Dictionary = {}) -> void:
	_options = options
	visible = true
	_unlock_at_msec = Time.get_ticks_msec() + INPUT_LOCK_MSEC
	_input_locked = true
	_hint_pool = int(info.get("pool", options.size()))
	_title.text = Locale.t("levelup.title")
	_subtitle.text = Locale.t("levelup.subtitle", {"level": level})
	_pool_label.text = Locale.t("levelup.pool", {
		"pool": _hint_pool,
		"taken": int(info.get("taken", 0)),
	})
	_set_cards_locked(true)
	_refresh_selection_hint()
	for i in range(_cards.size()):
		var card := _cards[i]
		if i >= options.size():
			card.visible = false
			card.disabled = true
			continue
		card.visible = true
		_apply_option(card, options[i], i)
		_animate_card(card, i)


func hide_options() -> void:
	visible = false
	_input_locked = false
	_unlock_at_msec = 0
	_set_cards_locked(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index := -1
		match event.physical_keycode:
			KEY_1:
				index = 0
			KEY_2:
				index = 1
			KEY_3:
				index = 2
		if index >= 0:
			_choose(index)
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		_refresh_input_lock()


func is_locked() -> bool:
	_refresh_input_lock()
	return _input_locked


func can_choose(index: int = -1) -> bool:
	if not visible or is_locked():
		return false
	return index < 0 or (index >= 0 and index < _options.size())


func _refresh_input_lock() -> void:
	if not _input_locked:
		return
	var remaining := _unlock_at_msec - Time.get_ticks_msec()
	if remaining <= 0:
		_input_locked = false
		_set_cards_locked(false)
		if not _cards.is_empty() and _cards[0].visible:
			_cards[0].grab_focus()
	_refresh_selection_hint()


func _set_cards_locked(locked: bool) -> void:
	for i in range(_cards.size()):
		_cards[i].disabled = locked or i >= _options.size()


func _refresh_selection_hint() -> void:
	if _hint == null:
		return
	if _input_locked:
		var remaining := maxi(1, _unlock_at_msec - Time.get_ticks_msec())
		var seconds := ceilf(float(remaining) / 100.0) / 10.0
		_hint.text = Locale.t("levelup.locked", {"seconds": "%0.1f" % seconds})
		_hint.add_theme_color_override("font_color", VERMILION)
	else:
		_hint.text = Locale.t("levelup.hint", {"pool": _hint_pool})
		_hint.add_theme_color_override("font_color", Color(MUTED, 0.58))


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.006, 0.010, 0.012, 0.90)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var left_glow := ColorRect.new()
	left_glow.color = Color(0.72, 0.48, 0.18, 0.06)
	left_glow.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left_glow.offset_left = 32.0
	left_glow.offset_right = 35.0
	left_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_glow)
	var right_glow := ColorRect.new()
	right_glow.color = Color(0.72, 0.48, 0.18, 0.06)
	right_glow.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right_glow.offset_left = -35.0
	right_glow.offset_right = -32.0
	right_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_glow)

	var column := VBoxContainer.new()
	_column = column
	UILayout.place(column, 54.0, 24.0, 1172.0, 672.0, 0.5, 0.5)
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	_title = _label(Locale.t("levelup.title"), 38, GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_subtitle = _label("", 15, Color(MUTED, 0.88))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)
	_pool_label = _label("", 11, Color(MUTED, 0.58))
	_pool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_pool_label)

	var row := HBoxContainer.new()
	_card_row = row
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)

	for i in range(3):
		var card := Button.new()
		card.name = "UpgradeCard%d" % (i + 1)
		card.custom_minimum_size = Vector2(348.0, 490.0)
		card.clip_contents = true
		card.add_theme_stylebox_override("normal", _card_style(Color(0.045, 0.060, 0.062, 0.98), Color(GOLD, 0.28)))
		card.add_theme_stylebox_override("hover", _card_style(Color(0.070, 0.082, 0.076, 0.99), Color(GOLD, 0.88)))
		card.add_theme_stylebox_override("pressed", _card_style(Color(0.085, 0.078, 0.055, 0.99), Color(GOLD, 1.0)))
		card.pressed.connect(_choose.bind(i))
		row.add_child(card)
		_cards.append(card)
		_build_card(card, i)
		_cache_mobile_card_layout(card)
		var slot := Control.new()
		slot.name = "MobileUpgradeCardSlot%d" % (i + 1)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_card_slots.append(slot)

	_mobile_scroll = ScrollContainer.new()
	_mobile_scroll.name = "MobileUpgradeScroll"
	_mobile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mobile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_mobile_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mobile_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mobile_scroll.visible = false
	column.add_child(_mobile_scroll)
	_mobile_stack = VBoxContainer.new()
	_mobile_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mobile_stack.add_theme_constant_override("separation", 20)
	_mobile_scroll.add_child(_mobile_stack)

	_hint = _label(Locale.t("levelup.hint", {"pool": 0}), 11, Color(MUTED, 0.58))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint)


func _screen_size() -> Vector2:
	if OS.has_feature("web"):
		var parsed: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify([window.innerWidth || 0, window.innerHeight || 0])", true)))
		if parsed is Array and (parsed as Array).size() >= 2:
			var css_size := Vector2(float(parsed[0]), float(parsed[1]))
			if css_size.x > 0.0 and css_size.y > 0.0:
				return css_size
	var window_size := Vector2(DisplayServer.window_get_size())
	return window_size if window_size.x > 0.0 and window_size.y > 0.0 else get_viewport_rect().size


func _apply_responsive_layout() -> void:
	if not is_instance_valid(_column):
		return
	var viewport_size := get_viewport_rect().size
	var screen_size := _screen_size()
	_display_scale = UILayout.display_scale(viewport_size, screen_size)
	_portrait_layout = screen_size.y > screen_size.x
	if _portrait_layout:
		var margin := UILayout.display_units(12.0, _display_scale)
		var top := UILayout.display_units(18.0, _display_scale)
		var bottom := UILayout.display_units(18.0, _display_scale)
		UILayout.place(_column, margin, top, viewport_size.x - margin * 2.0, viewport_size.y - top - bottom)
		_column.add_theme_constant_override("separation", UILayout.display_units(6.0, _display_scale))
		_title.add_theme_font_size_override("font_size", maxi(28, roundi(30.0 / _display_scale)))
		_subtitle.add_theme_font_size_override("font_size", maxi(19, roundi(20.0 / _display_scale)))
		_pool_label.add_theme_font_size_override("font_size", maxi(16, roundi(16.0 / _display_scale)))
		_hint.add_theme_font_size_override("font_size", maxi(16, roundi(16.0 / _display_scale)))
		_card_row.visible = false
		_mobile_scroll.visible = true
		_hint.visible = false
		# Resize the actual Controls, rather than scaling their draw transform.
		# ScrollContainer measures Control sizes and otherwise leaves a narrow hit
		# region even when the card appears wider.
		var available_width := maxf(1.0, viewport_size.x - margin * 2.0)
		var width_scale := available_width / 348.0
		var height_scale := width_scale * 0.76
		for index in range(_cards.size()):
			var card := _cards[index]
			var slot := _card_slots[index]
			if slot.get_parent() != _mobile_stack:
				if card.get_parent() == _card_row:
					_card_row.remove_child(card)
				_mobile_stack.add_child(slot)
				if card.get_parent() != slot:
					if card.get_parent() != null:
							card.get_parent().remove_child(card)
					slot.add_child(card)
			var card_size := Vector2(available_width, 490.0 * height_scale)
			card.custom_minimum_size = card_size
			card.size = card_size
			card.position = Vector2.ZERO
			card.scale = Vector2.ONE
			card.pivot_offset = Vector2.ZERO
			_apply_mobile_card_layout(card, width_scale, height_scale)
			slot.custom_minimum_size = card_size
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.size = card_size
		_card_row.visible = false
	else:
		UILayout.place(_column, 54.0, 24.0, 1172.0, 672.0, 0.5, 0.5)
		_column.add_theme_constant_override("separation", 8)
		_title.add_theme_font_size_override("font_size", 38)
		_subtitle.add_theme_font_size_override("font_size", 15)
		_pool_label.add_theme_font_size_override("font_size", 11)
		_hint.add_theme_font_size_override("font_size", 11)
		_hint.visible = true
		_mobile_scroll.visible = false
		_card_row.visible = true
		for index in range(_cards.size()):
			var card := _cards[index]
			var slot := _card_slots[index]
			if card.get_parent() == slot:
				slot.remove_child(card)
				_mobile_stack.remove_child(slot)
				_card_row.add_child(card)
			card.custom_minimum_size = Vector2(348.0, 490.0)
			card.scale = Vector2.ONE
			card.pivot_offset = Vector2.ZERO
			for node in card.find_children("*", "Control", true, false):
				var control := node as Control
				var base_offsets: Vector4 = control.get_meta("mobile_base_offsets", Vector4.ZERO)
				control.offset_left = base_offsets.x
				control.offset_top = base_offsets.y
				control.offset_right = base_offsets.z
				control.offset_bottom = base_offsets.w
				control.custom_minimum_size = control.get_meta("mobile_base_minimum", Vector2.ZERO)
				if control is Label:
					control.add_theme_font_size_override("font_size", int(control.get_meta("mobile_base_font_size", 12)))


func _build_card(card: Button, index: int) -> void:
	var cw := 348.0
	var ch := 490.0
	var accent := ColorRect.new()
	accent.name = "CardAccent"
	accent.color = Color(GOLD, 0.9)
	UILayout.place_in(accent, 0, 0, 348, 4, cw, ch)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(accent)

	var number := _label(str(index + 1), 12, Color(MUTED, 0.58))
	number.name = "CardNumber"
	UILayout.place_in(number, 14, 10, 20, 20, cw, ch)
	card.add_child(number)

	var family := _label("", 11, MUTED)
	family.name = "CardFamily"
	UILayout.place_in(family, 186, 10, 148, 20, cw, ch, 1.0, 0.0)
	family.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(family)

	var icon_plate := PanelContainer.new()
	icon_plate.name = "CardIconPlate"
	icon_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UILayout.place_in(icon_plate, 115, 34, 118, 118, cw, ch, 0.5, 0.0)
	icon_plate.add_theme_stylebox_override("panel", _icon_plate_style(Color(GOLD, 0.18)))
	card.add_child(icon_plate)
	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_plate.add_child(icon_center)
	var icon := TextureRect.new()
	icon.name = "CardIcon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(82, 82)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_center.add_child(icon)

	var kind := _label("", 11, Color(MUTED, 0.82))
	kind.name = "CardKind"
	UILayout.place_in(kind, 18, 156, 312, 20, cw, ch, 0.5, 0.0)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(kind)

	var title := _label("", 24, GOLD)
	title.name = "CardTitle"
	UILayout.place_in(title, 16, 178, 316, 54, cw, ch, 0.5, 0.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(title)

	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.24)
	UILayout.place_in(rule, 40, 238, 268, 1, cw, ch, 0.5, 0.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rule)

	var description := _label("", 14, PAPER)
	description.name = "CardDescription"
	UILayout.place_in(description, 22, 248, 304, 58, cw, ch, 0.5, 0.0)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(description)

	var effect := _label("", 12, Color("#f0c363"))
	effect.name = "CardEffect"
	UILayout.place_in(effect, 22, 306, 304, 30, cw, ch, 0.5, 0.0)
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(effect)

	var culture_label := _label(Locale.t("levelup.culture_label"), 10, Color(VERMILION, 0.92))
	UILayout.place_in(culture_label, 22, 340, 304, 16, cw, ch, 0.5, 0.0)
	card.add_child(culture_label)

	var culture := _label("", 12, Color(PAPER, 0.82))
	culture.name = "CardCulture"
	UILayout.place_in(culture, 22, 356, 304, 92, cw, ch, 0.5, 0.0)
	culture.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(culture)

	var meta_rule := ColorRect.new()
	meta_rule.color = Color(GOLD, 0.14)
	UILayout.place_in(meta_rule, 22, 450, 304, 1, cw, ch, 0.5, 0.0)
	meta_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(meta_rule)

	var level := _label("", 10, Color(GOLD, 0.86))
	level.name = "CardLevel"
	UILayout.place_in(level, 22, 456, 158, 18, cw, ch)
	card.add_child(level)

	var rarity := _label("", 10, Color(MUTED, 0.78))
	rarity.name = "CardRarity"
	UILayout.place_in(rarity, 180, 456, 146, 18, cw, ch, 1.0, 0.0)
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(rarity)

	var category := _label("", 9, Color(VERMILION, 0.82))
	category.name = "CardCategory"
	UILayout.place_in(category, 22, 472, 304, 14, cw, ch, 0.5, 0.0)
	category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(category)


func _cache_mobile_card_layout(card: Button) -> void:
	for node in card.find_children("*", "Control", true, false):
		var control := node as Control
		control.set_meta("mobile_base_offsets", Vector4(
			control.offset_left, control.offset_top,
			control.offset_right, control.offset_bottom
		))
		control.set_meta("mobile_base_minimum", control.custom_minimum_size)
		if control is Label:
			control.set_meta("mobile_base_font_size", control.get_theme_font_size("font_size"))


func _apply_mobile_card_layout(card: Button, width_scale: float, height_scale: float) -> void:
	var font_scale := width_scale * 0.88
	for node in card.find_children("*", "Control", true, false):
		var control := node as Control
		var base_offsets: Vector4 = control.get_meta("mobile_base_offsets", Vector4.ZERO)
		control.offset_left = base_offsets.x * width_scale
		control.offset_right = base_offsets.z * width_scale
		control.offset_top = base_offsets.y * height_scale
		control.offset_bottom = base_offsets.w * height_scale
		var base_minimum: Vector2 = control.get_meta("mobile_base_minimum", Vector2.ZERO)
		control.custom_minimum_size = Vector2(base_minimum.x * width_scale, base_minimum.y * height_scale)
		if control is Label:
			var base_font_size := float(control.get_meta("mobile_base_font_size", 12))
			control.add_theme_font_size_override("font_size", maxi(10, roundi(base_font_size * font_scale)))


func _apply_option(card: Button, option: Dictionary, index: int) -> void:
	var family := str(option.get("family", ""))
	var color := UpgradeCatalog.family_color(family)
	var rarity := str(option.get("rarity", "common"))
	var rarity_color := _rarity_color(rarity)
	card.set_meta("option_index", index)
	(card.find_child("CardAccent", true, false) as ColorRect).color = color
	var family_label := card.find_child("CardFamily", true, false) as Label
	family_label.text = str(option.get("kind_label", ""))
	family_label.add_theme_color_override("font_color", color)
	(card.find_child("CardKind", true, false) as Label).text = Locale.t("levelup.level", {
		"level": int(option.get("level", 1)),
		"max": int(option.get("max_level", 1)),
	})
	(card.find_child("CardTitle", true, false) as Label).text = str(option.get("title", ""))
	(card.find_child("CardDescription", true, false) as Label).text = str(option.get("description", ""))
	(card.find_child("CardCulture", true, false) as Label).text = str(option.get("culture", ""))
	(card.find_child("CardEffect", true, false) as Label).text = str(option.get("effect_summary", ""))
	(card.find_child("CardLevel", true, false) as Label).text = _level_pips(
		int(option.get("level", 1)),
		int(option.get("max_level", 1))
	)
	var rarity_label := card.find_child("CardRarity", true, false) as Label
	rarity_label.text = "%s · %s" % [
		Locale.t("levelup.rarity"),
		str(option.get("rarity_label", "")),
	]
	rarity_label.add_theme_color_override("font_color", rarity_color)
	var category := UpgradeCatalog.localized_category(str(option.get("category", "")))
	var category_label := card.find_child("CardCategory", true, false) as Label
	category_label.text = category if not category.is_empty() else str(option.get("kind_label", ""))
	var source_text := GameData.source_label(option)
	category_label.tooltip_text = source_text
	card.tooltip_text = "%s\n%s" % [source_text, option.get("effect_summary", "")]
	var icon := card.find_child("CardIcon", true, false) as TextureRect
	var texture := GameData.texture(str(option.get("icon", "")))
	icon.texture = texture
	icon.visible = texture != null
	icon.modulate = color.lightened(0.30)
	(card.find_child("CardIconPlate", true, false) as PanelContainer).add_theme_stylebox_override(
		"panel",
		_icon_plate_style(Color(color, 0.22))
	)
	card.add_theme_stylebox_override("normal", _card_style(Color(0.045, 0.060, 0.062, 0.98), Color(rarity_color, 0.42)))
	card.add_theme_stylebox_override("hover", _card_style(Color(0.070, 0.082, 0.076, 0.99), Color(color, 0.90)))


func _animate_card(card: Button, index: int) -> void:
	card.modulate = Color(1, 1, 1, 0)
	var target_scale := Vector2.ONE * (348.0 / maxf(1.0, card.custom_minimum_size.x) if _portrait_layout else 1.0)
	if _portrait_layout:
		target_scale = card.scale
	card.scale = target_scale * 0.97
	card.pivot_offset = card.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "modulate:a", 1.0, 0.22).set_delay(float(index) * 0.055)
	tween.tween_property(card, "scale", target_scale, 0.24).set_delay(float(index) * 0.055)


func _level_pips(level: int, max_level: int) -> String:
	var pips := ""
	for i in range(max_level):
		pips += "◆" if i < level else "◇"
	return pips


func _choose(index: int) -> void:
	if can_choose(index):
		chosen.emit(index)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	return box


func _icon_plate_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.04, 0.04, 0.76)
	box.border_color = color
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 59
	box.corner_radius_top_right = 59
	box.corner_radius_bottom_left = 59
	box.corner_radius_bottom_right = 59
	return box


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color("#7fb7a8")
		"rare":
			return Color("#79a9bf")
		"legendary":
			return Color("#e08a4f")
	return Color("#baa98a")
