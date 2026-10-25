class_name Puppet
extends Node2D
## A jointed shadow puppet built from polygons. Limbs swing around joints the way
## leather shadow puppets are worked. Facing is handled by flipping scale.x.
## Origin is at the feet.

var rim := Color(1.0, 0.6, 0.28, 0.85)
var accent := Color(0.62, 0.08, 0.06)
var eye_color := Color(1.0, 0.72, 0.32)

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
var scarf: Line2D

var _s := 1.0
var _facing := 1
var _hip_y := -46.0
var _phase := 0.0
var _time := 0.0
var _cast := 0.0
var _scarf_pts: Array[Vector2] = []


## style: "hero" or "soldier".
func build(style: String) -> void:
	var soldier := style == "soldier"
	# Puppets draw above the world. Their rim outlines sit far below the fills (see
	# _shape), so only the outer edge of the whole figure catches the light.
	z_index = 30
	_s = 1.22 if soldier else 1.0
	var bulk := 1.5 if soldier else 1.0
	if soldier:
		rim = Color(0.85, 0.28, 0.2, 0.7)
		eye_color = Color(1.0, 0.18, 0.1)
	_hip_y = -46.0 * _s
	hips = _joint(self, Vector2(0, _hip_y), 0)

	leg_b = _limb(hips, Vector2(-4, 2) * _s, 23.0 * _s, 4.6 * bulk, -1)
	shin_b = _limb(leg_b, Vector2(0, 23.0 * _s), 22.0 * _s, 3.8 * bulk, 0, true)
	leg_f = _limb(hips, Vector2(4, 2) * _s, 23.0 * _s, 4.6 * bulk, 1)
	shin_f = _limb(leg_f, Vector2(0, 23.0 * _s), 22.0 * _s, 3.8 * bulk, 0, true)

	# Flared dhoti over the hips.
	var skirt := PackedVector2Array([Vector2(-11, -4), Vector2(11, -4), Vector2(17, 13), Vector2(6, 10),
		Vector2(-1, 15), Vector2(-16, 12)])
	_shape(hips, _scaled(skirt, bulk), Fx.INK, 2)

	torso = _joint(hips, Vector2(0, -2) * _s, 1)
	var chest := PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(11, -14), Vector2(14, -29),
		Vector2(9, -32), Vector2(-9, -32), Vector2(-13, -29), Vector2(-10, -14)])
	_shape(torso, _scaled(chest, bulk), Fx.INK, 0)
	# Gold belt and necklace: the ornament that makes it read as a puppet, not a shadow.
	_trim(torso, PackedVector2Array([Vector2(-9, -2), Vector2(9, -2)]) if not soldier else PackedVector2Array([Vector2(-13, -2), Vector2(13, -2)]), 2.2)
	_trim(torso, _arc(Vector2(0, -30) * _s, 7.0 * _s * bulk, 0.3, PI - 0.3), 1.6)

	arm_b = _limb(torso, Vector2(-3, -28) * _s, 17.0 * _s, 3.8 * bulk, -2)
	fore_b = _limb(arm_b, Vector2(0, 17.0 * _s), 16.0 * _s, 3.2 * bulk, 0, false, true)
	arm_f = _limb(torso, Vector2(3, -28) * _s, 17.0 * _s, 3.8 * bulk, 2)
	fore_f = _limb(arm_f, Vector2(0, 17.0 * _s), 16.0 * _s, 3.2 * bulk, 0, false, true)

	head = _joint(torso, Vector2(1, -32) * _s, 1)
	_shape(head, Fx.ellipse(Vector2(0, -9) * _s, Vector2(9.5, 10.5) * _s, 18), Fx.INK, 0)
	if soldier:
		_build_soldier_head()
		_build_spear()
	else:
		_build_hero_head()
		_build_scarf()
	var eye := Fx.glow(eye_color, 9.0 * _s)
	eye.position = Vector2(4.5, -10) * _s
	head.add_child(eye)
	var pupil := Fx.polygon(Fx.ellipse(Vector2(4.5, -10) * _s, Vector2(2.2, 1.4) * _s, 8), eye_color.lightened(0.4))
	head.add_child(pupil)


func _build_hero_head() -> void:
	# Tall crown of three flames and small swept-back horns.
	var crown := PackedVector2Array([Vector2(-9, -14), Vector2(-8, -23), Vector2(-4, -17), Vector2(0, -31),
		Vector2(4, -17), Vector2(7, -24), Vector2(9, -14)])
	_shape(head, _scaled(crown, 1.0), Fx.INK, 0)
	_trim(head, _scaled(PackedVector2Array([Vector2(-9, -14), Vector2(9, -14)]), 1.0), 1.8)
	var horn := PackedVector2Array([Vector2(-6, -15), Vector2(-14, -21), Vector2(-21, -19), Vector2(-15, -17),
		Vector2(-8, -12)])
	_shape(head, _scaled(horn, 1.0), Fx.INK, -1)
	# Long hair falling behind.
	var hair := PackedVector2Array([Vector2(-6, -16), Vector2(-14, -8), Vector2(-17, 6), Vector2(-12, 3),
		Vector2(-9, 10), Vector2(-5, -4)])
	_shape(head, _scaled(hair, 1.0), Fx.INK, -1)


func _build_soldier_head() -> void:
	var helm := PackedVector2Array([Vector2(-11, -12), Vector2(-10, -21), Vector2(0, -26), Vector2(10, -21),
		Vector2(11, -12)])
	_shape(head, _scaled(helm, 1.0), Fx.INK, 0)
	for side in [-1.0, 1.0]:
		var horn := PackedVector2Array([Vector2(side * 8, -20), Vector2(side * 20, -26), Vector2(side * 27, -40),
			Vector2(side * 22, -28), Vector2(side * 10, -16)])
		_shape(head, _scaled(horn, 1.0), Fx.INK, 0)
	# Smoke pours off the shoulders.
	var smoke := Fx.smoke(Vector2(12, 4), Color(0.1, 0.07, 0.08, 0.5), 10)
	smoke.position = Vector2(0, 6) * _s
	torso.add_child(smoke)


func _build_spear() -> void:
	var spear := Node2D.new()
	spear.position = Vector2(0, 16) * _s
	spear.rotation = -1.2
	fore_f.add_child(spear)
	var shaft := Line2D.new()
	shaft.points = PackedVector2Array([Vector2(0, 40), Vector2(0, -70)])
	shaft.width = 3.0
	shaft.default_color = Fx.INK
	spear.add_child(shaft)
	_shape(spear, PackedVector2Array([Vector2(-5, -70), Vector2(0, -92), Vector2(5, -70), Vector2(0, -74)]), Fx.INK, 0)


func _build_scarf() -> void:
	scarf = Line2D.new()
	scarf.width = 6.0
	scarf.default_color = accent
	scarf.joint_mode = Line2D.LINE_JOINT_ROUND
	scarf.end_cap_mode = Line2D.LINE_CAP_ROUND
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0.25))
	scarf.width_curve = c
	scarf.z_index = -3
	scarf.antialiased = true
	add_child(scarf)


## dir: 1 faces right, -1 faces left.
func face(dir: int) -> void:
	_facing = 1 if dir >= 0 else -1
	scale.x = _facing


## Plays the casting pose for a moment.
func cast() -> void:
	_cast = 0.35


func flash(color: Color) -> void:
	modulate = color
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.35)


## move: -1..1 horizontal speed ratio. vy: vertical velocity (negative is up).
func animate(delta: float, move: float, on_floor: bool, vy: float) -> void:
	_time += delta
	var run := clampf(absf(move), 0.0, 1.0)
	var thigh_f := 0.0
	var thigh_b := 0.0
	var knee_f := 0.0
	var knee_b := 0.0
	var upper_f := 0.0
	var upper_b := 0.0
	var elbow_f := -0.3
	var elbow_b := -0.3
	var lean := 0.0
	var bob := 0.0
	if on_floor:
		_phase += delta * lerpf(2.0, 11.5, run)
		var s := sin(_phase)
		var c := cos(_phase)
		thigh_f = -s * 0.8 * run
		thigh_b = s * 0.8 * run
		knee_f = maxf(0.0, c) * 1.1 * run + 0.05
		knee_b = maxf(0.0, -c) * 1.1 * run + 0.05
		upper_f = s * 0.7 * run
		upper_b = -s * 0.7 * run
		elbow_f = -0.3 - 0.4 * run
		elbow_b = -0.3 - 0.4 * run
		lean = 0.16 * run
		bob = -absf(s) * 3.5 * run + sin(_time * 2.2) * 0.9 * (1.0 - run)
	elif vy < 0.0:
		thigh_f = -1.2
		knee_f = 1.5
		thigh_b = 0.35
		knee_b = 0.9
		upper_f = -2.3
		upper_b = 0.9
		elbow_f = -0.5
		lean = 0.08
	else:
		thigh_f = -0.45
		knee_f = 0.5
		thigh_b = 0.3
		knee_b = 0.35
		upper_f = -2.6
		upper_b = -2.1
		elbow_f = -0.2
		elbow_b = -0.2
	if _cast > 0.0:
		_cast -= delta
		upper_f = -1.6
		elbow_f = -0.05
	var k := 1.0 - exp(-18.0 * delta)
	leg_f.rotation = lerp_angle(leg_f.rotation, thigh_f, k)
	leg_b.rotation = lerp_angle(leg_b.rotation, thigh_b, k)
	shin_f.rotation = lerp_angle(shin_f.rotation, knee_f, k)
	shin_b.rotation = lerp_angle(shin_b.rotation, knee_b, k)
	arm_f.rotation = lerp_angle(arm_f.rotation, upper_f, k)
	arm_b.rotation = lerp_angle(arm_b.rotation, upper_b, k)
	fore_f.rotation = lerp_angle(fore_f.rotation, elbow_f, k)
	fore_b.rotation = lerp_angle(fore_b.rotation, elbow_b, k)
	torso.rotation = lerp_angle(torso.rotation, lean, k)
	hips.position.y = lerpf(hips.position.y, _hip_y + bob, k)
	head.rotation = sin(_time * 1.7) * 0.03
	_update_scarf(delta)


func _update_scarf(delta: float) -> void:
	if scarf == null:
		return
	var anchor := head.to_global(Vector2(-5, -3) * _s)
	if _scarf_pts.is_empty():
		for i in 9:
			_scarf_pts.append(anchor)
	_scarf_pts[0] = anchor
	var back := -float(_facing)
	var k := 1.0 - exp(-12.0 * delta)
	for i in range(1, _scarf_pts.size()):
		var wave := sin(_time * 7.0 - i * 0.9) * 2.0
		var target := _scarf_pts[i - 1] + Vector2(back * 7.0, 1.5 + wave)
		_scarf_pts[i] = _scarf_pts[i].lerp(target, k)
		var seg := _scarf_pts[i] - _scarf_pts[i - 1]
		if seg.length() > 8.0:
			_scarf_pts[i] = _scarf_pts[i - 1] + seg.normalized() * 8.0
	var local := PackedVector2Array()
	for p in _scarf_pts:
		local.append(to_local(p))
	scarf.points = local


func _joint(parent: Node, pos: Vector2, z: int) -> Node2D:
	var j := Node2D.new()
	j.position = pos
	j.z_index = z
	parent.add_child(j)
	return j


## A tapered limb hanging down from its joint. Feet and hands are part of the shape.
func _limb(parent: Node, pos: Vector2, length: float, width: float, z: int, foot := false, hand := false) -> Node2D:
	var j := _joint(parent, pos, z)
	var pts := PackedVector2Array([Vector2(-width, 0), Vector2(width, 0)])
	if foot:
		pts.append_array([Vector2(width * 0.8, length - 3), Vector2(width * 0.8 + 8, length - 1),
			Vector2(width * 0.8 + 8, length + 1), Vector2(-width * 0.85, length + 1)])
	else:
		pts.append_array([Vector2(width * 0.8, length), Vector2(-width * 0.8, length)])
	_shape(j, pts, Fx.INK, 0)
	if hand:
		_shape(j, Fx.ellipse(Vector2(0, length + 1), Vector2(width * 0.9, width * 0.9), 8), Fx.INK, 0)
	# Joint disc hides the seam, like the pin on a real puppet.
	_shape(j, Fx.ellipse(Vector2.ZERO, Vector2(width, width), 10), Fx.INK, 0)
	return j


func _shape(parent: Node, pts: PackedVector2Array, color: Color, z: int) -> void:
	var holder := Node2D.new()
	holder.z_index = z
	holder.add_child(Fx.polygon(pts, color))
	var edge := Fx.outline(pts, rim, 2.6)
	edge.z_index = -26
	holder.add_child(edge)
	parent.add_child(holder)


func _trim(parent: Node, pts: PackedVector2Array, width: float) -> void:
	var l := Line2D.new()
	l.points = pts
	l.width = width
	l.default_color = Color(1.0, 0.72, 0.3, 0.95)
	l.antialiased = true
	l.z_index = 1
	parent.add_child(l)


func _scaled(pts: PackedVector2Array, bulk: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x * bulk, p.y) * _s)
	return out


func _arc(center: Vector2, radius: float, from: float, to: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 9:
		var a := lerpf(from, to, i / 8.0)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts
