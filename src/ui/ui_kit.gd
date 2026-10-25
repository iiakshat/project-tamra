class_name UiKit
extends RefCounted
## Shared UI building blocks so every screen looks the same. Part of the reusable shell.

const GOLD := Color(1.0, 0.74, 0.36)
const TEXT := Color(1.0, 0.93, 0.82)
const SHADOW := Color(0.05, 0.01, 0.02, 0.92)


static func label(text: String, size: int, color: Color = TEXT, outline: int = 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", SHADOW)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel_style(alpha: float = 0.85) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.02, 0.03, alpha)
	sb.border_color = Color(GOLD, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	return sb


static func button(text: String, min_width: float = 300.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 70)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	var normal := panel_style(0.78)
	normal.set_content_margin_all(12)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = GOLD
	hover.bg_color = Color(0.16, 0.05, 0.05, 0.9)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.3, 0.1, 0.05, 0.95)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
