class_name JwalaBolt
extends Area2D
## JWALA: a bolt of fire. Burns anything with a burn() method (guards, smoke-thorns)
## and fizzles on rock.

var dir := 1
var speed := 950.0
var max_range := 900.0
var color := Color(1.0, 0.48, 0.18)

var _travelled := 0.0
var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	add_child(Fx.glow(color, 46.0))
	add_child(Fx.glow(Color(1.0, 0.95, 0.8), 14.0))
	var trail := CPUParticles2D.new()
	trail.amount = 40
	trail.lifetime = 0.4
	trail.local_coords = false
	trail.texture = Fx.glow_texture()
	trail.material = Fx.additive()
	trail.spread = 25.0
	trail.direction = Vector2(-dir, 0)
	trail.gravity = Vector2(0, -60)
	trail.initial_velocity_min = 30.0
	trail.initial_velocity_max = 90.0
	trail.scale_amount_min = 0.12
	trail.scale_amount_max = 0.3
	trail.color = color
	trail.color_ramp = Fx.fade_ramp()
	add_child(trail)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	position.x += dir * step
	_travelled += step
	if _travelled > max_range:
		_fizzle()


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	if body.has_method("burn"):
		body.burn()
	_fizzle()


func _fizzle() -> void:
	if _done:
		return
	_done = true
	Fx.burst(get_parent(), global_position, color, 20, 240.0)
	Sfx.play("jwala_impact", global_position)
	queue_free()
