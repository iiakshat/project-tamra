class_name IntroCurtain
extends CanvasLayer
## The first screen at launch: dark storm clouds fill the screen and Tamra runs in place
## over a thin loading line. When loading is done the clouds burst away in every
## direction with a gust of wind and `opened` fires, so the title screen can pull back
## from Tamra to the full view. Flat 2D shapes only (owner art rule).

signal opened

const RUN_PNG := "res://assets/chars/hero/run.png"
const MIN_TIME := 1.1

var _clouds: Array[Node2D] = []
var _runner: TextureRect
var _frames: Array[Texture2D] = []
var _bar: ColorRect
var _bar_back: ColorRect
var _t := 0.0
var _opening := false
var _bg: ColorRect
var _preload: Array[String] = []


func _ready() -> void:
	layer = 60
	var view := get_viewport().get_visible_rect().size
	_bg = ColorRect.new()
	_bg.color = Color(0.05, 0.035, 0.09)
	_bg.size = view
	add_child(_bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var c := Cloud.new()
		c.radius = rng.randf_range(110.0, 230.0)
		c.tone = rng.randf()
		c.position = Vector2(rng.randf_range(-0.1, 1.1) * view.x, rng.randf_range(-0.1, 1.1) * view.y)
		c.drift = rng.randf_range(-14.0, 14.0)
		add_child(c)
		_clouds.append(c)
	_runner = TextureRect.new()
	_runner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_runner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_runner.size = Vector2(150, 150)
	_runner.position = view / 2.0 - Vector2(75, 110)
	add_child(_runner)
	_load_run_frames()
	_bar_back = ColorRect.new()
	_bar_back.color = Color(1, 1, 1, 0.12)
	_bar_back.size = Vector2(220, 3)
	_bar_back.position = view / 2.0 + Vector2(-110, 58)
	add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = Color(UiKit.ACCENT, 0.9)
	_bar.size = Vector2(0, 3)
	_bar_back.add_child(_bar)
	# Warm the heavy textures the first screens need while the curtain is up.
	_preload = ["res://assets/ui/journey_map.png", "res://assets/env/ember_far.png", "res://assets/story/plates/p01_fire.jpg"]
	for p in _preload:
		if ResourceLoader.exists(p):
			ResourceLoader.load_threaded_request(p)


func _process(delta: float) -> void:
	_t += delta
	if not _frames.is_empty():
		_runner.texture = _frames[int(_t * 13.0) % _frames.size()]
	for c in _clouds:
		if not _opening:
			c.position.x += c.drift * delta
	if _opening:
		return
	var loaded := 0
	for p in _preload:
		if not ResourceLoader.exists(p) or ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_LOADED:
			loaded += 1
	var progress := minf(_t / MIN_TIME, float(loaded + 1) / float(_preload.size() + 1))
	_bar.size.x = lerpf(_bar.size.x, 220.0 * progress, minf(1.0, delta * 10.0))
	if progress >= 1.0 and _t >= MIN_TIME:
		_open()


## Clouds fly outward from the centre and fade, the runner and bar fade, wind blows.
func _open() -> void:
	_opening = true
	Sfx.play("wind_gust")
	var view := get_viewport().get_visible_rect().size
	var centre := view / 2.0
	var tw := create_tween().set_parallel()
	for c in _clouds:
		var dir := (c.position - centre)
		if dir.length() < 1.0:
			dir = Vector2.RIGHT
		var to := c.position + dir.normalized() * (view.length() * 0.9)
		tw.tween_property(c, "position", to, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(c, "modulate:a", 0.0, 0.9).set_delay(0.15)
	tw.tween_property(_bg, "color:a", 0.0, 0.6).set_delay(0.1)
	tw.tween_property(_runner, "modulate:a", 0.0, 0.25)
	tw.tween_property(_bar_back, "modulate:a", 0.0, 0.2)
	opened.emit()
	tw.chain().tween_callback(queue_free)


func _load_run_frames() -> void:
	if not ResourceLoader.exists(RUN_PNG):
		return
	var strip: Texture2D = load(RUN_PNG)
	var meta: Dictionary = GameConfig.read("actors").get("hero", {}).get("anims", {}).get("run", {})
	var n := int(meta.get("frames", 8))
	var fw := float(meta.get("frame_w", strip.get_width() / float(n)))
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = strip
		at.region = Rect2(i * fw, 0, fw, strip.get_height())
		_frames.append(at)


## A flat storm cloud: a few overlapping discs in dark violet, one lighter rim layer.
class Cloud extends Node2D:
	var radius := 160.0
	var tone := 0.5
	var drift := 0.0

	func _draw() -> void:
		var dark := Color(0.09, 0.07, 0.15).lerp(Color(0.16, 0.12, 0.24), tone)
		var rim := dark.lightened(0.12)
		var blobs := [Vector2(0, 0), Vector2(radius * 0.7, radius * 0.15), Vector2(-radius * 0.65, radius * 0.2),
			Vector2(radius * 0.25, -radius * 0.35), Vector2(-radius * 0.3, -radius * 0.25)]
		for b in blobs:
			draw_circle(b + Vector2(0, -6), radius * 0.62, rim)
		for b in blobs:
			draw_circle(b, radius * 0.6, dark)
