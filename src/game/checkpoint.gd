class_name Checkpoint
extends Area2D
## A cold lamp on a pole. Lights up when the hero passes and becomes the respawn point.

signal reached(at: Vector2)

var lit := false

var _shrine: Sprite2D
var _flame: Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 180)
	shape.shape = rect
	shape.position = Vector2(0, -90)
	add_child(shape)
	# A stone lamp shrine: unlit until the hero reaches it, then its diya burns.
	_shrine = Props.standing("shrine_off", 74.0)
	add_child(_shrine)
	_flame = Node2D.new()
	_flame.position = Vector2(0, -80)
	_flame.add_child(Fx.glow(Color(1.0, 0.75, 0.4, 0.75), 70.0))
	_flame.visible = false
	add_child(_flame)
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	if lit:
		_flame.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.06)


func _on_body_entered(body: Node) -> void:
	if lit or not body is Player:
		return
	lit = true
	_flame.visible = true
	var on := Props.texture("shrine_on")
	if on != null:
		# The lit shrine art is taller (it includes the flame); keep the same scale.
		_shrine.texture = on
		_shrine.offset = Vector2(0, -on.get_height() / 2.0)
	_flame.scale = Vector2.ZERO
	Fx.burst(get_parent(), global_position + Vector2(0, -86), Color(0.6, 1.0, 0.9), 20, 160.0)
	Sfx.play("checkpoint", global_position)
	reached.emit(global_position)
