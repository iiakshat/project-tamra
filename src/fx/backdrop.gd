class_name Backdrop
extends Node2D
## Painted sky plus layered temple skylines at different parallax depths.
## Far layers take the sky's colour, near ones fade to ink: atmospheric perspective
## does most of the "high graphics" work for very little GPU.

const SKY_SHADER := preload("res://src/fx/sky.gdshader")

var colors: Dictionary
var sky_material: ShaderMaterial
var _layers: Array[Parallax2D] = []


func build(width: float, palette_name: String, seed_value: int, quality: String = "high") -> void:
	colors = Fx.palette(palette_name)
	_add_sky(quality)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Base lines sit just below where the playfield ground usually appears on screen,
	# so every layer peeks out above the rock the hero runs on.
	_add_layer(width, 0.12, 478.0, Vector2(200, 350), colors["far"], rng, false)
	_add_layer(width, 0.3, 500.0, Vector2(140, 270), colors["middle"], rng, false)
	_add_layer(width, 0.6, 530.0, Vector2(110, 220), colors["near"], rng, true)


## Big dark shapes that pass in front of the world. Cheap depth.
func build_foreground(width: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 99
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(1.35, 1.0)
	p.z_index = 40
	add_child(p)
	var x := 900.0
	while x < width * 1.35 + 1500.0:
		var h := rng.randf_range(140, 250)
		var w := rng.randf_range(140, 300)
		var pts := PackedVector2Array([Vector2(x, 900)])
		var steps := 9
		for i in steps + 1:
			var t := float(i) / steps
			var y := 830.0 - sin(t * PI) * h + rng.randf_range(-14, 14)
			pts.append(Vector2(x + t * w, y))
		pts.append(Vector2(x + w, 900))
		p.add_child(Fx.polygon(pts, Fx.INK))
		for i in rng.randi_range(3, 7):
			var bx := x + rng.randf_range(0.1, 0.9) * w
			var blade := Line2D.new()
			blade.points = PackedVector2Array([Vector2(bx, 820), Vector2(bx + rng.randf_range(-30, 30), 820 - h - rng.randf_range(10, 60))])
			blade.width = rng.randf_range(3, 6)
			blade.width_curve = _taper()
			blade.default_color = Fx.INK
			p.add_child(blade)
		x += w + rng.randf_range(1000, 1700)


func set_autoscroll(speed: float) -> void:
	for layer in _layers:
		layer.autoscroll = Vector2(speed * layer.scroll_scale.x, 0)


func _add_sky(quality: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky_material.set_shader_parameter("top_color", colors["top"])
	sky_material.set_shader_parameter("mid_color", colors["mid"])
	sky_material.set_shader_parameter("horizon_color", colors["horizon"])
	sky_material.set_shader_parameter("sun_color", colors["sun"])
	sky_material.set_shader_parameter("octaves", 4 if quality == "high" else 2)
	rect.material = sky_material
	layer.add_child(rect)
	add_child(layer)


func _add_layer(width: float, scroll: float, base_y: float, heights: Vector2, color: Color,
		rng: RandomNumberGenerator, with_trees: bool) -> void:
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(scroll, scroll * 0.3)
	add_child(p)
	_layers.append(p)
	var span := width * scroll + 2200.0
	_add_haze(p, span, base_y, color)
	var x := -300.0
	while x < span:
		var w := rng.randf_range(70, 160)
		var h := rng.randf_range(heights.x, heights.y)
		var roll := rng.randf()
		var pts: PackedVector2Array
		if roll < 0.55:
			pts = _spire(x, base_y, w, h, rng)
		elif roll < 0.8:
			pts = _dome(x, base_y, w * 1.3, h * 0.55)
			w *= 1.3
		else:
			pts = _ruin(x, base_y, w * 1.6, h * 0.45, rng)
			w *= 1.6
		p.add_child(Fx.polygon(pts, color))
		if with_trees and rng.randf() < 0.4:
			_tree(p, Vector2(x + w + 25, base_y + 2), rng.randf_range(90, 170), color, rng)
		x += w + rng.randf_range(-25, 110)
	var ground := PackedVector2Array([Vector2(-400, base_y - 1), Vector2(span + 400, base_y - 1),
		Vector2(span + 400, base_y + 1200), Vector2(-400, base_y + 1200)])
	p.add_child(Fx.polygon(ground, color))


## Soft band of light behind each layer: the glow of fires in the distance.
func _add_haze(p: Parallax2D, span: float, base_y: float, layer_color: Color) -> void:
	var t := GradientTexture2D.new()
	var hz: Color = colors["horizon"]
	hz.a = 0.22 if layer_color.v > 0.2 else 0.14
	t.gradient = Fx.gradient([Color(hz, 0.0), hz, Color(hz, 0.0)], [0.0, 0.7, 1.0])
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 128
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.position = Vector2(-400, base_y - 260)
	s.scale = Vector2((span + 800) / 4.0, 300.0 / 128.0)
	p.add_child(s)


## Curved temple tower with stepped tiers and a finial.
func _spire(x: float, base_y: float, w: float, h: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var left := PackedVector2Array()
	var wall_h := h * rng.randf_range(0.2, 0.32)
	var cx := x + w * 0.5
	left.append(Vector2(x, base_y))
	left.append(Vector2(x, base_y - wall_h))
	left.append(Vector2(x - w * 0.07, base_y - wall_h))
	left.append(Vector2(x - w * 0.07, base_y - wall_h - 7))
	var tiers := 8
	for i in tiers + 1:
		var t := float(i) / tiers
		var half := w * 0.5 * (1.0 - pow(t, 1.4) * 0.84)
		var y := base_y - wall_h - 7 - t * (h - wall_h)
		left.append(Vector2(cx - half - (4.0 if i % 2 == 0 else 0.0), y))
		left.append(Vector2(cx - half, y - 3))
	var top := base_y - h
	left.append(Vector2(cx - 5, top - 6))
	left.append(Vector2(cx - 2, top - 12))
	left.append(Vector2(cx, top - 26))
	var pts := left.duplicate()
	for i in range(left.size() - 2, -1, -1):
		pts.append(Vector2(2.0 * cx - left[i].x, left[i].y))
	return pts


func _dome(x: float, base_y: float, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(x, base_y), Vector2(x, base_y - h * 0.45)])
	var cx := x + w * 0.5
	for i in range(1, 16):
		var a := PI - PI * i / 16.0
		pts.append(Vector2(cx + cos(a) * w * 0.5, base_y - h * 0.45 - sin(a) * h * 0.55))
		if i == 8:
			pts.append(Vector2(cx - 3, base_y - h - 4))
			pts.append(Vector2(cx, base_y - h - 22))
			pts.append(Vector2(cx + 3, base_y - h - 4))
	pts.append(Vector2(x + w, base_y - h * 0.45))
	pts.append(Vector2(x + w, base_y))
	return pts


## Broken wall with crenellations and a collapsed arch.
func _ruin(x: float, base_y: float, w: float, h: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(x, base_y)])
	var cx := x
	while cx < x + w:
		var top := base_y - h * rng.randf_range(0.6, 1.0)
		var seg := rng.randf_range(10, 22)
		pts.append(Vector2(cx, top))
		pts.append(Vector2(cx + seg, top))
		pts.append(Vector2(cx + seg, top + rng.randf_range(4, 16)))
		cx += seg + rng.randf_range(2, 8)
	pts.append(Vector2(x + w, base_y))
	# arch opening cut into the base
	var ax := x + w * 0.4
	var aw := w * 0.2
	var ah := h * 0.45
	pts.append(Vector2(ax + aw, base_y))
	for i in range(0, 9):
		var a := PI * i / 8.0
		pts.append(Vector2(ax + aw * 0.5 + cos(a) * aw * 0.5, base_y - ah - sin(a) * aw * 0.45))
	pts.append(Vector2(ax, base_y))
	return pts


func _tree(parent: Node, root: Vector2, h: float, color: Color, rng: RandomNumberGenerator) -> void:
	_branch(parent, root, -PI / 2.0 + rng.randf_range(-0.15, 0.15), h * 0.42, 9.0, 4, color, rng)


func _branch(parent: Node, from: Vector2, angle: float, length: float, width: float, depth: int,
		color: Color, rng: RandomNumberGenerator) -> void:
	var to := from + Vector2.from_angle(angle) * length
	var l := Line2D.new()
	l.points = PackedVector2Array([from, to])
	l.width = width
	l.default_color = color
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(l)
	if depth <= 0:
		return
	for side in [-1.0, 1.0]:
		var spread: float = side * rng.randf_range(0.25, 0.6)
		_branch(parent, to, angle + spread, length * rng.randf_range(0.58, 0.78), width * 0.62, depth - 1, color, rng)


func _taper() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0.1))
	return c
