class_name GestureRecognizer
extends RefCounted
## Recognizes single-stroke gestures with the $1 Unistroke method (Wobbrock et al. 2007),
## kept orientation-sensitive so a V and an upside-down V stay different.
## Straight lines are detected separately, because $1 handles 1-D shapes poorly.

const SAMPLES := 64
const SQUARE := 250.0
const ANGLE_RANGE := 0.4363  # 25 degrees of rotation tolerance
const ANGLE_STEP := 0.0349   # 2 degrees
const PHI := 0.6180339887

var min_score := 0.78
var min_size := 40.0  # pixels; smaller strokes are taps, not gestures

var _templates: Array[Dictionary] = []


static func with_default_templates() -> GestureRecognizer:
	var r := GestureRecognizer.new()
	for name in ["circle", "triangle", "v", "bolt"]:
		for pts in GlyphShapes.variants(name):
			r.add_template(name, pts)
	return r


func add_template(name: String, points: PackedVector2Array) -> void:
	_templates.append({"name": name, "points": _normalize(points)})


## Returns {"name": String, "score": float, "direction": int}.
## name is "" when nothing matched. direction is only set for lines (+1 right, -1 left).
func recognize(stroke: PackedVector2Array) -> Dictionary:
	var result := {"name": "", "score": 0.0, "direction": 0}
	if stroke.size() < 2:
		return result
	var box := _bounds(stroke)
	var longest := maxf(box.size.x, box.size.y)
	if longest < min_size:
		return result
	var line_dir := _line_direction(stroke, box)
	if line_dir != 0:
		return {"name": "line", "score": 1.0, "direction": line_dir}
	if minf(box.size.x, box.size.y) < longest * 0.2:
		return result  # Too thin to be a 2-D shape (e.g. a vertical line).
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
	if score >= min_score:
		result["name"] = best_name
	return result


func _line_direction(stroke: PackedVector2Array, box: Rect2) -> int:
	if box.size.y > box.size.x * 0.25:
		return 0
	var first := stroke[0]
	var last := stroke[stroke.size() - 1]
	if first.distance_to(last) < _path_length(stroke) * 0.8:
		return 0  # Doubled back on itself; not a clean line.
	return 1 if last.x > first.x else -1


func _normalize(points: PackedVector2Array) -> PackedVector2Array:
	var pts := _resample(points, SAMPLES)
	var box := _bounds(pts)
	var w := maxf(box.size.x, 1.0)
	var h := maxf(box.size.y, 1.0)
	var centroid := Vector2.ZERO
	for i in pts.size():
		pts[i] = Vector2((pts[i].x - box.position.x) * SQUARE / w, (pts[i].y - box.position.y) * SQUARE / h)
		centroid += pts[i]
	centroid /= pts.size()
	for i in pts.size():
		pts[i] -= centroid
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
