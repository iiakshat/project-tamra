extends Node
## Game-wide state: configs, save data, progression and the mantra rules.

signal mantras_changed

var game_cfg: Dictionary
var player_cfg: Dictionary
var mantra_cfg: Dictionary
var save: SaveData
var grimoire: Grimoire

var _store: SaveStore


func _ready() -> void:
	InputSetup.ensure_actions()
	game_cfg = GameConfig.read("game")
	player_cfg = GameConfig.read("player")
	mantra_cfg = GameConfig.read("mantras")
	_store = SaveStore.new(Services.storage)
	save = _store.load_data()
	grimoire = Grimoire.new(mantra_cfg, save)
	Services.analytics.log_event("session_start", {"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"learned": save.learned.size(), "bank": save.embers_bank})


func persist() -> void:
	if not _store.save_data(save):
		GameLog.error("save", "saving failed", {"dir": OS.get_user_data_dir()})


func gesture_min_score() -> float:
	return float(game_cfg.get("gesture_min_score", 0.72))


func all_levels() -> Array[String]:
	var out: Array[String] = []
	for ch in game_cfg.get("chapters", []):
		for id in ch.get("levels", []):
			out.append(str(id))
	return out


func chapter_of(level_id: String) -> Dictionary:
	for ch in game_cfg.get("chapters", []):
		if ch.get("levels", []).has(level_id):
			return ch
	return {}


func level_name(level_id: String) -> String:
	return str(GameConfig.level(level_id).get("name", level_id))


func next_level(id: String) -> String:
	var levels := all_levels()
	var i := levels.find(id)
	return levels[i + 1] if i >= 0 and i + 1 < levels.size() else ""


## The furthest unlocked level, used by "Continue".
func continue_level() -> String:
	var last := ""
	for id in all_levels():
		if save.unlocked.has(id):
			last = id
	return last


func has_progress() -> bool:
	return not save.results.is_empty()


## Learns the mantras a level teaches. Returns the ones that are new.
func learn_from_level(level_id: String) -> Array[String]:
	var fresh: Array[String] = []
	for id in GameConfig.level(level_id).get("teaches", []):
		if grimoire.learn(str(id)):
			fresh.append(str(id))
	if not fresh.is_empty():
		persist()
		mantras_changed.emit()
		Services.analytics.log_event("mantra_learned", {"ids": fresh, "how": "level"})
	return fresh


func buy_mantra(id: String) -> bool:
	if not grimoire.buy(id):
		return false
	persist()
	mantras_changed.emit()
	Services.analytics.log_event("mantra_learned", {"ids": [id], "how": "embers", "bank": save.embers_bank})
	return true


func set_custom_sign(id: String, strokes: Array[PackedVector2Array]) -> void:
	save.set_sign(id, strokes)
	persist()
	mantras_changed.emit()
	Services.analytics.log_event("custom_sign", {"id": id})


func clear_custom_sign(id: String) -> void:
	save.custom_signs.erase(id)
	persist()
	mantras_changed.emit()


## Records the run. Returns {"banked": int, "buyable": Array[String]} for the results screen.
func complete_level(id: String, time: float, embers: int) -> Dictionary:
	var banked := save.record_result(id, time, embers)
	var nxt := next_level(id)
	if nxt != "" and not save.unlocked.has(nxt):
		save.unlocked.append(nxt)
	persist()
	return {"banked": banked, "buyable": grimoire.newly_buyable_after(id)}


func vibrate(ms: int) -> void:
	if bool(save.settings.get("vibration", true)):
		Input.vibrate_handheld(ms)
