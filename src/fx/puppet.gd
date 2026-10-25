class_name Puppet
extends Node2D
## A jointed leather puppet in the Tholu Bommalata tradition: translucent dyed hide
## pieces with dark borders and punched-hole patterns, lit from behind. Joints follow a
## gait cycle through springs (weight, overshoot, recoil); hair, cloth and jewellery are
## Verlet chains. Origin is at the feet. Faces right; flip with face().

const OUTLINE := Color(0.1, 0.03, 0.02)
const GOLD := Color(1.0, 0.8, 0.3)

const PALETTES := {
	"hero": {
		"skin": Color(0.76, 0.31, 0.14), "cloth": Color(0.97, 0.64, 0.15), "sash": Color(0.07, 0.6, 0.55),
		"hair": Color(0.13, 0.06, 0.05), "metal": GOLD, "accent": Color(0.86, 0.13, 0.1),
		"light": Color(1.0, 0.94, 0.72), "eye": Color(1.0, 0.97, 0.9),
	},
	"soldier": {
		"skin": Color(0.42, 0.39, 0.37), "cloth": Color(0.24, 0.15, 0.28), "sash": Color(0.6, 0.11, 0.08),
		"hair": Color(0.09, 0.05, 0.06), "metal": Color(0.58, 0.52, 0.54), "accent": Color(0.75, 0.16, 0.08),
		"light": Color(1.0, 0.45, 0.15), "eye": Color(1.0, 0.3, 0.12),
	},
}

var style := "hero"
var palette: Dictionary

var body: Node2D
var hips: Node2D
var torso: Node2D
var head: Node2D
var arm_f: Node2D
var fore_f: Node2D
var arm_b: Node2D
var fore_b: Node2D
var leg_f: Node2D
var shin_f: Node2D
var leg_b: Node2D
var shin_b: Node2D
var weapon: Node2D
var weapon_tip: Node2D

var _s := 1.0
var _bulk := 1.0
var _facing := 1
var _hip_y := -52.0
var _phase := 0.0
var _time := 0.0
var _action := ""
var _action_t := 0.0
var _action_len := 0.0
var _blink := 2.0
var _eye: Node2D
var _bound := false
var _chains: Array[Chain] = []
var _pieces: Array[Node2D] = []
var _leather: Texture2D

var _squash := Spring.new(260.0, 15.0, 1.0)
var _lean := Spring.new(110.0, 11.0)
var _drop := Spring.new(220.0, 16.0)
var _recoil := Spring.new(170.0, 10.0)


## style: "hero" or "soldier".
func build(style_name: String) -> void:
	style = style_name if PALETTES.has(style_name) else "hero"
	palette = PALETTES[style]
	_leather = Fx.leather_texture()
	var soldier := style == "soldier"
	z_index = 30
	_s = 1.16 if soldier else 1.0
	_bulk = 1.3 if soldier else 1.0
	_hip_y = -52.0 * _s
	body = _joint(self, Vector2.ZERO)
	hips = _joint(body, Vector2(0, _hip_y))

	var leg_color: Color = palette["metal"] if soldier else palette["skin"]
	leg_b = _joint(hips, Vector2(-3, 2) * _s)
	_piece(leg_b, _sc(_THIGH), palette["skin"], -3)
	shin_b = _joint(leg_b, Vector2(0, 25) * _s)
	_piece(shin_b, _sc(_SHIN), leg_color, -3)
	_piece(shin_b, _sc(_FOOT), palette["cloth"] if soldier else palette["skin"], -3, false)

	torso = _joint(hips, Vector2(0, -4) * _s)
	_piece(torso, _sc(_TORSO), palette["skin"], 0, true, 9)

	leg_f = _joint(hips, Vector2(3, 2) * _s)
	_piece(leg_f, _sc(_THIGH), palette["skin"], 1)
	shin_f = _joint(leg_f, Vector2(0, 25) * _s)
	_piece(shin_f, _sc(_SHIN), leg_color, 1)
	_piece(shin_f, _sc(_FOOT), palette["cloth"] if soldier else palette["skin"], 1, false)

	arm_b = _joint(torso, Vector2(-1, -27) * _s)
	fore_b = _build_arm(arm_b, -4)
	arm_f = _joint(torso, Vector2(1, -27) * _s)
	fore_f = _build_arm(arm_f, 5)

	head = _joint(torso, Vector2(2, -31) * _s)
	if soldier:
		_build_soldier()
	else:
		_build_hero()


func _build_hero() -> void:
	# Dhoti draped over the hips, with a gold hem and punched border.
	var dhoti := _piece(hips, _sc(_DHOTI), palette["cloth"], 2, true, 7)
	_trim(dhoti, _sc(PackedVector2Array([Vector2(16, 20), Vector2(9, 17), Vector2(4, 22), Vector2(-2, 18),
		Vector2(-8, 22), Vector2(-14, 19)])), 2.0)
	_piece(hips, _sc(PackedVector2Array([Vector2(-9, -8), Vector2(9.5, -8), Vector2(9.5, -3.5), Vector2(-9, -3.5)])), palette["metal"], 3, false)
	_piece(hips, _sc(Fx.ellipse(Vector2(6.5, -5.7), Vector2(2.6, 2.6), 10)), palette["accent"], 3, false)
	# Sash across the chest.
	_piece(torso, _sc(PackedVector2Array([Vector2(-9, -26), Vector2(-5, -29), Vector2(9, -6), Vector2(5, -3)])), palette["sash"], 1, false)
	_trim(torso, _sc(PackedVector2Array([Vector2(-2, -30), Vector2(1, -26), Vector2(5, -23.5), Vector2(10, -22.5)])), 1.6)
	_dots(torso, _sc(PackedVector2Array([Vector2(1, -26), Vector2(5, -23.5), Vector2(10, -22.5)])), 1.4 * _s, palette["accent"], 1)

	# Head in profile with a large frontal eye, as puppets are cut.
	var crown_fan := PackedVector2Array([Vector2(-3, -24)])
	for i in 15:
		var a := deg_to_rad(lerpf(150.0, 305.0, i / 14.0))
		var r := 16.0 if i % 2 == 0 else 18.5
		crown_fan.append(Vector2(-3, -24) + Vector2(cos(a), sin(a)) * r)
	_piece(head, _sc(crown_fan), palette["accent"], -1, false, 0)
	var fan_dots := PackedVector2Array()
	for i in 7:
		var a := deg_to_rad(lerpf(160.0, 295.0, i / 6.0))
		fan_dots.append(Vector2(-3, -24) + Vector2(cos(a), sin(a)) * 12.5)
	_dots(head, _sc(fan_dots), 1.3, palette["light"], -1)
	_piece(head, _sc(_HEAD), palette["skin"], 3, false)
	_piece(head, _sc(_HORN), Color(0.96, 0.88, 0.7), 2, false)
	var crown := _piece(head, _sc(_CROWN), palette["metal"], 4, false)
	_dots(crown, _sc(PackedVector2Array([Vector2(0.5, -21), Vector2(0.5, -27), Vector2(0.5, -32), Vector2(0.5, -37)])), 1.5, palette["accent"], 1)
	_trim(head, _sc(PackedVector2Array([Vector2(1.5, -15.6), Vector2(4.5, -16.4), Vector2(7.5, -15.2)])), 1.3, OUTLINE)
	_trim(head, _sc(PackedVector2Array([Vector2(9.2, -6.6), Vector2(6.5, -6.2), Vector2(5.2, -7.6)])), 1.2, OUTLINE)
	_build_eye(palette["eye"], OUTLINE)

	_chain(head, Vector2(-8, -12), 8, 6.0, 5.5, palette["hair"], -6, 520.0, 60.0)
	_chain(head, Vector2(-9, -6), 8, 5.5, 5.0, palette["hair"], -6, 460.0, 50.0)
	_chain(head, Vector2(-7, -1), 7, 5.0, 4.5, palette["hair"], -6, 400.0, 40.0)
	_chain(torso, Vector2(-8, -5), 7, 6.5, 5.5, palette["sash"], -5, 480.0, 160.0)
	_chain(hips, Vector2(7, 0), 4, 5.0, 5.0, palette["cloth"], 3, 40.0, 60.0)
	var gem := Fx.polygon(Fx.ellipse(Vector2.ZERO, Vector2(1.8, 2.4) * _s, 8), palette["accent"])
	_chain(head, Vector2(-1, -6), 2, 3.5, 1.4, palette["metal"], 4, 0.0, 0.0, gem)

	# Copper-banded staff, held like a walking stick and swung in a strike.
	weapon = _joint(fore_f, Vector2(0.5, 19) * _s)
	weapon.rotation = -0.18
	var staff := Line2D.new()
	staff.points = _sc([Vector2(0, -14), Vector2(0, 50)])
	staff.width = 3.4 * _s
	staff.default_color = Color(0.32, 0.17, 0.08)
	staff.z_index = 6
	weapon.add_child(staff)
	for y in [-10.0, 0.0, 30.0, 46.0]:
		var band := Line2D.new()
		band.points = _sc([Vector2(-2.4, y), Vector2(2.4, y)])
		band.width = 2.4
		band.default_color = Color(0.92, 0.5, 0.25)
		band.z_index = 6
		weapon.add_child(band)
	weapon_tip = _joint(weapon, Vector2(0, 50) * _s)


func _build_soldier() -> void:
	# Armoured skirt of leather strips, breastplate, pauldrons, horned helmet, spear.
	var skirt := _piece(hips, _sc(_DHOTI), palette["cloth"], 2, true, 7)
	for x in [-10.0, -4.0, 2.0, 8.0, 14.0]:
		_trim(skirt, _sc(PackedVector2Array([Vector2(x, -2), Vector2(x + 1, 18)])), 1.2, OUTLINE)
	_piece(torso, _sc(PackedVector2Array([Vector2(-9, -6), Vector2(9, -6), Vector2(13, -18), Vector2(11, -27),
		Vector2(-9, -28), Vector2(-11, -17)])), palette["metal"], 1, true, 8)
	for side in [-1.0, 1.0]:
		var spike := PackedVector2Array([Vector2(-6, 2), Vector2(6, 2), Vector2(3 * side + 2, -10), Vector2(0, -2)])
		_piece(arm_f if side > 0 else arm_b, _sc(spike), palette["metal"], 6 if side > 0 else -4, false)
	_piece(head, _sc(_HEAD), palette["skin"], 3, false)
	_piece(head, _sc(PackedVector2Array([Vector2(-11, -6), Vector2(-11, -18), Vector2(-4, -24), Vector2(6, -23),
		Vector2(10, -17), Vector2(10, -13), Vector2(3, -13), Vector2(1, -8), Vector2(-4, -2)])), palette["metal"], 4, false)
	for side in [0.0, 1.0]:
		var horn := PackedVector2Array([Vector2(-2 + side * 6, -21), Vector2(-8 + side * 10, -30),
			Vector2(-6 + side * 16, -42), Vector2(-3 + side * 10, -31), Vector2(2 + side * 6, -22)])
		_piece(head, _sc(horn), Color(0.85, 0.8, 0.7), 2, false)
	_piece(head, _sc(PackedVector2Array([Vector2(7, -2), Vector2(10, -6), Vector2(9, -1)])), Color(0.95, 0.9, 0.8), 4, false)
	_build_eye(palette["eye"], palette["eye"])
	var eye_glow := Fx.glow(palette["eye"], 10.0 * _s)
	eye_glow.position = Vector2(4.5, -12) * _s
	eye_glow.z_index = 5
	head.add_child(eye_glow)
	_chain(head, Vector2(-6, -24), 6, 6.0, 4.0, palette["sash"], -6, 260.0, 90.0)
	_chain(hips, Vector2(-8, 4), 4, 6.0, 7.0, palette["cloth"], -2, 120.0, 40.0)
	_chain(hips, Vector2(8, 4), 4, 6.0, 7.0, palette["cloth"], 3, 60.0, 40.0)
	var smoke := Fx.smoke(Vector2(10, 4), Color(0.1, 0.07, 0.08, 0.5), 10)
	smoke.position = Vector2(0, -24) * _s
	torso.add_child(smoke)

	weapon = _joint(fore_f, Vector2(0, 18) * _s)
	weapon.rotation = -0.25
	var shaft := Line2D.new()
	shaft.points = _sc([Vector2(-42, 0), Vector2(62, 0)])
	shaft.width = 3.0 * _s
	shaft.default_color = Color(0.18, 0.1, 0.06)
	shaft.z_index = 6
	weapon.add_child(shaft)
	var blade := _piece(weapon, _sc(PackedVector2Array([Vector2(60, -3.5), Vector2(80, 0), Vector2(60, 3.5), Vector2(63, 0)])), palette["metal"], 6, false)
	blade.name = "Blade"
	weapon_tip = _joint(weapon, Vector2(78, 0) * _s)


func _build_arm(upper: Node2D, z: int) -> Node2D:
	_piece(upper, _sc(_UPPER_ARM), palette["skin"], z)
	_trim(upper, _sc(PackedVector2Array([Vector2(-4.3, 5), Vector2(4.4, 5)])), 2.2, palette["metal"], z + 1)
	var fore := _joint(upper, Vector2(0, 18) * _s)
	_piece(fore, _sc(_FOREARM), palette["metal"] if style == "soldier" else palette["skin"], z)
	_piece(fore, _sc(_HAND), palette["skin"], z, false)
	_trim(fore, _sc(PackedVector2Array([Vector2(-3, 13.5), Vector2(3, 13.5)])), 2.0, palette["metal"], z + 1)
	return fore


func _build_eye(white: Color, iris_ring: Color) -> void:
	_eye = Node2D.new()
	_eye.position = Vector2(4.2, -12.3) * _s
	_eye.z_index = 5
	head.add_child(_eye)
	var almond := PackedVector2Array([Vector2(-3.4, 0.2), Vector2(-0.6, -1.8), Vector2(3.0, -0.4), Vector2(0.1, 1.5)])
	_eye.add_child(Fx.polygon(_sc(almond), white))
	_eye.add_child(Fx.outline(_sc(almond), OUTLINE, 1.1))
	_eye.add_child(Fx.polygon(Fx.ellipse(Vector2(0.2, -0.2) * _s, Vector2(1.25, 1.25) * _s, 10), iris_ring if style == "soldier" else OUTLINE))
	var kohl := Line2D.new()
	kohl.points = _sc(PackedVector2Array([Vector2(-3.4, 0.2), Vector2(-5.5, -0.6)]))
	kohl.width = 1.1
	kohl.default_color = OUTLINE
	_eye.add_child(kohl)


# --- shapes (hero units, facing right, y down) --------------------------------------

const _THIGH := [Vector2(-5.5, -2), Vector2(5, -2), Vector2(7, 6), Vector2(5.5, 16), Vector2(3.5, 25), Vector2(-3, 25), Vector2(-6, 12)]
const _SHIN := [Vector2(-3.5, 0), Vector2(3.8, 0), Vector2(4.2, 8), Vector2(2.6, 19), Vector2(2.4, 23), Vector2(-2.4, 23), Vector2(-4.8, 9)]
const _FOOT := [Vector2(-3.2, 20.5), Vector2(2.6, 20.5), Vector2(9, 23.4), Vector2(11.5, 25.6), Vector2(-3.6, 25.6)]
const _DHOTI := [Vector2(-9, -6), Vector2(9, -6), Vector2(11, 2), Vector2(14, 12), Vector2(16, 20), Vector2(9, 17), Vector2(4, 22), Vector2(-2, 18), Vector2(-8, 22), Vector2(-14, 19), Vector2(-12, 6)]
const _TORSO := [Vector2(-7, 0), Vector2(7, 0), Vector2(8.5, -6), Vector2(12, -16), Vector2(12, -22), Vector2(8, -28.5), Vector2(3, -31), Vector2(-3, -31), Vector2(-9.5, -28), Vector2(-10.5, -18), Vector2(-8.5, -7)]
const _UPPER_ARM := [Vector2(-4, -1), Vector2(4, -1), Vector2(4.6, 8), Vector2(3, 18.5), Vector2(-3, 18.5), Vector2(-4.4, 8)]
const _FOREARM := [Vector2(-3, 0), Vector2(3, 0), Vector2(3.4, 8), Vector2(2.4, 15.5), Vector2(-2.4, 15.5), Vector2(-3.4, 7)]
const _HAND := [Vector2(-2.6, 14.5), Vector2(2.6, 14.5), Vector2(4.6, 17.5), Vector2(6.8, 20.6), Vector2(5.2, 21.8), Vector2(2.2, 20.8), Vector2(0.6, 23), Vector2(-1.6, 22), Vector2(-2.9, 18.6)]
const _HEAD := [Vector2(-9, -6), Vector2(-10.5, -13), Vector2(-7, -19.5), Vector2(0, -21.5), Vector2(6, -19), Vector2(8, -14), Vector2(8.6, -11.5), Vector2(12, -8.2), Vector2(9.2, -7), Vector2(9.6, -5.6), Vector2(8.5, -4.9), Vector2(9.5, -4), Vector2(8.6, -1.4), Vector2(4, 1), Vector2(2.2, 4), Vector2(-5, 4), Vector2(-8, -1)]
const _HORN := [Vector2(-3, -19), Vector2(-10, -22), Vector2(-15, -27), Vector2(-16.5, -34), Vector2(-13, -28.5), Vector2(-9, -25), Vector2(-4, -22.5)]
const _CROWN := [Vector2(-7, -18), Vector2(8, -18), Vector2(8, -22), Vector2(6, -24), Vector2(7, -28), Vector2(4, -30), Vector2(5, -34), Vector2(2, -37), Vector2(3, -41), Vector2(0.5, -47), Vector2(-2, -41), Vector2(-1, -37), Vector2(-4, -34), Vector2(-3, -30), Vector2(-6, -28), Vector2(-5, -24), Vector2(-7, -22)]


# --- animation ------------------------------------------------------------------

## dir: 1 faces right, -1 faces left.
func face(dir: int) -> void:
	_facing = 1 if dir >= 0 else -1
	scale.x = _facing
	for c in _chains:
		c.facing = _facing


func jumped() -> void:
	_squash.value = 1.2
	_squash.velocity = 0.0


## impact: downward speed at touchdown, in px/s.
func landed(impact: float) -> void:
	var amount := clampf(impact / 2400.0, 0.04, 0.3)
	_squash.value = 1.0 - amount
	_drop.kick(impact * 0.012)


func cast() -> void:
	_start("cast", 0.35)


func strike() -> void:
	_start("strike", 0.34)
	_swoosh()


func windup() -> void:
	_start("windup", 10.0)  # held until thrust()


func thrust() -> void:
	_start("thrust", 0.3)


func relax() -> void:
	_action = ""


func hit(from_dir: float) -> void:
	_recoil.kick(-9.0 * from_dir * _facing)
	_squash.value = 0.88
	flash(Color(1.0, 0.4, 0.3))


func set_bound(on: bool) -> void:
	_bound = on


func flash(color: Color) -> void:
	modulate = color
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.35)


## The puppet comes apart: every leather piece flies off, spins and fades.
func shatter(into: Node, ground_y: float) -> void:
	var debris := PuppetDebris.new()
	debris.ground_y = ground_y
	debris.z_index = 30
	debris.modulate = modulate
	into.add_child(debris)
	var center := global_position + Vector2(0, -50)
	for holder in _pieces:
		if not is_instance_valid(holder):
			continue
		var copy := holder.duplicate() as Node2D
		var from := holder.global_position
		var vel := (from - center).normalized() * randf_range(120, 340) + Vector2(randf_range(-80, 80), -randf_range(250, 520))
		debris.add_piece(copy, vel, randf_range(-9, 9))
		copy.global_transform = holder.global_transform
		copy.z_index = holder.z_index
	visible = false


func restore() -> void:
	visible = true
	modulate = Color.WHITE
	for c in _chains:
		c.reset()


## move: -1..1 horizontal speed ratio. vy: vertical velocity (negative is up).
func animate(delta: float, move: float, on_floor: bool, vy: float) -> void:
	_time += delta
	if _bound:
		body.position.x = sin(_time * 60.0) * 0.8
		return
	body.position.x = 0.0
	var run := clampf(absf(move), 0.0, 1.0)
	var forward := 1.0 if move * _facing >= 0.0 else -1.0
	var p := {
		"thigh_f": 0.0, "thigh_b": 0.0, "knee_f": 0.1, "knee_b": 0.1,
		"arm_f": 0.08, "arm_b": -0.08, "elbow_f": -0.35, "elbow_b": -0.3, "head": 0.0, "bob": 0.0,
	}
	if on_floor:
		_phase += delta * lerpf(2.0, 12.5, run)
		var s := sin(_phase)
		var c := cos(_phase)
		p["thigh_f"] = -0.78 * s * run
		p["thigh_b"] = 0.78 * s * run
		p["knee_f"] = 0.1 + maxf(0.0, -c) * 1.25 * run
		p["knee_b"] = 0.1 + maxf(0.0, c) * 1.25 * run
		p["arm_f"] = 0.62 * s * run + 0.08
		p["arm_b"] = -0.62 * s * run - 0.08
		p["elbow_f"] = -0.3 - 0.5 * run * (0.5 + 0.5 * s)
		p["elbow_b"] = -0.3 - 0.5 * run * (0.5 - 0.5 * s)
		p["bob"] = -absf(s) * 3.5 * run + sin(_time * 2.1) * 0.8 * (1.0 - run)
		p["head"] = sin(_time * 0.9) * 0.05 * (1.0 - run)
		_lean.target = 0.16 * run * forward
	elif vy < 0.0:
		p["thigh_f"] = -1.15
		p["knee_f"] = 1.5
		p["thigh_b"] = 0.4
		p["knee_b"] = 1.0
		p["arm_f"] = -2.2
		p["arm_b"] = 0.9
		p["elbow_f"] = -0.6
		_lean.target = 0.06
	else:
		p["thigh_f"] = -0.45
		p["knee_f"] = 0.55
		p["thigh_b"] = 0.3
		p["knee_b"] = 0.4
		p["arm_f"] = -2.5
		p["arm_b"] = -2.0
		p["elbow_f"] = -0.25
		p["elbow_b"] = -0.25
		_lean.target = -0.04
	_apply_action(p, delta)

	var drop := _drop.update(delta)
	var k := 1.0 - exp(-20.0 * delta)
	leg_f.rotation = lerp_angle(leg_f.rotation, p["thigh_f"] - drop * 0.02, k)
	leg_b.rotation = lerp_angle(leg_b.rotation, p["thigh_b"] + drop * 0.02, k)
	shin_f.rotation = lerp_angle(shin_f.rotation, p["knee_f"] + drop * 0.05, k)
	shin_b.rotation = lerp_angle(shin_b.rotation, p["knee_b"] + drop * 0.05, k)
	var arm_k := 1.0 - exp(-(34.0 if _action != "" else 16.0) * delta)
	arm_f.rotation = lerp_angle(arm_f.rotation, p["arm_f"], arm_k)
	arm_b.rotation = lerp_angle(arm_b.rotation, p["arm_b"], k)
	fore_f.rotation = lerp_angle(fore_f.rotation, p["elbow_f"], arm_k)
	fore_b.rotation = lerp_angle(fore_b.rotation, p["elbow_b"], k)
	torso.rotation = _lean.update(delta) + _recoil.update(delta) * 0.4
	head.rotation = lerp_angle(head.rotation, p["head"] - torso.rotation * 0.4, k)
	hips.position.y = lerpf(hips.position.y, _hip_y + p["bob"], k) + drop * 0.25
	var sq := _squash.update(delta)
	body.scale = Vector2(clampf(2.0 - sq, 0.75, 1.3), clampf(sq, 0.7, 1.3))
	_update_blink(delta)


func _apply_action(p: Dictionary, delta: float) -> void:
	if _action == "":
		return
	_action_t += delta
	var t := _action_t / _action_len
	if t >= 1.0:
		_action = ""
		return
	match _action:
		"cast":
			p["arm_f"] = -1.6
			p["elbow_f"] = -0.05
		"strike":
			# Raised behind, then over the top and down in front.
			p["arm_f"] = 2.5 if t < 0.25 else -0.95
			p["elbow_f"] = -0.2
			_lean.target = -0.1 if t < 0.25 else 0.28
		"windup":
			p["arm_f"] = 0.75
			p["elbow_f"] = -0.75
			_lean.target = -0.14
		"thrust":
			p["arm_f"] = -1.05
			p["elbow_f"] = 0.95
			_lean.target = 0.3


func _start(action: String, length: float) -> void:
	_action = action
	_action_t = 0.0
	_action_len = length


func _update_blink(delta: float) -> void:
	if _eye == null:
		return
	_blink -= delta
	if _blink < 0.0:
		_eye.scale.y = 0.15
		if _blink < -0.11:
			_eye.scale.y = 1.0
			_blink = randf_range(2.5, 5.0)


## A bright arc that follows the staff's path for a moment.
func _swoosh() -> void:
	var arc := Line2D.new()
	var pts := PackedVector2Array()
	for i in 13:
		var a := deg_to_rad(lerpf(-150.0, 35.0, i / 12.0))
		pts.append(Vector2(2, -80) * _s + Vector2(cos(a), sin(a)) * 62.0 * _s)
	arc.points = pts
	arc.width = 9.0
	var taper := Curve.new()
	taper.add_point(Vector2(0, 0.1))
	taper.add_point(Vector2(1, 1))
	arc.width_curve = taper
	arc.default_color = Color(1.0, 0.85, 0.55, 0.85)
	arc.material = Fx.additive()
	arc.z_index = 8
	add_child(arc)
	var tw := create_tween()
	tw.tween_property(arc, "modulate:a", 0.0, 0.22).set_delay(0.06)
	tw.tween_callback(arc.queue_free)


# --- construction helpers ----------------------------------------------------------

func _joint(parent: Node, pos: Vector2) -> Node2D:
	var j := Node2D.new()
	j.position = pos
	parent.add_child(j)
	return j


## One leather piece: dyed translucent fill with grain, dark border, optional punched holes.
func _piece(parent: Node, pts: PackedVector2Array, color: Color, z: int, smooth_it: bool = true, holes: int = 0) -> Node2D:
	var outline := Fx.smooth(pts, 4) if smooth_it else pts
	var holder := Node2D.new()
	holder.z_index = z
	var fill := Fx.polygon(outline, color)
	fill.texture = _leather
	fill.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	holder.add_child(fill)
	holder.add_child(Fx.outline(outline, OUTLINE, 1.5))
	if holes > 0:
		var center := Vector2.ZERO
		for q in outline:
			center += q
		center /= outline.size()
		var dots := PackedVector2Array()
		var step := maxi(1, outline.size() / holes)
		for i in range(0, outline.size(), step):
			dots.append(outline[i].lerp(center, 0.24))
		_dots(holder, dots, 1.1 * _s, palette["light"], 0)
	parent.add_child(holder)
	_pieces.append(holder)
	return holder


func _dots(parent: Node, pts: PackedVector2Array, radius: float, color: Color, z: int) -> void:
	var d := Dots.new()
	d.points = pts
	d.radius = radius
	d.color = color
	d.z_index = z
	parent.add_child(d)


func _trim(parent: Node, pts: PackedVector2Array, width: float, color: Color = GOLD, z: int = 1) -> void:
	var l := Line2D.new()
	l.points = pts
	l.width = width * _s
	l.default_color = color
	l.antialiased = true
	l.z_index = z
	parent.add_child(l)


func _chain(anchor: Node2D, offset: Vector2, segments: int, seg_len: float, width: float, color: Color,
		z: int, pull: float, flutter: float = 0.0, tip: Node2D = null) -> void:
	var c := Chain.new()
	c.anchor = anchor
	c.anchor_offset = offset * _s
	c.segments = segments
	c.seg_len = seg_len * _s
	c.width = width * _s
	c.color = color
	c.edge_color = OUTLINE
	c.backward_pull = pull
	c.flutter = flutter
	c.tip = tip
	c.z_as_relative = false
	c.z_index = 30 + z
	add_child(c)
	_chains.append(c)


## Scales hero-unit points to this figure (soldiers are taller and broader).
## Accepts an Array or a PackedVector2Array.
func _sc(pts) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(Vector2(q.x * _bulk, q.y) * _s)
	return out


## Holes punched through the hide; light shows through them.
class Dots extends Node2D:
	var points := PackedVector2Array()
	var radius := 1.0
	var color := Color.WHITE

	func _draw() -> void:
		for q in points:
			draw_circle(q, radius, color)
