extends "res://tests/test_case.gd"


func _grimoire(data: SaveData = null) -> Grimoire:
	return Grimoire.new(GameConfig.read("mantras"), data if data != null else SaveData.new())


func _shape(name: String, scale := 110.0, jitter := 0.0, seed_value := 1) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var src := GlyphShapes.canonical(name)
	var out := PackedVector2Array()
	for i in range(src.size() - 1):
		for s in 10:
			var p := src[i].lerp(src[i + 1], s / 10.0) * scale + Vector2(400, 300)
			out.append(p + Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter)))
	out.append(src[src.size() - 1] * scale + Vector2(400, 300))
	return out


## A spiral: a sign no mantra uses by default.
func _spiral(seed_value := 1) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedVector2Array()
	for i in 60:
		var a := i * 0.28
		out.append(Vector2(400, 300) + Vector2(cos(a), sin(a)) * (10.0 + i * 1.8) + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)))
	return out


func test_unlock_states() -> void:
	var g := _grimoire()
	check_eq(g.state("setu")["state"], "locked", "level-taught mantra starts locked")
	check_eq(g.state("kavach")["state"], "locked", "buyable only after its level")
	g.save.results["c1_l1"] = {"time": 60.0, "embers": 5}
	check_eq(g.state("kavach")["state"], "buyable", "buyable after c1_l1")
	check_eq(g.newly_buyable_after("c1_l1"), ["kavach"] as Array[String], "kavach announced after c1_l1")


func test_buy_spends_embers() -> void:
	var g := _grimoire()
	g.save.results["c1_l1"] = {"time": 60.0, "embers": 5}
	g.save.embers_bank = 4
	check(not g.buy("kavach"), "cannot buy without enough embers")
	g.save.embers_bank = 12
	check(g.buy("kavach"), "buy succeeds")
	check_eq(g.save.embers_bank, 2, "cost deducted")
	check(g.is_learned("kavach"), "learned after buying")
	check(not g.buy("kavach"), "cannot buy twice")


func test_default_signs_map_to_mantras() -> void:
	var g := _grimoire()
	var r := g.build_recognizer(0.72)
	for id in g.ids():
		var gesture := str(g.cfg[id]["gesture"])
		if GlyphShapes.SHAPES.has(gesture):
			check_eq(g.mantra_for(str(r.recognize(_shape(gesture))["name"])), id, id)
	check_eq(g.mantra_for("line"), "setu", "line casts setu")
	check_eq(g.mantra_for("line_up"), "udaan", "upward line casts udaan")
	check_eq(g.mantra_for("line_down"), "", "downward line casts nothing")


func test_custom_sign_replaces_default() -> void:
	var g := _grimoire()
	var strokes: Array[PackedVector2Array] = [_spiral(1), _spiral(2), _spiral(3)]
	check_eq(g.validate_sign("jwala", strokes, 0.72), "", "spiral is a valid sign")
	g.save.set_sign("jwala", strokes)
	var r := g.build_recognizer(0.72)
	check_eq(g.mantra_for(str(r.recognize(_spiral(9))["name"])), "jwala", "spiral now casts jwala")
	check_eq(g.mantra_for(str(r.recognize(_shape("bolt"))["name"])), "", "the old bolt no longer casts jwala")


func test_custom_sign_survives_save_round_trip() -> void:
	var data := SaveData.new()
	var strokes: Array[PackedVector2Array] = [_spiral(1), _spiral(2), _spiral(3)]
	data.set_sign("kavach", strokes)
	var loaded := SaveData.from_dict(JSON.parse_string(JSON.stringify(data.to_dict())))
	check_eq(loaded.sign_strokes("kavach").size(), 3, "three strokes restored")


func test_bad_signs_are_rejected() -> void:
	var g := _grimoire()
	var lines: Array[PackedVector2Array] = [_shape("line"), _shape("line"), _shape("line")]
	check(g.validate_sign("jwala", lines, 0.72).contains("Straight"), "straight lines rejected")
	var mixed: Array[PackedVector2Array] = [_spiral(1), _shape("square"), _shape("circle")]
	check(g.validate_sign("jwala", mixed, 0.72).contains("different"), "inconsistent strokes rejected")
	var taken: Array[PackedVector2Array] = [_shape("circle", 110.0, 3.0, 1), _shape("circle", 110.0, 3.0, 2), _shape("circle", 110.0, 3.0, 3)]
	check(g.validate_sign("jwala", taken, 0.72).contains("KAVACH"), "another mantra's sign rejected")
	check(g.validate_sign("jwala", [_spiral(1)] as Array[PackedVector2Array], 0.72).contains("3 times"), "needs three samples")


func test_v1_save_migrates_learned() -> void:
	var s := SaveData.from_dict({"version": 1, "results": {"c1_l1": {"time": 70.0, "embers": 10}}})
	check(s.learned.has("setu") and s.learned.has("jwala"), "level-1 mantras learned from a v1 save")


func test_replays_do_not_farm_embers() -> void:
	var s := SaveData.new()
	check_eq(s.record_result("c1_l1", 80.0, 6), 6, "first clear banks all embers")
	check_eq(s.record_result("c1_l1", 70.0, 6), 0, "same count banks nothing")
	check_eq(s.record_result("c1_l1", 75.0, 9), 3, "only the new ones bank")
	check_eq(s.embers_bank, 9, "bank total")
