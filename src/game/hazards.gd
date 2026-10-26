class_name Hazards
extends RefCounted
## Builders for level hazards. Each returns a ready node; the level adds it to the world.


## A strip of thorns lying on a ground surface. Costs a heart and bounces the hero up.
static func spikes(x: float, top_y: float, width: float) -> Area2D:
	var a := HazardArea.new()
	a.position = Vector2(x, top_y)
	a.rect = Rect2(0, -18, width, 18)
	var pts := PackedVector2Array([Vector2(0, 2)])
	var n := int(width / 14.0)
	for i in n:
		pts.append(Vector2(i * 14.0 + 3.0, -2))
		pts.append(Vector2(i * 14.0 + 7.0, -18 - (i % 2) * 4))
		pts.append(Vector2(i * 14.0 + 11.0, -2))
	pts.append(Vector2(width, 2))
	var row := Props.strip("spikes", width, 28.0)
	if row.texture != null:
		row.position.y += 4.0
		a.add_child(row)
	else:
		a.add_child(Fx.polygon(pts, Fx.INK))
	return a


## A column of fire that rises from the ground on a rhythm, with a warning flicker.
static func jet(x: float, ground_y: float, interval: float, on_time: float, offset: float) -> Node2D:
	var j := FlameJet.new()
	j.position = Vector2(x, ground_y)
	j.interval = interval
	j.on_time = on_time
	j.offset = offset
	return j


## Damages the hero on touch, with a short grace period.
class HazardArea extends Area2D:
	var rect := Rect2()
	var active := true

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = rect.size
		shape.shape = r
		shape.position = rect.get_center()
		add_child(shape)

	func _physics_process(_delta: float) -> void:
		if not active:
			return
		for b in get_overlapping_bodies():
			if b is Player and b.alive:
				var was: int = b.hearts
				b.take_hit(b.global_position.x - b.facing * 10.0)
				if b.hearts < was:
					b.velocity.y = -720.0


class FlameJet extends Node2D:
	const HEIGHT := 220.0
	var interval := 3.0
	var on_time := 1.2
	var offset := 0.0
	var _area: HazardArea
	var _fire: CPUParticles2D
	var _warn: Sprite2D
	var _t := 0.0
	var _was_on := false

	func _ready() -> void:
		_t = offset
		var vent := Props.standing("vent", 30.0)
		vent.position.y = 6.0
		add_child(vent)
		_warn = Fx.glow(Color(1.0, 0.45, 0.2, 0.0), 30.0)
		_warn.position = Vector2(0, -8)
		add_child(_warn)
		_fire = CPUParticles2D.new()
		_fire.amount = 46
		_fire.lifetime = 0.55
		_fire.texture = Fx.glow_texture()
		_fire.material = Fx.additive()
		_fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_fire.emission_rect_extents = Vector2(10, 2)
		_fire.direction = Vector2(0, -1)
		_fire.spread = 6.0
		_fire.gravity = Vector2.ZERO
		_fire.initial_velocity_min = HEIGHT * 1.4
		_fire.initial_velocity_max = HEIGHT * 1.9
		_fire.scale_amount_min = 0.35
		_fire.scale_amount_max = 0.6
		_fire.color = Color(1.0, 0.5, 0.2)
		_fire.color_ramp = Fx.fade_ramp()
		_fire.emitting = false
		add_child(_fire)
		_area = HazardArea.new()
		_area.rect = Rect2(-20, -HEIGHT, 40, HEIGHT)
		_area.active = false
		add_child(_area)

	func _physics_process(delta: float) -> void:
		_t = fmod(_t + delta, interval)
		var on := _t < on_time
		var warning := not on and _t > interval - 0.6
		_warn.modulate.a = (0.4 + 0.4 * sin(_t * 30.0)) if warning else (0.8 if on else 0.0)
		_fire.emitting = on
		_area.active = on
		if on and not _was_on:
			Sfx.play("cast_jwala", global_position, -8.0, 0.8)
		_was_on = on
