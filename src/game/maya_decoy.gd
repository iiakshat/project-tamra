class_name MayaDecoy
extends CharacterBody2D
## CHHAYA: a shadow-double of the hero that runs ahead. Guards chase it instead of you.

const SIZE := Vector2(30, 78)

var dir := 1
var speed := 240.0
var life := 4.0
var puppet: Puppet

var _gone := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	add_to_group("decoys")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y / 2.0)
	add_child(shape)
	var aura := Fx.glow(Color(0.35, 0.9, 1.0, 0.4), 80.0)
	aura.position = Vector2(0, -45)
	add_child(aura)
	puppet = Puppet.new()
	puppet.build("hero")
	puppet.modulate = Color(0.55, 0.95, 1.0, 0.6)
	puppet.face(dir)
	add_child(puppet)
	Fx.burst(get_parent(), global_position + Vector2(0, -40), Color(0.4, 0.9, 1.0), 24, 180.0)


func _physics_process(delta: float) -> void:
	if _gone:
		return
	life -= delta
	if life <= 0.0:
		dispel()
		return
	velocity.x = dir * speed
	velocity.y = minf(velocity.y + 2300.0 * delta, 1300.0)
	move_and_slide()
	if is_on_wall():
		velocity.x = 0.0


func _process(delta: float) -> void:
	if not _gone:
		puppet.animate(delta, 1.0, is_on_floor(), velocity.y)
		puppet.modulate.a = 0.45 + 0.15 * sin(life * 12.0)


func hitbox() -> Rect2:
	return Rect2(global_position + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


func dispel() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group("decoys")
	Fx.burst(get_parent(), global_position + Vector2(0, -40), Color(0.4, 0.9, 1.0), 30, 220.0)
	Sfx.play("decoy_pop", global_position)
	queue_free()
