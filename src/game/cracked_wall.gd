class_name CrackedWall
extends StaticBody2D
## Stone split by glowing cracks. Only TARANG's shockwave breaks it, and it usually
## hides something, so early levels reward coming back with new mantras.
## Origin is at its base.

var height := 200.0
var width := 46.0

var _broken := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("shatterable")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	shape.position = Vector2(0, -height / 2.0)
	add_child(shape)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x)
	var body := PackedVector2Array()
	var steps := 8
	for i in steps + 1:
		body.append(Vector2(-width / 2.0 + rng.randf_range(-3, 3), -height * i / steps))
	body.append(Vector2(width / 2.0, -height))
	for i in range(steps, -1, -1):
		body.append(Vector2(width / 2.0 + rng.randf_range(-3, 3), -height * i / steps))
	var art := Props.texture("wall")
	if art != null:
		# The painted wall is drawn lying down; stand it up to fill the wall's box.
		var w := Sprite2D.new()
		w.texture = art
		w.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		w.rotation = -PI / 2.0
		w.scale = Vector2(height / art.get_width(), (width + 14.0) / art.get_height())
		w.position = Vector2(0, -height / 2.0)
		add_child(w)
	else:
		add_child(Fx.polygon(body, Fx.INK))
	for i in (0 if art != null else 4):
		var crack := Line2D.new()
		var pts := PackedVector2Array()
		var y := -rng.randf_range(10, 40) - i * height / 4.5
		var x := rng.randf_range(-width / 2.0, -4)
		for k in 4:
			pts.append(Vector2(x, y))
			x += rng.randf_range(6, 14)
			y -= rng.randf_range(-14, 14)
		crack.points = pts
		crack.width = 2.0
		crack.default_color = Color(0.95, 0.35, 0.6, 0.9)
		crack.material = Fx.additive()
		add_child(crack)
	var hint := Fx.glow(Color(0.95, 0.35, 0.6, 0.25), 60.0)
	hint.position = Vector2(0, -height / 2.0)
	add_child(hint)


func shatter() -> void:
	if _broken:
		return
	_broken = true
	remove_from_group("shatterable")
	collision_layer = 0
	for i in 5:
		Fx.burst(get_parent(), global_position + Vector2(0, -height * (0.1 + 0.2 * i)), Color(0.3, 0.2, 0.18, 0.9), 14, 260.0, false, 0.9)
	Fx.burst(get_parent(), global_position + Vector2(0, -height / 2.0), Color(0.95, 0.5, 0.75), 30, 300.0)
	Sfx.play("land_heavy", global_position, 4.0, 0.7)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	t.tween_callback(queue_free)
