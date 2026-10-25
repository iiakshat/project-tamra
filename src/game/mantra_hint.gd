class_name MantraHint
extends Node2D
## A mantra's sign floating over the hero's head for a few seconds, traced the way it
## is drawn. Shown after repeated deaths in one spot (see HintFinder).

const RADIUS := 62.0

var mantra_id := ""

var _view: GlyphView
var _left := 0.0
var _color := Color(0.85, 0.8, 1.0)


func _ready() -> void:
	z_index = 60
	visible = false
	_view = GlyphView.new()
	_view.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	_view.position = -_view.size / 2.0
	_view.animate = true
	_view.line_width = 5.0
	add_child(_view)


func show_for(id: String, seconds: float) -> void:
	mantra_id = id
	_view.show_mantra(id)
	_color = GameConfig.color(Game.mantra_cfg.get(id, {}).get("color", ""), _color)
	_left = seconds
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	queue_redraw()


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	scale = Vector2.ONE * (1.0 + 0.04 * sin(Time.get_ticks_msec() * 0.006))
	if _left <= 0.0:
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.4)
		t.tween_callback(func() -> void: visible = false)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.04, 0.02, 0.08, 0.6))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(_color, 0.8), 2.5, true)
