class_name GoalGate
extends Area2D
## The ember gate at the end of a level: a pointed arch with fire burning inside.

signal reached

var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 170)
	shape.shape = rect
	shape.position = Vector2(0, -85)
	add_child(shape)

	var inner := Fx.glow(Color(1.0, 0.55, 0.2, 0.9), 120.0)
	inner.position = Vector2(0, -90)
	inner.z_index = -1
	add_child(inner)
	add_child(Fx.glow(Color(1.0, 0.85, 0.55, 0.6), 40.0))
	for side in [-1.0, 1.0]:
		var pillar := PackedVector2Array([Vector2(side * 52, 0), Vector2(side * 70, 0), Vector2(side * 66, -150), Vector2(side * 50, -150)])
		add_child(Fx.polygon(pillar, Fx.INK))
		add_child(Fx.outline(pillar, Color(1.0, 0.6, 0.3, 0.55), 1.5))
	var arch := Line2D.new()
	var pts := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		var x := lerpf(-60, 60, t)
		pts.append(Vector2(x, -150 - (1.0 - pow(absf(x) / 60.0, 1.6)) * 70.0))
	arch.points = pts
	arch.width = 18.0
	arch.default_color = Fx.INK
	add_child(arch)
	var finial := PackedVector2Array([Vector2(-6, -218), Vector2(0, -245), Vector2(6, -218)])
	add_child(Fx.polygon(finial, Fx.INK))

	var sparks := CPUParticles2D.new()
	sparks.amount = 30
	sparks.lifetime = 1.6
	sparks.texture = Fx.glow_texture()
	sparks.material = Fx.additive()
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(40, 60)
	sparks.position = Vector2(0, -80)
	sparks.direction = Vector2(0, -1)
	sparks.gravity = Vector2(0, -40)
	sparks.initial_velocity_min = 10.0
	sparks.initial_velocity_max = 50.0
	sparks.scale_amount_min = 0.06
	sparks.scale_amount_max = 0.16
	sparks.color = Color(1.0, 0.7, 0.3)
	sparks.color_ramp = Fx.fade_ramp()
	add_child(sparks)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _done or not body is Player:
		return
	_done = true
	Fx.burst(get_parent(), global_position + Vector2(0, -90), Color(1.0, 0.75, 0.35), 60, 360.0, true, 1.0)
	Sfx.play("goal", global_position)
	reached.emit()
