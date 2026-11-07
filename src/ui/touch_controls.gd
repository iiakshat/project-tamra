class_name TouchControls
extends CanvasLayer
## Hybrid touch controls. Fingers that land on a pad press an input action; any
## other finger draws a mantra stroke. One stroke at a time, so a thumb on the move
## pad and a finger drawing work together.

signal stroke_started
signal stroke_finished(points: PackedVector2Array)

const ACTIONS := {"left": "move_left", "right": "move_right", "jump": "jump", "strike": "attack"}
const HIT_SLOP := 1.25
const TRAIL_POINTS := 90

var hud: Hud

var _pad: PadView
var _trail: Line2D
var _roles := {}  # finger index -> "left" | "right" | "jump" | "stroke"
var _stroke_finger := -1
var _stroke := PackedVector2Array()


func _ready() -> void:
	layer = 15
	_pad = PadView.new()
	_pad.controls = self
	UiKit.full_rect(_pad)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)
	Game.settings_changed.connect(_pad.queue_redraw)
	_trail = Line2D.new()
	_trail.width = 12.0
	_trail.default_color = Color(0.75, 1.0, 0.92)
	_trail.material = Fx.additive()
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.antialiased = true
	var taper := Curve.new()
	taper.add_point(Vector2(0, 0.15))
	taper.add_point(Vector2(1, 1))
	_trail.width_curve = taper
	add_child(_trail)


## Pad centres and radii for the current screen, size and handedness (Settings).
func layout() -> Dictionary:
	return ControlLayout.compute(get_viewport().get_visible_rect().size,
		float(Game.save.settings.get("pad_scale", 1.0)), bool(Game.save.settings.get("left_handed", false)))


func centers() -> Dictionary:
	return layout()["centers"]


func is_pressed(role: String) -> bool:
	return _roles.values().has(role)


func release_all() -> void:
	for role in ACTIONS:
		Input.action_release(ACTIONS[role])
	_roles.clear()
	_stroke_finger = -1
	_stroke = PackedVector2Array()
	_trail.clear_points()
	_pad.queue_redraw()


func _role_at(pos: Vector2) -> String:
	if hud != null and hud.blocks(pos):
		return "blocked"
	var l := layout()
	for role in l["centers"]:
		if pos.distance_to(l["centers"][role]) <= float(l["radii"][role]) * HIT_SLOP:
			return role
	return ""


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_down(event.index, event.position)
		else:
			_on_up(event.index)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position)


func _on_down(index: int, pos: Vector2) -> void:
	var role := _role_at(pos)
	if role == "blocked":
		return
	if role == "":
		if _stroke_finger != -1:
			return
		_stroke_finger = index
		_roles[index] = "stroke"
		_stroke = PackedVector2Array([pos])
		_trail.points = _stroke
		_trail.modulate.a = 1.0
		Sfx.play("stroke_start")
		stroke_started.emit()
		return
	_roles[index] = role
	Input.action_press(ACTIONS[role])
	_pad.queue_redraw()


func _on_drag(index: int, pos: Vector2) -> void:
	var role: String = _roles.get(index, "")
	if role == "stroke":
		if _stroke[_stroke.size() - 1].distance_to(pos) >= 3.0:
			_stroke.append(pos)
			_trail.points = _stroke.slice(maxi(0, _stroke.size() - TRAIL_POINTS))
	elif role == "left" or role == "right":
		# Let the thumb slide between left and right without lifting.
		var now := _role_at(pos)
		if (now == "left" or now == "right") and now != role:
			_roles[index] = now
			_release_if_free(role)
			Input.action_press(ACTIONS[now])
			_pad.queue_redraw()


func _on_up(index: int) -> void:
	var role: String = _roles.get(index, "")
	_roles.erase(index)
	if role == "stroke":
		_stroke_finger = -1
		var pts := _stroke
		_stroke = PackedVector2Array()
		create_tween().tween_property(_trail, "modulate:a", 0.0, 0.25)
		stroke_finished.emit(pts)
	elif ACTIONS.has(role):
		_release_if_free(role)
		_pad.queue_redraw()


func _release_if_free(role: String) -> void:
	if not is_pressed(role):
		Input.action_release(ACTIONS[role])


class PadView extends Control:
	var controls: TouchControls

	func _draw() -> void:
		var l := controls.layout()
		for role in l["centers"]:
			var pressed := controls.is_pressed(role)
			var r: float = l["radii"][role]
			var center: Vector2 = l["centers"][role]
			# Themed like the HUD: an indigo disc with a copper rim (jade while held).
			draw_circle(center, r, Color(0.06, 0.05, 0.16, 0.5 if pressed else 0.3))
			draw_arc(center, r, 0.0, TAU, 56, Color(UiKit.ACCENT if pressed else UiKit.COPPER, 0.85 if pressed else 0.5), 3.0, true)
			draw_arc(center, r - 6.0, 0.0, TAU, 56, Color(UiKit.COPPER, 0.18), 1.5, true)
			var ink := Color(UiKit.TEXT, 0.9 if pressed else 0.55)
			var s := r * 0.32
			match role:
				"left":
					draw_colored_polygon(PackedVector2Array([center + Vector2(-s, 0), center + Vector2(s * 0.7, -s), center + Vector2(s * 0.7, s)]), ink)
				"right":
					draw_colored_polygon(PackedVector2Array([center + Vector2(s, 0), center + Vector2(-s * 0.7, -s), center + Vector2(-s * 0.7, s)]), ink)
				"jump":
					draw_colored_polygon(PackedVector2Array([center + Vector2(0, -s * 1.1), center + Vector2(s, s * 0.5), center + Vector2(-s, s * 0.5)]), ink)
				"strike":
					# A staff and the arc of its swing.
					draw_line(center + Vector2(-s, s), center + Vector2(s, -s), ink, 5.0, true)
					draw_arc(center + Vector2(-s * 0.4, s * 0.4), s * 1.3, -PI * 0.55, -PI * 0.05, 12, ink, 2.5, true)
