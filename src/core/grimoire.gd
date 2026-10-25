class_name Grimoire
extends RefCounted
## The rules of mantras: which are learned, which can be bought with embers, which sign
## casts which mantra (default or the player's own), and the recognizer that understands
## the player's current signs. Pure logic over config + SaveData, so it is unit tested.

const CUSTOM_PREFIX := "mantra:"
const SIGN_SAMPLES := 3
const SIGN_CONSISTENCY := 0.68

var cfg: Dictionary
var save: SaveData
var shop: Dictionary = {}  # config/shop.json: upgrade prices and multipliers


## Prana a cast costs at the player's current rank.
func prana_cost(id: String) -> int:
	var mult: Array = shop.get("upgrade_cost_mult", [1.0, 1.0, 1.0])
	return int(round(float(cfg.get(id, {}).get("prana", 0)) * float(mult[save.rank(id) - 1])))


func cooldown(id: String) -> float:
	var mult: Array = shop.get("upgrade_cooldown_mult", [1.0, 1.0, 1.0])
	return float(cfg.get(id, {}).get("cooldown", 1.0)) * float(mult[save.rank(id) - 1])


## Jyoti for the next rank, or -1 at max rank.
func upgrade_cost(id: String) -> int:
	var costs: Array = shop.get("upgrade_costs", [0, 40, 100])
	var r := save.rank(id)
	return int(costs[r]) if r < costs.size() else -1


func upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if not is_learned(id) or cost < 0 or save.jyoti < cost:
		return false
	save.jyoti -= cost
	save.upgrades[id] = save.rank(id) + 1
	return true


func _init(mantras: Dictionary, data: SaveData) -> void:
	cfg = mantras
	save = data


func ids() -> Array[String]:
	var out: Array[String] = []
	for id in cfg:
		out.append(str(id))
	return out


func is_learned(id: String) -> bool:
	return save.learned.has(id)


## Returns true if the mantra was not known before.
func learn(id: String) -> bool:
	if not cfg.has(id) or save.learned.has(id):
		return false
	save.learned.append(id)
	return true


## {"state": "learned" | "buyable" | "locked", "cost": int, "level": String, "after": String}
## "level": the level that teaches it. "after": the level that must be finished before buying.
func state(id: String) -> Dictionary:
	var unlock: Dictionary = cfg.get(id, {}).get("unlock", {})
	var out := {"state": "locked", "cost": int(unlock.get("cost", 0)), "level": str(unlock.get("level", "")),
		"after": str(unlock.get("after", ""))}
	if is_learned(id):
		out["state"] = "learned"
	elif unlock.has("cost") and (out["after"] == "" or save.results.has(out["after"])):
		out["state"] = "buyable"
	return out


func can_afford(id: String) -> bool:
	return save.jyoti >= int(state(id)["cost"])


func buy(id: String) -> bool:
	var s := state(id)
	if s["state"] != "buyable" or save.jyoti < int(s["cost"]):
		return false
	save.jyoti -= int(s["cost"])
	learn(id)
	return true


## Mantras that became buyable because `level_id` was just finished.
func newly_buyable_after(level_id: String) -> Array[String]:
	var out: Array[String] = []
	for id in ids():
		var s := state(id)
		if s["state"] == "buyable" and s["after"] == level_id:
			out.append(id)
	return out


func has_custom_sign(id: String) -> bool:
	return save.custom_signs.has(id)


## The gesture name the recognizer reports for this mantra.
func gesture_of(id: String) -> String:
	return CUSTOM_PREFIX + id if has_custom_sign(id) else str(cfg.get(id, {}).get("gesture", ""))


## Which mantra a recognized gesture casts ("" if none). A mantra with a custom sign
## no longer answers to its default one.
func mantra_for(gesture: String) -> String:
	if gesture.begins_with(CUSTOM_PREFIX):
		var id := gesture.substr(CUSTOM_PREFIX.length())
		return id if cfg.has(id) else ""
	for id in ids():
		if not has_custom_sign(id) and str(cfg[id].get("gesture", "")) == gesture:
			return id
	return ""


## The mantra whose built-in sign is `gesture`, customized or not ("" if none).
func mantra_with_default(gesture: String) -> String:
	for id in ids():
		if str(cfg[id].get("gesture", "")) == gesture:
			return id
	return ""


## Recognizer for every mantra's current sign (learned or not, so drawing a locked sign
## can say "not learned yet"). `skip` leaves one mantra out, for conflict checks.
func build_recognizer(min_score: float, skip: String = "") -> GestureRecognizer:
	var r := GestureRecognizer.new()
	r.min_score = min_score
	var shapes_added := {}
	for id in ids():
		if id == skip:
			continue
		if has_custom_sign(id):
			for stroke in save.sign_strokes(id):
				r.add_template(CUSTOM_PREFIX + id, stroke)
		else:
			var g := str(cfg[id].get("gesture", ""))
			if GlyphShapes.SHAPES.has(g) and not shapes_added.has(g):
				r.add_shape(g)
				shapes_added[g] = true
	return r


## "" if the strokes make a good custom sign for `id`, otherwise a message for the player.
func validate_sign(id: String, strokes: Array[PackedVector2Array], min_score: float) -> String:
	if strokes.size() < SIGN_SAMPLES:
		return "Draw your sign %d times." % SIGN_SAMPLES
	for s in strokes:
		if GestureRecognizer.is_straight(s):
			return "Straight lines belong to SETU and UDAAN. Try a shape with a turn in it."
	var r := build_recognizer(min_score, id)
	for i in strokes.size():
		for j in range(i + 1, strokes.size()):
			if r.similarity(strokes[i], strokes[j]) < SIGN_CONSISTENCY:
				return "Those looked different from each other. Draw it the same way each time."
	for s in strokes:
		var other := mantra_for(str(r.recognize(s)["name"]))
		if other != "" and other != id:
			return "Too close to the sign for %s. Try something more different." % str(cfg[other].get("label", other))
	return ""
