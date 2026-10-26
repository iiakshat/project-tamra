class_name PhantomWall
extends Node2D
## Maya: a rock wall that is not there. It looks like a solid cliff or pillar but has
## no body, so the hero walks straight through. It hides secret alcoves, the real
## path past a "dead end", and sometimes a drop. A fair tell: every few seconds it
## ripples like heat haze. DRISHTI shows it as a lie (thin, red-edged). Once walked
## through, it stays thin: the lie is broken. Origin: bottom-left corner.

const WIDTH := 110.0

var height := 240.0
var width := WIDTH

var _visual: Node2D
var _edge: Line2D
var _revealed := false
var _broken := false
var _area: Area2D


func _ready() -> void:
	add_to_group("maya")
	z_index = 4  # in front of the hero: he is hidden while inside it
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 3.0 + position.y)
	_visual = LevelArt.rock(Rect2(0, -height, width, height + 40.0), true, Color(0.55, 0.9, 1.0), rng)
	add_child(_visual)
	_edge = Line2D.new()
	_edge.points = PackedVector2Array([Vector2(0, 0), Vector2(0, -height), Vector2(width, -height), Vector2(width, 0)])
	_edge.width = 3.0
	_edge.default_color = Color(1.0, 0.3, 0.28)
	_edge.visible = false
	add_child(_edge)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	shape.position = Vector2(width / 2.0, -height / 2.0)
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	if _revealed:
		_edge.modulate.a = 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.012))
		_visual.modulate.a = 0.22
		return
	if _broken:
		_visual.modulate.a = 0.4
		return
	# The tell: a ripple every ~3 s (dims and shivers sideways for half a second).
	var t := fmod(Time.get_ticks_msec() * 0.001 + position.x * 0.0005, 3.0)
	var k := maxf(0.0, sin(t * PI / 0.5)) if t < 0.5 else 0.0
	_visual.modulate.a = 1.0 - 0.45 * k
	_visual.position.x = sin(Time.get_ticks_msec() * 0.06) * 3.0 * k


func set_revealed(on: bool) -> void:
	_revealed = on
	_edge.visible = on
	if not on:
		_visual.modulate.a = 1.0


func _on_body_entered(body: Node) -> void:
	if not body is Player or _broken:
		return
	_broken = true
	Sfx.play("decoy_pop", body.global_position, -4.0, 0.6)
	Fx.burst(get_parent(), body.global_position + Vector2(0, -50), Color(0.55, 0.9, 1.0, 0.7), 16, 140.0, false, 0.6)
	GameLog.info("level", "phantom_wall", {"x": int(position.x)})
