extends "res://tests/test_case.gd"


func test_blessing_once_per_day_and_never_resets() -> void:
	var d := DailyRules.new(SaveData.new())
	check_eq(d.claim_blessing("2026-10-25"), 20, "day 1 reward")
	check_eq(d.claim_blessing("2026-10-25"), 0, "only once a day")
	check_eq(d.claim_blessing("2026-10-30"), 30, "a gap of days continues the cycle, no reset")
	check_eq(d.save.jyoti, 50, "rewards banked")


func test_blessing_cycles_after_seven() -> void:
	var d := DailyRules.new(SaveData.new())
	for i in 7:
		d.claim_blessing("2026-11-%02d" % (i + 1))
	check_eq(d.blessing_step(), 0, "cycle wraps")
	check_eq(d.save.jyoti, 430, "sum of one cycle")


func test_vows_are_stable_per_date_and_change_daily() -> void:
	var a := DailyRules.new(SaveData.new())
	var b := DailyRules.new(SaveData.new())
	a.refresh("2026-10-25")
	b.refresh("2026-10-25")
	check_eq(a.vows().size(), 3, "three vows")
	check_eq(str(a.vows()), str(b.vows()), "same date, same vows for everyone")
	var ids := {}
	for v in a.vows():
		ids[v["id"]] = true
	check_eq(ids.size(), 3, "no duplicate vows")


func test_vow_progress_and_claim() -> void:
	var d := DailyRules.new(SaveData.new())
	d.refresh("2026-10-25")
	for v in d.vows():
		d.track(v["id"], int(v["goal"]) + 5)
	check_eq(d.unclaimed_vows(), 3, "all done")
	check_eq(d.claim_vows(), 3 * DailyRules.VOW_REWARD + DailyRules.ALL_VOWS_BONUS, "rewards plus bonus")
	check_eq(d.claim_vows(), 0, "cannot claim twice")
	d.refresh("2026-10-26")
	check_eq(d.unclaimed_vows(), 0, "new day, fresh vows")


func test_trial_once_per_day() -> void:
	var d := DailyRules.new(SaveData.new())
	check(d.trial("2026-10-25", []).is_empty(), "no trial before any clear")
	var t := d.trial("2026-10-25", ["c1_l1", "c1_l2"])
	check(["c1_l1", "c1_l2"].has(t["level"]), "trial level is a cleared one")
	check(DailyRules.TRIAL_MODS.has(t["mod"]), "trial has a twist")
	check_eq(d.complete_trial("2026-10-25"), DailyRules.TRIAL_REWARD, "reward")
	check_eq(d.complete_trial("2026-10-25"), 0, "once a day")


func test_save_v2_migrates_currency() -> void:
	var s := SaveData.from_dict({"version": 2, "embers_bank": 17})
	check_eq(s.jyoti, 17, "embers become jyoti")
	check_eq(s.skin, "classic", "default skin")
