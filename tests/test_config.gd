extends "res://tests/test_case.gd"
## Guards the data files: everything referenced must exist, and every level must be
## physically completable with the player's jump and the mantras known by then.


func _jump_distance(player: Dictionary) -> float:
	var g := float(player["gravity"])
	var v := float(player["jump_velocity"])
	var up := v / g
	var height := v * v / (2.0 * g)
	var down := sqrt(2.0 * height / (g * float(player["fall_gravity_mult"])))
	return float(player["run_speed"]) * (up + down)


func _levels_in_order() -> Array[String]:
	var out: Array[String] = []
	for ch in GameConfig.read("game")["chapters"]:
		for id in ch["levels"]:
			out.append(str(id))
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
		for p in level.get("platforms", []):
			spans.append(Vector2(float(p[0]), float(p[0]) + float(p[2])))
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
