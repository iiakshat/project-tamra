class_name GlyphView
extends Control
## Draws a mantra gesture. With `animate` on, a bright point traces the stroke the
## way the player should draw it.

var glyph := "":
	set(value):
		glyph = value
		queue_redraw()
var color := UiKit.GOLD
var animate := false
var line_width := 4.0

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if animate and is_visible_in_tree():
		_t = fmod(_t + delta * 0.7, 1.5)
		queue_redraw()


func _draw() -> void:
	var pts := _points()
	if pts.size() < 2:
		return
	draw_polyline(pts, Color(color, 0.3 if animate else 0.9), line_width, true)
	if glyph == "line":
		_arrow(pts[pts.size() - 2], pts[pts.size() - 1], Color(color, 0.3 if animate else 0.9))
	if animate:
		var traced := _partial(pts, clampf(_t, 0.0, 1.0))
		if traced.size() >= 2:
			draw_polyline(traced, color, line_width + 1.5, true)
		draw_circle(traced[traced.size() - 1], line_width * 1.9, Color(1.0, 0.96, 0.85))


func _points() -> PackedVector2Array:
	var out := PackedVector2Array()
	var r := minf(size.x, size.y) * 0.4
	for p in GlyphShapes.canonical(glyph):
		out.append(size / 2.0 + p * r)
	return out


func _partial(pts: PackedVector2Array, t: float) -> PackedVector2Array:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var want := total * t
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if want <= seg:
			out.append(pts[i - 1].lerp(pts[i], want / maxf(seg, 0.001)))
			return out
		want -= seg
		out.append(pts[i])
	return out


func _arrow(from: Vector2, to: Vector2, c: Color) -> void:
	var d := (to - from).normalized()
	var n := Vector2(-d.y, d.x)
	var s := line_width * 3.0
	draw_colored_polygon(PackedVector2Array([to + d * s, to - d * s + n * s, to - d * s - n * s]), c)
