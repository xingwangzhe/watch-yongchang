class_name ShopOverlay
extends Control

signal buy_requested(index: int)
signal reroll_requested
signal closed

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.webp")
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const VERMILION := Color("#c05a41")

var _title: Label
var _subtitle: Label
var _coin_label: Label
var _merc_label: Label
var _hint: Label
var _reroll_button: Button
var _continue_button: Button
var _cards: Array[Button] = []
var _offers: Array[Dictionary] = []
var _panel: PanelContainer
var _column: VBoxContainer
var _header: HBoxContainer
var _heading: VBoxContainer
var _wallet: VBoxContainer
var _grid: GridContainer
var _scroll: ScrollContainer
var _footer: VBoxContainer
var _action_row: HBoxContainer
var _portrait_layout := false


func _ready() -> void:
	name = "ShopOverlay"
	z_index = 55
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func show_shop(
	offers: Array[Dictionary],
	coin: int,
	reroll_cost: int,
	mercenary_info: Dictionary
) -> void:
	visible = true
	refresh(offers, coin, reroll_cost, mercenary_info)
	for i in range(_cards.size()):
		if i < offers.size() and not bool(offers[i].get("sold", false)):
			_cards[i].grab_focus()
			_animate_card(_cards[i], i)
			break


func refresh(
	offers: Array[Dictionary],
	coin: int,
	reroll_cost: int,
	mercenary_info: Dictionary
) -> void:
	_offers = offers
	_title.text = Locale.t("shop.title")
	_subtitle.text = Locale.t("shop.subtitle")
	_coin_label.text = Locale.t("shop.coin", {"coin": coin})
	_merc_label.text = Locale.t("shop.mercenaries", {
		"count": int(mercenary_info.get("count", 0)),
		"max": int(mercenary_info.get("max", 3)),
		"names": str(mercenary_info.get("names", "")),
	})
	_reroll_button.text = Locale.t("shop.reroll", {"cost": reroll_cost})
	_reroll_button.disabled = coin < reroll_cost
	_continue_button.text = Locale.t("shop.continue")
	_hint.text = Locale.t("shop.hint")
	for i in range(_cards.size()):
		var card := _cards[i]
		if i >= offers.size():
			card.visible = false
			continue
		card.visible = true
		_apply_offer(card, offers[i], i, coin)


func show_message(message: String, error: bool = false) -> void:
	_hint.text = message
	_hint.add_theme_color_override(
		"font_color",
		Color(VERMILION, 0.96) if error else Color(GOLD, 0.90)
	)


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
			KEY_4:
				index = 3
			KEY_5:
				index = 4
			KEY_6:
				index = 5
			KEY_7:
				index = 6
			KEY_8:
				index = 7
			KEY_9:
				index = 8
			KEY_0:
				index = 9
		if index >= 0 and index < _offers.size() and not bool(_offers[index].get("sold", false)):
			buy_requested.emit(index)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_R:
			reroll_requested.emit()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_SPACE]:
			closed.emit()
			get_viewport().set_input_as_handled()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.006, 0.010, 0.012, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var lantern_glow := ColorRect.new()
	lantern_glow.color = Color(0.88, 0.55, 0.20, 0.07)
	UILayout.place(lantern_glow, 68, 0, 1144, 3, 0.5, 0.0)
	lantern_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lantern_glow)

	_panel = PanelContainer.new()
	UILayout.place(_panel, 32, 18, 1216, 684, 0.5, 0.5)
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 8)
	_panel.add_child(_column)

	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 14)
	_column.add_child(_header)
	_heading = VBoxContainer.new()
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_heading)
	_title = _label(Locale.t("shop.title"), 35, GOLD)
	_heading.add_child(_title)
	_subtitle = _label(Locale.t("shop.subtitle"), 13, Color(MUTED, 0.82))
	_heading.add_child(_subtitle)
	_wallet = VBoxContainer.new()
	_wallet.custom_minimum_size = Vector2(230, 58)
	_header.add_child(_wallet)
	_coin_label = _label("", 20, GOLD)
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet.add_child(_coin_label)
	_merc_label = _label("", 11, Color(PAPER, 0.72))
	_merc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_merc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wallet.add_child(_merc_label)

	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.28)
	rule.custom_minimum_size = Vector2(0, 1)
	_column.add_child(rule)

	_scroll = ScrollContainer.new()
	_scroll.name = "OfferScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.name = "OfferGrid"
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)
	for i in range(12):
		var card := Button.new()
		card.name = "ShopCard%d" % (i + 1)
		card.custom_minimum_size = Vector2(272, 168)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.clip_contents = true
		card.add_theme_stylebox_override(
			"normal",
			_card_style(Color(0.040, 0.052, 0.054, 0.99), Color(GOLD, 0.30))
		)
		card.add_theme_stylebox_override(
			"hover",
			_card_style(Color(0.064, 0.076, 0.070, 1.0), Color(GOLD, 0.88))
		)
		card.add_theme_stylebox_override(
			"pressed",
			_card_style(Color(0.082, 0.074, 0.050, 1.0), Color(GOLD, 1.0))
		)
		card.pressed.connect(_choose.bind(i))
		_grid.add_child(card)
		_cards.append(card)
		_build_card(card, i)

	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", 6)
	_column.add_child(_footer)
	_hint = _label(Locale.t("shop.hint"), 12, Color(MUTED, 0.66))
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer.add_child(_hint)
	_action_row = HBoxContainer.new()
	_action_row.add_theme_constant_override("separation", 12)
	_footer.add_child(_action_row)
	_reroll_button = _button(Locale.t("shop.reroll", {"cost": 0}), false)
	_reroll_button.pressed.connect(func() -> void: reroll_requested.emit())
	_action_row.add_child(_reroll_button)
	_continue_button = _button(Locale.t("shop.continue"), true)
	_continue_button.pressed.connect(func() -> void: closed.emit())
	_action_row.add_child(_continue_button)
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if not is_instance_valid(_panel) or not _panel.is_inside_tree():
		return
	var viewport_size := get_viewport_rect().size
	var screen_size := _display_size()
	_portrait_layout = screen_size.y > screen_size.x
	var scale := UILayout.display_scale(viewport_size, screen_size)
	if _portrait_layout:
		var inset := UILayout.display_units(8.0, scale)
		_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel.offset_left = inset
		_panel.offset_top = inset
		_panel.offset_right = -inset
		_panel.offset_bottom = -inset
		_column.add_theme_constant_override("separation", int(UILayout.display_units(6.0, scale)))
		_header.add_theme_constant_override("separation", int(UILayout.display_units(6.0, scale)))
		if _wallet.get_parent() != _heading:
			_wallet.get_parent().remove_child(_wallet)
			_heading.add_child(_wallet)
		_wallet.custom_minimum_size = Vector2.ZERO
		_wallet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_merc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_title.add_theme_font_size_override("font_size", maxi(26, roundi(30.0 / scale)))
		_subtitle.add_theme_font_size_override("font_size", maxi(15, roundi(15.0 / scale)))
		_coin_label.add_theme_font_size_override("font_size", maxi(18, roundi(20.0 / scale)))
		_merc_label.add_theme_font_size_override("font_size", maxi(14, roundi(14.0 / scale)))
		_grid.columns = 1
		_grid.add_theme_constant_override("h_separation", 0)
		_grid.add_theme_constant_override("v_separation", int(UILayout.display_units(7.0, scale)))
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		var card_width := maxf(0.0, viewport_size.x - inset * 2.0 - UILayout.display_units(44.0, scale))
		var card_height := UILayout.display_units(170.0, scale)
		for i in range(_cards.size()):
			var card := _cards[i]
			card.custom_minimum_size = Vector2(card_width, card_height)
			_layout_mobile_card(card, card_width, card_height, scale)
		_hint.add_theme_font_size_override("font_size", maxi(14, roundi(14.0 / scale)))
		_action_row.add_theme_constant_override("separation", int(UILayout.display_units(8.0, scale)))
		_reroll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_reroll_button.custom_minimum_size = Vector2(0.0, UILayout.display_units(48.0, scale))
		_continue_button.custom_minimum_size = Vector2(0.0, UILayout.display_units(48.0, scale))
		_reroll_button.add_theme_font_override("font", UI_FONT)
		_continue_button.add_theme_font_override("font", UI_FONT)
		var action_font := maxi(18, roundi(17.0 / scale))
		_reroll_button.add_theme_font_size_override("font_size", action_font)
		_continue_button.add_theme_font_size_override("font_size", action_font)
	else:
		_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel.offset_left = 0.0
		_panel.offset_top = 0.0
		_panel.offset_right = 0.0
		_panel.offset_bottom = 0.0
		UILayout.place(_panel, 32, 18, 1216, 684, 0.5, 0.5)
		_column.add_theme_constant_override("separation", 8)
		_grid.columns = 4
		_grid.add_theme_constant_override("h_separation", 10)
		_grid.add_theme_constant_override("v_separation", 10)
		for card in _cards:
			card.custom_minimum_size = Vector2(272, 168)
			_layout_desktop_card(card)
		if _wallet.get_parent() != _header:
			_wallet.get_parent().remove_child(_wallet)
			_header.add_child(_wallet)
		_title.add_theme_font_size_override("font_size", 35)
		_subtitle.add_theme_font_size_override("font_size", 13)
		_coin_label.add_theme_font_size_override("font_size", 20)
		_merc_label.add_theme_font_size_override("font_size", 11)
		_hint.add_theme_font_size_override("font_size", 12)
		_wallet.custom_minimum_size = Vector2(230, 58)
		_wallet.size_flags_horizontal = Control.SIZE_SHRINK_END
		_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_merc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_footer.add_theme_constant_override("separation", 0)
		_action_row.add_theme_constant_override("separation", 12)
		_reroll_button.custom_minimum_size = Vector2(168, 42)
		_continue_button.custom_minimum_size = Vector2(168, 42)
		_reroll_button.add_theme_font_size_override("font_size", 15)
		_continue_button.add_theme_font_size_override("font_size", 15)


func _display_size() -> Vector2:
	if GameSettings.is_web_platform():
		var raw := str(JavaScriptBridge.eval("JSON.stringify([window.innerWidth || 0, window.innerHeight || 0])", true))
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Array and (parsed as Array).size() >= 2:
			return Vector2(float(parsed[0]), float(parsed[1]))
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x > 0.0 and window_size.y > 0.0:
		return window_size
	return get_viewport_rect().size


func _layout_mobile_card(card: Button, width: float, height: float, scale: float) -> void:
	var inset := UILayout.display_units(10.0, scale)
	var right := width - inset
	var top := UILayout.display_units(7.0, scale)
	var icon_size := UILayout.display_units(42.0, scale)
	var card_name := card.name
	var number := int(card_name.trim_prefix("ShopCard")) - 1
	var font := maxi(14, roundi(12.0 / scale))
	for name in ["CardAccent"]:
		var node := card.find_child(name, true, false) as Control
		node.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		node.offset_bottom = UILayout.display_units(3.0, scale)
	var number_label := card.find_child("Label", true, false) as Label
	# The first label is the card index; locate all known labels by their node names instead.
	var kind := card.find_child("CardKind", true, false) as Label
	var icon_plate := card.find_child("CardIconPlate", true, false) as Control
	var title := card.find_child("CardTitle", true, false) as Label
	var description := card.find_child("CardDescription", true, false) as Label
	var effect := card.find_child("CardEffect", true, false) as Label
	var meta := card.find_child("CardMeta", true, false) as Label
	var price := card.find_child("CardPrice", true, false) as Label
	if is_instance_valid(number_label):
		UILayout.place_in(number_label, inset, top, UILayout.display_units(22.0, scale), UILayout.display_units(18.0, scale), width, height)
		_set_label_size(number_label, font)
	UILayout.place_in(kind, right - UILayout.display_units(120.0, scale), top, UILayout.display_units(120.0, scale), UILayout.display_units(18.0, scale), width, height, 1.0, 0.0)
	_set_label_size(kind, font)
	UILayout.place_in(icon_plate, inset, UILayout.display_units(29.0, scale), icon_size, icon_size, width, height)
	var icon := icon_plate.find_child("CardIcon", true, false) as TextureRect
	icon.custom_minimum_size = Vector2.ONE * UILayout.display_units(30.0, scale)
	UILayout.place_in(title, inset + icon_size + UILayout.display_units(8.0, scale), UILayout.display_units(30.0, scale), width - icon_size - inset * 2.0 - UILayout.display_units(8.0, scale), UILayout.display_units(44.0, scale), width, height)
	_set_label_size(title, maxi(18, roundi(20.0 / scale)))
	UILayout.place_in(description, inset, UILayout.display_units(77.0, scale), right - inset, UILayout.display_units(30.0, scale), width, height)
	description.max_lines_visible = 2
	_set_label_size(description, maxi(15, roundi(15.0 / scale)))
	UILayout.place_in(effect, inset, UILayout.display_units(108.0, scale), right - inset, UILayout.display_units(24.0, scale), width, height)
	effect.max_lines_visible = 1
	_set_label_size(effect, maxi(15, roundi(15.0 / scale)))
	UILayout.place_in(price, inset, height - UILayout.display_units(27.0, scale), UILayout.display_units(120.0, scale), UILayout.display_units(20.0, scale), width, height)
	_set_label_size(price, maxi(16, roundi(16.0 / scale)))
	UILayout.place_in(meta, right - UILayout.display_units(126.0, scale), height - UILayout.display_units(26.0, scale), UILayout.display_units(126.0, scale), UILayout.display_units(19.0, scale), width, height, 1.0, 0.0)
	_set_label_size(meta, font)
	card.add_theme_font_size_override("font_size", maxi(16, roundi(16.0 / scale)))
	card.focus_mode = Control.FOCUS_NONE


func _layout_desktop_card(card: Button) -> void:
	var width := 272.0
	var height := 168.0
	var accent := card.find_child("CardAccent", true, false) as ColorRect
	UILayout.place_in(accent, 0, 0, width, 3, width, height, 0.0, 0.0)
	var number := card.find_child("Label", true, false) as Label
	if is_instance_valid(number):
		UILayout.place_in(number, 7, 5, 18, 16, width, height)
	var kind := card.find_child("CardKind", true, false) as Label
	UILayout.place_in(kind, 54, 5, 208, 16, width, height, 1.0, 0.0)
	var icon_plate := card.find_child("CardIconPlate", true, false) as Control
	UILayout.place_in(icon_plate, 8, 25, 42, 42, width, height)
	var title := card.find_child("CardTitle", true, false) as Label
	UILayout.place_in(title, 57, 23, 205, 24, width, height)
	var description := card.find_child("CardDescription", true, false) as Label
	UILayout.place_in(description, 8, 71, 255, 42, width, height)
	var effect := card.find_child("CardEffect", true, false) as Label
	UILayout.place_in(effect, 8, 115, 255, 26, width, height)
	var meta := card.find_child("CardMeta", true, false) as Label
	UILayout.place_in(meta, 150, 148, 112, 16, width, height, 1.0, 0.0)
	var price := card.find_child("CardPrice", true, false) as Label
	UILayout.place_in(price, 8, 144, 138, 20, width, height)
	_set_label_size(kind, 9)
	_set_label_size(title, 16)
	_set_label_size(description, 10)
	_set_label_size(effect, 10)
	_set_label_size(meta, 8)
	_set_label_size(price, 14)
	card.add_theme_font_size_override("font_size", 14)
	card.focus_mode = Control.FOCUS_ALL


func _set_label_size(label: Label, size: int) -> void:
	if is_instance_valid(label) and size > 0:
		label.add_theme_font_size_override("font_size", size)


func _build_card(card: Button, index: int) -> void:
	var cw := 272.0
	var ch := 168.0
	var accent := ColorRect.new()
	accent.name = "CardAccent"
	accent.color = Color(GOLD, 0.9)
	UILayout.place_in(accent, 0, 0, 272, 3, cw, ch)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(accent)
	var number := _label(str(index + 1) if index < 9 else "·", 10, Color(MUTED, 0.58))
	UILayout.place_in(number, 7, 5, 18, 16, cw, ch)
	card.add_child(number)
	var kind := _label("", 9, MUTED)
	kind.name = "CardKind"
	UILayout.place_in(kind, 54, 5, 208, 16, cw, ch, 1.0, 0.0)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(kind)

	var icon_plate := PanelContainer.new()
	icon_plate.name = "CardIconPlate"
	UILayout.place_in(icon_plate, 8, 25, 42, 42, cw, ch)
	icon_plate.add_theme_stylebox_override("panel", _icon_style(Color(GOLD, 0.20)))
	card.add_child(icon_plate)
	var center := CenterContainer.new()
	icon_plate.add_child(center)
	var icon := TextureRect.new()
	icon.name = "CardIcon"
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center.add_child(icon)

	var title := _label("", 16, GOLD)
	title.name = "CardTitle"
	UILayout.place_in(title, 57, 23, 205, 24, cw, ch)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(title)
	var description := _label("", 10, PAPER)
	description.name = "CardDescription"
	UILayout.place_in(description, 8, 71, 255, 42, cw, ch)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 3
	card.add_child(description)
	var effect := _label("", 10, Color("#f0c363"))
	effect.name = "CardEffect"
	UILayout.place_in(effect, 8, 115, 255, 26, cw, ch)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.max_lines_visible = 2
	card.add_child(effect)
	var culture_title := _label(Locale.t("shop.culture_label"), 10, Color(VERMILION, 0.94))
	culture_title.visible = false
	UILayout.place_in(culture_title, 0, 0, 1, 1, cw, ch)
	card.add_child(culture_title)
	var culture := _label("", 9, Color(PAPER, 0.80))
	culture.name = "CardCulture"
	culture.visible = false
	UILayout.place_in(culture, 0, 0, 1, 1, cw, ch)
	culture.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(culture)
	var meta := _label("", 8, Color(MUTED, 0.72))
	meta.name = "CardMeta"
	UILayout.place_in(meta, 150, 148, 112, 16, cw, ch, 1.0, 0.0)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(meta)
	var price := _label("", 14, GOLD)
	price.name = "CardPrice"
	UILayout.place_in(price, 8, 144, 138, 20, cw, ch)
	card.add_child(price)


func _apply_offer(card: Button, offer: Dictionary, index: int, coin: int) -> void:
	var color := UpgradeCatalog.family_color(str(offer.get("family", "")))
	var rarity := str(offer.get("rarity", "common"))
	var rarity_color := _rarity_color(rarity)
	var sold := bool(offer.get("sold", false))
	var price := int(offer.get("price", 0))
	card.set_meta("offer_index", index)
	(card.find_child("CardAccent", true, false) as ColorRect).color = color
	var kind := card.find_child("CardKind", true, false) as Label
	kind.text = str(offer.get("kind_label", ""))
	kind.add_theme_color_override("font_color", color)
	(card.find_child("CardTitle", true, false) as Label).text = str(offer.get("title", ""))
	(card.find_child("CardDescription", true, false) as Label).text = str(offer.get("description", ""))
	(card.find_child("CardEffect", true, false) as Label).text = str(offer.get("effect_summary", ""))
	(card.find_child("CardCulture", true, false) as Label).text = str(offer.get("culture", ""))
	card.tooltip_text = "%s\n%s\n%s\n%s" % [
		str(offer.get("effect_summary", "")),
		str(offer.get("culture", "")),
		GameData.source_label(offer),
		str(offer.get("description", "")),
	]
	(card.find_child("CardMeta", true, false) as Label).text = "%s · Lv.%d" % [
		str(offer.get("rarity_label", "")),
		int(offer.get("level", 1)),
	]
	var price_label := card.find_child("CardPrice", true, false) as Label
	if sold:
		price_label.text = Locale.t("shop.sold")
		price_label.add_theme_color_override("font_color", Color(MUTED, 0.50))
		card.disabled = true
		card.modulate = Color(0.58, 0.58, 0.58, 0.70)
	else:
		price_label.text = Locale.t("shop.price", {"coin": price})
		price_label.add_theme_color_override(
			"font_color",
			GOLD if coin >= price else Color(VERMILION, 0.92)
		)
		card.disabled = false
		card.modulate = Color.WHITE
	var icon := card.find_child("CardIcon", true, false) as TextureRect
	var texture := GameData.texture(str(offer.get("icon", "")))
	icon.texture = texture
	icon.visible = texture != null
	icon.modulate = color.lightened(0.30) if not sold else Color(0.55, 0.55, 0.55, 0.55)
	(card.find_child("CardIconPlate", true, false) as PanelContainer).add_theme_stylebox_override(
		"panel",
		_icon_style(Color(color, 0.20))
	)
	card.add_theme_stylebox_override(
		"normal",
		_card_style(Color(0.040, 0.052, 0.054, 0.99), Color(rarity_color, 0.42))
	)


func _choose(index: int) -> void:
	if visible and index >= 0 and index < _offers.size() and not bool(_offers[index].get("sold", false)):
		buy_requested.emit(index)


func _animate_card(card: Button, index: int) -> void:
	card.modulate = Color(1, 1, 1, 0)
	card.scale = Vector2(0.97, 0.97)
	card.pivot_offset = card.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "modulate:a", 1.0, 0.16).set_delay(minf(float(index) * 0.018, 0.18))
	tween.tween_property(card, "scale", Vector2.ONE, 0.18).set_delay(minf(float(index) * 0.018, 0.18))


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(168, 42)
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_stylebox_override(
		"normal",
		_card_style(Color(GOLD, 0.12 if primary else 0.04), Color(GOLD, 0.62 if primary else 0.24))
	)
	button.add_theme_stylebox_override(
		"hover",
		_card_style(Color(GOLD, 0.19), Color(GOLD, 0.86))
	)
	return button


func _panel_style() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = PANEL_TEXTURE
	box.texture_margin_left = 28.0
	box.texture_margin_top = 28.0
	box.texture_margin_right = 28.0
	box.texture_margin_bottom = 28.0
	box.content_margin_left = 28.0
	box.content_margin_right = 28.0
	box.content_margin_top = 20.0
	box.content_margin_bottom = 18.0
	return box


func _card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 3
	box.corner_radius_top_right = 3
	box.corner_radius_bottom_left = 3
	box.corner_radius_bottom_right = 3
	return box


func _icon_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.04, 0.04, 0.76)
	box.border_color = color
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 53
	box.corner_radius_top_right = 53
	box.corner_radius_bottom_left = 53
	box.corner_radius_bottom_right = 53
	return box


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color("#7fb7a8")
		"rare":
			return Color("#79a9bf")
		"legendary":
			return Color("#d9a95f")
		_:
			return Color("#baa98a")
