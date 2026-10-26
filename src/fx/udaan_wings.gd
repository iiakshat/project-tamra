class_name UdaanWings
extends Node2D
## UDAAN's look: two fans of pale flat feathers open behind the hero's shoulders.
## On the leap they beat down once with streaks of air under his feet; in the glide
## they stay spread, rippling, with a slow ring of light turning around his waist.
## Flat colours, normal blending: no glow, no bloom (owner's art rule).

const FEATHER := Color(0.86, 0.82, 1.0, 0.92)
const FEATHER_DARK := Color(0.6, 0.52, 0.92, 0.92)
const RING := Color(0.9, 0.86, 1.0, 0.85)

var spread := false

var _left: Node2D
var _right: Node2D
var _ring: Node2D
var _streaks: Array[Line2D] = []
var _mode := ""
var _t := 0.0
var _fade: Tween


func _ready() -> void:
	z_index = -1
	modulate.a = 0.0
	visible = false
	_right = _wing()
	add_child(_right)
	_left = _wing()
	_left.scale.x = -1.0
	add_child(_left)
	_ring = Node2D.new()
	_ring.position = Vector2(0, 22)
	_ring.z_index = 2
	for i in 3:
		var arc := Line2D.new()
		var pts := PackedVector2Array()
		for k in 9:
			var a := TAU * i / 3.0 + k * 0.12
			pts.append(Vector2(cos(a) * 46.0, sin(a) * 13.0))
		arc.points = pts
		arc.width = 3.0
		arc.default_color = RING
		arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
		arc.end_cap_mode = Line2D.LINE_CAP_ROUND
		_ring.add_child(arc)
	_ring.visible = false
	add_child(_ring)
	for i in 4:
		var s := Line2D.new()
		s.width = 2.5
		s.default_color = Color(FEATHER, 0.7)
		s.position = Vector2(-18 + i * 12, 70)
		s.points = PackedVector2Array([Vector2.ZERO, Vector2(0, 40)])
		add_child(s)
		_streaks.append(s)


## One fan of four leaf-shaped feathers, pointing outward (right) from the shoulder.
func _wing() -> Node2D:
	var w := Node2D.new()
	for i in 4:
		var length := 74.0 - i * 9.0
		var width := 11.0 - i * 1.2
		var leaf := PackedVector2Array([
			Vector2(0, 0), Vector2(length * 0.25, -width), Vector2(length * 0.75, -width * 0.8),
			Vector2(length, 0), Vector2(length * 0.7, width * 0.55), Vector2(length * 0.2, width * 0.5)])
		var f := Fx.polygon(leaf, FEATHER if i % 2 == 0 else FEATHER_DARK)
		f.rotation = deg_to_rad(-38.0 + i * 20.0)
		w.add_child(f)
	return w


## The leap: wings snap open high and beat down once.
func lift() -> void:
	_mode = "lift"
	_t = 0.0
	spread = false
	_show(true)


## The glide: wings held wide, rippling; the ring turns.
func glide() -> void:
	_mode = "glide"
	_t = 0.0
	spread = true
	_show(true)


func fold() -> void:
	if _mode == "":
		return
	_mode = ""
	spread = false
	_show(false)


func _show(on: bool) -> void:
	if _fade != null:
		_fade.kill()
	visible = true
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0 if on else 0.0, 0.12 if on else 0.3)
	if not on:
		_fade.tween_callback(func() -> void: visible = false)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var angle := 0.0
	var streak := 0.0
	match _mode:
		"lift":
			# High, then one strong downbeat over a third of a second.
			var k := clampf(_t / 0.32, 0.0, 1.0)
			angle = lerpf(-0.95, 0.35, k * k * (3.0 - 2.0 * k))
			streak = 1.0 - clampf(_t / 0.6, 0.0, 1.0)
		"glide":
			angle = -0.12 + 0.1 * sin(_t * 6.0)
			streak = 0.35
	_right.rotation = angle
	_left.rotation = -angle
	_ring.visible = _mode == "glide"
	if _ring.visible:
		# Arcs run around a flat ellipse (a ring seen from the side).
		for i in _ring.get_child_count():
			var arc := _ring.get_child(i) as Line2D
			var pts := PackedVector2Array()
			for k in 9:
				var a := TAU * i / 3.0 + k * 0.12 + _t * 3.2
				pts.append(Vector2(cos(a) * 46.0, sin(a) * 13.0))
			arc.points = pts
	for i in _streaks.size():
		var s := _streaks[i]
		s.visible = streak > 0.01
		var length := (36.0 + 18.0 * sin(_t * 20.0 + i * 1.7)) * streak
		s.points = PackedVector2Array([Vector2.ZERO, Vector2(0, length)])
