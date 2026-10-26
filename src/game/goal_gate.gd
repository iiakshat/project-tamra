class_name GoalGate
extends Area2D
## The ember gate at the end of a level: a pointed arch with fire burning inside.

signal reached
## Maya levels: the gate is veiled (only a faint shimmer) until DRISHTI shows it or the
## hero comes close; once seen it stays seen.
signal unveiled

var veiled := false

var _done := false
var _inner: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 170)
	shape.shape = rect
	shape.position = Vector2(0, -85)
	add_child(shape)

	var inner := Fx.glow(Color(0.7, 0.62, 1.0, 0.9), 120.0)
	inner.position = Vector2(0, -90)
	inner.z_index = -1
	add_child(inner)
	_inner = inner
	add_child(Fx.glow(Color(0.95, 0.9, 1.0, 0.6), 40.0))
	# A carved temple doorway with light pouring from the arch: the way out.
	var door := Props.standing("door", 240.0)
	door.position.y = 6.0
	add_child(door)

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
	sparks.color = Color(0.85, 0.8, 1.0)
	sparks.color_ramp = Fx.fade_ramp()
	add_child(sparks)
	body_entered.connect(_on_body_entered)
	if veiled:
		add_to_group("maya")


func _process(_delta: float) -> void:
	if not veiled:
		return
	modulate.a = 0.08 + 0.05 * sin(Time.get_ticks_msec() * 0.006)
	var tree := get_tree()
	var p: Node2D = tree.get_first_node_in_group("hero") if tree != null else null
	if p != null and absf(p.global_position.x - global_position.x) < 160.0:
		set_revealed(true)


func set_revealed(on: bool) -> void:
	if not on or not veiled:
		return
	veiled = false
	modulate.a = 1.0
	remove_from_group("maya")
	Fx.burst(get_parent(), global_position + Vector2(0, -90), Color(0.6, 1.0, 0.85, 0.8), 30, 220.0, false, 0.8)
	Sfx.play("checkpoint", global_position, -4.0, 1.3)
	unveiled.emit()


func _on_body_entered(body: Node) -> void:
	if _done or not body is Player:
		return
	set_revealed(true)
	_done = true
	Fx.burst(get_parent(), global_position + Vector2(0, -90), Color(0.9, 0.85, 1.0), 60, 360.0, true, 1.0)
	Sfx.play("goal", global_position)
	reached.emit()


## The doorway swells with light and swallows the hero as he steps through.
func swallow() -> void:
	var light := Fx.glow(Color(0.92, 0.88, 1.0, 0.0), 150.0)
	light.position = Vector2(0, -90)
	light.z_index = 50
	add_child(light)
	var t := create_tween()
	t.tween_property(light, "modulate:a", 1.0, 0.35)
	t.parallel().tween_property(_inner, "scale", _inner.scale * 1.6, 0.35)
	t.tween_property(light, "modulate:a", 0.0, 0.6)
	Fx.burst(get_parent(), global_position + Vector2(0, -90), Color(0.9, 0.85, 1.0), 40, 260.0, true, 0.9)
