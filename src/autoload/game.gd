extends Node
## Game-wide state: configs, save data, progression, mantra rules, daily rewards,
## the shop and settings.

signal mantras_changed
signal jyoti_changed(total: int)
signal vow_completed(vow: Dictionary)
signal settings_changed

var game_cfg: Dictionary
var player_cfg: Dictionary
var mantra_cfg: Dictionary
var shop_cfg: Dictionary
var save: SaveData
var grimoire: Grimoire
var daily: DailyRules

var _store: SaveStore


func _ready() -> void:
	InputSetup.ensure_actions()
	game_cfg = GameConfig.read("game")
	player_cfg = GameConfig.read("player")
	mantra_cfg = GameConfig.read("mantras")
	shop_cfg = GameConfig.read("shop")
	_store = SaveStore.new(Services.storage)
	save = _store.load_data()
	grimoire = Grimoire.new(mantra_cfg, save)
	grimoire.shop = shop_cfg
	daily = DailyRules.new(save)
	daily.refresh(today())
	Services.analytics.set_consent(analytics_consent() == "yes")
	# Device facts (model, Android version, screen) show which phones struggle; nothing personal.
	var screen := DisplayServer.screen_get_size()
	Services.analytics.log_event("session_start", {"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"learned": save.learned.size(), "jyoti": save.jyoti, "stars": save.total_stars(),
		"model": OS.get_model_name(), "os": OS.get_version(), "gpu": RenderingServer.get_video_adapter_name(),
		"screen": "%dx%d" % [screen.x, screen.y]})
	apply_audio_settings.call_deferred()


## Local calendar date, "YYYY-MM-DD". Daily rewards roll over at local midnight.
func today() -> String:
	return Time.get_date_string_from_system()


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


func cleared_levels() -> Array:
	return all_levels().filter(func(id: String) -> bool: return save.results.has(id))


func add_jyoti(amount: int) -> void:
	if amount == 0:
		return
	save.jyoti += amount
	persist()
	jyoti_changed.emit(save.jyoti)


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
	jyoti_changed.emit(save.jyoti)
	Services.analytics.log_event("mantra_learned", {"ids": [id], "how": "jyoti", "jyoti": save.jyoti})
	return true


func upgrade_mantra(id: String) -> bool:
	if not grimoire.upgrade(id):
		return false
	persist()
	mantras_changed.emit()
	jyoti_changed.emit(save.jyoti)
	Services.analytics.log_event("mantra_upgraded", {"id": id, "rank": save.rank(id)})
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


# --- shop -------------------------------------------------------------------------

func skin_palette(id: String = "") -> Dictionary:
	var key := id if id != "" else save.skin
	var raw: Dictionary = shop_cfg.get("skins", {}).get(key, {}).get("palette", {})
	var out := {}
	for k in raw:
		out[k] = GameConfig.color(raw[k])
	return out


func buy_skin(id: String) -> bool:
	var item: Dictionary = shop_cfg.get("skins", {}).get(id, {})
	if item.is_empty() or bool(item.get("premium", false)) or save.skins_owned.has(id) or save.jyoti < int(item.get("cost", 0)):
		return false
	save.jyoti -= int(item.get("cost", 0))
	save.skins_owned.append(id)
	save.skin = id
	persist()
	jyoti_changed.emit(save.jyoti)
	Services.analytics.log_event("skin_bought", {"id": id})
	return true


func equip_skin(id: String) -> void:
	if save.skins_owned.has(id):
		save.skin = id
		persist()


# --- daily ------------------------------------------------------------------------

## Counts toward today's vows; announces any vow it completes.
func track(event: String, amount: int = 1) -> void:
	daily.refresh(today())
	for v in daily.track(event, amount):
		vow_completed.emit(v)
		Services.analytics.log_event("vow_done", {"id": v["id"]})


func claim_blessing() -> int:
	var reward := daily.claim_blessing(today())
	if reward > 0:
		persist()
		jyoti_changed.emit(save.jyoti)
		Services.analytics.log_event("blessing_claimed", {"reward": reward, "step": daily.blessing_step()})
	return reward


func claim_vows() -> int:
	var reward := daily.claim_vows()
	if reward > 0:
		persist()
		jyoti_changed.emit(save.jyoti)
	return reward


## Something waiting to be collected right now: drives the menu badge. False once every
## claimable reward is claimed (an unplayed trial does not count; it is not a claim).
func daily_waiting() -> bool:
	daily.refresh(today())
	return daily.claimable(today())


## Records the run. Returns {"banked", "buyable", "stars", "trial_reward"} for the results.
func complete_level(id: String, time: float, embers: int, embers_total: int, deaths: int, trial_mod: String) -> Dictionary:
	var star_count := 1 + (1 if embers >= embers_total else 0) + (1 if deaths == 0 else 0)
	var banked := save.record_result(id, time, embers, star_count)
	var nxt := next_level(id)
	if nxt != "" and not save.unlocked.has(nxt):
		save.unlocked.append(nxt)
	var trial_reward := daily.complete_trial(today()) if trial_mod != "" else 0
	persist()
	jyoti_changed.emit(save.jyoti)
	track("levels")
	if deaths == 0:
		track("clean_clear")
	return {"banked": banked, "buyable": grimoire.newly_buyable_after(id), "stars": star_count, "trial_reward": trial_reward}


# --- settings ---------------------------------------------------------------------

func set_setting(key: String, value: Variant) -> void:
	save.settings[key] = value
	persist()
	apply_audio_settings()
	settings_changed.emit()


## "ask" until the player answers the data card, then "yes" or "no".
func analytics_consent() -> String:
	var v := str(save.settings.get("share_data", "ask"))
	return v if v == "yes" or v == "no" else "ask"


func set_analytics_consent(granted: bool) -> void:
	set_setting("share_data", "yes" if granted else "no")
	Services.analytics.set_consent(granted)
	if granted:  # Never send anything once the player has said no.
		Services.analytics.log_event("consent_granted")


func apply_audio_settings() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio == null:
		return
	var music: float = float(save.settings.get("music", 0.8)) if bool(save.settings.get("music_on", true)) else 0.0
	var sfx: float = float(save.settings.get("sfx", 1.0)) if bool(save.settings.get("sfx_on", true)) else 0.0
	audio.set_bus_volume("Music", music)
	audio.set_bus_volume("Ambience", music)
	audio.set_bus_volume("SFX", sfx)
	audio.set_bus_volume("UI", sfx)


func vibrate(ms: int) -> void:
	if bool(save.settings.get("vibration", true)):
		Input.vibrate_handheld(ms)
