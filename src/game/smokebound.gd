class_name Smokebound
extends CharacterBody2D
## A soldier of the Smoke King. Patrols, chases what it sees, and prefers a maya
## decoy over the real hero. Touching a decoy leaves it dazed. JWALA burns it away.

signal burned(at: Vector2)

const SIZE := Vector2(40, 100)
const LEASH := 120.0

var level: Level
var patrol_min := 0.0
var patrol_max := 0.0
var speed := 90.0
var chase_speed := 175.0
var sight := 380.0
var daze_time := 2.5
var dir := -1
var puppet: Puppet

var _dazed := 0.0
var _alive := true
var _daze_fx: Node2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("burnable")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y / 2.0)
	add_child(shape)
	var aura := Fx.glow(Color(0.9, 0.15, 0.1, 0.22), 90.0)
	aura.position = Vector2(0, -60)
	add_child(aura)
	puppet = Puppet.new()
	puppet.build("soldier")
	add_child(puppet)
	_daze_fx = Node2D.new()
	_daze_fx.position = Vector2(0, -135)
	_daze_fx.visible = false
	for i in 3:
		var m := Fx.glow(Color(0.5, 0.95, 1.0), 9.0)
		m.position = Vector2.from_angle(TAU * i / 3.0) * 16.0
		_daze_fx.add_child(m)
	add_child(_daze_fx)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	velocity.y = minf(velocity.y + 2300.0 * delta, 1300.0)
	var vx := 0.0
	if _dazed > 0.0:
		_dazed -= delta
	else:
		var target := _pick_target()
		if target == null:
			if global_position.x <= patrol_min:
				dir = 1
			elif global_position.x >= patrol_max:
				dir = -1
			vx = dir * speed
		else:
			var dx := target.global_position.x - global_position.x
			if absf(dx) > 6.0:
				dir = 1 if dx > 0.0 else -1
				vx = dir * chase_speed
			var lo := patrol_min - LEASH
			var hi := patrol_max + LEASH
			if (vx < 0.0 and global_position.x <= lo) or (vx > 0.0 and global_position.x >= hi):
				vx = 0.0
	velocity.x = vx
	move_and_slide()
	_check_contacts()


func _process(delta: float) -> void:
	puppet.face(dir)
	puppet.animate(delta, velocity.x / chase_speed, is_on_floor(), velocity.y)
	_daze_fx.visible = _dazed > 0.0
	_daze_fx.rotation += delta * 5.0


func _pick_target() -> Node2D:
	for d in level.active_decoys():
		if absf(d.global_position.x - global_position.x) < sight * 1.4 and absf(d.global_position.y - global_position.y) < 140.0:
			return d
	var p := level.player
	if p != null and p.alive:
		var dx := p.global_position.x - global_position.x
		var close := absf(dx) < 110.0
		var in_front := signf(dx) == float(dir)
		if absf(dx) < sight and absf(p.global_position.y - global_position.y) < 150.0 and (in_front or close):
			return p
	return null


func _check_contacts() -> void:
	var box := Rect2(global_position + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)
	for d in level.active_decoys():
		if box.intersects(d.hitbox()):
			d.dispel()
			_dazed = daze_time
			return
	if _dazed > 0.0:
		return
	var p := level.player
	if p != null and p.alive and box.intersects(p.hitbox()):
		if p.shield_time > 0.0:
			_dazed = 1.2
			Fx.burst(get_parent(), global_position + Vector2(0, -50), Color(1.0, 0.85, 0.5), 16, 200.0)
		else:
			p.take_hit(global_position.x)


func burn() -> void:
	if not _alive:
		return
	_alive = false
	collision_layer = 0
	remove_from_group("burnable")
	burned.emit(global_position)
	Fx.burst(get_parent(), global_position + Vector2(0, -55), Color(1.0, 0.5, 0.15), 48, 320.0)
	Fx.burst(get_parent(), global_position + Vector2(0, -55), Color(0.15, 0.1, 0.1, 0.8), 20, 120.0, false, 1.2)
	var t := create_tween()
	t.tween_property(self, "modulate", Color(1.0, 0.4, 0.1, 0.0), 0.45)
	t.tween_callback(queue_free)
