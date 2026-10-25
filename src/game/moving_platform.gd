class_name MovingPlatform
extends AnimatableBody2D
## A one-way stone slab that glides between two points (and carries the hero), or, with
## `crumble` set, a ledge that shakes, falls half a second after being stood on, and
## grows back after a few seconds.

var size := Vector2(150, 26)
var travel := Vector2.ZERO
var period := 3.0
var crumble := false

var _origin := Vector2.ZERO
var _t := 0.0
var _shape: CollisionShape2D
var _visual: Node2D
var _crumble_t := -1.0
var _down_t := 0.0
var _sensor: Area2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_origin = position
	sync_to_physics = not crumble
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	_shape.one_way_collision = true
	add_child(_shape)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 3.0 + position.y)
	_visual = LevelArt.rock(Rect2(Vector2.ZERO, size), false, Color(0.75, 0.68, 1.0) if not crumble else Color(0.95, 0.4, 0.55), rng)
	add_child(_visual)
	if crumble:
		for i in 3:
			var crack := Line2D.new()
			var x := size.x * (0.25 + 0.25 * i)
			crack.points = PackedVector2Array([Vector2(x, 2), Vector2(x - 6, 12), Vector2(x + 4, 20)])
			crack.width = 1.6
			crack.default_color = Color(0.95, 0.4, 0.55, 0.8)
			_visual.add_child(crack)
		_sensor = Area2D.new()
		_sensor.collision_layer = 0
		_sensor.collision_mask = 2
		var s := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(size.x - 8, 10)
		s.shape = r
		s.position = Vector2(size.x / 2.0, -6)
		_sensor.add_child(s)
		add_child(_sensor)
		_sensor.body_entered.connect(_on_stood)


func _physics_process(delta: float) -> void:
	if crumble:
		_update_crumble(delta)
		return
	_t += delta
	var k := 0.5 - 0.5 * cos(TAU * _t / maxf(period, 0.5))
	position = _origin + travel * k


func _on_stood(body: Node) -> void:
	if body is Player and _crumble_t < 0.0 and _down_t <= 0.0:
		_crumble_t = 0.5
		Sfx.play("enemy_windup", global_position, -4.0, 1.4)


func _update_crumble(delta: float) -> void:
	if _crumble_t >= 0.0:
		_crumble_t -= delta
		_visual.position = Vector2(randf_range(-2, 2), randf_range(-1, 1))
		if _crumble_t < 0.0:
			_down_t = 3.0
			_shape.set_deferred("disabled", true)
			Fx.burst(get_parent(), global_position + size / 2.0, Color(0.3, 0.22, 0.25, 0.9), 16, 180.0, false, 0.8)
			Sfx.play("land_heavy", global_position, -6.0, 1.2)
			var t := create_tween()
			t.tween_property(_visual, "position:y", 220.0, 0.6).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(_visual, "modulate:a", 0.0, 0.6)
	elif _down_t > 0.0:
		_down_t -= delta
		if _down_t <= 0.0:
			_shape.set_deferred("disabled", false)
			_visual.position = Vector2.ZERO
			create_tween().tween_property(_visual, "modulate:a", 1.0, 0.4)
