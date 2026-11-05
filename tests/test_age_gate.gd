extends "res://tests/test_case.gd"
## The neutral age screen: it asks for a birth year, keeps only "13 or older: yes/no", leans
## cautious when the year alone cannot tell, and nothing is shared unless age and consent agree.


func test_year_decides_cautiously() -> void:
	# Born in 2012 or earlier is certainly 13 by 2026; 2013 might still be 12.
	check(AgeGate.is_13_or_older(2012, 2026), "2012 is certainly 13+ in 2026")
	check(not AgeGate.is_13_or_older(2013, 2026), "2013 might be 12 in 2026")
	check(not AgeGate.is_13_or_older(2026, 2026), "born this year")
	check(AgeGate.is_13_or_older(1980, 2026), "an adult")


func test_years_are_clamped_to_a_sane_range() -> void:
	check_eq(AgeGate.clamp_year(1800, 2026), AgeGate.MIN_YEAR, "too old")
	check_eq(AgeGate.clamp_year(3000, 2026), 2026, "future")
	check_eq(AgeGate.clamp_year(1999, 2026), 1999, "in range")


func test_start_year_is_not_the_threshold() -> void:
	# A neutral screen must not preset the answer that unlocks things.
	check(AgeGate.START_YEAR != 2026 - 14 and AgeGate.START_YEAR != 2026 - 13, "start year is neutral")


func test_answer_maps_to_a_stored_state() -> void:
	check_eq(AgeGate.state_for(1990, 2026), "ok", "adult")
	check_eq(AgeGate.state_for(2015, 2026), "under", "child")


func test_data_sharing_needs_age_and_consent() -> void:
	check(AgeGate.sharing_allowed("ok", "yes"), "ok + yes")
	check(not AgeGate.sharing_allowed("ok", "no"), "ok + no")
	check(not AgeGate.sharing_allowed("ok", "ask"), "ok + not asked")
	check(not AgeGate.sharing_allowed("under", "yes"), "under 13 never shares, even if a yes is stored")
	check(not AgeGate.sharing_allowed("ask", "yes"), "age not asked yet means nothing is shared")
	check(not AgeGate.sharing_allowed("garbage", "yes"), "unknown state is treated as not ok")


func test_age_state_round_trips_and_defaults_to_ask() -> void:
	var s := SaveData.new()
	check_eq(s.settings["age_gate"], "ask", "default")
	s.settings["age_gate"] = "under"
	check_eq(SaveData.from_dict(s.to_dict()).settings["age_gate"], "under", "kept")
	# The birth year itself is never part of the save.
	check(not s.to_dict()["settings"].has("birth_year"), "no birth year stored")
