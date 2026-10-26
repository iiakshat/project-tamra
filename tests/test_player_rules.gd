extends "res://tests/test_case.gd"
## Round 5 player rules: hearts last the level (LifeRules) and tiredness is earned and
## rare (Fatigue). Frame-level checks of the same rules: tools/hearts_smoke.gd.

const DT := 1.0 / 60.0


func _cfg() -> Dictionary:
	return GameConfig.read("player")


func _run_for(f: Fatigue, seconds: float, state: String) -> void:
	for i in int(seconds / DT):
		f.update(DT, state)


func test_hearts_last_the_level() -> void:
	var max_hearts := int(GameConfig.read("game").get("max_hearts", 3))
	check_eq(max_hearts, 3, "three hearts")
	var h := max_hearts
	h = LifeRules.after_hit(h)
	check_eq(h, 2, "a hit costs a heart")
	h = LifeRules.after_fall(h)
	check_eq(h, 1, "a pit fall costs a heart")
	check_eq(LifeRules.after_respawn(h, max_hearts), 1, "respawning at a lamp never refills hearts")
	check(not LifeRules.is_game_over(h), "one heart left: play on")
	check_eq(LifeRules.after_heal(h, max_hearts), 2, "the heart pickup heals one")
	check_eq(LifeRules.after_heal(max_hearts, max_hearts), max_hearts, "healing never goes past full")
	h = LifeRules.after_fall(LifeRules.after_hit(2))
	check_eq(h, 0, "down to zero")
	check(LifeRules.is_game_over(h), "zero hearts: the level starts over")
	check_eq(LifeRules.after_fall(0), 0, "never below zero")


func test_short_runs_do_not_tire() -> void:
	var f := Fatigue.new(_cfg())
	for i in 5:
		_run_for(f, 5.0, "run")
		_run_for(f, 0.5, "rest")
	check(f.level < 1.0, "five 5 s dashes with pauses: not tired (%.1f)" % f.level)
	check(not f.wants_pant(), "no pant")


func test_long_run_tires() -> void:
	var f := Fatigue.new(_cfg())
	_run_for(f, 6.0, "run")
	check(f.level < 1.0, "the first 6 s of running are free")
	_run_for(f, 6.0, "run")
	check(f.wants_pant(), "12 s of non-stop running: he wants to catch his breath (%.1f)" % f.level)
	# Jumps inside the run do not break it.
	var g := Fatigue.new(_cfg())
	for i in 12:
		_run_for(g, 0.6, "run")
		_run_for(g, 0.4, "air")
	check(g.level > 0.0, "running with hops still counts as one run")


func test_rest_drains_fatigue() -> void:
	var f := Fatigue.new(_cfg())
	_run_for(f, 12.0, "run")
	var tired := f.level
	_run_for(f, 5.0, "rest")
	check(f.level < tired - 25.0, "five seconds of walking drain it (%.1f -> %.1f)" % [tired, f.level])


func test_fighting_tires() -> void:
	var f := Fatigue.new(_cfg())
	for i in 3:
		f.on_strike()
		_run_for(f, 3.0, "rest")
	check(f.level < 5.0, "a strike now and then is nothing (%.1f)" % f.level)
	var g := Fatigue.new(_cfg())
	for i in 8:
		g.on_strike()
		_run_for(g, 0.45, "rest")
	check(g.wants_pant(), "eight quick strikes: tired (%.1f)" % g.level)


func test_many_jumps_tire() -> void:
	var f := Fatigue.new(_cfg())
	for i in 6:
		f.on_jump()
		_run_for(f, 3.0, "rest")
	check(f.level < 10.0, "a jump every few seconds is fine (%.1f)" % f.level)
	var g := Fatigue.new(_cfg())
	for i in 11:
		g.on_jump()
		_run_for(g, 0.4, "air")
	check(g.wants_pant(), "eleven jumps in four seconds: tired (%.1f)" % g.level)


func test_panting_is_rare() -> void:
	var f := Fatigue.new(_cfg())
	_run_for(f, 12.0, "run")
	check(f.wants_pant(), "tired")
	f.panted()
	check_eq(f.level, 0.0, "catching breath rests him")
	_run_for(f, 12.0, "run")
	check(not f.wants_pant(), "no second pant within the cooldown")
	_run_for(f, 10.0, "run")
	check(f.wants_pant(), "after the cooldown he can tire again")
	check(float(_cfg()["pant_cooldown"]) >= 15.0, "cooldown at least 15 s")
