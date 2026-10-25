class_name StoryScreen
extends Node2D
## Story cards between chapters: one line at a time, typed out. Tap to advance.
## Tapping while a line is still typing completes it first.

signal finished

var story_id := ""

var _lines: Array = []
var _index := -1
var _label: Label
var _hint: Label
var _skip: Button
var _typing: Tween
var _done := false


func setup(id: String) -> void:
	story_id = id


func _ready() -> void:
	var backdrop := Backdrop.new()
	add_child(backdrop)
	backdrop.build(5000.0, "ember", 23, str(Game.save.settings.get("quality", "high")))
	backdrop.sky_material.set_shader_parameter("dim", 0.55)
	backdrop.set_autoscroll(-12.0)
	var embers := Fx.embers(Vector2(700, 360), 40)
	embers.position = Vector2(640, 420)
	add_child(embers)

	var ui := CanvasLayer.new()
	add_child(ui)
	var shade := UiKit.full_rect(ColorRect.new()) as ColorRect
	shade.color = Color(0.02, 0.0, 0.01, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	_label = UiKit.label("", 38, UiKit.TEXT, 8)
	UiKit.full_rect(_label)
	_label.offset_left = 140
	_label.offset_right = -140
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(_label)
	_hint = UiKit.label("Tap to continue", 20, Color(1.0, 0.8, 0.6, 0.6), 4)
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -200
	_hint.offset_right = 200
	_hint.offset_top = -70
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(_hint)
	_skip = UiKit.button("Skip", 140)
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.offset_left = -170
	_skip.offset_right = -24
	_skip.offset_top = 20
	_skip.offset_bottom = 90
	_skip.pressed.connect(_finish)
	ui.add_child(_skip)

	Sfx.scene("story")
	_lines = GameConfig.read("story").get(story_id, [])
	Services.analytics.log_event("story_view", {"id": story_id})
	_next()


func _process(_delta: float) -> void:
	_hint.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)


func _unhandled_input(event: InputEvent) -> void:
	var tapped: bool = event is InputEventScreenTouch and event.pressed
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	if not tapped and not key:
		return
	if tapped and _skip.get_global_rect().has_point(event.position):
		return
	if _typing != null and _typing.is_running():
		_typing.kill()
		_label.visible_ratio = 1.0
	else:
		Sfx.play("page_turn")
		_next()


func _next() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	_label.text = str(_lines[_index])
	_label.visible_ratio = 0.0
	_typing = create_tween()
	_typing.tween_property(_label, "visible_ratio", 1.0, _label.text.length() * 0.03)


func _finish() -> void:
	if _done:
		return
	_done = true
	if not Game.save.story_seen.has(story_id):
		Game.save.story_seen.append(story_id)
		Game.persist()
	finished.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_finish()
