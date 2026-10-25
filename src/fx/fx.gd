class_name Fx
extends RefCounted
## Shared visual helpers: palettes, glows, particles. Everything is generated in code,
## so the game ships with almost no image files and the APK stays small.

const INK := Color(0.035, 0.016, 0.024)

const PALETTES := {
	"ember": {
		"top": Color(0.07, 0.02, 0.07),
		"mid": Color(0.40, 0.07, 0.10),
		"horizon": Color(0.98, 0.50, 0.18),
		"sun": Color(1.0, 0.84, 0.52),
		"rim": Color(1.0, 0.58, 0.26),
		"far": Color(0.36, 0.10, 0.12),
		"middle": Color(0.18, 0.05, 0.07),
		"near": Color(0.085, 0.03, 0.04),
	},
	"marsh": {
		"top": Color(0.02, 0.03, 0.08),
		"mid": Color(0.08, 0.15, 0.27),
		"horizon": Color(0.42, 0.74, 0.82),
		"sun": Color(0.88, 0.95, 1.0),
		"rim": Color(0.55, 0.9, 1.0),
		"far": Color(0.11, 0.2, 0.3),
		"middle": Color(0.06, 0.11, 0.17),
		"near": Color(0.03, 0.05, 0.08),
	},
}

static var _glow: Texture2D
static var _additive: CanvasItemMaterial
static var _leather: Texture2D


## Faint fibre grain for puppet leather. Multiplied with each piece's colour so the
## translucent hide looks backlit and uneven instead of flat vector fill.
static func leather_texture() -> Texture2D:
	if _leather == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.frequency = 0.09
		noise.fractal_octaves = 3
		noise.seed = 7
		var img := noise.get_seamless_image(64, 64)
		img.convert(Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var v := 0.8 + img.get_pixel(x, y).r * 0.2
				img.set_pixel(x, y, Color(v, v * 0.97, v * 0.93))
		_leather = ImageTexture.create_from_image(img)
	return _leather


## Closed Catmull-Rom curve through the points: organic outlines from a few control points.
static func smooth(points: PackedVector2Array, steps: int = 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	for i in n:
		var p0 := points[(i - 1 + n) % n]
		var p1 := points[i]
		var p2 := points[(i + 1) % n]
		var p3 := points[(i + 2) % n]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	return out


static func palette(name: String) -> Dictionary:
	return PALETTES.get(name, PALETTES["ember"])


static func glow_texture() -> Texture2D:
	if _glow == null:
		var t := GradientTexture2D.new()
		t.gradient = gradient([Color(1, 1, 1, 1), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0)], [0.0, 0.3, 1.0])
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_glow = t
	return _glow


static func additive() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


static func gradient(colors: Array, offsets: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


## A soft additive light blob. radius is in pixels.
static func glow(color: Color, radius: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = glow_texture()
	s.material = additive()
	s.modulate = color
	s.scale = Vector2.ONE * (radius / 32.0)
	return s


static func fade_ramp() -> Gradient:
	return gradient([Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 1.0])


## One-shot spark/ash explosion that frees itself.
static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 24, speed: float = 220.0,
		additive_blend: bool = true, lifetime: float = 0.7) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	p.texture = glow_texture()
	if additive_blend:
		p.material = additive()
	p.spread = 180.0
	p.gravity = Vector2(0, 160)
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.damping_min = 40.0
	p.damping_max = 120.0
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.24
	p.color = color
	p.color_ramp = fade_ramp()
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(lifetime + 0.4, false).timeout.connect(p.queue_free)


## Drifting embers that fill the air around their emitter.
static func embers(extents: Vector2, amount: int = 40) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.texture = glow_texture()
	p.material = additive()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.direction = Vector2(0.35, -1.0)
	p.spread = 30.0
	p.gravity = Vector2(4, -10)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 42.0
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.13
	p.color = Color(1.0, 0.55, 0.22)
	p.color_ramp = gradient([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 0.8, 0.6, 0.6), Color(1, 1, 1, 0)], [0.0, 0.15, 0.6, 1.0])
	return p


## Slow dark smoke rising from a point (normal blending so it darkens).
static func smoke(extents: Vector2, color: Color = Color(0.12, 0.08, 0.09, 0.55), amount: int = 14) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 2.2
	p.preprocess = 2.0
	p.local_coords = false
	p.texture = glow_texture()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -25)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 30.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.8
	p.color = color
	p.color_ramp = gradient([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.3, 1.0])
	return p


## A wide strip that fades from transparent (top) to `color` (bottom).
static func vertical_fade(color: Color, top_left: Vector2, size: Vector2) -> Sprite2D:
	var t := GradientTexture2D.new()
	t.gradient = gradient([Color(color, 0.0), color], [0.0, 0.65])
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 128
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.position = top_left
	s.scale = Vector2(size.x / 4.0, size.y / 128.0)
	return s


## Closed outline for a polygon, used as the backlit "rim" on silhouettes.
static func outline(points: PackedVector2Array, color: Color, width: float = 1.5) -> Line2D:
	var l := Line2D.new()
	l.points = points
	l.closed = true
	l.width = width
	l.default_color = color
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.antialiased = true
	return l


static func polygon(points: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.antialiased = true
	return p


static func ellipse(center: Vector2, radius: Vector2, steps: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return pts
