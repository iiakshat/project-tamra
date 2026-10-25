class_name HintFinder
extends RefCounted
## Decides which mantra would have saved the hero, from the level data alone.
## Used after repeated deaths in one spot: the level then shows that mantra's sign.

## Deaths closer than this (px) count as "the same spot".
const SPOT := 400.0


## How many earlier deaths (in `xs`) sit within SPOT of `x`, counting this one.
static func deaths_near(xs: Array, x: float) -> int:
	var n := 0
	for d in xs:
		if absf(float(d) - x) <= SPOT:
			n += 1
	return n


## Returns a mantra id, or "" when no mantra is the answer here.
## level: the level JSON. at: where the hero died. cause: "fall" or "hit".
## known: learned mantra ids. barriers: x of smoke-thorn walls still standing.
## player: config/player.json. mantras: config/mantras.json.
static func mantra_for(level: Dictionary, at: Vector2, cause: String, known: Array, barriers: Array,
		player: Dictionary, mantras: Dictionary) -> String:
	var x := at.x
	# 1. A taught sign for this stretch (prompt zones carry the glyph).
	for p in level.get("prompts", []):
		var glyph := str(p.get("glyph", ""))
		if glyph == "":
			continue
		var x0 := float(p.get("x", 0))
		var x1 := x0 + float(p.get("width", 360))
		if x1 >= x - SPOT and x0 <= x + SPOT:
			var id := _mantra_with_gesture(mantras, glyph)
			if id != "" and known.has(id):
				return id
	# 2. A thorn wall just ahead: burn it.
	for bx in barriers:
		if float(bx) > x - 150.0 and float(bx) < x + 500.0 and known.has("jwala"):
			return "jwala"
	# 3. Cracked stone ahead: break it.
	for c in level.get("cracked", []):
		if float(c[0]) > x - 100.0 and float(c[0]) < x + 400.0 and known.has("tarang"):
			return "tarang"
	if cause == "fall":
		return _for_fall(level, x, known, player)
	if cause == "hit":
		return _for_fight(level, x, known)
	return ""


static func _for_fall(level: Dictionary, x: float, known: Array, player: Dictionary) -> String:
	var spans := _spans(level)
	var left := -INF
	var left_top := 0.0
	var right := INF
	var right_top := 0.0
	for s in spans:
		if s.y <= x and s.y > left:
			left = s.y
			left_top = s.z
		if s.x >= x and s.x < right:
			right = s.x
			right_top = s.z
	if left == -INF or right == INF:
		return ""
	# Illusions in the pit: the way across is there, but unseen.
	for key in ["maya_hidden", "maya_false"]:
		for m in level.get(key, []):
			var m0 := float(m[0])
			if m0 + float(m[2]) >= left - 40.0 and m0 <= right + 40.0 and known.has("drishti"):
				return "drishti"
	var rise := left_top - right_top
	if rise > tap_rise(player) and known.has("udaan"):
		return "udaan"
	if right - left > 0.8 * jump_length(player) and known.has("setu"):
		return "setu"
	if rise > tap_rise(player) and known.has("setu"):
		return "setu"
	return ""


static func _for_fight(level: Dictionary, x: float, known: Array) -> String:
	for e in level.get("enemies", []):
		if absf(float(e.get("x", 0)) - x) > SPOT + 200.0:
			continue
		var kind := str(e.get("type", "soldier"))
		if kind == "archer" and known.has("kavach"):
			return "kavach"
		if kind == "brute" and known.has("bandhan"):
			return "bandhan"
		if known.has("chhaya"):
			return "chhaya"
	return ""


## Standable spans as Vector3(x0, x1, top). Moving platforms cover their whole travel.
static func _spans(level: Dictionary) -> Array:
	var out: Array = []
	for key in ["ground", "platforms", "crumble"]:
		for g in level.get(key, []):
			out.append(Vector3(float(g[0]), float(g[0]) + float(g[2]), float(g[1])))
	for m in level.get("moving", []):
		var mx := float(m.get("x", 0))
		var dx := float(m.get("dx", 0))
		var top := minf(float(m.get("y", 0)), float(m.get("y", 0)) + float(m.get("dy", 0)))
		out.append(Vector3(minf(mx, mx + dx), maxf(mx, mx + dx) + float(m.get("w", 150)), top))
	return out


static func _mantra_with_gesture(mantras: Dictionary, glyph: String) -> String:
	for id in mantras:
		if str(mantras[id].get("gesture", "")) == glyph:
			return str(id)
	return ""


## Height of a quick tap on the jump pad (released at once): see Player.jump_rise.
static func tap_rise(player: Dictionary) -> float:
	var g := float(player.get("gravity", 2400.0))
	var v := float(player.get("jump_velocity", 1050.0))
	var t := float(player.get("jump_min_hold", 0.13))
	if t >= v / g:
		return v * v / (2.0 * g)
	var v_cut := (v - g * t) * float(player.get("jump_cut", 0.7))
	return v * t - 0.5 * g * t * t + v_cut * v_cut / (2.0 * g)


## Horizontal length of a full running jump that lands at the same height.
static func jump_length(player: Dictionary) -> float:
	var g := float(player.get("gravity", 2400.0))
	var v := float(player.get("jump_velocity", 1050.0))
	var apex := v * v / (2.0 * g)
	var down := sqrt(2.0 * apex / (g * float(player.get("fall_gravity_mult", 1.4))))
	return float(player.get("run_speed", 330.0)) * (v / g + down)
