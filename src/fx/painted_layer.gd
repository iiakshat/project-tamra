class_name PaintedLayer
extends CanvasLayer
## One painted backdrop layer (assets/env), drawn in screen space and scrolled from the
## camera position: far layers drift slowly, nearer ones faster. The painting repeats
## sideways (the build step makes its ends meet) and is scaled to the screen height.

var texture: Texture2D
var scroll := 0.1        # fraction of camera x travel
var lift := 0.03         # fraction of camera y travel
var height_frac := 1.0   # painting height as a fraction of screen height
var bottom_frac := 1.0   # where the painting's bottom edge sits (fraction of screen height)
var tint := Color.WHITE
var drift := 0.0         # px/s of extra sideways motion (menus without a camera)

var _sprite: Sprite2D
var _base_y := INF
var _drifted := 0.0


func _ready() -> void:
	follow_viewport_enabled = false
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.modulate = tint
	add_child(_sprite)


func _process(delta: float) -> void:
	if texture == null:
		return
	_drifted += drift * delta
	var view := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	var at := cam.get_screen_center_position() if cam != null else Vector2.ZERO
	if _base_y == INF:
		_base_y = at.y
	var s := view.y * height_frac / float(texture.get_height())
	_sprite.scale = Vector2(s, s)
	var w := view.x / s + 2.0
	var x := fposmod((at.x * scroll + _drifted) / s, float(texture.get_width()))
	_sprite.region_rect = Rect2(x, 0, w, texture.get_height())
	var y := view.y * bottom_frac - texture.get_height() * s - (at.y - _base_y) * lift
	_sprite.position = Vector2(-1, y)
