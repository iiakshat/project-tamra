class_name Level
extends Node2D
## Builds a level from config/levels/<id>.json and runs it: teaching mantras,
## checkpoints, death and respawn, mantra input, pause and completion.

signal completed(level_id: String)
signal quit_to_menu
signal restart_requested(level_id: String)

const PERF_INTERVAL := 10.0

var level_id := ""
var data: Dictionary
var player: Player
var world: Node2D
var hud: Hud
var touch: TouchControls
var caster: MantraCaster
var recognizer: GestureRecognizer
var camera: Camera2D

var _checkpoint := Vector2.ZERO
var _kill_y := 1000.0
var _time := 0.0
var _deaths := 0
var _embers := 0
var _embers_total := 0
var _done := false
var _reveal_time := 0.0
var _start_x := -1.0
var _rng := RandomNumberGenerator.new()
var _perf_timer := 0.0
var _min_fps := 1000.0


## start_x >= 0 drops the hero at that x instead of the spawn (debug and testing).
func setup(id: String, start_x: float = -1.0) -> void:
	level_id = id
	_start_x = start_x


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = GameConfig.level(level_id)
	_rng.seed = hash(level_id)
	var fresh := Game.learn_from_level(level_id)
	var size := GameConfig.vec(data.get("size"), Vector2(6000, 720))
	_kill_y = float(data.get("kill_y", 1000.0))
	var palette := str(data.get("palette", "ember"))
	var quality := str(Game.save.settings.get("quality", "high"))

	var backdrop := Backdrop.new()
	add_child(backdrop)
	backdrop.build(size.x, palette, hash(level_id), quality)

	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	# Pits fade into darkness so they read as deadly, not as open sky.
	world.add_child(Fx.vertical_fade(Fx.INK, Vector2(-200, 560), Vector2(size.x + 400, 300)))
	_build_geometry(size, Fx.palette(palette)["rim"])
	_build_entities()

	player = Player.new()
	player.level = self
	player.setup(Game.player_cfg, int(Game.game_cfg.get("max_hearts", 3)))
	_checkpoint = GameConfig.vec(data.get("spawn"), Vector2(100, 600))
	player.position = _checkpoint if _start_x < 0.0 else Vector2(_start_x, 200)
	world.add_child(player)
	player.died.connect(_on_player_died)

	camera = Camera2D.new()
	camera.position = Vector2(0, -90)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_right = int(size.x)
	camera.limit_top = -900
	camera.limit_bottom = int(data.get("camera_bottom", 780))
	player.add_child(camera)
	camera.make_current()
	camera.add_child(Fx.embers(Vector2(760, 420), 46))

	var front := Backdrop.new()
	add_child(front)
	front.build_foreground(size.x, hash(level_id))

	caster = MantraCaster.new()
	caster.process_mode = Node.PROCESS_MODE_PAUSABLE
	caster.level = self
	caster.cfg = Game.mantra_cfg
	caster.grimoire = Game.grimoire
	add_child(caster)

	hud = Hud.new()
	add_child(hud)
	hud.setup(caster, Game.mantra_cfg)
	hud.set_hearts(player.hearts, player.max_hearts)
	hud.set_embers(0, _embers_total)
	player.hearts_changed.connect(hud.set_hearts)
	caster.cast.connect(hud.on_cast)
	caster.failed.connect(hud.on_cast_failed)
	hud.pause_pressed.connect(toggle_pause)
	hud.resume_pressed.connect(toggle_pause)
	hud.restart_pressed.connect(_on_restart)
	hud.menu_pressed.connect(func() -> void: quit_to_menu.emit())
	hud.next_pressed.connect(func() -> void: completed.emit(level_id))
	hud.copy_log_pressed.connect(_on_copy_log)
	if not fresh.is_empty():
		hud.show_learned(fresh)

	touch = TouchControls.new()
	touch.process_mode = Node.PROCESS_MODE_PAUSABLE
	touch.hud = hud
	add_child(touch)
	touch.stroke_started.connect(_on_stroke_started)
	touch.stroke_finished.connect(_on_stroke_finished)

	_rebuild_recognizer()
	Game.mantras_changed.connect(_rebuild_recognizer)
	Sfx.scene("level")
	Services.analytics.log_event("level_start", {"level": level_id, "learned": Game.save.learned.size()})


func _exit_tree() -> void:
	if Game.mantras_changed.is_connected(_rebuild_recognizer):
		Game.mantras_changed.disconnect(_rebuild_recognizer)


func _physics_process(delta: float) -> void:
	if get_tree().paused or _done:
		return
	_time += delta
	if player.alive and player.global_position.y > _kill_y:
		player.die("fall")
	for d in active_decoys():
		if d.global_position.y > _kill_y:
			d.dispel()
	if _reveal_time > 0.0:
		_reveal_time -= delta
		if _reveal_time <= 0.0:
			_set_revealed(false)


func _process(delta: float) -> void:
	_sample_performance(delta)
	if camera != null:
		var look := Vector2(player.facing * 110.0, 0.0)
		camera.offset = camera.offset.lerp(look, 1.0 - exp(-2.0 * delta))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			toggle_pause()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if is_inside_tree() and not get_tree().paused and not _done:
				toggle_pause()


func active_decoys() -> Array:
	return get_tree().get_nodes_in_group("decoys")


func enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


## Touch positions are in screen space; the world scrolls under the camera.
func screen_to_world(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * p


func reveal_maya(duration: float) -> void:
	_reveal_time = duration
	_set_revealed(true)


func toggle_pause() -> void:
	if _done:
		return
	var paused := not get_tree().paused
	get_tree().paused = paused
	Engine.time_scale = 1.0
	touch.release_all()
	hud.show_pause(paused)


## Logs frame rate and load every few seconds: the only way to learn how the game
## runs on phones we never touch.
func _sample_performance(delta: float) -> void:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	if _time > 2.0 and fps > 0.0:
		_min_fps = minf(_min_fps, fps)
	_perf_timer += delta
	if _perf_timer < PERF_INTERVAL:
		return
	_perf_timer = 0.0
	GameLog.info("perf", "sample", {
		"fps": int(fps),
		"min_fps": int(_min_fps),
		"objects": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"mem_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"x": int(player.global_position.x),
	})
	if fps < 30.0:
		GameLog.warn("perf", "low frame rate", {"fps": int(fps), "x": int(player.global_position.x)})
	_min_fps = 1000.0


func _rebuild_recognizer() -> void:
	recognizer = Game.grimoire.build_recognizer(Game.gesture_min_score())


func _set_revealed(on: bool) -> void:
	for n in get_tree().get_nodes_in_group("maya"):
		n.set_revealed(on)
	hud.set_maya_tint(on)


func _on_stroke_started() -> void:
	Engine.time_scale = float(Game.game_cfg.get("slowmo_while_drawing", 0.35))


func _on_stroke_finished(points: PackedVector2Array) -> void:
	Engine.time_scale = 1.0
	cast_stroke(points)


## Recognizes a drawn stroke and casts the matching mantra.
func cast_stroke(points: PackedVector2Array) -> void:
	if _done or not player.alive:
		return
	var result := recognizer.recognize(points)
	# A tiny stroke is a stray tap, not a failed mantra; stay quiet about it.
	if result["name"] == "" and float(result["score"]) == 0.0:
		return
	caster.try_gesture(result)


func _on_copy_log() -> void:
	GameLog.copy_report_to_clipboard()
	hud.notify("Log copied. Paste it in a message to the developer.")


func _on_player_died(cause: String) -> void:
	_deaths += 1
	Engine.time_scale = 1.0
	Services.analytics.log_event("level_fail", {"level": level_id, "cause": cause, "x": int(player.global_position.x)})
	hud.flash_death()
	await get_tree().create_timer(1.0, false).timeout
	if not is_inside_tree():
		return
	player.respawn(_checkpoint)
	camera.reset_smoothing()


func _on_restart() -> void:
	if _done:
		restart_requested.emit(level_id)
		return
	toggle_pause()
	player.respawn(_checkpoint)
	camera.reset_smoothing()


func _on_checkpoint(at: Vector2) -> void:
	_checkpoint = at
	GameLog.info("level", "checkpoint", {"x": int(at.x), "time": int(_time)})


func _on_enemy_died(at: Vector2, cause: String) -> void:
	Services.analytics.log_event("enemy_defeated", {"level": level_id, "x": int(at.x), "cause": cause})


func _on_ember() -> void:
	_embers += 1
	hud.set_embers(_embers, _embers_total)


func _on_goal() -> void:
	if _done:
		return
	_done = true
	player.controls_enabled = false
	touch.release_all()
	Engine.time_scale = 1.0
	var outcome := Game.complete_level(level_id, _time, _embers)
	Services.analytics.log_event("level_complete", {"level": level_id, "time": int(_time), "deaths": _deaths,
		"embers": _embers, "banked": outcome["banked"]})
	await get_tree().create_timer(0.9, false).timeout
	if is_inside_tree():
		var buyable: Array[String] = outcome["buyable"]
		hud.show_results(str(data.get("name", level_id)), _time, _embers, _embers_total, Game.next_level(level_id) != "",
			int(outcome["banked"]), buyable)


func _build_geometry(size: Vector2, rim: Color) -> void:
	for g in data.get("ground", []):
		var top := float(g[1])
		_solid(Rect2(float(g[0]), top, float(g[2]), 1500.0 - top), true, rim)
	for p in data.get("platforms", []):
		_solid(Rect2(float(p[0]), float(p[1]), float(p[2]), 26.0), false, rim)
	# Invisible walls at both ends.
	for x in [-40.0, size.x]:
		var wall := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40, 4000)
		shape.shape = rect
		shape.position = Vector2(x + 20.0, -500.0)
		wall.add_child(shape)
		world.add_child(wall)
	for kind in ["false", "hidden"]:
		for m in data.get("maya_" + kind, []):
			var mp := MayaPlatform.new()
			mp.kind = kind
			mp.position = Vector2(float(m[0]), float(m[1]))
			mp.size = Vector2(float(m[2]), 26.0)
			world.add_child(mp)


func _solid(rect: Rect2, is_ground: bool, rim: Color) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	shape.shape = r
	shape.position = rect.position + rect.size / 2.0
	# Thin ledges can be jumped through from below.
	shape.one_way_collision = not is_ground
	body.add_child(shape)
	body.add_child(LevelArt.rock(rect, is_ground, rim, _rng))
	world.add_child(body)


func _build_entities() -> void:
	for b in data.get("barriers", []):
		var barrier := SmokeBarrier.new()
		barrier.position = Vector2(float(b[0]), float(b[1]))
		barrier.height = float(b[2])
		world.add_child(barrier)
	for c in data.get("cracked", []):
		var wall := CrackedWall.new()
		wall.position = Vector2(float(c[0]), float(c[1]))
		wall.height = float(c[2])
		world.add_child(wall)
	for c in data.get("checkpoints", []):
		var cp := Checkpoint.new()
		cp.position = GameConfig.vec(c)
		cp.reached.connect(_on_checkpoint)
		world.add_child(cp)
	for e in data.get("embers", []):
		var ember := EmberPickup.new()
		ember.position = GameConfig.vec(e)
		ember.collected.connect(_on_ember)
		world.add_child(ember)
		_embers_total += 1
	for pr in data.get("prompts", []):
		var zone := PromptZone.new()
		zone.position = Vector2(float(pr.get("x", 0)), 600)
		zone.width = float(pr.get("width", 360))
		zone.text = str(pr.get("text", ""))
		zone.glyph = str(pr.get("glyph", ""))
		zone.shown.connect(func(text: String, glyph: String) -> void: hud.show_prompt(text, glyph))
		zone.hidden_again.connect(func() -> void: hud.hide_prompt())
		world.add_child(zone)
	for e in data.get("enemies", []):
		var s := Smokebound.new()
		s.level = self
		s.position = Vector2(float(e.get("x", 0)), float(e.get("y", 600)))
		s.patrol_min = float(e.get("min", s.position.x - 200))
		s.patrol_max = float(e.get("max", s.position.x + 200))
		s.died.connect(_on_enemy_died)
		world.add_child(s)
	if data.has("goal"):
		var gate := GoalGate.new()
		gate.position = GameConfig.vec(data["goal"])
		gate.reached.connect(_on_goal)
		world.add_child(gate)
