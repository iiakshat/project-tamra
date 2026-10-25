class_name GoalArrow
extends CanvasLayer
## A small arrow at the screen edge pointing toward the goal gate while it is off
## screen, so the player always knows which way to go.

## Screen margins: the top holds hearts and prana, the bottom corners the touch pads.
const MARGIN_SIDE := 44.0
const MARGIN_TOP := 120.0
const MARGIN_BOTTOM := 250.0

var goal := Vector2.ZERO

var _mark: Mark


func _ready() -> void:
	layer = 14  # under the touch pads (15) and the HUD (20)
	_mark = Mark.new()
	add_child(_mark)


func _process(_delta: float) -> void:
	var view := get_viewport().get_visible_rect()
	# Aim at the middle of the gate, not its feet.
	var p := get_viewport().get_canvas_transform() * (goal + Vector2(0, -90))
	var inner := Rect2(view.position + Vector2(MARGIN_SIDE, MARGIN_TOP),
		view.size - Vector2(MARGIN_SIDE * 2.0, MARGIN_TOP + MARGIN_BOTTOM))
	if view.grow(-20.0).has_point(p):
		_mark.visible = false
		return
	_mark.visible = true
	var c := inner.get_center()
	var d := p - c
	var half := inner.size / 2.0
	var k := 1.0
	if absf(d.x) > 0.001:
		k = minf(k, half.x / absf(d.x))
	if absf(d.y) > 0.001:
		k = minf(k, half.y / absf(d.y))
	_mark.position = c + d * k
	_mark.rotation = d.angle()
	_mark.modulate.a = 0.65 + 0.25 * sin(Time.get_ticks_msec() * 0.005)


class Mark extends Node2D:
	func _draw() -> void:
		var tip := PackedVector2Array([Vector2(22, 0), Vector2(-10, -16), Vector2(-3, 0), Vector2(-10, 16)])
		draw_circle(Vector2(2, 0), 26.0, Color(0.04, 0.02, 0.08, 0.45))
		draw_colored_polygon(tip, Color(0.88, 0.82, 1.0))
		draw_polyline(tip + PackedVector2Array([tip[0]]), Color(0.55, 0.45, 0.95), 2.0, true)
