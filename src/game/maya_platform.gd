class_name MayaPlatform
extends StaticBody2D
## Illusions. "false" platforms look solid but are not; "hidden" ones are real but
## invisible and only solid while revealed. DRISHTI (sight) shows the truth for a while:
## real stones glow cyan, lies flicker red and fade.

var kind := "false"
var size := Vector2(160, 26)

var _shape: CollisionShape2D
var _visual: Node2D
var _aura: Line2D
var _revealed := false


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
	_visual = LevelArt.rock(Rect2(Vector2.ZERO, size), false, Color(0.55, 0.9, 1.0), rng)
	add_child(_visual)
	_aura = Line2D.new()
	_aura.points = PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x - 8, size.y + 14),
		Vector2(8, size.y + 14)])
	_aura.closed = true
	_aura.width = 3.0
	_aura.material = Fx.additive()
	_aura.default_color = Color(0.4, 1.0, 1.0) if kind == "hidden" else Color(1.0, 0.3, 0.25)
	_aura.visible = false
	add_child(_aura)
	set_revealed(false)


func _process(_delta: float) -> void:
	if _revealed and kind == "false":
		_aura.modulate.a = 0.4 + 0.6 * absf(sin(Time.get_ticks_msec() * 0.012))


func set_revealed(on: bool) -> void:
	_revealed = on
	_aura.visible = on
	if kind == "false":
		_visual.modulate = Color(1, 1, 1, 0.25) if on else Color.WHITE
	else:
		_shape.set_deferred("disabled", not on)
		_visual.modulate = Color(1, 1, 1, 1) if on else Color(1, 1, 1, 0)
