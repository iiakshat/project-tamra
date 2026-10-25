class_name SaveData
extends RefCounted
## Everything the game persists. Plain data, so it is easy to test and migrate.
## from_dict() never trusts its input: anything missing or mistyped falls back to defaults.

const VERSION := 1

var unlocked: Array[String] = ["c1_l1"]
var results := {}  # level_id -> {"time": float, "embers": int}
var story_seen: Array[String] = []
var settings := {"vibration": true, "quality": "high", "music": 0.8, "sfx": 1.0}


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"unlocked": unlocked,
		"results": results,
		"story_seen": story_seen,
		"settings": settings,
	}


static func from_dict(d: Dictionary) -> SaveData:
	var s := SaveData.new()
	var unlocked_in = d.get("unlocked", [])
	if unlocked_in is Array:
		for id in unlocked_in:
			if id is String and not s.unlocked.has(id):
				s.unlocked.append(id)
	var results_in = d.get("results", {})
	if results_in is Dictionary:
		for id in results_in:
			var r = results_in[id]
			if r is Dictionary:
				s.results[str(id)] = {"time": float(r.get("time", 0.0)), "embers": int(r.get("embers", 0))}
	var seen_in = d.get("story_seen", [])
	if seen_in is Array:
		for id in seen_in:
			if id is String and not s.story_seen.has(id):
				s.story_seen.append(id)
	var settings_in = d.get("settings", {})
	if settings_in is Dictionary:
		for key in s.settings:
			if settings_in.has(key) and typeof(settings_in[key]) == typeof(s.settings[key]):
				s.settings[key] = settings_in[key]
	return s


## Keeps the best time (lowest) and the most embers ever collected for a level.
func record_result(level_id: String, time: float, embers: int) -> void:
	if not results.has(level_id):
		results[level_id] = {"time": time, "embers": embers}
		return
	var r: Dictionary = results[level_id]
	r["time"] = minf(float(r["time"]), time)
	r["embers"] = maxi(int(r["embers"]), embers)
