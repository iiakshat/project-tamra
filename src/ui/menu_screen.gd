class_name MenuScreen
extends Node2D
## Title screen: painted key art drifting slowly (Ken Burns), floating motes, the title,
## one big Play pill, then a row of labelled medallions: Map, Mantras, Shop, Daily (with a
## badge only while a reward can be claimed) and Settings.
## Layout assumes only this about the art: hero lower-left, palace right, open sky top-middle.

signal begin_pressed
signal continue_pressed(level_id: String)
signal level_chosen(level_id: String, mod: String)
signal story_chosen(story_id: String)

const KEYART := preload("res://assets/ui/menu_keyart.png")

var _art: Sprite2D
var _t := 0.0
var _ui_root: Control
var _panel: Control
var _jyoti: PanelContainer
var _badge: Control
var _book_button: Button
## 0 while the intro holds the camera on Tamra, 1 for the normal title view.
var _reveal := 1.0
static var _intro_shown := false
const HERO_AT := Vector2(520, 700)  # Tamra on the cliff, in key-art pixels


func _ready() -> void:
	_art = Sprite2D.new()
	_art.texture = KEYART
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var wind := ShaderMaterial.new()
	wind.shader = preload("res://src/ui/keyart.gdshader")
	_art.material = wind
	add_child(_art)
	add_child(_motes())
	_build_ui()
	if not _intro_shown and not Engine.is_editor_hint():
		_intro_shown = true
		_play_intro()
	_process(0.0)
	Game.jyoti_changed.connect(func(_t: int) -> void: _refresh())
	Sfx.scene("menu")


## Launch intro: clouds over a running Tamra, then they burst away and the camera
## pulls back from him to the full title screen; the buttons rise in last.
func _play_intro() -> void:
	_reveal = 0.0
	_ui_root.modulate.a = 0.0
	var curtain := IntroCurtain.new()
	add_child(curtain)
	curtain.opened.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(self, "_reveal", 1.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_ui_root, "modulate:a", 1.0, 0.45)
		_ui_root.position.y = 40.0
		tw.parallel().tween_property(_ui_root, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))


## Debug and deep-link entry: "levels"/"map", "daily", "shop", "settings", "book".
func open_panel(name: String) -> void:
	match name:
		"levels", "map":
			open_map()
		"daily":
			_open_daily()
		"shop":
			_open(ShopPanel.new())
		"settings":
			_open(SettingsPanel.new())
		"book":
			open_book()


func open_book() -> void:
	var mb := MantraBook.new()
	UiKit.full_rect(mb)
	_open_full(mb)


func open_map(walk_from: String = "") -> LevelSelect:
	var map := LevelSelect.new()
	map.walk_from = walk_from
	UiKit.full_rect(map)
	map.chosen.connect(func(id: String) -> void: level_chosen.emit(id, ""))
	map.story_chosen.connect(func(id: String) -> void: story_chosen.emit(id))
	_open_full(map)
	return map


func _process(delta: float) -> void:
	# Ken Burns: a slow zoom and drift that never shows the art's edges.
	_t += delta
	var vp := get_viewport_rect().size
	var cover := maxf(vp.x / KEYART.get_width(), vp.y / KEYART.get_height())
	var k := cover * (1.07 + 0.03 * sin(_t * 0.05))
	var slack := (Vector2(KEYART.get_size()) * k - vp) / 2.0
	var pos := vp / 2.0 + Vector2(sin(_t * 0.061), sin(_t * 0.043 + 1.0)) * slack * 0.85
	if _reveal < 1.0:
		# Intro: start close on Tamra, pull back to the title view.
		var zk := cover * 2.6
		var zpos := vp / 2.0 - (HERO_AT - Vector2(KEYART.get_size()) / 2.0) * zk
		var e := ease(_reveal, -2.2)
		k = lerpf(zk, k, e)
		pos = zpos.lerp(pos, e)
	_art.scale = Vector2(k, k)
	_art.position = pos


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	_ui_root = UiKit.full_rect(Control.new())
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ui.add_child(_ui_root)
	_ui_root.add_child(_vignette())

	# Title, top-middle over the sky.
	var head := VBoxContainer.new()
	head.anchor_left = 0.5
	head.anchor_right = 0.5
	head.offset_left = -300
	head.offset_right = 300
	head.offset_top = 18
	head.add_theme_constant_override("separation", -18)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(head)
	# Ink letters with an ivory rim: readable over both the moon and the night sky.
	var title := UiKit.title(str(Game.game_cfg.get("title", "TAMRA")), 104, Color(0.13, 0.09, 0.26), 14)
	title.add_theme_color_override("font_outline_color", Color(0.96, 0.94, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.12, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_outline_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var deva := UiKit.title("ताम्र", 38, Color(0.62, 0.16, 0.26), 8)
	deva.add_theme_color_override("font_outline_color", Color(0.96, 0.94, 1.0))
	deva.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(deva)
	UiKit.pop_in(head, 0.1)
	_breathe(title)

	# The one big action.
	var play := UiKit.pill("PLAY", "play", "red", 88, 320)
	play.anchor_left = 0.5
	play.anchor_right = 0.5
	play.anchor_top = 1.0
	play.anchor_bottom = 1.0
	play.offset_left = -160
	play.offset_right = 160
	play.offset_top = -236
	play.offset_bottom = -148
	play.pressed.connect(func() -> void:
		if Game.has_progress():
			continue_pressed.emit(Game.continue_level())
		else:
			begin_pressed.emit()
	)
	_ui_root.add_child(play)
	UiKit.pulse(play, 0.035, 1.8)

	# Secondary actions, each with a one-word label.
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -300
	row.offset_right = 300
	row.offset_top = -128
	row.offset_bottom = -14
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	_ui_root.add_child(row)
	var map := UiKit.icon_button("map", 74)
	map.pressed.connect(open_map)
	row.add_child(UiKit.labeled(map, "Map"))
	_book_button = UiKit.icon_button("book", 74)
	_book_button.pressed.connect(open_book)
	_book_button.disabled = Game.save.learned.is_empty()
	row.add_child(UiKit.labeled(_book_button, "Mantras"))
	var shop := UiKit.icon_button("shop", 74)
	shop.pressed.connect(func() -> void: _open(ShopPanel.new()))
	row.add_child(UiKit.labeled(shop, "Shop"))
	var daily := UiKit.icon_button("gift", 74)
	daily.pressed.connect(_open_daily)
	row.add_child(UiKit.labeled(daily, "Daily"))
	_badge = Badge.new()
	_badge.position = Vector2(54, 2)
	daily.add_child(_badge)
	var gear := UiKit.icon_button("gear", 74)
	gear.pressed.connect(func() -> void: _open(SettingsPanel.new()))
	row.add_child(UiKit.labeled(gear, "Settings"))
	for i in row.get_child_count():
		UiKit.pop_in(row.get_child(i), 0.25 + i * 0.06)

	_jyoti = UiKit.jyoti_counter(26)
	_jyoti.anchor_left = 1.0
	_jyoti.anchor_right = 1.0
	_jyoti.offset_left = -170
	_jyoti.offset_right = -22
	_jyoti.offset_top = 20
	_jyoti.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ui_root.add_child(_jyoti)

	# After a crash, offer the log right here (it also lives in Settings).
	if GameLog.previous_session_crashed:
		var report := UiKit.icon_button("log", 56, UiKit.DANGER)
		report.anchor_top = 1.0
		report.anchor_bottom = 1.0
		report.offset_left = 20
		report.offset_top = -76
		report.offset_right = 76
		report.offset_bottom = -20
		report.pressed.connect(func() -> void:
			GameLog.copy_report_to_clipboard()
			(report.get_child(0) as UiKit.IconView).icon = "check"
		)
		_ui_root.add_child(report)
	_refresh()


func _refresh() -> void:
	(_jyoti.get_child(0).get_child(1) as Label).text = str(Game.save.jyoti)
	_badge.visible = Game.daily_waiting()
	_book_button.disabled = Game.save.learned.is_empty()


## A centred panel over a dim veil. Tapping the veil closes it.
func _open(panel: Control) -> void:
	_close_panel()
	_panel = UiKit.full_rect(Control.new())
	var dim := UiKit.full_rect(ColorRect.new()) as ColorRect
	dim.color = Color(0.01, 0.0, 0.04, 0.6)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_panel()
	)
	_panel.add_child(dim)
	var center := UiKit.full_rect(CenterContainer.new())
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(center)
	center.add_child(panel)
	_ui_root.add_child(_panel)
	panel.connect("closed", _close_panel)
	UiKit.pop_in(panel)
	Sfx.play("page_turn")


## A full-screen view (map, mantra book).
func _open_full(view: Control) -> void:
	_close_panel()
	_panel = view
	_ui_root.add_child(view)
	view.connect("closed", _close_panel)
	view.modulate.a = 0.0
	view.create_tween().tween_property(view, "modulate:a", 1.0, 0.25)


func _close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	_refresh()


func _open_daily() -> void:
	var dp := DailyPanel.new()
	dp.play_trial.connect(func(id: String, mod: String) -> void: level_chosen.emit(id, mod))
	dp.claimed.connect(_refresh)
	_open(dp)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _panel != null:
			_close_panel()
		else:
			get_tree().quit()


## The title breathes: a very slow, small scale swell.
func _breathe(c: Control) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size / 2.0)
	var t := c.create_tween().set_loops()
	t.tween_property(c, "scale", Vector2.ONE * 1.025, 2.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "scale", Vector2.ONE, 2.6).set_trans(Tween.TRANS_SINE)


## Edge darkening, plus a darker band at the bottom so the buttons read on any art.
func _vignette() -> Control:
	var holder := UiKit.full_rect(Control.new())
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var radial := GradientTexture2D.new()
	radial.gradient = _grad([Color(0.02, 0.01, 0.06, 0.0), Color(0.02, 0.01, 0.06, 0.55)], [0.55, 1.0])
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.45)
	radial.fill_to = Vector2(1.05, 0.45)
	var v := UiKit.full_rect(TextureRect.new()) as TextureRect
	v.texture = radial
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(v)
	var band := GradientTexture2D.new()
	band.gradient = _grad([Color(0.02, 0.01, 0.06, 0.0), Color(0.02, 0.01, 0.06, 0.7)], [0.0, 1.0])
	band.fill_from = Vector2(0.5, 0.0)
	band.fill_to = Vector2(0.5, 1.0)
	var b := TextureRect.new()
	b.texture = band
	b.stretch_mode = TextureRect.STRETCH_SCALE
	b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.anchor_right = 1.0
	b.anchor_top = 0.62
	b.anchor_bottom = 1.0
	holder.add_child(b)
	return holder


## Small flat motes drifting up through the scene: ash and a few jade sparks.
func _motes() -> CPUParticles2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(4, 4))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(4.0 - d, 0.0, 1.0)))
	var p := CPUParticles2D.new()
	p.texture = ImageTexture.create_from_image(img)
	p.amount = 42
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1100, 40)
	p.position = Vector2(780, 760)
	p.direction = Vector2(0.25, -1.0)
	p.spread = 25.0
	p.gravity = Vector2(3, -6)
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 46.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color_ramp = _grad([Color(0.95, 0.45, 0.55, 0.0), Color(0.95, 0.45, 0.55, 0.85), Color(0.55, 0.95, 0.85, 0.6),
		Color(0.55, 0.95, 0.85, 0.0)], [0.0, 0.15, 0.6, 1.0])
	return p


static func _grad(colors: Array, offsets: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


## A small crimson dot that pops gently: a reward is waiting.
class Badge extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(20, 20)
		pivot_offset = Vector2(10, 10)
		var t := create_tween().set_loops()
		t.tween_property(self, "scale", Vector2.ONE * 1.25, 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)

	func _draw() -> void:
		draw_circle(Vector2(10, 10), 10.0, UiKit.SHADOW)
		draw_circle(Vector2(10, 10), 8.0, UiKit.DANGER)
		draw_circle(Vector2(10, 10), 3.0, UiKit.TEXT)
