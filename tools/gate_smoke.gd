extends SceneTree
## Headless check of the goal-gate exit: once the hero reaches the gate nothing may hurt
## him, guards stand down, bolts vanish, and he walks into the doorway and fades out.
## Needs real frames, so it is separate from tests/run_tests.gd. Run:
##   godot --headless --path . --fixed-fps 60 --script res://tools/gate_smoke.gd
## Exit code is 1 if any check fails.

## Game classes are loaded at run time: this script compiles before the autoloads exist.
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level = load("res://src/game/level.gd").new()
	level.setup("c2_l1")
	root.add_child(level)
	for i in 30:
		await physics_frame
	var goal: Array = level.data["goal"]
	var gate := Vector2(float(goal[0]), float(goal[1]))
	var player = level.player
	# A guard right behind the hero, alert and winding up, and a bolt in the air.
	var guard = load("res://src/game/smokebound.gd").new()
	guard.level = level
	guard.position = Vector2(gate.x - 150.0, gate.y)
	guard.patrol_min = guard.position.x - 50.0
	guard.patrol_max = guard.position.x + 50.0
	level.world.add_child(guard)
	player.global_position = Vector2(gate.x - 90.0, gate.y - 2.0)
	player.velocity = Vector2.ZERO
	var bolt = load("res://src/game/smoke_bolt.gd").new()
	bolt.position = player.global_position + Vector2(-200, -50)
	bolt.dir = Vector2.RIGHT
	level.world.add_child(bolt)
	for i in 3:
		await physics_frame
	player.global_position = Vector2(gate.x - 30.0, gate.y - 2.0)  # into the gate area
	for i in 240:
		await physics_frame
	_check(player.alive, "hero alive after reaching the gate")
	_check(player.hearts == player.max_hearts, "hero unhurt after the gate (%d/%d)" % [player.hearts, player.max_hearts])
	_check(player.finishing, "hero is in the finishing state")
	_check(not player.controls_enabled, "controls are off at the gate")
	_check(absf(player.global_position.x - gate.x) < 12.0, "hero walked into the doorway (dx %d)" % int(player.global_position.x - gate.x))
	_check(player.modulate.a < 0.1, "hero faded into the light (a=%.2f)" % player.modulate.a)
	_check(not guard.is_physics_processing(), "guards stand down")
	_check(get_nodes_in_group("bolts").is_empty(), "bolts are gone")
	for f in _failures:
		print("FAIL  " + f)
	print("gate_smoke: %d failures" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
