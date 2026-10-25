class_name MenuScreen
extends Node2D
## Title screen: Tamra on a cliff above the burning isle. One big play button, then a
## row of icons: levels, mantra book, shop, daily gifts (with a dot when something
## waits), settings.

signal begin_pressed
signal continue_pressed(level_id: String)
signal level_chosen(level_id: String, mod: String)

const TITLE_FONT := preload("res://assets/fonts/YatraOne-Regular.ttf")

var _hero: Puppet
var _ui_root: Control
var _panel: Control
var _jyoti: HBoxContainer
var _daily_dot: Control


func _ready() -> void:
	var backdrop := Backdrop.new()
	add_child(backdrop)
	backdrop.build(5000.0, "ember", 11, str(Game.save.settings.get("quality", "high")))
	backdrop.set_autoscroll(-30.0)

	var embers := Fx.embers(Vector2(700, 300), 50, Fx.palette("ember")["spark"])
	embers.position = Vector2(640, 520)
	add_child(embers)

	var cliff := PackedVector2Array([Vector2(-20, 760), Vector2(-20, 590), Vector2(60, 582), Vector2(150, 590),
		Vector2(250, 584), Vector2(360, 592), Vector2(430, 604), Vector2(470, 640), Vector2(500, 760)])
	add_child(Fx.polygon(cliff, Fx.INK))
	var rim := Line2D.new()
	rim.points = cliff.slice(1, 8)
	rim.width = 2.0
	rim.default_color = Color(0.95, 0.38, 0.55, 0.6)
	add_child(rim)

	var aura := Fx.glow(Color(0.7, 0.6, 1.0, 0.3), 200.0)
	aura.position = Vector2(300, 480)
	add_child(aura)
	var holder := Node2D.new()
	holder.position = Vector2(300, 588)
	holder.scale = Vector2(2.2, 2.2)
	add_child(holder)
	_hero = Puppet.new()
	_hero.build("hero", Game.skin_palette())
	_hero.face(1)
	holder.add_child(_hero)

	_build_ui()
	Game.jyoti_changed.connect(func(_t: int) -> void: _refresh())
	Sfx.scene("menu")


## Debug and deep-link entry: "levels", "daily", "shop", "settings", "book".
func open_panel(name: String) -> void:
	match name:
		"levels":
			_open_levels()
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
	_ui_root.add_child(mb)
	mb.closed.connect(func() -> void:
		mb.queue_free()
		_refresh()
	)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	_ui_root = UiKit.full_rect(Control.new())
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_ui_root)

	var col := VBoxContainer.new()
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = -640
	col.offset_right = -60
	col.offset_top = -200
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.add_theme_constant_override("separation", 6)
	_ui_root.add_child(col)

	var title := UiKit.label(str(Game.game_cfg.get("title", "TAMRA")), 92, UiKit.TEXT, 14)
	title.add_theme_font_override("font", TITLE_FONT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var deva := UiKit.label("ताम्र", 40, UiKit.ACCENT, 8)
	deva.add_theme_font_override("font", TITLE_FONT)
	deva.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(deva)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	col.add_child(gap)

	var play := UiKit.icon_button("play", 132, UiKit.ACCENT)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void:
		if Game.has_progress():
			continue_pressed.emit(Game.continue_level())
		else:
			begin_pressed.emit()
	)
	col.add_child(play)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 18)
	col.add_child(gap2)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var levels := UiKit.icon_button("star", 84)
	levels.pressed.connect(_open_levels)
	row.add_child(levels)
	var book := UiKit.icon_button("book", 84)
	book.pressed.connect(open_book)
	book.disabled = Game.save.learned.is_empty()
	row.add_child(book)
	var shop := UiKit.icon_button("shop", 84)
	shop.pressed.connect(func() -> void: _open(ShopPanel.new()))
	row.add_child(shop)
	var gift := UiKit.icon_button("gift", 84)
	gift.pressed.connect(_open_daily)
	row.add_child(gift)
	_daily_dot = Badge.new()
	_daily_dot.position = Vector2(64, 4)
	gift.add_child(_daily_dot)
	var gear := UiKit.icon_button("gear", 84)
	gear.pressed.connect(func() -> void: _open(SettingsPanel.new()))
	row.add_child(gear)

	_jyoti = UiKit.stat("jyoti", "", UiKit.JYOTI, 30)
	_jyoti.anchor_left = 1.0
	_jyoti.anchor_right = 1.0
	_jyoti.offset_left = -220
	_jyoti.offset_right = -28
	_jyoti.offset_top = 22
	_jyoti.alignment = BoxContainer.ALIGNMENT_END
	_ui_root.add_child(_jyoti)

	# Lets testers send a log without USB: copy, then paste into any chat app.
	var report := UiKit.icon_button("log", 56, UiKit.DANGER if GameLog.previous_session_crashed else UiKit.MUTED)
	report.anchor_top = 1.0
	report.anchor_bottom = 1.0
	report.offset_left = 20
	report.offset_top = -76
	report.offset_right = 76
	report.offset_bottom = -20
	report.pressed.connect(func() -> void:
		GameLog.copy_report_to_clipboard()
		var v: UiKit.IconView = report.get_child(0)
		v.icon = "check"
	)
	_ui_root.add_child(report)
	_refresh()


func _refresh() -> void:
	(_jyoti.get_child(1) as Label).text = str(Game.save.jyoti)
	_daily_dot.visible = Game.daily_waiting()


func _open(panel: Control) -> void:
	if _panel != null:
		_panel.queue_free()
	_panel = UiKit.full_rect(CenterContainer.new())
	var dim := UiKit.full_rect(ColorRect.new()) as ColorRect
	dim.color = Color(0.01, 0.0, 0.04, 0.55)
	_panel.add_child(dim)
	_panel.add_child(panel)
	_ui_root.add_child(_panel)
	panel.connect("closed", func() -> void:
		_panel.queue_free()
		_panel = null
		_refresh()
	)
	Sfx.play("page_turn")


func _open_levels() -> void:
	var ls := LevelSelect.new()
	ls.chosen.connect(func(id: String) -> void: level_chosen.emit(id, ""))
	_open(ls)


func _open_daily() -> void:
	var dp := DailyPanel.new()
	dp.play_trial.connect(func(id: String, mod: String) -> void: level_chosen.emit(id, mod))
	_open(dp)


func _process(delta: float) -> void:
	_hero.animate(delta, 0.0, true, 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _panel != null:
			_panel.queue_free()
			_panel = null
		else:
			get_tree().quit()


## A small pulsing dot: something is waiting to be collected.
class Badge extends Control:
	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
		draw_circle(Vector2(8, 8), 9.0 * pulse, UiKit.DANGER)
