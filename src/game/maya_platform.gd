class_name MayaPlatform
extends StaticBody2D
## Illusions. "false" platforms look solid but are not; "hidden" ones are real but
## invisible and only solid while revealed. DRISHTI (sight) shows the truth for a while.

var kind := "false"
var size := Vector2(160, 26)

var _shape: CollisionShape2D
var _visual: Node2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("maya")
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	_shape.one_way_collision = true
	_shape.disabled = true
	add_child(_shape)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 7.0 + position.y)
	_visual = LevelArt.rock(Rect2(Vector2.ZERO, size), false, Color(1.0, 0.58, 0.26), rng)
	add_child(_visual)
	set_revealed(false)


func set_revealed(on: bool) -> void:
	if kind == "false":
		_visual.modulate = Color(0.5, 0.95, 1.0, 0.3) if on else Color.WHITE
	else:
		_shape.set_deferred("disabled", not on)
		_visual.modulate = Color(0.6, 1.0, 1.0, 0.9) if on else Color(1, 1, 1, 0)
