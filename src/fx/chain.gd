class_name Chain
extends Node2D
## A dangling strand (hair lock, sash end, tassel, earring) simulated with Verlet
## integration in world space. It trails behind movement, swings when the body stops
## and settles under gravity. Drawn as a tapered ribbon with a dark leather edge.

var anchor: Node2D
var anchor_offset := Vector2.ZERO
var segments := 6
var seg_len := 7.0
var gravity := 900.0
var damping := 0.94
var backward_pull := 220.0  # sweeps the strand behind the facing direction
var flutter := 0.0          # sideways noise, for cloth in wind
var width := 5.0
var color := Color(0.1, 0.05, 0.04)
var edge_color := Color(0.08, 0.02, 0.02)
var tip: Node2D             # optional ornament drawn at the end (earring gem, tassel)
var facing := 1

var _pts := PackedVector2Array()
var _prev := PackedVector2Array()
var _ribbon: Line2D
var _edge: Line2D
var _t := 0.0


func _ready() -> void:
	top_level = true  # points live in world space
	var taper := Curve.new()
	taper.add_point(Vector2(0, 1))
	taper.add_point(Vector2(1, 0.3))
	_edge = Line2D.new()
	_edge.width = width + 2.4
	_edge.width_curve = taper
	_edge.default_color = edge_color
	_edge.joint_mode = Line2D.LINE_JOINT_ROUND
	_edge.end_cap_mode = Line2D.LINE_CAP_ROUND
	_edge.antialiased = true
	add_child(_edge)
	_ribbon = Line2D.new()
	_ribbon.width = width
	_ribbon.width_curve = taper
	_ribbon.default_color = color
	_ribbon.joint_mode = Line2D.LINE_JOINT_ROUND
	_ribbon.end_cap_mode = Line2D.LINE_CAP_ROUND
	_ribbon.antialiased = true
	add_child(_ribbon)
	if tip != null:
		add_child(tip)
	reset()


## Snap the strand to its anchor, e.g. after a respawn teleport.
func reset() -> void:
	if anchor == null:
		return
	var a := anchor.to_global(anchor_offset)
	_pts.clear()
	_prev.clear()
	for i in segments + 1:
		var p := a + Vector2(-facing * seg_len * i * 0.5, seg_len * i * 0.8)
		_pts.append(p)
		_prev.append(p)


func _process(delta: float) -> void:
	if anchor == null or _pts.is_empty() or not anchor.is_visible_in_tree():
		visible = anchor != null and anchor.is_visible_in_tree()
		return
	visible = true
	_t += delta
	# Strands live in world space, so they must follow the figure's on-screen size
	# (the title screen draws the hero at 2x).
	var sf := absf(anchor.get_global_transform().get_scale().y)
	var length_now := seg_len * sf
	_ribbon.width = width * sf
	_edge.width = (width + 2.4) * sf
	var a := anchor.to_global(anchor_offset)
	if a.distance_to(_pts[0]) > 200.0 * sf:
		reset()
	_pts[0] = a
	_prev[0] = a
	var dt2 := minf(delta, 1.0 / 30.0)
	dt2 *= dt2
	var force := Vector2(-facing * backward_pull, gravity) * sf
	for i in range(1, _pts.size()):
		var p := _pts[i]
		var v := (p - _prev[i]) * damping
		_prev[i] = p
		var wobble := Vector2(0, sin(_t * 9.0 + i * 1.3) * flutter)
		_pts[i] = p + v + (force + wobble) * dt2
	for iteration in 3:
		for i in range(1, _pts.size()):
			var d := _pts[i] - _pts[i - 1]
			var length := d.length()
			if length > 0.0001:
				_pts[i] = _pts[i - 1] + d * (length_now / length)
	_edge.points = _pts
	_ribbon.points = _pts
	if tip != null:
		tip.position = _pts[_pts.size() - 1]
		tip.rotation = (_pts[_pts.size() - 1] - _pts[_pts.size() - 2]).angle() - PI / 2.0
