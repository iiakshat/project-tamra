class_name UiKit
extends RefCounted
## Shared UI building blocks so every screen looks the same. Part of the reusable shell.
## Palette: indigo night panels, ivory text, jade accent, crimson for danger. No orange:
## fire belongs to the world, not the interface.

const ACCENT := Color(0.42, 0.9, 0.78)
const VIOLET := Color(0.66, 0.55, 1.0)
const DANGER := Color(0.95, 0.3, 0.4)
const TEXT := Color(0.96, 0.95, 0.9)
const MUTED := Color(0.72, 0.72, 0.8)
const JYOTI := Color(0.8, 0.95, 1.0)
const PANEL := Color(0.06, 0.05, 0.14)
const SHADOW := Color(0.02, 0.01, 0.05, 0.92)


static func label(text: String, size: int, color: Color = TEXT, outline: int = 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", SHADOW)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel_style(alpha: float = 0.88) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL, alpha)
	sb.border_color = Color(ACCENT, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(22)
	return sb


static func button(text: String, min_width: float = 300.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 70)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	_style(b, 18)
	b.pressed.connect(func() -> void: Sfx.play("ui_click"))
	return b


## A round button showing one icon (see Icons). Words only where an icon cannot say it.
static func icon_button(icon: String, diameter: float = 84.0, color: Color = TEXT) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(diameter, diameter)
	_style(b, int(diameter / 2.0))
	var view := IconView.new()
	view.icon = icon
	view.color = color
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(view)
	b.add_child(view)
	b.pressed.connect(func() -> void: Sfx.play("ui_click"))
	return b


## A row: icon followed by a short value, e.g. clock + "1:12".
static func stat(icon: String, value: String, color: Color = TEXT, size: int = 30) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var view := IconView.new()
	view.icon = icon
	view.color = color
	view.custom_minimum_size = Vector2(size + 8, size + 8)
	row.add_child(view)
	row.add_child(label(value, size, color, 5))
	return row


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


static func _style(b: Button, radius: int) -> void:
	var normal := panel_style(0.82)
	normal.set_content_margin_all(12)
	normal.set_corner_radius_all(radius)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = ACCENT
	hover.bg_color = Color(0.1, 0.09, 0.22, 0.92)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.14, 0.2, 0.28, 0.95)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.border_color = Color(MUTED, 0.25)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Draws one icon centred in its rect.
class IconView extends Control:
	var icon := "":
		set(value):
			icon = value
			queue_redraw()
	var color := Color.WHITE:
		set(value):
			color = value
			queue_redraw()

	func _draw() -> void:
		Icons.draw(self, icon, size / 2.0, minf(size.x, size.y) * 0.5, color)
