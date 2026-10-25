class_name MantraCaster
extends Node
## Turns recognized gestures into mantra effects. Which sign casts which mantra, and
## which mantras are learned, comes from the Grimoire; every number from mantras.json.

signal cast(id: String)
signal failed(reason: String, detail: String)

var level: Level
var cfg: Dictionary
var grimoire: Grimoire

var _cooldowns := {}


func _process(delta: float) -> void:
	for id in _cooldowns:
		_cooldowns[id] = maxf(0.0, float(_cooldowns[id]) - delta)


## 0 = ready, 1 = just cast.
func cooldown_ratio(id: String) -> float:
	var total := float(cfg.get(id, {}).get("cooldown", 1.0))
	return clampf(float(_cooldowns.get(id, 0.0)) / maxf(total, 0.01), 0.0, 1.0)


func try_gesture(result: Dictionary) -> void:
	var gesture: String = result.get("name", "")
	if gesture == "":
		var closest := grimoire.mantra_for(str(result.get("closest", "")))
		failed.emit("unrecognized", closest)
		Services.analytics.log_event("gesture_unrecognized", {"score": snappedf(float(result.get("score", 0.0)), 0.01),
			"closest": closest, "level": level.level_id})
		return
	var id := grimoire.mantra_for(gesture)
	if id == "":
		failed.emit("unknown", gesture)
		return
	if not grimoire.is_learned(id):
		failed.emit("locked", id)
		Services.analytics.log_event("locked_mantra_drawn", {"id": id, "level": level.level_id})
		return
	if float(_cooldowns.get(id, 0.0)) > 0.0:
		failed.emit("cooldown", id)
		return
	var problem := _execute(id, cfg[id], result)
	if problem != "":
		failed.emit(problem, id)
		return
	_cooldowns[id] = float(cfg[id].get("cooldown", 1.0))
	cast.emit(id)
	Sfx.play("cast_" + id, level.player.global_position)
	Services.analytics.log_event("mantra_cast", {"id": id, "level": level.level_id})


## Returns "" on success, otherwise a failure reason.
func _execute(id: String, m: Dictionary, result: Dictionary) -> String:
	var p := level.player
	if p == null or not p.alive:
		return "dead"
	var color := GameConfig.color(m.get("color", ""), Color(1, 0.8, 0.4))
	match id:
		"setu":
			var problem := _cast_bridge(m, result, color)
			if problem != "":
				return problem
		"chhaya":
			var decoy := MayaDecoy.new()
			decoy.dir = p.facing
			decoy.speed = float(m.get("speed", 240.0))
			decoy.life = float(m.get("duration", 4.0))
			decoy.position = p.global_position
			level.world.add_child(decoy)
		"jwala":
			var bolt := JwalaBolt.new()
			bolt.dir = p.facing
			bolt.speed = float(m.get("speed", 950.0))
			bolt.max_range = float(m.get("range", 900.0))
			bolt.color = color
			bolt.position = p.global_position + Vector2(p.facing * 26.0, -55.0)
			level.world.add_child(bolt)
		"udaan":
			p.udaan(float(m.get("lift", 1050.0)))
		"kavach":
			p.shield_time = float(m.get("duration", 3.0))
		"drishti":
			level.reveal_maya(float(m.get("duration", 5.0)))
		"tarang":
			_cast_wave(m, color)
		"bandhan":
			var radius := float(m.get("radius", 300.0))
			for e in level.enemies():
				if e.global_position.distance_to(p.global_position) <= radius:
					e.bind(float(m.get("duration", 3.5)))
			_ring(p.global_position + Vector2(0, -40), radius, color)
		_:
			return "unknown"
	p.puppet.cast()
	Fx.burst(level.world, p.global_position + Vector2(p.facing * 20.0, -60.0), color, 16, 160.0)
	Game.vibrate(25)
	return ""


## SETU follows the stroke: same place, length and slope as drawn, within limits.
func _cast_bridge(m: Dictionary, result: Dictionary, color: Color) -> String:
	var p := level.player
	var a := level.screen_to_world(result.get("start", Vector2.ZERO))
	var b := level.screen_to_world(result.get("end", Vector2.ZERO))
	# Build outward from whichever end is nearer the hero.
	if b.distance_to(p.global_position) < a.distance_to(p.global_position):
		var swap := a
		a = b
		b = swap
	var dir := (b - a).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(p.facing, 0)
	var length := clampf(a.distance_to(b), float(m.get("min_length", 80.0)), float(m.get("max_length", 540.0)))
	b = a + dir * length
	var nearest := Geometry2D.get_closest_point_to_segment(p.global_position + Vector2(0, -40), a, b)
	if nearest.distance_to(p.global_position + Vector2(0, -40)) > float(m.get("reach", 700.0)):
		return "far"
	var bridge := LightBridge.new()
	bridge.from = a
	bridge.to = b
	bridge.life = float(m.get("duration", 5.0))
	bridge.color = color
	level.world.add_child(bridge)
	return ""


func _cast_wave(m: Dictionary, color: Color) -> void:
	var p := level.player
	var radius := float(m.get("radius", 260.0))
	for e in level.enemies():
		if e.global_position.distance_to(p.global_position) <= radius:
			e.push(p.global_position, float(m.get("force", 620.0)))
	for w in level.get_tree().get_nodes_in_group("shatterable"):
		if absf(w.global_position.x - p.global_position.x) <= radius + 40.0 and absf(w.global_position.y - p.global_position.y) < 260.0:
			w.shatter()
	_ring(p.global_position + Vector2(0, -40), radius, color)


## Expanding ring of light that shows a mantra's area.
func _ring(center: Vector2, radius: float, color: Color) -> void:
	var ring := Line2D.new()
	ring.points = Fx.ellipse(Vector2.ZERO, Vector2.ONE, 40)
	ring.closed = true
	ring.width = 0.05
	ring.default_color = color
	ring.material = Fx.additive()
	ring.position = center
	ring.scale = Vector2.ONE * 20.0
	ring.z_index = 45
	level.world.add_child(ring)
	var t := ring.create_tween().set_parallel()
	t.tween_property(ring, "scale", Vector2.ONE * radius, 0.35).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.45)
	t.chain().tween_callback(ring.queue_free)
