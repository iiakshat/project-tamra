class_name SettingsPanel
extends PanelContainer
## Settings: each row is an icon, a one-word label and a switch (Music, Sound effects,
## Vibration), then Copy debug log. Used on the title screen and in pause. (Owner removed the
## Credits screen; licence notices ship inside the app in assets/licenses/.)

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
	_body.add_child(_toggle_row("cast", "Left-handed", "left_handed", false))
	_body.add_child(_pad_size_row())
	if Game.age_gate() == "ok":  # asked only of players the age screen found to be 13 or older
		_body.add_child(_toggle_row("info", "Share play data", "share_data", false))
	var line := ColorRect.new()
	line.color = Color(UiKit.COPPER, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	_body.add_child(line)
	var copy := _action_row("log", "Copy debug log", func() -> void: pass)
	copy.pressed.connect(func() -> void:
		GameLog.copy_report_to_clipboard()
		var row := copy.get_child(0)
		(row.get_child(0) as UiKit.IconView).icon = "check"
		(row.get_child(1) as Label).text = "Copied. Paste it in a chat."
	)
	_body.add_child(copy)
	_refresh()


## One row that cycles the on-screen pad size (small, normal, large, extra large).
func _pad_size_row() -> Button:
	var b := _row_button("leap", "Pad size")
	var value := UiKit.label(_size_name(), 22, UiKit.COPPER, 4)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.get_child(0).add_child(value)
	b.pressed.connect(func() -> void:
		Game.set_setting("pad_scale", ControlLayout.next_scale(float(Game.save.settings.get("pad_scale", 1.0))))
		value.text = _size_name()
	)
	return b


func _size_name() -> String:
	var k := float(Game.save.settings.get("pad_scale", 1.0))
	var names := ["S", "M", "L", "XL"]
	var best := 0
	for i in ControlLayout.PRESETS.size():
		if absf(ControlLayout.PRESETS[i] - k) < absf(ControlLayout.PRESETS[best] - k):
			best = i
	return names[best]


func _toggle_row(icon: String, text: String, key: String, default_on: bool = true) -> Button:
	var b := _row_button(icon, text)
	var sw := Switch.new()
	sw.custom_minimum_size = Vector2(64, 34)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.get_child(0).add_child(sw)
	_switches[key] = sw
	sw.on = _switch_value(key)
	b.pressed.connect(func() -> void:
		if key == "share_data":
			Game.set_analytics_consent(Game.analytics_consent() != "yes")
			_refresh()
			return
		Game.set_setting(key, not bool(Game.save.settings.get(key, default_on)))
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
		(_switches[key] as Switch).on = _switch_value(key)


func _switch_value(key: String) -> bool:
	if key == "share_data":
		return Game.analytics_consent() == "yes"
	return bool(Game.save.settings.get(key, key != "left_handed"))


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
