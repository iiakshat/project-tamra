class_name GlyphShapes
extends RefCounted
## Canonical mantra gestures in a -1..1 box, y pointing down (screen space).
## The recognizer's templates and the on-screen hints both come from here,
## so what players are shown is exactly what the recognizer expects.

## Straight strokes, classified by angle rather than by template.
const LINES := ["line", "line_up", "line_down"]
## Shapes matched by template.
const SHAPES := ["circle", "triangle", "v", "caret", "bolt", "square"]
const NAMES := ["line", "line_up", "line_down", "circle", "triangle", "v", "caret", "bolt", "square"]

const _TRIANGLE := [Vector2(0, -1), Vector2(0.9, 0.75), Vector2(-0.9, 0.75)]
const _SQUARE := [Vector2(-0.85, -0.85), Vector2(0.85, -0.85), Vector2(0.85, 0.85), Vector2(-0.85, 0.85)]


static func canonical(name: String) -> PackedVector2Array:
	match name:
		"line":
			return PackedVector2Array([Vector2(-1, 0), Vector2(1, 0)])
		"line_up":
			return PackedVector2Array([Vector2(0, 1), Vector2(0, -1)])
		"line_down":
			return PackedVector2Array([Vector2(0, -1), Vector2(0, 1)])
		"circle":
			return circle(-PI / 2.0, 1.0)
		"triangle":
			return _closed(_TRIANGLE, 0, 1)
		"square":
			return _closed(_SQUARE, 0, 1)
		"v":
			return PackedVector2Array([Vector2(-0.8, -1), Vector2(0, 1), Vector2(0.8, -1)])
		"caret":
			return PackedVector2Array([Vector2(-0.8, 1), Vector2(0, -1), Vector2(0.8, 1)])
		"bolt":
			return PackedVector2Array([Vector2(0.45, -1), Vector2(-0.4, 0.05), Vector2(0.4, -0.05), Vector2(-0.45, 1)])
	return PackedVector2Array()


## Every way a player plausibly draws the shape: other start points, other directions,
## mirrored. The recognizer is orientation-sensitive, so these must be listed.
static func variants(name: String) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	match name:
		"circle":
			for i in 8:
				var start := -PI / 2.0 + i * PI / 4.0
				out.append(circle(start, 1.0))
				out.append(circle(start, -1.0))
		"triangle":
			for first in 3:
				out.append(_closed(_TRIANGLE, first, 1))
				out.append(_closed(_TRIANGLE, first, -1))
		"square":
			for first in 4:
				out.append(_closed(_SQUARE, first, 1))
				out.append(_closed(_SQUARE, first, -1))
		"v", "caret":
			var c := canonical(name)
			out.append(c)
			out.append(reversed(c))
		"bolt":
			var c := canonical(name)
			var m := mirrored(c)
			out.append_array([c, reversed(c), m, reversed(m)])
	return out


static func circle(start: float, dir: float, steps: int = 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := start + dir * TAU * float(i) / steps
		pts.append(Vector2(cos(a), sin(a)))
	return pts


static func reversed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.reverse()
	return out


static func mirrored(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(-p.x, p.y))
	return out


## A closed polygon path starting at corner `first`, walking in direction `dir`.
static func _closed(corners: Array, first: int, dir: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := corners.size()
	for k in n + 1:
		pts.append(corners[posmod(first + dir * k, n)])
	return pts
