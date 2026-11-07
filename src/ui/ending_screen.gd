class_name EndingScreen
extends Node2D
## "To be continued…" card after the last level: the tower plate slowly darkens under
## the words, then a single button returns to the title. Text lives in game.json "ending".
## Flat 2D only (no glow).

signal finished

const FADE_IN := 2.2

var _art: Sprite2D
var _t := 0.0
var _ui: Control
var _button: Button
var _done := false


func _ready() -> void:
	var ending: Dictionary = Game.game_cfg.get("ending", {})
	var path := "res://assets/story/%s.jpg" % str(ending.get("plate", ""))
	var back := CanvasLayer.new()
	back.layer = -10
	add_child(back)
	var black := ColorRect.new()
	black.color = Color(0.03, 0.02, 0.06)
	UiKit.full_rect(black)
	back.add_child(black)
	if ResourceLoader.exists(path):
		_art = Sprite2D.new()
		_art.texture = load(path)
		_art.modulate = Color(0.55, 0.55, 0.6, 0.0)
		add_child(_art)

	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = UiKit.full_rect(Control.new())
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(box)
	_ui.add_child(box)
	var title := UiKit.title(str(ending.get("title", "To be continued…")), 76, UiKit.TEXT, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var deva := UiKit.title(str(ending.get("hi", "")), 42, UiKit.COPPER, 8)
	deva.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(deva)
	var line := UiKit.label(str(ending.get("line", "")), 26, UiKit.MUTED, 6)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	for c in box.get_children():
		c.modulate.a = 0.0

	_button = UiKit.pill("TITLE", "home", "red", 76, 260)
	_button.anchor_left = 0.5
	_button.anchor_right = 0.5
	_button.anchor_top = 1.0
	_button.anchor_bottom = 1.0
	_button.offset_left = -130
	_button.offset_right = 130
	_button.offset_top = -130
	_button.offset_bottom = -54
	_button.modulate.a = 0.0
	_button.disabled = true
	_button.pressed.connect(_finish)
	_ui.add_child(_button)

	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void: Sfx.scene("story"))
	for i in box.get_child_count():
		tw.tween_property(box.get_child(i), "modulate:a", 1.0, 1.1)
		tw.tween_interval(0.35)
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void: _button.disabled = false)
	tw.tween_property(_button, "modulate:a", 1.0, 0.6)
	Services.analytics.log_event("game_end_card", {"stars": Game.save.total_stars()})


func _process(delta: float) -> void:
	_t += delta
	if _art == null:
		return
	var vp := get_viewport_rect().size
	var cover := maxf(vp.x / _art.texture.get_width(), vp.y / _art.texture.get_height())
	var k := cover * (1.04 + 0.01 * _t / 20.0)
	_art.scale = Vector2(k, k)
	_art.position = vp / 2.0
	_art.modulate.a = minf(_t / FADE_IN, 1.0) * 0.45


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _button.disabled:
		_finish()


func _finish() -> void:
	if _done:
		return

	_done = true
	finished.emit()
