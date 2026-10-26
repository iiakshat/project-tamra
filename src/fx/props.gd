class_name Props
extends RefCounted
## Painted level props (assets/props, cut from a Gemini sheet): spikes, fire vent,
## lamp shrine, exit doorway, stone slabs, cracked wall.

static var _cache := {}


static func texture(prop: String) -> Texture2D:
	var path := "res://assets/props/%s.png" % prop
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## A prop standing on the ground: bottom-centre at the node origin, `height` px tall.
static func standing(prop: String, height: float) -> Sprite2D:
	var tex := texture(prop)
	var s := Sprite2D.new()
	if tex == null:
		return s
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var k := height / float(tex.get_height())
	s.scale = Vector2(k, k)
	s.offset = Vector2(0, -tex.get_height() / 2.0)
	return s


## A prop stretched over a rect (top-left origin), e.g. a slab platform.
static func spanning(prop: String, size: Vector2) -> Sprite2D:
	var tex := texture(prop)
	var s := Sprite2D.new()
	if tex == null:
		return s
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.centered = false
	s.scale = Vector2(size.x / tex.get_width(), size.y / tex.get_height())
	return s


## A prop repeated sideways along a strip `width` px wide and `height` px tall,
## bottom-left at the node origin (rows of spikes).
static func strip(prop: String, width: float, height: float) -> Sprite2D:
	var tex := texture(prop)
	var s := Sprite2D.new()
	if tex == null:
		return s
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.centered = false
	var k := height / float(tex.get_height())
	s.scale = Vector2(k, k)
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, width / k, tex.get_height())
	s.position = Vector2(0, -height)
	return s
