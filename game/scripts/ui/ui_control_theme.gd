extends RefCounted

const BUTTON_NORMAL := preload("res://assets/ui/controls/button_normal.webp")
const BUTTON_HOVER := preload("res://assets/ui/controls/button_hover.webp")
const BUTTON_PRESSED := preload("res://assets/ui/controls/button_pressed.webp")
const BUTTON_PRIMARY_NORMAL := preload("res://assets/ui/controls/button_primary_normal.webp")
const BUTTON_PRIMARY_HOVER := preload("res://assets/ui/controls/button_primary_hover.webp")
const BUTTON_PRIMARY_PRESSED := preload("res://assets/ui/controls/button_primary_pressed.webp")
const BUTTON_COMPACT_NORMAL := preload("res://assets/ui/controls/button_compact_normal.webp")
const BUTTON_COMPACT_HOVER := preload("res://assets/ui/controls/button_compact_hover.webp")
const BUTTON_COMPACT_PRESSED := preload("res://assets/ui/controls/button_compact_pressed.webp")
const OPTION_ARROW := preload("res://assets/ui/controls/option_arrow.webp")
const POPUP_PANEL := preload("res://assets/ui/controls/popup_panel.webp")
const POPUP_HOVER := preload("res://assets/ui/controls/popup_hover.webp")
const SLIDER_TRACK := preload("res://assets/ui/controls/slider_track.webp")
const SLIDER_FILL := preload("res://assets/ui/controls/slider_fill.webp")
const SLIDER_GRABBER := preload("res://assets/ui/controls/slider_grabber.webp")
const SLIDER_GRABBER_HOVER := preload("res://assets/ui/controls/slider_grabber_hover.webp")
const CHECK_OFF := preload("res://assets/ui/controls/check_off.webp")
const CHECK_ON := preload("res://assets/ui/controls/check_on.webp")
const TOOLTIP := preload("res://assets/ui/controls/tooltip.webp")
const SCROLL_TRACK := preload("res://assets/ui/controls/scroll_track.webp")
const SCROLL_GRABBER := preload("res://assets/ui/controls/scroll_grabber.webp")

const PAPER := Color("#e8d8b6")
const MUTED := Color("#a99778")
const GOLD := Color("#d8a548")


static func install(theme: Theme) -> void:
	_install_buttons(theme)
	_install_option_button(theme)
	_install_check_button(theme)
	_install_slider(theme)
	_install_popup(theme)
	_install_scrollbars(theme)
	_install_tooltip(theme)


static func apply_primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_box(BUTTON_PRIMARY_NORMAL))
	button.add_theme_stylebox_override("hover", _button_box(BUTTON_PRIMARY_HOVER))
	button.add_theme_stylebox_override("pressed", _button_box(BUTTON_PRIMARY_PRESSED))


static func apply_compact(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _compact_box(BUTTON_COMPACT_NORMAL))
	button.add_theme_stylebox_override("hover", _compact_box(BUTTON_COMPACT_HOVER))
	button.add_theme_stylebox_override("pressed", _compact_box(BUTTON_COMPACT_PRESSED))


static func apply_option(option: OptionButton) -> void:
	option.add_theme_icon_override("arrow", OPTION_ARROW)
	var popup := option.get_popup()
	popup.add_theme_stylebox_override("panel", _popup_panel_box())
	popup.add_theme_stylebox_override("hover", _popup_hover_box())
	popup.add_theme_color_override("font_color", PAPER)
	popup.add_theme_color_override("font_hover_color", Color("#fff0cf"))
	popup.add_theme_color_override("font_accent_color", GOLD)
	popup.add_theme_constant_override("item_start_padding", 18)
	popup.add_theme_constant_override("item_end_padding", 18)
	popup.add_theme_constant_override("v_separation", 8)
	popup.add_theme_constant_override("item_separation", 4)


static func _install_buttons(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", _button_box(BUTTON_NORMAL))
	theme.set_stylebox("hover", "Button", _button_box(BUTTON_HOVER))
	theme.set_stylebox("pressed", "Button", _button_box(BUTTON_PRESSED))
	theme.set_stylebox("disabled", "Button", _button_box(BUTTON_PRESSED, 0.55))
	theme.set_stylebox("focus", "Button", _focus_box())
	theme.set_stylebox("normal", "OptionButton", _compact_box(BUTTON_COMPACT_NORMAL))
	theme.set_stylebox("hover", "OptionButton", _compact_box(BUTTON_COMPACT_HOVER))
	theme.set_stylebox("pressed", "OptionButton", _compact_box(BUTTON_COMPACT_PRESSED))
	theme.set_stylebox("disabled", "OptionButton", _compact_box(BUTTON_COMPACT_PRESSED, 0.55))
	theme.set_stylebox("focus", "OptionButton", _focus_box())
	for type_name in ["Button", "OptionButton"]:
		theme.set_color("font_color", type_name, PAPER)
		theme.set_color("font_hover_color", type_name, Color("#fff0cf"))
		theme.set_color("font_pressed_color", type_name, Color("#f4dfb2"))
		theme.set_color("font_focus_color", type_name, Color("#fff0cf"))
		theme.set_color("font_disabled_color", type_name, Color(MUTED, 0.58))


static func _install_option_button(theme: Theme) -> void:
	theme.set_icon("arrow", "OptionButton", OPTION_ARROW)
	theme.set_constant("arrow_margin", "OptionButton", 10)
	theme.set_constant("modulate_arrow", "OptionButton", 1)


static func _install_check_button(theme: Theme) -> void:
	theme.set_stylebox("normal", "CheckButton", _transparent_box())
	theme.set_stylebox("hover", "CheckButton", _hint_box(0.06, 0.28))
	theme.set_stylebox("pressed", "CheckButton", _hint_box(0.12, 0.48))
	theme.set_stylebox("disabled", "CheckButton", _transparent_box())
	theme.set_stylebox("focus", "CheckButton", _focus_box())
	theme.set_icon("checked", "CheckButton", CHECK_ON)
	theme.set_icon("unchecked", "CheckButton", CHECK_OFF)
	theme.set_icon("checked_disabled", "CheckButton", CHECK_ON)
	theme.set_icon("unchecked_disabled", "CheckButton", CHECK_OFF)
	theme.set_color("font_color", "CheckButton", PAPER)
	theme.set_color("font_hover_color", "CheckButton", Color("#fff0cf"))
	theme.set_color("font_pressed_color", "CheckButton", Color("#f4dfb2"))
	theme.set_constant("h_separation", "CheckButton", 9)


static func _install_slider(theme: Theme) -> void:
	theme.set_stylebox("slider", "HSlider", _slider_track_box())
	theme.set_stylebox("grabber_area", "HSlider", _slider_fill_box())
	theme.set_stylebox("grabber_area_highlight", "HSlider", _slider_fill_box())
	theme.set_icon("grabber", "HSlider", SLIDER_GRABBER)
	theme.set_icon("grabber_highlight", "HSlider", SLIDER_GRABBER_HOVER)
	theme.set_icon("grabber_disabled", "HSlider", SLIDER_GRABBER)
	theme.set_constant("grabber_offset", "HSlider", 0)
	theme.set_constant("center_grabber", "HSlider", 1)


static func _install_popup(theme: Theme) -> void:
	theme.set_stylebox("panel", "PopupMenu", _popup_panel_box())
	theme.set_stylebox("hover", "PopupMenu", _popup_hover_box())
	theme.set_color("font_color", "PopupMenu", PAPER)
	theme.set_color("font_hover_color", "PopupMenu", Color("#fff0cf"))
	theme.set_color("font_accent_color", "PopupMenu", GOLD)
	theme.set_constant("item_start_padding", "PopupMenu", 18)
	theme.set_constant("item_end_padding", "PopupMenu", 18)
	theme.set_constant("v_separation", "PopupMenu", 8)
	theme.set_constant("item_separation", "PopupMenu", 4)


static func _install_scrollbars(theme: Theme) -> void:
	for type_name in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type_name, _scroll_track_box())
		theme.set_stylebox("grabber", type_name, _scroll_grabber_box())
		theme.set_stylebox("grabber_highlight", type_name, _scroll_grabber_box())
		theme.set_stylebox("grabber_pressed", type_name, _scroll_grabber_box())


static func _install_tooltip(theme: Theme) -> void:
	var box := StyleBoxTexture.new()
	box.texture = TOOLTIP
	box.texture_margin_left = 18.0
	box.texture_margin_top = 18.0
	box.texture_margin_right = 18.0
	box.texture_margin_bottom = 18.0
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	theme.set_stylebox("panel", "TooltipPanel", box)
	theme.set_color("font_color", "TooltipLabel", PAPER)


static func _button_box(texture: Texture2D, alpha: float = 1.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = 24.0
	box.texture_margin_top = 24.0
	box.texture_margin_right = 24.0
	box.texture_margin_bottom = 24.0
	box.content_margin_left = 24.0
	box.content_margin_right = 20.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	box.modulate_color = Color(1.0, 1.0, 1.0, alpha)
	return box


static func _compact_box(texture: Texture2D, alpha: float = 1.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = 16.0
	box.texture_margin_top = 16.0
	box.texture_margin_right = 16.0
	box.texture_margin_bottom = 16.0
	box.content_margin_left = 18.0
	box.content_margin_right = 14.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	box.modulate_color = Color(1.0, 1.0, 1.0, alpha)
	return box


static func _popup_panel_box() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = POPUP_PANEL
	box.texture_margin_left = 26.0
	box.texture_margin_top = 26.0
	box.texture_margin_right = 26.0
	box.texture_margin_bottom = 26.0
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


static func _popup_hover_box() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = POPUP_HOVER
	box.texture_margin_left = 12.0
	box.texture_margin_top = 8.0
	box.texture_margin_right = 12.0
	box.texture_margin_bottom = 8.0
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 7.0
	box.content_margin_bottom = 7.0
	return box


static func _slider_track_box() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = SLIDER_TRACK
	box.texture_margin_left = 8.0
	box.texture_margin_top = 0.0
	box.texture_margin_right = 8.0
	box.texture_margin_bottom = 0.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


static func _slider_fill_box() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = SLIDER_FILL
	box.texture_margin_left = 8.0
	box.texture_margin_top = 0.0
	box.texture_margin_right = 8.0
	box.texture_margin_bottom = 0.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


static func _scroll_track_box() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = SCROLL_TRACK
	box.texture_margin_left = 3.0
	box.texture_margin_top = 8.0
	box.texture_margin_right = 3.0
	box.texture_margin_bottom = 8.0
	return box


static func _scroll_grabber_box() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = SCROLL_GRABBER
	box.texture_margin_left = 3.0
	box.texture_margin_top = 8.0
	box.texture_margin_right = 3.0
	box.texture_margin_bottom = 8.0
	return box


static func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.border_color = Color(GOLD, 0.82)
	box.set_border_width_all(2)
	box.set_corner_radius_all(2)
	box.expand_margin_left = 2.0
	box.expand_margin_right = 2.0
	box.expand_margin_top = 2.0
	box.expand_margin_bottom = 2.0
	return box


static func _transparent_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	return box


static func _hint_box(fill_alpha: float, border_alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(GOLD, fill_alpha)
	box.border_color = Color(GOLD, border_alpha)
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	return box
