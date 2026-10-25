class_name Smokebound
extends CharacterBody2D
## A soldier of the Smoke King. Patrols, chases what it sees (a maya decoy before the
## real hero), and attacks with a telegraphed spear thrust: wind-up with a glint, lunge,
## recover. Three staff strikes or one bolt of fire fell it. Strikes interrupt a wind-up.

signal died(at: Vector2, cause: String)

enum State { PATROL, CHASE, WINDUP, THRUST, RECOVER, STAGGER, DAZED, BOUND, DEAD }

const SIZE := Vector2(44, 108)
const LEASH := 140.0
const ATTACK_RANGE := 100.0
const SPEAR_REACH := 118.0
const WINDUP_TIME := 0.55
const THRUST_TIME := 0.18
const RECOVER_TIME := 0.6

var level: Level
var patrol_min := 0.0
var patrol_max := 0.0
var speed := 85.0
var chase_speed := 165.0
var sight := 420.0
var daze_time := 2.5
var max_hp := 3
var hp := 3
var dir := -1
var puppet: Puppet
## "soldier" patrols and thrusts; "archer" holds position and looses smoke bolts.
var kind := "soldier"
var fire_interval := 2.6
var drop_prana := 20.0

var _fire_t := 1.2

var _state := State.PATROL
var _t := 0.0
var _knock := 0.0
var _alerted := false
var _thrust_hit := false
var _glint: Sprite2D
var _daze_fx: Node2D
var _roots: Node2D
var _pips: Pips


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("enemies")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y / 2.0)
	add_child(shape)
	var aura := Fx.glow(Color(0.9, 0.15, 0.1, 0.2), 95.0)
	aura.position = Vector2(0, -60)
	add_child(aura)
	hp = max_hp
	puppet = Puppet.new()
	if kind == "archer":
		puppet.build("soldier", {"cloth": Color(0.3, 0.14, 0.36), "sash": Color(0.5, 0.2, 0.8), "metal": Color(0.42, 0.38, 0.46)})
	else:
		puppet.build("soldier")
	add_child(puppet)
	_glint = Fx.glow(Color(1.0, 0.95, 0.75), 26.0)
	_glint.visible = false
	_glint.z_index = 45
	add_child(_glint)
	_daze_fx = Node2D.new()
	_daze_fx.position = Vector2(0, -150)
	_daze_fx.visible = false
	_daze_fx.z_index = 45
	for i in 3:
		var m := Fx.glow(Color(0.5, 0.95, 1.0), 9.0)
		m.position = Vector2.from_angle(TAU * i / 3.0) * 16.0
		_daze_fx.add_child(m)
	add_child(_daze_fx)
	_roots = _make_roots()
	add_child(_roots)
	_pips = Pips.new()
	_pips.position = Vector2(0, -150)
	_pips.z_index = 45
	_pips.visible = false
	add_child(_pips)


func is_alive() -> bool:
	return _state != State.DEAD


func hitbox() -> Rect2:
	return Rect2(global_position + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	velocity.y = minf(velocity.y + 2300.0 * delta, 1300.0)
	_knock = move_toward(_knock, 0.0, 1400.0 * delta)
	_t -= delta
	var vx := 0.0
	match _state:
		State.PATROL, State.CHASE:
			vx = _archer_aim(delta) if kind == "archer" else _move_or_engage()
		State.WINDUP:
			if _t <= 0.0 and kind == "archer":
				_loose_bolt()
			elif _t <= 0.0:
				_enter(State.THRUST, THRUST_TIME)
				puppet.thrust()
				_glint.visible = false
				_thrust_hit = false
				Sfx.play("enemy_attack", global_position)
		State.THRUST:
			vx = dir * 240.0
			_check_spear()
			if _t <= 0.0:
				_enter(State.RECOVER, RECOVER_TIME)
				puppet.relax()
		State.RECOVER, State.STAGGER, State.BOUND:
			if _t <= 0.0:
				if _state == State.BOUND:
					puppet.set_bound(false)
					_roots.visible = false
				_enter(State.CHASE, 0.0)
		State.DAZED:
			if _t <= 0.0:
				_enter(State.PATROL, 0.0)
	velocity.x = vx + _knock
	move_and_slide()


func _process(delta: float) -> void:
	puppet.face(dir)
	puppet.animate(delta, velocity.x / chase_speed, is_on_floor(), velocity.y)
	_daze_fx.visible = _state == State.DAZED
	_daze_fx.rotation += delta * 5.0
	if _glint.visible:
		_glint.position = to_local(puppet.weapon_tip.global_position)
		_glint.scale = Vector2.ONE * (0.6 + 0.3 * sin(Time.get_ticks_msec() * 0.03))


## Archers never walk: they turn to the hero in range and, every few seconds, draw
## (glint, half a second of warning) and loose a bolt.
func _archer_aim(delta: float) -> float:
	var p := level.player
	if p == null or not p.alive or p.global_position.distance_to(global_position) > 650.0:
		_fire_t = maxf(_fire_t, 0.8)
		return 0.0
	dir = 1 if p.global_position.x > global_position.x else -1
	if not _alerted:
		_alerted = true
		Sfx.play("enemy_alert", global_position)
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = fire_interval
		_enter(State.WINDUP, 0.5)
		puppet.windup()
		_glint.visible = true
		Sfx.play("enemy_windup", global_position)
	return 0.0


func _loose_bolt() -> void:
	_glint.visible = false
	puppet.thrust()
	var bolt := SmokeBolt.new()
	var from := puppet.weapon_tip.global_position
	bolt.position = from
	var target := level.player.global_position + Vector2(0, -50)
	bolt.dir = (target - from).normalized()
	get_parent().add_child(bolt)
	Sfx.play("enemy_attack", global_position, -3.0, 1.3)
	_enter(State.RECOVER, 0.4)


func _move_or_engage() -> float:
	var target := _pick_target()
	if target == null:
		_state = State.PATROL
		if global_position.x <= patrol_min:
			dir = 1
		elif global_position.x >= patrol_max:
			dir = -1
		return dir * speed
	if not _alerted:
		_alerted = true
		Sfx.play("enemy_alert", global_position)
	_state = State.CHASE
	var dx := target.global_position.x - global_position.x
	if absf(dx) > 6.0:
		dir = 1 if dx > 0.0 else -1
	if absf(dx) < ATTACK_RANGE and absf(target.global_position.y - global_position.y) < 70.0:
		_enter(State.WINDUP, WINDUP_TIME)
		puppet.windup()
		_glint.visible = true
		Sfx.play("enemy_windup", global_position)
		return 0.0
	var vx := dir * chase_speed
	if (vx < 0.0 and global_position.x <= patrol_min - LEASH) or (vx > 0.0 and global_position.x >= patrol_max + LEASH):
		vx = 0.0
	return vx


func _pick_target() -> Node2D:
	for d in level.active_decoys():
		if absf(d.global_position.x - global_position.x) < sight * 1.4 and absf(d.global_position.y - global_position.y) < 140.0:
			return d
	var p := level.player
	if p != null and p.alive:
		var dx := p.global_position.x - global_position.x
		var close := absf(dx) < 120.0
		var in_front := signf(dx) == float(dir) or _alerted
		if absf(dx) < sight and absf(p.global_position.y - global_position.y) < 160.0 and (in_front or close):
			return p
	return null


func _check_spear() -> void:
	if _thrust_hit:
		return
	var x0 := global_position.x + (10.0 if dir > 0 else -SPEAR_REACH - 10.0)
	var spear := Rect2(Vector2(x0, global_position.y - 92.0), Vector2(SPEAR_REACH, 40.0))
	for d in level.active_decoys():
		if spear.intersects(d.hitbox()):
			_thrust_hit = true
			d.dispel()
			_enter(State.DAZED, daze_time)
			puppet.relax()
			Sfx.play("enemy_dazed", global_position)
			return
	var p := level.player
	if p != null and p.alive and spear.intersects(p.hitbox()):
		_thrust_hit = true
		if p.shield_time > 0.0:
			Sfx.play("kavach_block", p.global_position)
			Fx.burst(get_parent(), p.global_position + Vector2(0, -50), Color(1.0, 0.85, 0.5), 18, 220.0)
			_enter(State.DAZED, 1.4)
			puppet.relax()
		else:
			p.take_hit(global_position.x)


## amount: hit points. cause: "strike", "fire", ...
func damage(amount: int, from_x: float, cause: String) -> void:
	if _state == State.DEAD:
		return
	hp -= amount
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -dir
	puppet.hit(away)
	_pips.hp = hp
	_pips.max_hp = max_hp
	_pips.visible = true
	_pips.queue_redraw()
	if hp <= 0:
		_die(cause)
		return
	Sfx.play("enemy_hurt", global_position)
	_glint.visible = false
	puppet.relax()
	_knock = away * 300.0
	dir = -int(away)
	_alerted = true
	_enter(State.STAGGER, 0.4)


## JWALA and anything else that burns.
func burn() -> void:
	damage(max_hp, global_position.x - dir, "fire")


## TARANG: hurled away from the source and staggered.
func push(from: Vector2, force: float) -> void:
	if _state == State.DEAD:
		return
	var away := signf(global_position.x - from.x)
	_knock = away * force
	velocity.y = -force * 0.45
	_glint.visible = false
	puppet.relax()
	_enter(State.STAGGER, 0.7)


## BANDHAN: rooted in place, unable to strike.
func bind(duration: float) -> void:
	if _state == State.DEAD:
		return
	_glint.visible = false
	puppet.relax()
	puppet.set_bound(true)
	_roots.visible = true
	_enter(State.BOUND, duration)


func _enter(state: State, time: float) -> void:
	_state = state
	_t = time


func _die(cause: String) -> void:
	_state = State.DEAD
	collision_layer = 0
	remove_from_group("enemies")
	_glint.visible = false
	_pips.visible = false
	_roots.visible = false
	died.emit(global_position, cause)
	Game.track("fire_kills" if cause == "fire" else "strike_kills")
	if drop_prana > 0.0:
		var orb := PranaOrb.new()
		orb.amount = drop_prana
		orb.position = global_position + Vector2(0, -60)
		get_parent().call_deferred("add_child", orb)
	if cause == "fire":
		Sfx.play("enemy_burn", global_position)
		Fx.burst(get_parent(), global_position + Vector2(0, -55), Color(1.0, 0.5, 0.15), 48, 320.0)
		Fx.burst(get_parent(), global_position + Vector2(0, -55), Color(0.15, 0.1, 0.1, 0.8), 20, 120.0, false, 1.2)
		var t := create_tween()
		t.tween_property(puppet, "modulate", Color(1.0, 0.4, 0.1, 0.0), 0.45)
		t.tween_callback(queue_free)
	else:
		Sfx.play("enemy_hurt", global_position, 2.0, 0.8)
		puppet.shatter(get_parent(), global_position.y)
		get_tree().create_timer(2.0, false).timeout.connect(queue_free)


func _make_roots() -> Node2D:
	var root := Node2D.new()
	root.visible = false
	root.z_index = 44
	for i in 7:
		var vine := Line2D.new()
		var x := randf_range(-26, 26)
		var pts := PackedVector2Array()
		for k in 6:
			pts.append(Vector2(x + sin(k * 1.7 + i) * 7.0, -k * 16.0))
		vine.points = pts
		vine.width = 3.0
		vine.default_color = Color(0.7, 1.0, 0.6, 0.9)
		vine.material = Fx.additive()
		root.add_child(vine)
	root.add_child(Fx.glow(Color(0.5, 1.0, 0.5, 0.3), 70.0))
	return root


## Health shown as small lamps over the head once the guard has been hurt.
class Pips extends Node2D:
	var hp := 3
	var max_hp := 3

	func _draw() -> void:
		for i in max_hp:
			var x := (i - (max_hp - 1) / 2.0) * 13.0
			draw_circle(Vector2(x, 0), 4.5, Color(0.1, 0.03, 0.03, 0.9))
			if i < hp:
				draw_circle(Vector2(x, 0), 3.2, Color(1.0, 0.4, 0.15))
