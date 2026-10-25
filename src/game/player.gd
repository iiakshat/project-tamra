class_name Player
extends CharacterBody2D
## The hero. Movement feel (coyote time, jump buffering, variable jump height) is
## tuned from config/player.json. Origin is at the feet.

signal died(cause: String)
signal hearts_changed(hearts: int, max_hearts: int)

const SIZE := Vector2(30, 78)

var cfg: Dictionary
var max_hearts := 3
var hearts := 3
var facing := 1
var alive := true
var controls_enabled := true
var shield_time := 0.0
var puppet: Puppet

var _invulnerable := 0.0
var _coyote := 0.0
var _buffer := 0.0
var _shield: Node2D


func setup(config: Dictionary, hearts_max: int) -> void:
	cfg = config
	max_hearts = hearts_max
	hearts = hearts_max


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 8.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y / 2.0)
	add_child(shape)
	# Warm aura so the black silhouette still reads against black rock.
	var aura := Fx.glow(Color(1.0, 0.5, 0.22, 0.32), 95.0)
	aura.position = Vector2(0, -48)
	add_child(aura)
	puppet = Puppet.new()
	puppet.build("hero")
	add_child(puppet)
	_shield = _make_shield()
	add_child(_shield)


func _num(key: String, fallback: float) -> float:
	return float(cfg.get(key, fallback))


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var dir := 0.0
	if controls_enabled:
		dir = Input.get_axis("move_left", "move_right")
	var accel: float
	if is_on_floor():
		accel = _num("ground_accel", 2600.0) if dir != 0.0 else _num("ground_decel", 3200.0)
	else:
		accel = _num("air_accel", 1900.0)
	velocity.x = move_toward(velocity.x, dir * _num("run_speed", 330.0), accel * delta)

	var gravity := _num("gravity", 2300.0)
	if velocity.y > 0.0:
		gravity *= _num("fall_gravity_mult", 1.4)
	velocity.y = minf(velocity.y + gravity * delta, _num("max_fall", 1300.0))

	if is_on_floor():
		_coyote = _num("coyote_time", 0.1)
	else:
		_coyote -= delta
	if controls_enabled and Input.is_action_just_pressed("jump"):
		_buffer = _num("jump_buffer", 0.12)
	else:
		_buffer -= delta
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -_num("jump_velocity", 860.0)
		_buffer = 0.0
		_coyote = 0.0
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= _num("jump_cut", 0.45)

	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
	move_and_slide()
	_invulnerable = maxf(0.0, _invulnerable - delta)
	shield_time = maxf(0.0, shield_time - delta)


func _process(delta: float) -> void:
	puppet.face(facing)
	puppet.animate(delta, velocity.x / _num("run_speed", 330.0), is_on_floor(), velocity.y)
	_shield.visible = shield_time > 0.0
	_shield.rotation += delta * 2.5
	if alive:
		var blink := _invulnerable > 0.0 and fmod(_invulnerable, 0.16) < 0.08
		puppet.modulate.a = 0.4 if blink else 1.0


func hitbox() -> Rect2:
	return Rect2(global_position + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


func take_hit(from_x: float) -> void:
	if not alive or _invulnerable > 0.0 or shield_time > 0.0:
		return
	hearts -= 1
	hearts_changed.emit(hearts, max_hearts)
	_invulnerable = _num("invulnerable_after_hit", 1.2)
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 380.0, -420.0)
	puppet.flash(Color(1.0, 0.35, 0.25))
	Game.vibrate(70)
	if hearts <= 0:
		die("hit")


func die(cause: String) -> void:
	if not alive:
		return
	alive = false
	velocity = Vector2.ZERO
	Fx.burst(get_parent(), global_position + Vector2(0, -40), Color(1.0, 0.45, 0.2), 36, 260.0)
	create_tween().tween_property(puppet, "modulate:a", 0.0, 0.25)
	Game.vibrate(120)
	died.emit(cause)


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	hearts = max_hearts
	alive = true
	shield_time = 0.0
	_invulnerable = 1.0
	puppet.modulate = Color.WHITE
	hearts_changed.emit(hearts, max_hearts)


func _make_shield() -> Node2D:
	var root := Node2D.new()
	root.position = Vector2(0, -42)
	root.visible = false
	var ring := Line2D.new()
	ring.points = Fx.ellipse(Vector2.ZERO, Vector2(56, 56), 32)
	ring.closed = true
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.86, 0.5, 0.85)
	ring.material = Fx.additive()
	root.add_child(ring)
	root.add_child(Fx.glow(Color(1.0, 0.8, 0.45, 0.25), 70.0))
	for i in 6:
		var mote := Fx.glow(Color(1.0, 0.9, 0.6), 7.0)
		mote.position = Vector2.from_angle(TAU * i / 6.0) * 56.0
		root.add_child(mote)
	return root
