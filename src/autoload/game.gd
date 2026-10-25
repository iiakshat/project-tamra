extends Node
## Game-wide state: configs, save data and progression.

var game_cfg: Dictionary
var player_cfg: Dictionary
var mantra_cfg: Dictionary
var save: SaveData

var _store: SaveStore


func _ready() -> void:
	InputSetup.ensure_actions()
	game_cfg = GameConfig.read("game")
	player_cfg = GameConfig.read("player")
	mantra_cfg = GameConfig.read("mantras")
	_store = SaveStore.new(Services.storage)
	save = _store.load_data()
	Services.analytics.log_event("session_start", {"version": str(ProjectSettings.get_setting("application/config/version", ""))})


func persist() -> void:
	if not _store.save_data(save):
		push_error("Saving failed.")


func all_levels() -> Array[String]:
	var out: Array[String] = []
	for ch in game_cfg.get("chapters", []):
		for id in ch.get("levels", []):
			out.append(str(id))
	return out


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


func complete_level(id: String, time: float, embers: int) -> void:
	save.record_result(id, time, embers)
	var nxt := next_level(id)
	if nxt != "" and not save.unlocked.has(nxt):
		save.unlocked.append(nxt)
	persist()


func vibrate(ms: int) -> void:
	if bool(save.settings.get("vibration", true)):
		Input.vibrate_handheld(ms)
