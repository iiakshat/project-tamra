class_name LevelArt
extends RefCounted
## Level geometry visuals. With painted chapter art (assets/env/<theme>_rock.png and
## _edge.png) ground is textured rock, lit at the top and sinking into shadow, crowned
## with a painted edge strip (ash crust, marsh moss, palace cornice). Without it, the
## older procedural silhouette with a backlit rim.

## Set by Backdrop.build() from the level's palette before geometry is built.
static var theme := ""
static var _cache := {}


static func _tex(kind: String) -> Texture2D:
	var path := "res://assets/env/%s_%s.png" % [theme, kind]
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func _painted(rect: Rect2, is_ground: bool, rng: RandomNumberGenerator, rock_tex: Texture2D) -> Node2D:
	var root := Node2D.new()
	var top := PackedVector2Array()
	var x := rect.position.x
	var right := rect.end.x
	while x < right:
		top.append(Vector2(x, rect.position.y + rng.randf_range(-2.0, 1.0)))
		x += rng.randf_range(30, 60)
	top.append(Vector2(right, rect.position.y))
	var body := top.duplicate()
	var colors := PackedColorArray()
	for i in top.size():
		colors.append(Color(1, 1, 1))
	if is_ground:
		var deep := minf(rect.size.y, 420.0)
		body.append(Vector2(right, rect.position.y + deep))
		body.append(Vector2(rect.position.x, rect.position.y + deep))
		colors.append(Color(0.08, 0.06, 0.1))
		colors.append(Color(0.08, 0.06, 0.1))
	else:
		var under := rect.position.y + rect.size.y
		var steps := 7
		for i in range(steps, -1, -1):
			var t := float(i) / steps
			var drop := sin(t * PI) * rng.randf_range(22, 40)
			body.append(Vector2(lerpf(rect.position.x + 4, right - 4, t), under + drop))
			colors.append(Color(0.35, 0.3, 0.38))
	var poly := Polygon2D.new()
	poly.polygon = body
	poly.vertex_colors = colors
	poly.texture = rock_tex
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	poly.texture_scale = Vector2(1.6, 1.6)
	poly.color = Color(0.85, 0.82, 0.9)
	root.add_child(poly)
	if is_ground:
		# Below the lit band the ground falls into solid shadow (cheap: no texture).
		var deep_y := rect.position.y + minf(rect.size.y, 420.0)
		if rect.end.y > deep_y:
			root.add_child(Fx.polygon(PackedVector2Array([Vector2(rect.position.x, deep_y - 1), Vector2(right, deep_y - 1),
				Vector2(right, rect.end.y), Vector2(rect.position.x, rect.end.y)]), Color(0.08, 0.06, 0.1).darkened(0.1)))
	var edge_tex := _tex("edge")
	if edge_tex != null:
		var edge := Line2D.new()
		var pts := PackedVector2Array()
		for pnt in top:
			pts.append(pnt + Vector2(0, 8))
		pts[0].x -= 10.0
		pts[pts.size() - 1].x += 10.0
		edge.points = pts
		edge.width = 44.0
		edge.texture = edge_tex
		edge.texture_mode = Line2D.LINE_TEXTURE_TILE
		edge.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		edge.joint_mode = Line2D.LINE_JOINT_ROUND
		edge.z_index = 1
		edge.default_color = Color(0.8, 0.76, 0.84)
		root.add_child(edge)
	return root


## Visual for a solid rect. Ground gets a jagged top and thorny tufts; thin ledges get
## a tapered underside so they read as floating rock, not boxes.
static func rock(rect: Rect2, is_ground: bool, rim: Color, rng: RandomNumberGenerator) -> Node2D:
	var rock_tex := _tex("rock")
	if rock_tex != null:
		return _painted(rect, is_ground, rng, rock_tex)
	var root := Node2D.new()
	var top := PackedVector2Array()
	var x := rect.position.x
	var right := rect.end.x
	while x < right:
		top.append(Vector2(x, rect.position.y + rng.randf_range(-3.0, 1.5)))
		x += rng.randf_range(14, 30)
	top.append(Vector2(right, rect.position.y + rng.randf_range(-3.0, 1.5)))

	var body := top.duplicate()
	if is_ground:
		body.append(Vector2(right, rect.end.y))
		body.append(Vector2(rect.position.x, rect.end.y))
	else:
		var under := rect.position.y + rect.size.y
		var steps := 7
		for i in range(steps, -1, -1):
			var t := float(i) / steps
			var drop := sin(t * PI) * rng.randf_range(16, 34)
			body.append(Vector2(lerpf(rect.position.x + 6, right - 6, t), under + drop))
	root.add_child(Fx.polygon(body, Fx.INK))

	var edge := Line2D.new()
	edge.points = top
	edge.width = 2.2
	edge.default_color = Color(rim, 0.6)
	edge.antialiased = true
	root.add_child(edge)

	if is_ground:
		var tufts := int(rect.size.x / 90.0)
		for i in tufts:
			if rng.randf() < 0.45:
				_tuft(root, Vector2(rng.randf_range(rect.position.x + 10, right - 10), rect.position.y), rng)
	return root


static func _tuft(parent: Node, at: Vector2, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(2, 4):
		var blade := Line2D.new()
		var lean := rng.randf_range(-9, 9)
		blade.points = PackedVector2Array([at + Vector2(i * 3 - 4, 2), at + Vector2(i * 3 - 4 + lean, -rng.randf_range(8, 18))])
		blade.width = 2.4
		blade.default_color = Fx.INK
		parent.add_child(blade)
