class_name StoryScreen
extends Node2D
## The story as a shadow-puppet play: the cast stands on a lit stage, the speaker's
## puppet is shaken as it talks (the way puppeteers do), lines are voiced in Hindi
## (Sanskrit for invocations) with English subtitles, and choices branch briefly before
## rejoining the one path. Script: config/story.json.

signal finished

const FONT := preload("res://assets/fonts/YatraOne-Regular.ttf")
const PAUSE_AFTER_VOICE := 0.9
const SPEAKERS := {"tamra": "Tamra", "maa": "Maa", "king": "The Smoke King", "guard": "Guard"}
const STAGES := {"fire": "ember", "court": "palace", "pit": "ember", "marsh": "marsh", "walls": "palace", "tower": "palace"}

var story_id := ""

var _scenes: Array = []
var _scene_i := -1
var _queue: Array = []
var _actors := {}
var _speaker := ""
var _stage: Node2D
var _name: Label
var _line: Label
var _sub: Label
var _choices: HBoxContainer
var _typing: Tween
var _voice: AudioStreamPlayer
var _token := 0
var _done := false
var _t := 0.0


func setup(id: String) -> void:
	story_id = id


func _ready() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var root := UiKit.full_rect(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	var panel := PanelContainer.new()
	var style := UiKit.panel_style(0.78)
	style.set_corner_radius_all(0)
	style.border_color = Color(UiKit.ACCENT, 0.25)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_right = 1.0
	panel.offset_top = -168
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	_name = UiKit.label("", 20, UiKit.ACCENT, 4)
	col.add_child(_name)
	_line = UiKit.label("", 34, UiKit.TEXT, 6)
	_line.add_theme_font_override("font", FONT)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_line)
	_sub = UiKit.label("", 21, UiKit.MUTED, 4)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_sub)

	_choices = HBoxContainer.new()
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 22)
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.anchor_right = 1.0
	_choices.offset_top = -300
	_choices.offset_bottom = -190
	_choices.visible = false
	root.add_child(_choices)

	var skip := UiKit.icon_button("next", 64, UiKit.MUTED)
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -88
	skip.offset_right = -24
	skip.offset_top = 20
	skip.offset_bottom = 84
	skip.pressed.connect(_finish)
	root.add_child(skip)

	_voice = AudioStreamPlayer.new()
	_voice.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_voice.finished.connect(_on_voice_finished)
	add_child(_voice)

	_scenes = GameConfig.read("story").get(story_id, [])
	Services.analytics.log_event("story_view", {"id": story_id})
	Sfx.scene("story")
	_next_scene()


func _process(delta: float) -> void:
	_t += delta
	for id in _actors:
		var a: Dictionary = _actors[id]
		var holder: Node2D = a["holder"]
		var p: Puppet = a["puppet"]
		p.animate(delta, 0.0, true, 0.0)
		var talking: bool = id == _speaker and _voice.playing
		# A puppeteer jiggles the figure that is speaking.
		holder.rotation = sin(_t * 18.0) * 0.025 if talking else lerpf(holder.rotation, 0.0, 0.2)
		var glow: Sprite2D = a["glow"]
		glow.modulate.a = lerpf(glow.modulate.a, 0.55 if id == _speaker else 0.12, 0.1)
		if bool(a["ghost"]):
			holder.position.y = float(a["y"]) + sin(_t * 1.6) * 8.0


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


func _next_scene() -> void:
	_scene_i += 1
	if _scene_i >= _scenes.size():
		_finish()
		return
	var scene: Dictionary = _scenes[_scene_i]
	_build_stage(scene)
	_queue = (scene.get("beats", []) as Array).duplicate()
	_next_beat()


func _next_beat() -> void:
	_token += 1
	_voice.stop()
	if _queue.is_empty():
		_next_scene()
		return
	var beat: Dictionary = _queue.pop_front()
	if beat.has("choice"):
		_show_choice(beat)
	else:
		_play(beat)


func _play(beat: Dictionary) -> void:
	_speaker = str(beat.get("speaker", ""))
	_name.text = SPEAKERS.get(_speaker, "")
	var main := str(beat.get("sa", beat.get("hi", "")))
	_line.text = main
	_line.add_theme_color_override("font_color", UiKit.ACCENT if beat.has("sa") else UiKit.TEXT)
	_sub.text = str(beat.get("en", ""))
	_line.visible_ratio = 0.0
	_sub.modulate.a = 0.0
	var stream: AudioStream = null
	var path := "res://audio/voice/%s.ogg" % str(beat.get("voice", ""))
	if beat.has("voice") and ResourceLoader.exists(path):
		stream = load(path)
	var spoken := stream.get_length() if stream != null else 0.0
	_typing = create_tween()
	_typing.tween_property(_line, "visible_ratio", 1.0, maxf(main.length() * 0.025, spoken * 0.6))
	_typing.parallel().tween_property(_sub, "modulate:a", 1.0, 0.5).set_delay(0.3)
	if beat.has("pose") and _actors.has(_speaker if _speaker != "narrator" else "tamra"):
		var p: Puppet = _actors[_speaker if _speaker != "narrator" else "tamra"]["puppet"]
		match str(beat["pose"]):
			"cast":
				p.cast()
				Sfx.play("cast_setu")
			"strike":
				p.strike()
				Sfx.play("strike_swing")
	if stream != null:
		_voice.stream = stream
		_voice.play()
	elif not beat.has("voice"):
		_on_voice_finished()


func _on_voice_finished() -> void:
	var token := _token
	await get_tree().create_timer(PAUSE_AFTER_VOICE).timeout
	if token == _token and not _done and not _choices.visible:
		_next_beat()


func _show_choice(beat: Dictionary) -> void:
	_speaker = "tamra"
	_name.text = ""
	_line.text = ""
	_sub.text = ""
	for c in _choices.get_children():
		c.queue_free()
	var options: Array = beat.get("options", [])
	for i in options.size():
		var opt: Dictionary = options[i]
		var b := UiKit.button("", 250)
		b.custom_minimum_size = Vector2(250, 100)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.full_rect(row)
		var icon := str(opt.get("icon", ""))
		if GlyphShapes.NAMES.has(icon):
			var g := GlyphView.new()
			g.glyph = icon
			g.custom_minimum_size = Vector2(56, 56)
			row.add_child(g)
		elif icon != "":
			var v := UiKit.IconView.new()
			v.icon = icon
			v.color = UiKit.ACCENT
			v.custom_minimum_size = Vector2(44, 44)
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(v)
		row.add_child(UiKit.label(str(opt.get("en", "")), 26, UiKit.TEXT, 4))
		b.add_child(row)
		b.pressed.connect(_pick.bind(str(beat["choice"]), i, opt))
		_choices.add_child(b)
	_choices.visible = true
	_choices.modulate.a = 0.0
	create_tween().tween_property(_choices, "modulate:a", 1.0, 0.3)


func _pick(choice_id: String, index: int, opt: Dictionary) -> void:
	_choices.visible = false
	Game.save.story_choices[choice_id] = index
	Services.analytics.log_event("story_choice", {"id": choice_id, "pick": index})
	var reply: Array = opt.get("reply", [])
	_queue = reply.duplicate() + _queue
	_next_beat()


func _build_stage(scene: Dictionary) -> void:
	if _stage != null:
		_stage.queue_free()
	_actors.clear()
	_stage = Node2D.new()
	add_child(_stage)
	var stage_name := str(scene.get("stage", "pit"))
	var palette := str(STAGES.get(stage_name, "ember"))
	var backdrop := Backdrop.new()
	_stage.add_child(backdrop)
	backdrop.build(3000.0, palette, hash(stage_name))
	backdrop.sky_material.set_shader_parameter("dim", 0.6)
	backdrop.set_autoscroll(-6.0)
	var spark: Color = Fx.palette(palette).get("spark", Color.WHITE)
	var embers := Fx.embers(Vector2(700, 300), 30, spark)
	embers.position = Vector2(640, 420)
	_stage.add_child(embers)
	# The lit cloth of a shadow-puppet stage, glowing behind the cast.
	var lamp := Fx.glow(Color(spark, 0.22), 520.0)
	lamp.position = Vector2(640, 420)
	_stage.add_child(lamp)
	_stage.add_child(Fx.polygon(PackedVector2Array([Vector2(0, 590), Vector2(1280, 590), Vector2(1280, 720), Vector2(0, 720)]), Fx.INK))
	match stage_name:
		"fire":
			var fire := CPUParticles2D.new()
			fire.amount = 40
			fire.lifetime = 0.9
			fire.texture = Fx.glow_texture()
			fire.material = Fx.additive()
			fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			fire.emission_rect_extents = Vector2(18, 4)
			fire.direction = Vector2(0, -1)
			fire.spread = 12.0
			fire.gravity = Vector2(0, -60)
			fire.initial_velocity_min = 40.0
			fire.initial_velocity_max = 90.0
			fire.scale_amount_min = 0.3
			fire.scale_amount_max = 0.6
			fire.color = Color(1.0, 0.55, 0.25)
			fire.color_ramp = Fx.fade_ramp()
			fire.position = Vector2(640, 586)
			_stage.add_child(fire)
			var warm := Fx.glow(Color(1.0, 0.5, 0.25, 0.45), 220.0)
			warm.position = Vector2(640, 540)
			_stage.add_child(warm)
		"court", "walls", "tower":
			for x in [120.0, 1160.0]:
				_stage.add_child(Fx.polygon(PackedVector2Array([Vector2(x - 40, 590), Vector2(x + 40, 590), Vector2(x + 30, 160),
					Vector2(x - 30, 160)]), Fx.INK))
	for a in scene.get("actors", []):
		var holder := Node2D.new()
		var x := float(a.get("x", 0.5)) * 1280.0
		var y := 588.0 - (30.0 if bool(a.get("ghost", false)) else 0.0)
		holder.position = Vector2(x, y)
		holder.scale = Vector2.ONE * 2.0 * float(a.get("scale", 1.0))
		_stage.add_child(holder)
		var glow := Fx.glow(Color(UiKit.ACCENT, 0.12), 70.0)
		glow.position = Vector2(0, -60)
		holder.add_child(glow)
		var p := Puppet.new()
		var style := str(a.get("style", "hero"))
		p.build(style, Game.skin_palette() if style == "hero" else {})
		p.face(int(a.get("face", 1)))
		holder.add_child(p)
		if bool(a.get("ghost", false)):
			p.modulate = Color(0.7, 0.9, 1.0, 0.5)
		_actors[str(a.get("id", ""))] = {"holder": holder, "puppet": p, "glow": glow, "ghost": bool(a.get("ghost", false)), "y": y}


func _finish() -> void:
	if _done:
		return
	_done = true
	_voice.stop()
	if not Game.save.story_seen.has(story_id):
		Game.save.story_seen.append(story_id)
	Game.persist()
	finished.emit()
