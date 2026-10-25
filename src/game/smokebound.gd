class_name Smokebound
extends CharacterBody2D
## A soldier of the Smoke King. Three kinds:
## - "soldier" patrols, notices the hero (ahead, or close behind), gives chase, hops up
##   small ledges, and thrusts with a spear after a short glinting wind-up, sometimes
##   twice in a row.
## - "archer" holds a ledge and looses smoke bolts that lead the hero a little; if the
##   hero comes close it hops back, or bashes when cornered.
## - "brute" is big, slow and shielded: fire from the front only staggers it. It slams
##   the ground after a long telegraph; jump or step back.
## Touching an enemy never hurts: every attack is telegraphed (design rule).

signal died(at: Vector2, cause: String)

enum State { PATROL, CHASE, WINDUP, THRUST, RECOVER, STAGGER, DAZED, BOUND, HOP, DEAD }

const SIZE := Vector2(44, 108)
const BRUTE_SCALE := 1.3
const GRAVITY := 2300.0
## How far past his patrol a soldier will give chase.
const LEASH := 650.0
## Sight ahead, and how close the hero must be to be noticed from behind.
const SIGHT := 520.0
const NOTICE_BEHIND := 250.0
const SIGHT_DY := 170.0
## An alerted guard gives up only when the hero is this far away.
const LOSE_SIGHT := 900.0
const ATTACK_RANGE := 100.0
const SPEAR_REACH := 118.0
const WINDUP_TIME := 0.4
const COMBO_WINDUP := 0.24
const COMBO_CHANCE := 0.4
const THRUST_TIME := 0.18
const RECOVER_TIME := 0.45
const STAGGER_TIME := 0.28
## After one stagger, further hits inside this window no longer interrupt him.
const POISE_WINDOW := 1.4
## Ledges up to this tall he hops onto; drops deeper than SAFE_DROP he will not walk off.
const STEP_UP := 130.0
const SAFE_DROP := 140.0
const HOP_COOLDOWN := 1.0
## Archers.
const ARCHER_RANGE := 650.0
const ARCHER_INTERVAL := 1.7
const ARCHER_DRAW := 0.45
const ARCHER_LEAD := 0.5
const ARCHER_PANIC := 170.0
## Brutes.
const SLAM_WINDUP := 0.8
const SLAM_REACH := 175.0
const SLAM_RECOVER := 0.85
const BRUTE_RANGE := 140.0

var level: Level
var patrol_min := 0.0
var patrol_max := 0.0
var speed := 95.0
var chase_speed := 230.0
var daze_time := 2.5
var max_hp := 3
var hp := 3
var dir := -1
var puppet: Puppet
## "soldier", "archer" or "brute".
var kind := "soldier"
var fire_interval := ARCHER_INTERVAL
var combo_chance := COMBO_CHANCE
var drop_prana := 20.0

var _fire_t := 0.6
var _state := State.PATROL
var _t := 0.0
var _knock := 0.0
var _alerted := false
var _thrust_hit := false
var _combo := false
var _melee := false
var _poise_t := 0.0
var _hop_cool := 0.0
var _home := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _rig: Node2D
var _glint: Sprite2D
var _daze_fx: Node2D
var _roots: Node2D
var _pips: Pips
var _slam_mark: Line2D


## Hit points when the level data gives none. Chapter 1 guards fall to one JWALA (2).
static func default_hp(kind_name: String, chapter: String) -> int:
	match kind_name:
		"archer":
			return 2
		"brute":
			return 5
	return 2 if chapter == "c1" else 3


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("enemies")
	_home = position
	_rng.seed = hash(Vector2i(position))
	var k := BRUTE_SCALE if kind == "brute" else 1.0
	if kind == "brute":
		speed = 65.0
		chase_speed = 160.0
		drop_prana = 35.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE * k
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y * k / 2.0)
	add_child(shape)
	var aura := Fx.glow(Color(0.9, 0.15, 0.1, 0.2), 95.0 * k)
	aura.position = Vector2(0, -60 * k)
	add_child(aura)
	hp = max_hp
	# The puppet sits in a rig so the brute can be drawn bigger: face() owns scale.x.
	_rig = Node2D.new()
	_rig.scale = Vector2.ONE * k
	add_child(_rig)
	puppet = Puppet.new()
	match kind:
		"archer":
			puppet.build("soldier", {"cloth": Color(0.3, 0.14, 0.36), "sash": Color(0.5, 0.2, 0.8), "metal": Color(0.42, 0.38, 0.46)})
		"brute":
			puppet.build("soldier", {"cloth": Color(0.36, 0.08, 0.08), "sash": Color(0.15, 0.1, 0.12), "metal": Color(0.3, 0.27, 0.3)})
		_:
			puppet.build("soldier")
	_rig.add_child(puppet)
	_glint = Fx.glow(Color(1.0, 0.95, 0.75), 26.0 * k)
	_glint.visible = false
	_glint.z_index = 45
	add_child(_glint)
	_daze_fx = Node2D.new()
	_daze_fx.position = Vector2(0, -150 * k)
	_daze_fx.visible = false
	_daze_fx.z_index = 45
	for i in 3:
		var m := Fx.glow(Color(0.5, 0.95, 1.0), 9.0)
		m.position = Vector2.from_angle(TAU * i / 3.0) * 16.0
		_daze_fx.add_child(m)
	add_child(_daze_fx)
	_roots = _make_roots()
	add_child(_roots)
	_pips = Pips.new()
	_pips.position = Vector2(0, -150 * k)
	_pips.z_index = 45
	_pips.visible = false
	add_child(_pips)
	if kind == "brute":
		_slam_mark = _make_slam_mark()
		add_child(_slam_mark)


func is_alive() -> bool:
	return _state != State.DEAD


func hitbox() -> Rect2:
	var k := BRUTE_SCALE if kind == "brute" else 1.0
	return Rect2(global_position + Vector2(-SIZE.x * k / 2.0, -SIZE.y * k), SIZE * k)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, 1300.0)
	_knock = move_toward(_knock, 0.0, 1400.0 * delta)
	_t -= delta
	_poise_t = maxf(0.0, _poise_t - delta)
	_hop_cool = maxf(0.0, _hop_cool - delta)
	var vx := 0.0
	match _state:
		State.PATROL, State.CHASE:
			match kind:
				"archer":
					vx = _archer_think(delta)
				_:
					vx = _move_or_engage()
		State.WINDUP:
			if _t <= 0.0:
				_release_attack()
		State.THRUST:
			vx = dir * 240.0
			_check_spear()
			if _t <= 0.0:
				_after_thrust()
		State.HOP:
			vx = dir * -280.0 if kind == "archer" else dir * chase_speed
			if _t <= 0.0 and is_on_floor():
				_enter(State.CHASE, 0.0)
		State.RECOVER, State.STAGGER, State.BOUND:
			if _t <= 0.0:
				if _state == State.BOUND:
					puppet.set_bound(false)
					_roots.visible = false
				_enter(State.CHASE, 0.0)
		State.DAZED:
			if _t <= 0.0:
				_enter(State.PATROL, 0.0)
	velocity.x = vx + _knock
	move_and_slide()


func _process(delta: float) -> void:
	puppet.face(dir)
	puppet.animate(delta, velocity.x / chase_speed, is_on_floor(), velocity.y)
	_daze_fx.visible = _state == State.DAZED
	_daze_fx.rotation += delta * 5.0
	if _glint.visible:
		_glint.position = to_local(puppet.weapon_tip.global_position)
		_glint.scale = Vector2.ONE * (0.6 + 0.3 * sin(Time.get_ticks_msec() * 0.03))
	if _slam_mark != null and _slam_mark.visible:
		_slam_mark.scale.x = dir
		_slam_mark.modulate.a = 0.45 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.02))


# --- Soldiers and brutes -------------------------------------------------------------


func _move_or_engage() -> float:
	var target := _pick_target()
	if target == null:
		return _patrol()
	if not _alerted:
		_alerted = true
		Sfx.play("enemy_alert", global_position)
	_state = State.CHASE
	var dx := target.global_position.x - global_position.x
	var dy := target.global_position.y - global_position.y
	if absf(dx) > 6.0:
		dir = 1 if dx > 0.0 else -1
	var reach := BRUTE_RANGE if kind == "brute" else ATTACK_RANGE
	if absf(dx) < reach and absf(dy) < 70.0 and is_on_floor():
		_start_windup(SLAM_WINDUP if kind == "brute" else WINDUP_TIME)
		return 0.0
	# Hero on a ledge right above: hop up through it to follow.
	if dy < -40.0 and dy > -(STEP_UP + 40.0) and absf(dx) < 160.0 and kind != "brute":
		_hop(dy)
	var vx := dir * chase_speed
	if (vx < 0.0 and global_position.x <= patrol_min - LEASH) or (vx > 0.0 and global_position.x >= patrol_max + LEASH):
		return 0.0
	return _guard_edges(vx, dy)


func _patrol() -> float:
	_state = State.PATROL
	if global_position.x <= patrol_min:
		dir = 1
	elif global_position.x >= patrol_max:
		dir = -1
	var vx := _guard_edges(dir * speed, 0.0)
	if vx == 0.0 and is_on_floor():
		dir = -dir  # a drop ahead: turn back
	return vx


## Stops at a pit edge, hops a small step, never walks off a deadly drop.
func _guard_edges(vx: float, target_dy: float) -> float:
	if not is_on_floor() or vx == 0.0:
		return vx
	var ahead := signf(vx)
	var k := BRUTE_SCALE if kind == "brute" else 1.0
	var probe := global_position + Vector2(ahead * (SIZE.x * k / 2.0 + 14.0), 0.0)
	if not _ray(probe + Vector2(0, -6), probe + Vector2(0, SAFE_DROP)):
		return 0.0
	var knee := global_position + Vector2(0, -24)
	if _ray(knee, knee + Vector2(ahead * (SIZE.x * k / 2.0 + 18.0), 0.0)):
		# A wall: hop if its top is within reach, otherwise wait at its foot.
		var high := global_position + Vector2(0, -STEP_UP - 12.0)
		if kind != "brute" and not _ray(high, high + Vector2(ahead * (SIZE.x / 2.0 + 30.0), 0.0)):
			_hop(minf(target_dy, -STEP_UP))
		return vx
	return vx


func _hop(dy: float) -> void:
	if _hop_cool > 0.0 or not is_on_floor():
		return
	_hop_cool = HOP_COOLDOWN
	var rise := clampf(-dy, 60.0, STEP_UP) + 30.0
	velocity.y = -sqrt(2.0 * GRAVITY * rise)
	puppet.jumped()


func _ray(from: Vector2, to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _pick_target() -> Node2D:
	for d in level.active_decoys():
		if absf(d.global_position.x - global_position.x) < SIGHT * 1.4 and absf(d.global_position.y - global_position.y) < 140.0:
			return d
	var p := level.player
	if p == null or not p.alive:
		return null
	var dx := p.global_position.x - global_position.x
	var dy := absf(p.global_position.y - global_position.y)
	if _alerted:
		if absf(dx) < LOSE_SIGHT and dy < SIGHT_DY + 60.0:
			return p
		_alerted = false
		return null
	var ahead := signf(dx) == float(dir)
	# A running hero is heard further away than a creeping one.
	var behind := NOTICE_BEHIND * (1.5 if absf(p.velocity.x) > 200.0 and p.is_on_floor() else 1.0)
	if dy < SIGHT_DY and absf(dx) < (SIGHT if ahead else behind):
		return p
	return null


func _start_windup(time: float) -> void:
	_enter(State.WINDUP, time)
	puppet.windup()
	_glint.visible = true
	if _slam_mark != null:
		_slam_mark.visible = true
	Sfx.play("enemy_windup", global_position, 2.0 if kind == "brute" else 0.0, 0.7 if kind == "brute" else 1.0)


func _release_attack() -> void:
	_glint.visible = false
	if kind == "archer" and not _melee:
		_loose_bolt()
		return
	if kind == "brute":
		_slam()
		return
	_enter(State.THRUST, THRUST_TIME)
	puppet.thrust()
	_thrust_hit = false
	Sfx.play("enemy_attack", global_position)


func _after_thrust() -> void:
	var p := level.player
	var close := p != null and p.alive and absf(p.global_position.x - global_position.x) < ATTACK_RANGE + 50.0
	if kind == "soldier" and not _combo and close and _rng.randf() < combo_chance:
		_combo = true
		_start_windup(COMBO_WINDUP)
		return
	_combo = false
	_melee = false
	_enter(State.RECOVER, RECOVER_TIME)
	puppet.relax()


func _check_spear() -> void:
	if _thrust_hit:
		return
	var reach := 80.0 if kind == "archer" else SPEAR_REACH
	var x0 := global_position.x + (10.0 if dir > 0 else -reach - 10.0)
	var spear := Rect2(Vector2(x0, global_position.y - 92.0), Vector2(reach, 40.0))
	for d in level.active_decoys():
		if spear.intersects(d.hitbox()):
			_thrust_hit = true
			d.dispel()
			_enter(State.DAZED, daze_time)
			puppet.relax()
			Sfx.play("enemy_dazed", global_position)
			return
	var p := level.player
	if p != null and p.alive and spear.intersects(p.hitbox()):
		_thrust_hit = true
		if p.shield_time > 0.0:
			Sfx.play("kavach_block", p.global_position)
			Fx.burst(get_parent(), p.global_position + Vector2(0, -50), Color(1.0, 0.85, 0.5), 18, 220.0)
			_combo = true  # no follow-up after a block
			_enter(State.DAZED, 1.4)
			puppet.relax()
		else:
			p.take_hit(global_position.x)


## The brute's ground slam: everything standing in front of him is hit. Jump over it.
func _slam() -> void:
	puppet.thrust()
	if _slam_mark != null:
		_slam_mark.visible = false
	Sfx.play("land_heavy", global_position, 3.0, 0.7)
	Sfx.play("enemy_attack", global_position, 0.0, 0.7)
	Game.vibrate(40)
	for i in 5:
		Fx.burst(get_parent(), global_position + Vector2(dir * (30.0 + i * 35.0), -6), Color(0.45, 0.35, 0.32, 0.8), 6, 160.0, false, 0.5)
	_enter(State.RECOVER, SLAM_RECOVER)
	var p := level.player
	if p == null or not p.alive:
		return
	var dx := (p.global_position.x - global_position.x) * dir
	if dx > -40.0 and dx < SLAM_REACH and absf(p.global_position.y - global_position.y) < 40.0 and p.is_on_floor():
		if p.shield_time > 0.0:
			Sfx.play("kavach_block", p.global_position)
		else:
			p.take_hit(global_position.x)


# --- Archers -----------------------------------------------------------------------


## Archers stand their ground: they turn to the hero in range and, every couple of
## seconds, draw (glint) and loose a bolt. Too close, they hop back or bash.
func _archer_think(delta: float) -> float:
	var p := level.player
	if p == null or not p.alive or p.global_position.distance_to(global_position) > ARCHER_RANGE:
		_fire_t = maxf(_fire_t, 0.6)
		return 0.0
	dir = 1 if p.global_position.x > global_position.x else -1
	if not _alerted:
		_alerted = true
		Sfx.play("enemy_alert", global_position)
	var dx := absf(p.global_position.x - global_position.x)
	if dx < ARCHER_PANIC and absf(p.global_position.y - global_position.y) < 90.0 and is_on_floor():
		if _hop_cool <= 0.0 and _floor_behind():
			_hop_cool = 2.2
			velocity.y = -600.0
			_enter(State.HOP, 0.25)
			return 0.0
		if dx < 95.0:
			_melee = true
			_start_windup(0.32)
			return 0.0
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = fire_interval
		_melee = false
		_start_windup(ARCHER_DRAW)
	return 0.0


func _floor_behind() -> bool:
	var at := global_position + Vector2(-dir * 150.0, 0.0)
	return _ray(at + Vector2(0, -40), at + Vector2(0, 80)) and not _ray(global_position + Vector2(0, -30), at + Vector2(0, -30))


func _loose_bolt() -> void:
	puppet.thrust()
	var bolt := SmokeBolt.new()
	var from := puppet.weapon_tip.global_position
	bolt.position = from
	var p := level.player
	var target := p.global_position + Vector2(0, -50)
	# Lead the hero a little: half of where he will be when the bolt arrives.
	var flight := from.distance_to(target) / SmokeBolt.SPEED
	var lead := (p.velocity * flight * ARCHER_LEAD).limit_length(170.0)
	lead.y = clampf(lead.y, -60.0, 60.0)
	bolt.dir = (target + lead - from).normalized()
	get_parent().add_child(bolt)
	Sfx.play("enemy_attack", global_position, -3.0, 1.3)
	_enter(State.RECOVER, 0.35)


# --- Taking damage -------------------------------------------------------------------


## amount: hit points. cause: "strike", "fire", ...
func damage(amount: int, from_x: float, cause: String) -> void:
	if _state == State.DEAD:
		return
	hp -= amount
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -dir
	puppet.hit(away)
	_show_pips()
	if hp <= 0:
		_die(cause)
		return
	Sfx.play("enemy_hurt", global_position)
	_alerted = true
	if kind == "brute":
		_knock = away * 90.0
		return  # too heavy to flinch from a staff
	_knock = away * 260.0
	var busy := _state == State.WINDUP or _state == State.THRUST
	if busy and _poise_t > 0.0:
		return  # already staggered once: this time he keeps coming
	_glint.visible = false
	puppet.relax()
	dir = -int(away)
	_poise_t = POISE_WINDOW
	_enter(State.STAGGER, STAGGER_TIME)


## Hit points a fire bolt takes. A brute's shield takes fire from the front (the bolt
## flies against the way he faces): it staggers him but does no harm.
static func fire_damage(kind_name: String, facing: int, bolt_dir: int, amount: int) -> int:
	if kind_name == "brute" and bolt_dir == -facing:
		return 0
	return amount


## JWALA's bolt. `bolt_dir` is the way the bolt flies.
func fire_hit(amount: int, bolt_dir: int) -> void:
	if _state == State.DEAD:
		return
	if fire_damage(kind, dir, bolt_dir, amount) == 0:
		Sfx.play("kavach_block", global_position, -2.0, 0.7)
		Fx.burst(get_parent(), global_position + Vector2(dir * 30.0, -80), Color(1.0, 0.6, 0.3), 16, 200.0)
		_glint.visible = false
		if _slam_mark != null:
			_slam_mark.visible = false
		puppet.relax()
		puppet.hit(-float(bolt_dir))
		_alerted = true
		_enter(State.STAGGER, 0.6)
		return
	damage(amount, global_position.x - bolt_dir, "fire")
	if _state != State.DEAD:
		Fx.burst(get_parent(), global_position + Vector2(0, -55), Color(1.0, 0.5, 0.15), 24, 220.0)


## Anything else that burns (default: one JWALA bolt from behind).
func burn() -> void:
	fire_hit(2, dir)


## TARANG: hurled away from the source and staggered (a brute only stumbles).
func push(from: Vector2, force: float) -> void:
	if _state == State.DEAD:
		return
	var heavy := kind == "brute"
	var away := signf(global_position.x - from.x)
	_knock = away * force * (0.45 if heavy else 1.0)
	velocity.y = -force * (0.2 if heavy else 0.45)
	_glint.visible = false
	if _slam_mark != null:
		_slam_mark.visible = false
	puppet.relax()
	_alerted = true
	_enter(State.STAGGER, 0.5 if heavy else 0.7)


## BANDHAN: rooted in place, unable to strike.
func bind(duration: float) -> void:
	if _state == State.DEAD:
		return
	_glint.visible = false
	if _slam_mark != null:
		_slam_mark.visible = false
	puppet.relax()
	puppet.set_bound(true)
	_roots.visible = true
	_enter(State.BOUND, duration)


## The level is won: he lowers his spear and stays where he is.
func stand_down() -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO
	_glint.visible = false
	if _slam_mark != null:
		_slam_mark.visible = false
	puppet.relax()


## After the hero respawns, a living guard is back at his post and calm again.
func return_to_post() -> void:
	if _state == State.DEAD:
		return
	global_position = _home
	velocity = Vector2.ZERO
	_knock = 0.0
	_alerted = false
	_combo = false
	_melee = false
	_fire_t = 0.6
	_glint.visible = false
	if _slam_mark != null:
		_slam_mark.visible = false
	_roots.visible = false
	puppet.set_bound(false)
	puppet.relax()
	_enter(State.PATROL, 0.0)


func _enter(state: State, time: float) -> void:
	_state = state
	_t = time


func _show_pips() -> void:
	_pips.hp = maxi(hp, 0)
	_pips.max_hp = max_hp
	_pips.visible = true
	_pips.queue_redraw()


func _die(cause: String) -> void:
	_state = State.DEAD
	collision_layer = 0
	remove_from_group("enemies")
	_glint.visible = false
	_pips.visible = false
	_roots.visible = false
	if _slam_mark != null:
		_slam_mark.visible = false
	died.emit(global_position, cause)
	Game.track("fire_kills" if cause == "fire" else "strike_kills")
	if drop_prana > 0.0:
		var orb := PranaOrb.new()
		orb.amount = drop_prana
		orb.position = global_position + Vector2(0, -60)
		get_parent().call_deferred("add_child", orb)
	if cause == "fire":
		Sfx.play("enemy_burn", global_position)
		Fx.burst(get_parent(), global_position + Vector2(0, -55), Color(1.0, 0.5, 0.15), 48, 320.0)
		Fx.burst(get_parent(), global_position + Vector2(0, -55), Color(0.15, 0.1, 0.1, 0.8), 20, 120.0, false, 1.2)
		var t := create_tween()
		t.tween_property(puppet, "modulate", Color(1.0, 0.4, 0.1, 0.0), 0.45)
		t.tween_callback(queue_free)
	else:
		Sfx.play("enemy_hurt", global_position, 2.0, 0.8)
		puppet.shatter(get_parent(), global_position.y)
		get_tree().create_timer(2.0, false).timeout.connect(queue_free)


func _make_roots() -> Node2D:
	var root := Node2D.new()
	root.visible = false
	root.z_index = 44
	for i in 7:
		var vine := Line2D.new()
		var x := randf_range(-26, 26)
		var pts := PackedVector2Array()
		for k in 6:
			pts.append(Vector2(x + sin(k * 1.7 + i) * 7.0, -k * 16.0))
		vine.points = pts
		vine.width = 3.0
		vine.default_color = Color(0.7, 1.0, 0.6, 0.9)
		vine.material = Fx.additive()
		root.add_child(vine)
	root.add_child(Fx.glow(Color(0.5, 1.0, 0.5, 0.3), 70.0))
	return root


## The brute's telegraph: a red crack along the ground where the slam will land.
func _make_slam_mark() -> Line2D:
	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(-40, -3), Vector2(SLAM_REACH, -3)])
	line.width = 7.0
	line.default_color = Color(1.0, 0.25, 0.15, 0.8)
	line.material = Fx.additive()
	line.z_index = 44
	line.visible = false
	return line


## Health shown as small lamps over the head once the guard has been hurt.
class Pips extends Node2D:
	var hp := 3
	var max_hp := 3

	func _draw() -> void:
		for i in max_hp:
			var x := (i - (max_hp - 1) / 2.0) * 13.0
			draw_circle(Vector2(x, 0), 4.5, Color(0.1, 0.03, 0.03, 0.9))
			if i < hp:
				draw_circle(Vector2(x, 0), 3.2, Color(1.0, 0.4, 0.15))
