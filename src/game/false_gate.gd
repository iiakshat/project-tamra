class_name FalseGate
extends Area2D
## Maya: a doorway that looks exactly like the level's exit. Step into it and it
## blows apart as smoke while the Smoke King laughs; the real gate is elsewhere
## (often veiled, see GoalGate.veiled). Its tell: the light inside flickers instead of
## burning steady, and the doorway ripples every few seconds. DRISHTI shows it thin
## and red-edged.

var _door: Sprite2D
var _inner: Sprite2D
var _edge: Line2D
var _revealed := false
var _gone := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("maya")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 170)
	shape.shape = rect
	shape.position = Vector2(0, -85)
	add_child(shape)
	# The same light as the real gate (GoalGate), so only the tells give it away.
	_inner = Fx.glow(Color(0.7, 0.62, 1.0, 0.9), 120.0)
	_inner.position = Vector2(0, -90)
	_inner.z_index = -1
	add_child(_inner)
	_door = Props.standing("door", 240.0)
	_door.position.y = 6.0
	add_child(_door)
	_edge = Line2D.new()
	_edge.points = PackedVector2Array([Vector2(-60, 0), Vector2(-60, -200), Vector2(0, -250), Vector2(60, -200), Vector2(60, 0)])
	_edge.width = 3.0
	_edge.default_color = Color(1.0, 0.3, 0.28)
	_edge.visible = false
	add_child(_edge)
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	if _gone:
		return
	var ms := Time.get_ticks_msec()
	if _revealed:
		_edge.modulate.a = 0.45 + 0.55 * absf(sin(ms * 0.012))
		modulate.a = 0.35
		return
	modulate.a = 1.0
	# The tell: the light stutters, and the whole doorway ripples now and then.
	_inner.modulate.a = 0.9 if fmod(ms * 0.001, 0.9) > 0.12 else 0.25
	var t := fmod(ms * 0.001 + position.x * 0.0005, 3.0)
	var k := maxf(0.0, sin(t * PI / 0.5)) if t < 0.5 else 0.0
	_door.modulate.a = 1.0 - 0.4 * k


func set_revealed(on: bool) -> void:
	_revealed = on
	_edge.visible = on


func _on_body_entered(body: Node) -> void:
	if _gone or not body is Player:
		return
	_gone = true
	remove_from_group("maya")
	Sfx.play("smoke_laugh", global_position)
	Sfx.play("decoy_pop", global_position, 0.0, 0.6)
	Fx.burst(get_parent(), global_position + Vector2(0, -110), Color(0.3, 0.28, 0.34, 0.85), 40, 220.0, false, 1.2)
	GameLog.info("level", "false_gate", {"x": int(global_position.x)})
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)
