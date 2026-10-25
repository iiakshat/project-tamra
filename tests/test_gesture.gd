extends "res://tests/test_case.gd"

const SHAPES := ["circle", "triangle", "v", "caret", "bolt", "square"]


## Turns a canonical glyph into a finger-like stroke: dense points, optional
## rotation, scale and jitter.
func _stroke(points: PackedVector2Array, scale := 120.0, angle := 0.0, jitter := 0.0, seed_value := 1) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var offset := Vector2(500, 320)
	var out := PackedVector2Array()
	for i in range(points.size() - 1):
		var a := points[i] * scale
		var b := points[i + 1] * scale
		var steps := maxi(2, int(a.distance_to(b) / 6.0))
		for s in steps:
			var p := a.lerp(b, float(s) / steps).rotated(angle) + offset
			out.append(p + Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter)))
	out.append((points[points.size() - 1] * scale).rotated(angle) + offset)
	return out


func test_canonical_shapes_are_recognized() -> void:
	var r := GestureRecognizer.with_default_templates()
	for name in SHAPES:
		check_eq(r.recognize(_stroke(GlyphShapes.canonical(name))).get("name"), name, name)


func test_sloppy_shapes_are_recognized() -> void:
	var r := GestureRecognizer.with_default_templates()
	var seed_value := 1
	for name in SHAPES:
		for angle in [-0.15, 0.15]:
			for scale in [70.0, 160.0]:
				seed_value += 1
				var stroke := _stroke(GlyphShapes.canonical(name), scale, angle, 5.0, seed_value)
				check_eq(r.recognize(stroke).get("name"), name, "%s angle=%s scale=%s" % [name, angle, scale])


func test_circle_from_any_start_and_direction() -> void:
	var r := GestureRecognizer.with_default_templates()
	for start in [0.4, 1.9, 3.5, 5.2]:
		for dir in [1.0, -1.0]:
			var stroke := _stroke(GlyphShapes.circle(start, dir), 110.0, 0.0, 3.0)
			check_eq(r.recognize(stroke).get("name"), "circle", "start=%s dir=%s" % [start, dir])


func test_mirrored_and_reversed_shapes() -> void:
	var r := GestureRecognizer.with_default_templates()
	check_eq(r.recognize(_stroke(GlyphShapes.reversed(GlyphShapes.canonical("v")))).get("name"), "v", "v right-to-left")
	check_eq(r.recognize(_stroke(GlyphShapes.mirrored(GlyphShapes.canonical("bolt")))).get("name"), "bolt", "mirrored bolt")


func test_line_reports_direction() -> void:
	var r := GestureRecognizer.with_default_templates()
	var right := r.recognize(_stroke(GlyphShapes.canonical("line"), 150.0, 0.1, 4.0))
	check_eq(right.get("name"), "line", "right line")
	check_eq(right.get("direction"), 1, "right direction")
	var left := r.recognize(_stroke(GlyphShapes.reversed(GlyphShapes.canonical("line")), 150.0, -0.1, 4.0))
	check_eq(left.get("name"), "line", "left line")
	check_eq(left.get("direction"), -1, "left direction")


func test_taps_are_ignored() -> void:
	var r := GestureRecognizer.with_default_templates()
	var tap := r.recognize(PackedVector2Array([Vector2(10, 10), Vector2(14, 12)]))
	check_eq(tap.get("name"), "", "tap")
	check_eq(tap.get("score"), 0.0, "tap scores zero so it is not reported as a failed cast")


func test_lines_are_classified_by_angle() -> void:
	var r := GestureRecognizer.with_default_templates()
	check_eq(r.recognize(_stroke(GlyphShapes.canonical("line_up"), 120.0, 0.2, 3.0)).get("name"), "line_up", "upward stroke")
	check_eq(r.recognize(_stroke(GlyphShapes.canonical("line_down"), 120.0, -0.2, 3.0)).get("name"), "line_down", "downward stroke")
	# 30 degrees is still a bridge (a ramp), not a leap.
	var ramp := r.recognize(_stroke(GlyphShapes.canonical("line"), 150.0, -0.52, 3.0))
	check_eq(ramp.get("name"), "line", "sloped line is still a line")
	check(ramp.get("end").y < ramp.get("start").y, "endpoints are reported")


func test_v_and_caret_differ() -> void:
	var r := GestureRecognizer.with_default_templates()
	check_eq(r.recognize(_stroke(GlyphShapes.canonical("caret"))).get("name"), "caret", "caret")
	check_eq(r.recognize(_stroke(GlyphShapes.canonical("v"))).get("name"), "v", "v")


func test_near_misses_report_closest() -> void:
	var r := GestureRecognizer.with_default_templates()
	r.min_score = 0.99
	var res := r.recognize(_stroke(GlyphShapes.canonical("circle"), 110.0, 0.0, 6.0))
	check_eq(res.get("name"), "", "below threshold")
	check_eq(res.get("closest"), "circle", "but the closest guess is kept for feedback")
