extends "res://tests/test_case.gd"
## Guards the data files: everything referenced must exist, and every level must be
## physically completable with the player's jump and the mantras known by then.

const JUMP_RISE := 150.0  # tallest step-up a plain jump is trusted with (apex is ~160)
const UDAAN_RISE := 380.0  # jump, then UDAAN at the top (apex is ~400)
const SETU_MAX_SLOPE := 40.0
const ENEMY_TYPES := ["soldier", "archer"]
const MAX_PROMPT_WORDS := 6


func _jump_distance(player: Dictionary) -> float:
	var g := float(player["gravity"])
	var v := float(player["jump_velocity"])
	var up := v / g
	var height := v * v / (2.0 * g)
	var down := sqrt(2.0 * height / (g * float(player["fall_gravity_mult"])))
	return float(player["run_speed"]) * (up + down)


## Horizontal distance of a running jump that lands `rise` px higher (negative: lower).
## `lift` is UDAAN's extra upward speed, cast at the apex (0 for a plain jump).
## Returns -1 when the height cannot be reached. Keeps a 10% margin like the gap test.
func _reach(player: Dictionary, rise: float, lift: float) -> float:
	var g := float(player["gravity"])
	var v := float(player["jump_velocity"])
	var apex := v * v / (2.0 * g) + lift * lift / (2.0 * g)
	if rise > apex - 8.0:
		return -1.0
	var t_up := (v + lift) / g
	var t_down := sqrt(2.0 * (apex - rise) / (g * float(player["fall_gravity_mult"])))
	return float(player["run_speed"]) * (t_up + t_down) * 0.9


func _levels_in_order() -> Array[String]:
	var out: Array[String] = []
	for ch in GameConfig.read("game")["chapters"]:
		for id in ch["levels"]:
			out.append(str(id))
	return out


func _known_before_each_level() -> Dictionary:
	var out := {}
	var known: Array = []
	for id in _levels_in_order():
		known.append_array(GameConfig.level(id).get("teaches", []))
		out[id] = known.duplicate()
	return out


func test_configs_parse() -> void:
	for name in ["game", "player", "mantras", "story"]:
		check(not GameConfig.read(name).is_empty(), name + ".json parses")


func test_references_exist() -> void:
	var game := GameConfig.read("game")
	var story := GameConfig.read("story")
	var mantras := GameConfig.read("mantras")
	for ch in game["chapters"]:
		check(story.has(ch["story"]), "story %s exists" % ch["story"])
		for id in ch["levels"]:
			var level := GameConfig.level(id)
			check(not level.is_empty(), "level %s exists" % id)
			for m in level.get("teaches", []):
				check(mantras.has(m), "%s: mantra %s exists" % [id, m])
			for p in level.get("prompts", []):
				if p.has("glyph"):
					check(GlyphShapes.NAMES.has(p["glyph"]), "%s: prompt glyph %s exists" % [id, p["glyph"]])
	var levels := _levels_in_order()
	for id in mantras:
		var m: Dictionary = mantras[id]
		check(GlyphShapes.NAMES.has(m["gesture"]), "mantra %s has a known gesture" % id)
		check(str(m.get("description", "")) != "", "mantra %s has a description" % id)
		var unlock: Dictionary = m.get("unlock", {})
		check(unlock.has("level") or unlock.has("cost"), "mantra %s can be unlocked" % id)
		if unlock.has("level"):
			check(levels.has(unlock["level"]), "mantra %s taught in an existing level" % id)
			check(GameConfig.level(unlock["level"]).get("teaches", []).has(id), "level %s teaches %s" % [unlock["level"], id])
		if unlock.has("after"):
			check(levels.has(unlock["after"]), "mantra %s unlock level exists" % id)


func test_mantra_gestures_are_unique() -> void:
	var seen := {}
	var mantras := GameConfig.read("mantras")
	for id in mantras:
		var g: String = mantras[id]["gesture"]
		check(not seen.has(g), "gesture %s used twice" % g)
		seen[g] = true


func test_levels_are_completable() -> void:
	var player := GameConfig.read("player")
	var mantras := GameConfig.read("mantras")
	var jump := _jump_distance(player) * 0.9  # keep a margin; perfect jumps are not fair
	var known: Array = []
	for id in _levels_in_order():
		var level := GameConfig.level(id)
		known.append_array(level.get("teaches", []))
		var spans: Array = []
		for g in level["ground"]:
			spans.append(Vector2(float(g[0]), float(g[0]) + float(g[2])))
		for key in ["platforms", "crumble"]:
			for p in level.get(key, []):
				spans.append(Vector2(float(p[0]), float(p[0]) + float(p[2])))
		# A moving platform can be boarded anywhere along its travel.
		for m in level.get("moving", []):
			var x := float(m["x"])
			var dx := float(m.get("dx", 0))
			spans.append(Vector2(minf(x, x + dx), maxf(x, x + dx) + float(m["w"])))
		if known.has("drishti"):
			for p in level.get("maya_hidden", []):
				spans.append(Vector2(float(p[0]), float(p[0]) + float(p[2])))
		spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var bridge := float(mantras["setu"]["max_length"]) if known.has("setu") else 0.0
		var reach: float = spans[0].y
		for s in spans:
			var gap: float = s.x - reach
			if gap > jump:
				check(gap <= bridge + jump, "%s: gap of %d px at x=%d cannot be crossed" % [id, gap, reach])
			reach = maxf(reach, s.y)
		var goal := GameConfig.vec(level["goal"])
		check(goal.x <= reach, "%s: goal sits on ground" % id)


# --- Two-dimensional reachability -------------------------------------------------
# Every standable surface becomes a node; an edge exists when the hero can get from
# one to the other with a jump, JUMP + UDAAN, or a SETU bridge (ramps up to 40°).
# Moving platforms count with their whole travel box, as the player can wait.
# Cracked walls (TARANG only) split the ground they stand on and block the path.


func _surfaces(level: Dictionary, known: Array, tarang: bool) -> Array:
	var out: Array = []
	for g in level.get("ground", []):
		out.append({"x0": float(g[0]), "x1": float(g[0]) + float(g[2]), "top": float(g[1]), "low": float(g[1])})
	var keys := ["platforms", "crumble"]
	if known.has("drishti"):
		keys.append("maya_hidden")
	for key in keys:
		for p in level.get(key, []):
			out.append({"x0": float(p[0]), "x1": float(p[0]) + float(p[2]), "top": float(p[1]), "low": float(p[1])})
	for m in level.get("moving", []):
		var x := float(m["x"])
		var y := float(m["y"])
		var dx := float(m.get("dx", 0))
		var dy := float(m.get("dy", 0))
		out.append({"x0": minf(x, x + dx), "x1": maxf(x, x + dx) + float(m["w"]),
			"top": minf(y, y + dy), "low": maxf(y, y + dy)})
	if tarang:
		return out
	for c in level.get("cracked", []):
		var cx := float(c[0])
		var base := float(c[1])
		var split: Array = []
		for s in out:
			if absf(float(s["low"]) - base) < 2.0 and float(s["x0"]) < cx and cx < float(s["x1"]):
				split.append({"x0": s["x0"], "x1": cx - 23.0, "top": s["top"], "low": s["low"]})
				split.append({"x0": cx + 23.0, "x1": s["x1"], "top": s["top"], "low": s["low"]})
			else:
				split.append(s)
		out = split
	return out


## Things a jump has to clear: rock columns and (without TARANG) cracked walls.
func _obstacles(level: Dictionary, tarang: bool) -> Array:
	var out: Array = []
	for g in level.get("ground", []):
		out.append({"x0": float(g[0]), "x1": float(g[0]) + float(g[2]), "top": float(g[1])})
	if not tarang:
		for c in level.get("cracked", []):
			out.append({"x0": float(c[0]) - 23.0, "x1": float(c[0]) + 23.0, "top": float(c[1]) - float(c[2])})
	return out


func _can_move(a: Dictionary, b: Dictionary, obstacles: Array, player: Dictionary, known: Array, lift: float,
		setu_len: float) -> bool:
	var ax0 := float(a["x0"])
	var ax1 := float(a["x1"])
	var bx0 := float(b["x0"])
	var bx1 := float(b["x1"])
	var dx := maxf(0.0, maxf(bx0 - ax1, ax0 - bx1))
	var rise := float(a["top"]) - float(b["low"])  # best case: leave from A's highest, land on B's lowest
	var limit := UDAAN_RISE if known.has("udaan") else JUMP_RISE
	if dx > 0.0:
		var lo := ax1 if bx0 >= ax1 else bx1
		var hi := bx0 if bx0 >= ax1 else ax0
		for o in obstacles:
			if float(o["x1"]) > lo + 1.0 and float(o["x0"]) < hi - 1.0:
				var top := float(o["top"])
				if top < float(a["top"]) - limit and top < float(b["low"]):
					return false
	if rise <= JUMP_RISE and dx <= _reach(player, rise, 0.0):
		return true
	if known.has("udaan") and rise <= UDAAN_RISE and dx <= _reach(player, rise, lift):
		return true
	if known.has("setu"):
		# The bridge climbs what a jump cannot, at up to 40°; a jump covers the rest.
		var jump_rise := minf(rise, 140.0)
		var need := maxf(0.0, rise - 140.0)
		var run := maxf(need / tan(deg_to_rad(SETU_MAX_SLOPE)), dx - maxf(0.0, _reach(player, jump_rise, 0.0)))
		if sqrt(run * run + need * need) <= setu_len:
			return true
	return false


func _surface_at(surfaces: Array, p: Vector2) -> int:
	for i in surfaces.size():
		var s: Dictionary = surfaces[i]
		if p.x >= float(s["x0"]) - 4.0 and p.x <= float(s["x1"]) + 4.0 \
				and p.y >= float(s["top"]) - 40.0 and p.y <= float(s["low"]) + 40.0:
			return i
	return -1


func _reachable(level: Dictionary, surfaces: Array, known: Array, tarang: bool) -> Dictionary:
	var player := GameConfig.read("player")
	var mantras := GameConfig.read("mantras")
	var lift := float(mantras["udaan"]["lift"])
	var setu_len := float(mantras["setu"]["max_length"]) if known.has("setu") else 0.0
	var obstacles := _obstacles(level, tarang)
	var seen := {}
	var start := _surface_at(surfaces, GameConfig.vec(level["spawn"]))
	if start < 0:
		return seen
	var queue: Array = [start]
	seen[start] = true
	while not queue.is_empty():
		var i: int = queue.pop_front()
		for j in surfaces.size():
			if not seen.has(j) and _can_move(surfaces[i], surfaces[j], obstacles, player, known, lift, setu_len):
				seen[j] = true
				queue.append(j)
	return seen


func test_levels_are_reachable_in_2d() -> void:
	var known_by := _known_before_each_level()
	var all_mantras: Array = GameConfig.read("mantras").keys()
	for id in _levels_in_order():
		var level := GameConfig.level(id)
		var known: Array = known_by[id]
		var surfaces := _surfaces(level, known, false)
		var seen := _reachable(level, surfaces, known, false)
		check(_surface_at(surfaces, GameConfig.vec(level["spawn"])) >= 0, "%s: spawn stands on a surface" % id)
		var goal := _surface_at(surfaces, GameConfig.vec(level["goal"]))
		check(goal >= 0 and seen.has(goal), "%s: goal reachable with taught mantras only" % id)
		for c in level.get("checkpoints", []):
			var cp := _surface_at(surfaces, GameConfig.vec(c))
			check(cp >= 0 and seen.has(cp), "%s: checkpoint %s reachable" % [id, str(c)])
		# Embers may need bought mantras (replays), but must be reachable with everything.
		var full := _surfaces(level, all_mantras, true)
		var full_seen := _reachable(level, full, all_mantras, true)
		for e in level.get("embers", []):
			var p := GameConfig.vec(e)
			var ok := false
			for i in full_seen:
				var s: Dictionary = full[i]
				# 320 px sideways: a SETU bridge can carry the hero out over a pit.
				if p.x >= float(s["x0"]) - 320.0 and p.x <= float(s["x1"]) + 320.0 \
						and p.y >= float(s["top"]) - 440.0 and p.y <= float(s["low"]) + 60.0:
					ok = true
					break
			check(ok, "%s: ember at %s reachable" % [id, str(e)])


# --- Sanity checks for level data ---------------------------------------------------


func _on_surface(level: Dictionary, keys: Array, x0: float, x1: float, y: float) -> bool:
	for key in keys:
		for s in level.get(key, []):
			if absf(float(s[1]) - y) < 2.0 and x0 >= float(s[0]) - 1.0 and x1 <= float(s[0]) + float(s[2]) + 1.0:
				return true
	return false


func _is_triple_list(value) -> bool:
	if not value is Array:
		return false
	for v in value:
		if not v is Array or v.size() != 3:
			return false
		for n in v:
			if not (n is float or n is int):
				return false
	return true


func test_level_data_is_sane() -> void:
	for id in _levels_in_order():
		var level := GameConfig.level(id)
		var size := GameConfig.vec(level.get("size"))
		var kill_y := float(level.get("kill_y", 1000.0))
		for key in ["ground", "platforms", "crumble", "spikes", "maya_false", "maya_hidden", "cracked", "barriers"]:
			if level.has(key):
				check(_is_triple_list(level[key]), "%s: %s entries are [x, y, n]" % [id, key])
		check(["ember", "marsh", "palace"].has(str(level.get("palette", ""))), "%s: known palette" % id)

		var checkpoints: Array = level.get("checkpoints", [])
		check(checkpoints.size() >= 3, "%s: at least 3 checkpoints" % id)
		var embers: Array = level.get("embers", [])
		check(embers.size() >= 10 and embers.size() <= 12, "%s: 10-12 embers (has %d)" % [id, embers.size()])
		for e in embers + level.get("orbs", []) + checkpoints:
			var p := GameConfig.vec(e)
			check(p.x > 0.0 and p.x < size.x and p.y > -900.0 and p.y < kill_y, "%s: %s inside the level" % [id, str(e)])

		for p in level.get("prompts", []):
			var words := str(p.get("text", "")).split(" ", false).size()
			check(words <= MAX_PROMPT_WORDS, "%s: prompt '%s' has %d words" % [id, p.get("text", ""), words])

		for s in level.get("spikes", []):
			var x0 := float(s[0])
			check(_on_surface(level, ["ground"], x0, x0 + float(s[2]), float(s[1])), "%s: spikes at x=%d lie on ground" % [id, x0])
			for c in checkpoints + [level["spawn"], level["goal"]]:
				var p := GameConfig.vec(c)
				check(p.x < x0 - 60.0 or p.x > x0 + float(s[2]) + 60.0 or absf(p.y - float(s[1])) > 2.0,
					"%s: %s is clear of spikes" % [id, str(c)])

		for j in level.get("jets", []):
			check(j is Dictionary and j.has("x") and j.has("y") and j.has("interval") and j.has("on"), "%s: jet has x, y, interval, on" % id)
			var jx := float(j.get("x", 0))
			var jy := float(j.get("y", 0))
			check(jx > 0.0 and jx < size.x and jy - 220.0 > -900.0 and jy < kill_y, "%s: jet at x=%d inside the level" % [id, jx])
			check(_on_surface(level, ["ground", "platforms"], jx - 20.0, jx + 20.0, jy), "%s: jet at x=%d stands on a surface" % [id, jx])
			check(float(j.get("on", 0)) > 0.0 and float(j.get("on", 0)) < float(j.get("interval", 0)) - 0.5,
				"%s: jet at x=%d leaves a safe window" % [id, jx])
			for c in checkpoints + [level["spawn"]]:
				check(absf(GameConfig.vec(c).x - jx) > 80.0, "%s: %s is clear of the jet at x=%d" % [id, str(c), jx])

		for m in level.get("moving", []):
			check(m is Dictionary and m.has("x") and m.has("y") and m.has("w") and m.has("period"), "%s: moving platform has x, y, w, period" % id)
			var period := float(m.get("period", 0))
			check(period >= 2.0 and period <= 5.0, "%s: moving platform at x=%d period 2-5 s" % [id, float(m.get("x", 0))])
			check(float(m.get("w", 0)) >= 100.0, "%s: moving platform at x=%d at least 100 px wide" % [id, float(m.get("x", 0))])

		for e in level.get("enemies", []):
			var kind := str(e.get("type", "soldier"))
			var ex := float(e.get("x", 0))
			var ey := float(e.get("y", 600))
			check(ENEMY_TYPES.has(kind), "%s: enemy type %s known" % [id, kind])
			check(int(e.get("hp", 3)) >= 1 and int(e.get("hp", 3)) <= 5, "%s: enemy at x=%d hp 1-5" % [id, ex])
			# Respawning must never drop the hero straight into an attack.
			for c in checkpoints + [level["spawn"]]:
				var cp := GameConfig.vec(c)
				if kind == "archer":
					check(cp.distance_to(Vector2(ex, ey)) > 650.0, "%s: %s out of range of the archer at x=%d" % [id, str(c), ex])
				elif absf(cp.y - ey) < 160.0:
					var near := clampf(cp.x, float(e.get("min", ex)), float(e.get("max", ex)))
					check(absf(cp.x - near) >= 200.0, "%s: %s at least 200 px from the patrol of the soldier at x=%d" % [id, str(c), ex])
			if kind == "archer":
				check(_on_surface(level, ["ground", "platforms"], ex - 10.0, ex + 10.0, ey), "%s: archer at x=%d stands on a surface" % [id, ex])
			else:
				var lo := float(e.get("min", ex - 200))
				var hi := float(e.get("max", ex + 200))
				check(lo <= ex and ex <= hi, "%s: soldier at x=%d starts inside its patrol" % [id, ex])
				# Chasing carries a soldier LEASH px past his patrol; he must not walk off.
				check(_on_surface(level, ["ground", "platforms"], lo - Smokebound.LEASH, hi + Smokebound.LEASH, ey),
					"%s: soldier at x=%d stays on one surface while chasing" % [id, ex])
