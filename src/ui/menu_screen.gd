class_name MenuScreen
extends Node2D
## Title screen: the hero on a cliff above the burning isle.

signal begin_pressed
signal continue_pressed(level_id: String)

var _hero: Puppet
var _ui_root: Control


func open_book() -> void:
	var mb := MantraBook.new()
	UiKit.full_rect(mb)
	_ui_root.add_child(mb)
	mb.closed.connect(mb.queue_free)


func _ready() -> void:
	var backdrop := Backdrop.new()
	add_child(backdrop)
	backdrop.build(5000.0, "ember", 11, str(Game.save.settings.get("quality", "high")))
	backdrop.set_autoscroll(-30.0)

	var embers := Fx.embers(Vector2(700, 300), 50)
	embers.position = Vector2(640, 520)
	add_child(embers)

	var cliff := PackedVector2Array([Vector2(-20, 760), Vector2(-20, 590), Vector2(60, 582), Vector2(150, 590),
		Vector2(250, 584), Vector2(360, 592), Vector2(430, 604), Vector2(470, 640), Vector2(500, 760)])
	add_child(Fx.polygon(cliff, Fx.INK))
	var rim := Line2D.new()
	rim.points = cliff.slice(1, 8)
	rim.width = 2.0
	rim.default_color = Color(1.0, 0.58, 0.26, 0.6)
	add_child(rim)

	var aura := Fx.glow(Color(1.0, 0.5, 0.22, 0.35), 200.0)
	aura.position = Vector2(300, 480)
	add_child(aura)
	var holder := Node2D.new()
	holder.position = Vector2(300, 588)
	holder.scale = Vector2(2.2, 2.2)
	add_child(holder)
	_hero = Puppet.new()
	_hero.build("hero")
	_hero.face(1)
	holder.add_child(_hero)

	_build_ui()
	Sfx.scene("menu")


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := UiKit.full_rect(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var col := VBoxContainer.new()
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = -620
	col.offset_right = -70
	col.offset_top = -230
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)

	var title := UiKit.label(str(Game.game_cfg.get("title", "")), 76, UiKit.GOLD, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UiKit.label(str(Game.game_cfg.get("subtitle", "")).to_upper(), 18, Color(0.95, 0.75, 0.6, 0.7), 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var tag := UiKit.label(str(Game.game_cfg.get("tagline", "")), 28, UiKit.TEXT, 6)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	col.add_child(gap)

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	col.add_child(buttons)
	if Game.has_progress():
		var cont := UiKit.button("Continue", 340)
		cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cont.pressed.connect(func() -> void: continue_pressed.emit(Game.continue_level()))
		buttons.add_child(cont)
	var begin := UiKit.button("New story" if Game.has_progress() else "Begin", 340)
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	begin.pressed.connect(func() -> void: begin_pressed.emit())
	buttons.add_child(begin)
	if not Game.save.learned.is_empty():
		var book := UiKit.button("Mantra Book", 340)
		book.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		book.pressed.connect(open_book)
		buttons.add_child(book)
	_ui_root = root

	var footer := UiKit.label("Plays fully offline.  No forced ads.", 18, Color(0.95, 0.8, 0.7, 0.6), 4)
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.anchor_left = 1.0
	footer.anchor_right = 1.0
	footer.offset_top = -44
	footer.offset_left = -420
	footer.offset_right = -24
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(footer)

	# Lets testers send a log without USB: copy, then paste into any chat app.
	var report_label := "Something broke? Copy log" if GameLog.previous_session_crashed else "Copy debug log"
	var report := UiKit.button(report_label, 300)
	report.custom_minimum_size = Vector2(300, 52)
	report.add_theme_font_size_override("font_size", 20)
	report.anchor_top = 1.0
	report.anchor_bottom = 1.0
	report.offset_left = 24
	report.offset_top = -76
	report.offset_bottom = -24
	report.pressed.connect(func() -> void:
		GameLog.copy_report_to_clipboard()
		report.text = "Copied. Paste it to the developer."
	)
	root.add_child(report)


func _process(delta: float) -> void:
	_hero.animate(delta, 0.0, true, 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
