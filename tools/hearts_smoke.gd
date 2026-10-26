extends SceneTree
## Headless frame-level checks of the round 5 rules, in a real level:
##   - a pit fall costs a heart and returns the hero to the lamp WITHOUT refilling hearts
##   - losing the last heart (hits) restarts the level (restart_requested) and logs it
##   - the heart pickup heals one, and is left alone at full hearts
##   - UDAAN leaps ~1.6x a jump, then glides (slow sink) for ~1.5 s
##   - mirage guards burst harmlessly; veiled guards are near-invisible until revealed
##   - phantom walls let the hero walk through
## Needs real frames, so it is separate from tests/run_tests.gd. Run:
##   godot --headless --path . --fixed-fps 60 --script res://tools/hearts_smoke.gd
## Exit code is 1 if any check fails.

var _failures: Array[String] = []
var _restarted := false


func _initialize() -> void:
	_run.call_deferred()


func _level(id: String) -> Node:
	var level = load("res://src/game/level.gd").new()
	level.setup(id)
	root.add_child(level)
	for i in 20:
		await physics_frame
	return level


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	await _falls_and_restart()
	await _heart_pickup()
	await _udaan()
	await _maya()
	for f in _failures:
		print("FAIL  " + f)
	print("hearts_smoke: %d failures" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


func _falls_and_restart() -> void:
	var level = await _level("c1_l4")
	var p = level.player
	var spawn: Vector2 = p.global_position
	level.restart_requested.connect(func(_id: String) -> void: _restarted = true)
	_check(p.hearts == 3, "starts with 3 hearts")
	p.global_position = Vector2(spawn.x + 300.0, level.kill_plane() + 20.0)
	await _frames(90)
	_check(p.alive, "alive again after a pit fall")
	_check(p.hearts == 2, "a pit fall cost one heart (%d)" % p.hearts)
	_check(p.global_position.distance_to(spawn) < 40.0, "back at the start lamp")
	await _frames(30)
	_check(p.hearts == 2, "hearts not refilled after the respawn (%d)" % p.hearts)
	p._invulnerable = 0.0
	p.take_hit(p.global_position.x + 10.0)
	_check(p.hearts == 1, "a hit cost one heart (%d)" % p.hearts)
	await _frames(5)
	p._invulnerable = 0.0
	p.take_hit(p.global_position.x + 10.0)
	_check(not p.alive and p.hearts == 0, "last heart gone")
	await _frames(int(60 * (level.GAME_OVER_SECONDS + 0.5)))
	_check(_restarted, "the level asked to start over (restart_requested)")
	level.queue_free()
	await _frames(2)


func _heart_pickup() -> void:
	var level = await _level("c1_l4")
	var p = level.player
	var pickup = load("res://src/game/heart_pickup.gd").new()
	pickup.position = p.global_position + Vector2(0, -40)
	level.world.add_child(pickup)
	await _frames(10)
	_check(is_instance_valid(pickup) and not pickup.is_queued_for_deletion(), "at full hearts the pickup stays")
	p._invulnerable = 0.0
	p.take_hit(p.global_position.x + 10.0)
	p.velocity = Vector2.ZERO
	p.global_position = pickup.global_position + Vector2(0, 40)
	await _frames(10)
	_check(p.hearts == 3, "the pickup healed a heart (%d)" % p.hearts)
	_check(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "the pickup is used up")
	level.queue_free()
	await _frames(2)


func _udaan() -> void:
	var level = await _level("c1_l4")
	var p = level.player
	var udaan: Dictionary = load("res://src/core/game_config.gd").read("mantras")["udaan"]
	# A plain full jump, for scale: release never comes (held).
	var y0: float = p.global_position.y
	p.udaan(float(udaan["lift"]), float(udaan["glide"]))
	var top := y0
	var air := 0.0
	var glided := 0.0
	for i in 400:
		await physics_frame
		top = minf(top, p.global_position.y)
		air += 1.0 / 60.0
		if p.gliding():
			glided += 1.0 / 60.0
		if p.is_on_floor() and air > 0.2:
			break
	var full: float = load("res://src/game/player.gd").jump_rise(load("res://src/core/game_config.gd").read("player"), 10.0)
	var rise := y0 - top
	_check(rise > 1.45 * full and rise < 1.75 * full, "UDAAN rose %d px (~1.6x %d)" % [rise, full])
	_check(glided > 1.3 and glided < 1.7, "glided %.2f s" % glided)
	_check(air > 2.2, "airborne %.2f s (leap + glide + fall)" % air)
	level.queue_free()
	await _frames(2)


func _maya() -> void:
	var level = await _level("c2_l4")
	var p = level.player
	var sb = load("res://src/game/smokebound.gd")
	var mirage = sb.new()
	mirage.level = level
	mirage.illusion = "mirage"
	mirage.position = p.global_position + Vector2(90, 0)
	mirage.patrol_min = mirage.position.x - 40
	mirage.patrol_max = mirage.position.x + 40
	level.world.add_child(mirage)
	await _frames(120)  # it winds up and thrusts at him
	_check(p.hearts == 3, "a mirage's spear does no harm (%d hearts)" % p.hearts)
	mirage.damage(1, p.global_position.x, "strike")
	_check(not mirage.is_alive() and not mirage.is_in_group("enemies"), "a struck mirage bursts")
	var veiled = sb.new()
	veiled.level = level
	veiled.illusion = "veiled"
	veiled.position = p.global_position + Vector2(600, 0)
	veiled.patrol_min = veiled.position.x - 20
	veiled.patrol_max = veiled.position.x + 20
	level.world.add_child(veiled)
	await _frames(5)
	_check(veiled._rig.modulate.a < 0.2, "a veiled guard is near-invisible")
	level.reveal_maya(1.0)
	await _frames(3)
	_check(veiled._rig.modulate.a > 0.9, "DRISHTI shows the veiled guard")
	await _frames(90)
	_check(veiled._rig.modulate.a < 0.2, "and he fades again when sight ends")
	# Phantom wall: walk straight through.
	var wall = load("res://src/game/phantom_wall.gd").new()
	wall.position = Vector2(p.global_position.x + 60.0, p.global_position.y)
	level.world.add_child(wall)
	veiled.queue_free()
	var x0: float = p.global_position.x
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	_check(p.global_position.x > x0 + 200.0, "walked through the phantom wall (%d px)" % int(p.global_position.x - x0))
	level.queue_free()
	await _frames(2)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
