class_name StoryScreen
extends Node2D
## The story as a painted motion comic. Each panel is a full-screen flat 2D painting
## (assets/story/<panel>.jpg) that the camera drifts across; it pushes in on the
## speaker, punches in and shakes on dramatic lines, and cross-fades to the next panel.
## Flat particles (embers, ash, smoke, mist) drift over it. Lines are voiced in Hindi
## with emotion (Gemini TTS) and subtitled in Devanagari and English beside the
## speaker's portrait. Choices branch briefly, then rejoin. Script: config/story.json.

signal finished

const FONT := preload("res://assets/fonts/YatraOne-Regular.ttf")
const PAUSE_AFTER_VOICE := 0.75
const SPEAKERS := {"tamra": "Tamra", "maa": "Maa", "king": "The Smoke King", "guard": "Guard", "narrator": "", "chant": ""}
const PORTRAITS := {"tamra": "hero", "maa": "maa", "king": "king", "guard": "soldier"}
const BAR := Color(0.03, 0.02, 0.06)

var story_id := ""

var _panels: Array = []
var _panel_i := -1
var _queue: Array = []
var _speaker := ""
var _done := false
var _token := 0

var _stage: Node2D          # holds the painting sprites; moved/scaled as a camera
var _art: Sprite2D
var _old_art: Sprite2D
var _fx_layer: Node2D
var _cam := Vector3(0.5, 0.5, 1.0)   # focus x, focus y (0..1 of the painting), zoom
var _cam_tween: Tween
var _shake := 0.0
var _base_shake := 0.0
var _flash: ColorRect

var _box: Control
var _portrait: TextureRect
var _name: Label
var _line: Label
var _sub: Label
var _choices: HBoxContainer
var _typing: Tween
var _voice: AudioStreamPlayer
var _t := 0.0


## Seen-flags carry the script version, so a rewritten story plays once more for
## players who saw the old one.
static func seen_key(id: String) -> String:
	return "%s@%d" % [id, int(GameConfig.read("story").get("_version", 1))]


static func is_seen(id: String) -> bool:
	return Game.save.story_seen.has(seen_key(id))


func setup(id: String) -> void:
	story_id = id


func _ready() -> void:
	var back := CanvasLayer.new()
	back.layer = -10
	add_child(back)
	var black := ColorRect.new()
	black.color = BAR
	UiKit.full_rect(black)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(black)

	_stage = Node2D.new()
	add_child(_stage)
	_fx_layer = Node2D.new()
	add_child(_fx_layer)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var root := UiKit.full_rect(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_flash)
	root.add_child(_flash)
	_add_letterbox(root)
	_build_box(root)

	_choices = HBoxContainer.new()
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 26)
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.anchor_right = 1.0
	_choices.offset_top = -330
	_choices.offset_bottom = -210
	_choices.visible = false
	root.add_child(_choices)

	var skip := Button.new()
	skip.text = "Skip  ▸▸"
	skip.flat = true
	skip.add_theme_font_size_override("font_size", 22)
	skip.add_theme_color_override("font_color", Color(UiKit.TEXT, 0.75))
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -170
	skip.offset_right = -24
	skip.offset_top = 14
	skip.offset_bottom = 60
	skip.pressed.connect(_finish)
	root.add_child(skip)

	_voice = AudioStreamPlayer.new()
	_voice.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_voice.finished.connect(_on_voice_finished)
	add_child(_voice)

	_panels = GameConfig.read("story").get(story_id, [])
	Services.analytics.log_event("story_view", {"id": story_id})
	Sfx.scene("story")
	_next_panel()


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(_base_shake, _shake - delta * 1.6)
	_apply_camera()


func _unhandled_input(event: InputEvent) -> void:
	var tapped: bool = event is InputEventScreenTouch and event.pressed
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	if (not tapped and not key) or _choices.visible or _done:
		return
	if _typing != null and _typing.is_running():
		_typing.kill()
		_line.visible_ratio = 1.0
		_sub.modulate.a = 1.0
	else:
		_next_beat()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_finish()


# --- panels and camera -------------------------------------------------------------

func _next_panel() -> void:
	_panel_i += 1
	if _panel_i >= _panels.size():
		_finish()
		return
	var panel: Dictionary = _panels[_panel_i]
	_show_panel(panel)
	_queue = (panel.get("beats", []) as Array).duplicate()
	_next_beat()


func _show_panel(panel: Dictionary) -> void:
	var path := "res://assets/story/%s.jpg" % str(panel.get("panel", ""))
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if _art != null:
		_old_art = _art
		var fade := create_tween()
		fade.tween_property(_old_art, "modulate:a", 0.0, 0.7)
		fade.tween_callback(_old_art.queue_free)
	_art = Sprite2D.new()
	_art.texture = tex
	_art.centered = false
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.modulate.a = 0.0 if _old_art != null else 1.0
	_stage.add_child(_art)
	if _old_art != null:
		create_tween().tween_property(_art, "modulate:a", 1.0, 0.7)
	var from := _vec3(panel.get("from", [0.5, 0.5, 1.0]))
	var to := _vec3(panel.get("to", [0.5, 0.5, 1.05]))
	_cam = from
	_move_camera(to, 14.0, Tween.TRANS_SINE)
	_base_shake = float(panel.get("shake", 0.0)) * 5.0
	_build_fx(str(panel.get("fx", "")))


func _move_camera(to: Vector3, time: float, trans := Tween.TRANS_CUBIC) -> void:
	if _cam_tween != null:
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.tween_property(self, "_cam", to, time).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	if time < 5.0:
		# After a quick push-in, keep drifting so the frame never freezes.
		_cam_tween.tween_property(self, "_cam", to + Vector3(0.02, -0.01, 0.04), 10.0).set_trans(Tween.TRANS_SINE)


## Scales the painting to cover the screen times the zoom, with the focus point at the
## screen centre (clamped so no edge shows), plus shake.
func _apply_camera() -> void:
	if _art == null or _art.texture == null:
		return
	var view := get_viewport().get_visible_rect().size
	var tex_size := Vector2(_art.texture.get_size())
	var cover := maxf(view.x / tex_size.x, view.y / tex_size.y)
	var s := cover * maxf(_cam.z, 1.0)
	var size := tex_size * s
	var pos := view / 2.0 - Vector2(_cam.x * size.x, _cam.y * size.y)
	pos.x = clampf(pos.x, view.x - size.x, 0.0)
	pos.y = clampf(pos.y, view.y - size.y, 0.0)
	if _shake > 0.0:
		pos += Vector2(sin(_t * 47.0), cos(_t * 39.0)) * _shake
	_stage.position = pos
	_stage.scale = Vector2(s, s)
	if _old_art != null and is_instance_valid(_old_art) and _old_art.texture != null:
		_old_art.scale = tex_size / Vector2(_old_art.texture.get_size())


func _punch() -> void:
	_shake = 14.0
	var z := _cam
	_move_camera(Vector3(z.x, z.y, z.z + 0.08), 0.18, Tween.TRANS_BACK)
	_flash.color = Color(0.85, 0.3, 0.4, 0.22)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	Game.vibrate(40)


func _vec3(v) -> Vector3:
	var a: Array = v
	return Vector3(float(a[0]), float(a[1]), float(a[2]) if a.size() > 2 else 1.0)


## Flat drifting particles over the painting (no additive glow: the art is flat 2D).
func _build_fx(kind: String) -> void:
	for c in _fx_layer.get_children():
		c.queue_free()
	if kind == "":
		return
	var view := get_viewport().get_visible_rect().size
	var p := CPUParticles2D.new()
	p.position = Vector2(view.x / 2.0, view.y / 2.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = view / 2.0
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.gravity = Vector2.ZERO
	match kind:
		"embers", "embers_heavy":
			p.amount = 70 if kind == "embers_heavy" else 34
			p.direction = Vector2(0.2, -1)
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 90.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.5
			p.color = Color(0.95, 0.42, 0.55, 0.85)
		"ash":
			p.amount = 60
			p.direction = Vector2(0.15, 1)
			p.initial_velocity_min = 20.0
			p.initial_velocity_max = 60.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 5.0
			p.color = Color(0.72, 0.68, 0.78, 0.6)
		"smoke":
			p.amount = 14
			p.lifetime = 7.0
			p.direction = Vector2(1, -0.2)
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 30.0
			p.scale_amount_min = 60.0
			p.scale_amount_max = 140.0
			p.color = Color(0.06, 0.04, 0.09, 0.22)
		"mist":
			p.amount = 12
			p.lifetime = 8.0
			p.direction = Vector2(1, 0)
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 24.0
			p.scale_amount_min = 80.0
			p.scale_amount_max = 160.0
			p.color = Color(0.55, 0.85, 0.85, 0.08)
		"light":
			p.amount = 26
			p.direction = Vector2(0, -1)
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 26.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			p.color = Color(0.85, 0.95, 1.0, 0.7)
	p.spread = 25.0
	_fx_layer.add_child(p)


# --- lines -------------------------------------------------------------------------

func _next_beat() -> void:
	_token += 1
	_voice.stop()
	if _queue.is_empty():
		_next_panel()
		return
	var beat: Dictionary = _queue.pop_front()
	if beat.has("choice"):
		_show_choice(beat)
	else:
		_play(beat)


func _play(beat: Dictionary) -> void:
	_speaker = str(beat.get("speaker", ""))
	_name.text = SPEAKERS.get(_speaker, "")
	_name.visible = _name.text != ""
	var art := str(PORTRAITS.get(_speaker, ""))
	var tex_path := "res://assets/story/portraits/%s.png" % art
	_portrait.texture = load(tex_path) if art != "" and ResourceLoader.exists(tex_path) else null
	_portrait.visible = _portrait.texture != null
	var main := str(beat.get("hi", ""))
	_line.text = main
	_line.add_theme_color_override("font_color", UiKit.ACCENT if _speaker == "chant" else UiKit.TEXT)
	_sub.text = str(beat.get("en", ""))
	_line.visible_ratio = 0.0
	_sub.modulate.a = 0.0
	_box.modulate.a = 1.0
	if beat.has("focus"):
		_move_camera(_vec3(beat["focus"]), 1.3)
	if bool(beat.get("punch", false)):
		_punch()
	var stream: AudioStream = null
	# "voice_pending": a line whose take is not generated yet; plays once the file exists.
	var vid := str(beat.get("voice", beat.get("voice_pending", "")))
	var path := "res://audio/voice/%s.ogg" % vid
	if vid != "" and ResourceLoader.exists(path):
		stream = load(path)
	var spoken := stream.get_length() if stream != null else main.length() * 0.06
	_typing = create_tween()
	_typing.tween_property(_line, "visible_ratio", 1.0, clampf(spoken * 0.7, 0.4, 4.0))
	_typing.parallel().tween_property(_sub, "modulate:a", 1.0, 0.5).set_delay(0.25)
	if stream != null:
		_voice.stream = stream
		_voice.play()
	else:
		var token := _token
		await get_tree().create_timer(spoken + 1.2).timeout
		if token == _token:
			_on_voice_finished()


func _on_voice_finished() -> void:
	var token := _token
	await get_tree().create_timer(PAUSE_AFTER_VOICE).timeout
	if token == _token and not _done and not _choices.visible:
		_next_beat()


func _show_choice(beat: Dictionary) -> void:
	_box.modulate.a = 0.0
	for c in _choices.get_children():
		c.queue_free()
	var options: Array = beat.get("options", [])
	var pill: Texture2D = load("res://assets/ui/pill_jade.png") if ResourceLoader.exists("res://assets/ui/pill_jade.png") else null
	for i in options.size():
		var opt: Dictionary = options[i]
		var b := Button.new()
		b.text = str(opt.get("en", ""))
		b.custom_minimum_size = Vector2(330, 96)
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_color_override("font_color", UiKit.TEXT)
		if pill != null:
			for state in ["normal", "hover", "pressed", "focus"]:
				var sb := StyleBoxTexture.new()
				sb.texture = pill
				sb.texture_margin_left = 56
				sb.texture_margin_right = 56
				sb.texture_margin_top = 40
				sb.texture_margin_bottom = 40
				sb.modulate_color = Color(1.15, 1.15, 1.15) if state == "pressed" else Color.WHITE
				b.add_theme_stylebox_override(state, sb)
		b.pressed.connect(_pick.bind(str(beat["choice"]), i, opt))
		_choices.add_child(b)
	_choices.visible = true
	_choices.modulate.a = 0.0
	_choices.scale = Vector2(0.96, 0.96)
	var tw := create_tween()
	tw.tween_property(_choices, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(_choices, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)


func _pick(choice_id: String, index: int, opt: Dictionary) -> void:
	_choices.visible = false
	Sfx.play("ui_click")
	Game.save.story_choices[choice_id] = index
	Services.analytics.log_event("story_choice", {"id": choice_id, "pick": index})
	var reply: Array = opt.get("reply", [])
	_queue = reply.duplicate() + _queue
	_next_beat()


func _finish() -> void:
	if _done:
		return
	_done = true
	_voice.stop()
	var key := seen_key(story_id)
	if not Game.save.story_seen.has(key):
		Game.save.story_seen.append(key)
	Game.persist()
	finished.emit()


# --- layout -------------------------------------------------------------------------

func _add_letterbox(root: Control) -> void:
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = BAR
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if top:
			bar.offset_bottom = 44
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -44
		root.add_child(bar)
		var slide := create_tween()
		var from := -44.0 if top else 44.0
		bar.position.y += from
		slide.tween_property(bar, "position:y", bar.position.y - from, 0.5).set_trans(Tween.TRANS_CUBIC)


## Subtitle box: portrait on the left, name, the Hindi/Sanskrit line, English below.
func _build_box(root: Control) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.08, 0.82)
	style.border_color = Color(UiKit.ACCENT, 0.35)
	style.border_width_top = 2
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_right = 1.0
	panel.offset_top = -180
	panel.offset_bottom = -44
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	_box = panel
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(112, 112)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_portrait)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_name = UiKit.label("", 20, UiKit.ACCENT, 4)
	col.add_child(_name)
	_line = UiKit.label("", 32, UiKit.TEXT, 6)
	_line.add_theme_font_override("font", FONT)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_line)
	_sub = UiKit.label("", 20, UiKit.MUTED, 4)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_sub)
