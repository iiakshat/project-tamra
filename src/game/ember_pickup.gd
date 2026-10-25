class_name EmberPickup
extends Area2D
## A floating ember. Optional collectible that rewards exploring and replaying.

signal collected

var _glow: Node2D
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_t = position.x * 0.01
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	add_child(shape)
	_glow = Node2D.new()
	_glow.add_child(Fx.glow(Color(0.55, 0.88, 1.0, 0.85), 30.0))
	_glow.add_child(Fx.glow(Color(1.0, 0.9, 0.7), 8.0))
	add_child(_glow)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_glow.position.y = sin(_t * 2.4) * 5.0
	_glow.scale = Vector2.ONE * (1.0 + sin(_t * 5.0) * 0.1)


func _on_body_entered(body: Node) -> void:
	if not body is Player:
		return
	Fx.burst(get_parent(), global_position, Color(0.8, 0.95, 1.0), 18, 180.0)
	Sfx.play("ember_pickup", global_position)
	collected.emit()
	queue_free()
