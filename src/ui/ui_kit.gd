class_name UiKit
extends RefCounted
## Shared UI building blocks so every screen looks the same. Part of the reusable shell.
## Theme: indigo lacquer panels with a copper border, copper medallion buttons and
## copper-rimmed pills (assets/ui). Flat 2D: no glows or bloom. Icons come from real icon
## sets (see Icons). Every button gives press feedback: a quick scale-down and brighten.

const ACCENT := Color(0.42, 0.9, 0.78)    # jade
const VIOLET := Color(0.66, 0.55, 1.0)
const DANGER := Color(0.95, 0.33, 0.42)   # crimson
const TEXT := Color(0.96, 0.95, 0.9)
const MUTED := Color(0.72, 0.72, 0.8)
const JYOTI := Color(0.8, 0.95, 1.0)      # the light currency
const STAR := Color(0.98, 0.9, 0.7)
const COPPER := Color(0.86, 0.6, 0.47)
const PANEL := Color(0.06, 0.05, 0.14)
const INK := Color(0.09, 0.08, 0.2)
const SHADOW := Color(0.02, 0.01, 0.05, 0.92)

const TITLE_FONT := preload("res://assets/fonts/YatraOne-Regular.ttf")
const PANEL_TEX := preload("res://assets/ui/panel.png")
const ROUND_TEX := preload("res://assets/ui/button_round.png")
const PILL_RED := preload("res://assets/ui/pill_red.png")
const PILL_JADE := preload("res://assets/ui/pill_jade.png")

## Native-pixel sizes of the copper borders in the textures.
const PANEL_MARGIN := 64.0
const PILL_CAP := 60.0



static func label(text: String, size: int, color: Color = TEXT, outline: int = 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", SHADOW)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A heading in the display font (Yatra One).
static func title(text: String, size: int, color: Color = TEXT, outline: int = 8) -> Label:
	var l := label(text, size, color, outline)
	l.add_theme_font_override("font", TITLE_FONT)
	return l


## Flat panel style (still used by the story screen and small chips).
static func panel_style(alpha: float = 0.88) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL, alpha)
	sb.border_color = Color(COPPER, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(22)
	return sb


## The lacquered panel with its copper border, 9-sliced. `k` scales the border.
static func frame_style(k: float = 0.6, pad: float = 14.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = scaled(PANEL_TEX, k)
	sb.set_texture_margin_all(PANEL_MARGIN * k)
	sb.content_margin_left = PANEL_MARGIN * k * 0.55 + pad
	sb.content_margin_right = PANEL_MARGIN * k * 0.55 + pad
	sb.content_margin_top = PANEL_MARGIN * k * 0.5 + pad
	sb.content_margin_bottom = PANEL_MARGIN * k * 0.6 + pad
	return sb


## A rounded dark plate with a thin copper rim: counters and small badges.
static func plate_style(radius: int = 22, alpha: float = 0.78) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, alpha)
	sb.border_color = Color(COPPER, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## A plain text button (story choices and the like), in the copper plate style.
static func button(text: String, min_width: float = 300.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 70)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	var normal := plate_style(18, 0.85)
	normal.set_content_margin_all(12)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = ACCENT
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.14, 0.2, 0.3, 0.95)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.border_color = Color(MUTED, 0.25)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_click(b)
	juice(b)
	return b


## A round copper medallion showing one icon (see Icons). The icon is child 0.
static func icon_button(icon: String, diameter: float = 84.0, color: Color = TEXT) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_texture_styles(b, ROUND_TEX, 0.0, 0.0)
	var view := IconView.new()
	view.icon = icon
	view.color = color
	view.fill = 0.5
	full_rect(view)
	b.add_child(view)
	_click(b)
	juice(b)
	return b


## A medallion with a short label under it, for places where an icon alone is ambiguous.
## Returns the column; the button is `col.get_child(0)`.
static func labeled(b: Button, text: String, size: int = 18) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(b)
	var l := label(text, size, TEXT, 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return col


## A copper-rimmed pill for primary actions: Play, Claim. kind: "jade" or "red".
static func pill(text: String, icon: String = "", kind: String = "red", height: float = 72.0, min_width: float = 220.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(min_width, height)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tex: Texture2D = PILL_JADE if kind == "jade" else PILL_RED
	_texture_styles(b, scaled(tex, height / float(tex.get_height())), PILL_CAP * height / float(tex.get_height()), 0.0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(height * 0.12))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(row)
	if icon != "":
		var v := IconView.new()
		v.icon = icon
		v.custom_minimum_size = Vector2(height * 0.46, height * 0.46)
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(v)
	if text != "":
		var l := title(text, int(height * 0.4), TEXT, 6)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
	b.add_child(row)
	_click(b)
	juice(b)
	return b


## Changes a pill's text (its label is the last child of its row).
static func set_pill_text(b: Button, text: String) -> void:
	var row := b.get_child(0)
	(row.get_child(row.get_child_count() - 1) as Label).text = text


## A row: icon followed by a short value, e.g. clock + "1:12".
static func stat(icon: String, value: String, color: Color = TEXT, size: int = 30) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := IconView.new()
	view.icon = icon
	view.color = color
	view.custom_minimum_size = Vector2(size + 8, size + 8)
	row.add_child(view)
	row.add_child(label(value, size, color, 5))
	return row


## A jyoti counter on a copper-rimmed plate. The label is `get_child(0).get_child(1)`.
static func jyoti_counter(size: int = 26) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", plate_style(size))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := stat("jyoti", str(Game.save.jyoti), JYOTI, size)
	plate.add_child(row)
	glint(row.get_child(0))
	return plate


## Header used by every panel: icon, title, then a close medallion. Returns the row;
## the close button is its last child.
static func header(icon: String, text: String, on_close: Callable) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	if icon != "":
		var v := IconView.new()
		v.icon = icon
		v.color = COPPER
		v.custom_minimum_size = Vector2(40, 40)
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(v)
	var t := title(text, 34, TEXT, 6)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := icon_button("close", 56)
	close.pressed.connect(on_close)
	head.add_child(close)
	return head


## A small heading over a section, e.g. "VOWS".
static func section(text: String) -> Label:
	var l := label(text.to_upper(), 16, COPPER, 4)
	return l


## A flat progress bar with a copper rim.
static func bar(value: float, max_value: float, color: Color = ACCENT, width: float = 200.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(width, 14)
	b.max_value = max_value
	b.value = value
	b.show_percentage = false
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.02, 0.07, 0.9)
	bg.border_color = Color(COPPER, 0.7)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(7)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	return b


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


# --- motion ------------------------------------------------------------------------

## Press feedback: scale down and brighten while held, spring back on release.
static func juice(b: BaseButton) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func() -> void: _press_tween(b, 0.9, 1.3))
	b.button_up.connect(func() -> void: _press_tween(b, 1.0, 1.0))


## Fades and scales a control in (panels opening). Safe inside containers.
static func pop_in(c: Control, delay: float = 0.0) -> void:
	c.modulate.a = 0.0
	var t := c.create_tween()
	t.tween_interval(delay)
	t.tween_callback(func() -> void:
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2.ONE * 0.94
	)
	t.set_parallel()
	t.tween_property(c, "modulate:a", 1.0, 0.22)
	t.tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A slow breathing pulse (the main Play button).
static func pulse(c: Control, amount: float = 0.04, period: float = 1.6) -> void:
	var t := c.create_tween().set_loops()
	t.tween_callback(func() -> void: c.pivot_offset = c.size / 2.0)
	t.tween_property(c, "scale", Vector2.ONE * (1.0 + amount), period / 2.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "scale", Vector2.ONE, period / 2.0).set_trans(Tween.TRANS_SINE)


## Every few seconds the control brightens and pops slightly: a coin glint.
static func glint(c: Control, every: float = 3.2) -> void:
	var t := c.create_tween().set_loops()
	t.tween_interval(every)
	t.tween_callback(func() -> void: c.pivot_offset = c.size / 2.0)
	t.set_parallel()
	t.tween_property(c, "scale", Vector2.ONE * 1.22, 0.14).set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "modulate", Color(1.5, 1.5, 1.5), 0.14)
	t.chain().tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(c, "modulate", Color.WHITE, 0.3)


# --- textures ------------------------------------------------------------------------

## A resized copy of a texture, cached. Lets 9-slice borders render at a chosen scale
## (StyleBoxTexture itself cannot scale its margins).
static func scaled(tex: Texture2D, k: float) -> Texture2D:
	var key := "%s@%.3f" % [tex.resource_path, k]
	var cache := cache("scaled")
	if cache.has(key):
		return cache[key]
	var img := tex.get_image().duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	var out := ImageTexture.create_from_image(img)
	cache[key] = out
	return out


## A session cache kept on the scene tree's root, so it is freed with the tree at exit
## (a static variable would hold its textures past shutdown and be reported as a leak).
static func cache(name: String) -> Dictionary:
	var root := (Engine.get_main_loop() as SceneTree).root
	var key := "ui_cache_" + name
	if not root.has_meta(key):
		root.set_meta(key, {})
	return root.get_meta(key)


static func _texture_styles(b: Button, tex: Texture2D, cap: float, vmargin: float) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = cap
		sb.texture_margin_right = cap
		sb.texture_margin_top = vmargin
		sb.texture_margin_bottom = vmargin
		match state:
			"hover":
				sb.modulate_color = Color(1.08, 1.08, 1.08)
			"pressed", "hover_pressed":
				sb.modulate_color = Color(1.2, 1.2, 1.2)
			"disabled":
				sb.modulate_color = Color(0.5, 0.5, 0.56)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func _click(b: BaseButton) -> void:
	b.pressed.connect(func() -> void: Sfx.play("ui_click"))


static func _press_tween(b: Control, s: float, bright: float) -> void:
	if not is_instance_valid(b):
		return
	var t := b.create_tween().set_parallel()
	t.tween_property(b, "scale", Vector2.ONE * s, 0.07 if s < 1.0 else 0.16).set_trans(Tween.TRANS_SINE)
	t.tween_property(b, "modulate", Color(bright, bright, bright, b.modulate.a), 0.07 if s < 1.0 else 0.2)


## Draws one icon centred in its rect. `fill` is the icon's share of the rect.
class IconView extends Control:
	var icon := "":
		set(value):
			icon = value
			queue_redraw()
	var color := Color.WHITE:
		set(value):
			color = value
			queue_redraw()
	var fill := 1.0:
		set(value):
			fill = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _draw() -> void:
		var col := color
		var b := get_parent() as BaseButton
		if b != null and b.disabled:
			col = Color(col.r * 0.55, col.g * 0.55, col.b * 0.6, col.a * 0.8)
		Icons.draw(self, icon, size / 2.0, minf(size.x, size.y) * 0.5 * fill, col)
