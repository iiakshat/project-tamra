class_name GestureRecognizer
extends RefCounted
## Recognizes single-stroke gestures with the $1 Unistroke method (Wobbrock et al. 2007),
## kept orientation-sensitive so a V and a caret (^) stay different.
## Straight strokes are classified separately (line / line_up / line_down) because $1
## handles 1-D shapes poorly, and because SETU needs the stroke's actual endpoints.

const SAMPLES := 64
const SQUARE := 250.0
const ANGLE_RANGE := 0.4363  # 25 degrees of rotation tolerance
const ANGLE_STEP := 0.0349   # 2 degrees
const PHI := 0.6180339887
const HORIZONTAL_SLOPE := 0.84  # tan(40 deg): flatter than this is a "line"
const VERTICAL_SLOPE := 0.7     # tan(35 deg): steeper than this is line_up / line_down
const STRAIGHTNESS := 0.85      # chord / path length for a stroke to count as straight

var min_score := 0.72
var min_size := 40.0  # pixels; smaller strokes are taps, not gestures

var _templates: Array[Dictionary] = []


static func with_default_templates() -> GestureRecognizer:
	var r := GestureRecognizer.new()
	for name in GlyphShapes.SHAPES:
		r.add_shape(name)
	return r


func add_shape(name: String) -> void:
	for pts in GlyphShapes.variants(name):
		add_template(name, pts)


func add_template(name: String, points: PackedVector2Array) -> void:
	_templates.append({"name": name, "points": _normalize(points)})


func remove_templates(name: String) -> void:
	_templates = _templates.filter(func(t: Dictionary) -> bool: return t["name"] != name)


func has_templates(name: String) -> bool:
	return _templates.any(func(t: Dictionary) -> bool: return t["name"] == name)


## Returns {"name", "score", "direction", "start", "end", "closest"}.
## name is "" when nothing matched; "closest" is the best guess even then (for feedback).
## direction (+1 right / -1 left) and start/end are set for straight strokes.
func recognize(stroke: PackedVector2Array) -> Dictionary:
	var result := {"name": "", "score": 0.0, "direction": 0, "start": Vector2.ZERO, "end": Vector2.ZERO, "closest": ""}
	if stroke.size() < 2:
		return result
	var box := _bounds(stroke)
	var longest := maxf(box.size.x, box.size.y)
	if longest < min_size:
		return result
	var first := stroke[0]
	var last := stroke[stroke.size() - 1]
	result["start"] = first
	result["end"] = last
	var kind := _straight_kind(stroke)
	if kind != "":
		result["name"] = kind
		result["closest"] = kind
		result["score"] = 1.0
		result["direction"] = 1 if last.x >= first.x else -1
		return result
	var pts := _normalize(stroke)
	var best := INF
	var best_name := ""
	for t in _templates:
		var d := _distance_at_best_angle(pts, t["points"])
		if d < best:
			best = d
			best_name = t["name"]
	var score := 1.0 - best / (0.5 * sqrt(2.0 * SQUARE * SQUARE))
	result["score"] = score
	result["closest"] = best_name
	if score >= min_score:
		result["name"] = best_name
	return result


## "line", "line_up", "line_down" for a straight stroke at a usable angle, else "".
static func _straight_kind(stroke: PackedVector2Array) -> String:
	var first := stroke[0]
	var last := stroke[stroke.size() - 1]
	var d := last - first
	if d.length() < _path_length(stroke) * STRAIGHTNESS:
		return ""
	if absf(d.y) <= absf(d.x) * HORIZONTAL_SLOPE:
		return "line"
	if absf(d.x) <= absf(d.y) * VERTICAL_SLOPE:
		return "line_up" if d.y < 0.0 else "line_down"
	return ""


static func is_straight(stroke: PackedVector2Array) -> bool:
	return stroke.size() >= 2 and _straight_kind(stroke) != ""


## Similarity of two raw strokes (0..1), using the same measure as recognition.
## Used to check that a player's custom sign is drawn consistently.
func similarity(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var d := _distance_at_best_angle(_normalize(a), _normalize(b))
	return 1.0 - d / (0.5 * sqrt(2.0 * SQUARE * SQUARE))


func _normalize(points: PackedVector2Array) -> PackedVector2Array:
	var pts := _resample(points, SAMPLES)
	var centroid := Vector2.ZERO
	for p in pts:
		centroid += p
	centroid /= pts.size()
	# Size by RMS distance from the centroid: uniform (a tilted square stays a square)
	# and rotation-independent (a bounding box grows when a shape tilts), so the
	# rotation search compares like with like.
	var sum_sq := 0.0
	for i in pts.size():
		pts[i] -= centroid
		sum_sq += pts[i].length_squared()
	var k := (SQUARE * 0.5) / maxf(sqrt(sum_sq / pts.size()), 0.001)
	for i in pts.size():
		pts[i] *= k
	return pts


func _resample(points: PackedVector2Array, n: int) -> PackedVector2Array:
	var interval := _path_length(points) / float(n - 1)
	var src := points.duplicate()
	var out := PackedVector2Array([src[0]])
	var acc := 0.0
	var i := 1
	while i < src.size():
		var d := src[i - 1].distance_to(src[i])
		if d > 0.0 and acc + d >= interval:
			var q := src[i - 1].lerp(src[i], (interval - acc) / d)
			out.append(q)
			src.insert(i, q)
			acc = 0.0
		else:
			acc += d
		i += 1
	while out.size() < n:
		out.append(points[points.size() - 1])
	out.resize(n)
	return out


func _distance_at_best_angle(pts: PackedVector2Array, tmpl: PackedVector2Array) -> float:
	var a := -ANGLE_RANGE
	var b := ANGLE_RANGE
	var x1 := PHI * a + (1.0 - PHI) * b
	var f1 := _distance_at_angle(pts, tmpl, x1)
	var x2 := (1.0 - PHI) * a + PHI * b
	var f2 := _distance_at_angle(pts, tmpl, x2)
	while absf(b - a) > ANGLE_STEP:
		if f1 < f2:
			b = x2
			x2 = x1
			f2 = f1
			x1 = PHI * a + (1.0 - PHI) * b
			f1 = _distance_at_angle(pts, tmpl, x1)
		else:
			a = x1
			x1 = x2
			f1 = f2
			x2 = (1.0 - PHI) * a + PHI * b
			f2 = _distance_at_angle(pts, tmpl, x2)
	return minf(f1, f2)


func _distance_at_angle(pts: PackedVector2Array, tmpl: PackedVector2Array, angle: float) -> float:
	var total := 0.0
	for i in pts.size():
		total += pts[i].rotated(angle).distance_to(tmpl[i])
	return total / pts.size()


static func _path_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


static func _bounds(points: PackedVector2Array) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	return box
