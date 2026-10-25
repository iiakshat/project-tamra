class_name DailyRules
extends RefCounted
## Reasons to come back each day, designed to be generous rather than punishing
## (no streak that resets, no timers that pressure, nothing lost by missing a day):
##   Blessing: a 7-step reward cycle, one step per day you visit.
##   Vows: three small tasks a day, chosen from the date so everyone gets the same set.
##   Trial: one cleared level replayed with a twist, for a large reward once a day.
## Dates are "YYYY-MM-DD" strings passed in, so tests control time.

const BLESSINGS := [20, 30, 40, 50, 60, 80, 150]
const VOW_REWARD := 30
const ALL_VOWS_BONUS := 50
const TRIAL_REWARD := 100

const VOW_POOL := [
	{"id": "strike_kills", "goal": 4, "icon": "trial"},
	{"id": "fire_kills", "goal": 3, "icon": "prana"},
	{"id": "casts", "goal": 15, "icon": "prana"},
	{"id": "jyoti", "goal": 20, "icon": "jyoti"},
	{"id": "levels", "goal": 2, "icon": "play"},
	{"id": "clean_clear", "goal": 1, "icon": "heart"},
	{"id": "setu", "goal": 5, "icon": "up"},
	{"id": "udaan", "goal": 5, "icon": "up"},
]

const TRIAL_MODS := ["frail", "thin_prana", "fierce"]

var save: SaveData


func _init(data: SaveData) -> void:
	save = data


## Rolls the day's vows over when the date changes.
func refresh(date: String) -> void:
	if str(save.daily.get("vows_date", "")) == date:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(date)
	var pool := VOW_POOL.duplicate()
	var picked: Array = []
	for i in 3:
		var v: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		picked.append({"id": v["id"], "goal": v["goal"], "icon": v["icon"], "progress": 0, "claimed": false})
	save.daily["vows_date"] = date
	save.daily["vows"] = picked
	save.daily["bonus_claimed"] = false


func blessing_available(date: String) -> bool:
	return str(save.daily.get("blessing_date", "")) != date


## Index (0..6) of the reward the next blessing gives.
func blessing_step() -> int:
	return int(save.daily.get("blessing_step", 0)) % BLESSINGS.size()


func claim_blessing(date: String) -> int:
	if not blessing_available(date):
		return 0
	var reward: int = BLESSINGS[blessing_step()]
	save.daily["blessing_step"] = (blessing_step() + 1) % BLESSINGS.size()
	save.daily["blessing_date"] = date
	save.jyoti += reward
	return reward


func vows() -> Array:
	return save.daily.get("vows", [])


## Adds progress to every unfinished vow tracking `event`. Returns vows just completed.
func track(event: String, amount: int = 1) -> Array:
	var finished: Array = []
	for v in vows():
		if v["id"] != event or int(v["progress"]) >= int(v["goal"]):
			continue
		v["progress"] = mini(int(v["progress"]) + amount, int(v["goal"]))
		if int(v["progress"]) >= int(v["goal"]):
			finished.append(v)
	return finished


func vow_done(v: Dictionary) -> bool:
	return int(v["progress"]) >= int(v["goal"])


## Pays out every finished, unclaimed vow, plus the bonus once all three are done.
func claim_vows() -> int:
	var total := 0
	for v in vows():
		if vow_done(v) and not bool(v["claimed"]):
			v["claimed"] = true
			total += VOW_REWARD
	if not vows().is_empty() and vows().all(func(v) -> bool: return bool(v["claimed"])) and not bool(save.daily.get("bonus_claimed", false)):
		save.daily["bonus_claimed"] = true
		total += ALL_VOWS_BONUS
	save.jyoti += total
	return total


func unclaimed_vows() -> int:
	var n := 0
	for v in vows():
		if vow_done(v) and not bool(v["claimed"]):
			n += 1
	return n


## Today's trial: {"level": id, "mod": id}, or {} if no level has been cleared yet.
func trial(date: String, cleared: Array) -> Dictionary:
	if cleared.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(date + "trial")
	return {"level": cleared[rng.randi_range(0, cleared.size() - 1)], "mod": TRIAL_MODS[rng.randi_range(0, TRIAL_MODS.size() - 1)]}


func trial_done(date: String) -> bool:
	return str(save.daily.get("trial_date", "")) == date


func complete_trial(date: String) -> int:
	if trial_done(date):
		return 0
	save.daily["trial_date"] = date
	save.daily["trial_wins"] = int(save.daily.get("trial_wins", 0)) + 1
	save.jyoti += TRIAL_REWARD
	return TRIAL_REWARD
