class_name SettingsPanel
extends PanelContainer
## Music and sound toggles (and vibration), as icons. Used on the title screen and in pause.

signal closed

var _music: Button
var _sound: Button
var _buzz: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UiKit.panel_style(0.95))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	add_child(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	col.add_child(row)
	_music = UiKit.icon_button("music", 96)
	_music.pressed.connect(func() -> void: _toggle("music_on"))
	row.add_child(_music)
	_sound = UiKit.icon_button("sound", 96)
	_sound.pressed.connect(func() -> void: _toggle("sfx_on"))
	row.add_child(_sound)
	_buzz = UiKit.icon_button("heart", 96)
	_buzz.pressed.connect(func() -> void: _toggle("vibration"))
	row.add_child(_buzz)
	var close := UiKit.icon_button("check", 72, UiKit.ACCENT)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: closed.emit())
	col.add_child(close)
	_refresh()


func _toggle(key: String) -> void:
	Game.set_setting(key, not bool(Game.save.settings.get(key, true)))
	_refresh()


func _refresh() -> void:
	var s := Game.save.settings
	_set_icon(_music, "music" if bool(s.get("music_on", true)) else "music_off", bool(s.get("music_on", true)))
	_set_icon(_sound, "sound" if bool(s.get("sfx_on", true)) else "sound_off", bool(s.get("sfx_on", true)))
	_set_icon(_buzz, "heart", bool(s.get("vibration", true)))


func _set_icon(b: Button, icon: String, on: bool) -> void:
	var view: UiKit.IconView = b.get_child(0)
	view.icon = icon
	view.color = UiKit.TEXT if on else UiKit.MUTED
	b.modulate.a = 1.0 if on else 0.6
