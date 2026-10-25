class_name GlyphView
extends Control
## Draws a mantra's sign: a canonical glyph, or the player's own custom sign.
## With `animate` on, a bright point traces the stroke the way it should be drawn.

var glyph := "":
	set(value):
		glyph = value
		queue_redraw()
## Raw stroke of a custom sign (any coordinates); overrides `glyph` when set.
var custom: PackedVector2Array = PackedVector2Array():
	set(value):
		custom = value
		queue_redraw()
var color := UiKit.GOLD
var animate := false
var line_width := 4.0

var _t := 0.0


## Shows the sign that currently casts `mantra_id` (custom if the player made one).
func show_mantra(mantra_id: String) -> void:
	var strokes := Game.save.sign_strokes(mantra_id)
	custom = strokes[0] if not strokes.is_empty() else PackedVector2Array()
	glyph = str(Game.mantra_cfg.get(mantra_id, {}).get("gesture", ""))
	color = GameConfig.color(Game.mantra_cfg.get(mantra_id, {}).get("color", ""), UiKit.GOLD)


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
	if custom.is_empty() and GlyphShapes.LINES.has(glyph):
		_arrow(pts[pts.size() - 2], pts[pts.size() - 1], Color(color, 0.3 if animate else 0.9))
	if animate:
		var traced := _partial(pts, clampf(_t, 0.0, 1.0))
		if traced.size() >= 2:
			draw_polyline(traced, color, line_width + 1.5, true)
		draw_circle(traced[traced.size() - 1], line_width * 1.9, Color(1.0, 0.96, 0.85))


func _points() -> PackedVector2Array:
	var src := custom if not custom.is_empty() else GlyphShapes.canonical(glyph)
	var out := PackedVector2Array()
	if src.size() < 2:
		return out
	var box := Rect2(src[0], Vector2.ZERO)
	for p in src:
		box = box.expand(p)
	var half := maxf(maxf(box.size.x, box.size.y) / 2.0, 0.001)
	var r := minf(size.x, size.y) * 0.4
	for p in src:
		out.append(size / 2.0 + (p - box.get_center()) / half * r)
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
