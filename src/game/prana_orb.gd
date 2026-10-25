class_name PranaOrb
extends Area2D
## A floating mote of prana. Refills the hero's energy for casting mantras.

var amount := 35.0

var _glow: Node2D
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_t = position.x * 0.013
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	add_child(shape)
	_glow = Node2D.new()
	_glow.add_child(Fx.glow(Color(0.4, 1.0, 0.8, 0.7), 34.0 * sqrt(amount / 35.0)))
	_glow.add_child(Fx.glow(Color(0.85, 1.0, 0.95), 9.0))
	var ring := Line2D.new()
	ring.points = Fx.ellipse(Vector2.ZERO, Vector2(13, 13), 20)
	ring.closed = true
	ring.width = 2.0
	ring.default_color = Color(0.5, 1.0, 0.85, 0.8)
	ring.material = Fx.additive()
	_glow.add_child(ring)
	add_child(_glow)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_glow.position.y = sin(_t * 2.0) * 6.0
	_glow.rotation += delta * 1.5


func _on_body_entered(body: Node) -> void:
	if not body is Player:
		return
	body.add_prana(amount)
	Fx.burst(get_parent(), global_position, Color(0.5, 1.0, 0.85), 16, 160.0)
	Sfx.play("ember_pickup", global_position, -2.0, 1.5)
	queue_free()
