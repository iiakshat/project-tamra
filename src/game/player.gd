class_name Player
extends CharacterBody2D
## The hero. Movement feel (coyote time, jump buffering, variable jump height) is
## tuned from config/player.json. Origin is at the feet.

signal died(cause: String)
signal hearts_changed(hearts: int, max_hearts: int)
## -1 when a heart is lost, +1 when one is healed (the HUD animates it).
signal heart_delta(delta: int)
signal prana_changed(prana: float, max_prana: float)

const SIZE := Vector2(30, 88)
const STRIKE_COOLDOWN := 0.42
const STRIKE_WINDOW := Vector2(0.08, 0.2)  # seconds after the swing starts when it can hit
const STRIKE_REACH := 84.0
const PANT_TIME := 2.6  # seconds of catching breath when tired
const STEP_DISTANCE := 46.0
## UDAAN's glide: how slowly he sinks (px/s), and the gentle pull that gets him there.
const GLIDE_FALL := 80.0
const GLIDE_GRAVITY := 900.0

var cfg: Dictionary
var level: Level
var max_hearts := 3
var hearts := 3
var facing := 1
var alive := true
var controls_enabled := true
## Set at the goal gate: no input, no harm, he walks himself into the doorway.
var finishing := false
var shield_time := 0.0
var puppet: Puppet

var _invulnerable := 0.0
var _coyote := 0.0
var _buffer := 0.0
var _shield: Node2D
var _was_on_floor := true
var _fall_speed := 0.0
var _step_acc := 0.0
var _strike_t := -1.0
var _strike_cool := 0.0
var _struck: Array[Node] = []

## Prana: the energy every mantra spends. Regenerates after a short rest from casting.
var max_prana := 100.0
var prana := 100.0
var _since_cast := 99.0
var _idle_time := 0.0
var fatigue: Fatigue
var _pant_left := 0  # 1 while catching breath
var _pant_timer := 0.0  # seconds of panting left
var _screamed := false
var _scream_check := 0.0
var _breathing := false
## Seconds since the current jump left the ground (-1: not in a jump rise). A release
## before `jump_min_hold` is remembered and applied then, so a quick tap on the touch
## pad still rises about three quarters of a full jump.
var _jump_t := -1.0
var _cut_pending := false
var _walk_to := 0.0
## UDAAN: seconds of glide left once the leap tops out (-1: no glide waiting).
var _glide := -1.0
var _wings: UdaanWings


func setup(config: Dictionary, hearts_max: int, prana_max: float = -1.0) -> void:
	cfg = config
	max_hearts = hearts_max
	hearts = hearts_max
	max_prana = prana_max if prana_max > 0.0 else float(config.get("prana_max", 100.0))
	prana = max_prana
	fatigue = Fatigue.new(config)


## Full prana (checkpoints): traversal mantras must always be castable after a rest.
func refill_prana() -> void:
	add_prana(max_prana)


func spend_prana(cost: float) -> bool:
	if prana < cost:
		return false
	prana -= cost
	_since_cast = 0.0
	prana_changed.emit(prana, max_prana)
	return true


func add_prana(amount: float) -> void:
	prana = minf(max_prana, prana + amount)
	prana_changed.emit(prana, max_prana)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 8.0
	add_to_group("hero")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y / 2.0)
	add_child(shape)
	# Warm backlight: the leather puppet glows like a lamp is behind the screen.
	var aura := Fx.glow(Color(0.72, 0.68, 1.0, 0.28), 100.0)
	aura.position = Vector2(0, -55)
	add_child(aura)
	puppet = Puppet.new()
	puppet.build("hero", Game.skin_palette())
	add_child(puppet)
	puppet.breathed.connect(_on_breathed)
	_shield = _make_shield()
	add_child(_shield)
	_wings = UdaanWings.new()
	_wings.position = Vector2(0, -58)
	add_child(_wings)
	if fatigue == null:
		fatigue = Fatigue.new(cfg)


func _num(key: String, fallback: float) -> float:
	return float(cfg.get(key, fallback))


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if finishing:
		_walk_into_gate(delta)
		return
	var dir := 0.0
	if controls_enabled:
		dir = Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()
	var accel: float
	if on_floor:
		accel = _num("ground_accel", 2600.0) if dir != 0.0 else _num("ground_decel", 3200.0)
	else:
		accel = _num("air_accel", 1900.0)
	velocity.x = move_toward(velocity.x, dir * _num("run_speed", 330.0), accel * delta)

	var gravity := _num("gravity", 2400.0)
	if velocity.y > 0.0:
		gravity *= _num("fall_gravity_mult", 1.4)
	if gliding():
		velocity.y = minf(velocity.y + GLIDE_GRAVITY * delta, GLIDE_FALL)
	else:
		velocity.y = minf(velocity.y + gravity * delta, _num("max_fall", 1300.0))
	_update_glide(delta, on_floor)

	if on_floor:
		_coyote = _num("coyote_time", 0.1)
	else:
		_coyote -= delta
	if controls_enabled and Input.is_action_just_pressed("jump"):
		_buffer = _num("jump_buffer", 0.12)
	else:
		_buffer -= delta
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -_num("jump_velocity", 1050.0)
		_buffer = 0.0
		_coyote = 0.0
		_jump_t = 0.0
		# A buffered tap may already be released by the time the jump starts.
		_cut_pending = not Input.is_action_pressed("jump")
		puppet.jumped()
		fatigue.on_jump()
		Sfx.play("jump", global_position)
		Sfx.play("vo_jump", global_position)
		Fx.burst(get_parent(), global_position, Color(0.5, 0.4, 0.35, 0.6), 10, 90.0, false, 0.4)
	_update_jump_cut(delta)

	if dir != 0.0 and _strike_t < 0.0:
		facing = 1 if dir > 0.0 else -1
	if controls_enabled and Input.is_action_just_pressed("attack"):
		strike()
	_fall_speed = velocity.y
	move_and_slide()
	_after_move(delta)


## Variable jump height: letting go early trims the rise, but never below the height
## reached by holding for `jump_min_hold` seconds.
func _update_jump_cut(delta: float) -> void:
	if _jump_t < 0.0:
		return
	if velocity.y >= 0.0:
		_jump_t = -1.0
		_cut_pending = false
		return
	_jump_t += delta
	if Input.is_action_just_released("jump"):
		_cut_pending = true
	if _cut_pending and _jump_t >= _num("jump_min_hold", 0.13):
		velocity.y *= _num("jump_cut", 0.7)
		_jump_t = -1.0
		_cut_pending = false


## Height of a jump released after `hold` seconds (a long hold gives the full apex).
## Mirrors _update_jump_cut; the level tests use it to keep step-ups tap-friendly.
static func jump_rise(cfg: Dictionary, hold: float) -> float:
	var g := float(cfg.get("gravity", 2400.0))
	var v := float(cfg.get("jump_velocity", 1050.0))
	var t := maxf(hold, float(cfg.get("jump_min_hold", 0.13)))
	if t >= v / g:
		return v * v / (2.0 * g)
	var risen := v * t - 0.5 * g * t * t
	var v_cut := (v - g * t) * float(cfg.get("jump_cut", 0.7))
	return risen + v_cut * v_cut / (2.0 * g)


func _after_move(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and _fall_speed > 200.0:
		puppet.landed(_fall_speed)
		Sfx.play("land_heavy" if _fall_speed > 1100.0 else "land", global_position)
		if _fall_speed > 700.0:
			Fx.burst(get_parent(), global_position, Color(0.5, 0.4, 0.35, 0.6), 14, 140.0, false, 0.45)
	_was_on_floor = on_floor
	if on_floor and absf(velocity.x) > 60.0:
		_step_acc += absf(velocity.x) * delta
		if _step_acc >= STEP_DISTANCE:
			_step_acc = 0.0
			Sfx.play("footstep", global_position)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	shield_time = maxf(0.0, shield_time - delta)
	_strike_cool = maxf(0.0, _strike_cool - delta)
	_update_strike(delta)
	_update_prana(delta)
	_update_breath(delta, on_floor)
	_update_scream(delta, on_floor)


func _update_prana(delta: float) -> void:
	_since_cast += delta
	if prana < max_prana and _since_cast >= _num("prana_regen_delay", 1.5):
		add_prana(_num("prana_regen", 3.0) * delta)


## When he is really tired (Fatigue: a long non-stop run, a fight, many jumps close
## together) and stops, he bends over and catches his breath. Rare by design. Standing
## still he breathes softly. Small, but it makes the puppet feel alive.
func _update_breath(delta: float, on_floor: bool) -> void:
	var speed := absf(velocity.x)
	if not on_floor:
		fatigue.update(delta, "air")
		_idle_time = 0.0
	elif speed > 200.0:
		fatigue.update(delta, "run")
		_idle_time = 0.0
	else:
		fatigue.update(delta, "rest")
		if speed < 20.0:
			if _pant_left == 0 and fatigue.wants_pant():
				_pant_left = 1
				_pant_timer = PANT_TIME
				fatigue.panted()
				puppet.pant(PANT_TIME)
				GameLog.info("player", "tired", {"x": int(global_position.x)})
			_idle_time += delta
		else:
			_idle_time = 0.0
	if _pant_left > 0:
		_pant_timer -= delta
		if _pant_timer <= 0.0 or speed > 60.0:
			_pant_left = 0
			puppet.relax()
	var breathe := _idle_time > 0.6 and _pant_left == 0 and alive
	_breathing = breathe


func is_panting() -> bool:
	return _pant_left > 0


## Every breath of the chest animation (Puppet.breathed) has a sound: quick "hah"
## pants when tired, fading a little as he recovers; soft breaths at rest.
func _on_breathed(inhale: bool) -> void:
	if not alive:
		return
	if _pant_left > 0:
		var fade := -6.0 * (1.0 - _pant_timer / PANT_TIME)
		Sfx.play("pant_in" if inhale else "pant_out", global_position, fade)
	# No sound for resting breaths (owner: remove the idle breathing sound).


## The fall scream is for a fall into a pit, never for a jump that lands: it plays at
## most once per fall, and only when no reachable arc lands on anything.
func _update_scream(delta: float, on_floor: bool) -> void:
	if on_floor:
		_screamed = false
		_scream_check = 0.0
		return
	if _screamed or velocity.y < 450.0:
		return
	_scream_check -= delta
	if _scream_check > 0.0:
		return
	_scream_check = 0.1
	if _doomed():
		_screamed = true
		Sfx.play("vo_fall", global_position)


## True when every arc the hero can still steer (drift as now, full left, full right)
## falls past the kill plane without meeting a floor. Rays hit ledges and platforms on
## the world layer; a wall in the way ends that arc.
func _doomed() -> bool:
	if level == null:
		return false
	var kill := level.kill_plane()
	var space := get_world_2d().direct_space_state
	var g := _num("gravity", 2400.0) * _num("fall_gravity_mult", 1.4)
	var run := _num("run_speed", 330.0)
	var step := 0.05
	for vx in [velocity.x, -run, run]:
		var p := global_position
		var v := Vector2(vx, velocity.y)
		var t := 0.0
		var blocked := false
		while t < 2.5 and p.y < kill and not blocked:
			v.y = minf(v.y + g * step, _num("max_fall", 1300.0))
			var next := p + v * step
			for off in [-12.0, 12.0]:
				var q := PhysicsRayQueryParameters2D.create(p + Vector2(off, -4.0), next + Vector2(off, 0.0), 1)
				var hit := space.intersect_ray(q)
				if hit.is_empty():
					continue
				var normal: Vector2 = hit["normal"]
				if normal.y < -0.5:
					return false
				blocked = true
			p = next
			t += step
	return true


func _process(delta: float) -> void:
	puppet.face(facing)
	puppet.animate(delta, velocity.x / _num("run_speed", 330.0), is_on_floor(), velocity.y)
	_shield.visible = shield_time > 0.0
	_shield.rotation += delta * 2.5
	if alive:
		var blink := _invulnerable > 0.0 and fmod(_invulnerable, 0.16) < 0.08
		puppet.modulate.a = 0.45 if blink else 1.0


func hitbox() -> Rect2:
	return Rect2(global_position + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


## Staff swing. Hits each guard in reach once per swing.
func strike() -> void:
	if not alive or _strike_cool > 0.0:
		return
	_strike_cool = STRIKE_COOLDOWN
	_strike_t = 0.0
	_struck.clear()
	fatigue.on_strike()
	puppet.strike()
	Sfx.play("strike_swing", global_position)


func _update_strike(delta: float) -> void:
	if _strike_t < 0.0:
		return
	_strike_t += delta
	if _strike_t > STRIKE_WINDOW.y:
		_strike_t = -1.0
		return
	if _strike_t < STRIKE_WINDOW.x or level == null:
		return
	var reach := Rect2(global_position + Vector2(-10.0 if facing > 0 else -STRIKE_REACH, -100.0), Vector2(STRIKE_REACH + 10.0, 95.0))
	for b in get_tree().get_nodes_in_group("bolts"):
		if reach.has_point(b.global_position):
			b.pop()
			Sfx.play("strike_hit", b.global_position, -4.0, 1.3)
	for e in level.enemies():
		if _struck.has(e) or not e.is_alive():
			continue
		if reach.intersects(e.hitbox()):
			_struck.append(e)
			e.damage(1, global_position.x, "strike")
			Sfx.play("strike_hit", e.global_position)
			Fx.burst(get_parent(), e.global_position + Vector2(0, -60), Color(1.0, 0.85, 0.55), 14, 220.0)
			Game.vibrate(30)


## The level is won: control is taken away and nothing can hurt him any more.
func enter_gate(x: float) -> void:
	finishing = true
	controls_enabled = false
	_walk_to = x
	_strike_t = -1.0
	_pant_left = 0
	puppet.relax()


func at_gate() -> bool:
	return finishing and absf(global_position.x - _walk_to) < 8.0 and is_on_floor()


func _walk_into_gate(delta: float) -> void:
	var dx := _walk_to - global_position.x
	var want := 0.0
	if absf(dx) > 6.0:
		want = signf(dx) * _num("run_speed", 330.0) * 0.55
		facing = 1 if dx > 0.0 else -1
	velocity.x = move_toward(velocity.x, want, _num("ground_accel", 2600.0) * delta)
	velocity.y = minf(velocity.y + _num("gravity", 2400.0) * delta, _num("max_fall", 1300.0))
	move_and_slide()
	_was_on_floor = is_on_floor()


## UDAAN: a strong burst of lift (about 1.6x a full jump), usable in mid-air, then a
## glide of `glide` seconds once the leap tops out: he sinks slowly and can steer.
## Releasing the jump pad never trims it.
func udaan(lift: float, glide: float = 0.0) -> void:
	velocity.y = -lift
	_coyote = 0.0
	_jump_t = -1.0
	_cut_pending = false
	_glide = glide if glide > 0.0 else -1.0
	puppet.jumped()
	fatigue.on_jump()
	_wings.lift()
	Sfx.play("udaan_whoosh", global_position)
	_udaan_ring()


## True while the glide after an UDAAN leap holds him up.
func gliding() -> bool:
	return _glide > 0.0 and velocity.y >= -40.0 and alive and not finishing


func _update_glide(delta: float, on_floor: bool) -> void:
	if _glide < 0.0:
		return
	if on_floor and velocity.y >= 0.0:
		_end_glide()
		return
	if not gliding():
		return
	if not _wings.spread:
		_wings.glide()
		Sfx.play("glide_wind", global_position)
	_glide -= delta
	if _glide <= 0.0:
		_end_glide()


func _end_glide() -> void:
	_glide = -1.0
	if _wings != null:
		_wings.fold()


## Height an UDAAN leap adds when cast at the top of a jump (vy = 0), in px.
static func udaan_rise(lift: float, cfg: Dictionary) -> float:
	return lift * lift / (2.0 * float(cfg.get("gravity", 2400.0)))


## Glide after UDAAN: x = distance covered at full steer, y = height lost doing it.
static func glide_reach(glide: float, cfg: Dictionary) -> Vector2:
	return Vector2(float(cfg.get("run_speed", 330.0)) * glide, GLIDE_FALL * glide)


## A flat ring of pale light that spreads from his feet as he leaps.
func _udaan_ring() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ring := Line2D.new()
	ring.points = Fx.ellipse(Vector2.ZERO, Vector2(1.0, 0.3), 32)
	ring.closed = true
	ring.width = 0.05
	ring.default_color = Color(0.86, 0.8, 1.0, 0.9)
	ring.position = global_position
	ring.scale = Vector2.ONE * 20.0
	ring.z_index = 6
	parent.add_child(ring)
	var t := ring.create_tween().set_parallel()
	t.tween_property(ring, "scale", Vector2.ONE * 110.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(ring, "modulate:a", 0.0, 0.45)
	t.chain().tween_callback(ring.queue_free)


func take_hit(from_x: float) -> void:
	if not alive or finishing or _invulnerable > 0.0 or shield_time > 0.0:
		return
	hearts = LifeRules.after_hit(hearts)
	hearts_changed.emit(hearts, max_hearts)
	heart_delta.emit(-1)
	_invulnerable = _num("invulnerable_after_hit", 1.2)
	_end_glide()
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 380.0, -420.0)
	puppet.hit(away)
	Sfx.play("hurt", global_position)
	Sfx.play("vo_hurt", global_position)
	Services.analytics.log_event("player_hit", {"x": int(global_position.x), "hearts": hearts,
		"level": level.level_id if level != null else ""})
	Game.vibrate(70)
	if LifeRules.is_game_over(hearts):
		die("hit")


func die(cause: String) -> void:
	if not alive or finishing:
		return
	alive = false
	velocity = Vector2.ZERO
	_end_glide()
	Fx.burst(get_parent(), global_position + Vector2(0, -45), Color(0.95, 0.4, 0.6), 30, 240.0)
	if cause != "fall":
		puppet.shatter(get_parent(), global_position.y)
	else:
		puppet.visible = false
	Sfx.play("death", global_position)
	if cause != "fall":
		Sfx.play("vo_death", global_position)
	_breathing = false
	Game.vibrate(120)
	died.emit(cause)


## A pit fall costs a heart (the level respawns him while any are left).
func lose_heart() -> void:
	hearts = LifeRules.after_fall(hearts)
	hearts_changed.emit(hearts, max_hearts)
	heart_delta.emit(-1)


## The rare heart pickup. Returns false (and the pickup stays) at full health.
func heal(amount: int = 1) -> bool:
	if not alive or hearts >= max_hearts:
		return false
	hearts = LifeRules.after_heal(hearts, max_hearts, amount)
	hearts_changed.emit(hearts, max_hearts)
	heart_delta.emit(1)
	return true


## Back at the last lamp. Hearts are NOT refilled (owner rule: healing is rare); prana
## is, so traversal mantras can always be cast again.
func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	alive = true
	shield_time = 0.0
	_invulnerable = 1.0
	_strike_t = -1.0
	_jump_t = -1.0
	_cut_pending = false
	_screamed = false
	_end_glide()
	_pant_left = 0
	puppet.restore()
	prana = max_prana
	prana_changed.emit(prana, max_prana)
	hearts_changed.emit(hearts, max_hearts)
	Sfx.play("respawn", global_position)


func _make_shield() -> Node2D:
	var root := Node2D.new()
	root.position = Vector2(0, -48)
	root.visible = false
	root.z_index = 40
	var ring := Line2D.new()
	ring.points = Fx.ellipse(Vector2.ZERO, Vector2(62, 62), 32)
	ring.closed = true
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.86, 0.5, 0.85)
	ring.material = Fx.additive()
	root.add_child(ring)
	root.add_child(Fx.glow(Color(1.0, 0.8, 0.45, 0.25), 75.0))
	for i in 6:
		var mote := Fx.glow(Color(1.0, 0.9, 0.6), 7.0)
		mote.position = Vector2.from_angle(TAU * i / 6.0) * 62.0
		root.add_child(mote)
	return root
