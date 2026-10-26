class_name HeartPickup
extends Area2D
## The only way to win back a heart: a crimson lotus-heart, at most one per level, set
## in a hard-to-reach optional spot (LifeRules). At full hearts it is left alone, so it
## can be saved for later. Flat shapes, no glow.

const COLOR := Color(0.9, 0.2, 0.32)
const PETAL := Color(1.0, 0.72, 0.78)

var _art: Node2D
var _t := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_t = position.x * 0.01
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape.shape = circle
	add_child(shape)
	_art = Node2D.new()
	# Three pale petals behind a solid heart, all flat.
	for a in [-0.7, 0.0, 0.7]:
		var petal := Fx.polygon(Fx.ellipse(Vector2(0, -16), Vector2(8, 17), 14), Color(PETAL, 0.85))
		petal.rotation = a
		petal.position = Vector2(0, 4)
		_art.add_child(petal)
	_art.add_child(Fx.polygon(_heart(20.0), Color(0.25, 0.02, 0.08)))
	_art.add_child(Fx.polygon(_heart(16.0), COLOR))
	add_child(_art)
	body_entered.connect(_on_body_entered)


## A heart outline of half-width r, centred on the origin.
static func _heart(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(Vector2(x, y) * (r / 16.0))
	return pts


func _process(delta: float) -> void:
	_t += delta
	_art.position.y = sin(_t * 2.2) * 5.0
	var beat := maxf(0.0, sin(_t * 5.0)) * 0.08
	_art.scale = Vector2.ONE * (1.0 + beat)


func _physics_process(_delta: float) -> void:
	# Also checked every frame: he may already be standing here when a heart is lost.
	if _taken:
		return
	for b in get_overlapping_bodies():
		_try(b)


func _on_body_entered(body: Node) -> void:
	_try(body)


func _try(body: Node) -> void:
	if _taken or not body is Player or not body.heal(1):
		return
	_taken = true
	Fx.burst(get_parent(), global_position, PETAL, 18, 160.0, false, 0.6)
	Sfx.play("heart_pickup", global_position)
	Services.analytics.log_event("heart_pickup", {"x": int(global_position.x),
		"level": body.level.level_id if body.level != null else ""})
	queue_free()
