class_name Checkpoint
extends Area2D
## A cold lamp on a pole. Lights up when the hero passes and becomes the respawn point.

signal reached(at: Vector2)

var lit := false

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
	add_child(Fx.polygon(PackedVector2Array([Vector2(-2.5, 0), Vector2(2.5, 0), Vector2(1.5, -78), Vector2(-1.5, -78)]), Fx.INK))
	var bowl := PackedVector2Array([Vector2(-13, -80), Vector2(13, -80), Vector2(8, -72), Vector2(-8, -72)])
	add_child(Fx.polygon(bowl, Fx.INK))
	add_child(Fx.outline(bowl, Color(1.0, 0.6, 0.3, 0.5), 1.2))
	_flame = Node2D.new()
	_flame.position = Vector2(0, -86)
	_flame.add_child(Fx.glow(Color(1.0, 0.55, 0.2, 0.7), 60.0))
	_flame.add_child(Fx.polygon(PackedVector2Array([Vector2(-5, 4), Vector2(0, -14), Vector2(5, 4)]), Color(1.0, 0.85, 0.5)))
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
	_flame.scale = Vector2.ZERO
	Fx.burst(get_parent(), global_position + Vector2(0, -86), Color(1.0, 0.7, 0.3), 20, 160.0)
	Sfx.play("checkpoint", global_position)
	reached.emit(global_position)
