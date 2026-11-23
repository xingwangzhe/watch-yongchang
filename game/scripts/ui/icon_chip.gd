extends RefCounted

const GOLD := Color("#d8a548")
const PAPER := Color("#e8d8b6")


static func make_tile(texture: Texture2D, text: String, icon_size: int = 48) -> Dictionary:
	var root := VBoxContainer.new()
	root.name = "IconChip"
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 5)
	root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var frame := PanelContainer.new()
	frame.name = "IconFrame"
	frame.custom_minimum_size = Vector2(icon_size + 16.0, icon_size + 16.0)
	frame.add_theme_stylebox_override("panel", _frame_style())
	root.add_child(frame)
	frame.add_child(_icon(texture, icon_size))

	var label := _label(text, 12, Color(PAPER, 0.84))
	root.add_child(label)
	return {"root": root, "label": label}


static func make_inline(texture: Texture2D, text: String, icon_size: int = 22) -> Dictionary:
	var root := HBoxContainer.new()
	root.name = "InlineIconChip"
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 5)
	root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(_icon(texture, icon_size))

	var label := _label(text, 11, Color(PAPER, 0.78))
	root.add_child(label)
	return {"root": root, "label": label}


static func _icon(texture: Texture2D, size: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = texture
	icon.modulate = GOLD
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


static func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = "IconLabel"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _frame_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.050, 0.050, 0.62)
	box.border_color = Color(GOLD, 0.30)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	box.content_margin_left = 5.0
	box.content_margin_top = 5.0
	box.content_margin_right = 5.0
	box.content_margin_bottom = 5.0
	return box
