class_name BurnFx
extends RefCounted
## JWALA kills: the body flashes a flat crimson-orange, a fire-coloured edge eats up
## through the sprite (the actor shader's dissolve), flat flame tongues and sparks rise,
## and grey ash falls and settles in a small pile that fades after a few seconds.
## Flat colours and normal blending only: no glow, no bloom (owner's art rule).

const DISSOLVE := 1.2  # seconds for the fire edge to eat through the body
const ASH_HOLD := 3.0  # seconds the ash pile rests before fading
const EDGE := Color(1.0, 0.42, 0.14)
const FLASH := Color(0.95, 0.3, 0.16)
const CHARRED := Color(0.32, 0.06, 0.08)
const FLAME_OUT := Color(0.84, 0.13, 0.18)
const FLAME_IN := Color(0.98, 0.46, 0.2)
const ASH := Color(0.5, 0.48, 0.5)
const ASH_LIGHT := Color(0.74, 0.72, 0.74)


## ghost: the left-behind copy of the dying figure (feet at its origin), drawn by an
## actor-shader `mat`. height: on-screen height of the figure in px.
static func burn(into: Node, ghost: Node2D, mat: ShaderMaterial, height: float) -> void:
	var base := ghost.global_position
	var width := height * 0.36
	mat.set_shader_parameter("dissolve_edge", EDGE)
	var tw := ghost.create_tween()
	# Catches fire: a hard flat flash, then the body chars dark crimson as it burns.
	tw.tween_method(func(a: float) -> void: mat.set_shader_parameter("flash_color", Color(FLASH, a)), 0.0, 0.85, 0.1)
	tw.tween_method(func(c: Color) -> void: mat.set_shader_parameter("flash_color", c),
		Color(FLASH, 0.85), Color(CHARRED, 0.8), 0.6)
	tw.parallel().tween_method(func(v: float) -> void: mat.set_shader_parameter("dissolve", v), 0.0, 1.0, DISSOLVE).set_delay(0.05)
	tw.tween_callback(ghost.queue_free)
	# Flame tongues climb with the burning edge (it eats from the feet up).
	var flames := into.create_tween()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(base.x * 13.0)
	for i in 14:
		var k := float(i) / 13.0
		var at := base + Vector2(rng.randf_range(-width * 0.5, width * 0.5), -height * (0.08 + 0.8 * k))
		var size := rng.randf_range(14.0, 26.0) * (height / 110.0)
		flames.tween_callback(func() -> void: _flame(into, at, size))
		flames.tween_interval(DISSOLVE / 14.0)
	_sparks(into, base, width, height)
	_ash_fall(into, base, width, height)
	_ash_pile(into, base, width)


## One flat flame tongue that rises, shrinks and fades.
static func _flame(into: Node, at: Vector2, size: float) -> void:
	if not is_instance_valid(into) or not into.is_inside_tree():
		return
	var f := Node2D.new()
	f.position = at
	f.z_index = 31
	f.add_child(Fx.polygon(_tongue(size), FLAME_OUT))
	var inner := Fx.polygon(_tongue(size * 0.55), FLAME_IN)
	inner.position = Vector2(0, size * 0.12)
	f.add_child(inner)
	into.add_child(f)
	var t := f.create_tween().set_parallel()
	t.tween_property(f, "position:y", at.y - size * 2.4, 0.55).set_ease(Tween.EASE_OUT)
	t.tween_property(f, "scale", Vector2(0.4, 0.6), 0.55)
	t.tween_property(f, "modulate:a", 0.0, 0.55).set_delay(0.15)
	t.chain().tween_callback(f.queue_free)


## A teardrop pointing up, `size` px tall, base at the origin.
static func _tongue(size: float) -> PackedVector2Array:
	var w := size * 0.42
	return PackedVector2Array([
		Vector2(0, -size), Vector2(w * 0.5, -size * 0.55), Vector2(w, -size * 0.2),
		Vector2(w * 0.75, 0), Vector2(0, size * 0.12), Vector2(-w * 0.75, 0),
		Vector2(-w, -size * 0.2), Vector2(-w * 0.35, -size * 0.6)])


## Small flat square sparks drifting up while he burns.
static func _sparks(into: Node, base: Vector2, width: float, height: float) -> void:
	var p := CPUParticles2D.new()
	p.amount = 18
	p.lifetime = 0.8
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width * 0.5, height * 0.4)
	p.position = base + Vector2(0, -height * 0.45)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -80)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 120.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = FLAME_IN
	p.color_ramp = Fx.fade_ramp()
	p.z_index = 32
	into.add_child(p)
	p.emitting = true
	into.get_tree().create_timer(DISSOLVE, false).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false)
	into.get_tree().create_timer(DISSOLVE + 1.0, false).timeout.connect(p.queue_free)


## Flakes of grey ash dropping from the burning body to the ground.
static func _ash_fall(into: Node, base: Vector2, width: float, height: float) -> void:
	var p := CPUParticles2D.new()
	p.amount = 26
	p.lifetime = 0.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width * 0.45, height * 0.18)
	p.position = base + Vector2(0, -height * 0.28)
	p.direction = Vector2(0, 1)
	p.spread = 20.0
	p.gravity = Vector2(0, 380)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 40.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	p.color = ASH_LIGHT
	p.z_index = 32
	into.add_child(p)
	p.emitting = true
	into.get_tree().create_timer(DISSOLVE + 0.2, false).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false)
	into.get_tree().create_timer(DISSOLVE + 1.0, false).timeout.connect(p.queue_free)


## A low grey mound that builds up as he burns, rests, then fades away.
static func _ash_pile(into: Node, base: Vector2, width: float) -> void:
	var pile := Node2D.new()
	pile.position = base + Vector2(0, 2)
	pile.z_index = 6
	var half := width * 1.05
	var mound := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		mound.append(Vector2(-cos(a) * half, -sin(a) * 16.0 * (0.8 + 0.2 * sin(a * 5.0))))
	pile.add_child(Fx.polygon(mound, ASH))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(base.x)
	for i in 9:
		var fleck := Fx.polygon(Fx.ellipse(Vector2(rng.randf_range(-half * 0.7, half * 0.7), -rng.randf_range(3.0, 11.0)),
			Vector2(3.5, 2.2), 6), ASH_LIGHT)
		pile.add_child(fleck)
	pile.scale = Vector2(0.3, 0.0)
	into.add_child(pile)
	var t := pile.create_tween()
	t.tween_property(pile, "scale", Vector2.ONE, DISSOLVE).set_ease(Tween.EASE_OUT)
	t.tween_interval(ASH_HOLD)
	t.tween_property(pile, "modulate:a", 0.0, 1.0)
	t.tween_callback(pile.queue_free)
