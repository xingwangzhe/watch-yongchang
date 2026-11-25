class_name ShopOverlay
extends Control

signal buy_requested(index: int)
signal reroll_requested
signal closed

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.png")
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


func _ready() -> void:
	name = "ShopOverlay"
	z_index = 55
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false


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

	var panel := PanelContainer.new()
	UILayout.place(panel, 32, 18, 1216, 684, 0.5, 0.5)
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_title = _label(Locale.t("shop.title"), 35, GOLD)
	heading.add_child(_title)
	_subtitle = _label(Locale.t("shop.subtitle"), 13, Color(MUTED, 0.82))
	heading.add_child(_subtitle)
	var wallet := VBoxContainer.new()
	wallet.custom_minimum_size = Vector2(230, 58)
	header.add_child(wallet)
	_coin_label = _label("", 20, GOLD)
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet.add_child(_coin_label)
	_merc_label = _label("", 11, Color(PAPER, 0.72))
	_merc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_merc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wallet.add_child(_merc_label)

	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.28)
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	for i in range(3):
		var card := Button.new()
		card.name = "ShopCard%d" % (i + 1)
		card.custom_minimum_size = Vector2(354, 466)
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
		row.add_child(card)
		_cards.append(card)
		_build_card(card, i)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	_hint = _label(Locale.t("shop.hint"), 12, Color(MUTED, 0.66))
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_hint)
	_reroll_button = _button(Locale.t("shop.reroll", {"cost": 0}), false)
	_reroll_button.pressed.connect(func() -> void: reroll_requested.emit())
	footer.add_child(_reroll_button)
	_continue_button = _button(Locale.t("shop.continue"), true)
	_continue_button.pressed.connect(func() -> void: closed.emit())
	footer.add_child(_continue_button)


func _build_card(card: Button, index: int) -> void:
	var cw := 354.0
	var ch := 466.0
	var accent := ColorRect.new()
	accent.name = "CardAccent"
	accent.color = Color(GOLD, 0.9)
	UILayout.place_in(accent, 0, 0, 354, 4, cw, ch)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(accent)
	var number := _label(str(index + 1), 12, Color(MUTED, 0.58))
	UILayout.place_in(number, 14, 10, 20, 20, cw, ch)
	card.add_child(number)
	var kind := _label("", 11, MUTED)
	kind.name = "CardKind"
	UILayout.place_in(kind, 180, 10, 158, 20, cw, ch, 1.0, 0.0)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(kind)

	var icon_plate := PanelContainer.new()
	icon_plate.name = "CardIconPlate"
	UILayout.place_in(icon_plate, 124, 34, 106, 106, cw, ch, 0.5, 0.0)
	icon_plate.add_theme_stylebox_override("panel", _icon_style(Color(GOLD, 0.20)))
	card.add_child(icon_plate)
	var center := CenterContainer.new()
	icon_plate.add_child(center)
	var icon := TextureRect.new()
	icon.name = "CardIcon"
	icon.custom_minimum_size = Vector2(74, 74)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center.add_child(icon)

	var title := _label("", 25, GOLD)
	title.name = "CardTitle"
	UILayout.place_in(title, 16, 146, 322, 54, cw, ch, 0.5, 0.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(title)
	var description := _label("", 13, PAPER)
	description.name = "CardDescription"
	UILayout.place_in(description, 22, 205, 310, 54, cw, ch, 0.5, 0.0)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(description)
	var effect := _label("", 12, Color("#f0c363"))
	effect.name = "CardEffect"
	UILayout.place_in(effect, 22, 262, 310, 40, cw, ch, 0.5, 0.0)
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(effect)
	var culture_title := _label(Locale.t("shop.culture_label"), 10, Color(VERMILION, 0.94))
	UILayout.place_in(culture_title, 22, 306, 310, 16, cw, ch, 0.5, 0.0)
	card.add_child(culture_title)
	var culture := _label("", 12, Color(PAPER, 0.80))
	culture.name = "CardCulture"
	UILayout.place_in(culture, 22, 324, 310, 86, cw, ch, 0.5, 0.0)
	culture.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(culture)
	var meta := _label("", 10, Color(MUTED, 0.72))
	meta.name = "CardMeta"
	UILayout.place_in(meta, 22, 412, 310, 16, cw, ch, 0.5, 0.0)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(meta)
	var price := _label("", 22, GOLD)
	price.name = "CardPrice"
	UILayout.place_in(price, 22, 430, 310, 30, cw, ch, 0.5, 0.0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	card.tooltip_text = "%s\n%s" % [GameData.source_label(offer), offer.get("effect_summary", "")]
	(card.find_child("CardMeta", true, false) as Label).text = "%s · %s · %s" % [
		str(offer.get("category", "")),
		str(offer.get("rarity_label", "")),
		Locale.t("shop.level", {
			"level": int(offer.get("level", 1)),
			"max": int(offer.get("max_level", 1)),
		}),
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
	tween.tween_property(card, "modulate:a", 1.0, 0.20).set_delay(float(index) * 0.05)
	tween.tween_property(card, "scale", Vector2.ONE, 0.22).set_delay(float(index) * 0.05)


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
