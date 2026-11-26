extends RefCounted
## Signature theme palette & dialog theme:
## Arcane Obsidian Void + Imperial Gold + Electric Cyan + Royal Violet.

const BG_VOID := Color(0.028, 0.032, 0.085)
const BG_ABYSS := Color(0.068, 0.045, 0.155)
const BACKGROUND := Color(0.052, 0.062, 0.132)
const SURFACE := Color(0.082, 0.098, 0.205, 0.96)
const SURFACE_HOVER := Color(0.125, 0.148, 0.285, 0.98)
const GOLD := Color(0.96, 0.77, 0.28)
const GOLD_LIGHT := Color(1.0, 0.95, 0.76)
const GOLD_DARK := Color(0.38, 0.25, 0.05)
const CYAN := Color(0.18, 0.84, 1.0)
const CYAN_SOFT := Color(0.55, 0.92, 1.0)
const VIOLET := Color(0.54, 0.31, 0.98)
const OUTLINE := Color(0.14, 0.06, 0.22)
const DANGER := Color(0.32, 0.05, 0.08)
const TITLE_HEIGHT := 46
const CLOSE_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='#%s' stroke-width='2.4' stroke-linecap='round'><line x1='18' y1='6' x2='6' y2='18'/><line x1='6' y1='6' x2='18' y2='18'/></svg>"
const RADIO_ON_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='28' height='28' viewBox='0 0 28 28'><circle cx='14' cy='14' r='11.5' fill='#142240' stroke='#F5C447' stroke-width='2.6'/><circle cx='14' cy='14' r='6.2' fill='#2ED6FF'/></svg>"
const RADIO_OFF_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='28' height='28' viewBox='0 0 28 28'><circle cx='14' cy='14' r='11.5' fill='#0D1326' stroke='#7CA8C9' stroke-width='2.4'/></svg>"

static var _theme: Theme
static var _radio_on_icon: ImageTexture
static var _radio_off_icon: ImageTexture


static func apply(dialog: AcceptDialog, danger := false) -> void:
	dialog.theme = theme()
	dialog.transparent_bg = true
	dialog.get_ok_button().focus_mode = Control.FOCUS_ALL
	if danger:
		for state in ["normal", "hover", "pressed"]:
			var style := _button(state)
			style.bg_color = DANGER.lightened(0.14) if state != "normal" else DANGER
			dialog.get_ok_button().add_theme_stylebox_override(state, style)


static func radio_icon(checked: bool) -> ImageTexture:
	if checked:
		if _radio_on_icon == null:
			var img := Image.new()
			img.load_svg_from_string(RADIO_ON_SVG, 1.0)
			_radio_on_icon = ImageTexture.create_from_image(img)
		return _radio_on_icon
	if _radio_off_icon == null:
		var img := Image.new()
		img.load_svg_from_string(RADIO_OFF_SVG, 1.0)
		_radio_off_icon = ImageTexture.create_from_image(img)
	return _radio_off_icon


static func style_popup(popup: PopupMenu) -> void:
	if popup == null:
		return
	var mobile := OS.has_feature("mobile") or Paths.cmdline_value("mobile-controls") == "true"
	var panel := StyleBoxFlat.new()
	panel.bg_color = BACKGROUND
	panel.border_color = GOLD
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(10 if mobile else 8)
	panel.anti_aliasing = true
	var hover := StyleBoxFlat.new()
	hover.bg_color = SURFACE_HOVER
	hover.border_color = CYAN
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(7)
	hover.set_content_margin_all(8 if mobile else 6)
	hover.anti_aliasing = true
	popup.add_theme_stylebox_override("panel", panel)
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_font_override("font", Assets.ui_font(700))
	popup.add_theme_font_size_override("font_size", 18 if mobile else 15)
	popup.add_theme_color_override("font_color", GOLD_LIGHT)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_icon_override("radio_checked", radio_icon(true))
	popup.add_theme_icon_override("radio_unchecked", radio_icon(false))
	popup.add_theme_icon_override("radio_checked_disabled", radio_icon(true))
	popup.add_theme_icon_override("radio_unchecked_disabled", radio_icon(false))
	popup.add_theme_constant_override("v_separation", 14 if mobile else 10)
	popup.add_theme_constant_override("h_separation", 12)
	popup.add_theme_constant_override("item_start_padding", 8)
	popup.add_theme_constant_override("item_end_padding", 10)


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var mobile := OS.has_feature("mobile") or Paths.cmdline_value("mobile-controls") == "true"
	_theme = Theme.new()
	_theme.default_font = Assets.ui_font()
	_theme.default_font_size = 17
	var border := StyleBoxFlat.new()
	border.bg_color = BACKGROUND
	border.border_color = CYAN.lerp(GOLD, 0.65)
	border.set_border_width_all(2)
	border.set_corner_radius_all(14)
	border.shadow_color = Color(0, 0, 0, 0.68)
	border.shadow_size = 20
	border.shadow_offset = Vector2(0, 8)
	border.expand_margin_left = 14
	border.expand_margin_right = 14
	border.expand_margin_bottom = 14
	border.expand_margin_top = TITLE_HEIGHT + 6
	border.anti_aliasing = true
	_theme.set_stylebox("embedded_border", "Window", border)
	_theme.set_stylebox("embedded_unfocused_border", "Window", border)
	_theme.set_constant("title_height", "Window", TITLE_HEIGHT)
	_theme.set_color("title_color", "Window", GOLD)
	_theme.set_font_size("title_font_size", "Window", 21)
	_theme.set_constant("title_outline_size", "Window", 6)
	_theme.set_color("title_outline_modulate", "Window", OUTLINE)
	_theme.set_icon("close", "Window", _close_icon(GOLD))
	_theme.set_icon("close_pressed", "Window", _close_icon(CYAN_SOFT))
	_theme.set_constant("close_h_offset", "Window", 22)
	_theme.set_constant("close_v_offset", "Window", 32)
	var panel := StyleBoxFlat.new()
	panel.bg_color = BACKGROUND
	panel.border_color = Color(CYAN, 0.25)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(18)
	panel.content_margin_bottom = 14
	panel.anti_aliasing = true
	_theme.set_stylebox("panel", "AcceptDialog", panel)
	_theme.set_constant("buttons_separation", "AcceptDialog", 16)
	_theme.set_constant("buttons_min_width", "AcceptDialog", 128)
	_theme.set_constant("buttons_min_height", "AcceptDialog", 48 if mobile else 38)
	_theme.set_color("font_color", "Label", GOLD_LIGHT)
	_theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.72))
	_theme.set_constant("outline_size", "Label", 3)
	_theme.set_constant("line_spacing", "Label", 4)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_theme.set_stylebox(state, "Button", _button(state))
	_theme.set_color("font_color", "Button", GOLD_LIGHT)
	_theme.set_color("font_hover_color", "Button", Color.WHITE)
	_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	_theme.set_color("font_focus_color", "Button", Color.WHITE)
	_theme.set_color("font_disabled_color", "Button", Color(GOLD_LIGHT, 0.35))
	_theme.set_font_size("font_size", "Button", 16)
	var pop_panel := StyleBoxFlat.new()
	pop_panel.bg_color = BACKGROUND
	pop_panel.border_color = GOLD
	pop_panel.set_border_width_all(2)
	pop_panel.set_corner_radius_all(10)
	pop_panel.set_content_margin_all(10 if mobile else 8)
	pop_panel.anti_aliasing = true
	var pop_hover := StyleBoxFlat.new()
	pop_hover.bg_color = SURFACE_HOVER
	pop_hover.border_color = CYAN
	pop_hover.set_border_width_all(1)
	pop_hover.set_corner_radius_all(7)
	pop_hover.set_content_margin_all(8 if mobile else 6)
	pop_hover.anti_aliasing = true
	_theme.set_stylebox("panel", "PopupMenu", pop_panel)
	_theme.set_stylebox("hover", "PopupMenu", pop_hover)
	_theme.set_font("font", "PopupMenu", Assets.ui_font(700))
	_theme.set_font_size("font_size", "PopupMenu", 18 if mobile else 15)
	_theme.set_color("font_color", "PopupMenu", GOLD_LIGHT)
	_theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	_theme.set_icon("radio_checked", "PopupMenu", radio_icon(true))
	_theme.set_icon("radio_unchecked", "PopupMenu", radio_icon(false))
	_theme.set_constant("v_separation", "PopupMenu", 14 if mobile else 10)
	_theme.set_constant("h_separation", "PopupMenu", 12)
	_theme.set_icon("radio_checked", "CheckBox", radio_icon(true))
	_theme.set_icon("radio_unchecked", "CheckBox", radio_icon(false))
	return _theme


static func _button(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE_HOVER if state in ["hover", "pressed"] else SURFACE
	style.border_color = Color(GOLD, 0.25) if state == "disabled" else (Color(CYAN, 0.52) if state == "normal" else GOLD)
	style.draw_center = state != "focus"
	style.set_border_width_all(2 if state == "focus" else 1)
	style.set_corner_radius_all(8)
	style.anti_aliasing = true
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


static func _close_icon(color: Color) -> ImageTexture:
	var image := Image.new()
	image.load_svg_from_string(CLOSE_SVG % color.to_html(false), 0.9)
	return ImageTexture.create_from_image(image)
