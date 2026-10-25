class_name StoryScreen
extends Node2D
## Story cards between chapters: one line at a time, narrated in Hindi (Sanskrit for
## invocations) with the English line as a subtitle. Advances by itself after each
## spoken line; a tap completes the typing first, then skips ahead.

signal finished

const DEVANAGARI_FONT := preload("res://assets/fonts/YatraOne-Regular.ttf")
const PAUSE_AFTER_VOICE := 1.3

var story_id := ""

var _lines: Array = []
var _index := -1
var _label: Label
var _sub: Label
var _hint: Label
var _skip: Button
var _typing: Tween
var _voice: AudioStreamPlayer
var _auto_token := 0
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
	_label = UiKit.label("", 46, UiKit.GOLD, 8)
	_label.add_theme_font_override("font", DEVANAGARI_FONT)
	UiKit.full_rect(_label)
	_label.offset_left = 120
	_label.offset_right = -120
	_label.offset_bottom = -120
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.anchor_bottom = 0.55
	ui.add_child(_label)
	_sub = UiKit.label("", 28, UiKit.TEXT, 6)
	UiKit.full_rect(_sub)
	_sub.anchor_top = 0.58
	_sub.offset_left = 160
	_sub.offset_right = -160
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(_sub)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_voice.finished.connect(_on_voice_finished)
	add_child(_voice)
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
	_auto_token += 1
	var line = _lines[_index]
	var main := str(line)
	var sub := ""
	var stream: AudioStream = null
	if line is Dictionary:
		main = str(line.get("sa", line.get("hi", line.get("en", ""))))
		sub = str(line.get("en", "")) if main != str(line.get("en", "")) else ""
		var path := "res://audio/voice/%s.wav" % str(line.get("voice", ""))
		if line.has("voice") and ResourceLoader.exists(path):
			stream = load(path)
	_label.text = main
	_sub.text = sub
	_label.visible_ratio = 0.0
	_sub.modulate.a = 0.0
	var spoken := stream.get_length() if stream != null else 0.0
	_typing = create_tween()
	_typing.tween_property(_label, "visible_ratio", 1.0, maxf(main.length() * 0.03, spoken * 0.7))
	_typing.parallel().tween_property(_sub, "modulate:a", 1.0, 0.6).set_delay(0.4)
	_voice.stop()
	if stream != null:
		_voice.stream = stream
		_voice.play()


func _on_voice_finished() -> void:
	var token := _auto_token
	await get_tree().create_timer(PAUSE_AFTER_VOICE).timeout
	if token == _auto_token and not _done:
		_next()


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
