class_name SaveData
extends RefCounted
## Everything the game persists. Plain data, so it is easy to test and migrate.
## from_dict() never trusts its input: anything missing or mistyped falls back to defaults.

const VERSION := 3

var unlocked: Array[String] = ["c1_l1"]
var results := {}  # level_id -> {"time": float, "embers": int, "stars": int}
var story_seen: Array[String] = []
var learned: Array[String] = []  # mantra ids
var jyoti := 0                   # spendable light (the in-game currency)
var custom_signs := {}           # mantra id -> Array of strokes, each an Array of [x, y]
var upgrades := {}               # mantra id -> rank (1 = base)
var skins_owned: Array[String] = ["classic"]
var skin := "classic"
var story_choices := {}          # choice id -> option index, for flavour callbacks
var daily := {}                  # see DailyRules; plain data
var settings := {"vibration": true, "quality": "high", "music": 0.8, "sfx": 1.0, "music_on": true, "sfx_on": true,
	"pad_scale": 1.0, "left_handed": false,
	"share_data": "ask"}  # "ask" until the player answers, then "yes" or "no"


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"unlocked": unlocked,
		"results": results,
		"story_seen": story_seen,
		"learned": learned,
		"jyoti": jyoti,
		"custom_signs": custom_signs,
		"upgrades": upgrades,
		"skins_owned": skins_owned,
		"skin": skin,
		"story_choices": story_choices,
		"daily": daily,
		"settings": settings,
	}


func stars(level_id: String) -> int:
	return int(results.get(level_id, {}).get("stars", 0))


func total_stars() -> int:
	var total := 0
	for id in results:
		total += stars(id)
	return total


func rank(mantra_id: String) -> int:
	return int(upgrades.get(mantra_id, 1))


static func from_dict(d: Dictionary) -> SaveData:
	var s := SaveData.new()
	_read_strings(d.get("unlocked"), s.unlocked)
	_read_strings(d.get("story_seen"), s.story_seen)
	_read_strings(d.get("learned"), s.learned)
	var results_in = d.get("results", {})
	if results_in is Dictionary:
		for id in results_in:
			var r = results_in[id]
			if r is Dictionary:
				s.results[str(id)] = {"time": float(r.get("time", 0.0)), "embers": int(r.get("embers", 0)),
					"stars": clampi(int(r.get("stars", 1)), 0, 3)}
	# v2 called the currency "embers_bank".
	var bank = d.get("jyoti", d.get("embers_bank", 0))
	if bank is float or bank is int:
		s.jyoti = maxi(0, int(bank))
	var ups = d.get("upgrades", {})
	if ups is Dictionary:
		for id in ups:
			if ups[id] is float or ups[id] is int:
				s.upgrades[str(id)] = clampi(int(ups[id]), 1, 3)
	_read_strings(d.get("skins_owned"), s.skins_owned)
	if d.get("skin") is String and s.skins_owned.has(d["skin"]):
		s.skin = d["skin"]
	if d.get("story_choices") is Dictionary:
		s.story_choices = d["story_choices"]
	if d.get("daily") is Dictionary:
		s.daily = d["daily"]
	var signs_in = d.get("custom_signs", {})
	if signs_in is Dictionary:
		for id in signs_in:
			var strokes = signs_in[id]
			if strokes is Array and not strokes.is_empty() and strokes.all(func(st) -> bool: return st is Array):
				s.custom_signs[str(id)] = strokes
	var settings_in = d.get("settings", {})
	if settings_in is Dictionary:
		for key in s.settings:
			if settings_in.has(key) and typeof(settings_in[key]) == typeof(s.settings[key]):
				s.settings[key] = settings_in[key]
	# v1 saves predate mantra learning: whoever finished level 1 knew its three mantras.
	if int(d.get("version", 1)) < 2 and s.results.has("c1_l1"):
		for id in ["setu", "chhaya", "jwala"]:
			if not s.learned.has(id):
				s.learned.append(id)
	return s


static func _read_strings(value, into: Array[String]) -> void:
	if not value is Array:
		return
	for id in value:
		if id is String and not into.has(id):
			into.append(id)


## Keeps the best time (lowest), the most light ever collected and the most stars for a
## level. Returns how many pickups are new beyond the previous best; only those are banked,
## so replaying a level cannot farm currency (daily vows and the trial are the repeatable
## sources).
func record_result(level_id: String, time: float, embers: int, star_count: int = 1) -> int:
	if not results.has(level_id):
		results[level_id] = {"time": time, "embers": embers, "stars": star_count}
		jyoti += embers
		return embers
	var r: Dictionary = results[level_id]
	var gained := maxi(0, embers - int(r["embers"]))
	r["stars"] = maxi(int(r.get("stars", 1)), star_count)
	r["time"] = minf(float(r["time"]), time)
	r["embers"] = maxi(int(r["embers"]), embers)
	jyoti += gained
	return gained


## Custom sign strokes as PackedVector2Arrays.
func sign_strokes(id: String) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for stroke in custom_signs.get(id, []):
		var pts := PackedVector2Array()
		for p in stroke:
			if p is Array and p.size() >= 2:
				pts.append(Vector2(float(p[0]), float(p[1])))
		if pts.size() >= 2:
			out.append(pts)
	return out


func set_sign(id: String, strokes: Array[PackedVector2Array]) -> void:
	var stored: Array = []
	for pts in strokes:
		var arr: Array = []
		for p in pts:
			arr.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
		stored.append(arr)
	custom_signs[id] = stored
