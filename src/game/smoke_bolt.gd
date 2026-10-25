class_name SmokeBolt
extends Area2D
## An archer's bolt of smoke: slow enough to read, aimed where the hero was.
## A staff strike or KAVACH stops it; rock swallows it.

const SPEED := 280.0

var dir := Vector2.LEFT
var life := 3.5
var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 11.0
	shape.shape = c
	add_child(shape)
	add_child(Fx.glow(Color(0.9, 0.25, 0.45, 0.8), 30.0))
	add_child(Fx.glow(Color(0.2, 0.1, 0.15, 0.9), 12.0))
	var trail := Fx.smoke(Vector2(3, 3), Color(0.15, 0.08, 0.12, 0.6), 12)
	trail.lifetime = 0.6
	add_child(trail)
	add_to_group("bolts")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += dir * SPEED * delta
	life -= delta
	if life <= 0.0:
		pop()


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	if _is_ledge(body):
		return  # bolts pass through one-way ledges and stop at solid rock
	if body is Player:
		if body.shield_time > 0.0:
			Sfx.play("kavach_block", global_position)
		else:
			body.take_hit(global_position.x)
	pop()


func _is_ledge(body: Node) -> bool:
	for c in body.get_children():
		if c is CollisionShape2D and c.one_way_collision:
			return true
	return false


func pop() -> void:
	if _done:
		return
	_done = true
	Fx.burst(get_parent(), global_position, Color(0.6, 0.2, 0.35, 0.9), 12, 140.0, false, 0.5)
	queue_free()
