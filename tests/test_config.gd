extends "res://tests/test_case.gd"
## Guards the data files: everything referenced must exist, and every level must be
## physically completable with the player's jump and the mantras known by then.

## Tallest step-up a plain jump is trusted with. A quick tap on the touch pad rises
## ~172 px and a held jump ~230 px, so every required step-up works with a sloppy tap.
const JUMP_RISE := 170.0
## Jump, then UDAAN at the top: apex ~598 px (230 jump + 368 leap); 58 px margin.
## test_udaan_physics keeps this in step with mantras.json.
const UDAAN_RISE := 540.0
const SETU_MAX_SLOPE := 40.0
const ENEMY_TYPES := ["soldier", "archer", "brute"]
const MAX_PROMPT_WORDS := 6


func _jump_distance(player: Dictionary) -> float:
	var g := float(player["gravity"])
	var v := float(player["jump_velocity"])
	var up := v / g
	var height := v * v / (2.0 * g)
	var down := sqrt(2.0 * height / (g * float(player["fall_gravity_mult"])))
	return float(player["run_speed"]) * (up + down)


## Horizontal distance of a running jump that lands `rise` px higher (negative: lower).
## `lift` is UDAAN's extra upward speed, cast at the apex (0 for a plain jump), and
## `glide` the seconds of slow glide after it. Returns -1 when the height cannot be
## reached. Keeps a 10% margin like the gap test.
func _reach(player: Dictionary, rise: float, lift: float, glide: float = 0.0) -> float:
	var g := float(player["gravity"])
	var v := float(player["jump_velocity"])
	var apex := v * v / (2.0 * g) + lift * lift / (2.0 * g)
	if rise > apex - 8.0:
		return -1.0
	var t_up := (v + lift) / g
	var drift := Player.glide_reach(glide, player)
	var top := apex - drift.y
	if rise > top:
		# Lands during the glide: only part of it is used.
		var t_glide := (apex - rise) / Player.GLIDE_FALL
		return float(player["run_speed"]) * (t_up + t_glide) * 0.9
	var t_down := sqrt(2.0 * (top - rise) / (g * float(player["fall_gravity_mult"])))
	return float(player["run_speed"]) * (t_up + glide + t_down) * 0.9


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
		setu_len: float, glide: float = 0.0) -> bool:
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
	if known.has("udaan") and rise <= UDAAN_RISE and dx <= _reach(player, rise, lift, glide):
		return true
	if known.has("setu"):
		# The bridge climbs what a jump cannot, at up to 40°; a jump covers the rest.
		var jump_rise := minf(rise, JUMP_RISE)
		var need := maxf(0.0, rise - JUMP_RISE)
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
	var glide := float(mantras["udaan"].get("glide", 0.0))
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
			if not seen.has(j) and _can_move(surfaces[i], surfaces[j], obstacles, player, known, lift, setu_len, glide):
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
				check(lo <= ex and ex <= hi, "%s: %s at x=%d starts inside its patrol" % [id, kind, ex])
				# Guards stop at pit edges while chasing, but the patrol itself must be solid.
				check(_on_surface(level, ["ground", "platforms"], lo, hi, ey),
					"%s: %s at x=%d patrols one surface" % [id, kind, ex])


# --- Feel: jump, prana, enemies ------------------------------------------------------


## Steps the jump frame by frame the way Player does (gravity, then the deferred cut).
func _simulated_rise(player: Dictionary, hold: float) -> float:
	var dt := 1.0 / 60.0
	var g := float(player["gravity"])
	var vy := 0.0
	var y := 0.0
	var t := 0.0
	var cut_done := false
	var top := 0.0
	for i in 240:
		vy += g * (float(player["fall_gravity_mult"]) if vy > 0.0 else 1.0) * dt
		if i == 0:
			vy = -float(player["jump_velocity"])
		if vy < 0.0 and not cut_done:
			t += dt
			if t >= hold and t >= float(player["jump_min_hold"]):
				vy *= float(player["jump_cut"])
				cut_done = true
		y += vy * dt
		top = minf(top, y)
	return -top


func test_jump_reach_margin() -> void:
	var player := GameConfig.read("player")
	var full := Player.jump_rise(player, 10.0)
	var tap := Player.jump_rise(player, 0.0)
	check(full >= 220.0 and full <= 250.0, "full jump apex %d px is about 230" % full)
	check(tap >= JUMP_RISE, "a quick tap rises %d px, at least the %d px step-up rule" % [tap, JUMP_RISE])
	check(tap >= 0.72 * full, "a tap keeps %d%% of the full jump" % int(100.0 * tap / full))
	check(full - JUMP_RISE >= 50.0, "step-ups keep a %d px margin below a full jump" % int(full - JUMP_RISE))
	check(absf(HintFinder.tap_rise(player) - tap) < 0.5, "HintFinder and Player agree on the tap height")
	# Frame-stepped, as on a phone at 60 fps (a tap is released on the first frame).
	var sim_tap := _simulated_rise(player, 0.0)
	var sim_full := _simulated_rise(player, 10.0)
	check(sim_tap >= JUMP_RISE - 5.0, "simulated tap rises %d px" % sim_tap)
	check(absf(sim_full - full) < 20.0, "simulated full jump %d px matches %d" % [sim_full, full])
	# A plain step-up of JUMP_RISE still leaves room to move sideways onto the ledge.
	check(_reach(player, JUMP_RISE, 0.0) >= 120.0, "a %d px step-up allows a %d px run-in" % [JUMP_RISE, _reach(player, JUMP_RISE, 0.0)])
	check(_jump_distance(player) * 0.9 >= 230.0, "a flat running jump clears %d px" % int(_jump_distance(player) * 0.9))


func test_prana_regen_config() -> void:
	var player := GameConfig.read("player")
	var mantras := GameConfig.read("mantras")
	var regen := float(player["prana_regen"])
	check(regen >= 1.2 and regen <= 2.0, "prana regen %.1f/s is slow (owner: refill slower)" % regen)
	check(float(player["prana_regen_delay"]) >= 2.0, "prana waits at least 2 s after a cast")
	check_eq(int(mantras["jwala"]["prana"]), 25, "JWALA costs 25 prana")
	# Spamming JWALA is out: a full bar holds four bolts, regen alone gives one per 15 s.
	check(float(player["prana_max"]) / float(mantras["jwala"]["prana"]) <= 4.0, "a full bar holds at most 4 JWALA")
	check(float(mantras["jwala"]["prana"]) / regen >= 12.0, "regen alone gives JWALA at most every 12 s")
	# Traversal must stay castable: a full bar (every checkpoint refills it) covers a
	# DRISHTI reveal plus a SETU bridge plus an UDAAN leap.
	var trip := float(mantras["drishti"]["prana"]) + float(mantras["setu"]["prana"]) + float(mantras["udaan"]["prana"])
	check(trip <= float(player["prana_max"]), "full prana covers DRISHTI + SETU + UDAAN (%d)" % trip)


func test_jwala_damage_rule() -> void:
	var mantras := GameConfig.read("mantras")
	var fire := int(mantras["jwala"]["damage"])
	check_eq(fire, 2, "JWALA deals 2 damage")
	check(Smokebound.default_hp("soldier", "c1") <= fire, "a chapter 1 soldier falls to one JWALA")
	check(Smokebound.default_hp("soldier", "c2") > fire, "later soldiers survive one JWALA")
	check(Smokebound.default_hp("archer", "c3") <= fire, "an archer falls to one JWALA")
	check_eq(Smokebound.default_hp("brute", "c2"), 5, "brutes have 5 HP")
	# No instakill: one bolt leaves a 3 HP soldier standing; a brute's shield holds.
	check_eq(3 - Smokebound.fire_damage("soldier", -1, 1, fire), 1, "JWALA takes 2 of a 3 HP soldier")
	check_eq(Smokebound.fire_damage("soldier", 1, 1, fire), fire, "JWALA hits a soldier from behind too")
	check_eq(Smokebound.fire_damage("brute", -1, 1, fire), 0, "fire from the front only staggers a brute")
	check_eq(Smokebound.fire_damage("brute", 1, 1, fire), fire, "fire from behind wounds a brute")
	check_eq(Smokebound.fire_damage("archer", -1, 1, fire), fire, "archers have no shield")
	# Brutes only from chapter 2.
	for id in _levels_in_order():
		var level := GameConfig.level(id)
		for e in level.get("enemies", []):
			if str(e.get("type", "")) == "brute":
				check(str(level.get("chapter", "")) != "c1", "%s: no brutes in chapter 1" % id)


func test_hint_finder() -> void:
	var player := GameConfig.read("player")
	var mantras := GameConfig.read("mantras")
	var all: Array = mantras.keys()
	check_eq(HintFinder.deaths_near([1000.0, 1300.0, 3000.0], 1200.0), 2, "two deaths near x=1200")
	check_eq(HintFinder.mantra_for(GameConfig.level("c2_l1"), Vector2(1300, 960), "fall", all, [], player, mantras),
		"drishti", "c2_l1 first maya pit wants DRISHTI")
	check_eq(HintFinder.mantra_for(GameConfig.level("c1_l1"), Vector2(2800, 960), "fall", ["setu", "jwala"], [], player, mantras),
		"setu", "c1_l1 chasm wants SETU")
	check_eq(HintFinder.mantra_for(GameConfig.level("c1_l1"), Vector2(2800, 960), "fall", ["jwala"], [], player, mantras),
		"", "no hint for a mantra not learned")
	check_eq(HintFinder.mantra_for(GameConfig.level("c1_l1"), Vector2(4700, 600), "hit", ["jwala", "setu"], [4950.0], player, mantras),
		"jwala", "a standing thorn wall wants JWALA")


# --- Round 5: more levels, maya mechanics, UDAAN, hearts ------------------------------

## Keys whose use needs DRISHTI to be fair (sight shows the truth). Phantom walls and
## false gates do not: you walk through them, and they ripple (chapter 1 uses them).
const SIGHT_KEYS := ["maya_hidden"]


func test_fifteen_levels_five_per_chapter() -> void:
	var chapters: Array = GameConfig.read("game")["chapters"]
	check_eq(chapters.size(), 3, "three chapters")
	for ch in chapters:
		check_eq((ch["levels"] as Array).size(), 5, "chapter %s has 5 levels" % ch["id"])
	check_eq(_levels_in_order().size(), 15, "15 levels")
	for id in _levels_in_order():
		check_eq(str(GameConfig.level(id).get("id", "")), id, "%s: id matches its file" % id)


## Every maya mechanic is met first in a level that teaches it: a prompt zone that
## starts before the first one, within 1500 px.
func test_maya_mechanics_are_taught_first() -> void:
	var first := {}  # mechanic -> [level id, x]
	for id in _levels_in_order():
		var level := GameConfig.level(id)
		var found := {}
		for w in level.get("phantom_walls", []):
			found["phantom_walls"] = minf(float(found.get("phantom_walls", INF)), float(w[0]))
		for f in level.get("false_gates", []):
			found["false_gates"] = minf(float(found.get("false_gates", INF)), float(f[0]))
		for e in level.get("enemies", []):
			var m := str(e.get("maya", ""))
			if m != "":
				found[m] = minf(float(found.get(m, INF)), float(e.get("min", e.get("x", 0))))
		if bool(level.get("goal_veiled", false)):
			found["goal_veiled"] = float(level["goal"][0])
		for key in found:
			if first.has(key):
				continue
			first[key] = [id, found[key]]
			var taught := false
			for p in level.get("prompts", []):
				var px := float(p.get("x", 0))
				if px <= float(found[key]) and float(found[key]) - px <= 1500.0:
					taught = true
			check(taught, "%s: first %s at x=%d has a prompt before it" % [id, key, found[key]])
	for key in ["phantom_walls", "false_gates", "mirage", "veiled", "goal_veiled"]:
		check(first.has(key), "some level uses %s" % key)


func test_maya_rules() -> void:
	var known_by := _known_before_each_level()
	for id in _levels_in_order():
		var level := GameConfig.level(id)
		var known: Array = known_by[id]
		var sight := bool(level.get("goal_veiled", false))
		for key in SIGHT_KEYS:
			sight = sight or not level.get(key, []).is_empty()
		for e in level.get("enemies", []):
			var m := str(e.get("maya", ""))
			check(["", "mirage", "veiled"].has(m), "%s: maya kind '%s' known" % [id, m])
			if m == "mirage":
				check(str(e.get("type", "soldier")) != "archer", "%s: mirages are soldiers or brutes" % id)
			sight = sight or m != ""
		if sight:
			check(known.has("drishti"), "%s: uses sight-maya before DRISHTI is taught" % id)
		var size := GameConfig.vec(level.get("size"))
		for w in level.get("phantom_walls", []):
			check(w is Array and w.size() == 3, "%s: phantom wall is [x, base_y, height]" % id)
			check(_on_surface(level, ["ground", "platforms"], float(w[0]), float(w[0]) + PhantomWall.WIDTH, float(w[1])),
				"%s: phantom wall at x=%d stands on a surface" % [id, w[0]])
			check(float(w[2]) >= 200.0, "%s: phantom wall at x=%d tall enough to read as a wall" % [id, w[0]])
		for f in level.get("false_gates", []):
			var p := GameConfig.vec(f)
			check(_on_surface(level, ["ground", "platforms"], p.x - 30.0, p.x + 30.0, p.y), "%s: false gate at x=%d on a surface" % [id, p.x])
			check(p.x > 0.0 and p.x < size.x, "%s: false gate inside the level" % id)
			check(absf(p.x - float(level["goal"][0])) > 150.0, "%s: false gate apart from the real one" % id)


## Hearts are rare (LifeRules): at most one pickup per level, and it is off the easy
## path: well above any floor (a big leap) or tucked behind a smoke wall.
func test_heart_pickups_are_rare_and_reachable() -> void:
	var all_mantras: Array = GameConfig.read("mantras").keys()
	var with_heart := 0
	for id in _levels_in_order():
		var level := GameConfig.level(id)
		for key in level:
			check(key == "heart" or not str(key).begins_with("heart"), "%s: one heart key only (%s)" % [id, key])
		if not level.has("heart"):
			continue
		with_heart += 1
		var h := GameConfig.vec(level["heart"])
		check(level["heart"] is Array and level["heart"].size() == 2, "%s: heart is one [x, y]" % id)
		var hidden := false
		for w in level.get("phantom_walls", []):
			if h.x >= float(w[0]) - 20.0 and h.x <= float(w[0]) + PhantomWall.WIDTH + 140.0:
				hidden = true
		# The heart may rest on a lone stone (its perch); then the perch must be high.
		var tops: Array = []
		for key in ["ground", "platforms", "crumble", "maya_hidden"]:
			for s in level.get(key, []):
				if h.x >= float(s[0]) and h.x <= float(s[0]) + float(s[2]) and float(s[1]) >= h.y:
					tops.append(float(s[1]))
		tops.sort()
		var from := h.y
		if not tops.is_empty() and float(tops[0]) - h.y <= 100.0:
			from = float(tops[0])
			tops.pop_front()
		var below: float = (float(tops[0]) - from) if not tops.is_empty() else INF
		check(hidden or below >= 180.0, "%s: heart at %s is hard to reach (%d px over a floor)" % [id, str(h), below])
		var full := _surfaces(level, all_mantras, true)
		var seen := _reachable(level, full, all_mantras, true)
		var ok := false
		for i in seen:
			var s: Dictionary = full[i]
			if h.x >= float(s["x0"]) - 40.0 and h.x <= float(s["x1"]) + 40.0 and h.y >= float(s["top"]) - 440.0 and h.y <= float(s["low"]):
				ok = true
		check(ok, "%s: heart at %s reachable" % [id, str(h)])
	check(with_heart >= 6, "the new levels carry a heart (%d levels)" % with_heart)
	check_eq(LifeRules.MAX_HEART_PICKUPS, 1, "one heart pickup per level")


## UDAAN (owner, round 5): about 1.6x a full jump, then a glide of about 1.5 s.
func test_udaan_physics() -> void:
	var player := GameConfig.read("player")
	var udaan: Dictionary = GameConfig.read("mantras")["udaan"]
	var full := Player.jump_rise(player, 10.0)
	var rise := Player.udaan_rise(float(udaan["lift"]), player)
	check(rise >= 1.5 * full and rise <= 1.7 * full, "UDAAN rises %d px, about 1.6x a %d px jump" % [rise, full])
	var glide := float(udaan.get("glide", 0.0))
	check(glide >= 1.2 and glide <= 1.8, "glide lasts %.1f s" % glide)
	var drift := Player.glide_reach(glide, player)
	check(drift.y <= 150.0, "the glide sinks only %d px" % drift.y)
	check(drift.x >= 400.0, "the glide carries %d px" % drift.x)
	check(UDAAN_RISE <= full + rise - 40.0, "the step-up rule (%d) keeps a margin under jump + UDAAN (%d)" % [UDAAN_RISE, full + rise])
	# TARANG-only secrets stay TARANG-only: no cracked wall can be leapt.
	for id in _levels_in_order():
		for c in GameConfig.level(id).get("cracked", []):
			if id != "c1_l1":
				check(float(c[2]) > full + rise + 20.0, "%s: cracked wall at x=%d (%d px) taller than jump + UDAAN" % [id, c[0], c[2]])


## Owner saw coins stuck inside the rock in level 15: no pickup may sit inside ground,
## a ledge, or a wall.
func test_pickups_not_inside_solids() -> void:
	for id in _levels_in_order():
		var d := GameConfig.level(id)
		var solids: Array[Rect2] = []
		for g in d.get("ground", []):
			solids.append(Rect2(float(g[0]), float(g[1]), float(g[2]), 2000.0))
		for p in d.get("platforms", []):
			solids.append(Rect2(float(p[0]), float(p[1]), float(p[2]), 26.0))
		for key in ["cracked", "barriers"]:
			for c in d.get(key, []):
				solids.append(Rect2(float(c[0]) - 30.0, float(c[1]) - float(c[2]), 60.0, float(c[2])))
		var points: Array = (d.get("embers", []) as Array).duplicate()
		if d.has("heart"):
			points.append(d["heart"])
		for pt in points:
			var at := Vector2(float(pt[0]), float(pt[1]))
			for r in solids:
				check(not r.grow(-4.0).has_point(at + Vector2(0, 20)), "%s: pickup at %s is inside a solid %s" % [id, str(at), str(r)])
