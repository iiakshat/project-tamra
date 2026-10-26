class_name SettingsPanel
extends PanelContainer
## Settings: each row is an icon, a one-word label and a switch (Music, Sound effects,
## Vibration), then Credits and Copy debug log. Used on the title screen and in pause.
## Credits open inside the same panel.

signal closed

var _body: VBoxContainer
var _switches := {}  # setting key -> Switch


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_theme_stylebox_override("panel", UiKit.frame_style(0.6, 10))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.custom_minimum_size = Vector2(460, 0)
	add_child(_body)
	_show_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_visible_in_tree():
		closed.emit()


func _clear() -> void:
	_switches.clear()
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()


func _show_settings() -> void:
	_clear()
	_body.add_child(UiKit.header("gear", "Settings", func() -> void: closed.emit()))
	_body.add_child(_toggle_row("music", "Music", "music_on"))
	_body.add_child(_toggle_row("sound", "Sound effects", "sfx_on"))
	_body.add_child(_toggle_row("vibration", "Vibration", "vibration"))
	var line := ColorRect.new()
	line.color = Color(UiKit.COPPER, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	_body.add_child(line)
	_body.add_child(_action_row("info", "Credits", _show_credits))
	var copy := _action_row("log", "Copy debug log", func() -> void: pass)
	copy.pressed.connect(func() -> void:
		GameLog.copy_report_to_clipboard()
		var row := copy.get_child(0)
		(row.get_child(0) as UiKit.IconView).icon = "check"
		(row.get_child(1) as Label).text = "Copied. Paste it in a chat."
	)
	_body.add_child(copy)
	_refresh()


func _toggle_row(icon: String, text: String, key: String) -> Button:
	var b := _row_button(icon, text)
	var sw := Switch.new()
	sw.custom_minimum_size = Vector2(64, 34)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.get_child(0).add_child(sw)
	_switches[key] = sw
	b.pressed.connect(func() -> void:
		Game.set_setting(key, not bool(Game.save.settings.get(key, true)))
		if key == "vibration":
			Game.vibrate(60)
		_refresh()
	)
	return b


func _action_row(icon: String, text: String, on_press: Callable) -> Button:
	var b := _row_button(icon, text)
	var arrow := UiKit.IconView.new()
	arrow.icon = "chevron"
	arrow.color = UiKit.MUTED
	arrow.custom_minimum_size = Vector2(28, 28)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.get_child(0).add_child(arrow)
	b.pressed.connect(on_press)
	return b


## A full-width flat row button: icon, label, then whatever the caller adds at the end.
func _row_button(icon: String, text: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 58)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.04)
	normal.set_corner_radius_all(12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(UiKit.ACCENT, 0.16)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: Sfx.play("ui_click"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(row)
	row.offset_left = 12
	row.offset_right = -12
	var v := UiKit.IconView.new()
	v.icon = icon
	v.color = UiKit.COPPER
	v.custom_minimum_size = Vector2(34, 34)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	var l := UiKit.label(text, 22, UiKit.TEXT, 4)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	row.add_child(l)
	b.add_child(row)
	return b


func _refresh() -> void:
	for key in _switches:
		(_switches[key] as Switch).on = bool(Game.save.settings.get(key, true))


# --- credits ------------------------------------------------------------------------

func _show_credits() -> void:
	_clear()
	var head := UiKit.header("info", "Credits", _show_settings)
	(head.get_child(head.get_child_count() - 1).get_child(0) as UiKit.IconView).icon = "back"
	_body.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_font_size_override("bold_font_size", 19)
	text.add_theme_color_override("default_color", UiKit.TEXT)
	text.text = credits_text()
	scroll.add_child(text)


## Every third-party work in the game and its licence. Keep in step with ASSETS.md.
static func credits_text() -> String:
	var h := "[color=#dc997a][b]%s[/b][/color]\n"
	var c := h % "Icons"
	c += "Game icons from game-icons.net by Lorc, Delapouite and Sbed, licensed under CC BY 3.0 (creativecommons.org/licenses/by/3.0). Recoloured.\n"
	c += "[font_size=14]Lorc: candlebright, lotus, crossed-swords, tied-scroll, scroll-unfurled, open-book, fireball, magic-swirl, robe. "
	c += "Delapouite: present, level-end-flag, stone-bridge, jump-across. Sbed: death-skull.[/font_size]\n"
	c += "System icons: Material Symbols by Google, Apache License 2.0 (apache.org/licenses/LICENSE-2.0).\n\n"
	c += h % "Sound"
	c += "Foley and interface sounds by Kenney (kenney.nl), CC0. Other effects and music synthesized for this game.\n\n"
	c += h % "Art and voices"
	c += "Painted art and story voices generated with Google Gemini. Mantra calls voiced with Sarvam AI.\n\n"
	c += h % "Font"
	c += "Yatra One by The Yatra Project Authors, SIL Open Font License 1.1.\n\n"
	c += h % "Engine"
	c += "Made with Godot Engine (godotengine.org), MIT License:\n"
	c += "[font_size=13]%s[/font_size]\n\n" % Engine.get_license_text().strip_edges()
	var parts: Array[String] = []
	for info in Engine.get_copyright_info():
		parts.append(str(info.get("name", "")))
	c += "[font_size=13]Godot includes third-party components: %s. Their licences: godotengine.org/license.[/font_size]\n" % ", ".join(parts)
	return c


## A flat on/off switch: a jade track with the knob right when on, grey when off.
class Switch extends Control:
	var on := true:
		set(value):
			if value != on:
				on = value
				var t := create_tween()
				t.tween_property(self, "_k", 1.0 if on else 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	var _k := 1.0:
		set(value):
			_k = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := size.y / 2.0
		var track := Color(0.25, 0.25, 0.32).lerp(UiKit.ACCENT, _k)
		draw_circle(Vector2(r, r), r, track)
		draw_circle(Vector2(size.x - r, r), r, track)
		draw_rect(Rect2(r, 0, size.x - 2.0 * r, size.y), track)
		var knob := Vector2(lerpf(r, size.x - r, _k), r)
		draw_circle(knob, r - 4.0, Color(0.04, 0.03, 0.1, 0.5))
		draw_circle(knob, r - 5.0, UiKit.TEXT)
