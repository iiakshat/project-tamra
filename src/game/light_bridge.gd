class_name LightBridge
extends StaticBody2D
## SETU: a temporary bridge of light along the line the player drew. It can slope,
## so it doubles as a ramp. Flickers in its last second as a warning.

var from := Vector2.ZERO
var to := Vector2(420, 0)
var life := 5.0
var color := Color(1.0, 0.76, 0.35)

var _visual: Node2D
var _length := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	position = from
	_length = from.distance_to(to)
	rotation = (to - from).angle()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(_length, 12)
	shape.shape = rect
	shape.position = Vector2(_length / 2.0, 6)
	add_child(shape)

	_visual = Node2D.new()
	add_child(_visual)
	var wide := Line2D.new()
	wide.points = PackedVector2Array([Vector2(0, 4), Vector2(_length, 4)])
	wide.width = 22.0
	wide.default_color = Color(color, 0.28)
	wide.material = Fx.additive()
	_visual.add_child(wide)
	var core := Line2D.new()
	core.points = wide.points
	core.width = 5.0
	core.default_color = Color(1.0, 0.92, 0.7)
	core.material = Fx.additive()
	_visual.add_child(core)
	var motes := CPUParticles2D.new()
	motes.amount = int(clampf(_length / 16.0, 8, 34))
	motes.lifetime = 1.2
	motes.texture = Fx.glow_texture()
	motes.material = Fx.additive()
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(_length / 2.0, 2)
	motes.position = Vector2(_length / 2.0, 4)
	motes.direction = Vector2(0, -1)
	motes.spread = 20.0
	motes.gravity = Vector2(0, -30)
	motes.initial_velocity_min = 10.0
	motes.initial_velocity_max = 40.0
	motes.scale_amount_min = 0.05
	motes.scale_amount_max = 0.12
	motes.color = color
	motes.color_ramp = Fx.fade_ramp()
	_visual.add_child(motes)
	_visual.scale.x = 0.02
	create_tween().tween_property(_visual, "scale:x", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	life -= delta
	if life < 1.0:
		_visual.modulate.a = 0.35 + 0.65 * absf(sin(life * 20.0))
	if life <= 0.0:
		Fx.burst(get_parent(), from.lerp(to, 0.5), color, 30, 160.0)
		Sfx.play("bridge_fade", from.lerp(to, 0.5))
		queue_free()
