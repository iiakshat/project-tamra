class_name Spring
extends RefCounted
## A damped spring that chases a target. Gives motion weight: it overshoots a little
## and settles, instead of snapping. Used for lean, squash and stretch, and recoil.

var value := 0.0
var velocity := 0.0
var target := 0.0
var stiffness := 180.0
var damping := 14.0


func _init(k: float = 180.0, d: float = 14.0, start: float = 0.0) -> void:
	stiffness = k
	damping = d
	value = start
	target = start


func update(delta: float) -> float:
	# Sub-step so a long frame (or a 30 fps phone) cannot make the spring explode.
	var steps := maxi(1, ceili(delta / 0.008))
	var dt := delta / steps
	for i in steps:
		velocity += ((target - value) * stiffness - velocity * damping) * dt
		value += velocity * dt
	return value


func kick(impulse: float) -> void:
	velocity += impulse
