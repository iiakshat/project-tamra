class_name LevelArt
extends RefCounted
## Procedural silhouettes for level geometry: carved rock with a backlit rim.


## Visual for a solid rect. Ground gets a jagged top and thorny tufts; thin ledges get
## a tapered underside so they read as floating rock, not boxes.
static func rock(rect: Rect2, is_ground: bool, rim: Color, rng: RandomNumberGenerator) -> Node2D:
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
