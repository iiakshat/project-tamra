class_name SmokeBarrier
extends StaticBody2D
## A wall of smoke-thorns. Blocks the path until JWALA burns it. Origin is at its base.

var height := 220.0

var _shape: CollisionShape2D
var _burnt := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("burnable")
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(54, height)
	_shape.shape = rect
	_shape.position = Vector2(0, -height / 2.0)
	add_child(_shape)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x)
	for i in 7:
		var vine := Line2D.new()
		var pts := PackedVector2Array()
		var x := rng.randf_range(-22, 22)
		var y := 0.0
		while y > -height:
			pts.append(Vector2(x + rng.randf_range(-14, 14), y))
			y -= rng.randf_range(18, 34)
		vine.points = pts
		vine.width = rng.randf_range(4, 8)
		vine.default_color = Fx.INK
		add_child(vine)
		for p in pts:
			if rng.randf() < 0.6:
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				add_child(Fx.polygon(PackedVector2Array([p + Vector2(0, -3), p + Vector2(side * 14, -8), p + Vector2(0, 3)]), Fx.INK))
	for i in 5:
		var ember := Fx.glow(Color(0.9, 0.2, 0.1, 0.5), rng.randf_range(10, 18))
		ember.position = Vector2(rng.randf_range(-18, 18), -rng.randf_range(20, height - 20))
		add_child(ember)
	var smoke := Fx.smoke(Vector2(26, height / 2.0), Color(0.1, 0.07, 0.08, 0.5), 18)
	smoke.position = Vector2(0, -height / 2.0)
	add_child(smoke)


func burn() -> void:
	if _burnt:
		return
	_burnt = true
	remove_from_group("burnable")
	_shape.set_deferred("disabled", true)
	Sfx.play("barrier_burn", global_position)
	for i in 4:
		Fx.burst(get_parent(), global_position + Vector2(0, -height * (0.15 + 0.22 * i)), Color(1.0, 0.5, 0.15), 30, 280.0, true, 0.9)
	var t := create_tween()
	t.tween_property(self, "modulate", Color(1.0, 0.45, 0.1, 0.0), 0.6)
	t.tween_callback(queue_free)
