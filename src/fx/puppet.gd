class_name Puppet
extends Node2D
## A painted character (hero, soldiers, story cast) drawn from hand-painted frame strips
## in assets/chars (Gemini art, cut by tools/build_chars.sh; frame data in
## config/actors.json). Frames carry the poses; springs add weight on top (squash on
## landing, lean into runs, recoil on hits), and a shader breathes the idle frame:
## the chest rises on the inhale and settles on the exhale. Origin is at the feet.
## Art faces right; flip with face(). The name stays from the leather-puppet days so
## gameplay code did not have to change.

signal breathed(inhale: bool)

const SHADER := preload("res://src/fx/actor.gdshader")
const IDLE_BREATH_PERIOD := 3.0  # seconds per full breath at rest
const PANT_BREATH_PERIOD := 0.52

static var _cfg: Dictionary = {}
static var _textures: Dictionary = {}

var style := "hero"
var weapon_tip: Node2D
var body: Node2D
var sprite: Sprite2D

var _actor: Dictionary = {}
var _anim := ""
var _frame := 0
var _frame_t := 0.0
var _facing := 1
var _time := 0.0
var _action := ""
var _action_t := 0.0
var _action_len := 0.0
var _bound := false
var _land_t := 0.0
var _hurt_t := 0.0
var _breath_phase := 0.0
var _inhaling := false
var _mat: ShaderMaterial

var _squash := Spring.new(260.0, 15.0, 1.0)
var _lean := Spring.new(110.0, 11.0)
var _recoil := Spring.new(170.0, 10.0)


static func config() -> Dictionary:
	if _cfg.is_empty():
		_cfg = GameConfig.read("actors")
	return _cfg


static func texture(actor: String, anim: String) -> Texture2D:
	var path := "res://assets/chars/%s/%s.png" % [actor, anim]
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


## style: "hero", "soldier", "archer", "brute", "maa" or "king". `overrides` recolour
## the hero's clothes for shop skins: {"cloth": Color, "sash": Color}.
func build(style_name: String, overrides: Dictionary = {}) -> void:
	style = style_name
	_actor = config().get(style, config().get("hero", {}))
	body = Node2D.new()
	add_child(body)
	sprite = Sprite2D.new()
	sprite.centered = false
	# Plain linear: mipmaps blurred the figure at phone resolution (owner: "blurry").
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var s := float(_actor.get("scale", 0.5))
	sprite.scale = Vector2(s, s)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	sprite.material = _mat
	body.add_child(sprite)
	weapon_tip = Node2D.new()
	body.add_child(weapon_tip)
	_breath_phase = randf() * TAU
	if style == "hero":
		_mat.set_shader_parameter("outline_color", Color(1.0, 0.86, 0.62, 0.55))
	for key in ["cloth", "sash"]:
		if overrides.has(key):
			_mat.set_shader_parameter(key + "_to", overrides[key])
	_show("idle", 0)


## Height of the standing figure in world px (for UI framing and story staging).
func height() -> float:
	var a: Dictionary = _actor.get("anims", {}).get("idle", {})
	return float(a.get("anchor", [0, 250])[1]) * float(_actor.get("scale", 0.5))


# --- animation ------------------------------------------------------------------

## dir: 1 faces right, -1 faces left.
func face(dir: int) -> void:
	_facing = 1 if dir >= 0 else -1
	scale.x = absf(scale.x) * _facing


func jumped() -> void:
	_squash.value = 1.18
	_squash.velocity = 0.0


## impact: downward speed at touchdown, in px/s.
func landed(impact: float) -> void:
	var amount := clampf(impact / 2600.0, 0.04, 0.26)
	_squash.value = 1.0 - amount
	if impact > 700.0:
		_land_t = 0.14


func cast() -> void:
	_start("cast", 0.4)


func strike() -> void:
	_start("strike", 0.32)
	_swoosh()


## Bent over, hands on knees, chest heaving: catching breath after a long run.
func pant(duration: float) -> void:
	_start("pant", duration)


func windup() -> void:
	_start("windup", 10.0)  # held until thrust()


func thrust() -> void:
	_start("thrust", 0.3)


func relax() -> void:
	_action = ""


func hit(from_dir: float) -> void:
	_recoil.kick(-7.0 * from_dir * _facing)
	_squash.value = 0.9
	_hurt_t = 0.28
	flash(Color(1.0, 0.35, 0.3))


func set_bound(on: bool) -> void:
	_bound = on


func flash(color: Color) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("flash_color", Color(color.r, color.g, color.b, 0.75))
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void: _mat.set_shader_parameter("flash_color", Color(color.r, color.g, color.b, a)), 0.75, 0.0, 0.3)


## Death. The hero sinks to his knees and falls; the smoke-born dissolve into ash.
## The figure is left behind as a copy so this node can respawn right away.
func shatter(into: Node, ground_y: float) -> void:
	var ghost := Node2D.new()
	ghost.scale = scale
	ghost.z_index = 30
	into.add_child(ghost)
	ghost.global_position = Vector2(global_position.x, ground_y)
	var spr := Sprite2D.new()
	spr.centered = false
	spr.scale = sprite.scale
	spr.texture_filter = sprite.texture_filter
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	spr.material = mat
	ghost.add_child(spr)
	var tw := ghost.create_tween()
	if style == "hero" and _anims().has("death"):
		_frame_into(spr, "death", 0)
		tw.tween_interval(0.3)
		tw.tween_callback(func() -> void: _frame_into(spr, "death", 1))
		tw.tween_interval(0.9)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.5)
	else:
		_frame_into(spr, _anim, _frame)
		mat.set_shader_parameter("dissolve_edge", Color(1.0, 0.45, 0.15))
		Fx.burst(into, global_position + Vector2(0, -height() * 0.5), Color(0.12, 0.1, 0.12, 0.85), 26, 160.0, false, 1.3)
		tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.85)
	tw.tween_callback(ghost.queue_free)
	visible = false


func restore() -> void:
	visible = true
	modulate = Color.WHITE
	_action = ""
	_hurt_t = 0.0
	if _mat != null:
		_mat.set_shader_parameter("flash_color", Color(1, 1, 1, 0))
		_mat.set_shader_parameter("dissolve", 0.0)


## move: -1..1 horizontal speed ratio. vy: vertical velocity (negative is up).
func animate(delta: float, move: float, on_floor: bool, vy: float) -> void:
	_time += delta
	_land_t -= delta
	_hurt_t -= delta
	if _bound:
		body.position.x = sin(_time * 60.0) * 1.2
		return
	body.position.x = 0.0
	var run := clampf(absf(move), 0.0, 1.0)
	var forward := 1.0 if move * _facing >= 0.0 else -1.0
	var breath_period := 0.0
	_lean.target = 0.0

	if _action != "":
		_action_t += delta
		if _action_t >= _action_len and _action != "windup":
			_action = ""
	if _action != "":
		var t := _action_t / maxf(_action_len, 0.001)
		match _action:
			"strike":
				_show_action("strike", ["strike"], mini(int(t * 3.0), 2))
			"cast":
				_show_action("cast", ["cast"], 0 if t < 0.45 else 1)
			"windup":
				_show_action("windup", ["windup", "strike"], 0)
			"thrust":
				_show_action("thrust", ["thrust", "strike"], -1)
			"pant":
				_show_action("pant", ["pant", "idle"], 0)
				breath_period = PANT_BREATH_PERIOD
	elif _hurt_t > 0.0 and _anims().has("hurt"):
		_show("hurt", 0)
	elif not on_floor and _anims().has("jump"):
		if vy < -520.0:
			_show("jump", 1)
		elif vy < 140.0:
			_show("jump", 2)
		else:
			_show("fall" if _anims().has("fall") else "jump", 0)
		_lean.target = 0.05 * forward * run
	elif _land_t > 0.0 and _anims().has("land"):
		_show("land", 0)
	elif run > 0.08 and _anims().has("run"):
		var a: Dictionary = _anims()["run"]
		var fps := float(a.get("fps", 12.0)) * lerpf(0.55, 1.0, run)
		_frame_t += delta * fps
		var n := int(a.get("frames", 1))
		_show("run", int(_frame_t) % n)
		_lean.target = 0.05 * run * forward
	else:
		_show("idle", 0)
		breath_period = IDLE_BREATH_PERIOD

	_update_breath(delta, breath_period)
	body.rotation = _lean.update(delta) + _recoil.update(delta) * 0.03
	var sq := _squash.update(delta)
	body.scale = Vector2(clampf(2.0 - sq, 0.8, 1.2), clampf(sq, 0.78, 1.22))


## Inhale-exhale: a slow rise and fall of the chest at rest, a fast heave when panting.
func _update_breath(delta: float, period: float) -> void:
	if period <= 0.0:
		_mat.set_shader_parameter("breath", 0.0)
		return
	_breath_phase += delta * TAU / period
	var b := sin(_breath_phase)
	var strength := 0.9 if period >= IDLE_BREATH_PERIOD else 2.0
	_mat.set_shader_parameter("breath", b * strength)
	var inhaling := cos(_breath_phase) > 0.0
	if inhaling != _inhaling:
		_inhaling = inhaling
		breathed.emit(inhaling)


func _anims() -> Dictionary:
	return _actor.get("anims", {})


## Plays the first animation in `names` that this actor has (soldiers have no "strike"
## strip, the hero has no "thrust" strip). frame -1 means the last frame.
func _show_action(_action_name: String, names: Array, frame: int) -> void:
	for n in names:
		if _anims().has(n):
			var count := int(_anims()[n].get("frames", 1))
			_show(n, count - 1 if frame < 0 else mini(frame, count - 1))
			return
	_show("idle", 0)


func _show(anim: String, frame: int) -> void:
	if not _anims().has(anim):
		anim = "idle"
		frame = 0
	if anim == _anim and frame == _frame:
		return
	if anim != _anim:
		_frame_t = 0.0
	_anim = anim
	_frame = frame
	_frame_into(sprite, anim, frame)
	var a: Dictionary = _anims()[anim]
	var tips: Array = a.get("tips", [])
	if frame < tips.size():
		var tip: Array = tips[frame]
		weapon_tip.position = Vector2(float(tip[0]), float(tip[1])) * sprite.scale.x
	_mat.set_shader_parameter("waist", float(a.get("waist", 0.6)))
	_mat.set_shader_parameter("chest_x", float(a.get("chest_x", 0.5)))


func _frame_into(spr: Sprite2D, anim: String, frame: int) -> void:
	if not _anims().has(anim):
		return
	var a: Dictionary = _anims()[anim]
	var tex := texture(style, anim)
	if tex == null:
		return
	var n := int(a.get("frames", 1))
	spr.texture = tex
	spr.hframes = n
	spr.frame = clampi(frame, 0, n - 1)
	var anchor: Array = a.get("anchor", [0, 0])
	spr.offset = -Vector2(float(anchor[0]), float(anchor[1]))


func _start(action: String, length: float) -> void:
	_action = action
	_action_t = 0.0
	_action_len = length


## A bright arc that follows the staff's path for a moment.
func _swoosh() -> void:
	var arc := Line2D.new()
	var pts := PackedVector2Array()
	var h := height()
	for i in 13:
		var ang := deg_to_rad(lerpf(-150.0, 35.0, i / 12.0))
		pts.append(Vector2(6, -h * 0.62) + Vector2(cos(ang), sin(ang)) * h * 0.62)
	arc.points = pts
	arc.width = 10.0
	var taper := Curve.new()
	taper.add_point(Vector2(0, 0.1))
	taper.add_point(Vector2(1, 1))
	arc.width_curve = taper
	arc.default_color = Color(1.0, 0.85, 0.55, 0.85)
	arc.material = Fx.additive()
	arc.z_index = 8
	add_child(arc)
	var tw := create_tween()
	tw.tween_property(arc, "modulate:a", 0.0, 0.2).set_delay(0.06)
	tw.tween_callback(arc.queue_free)
