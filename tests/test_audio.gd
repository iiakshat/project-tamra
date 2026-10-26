extends "res://tests/test_case.gd"
## Guards the sound layer: every id gameplay calls exists, every file loads, loops loop,
## the budget holds, and the playback rules (variants, polyphony, voice cap) behave.

const AudioScript := preload("res://src/autoload/audio.gd")
const BUDGET_BYTES := 3 * 1024 * 1024

const REQUIRED := [
	"footstep", "footstep_heavy", "jump", "land", "land_heavy", "hurt", "death", "respawn",
	"strike_swing", "strike_hit", "enemy_alert", "enemy_windup", "enemy_attack", "enemy_hurt",
	"enemy_burn", "enemy_dazed", "stroke_start", "cast_fail",
	"cast_setu", "bridge_fade", "cast_chhaya", "decoy_pop", "cast_jwala", "jwala_impact",
	"cast_kavach", "kavach_block", "cast_drishti", "cast_udaan", "cast_tarang", "cast_bandhan",
	"barrier_burn", "ember_pickup", "checkpoint", "goal", "mantra_learned",
	"ui_click", "ui_back", "page_turn",
	"amb_wind", "amb_fire", "music_drone",
	"vo_jump", "vo_fall", "vo_hurt", "vo_death", "pant_in", "pant_out", "breath_in", "breath_out",
]
const LOOPS := ["amb_wind", "amb_fire", "music_drone"]


func test_required_ids_exist() -> void:
	var sounds := GameConfig.read("sounds")
	for id in REQUIRED:
		check(sounds.has(id), "sound %s is defined" % id)
	for id in LOOPS:
		check(bool(sounds.get(id, {}).get("loop", false)), "%s is marked loop" % id)


func test_entries_are_valid() -> void:
	var sounds := GameConfig.read("sounds")
	for id in sounds:
		var s: Dictionary = sounds[id]
		check(s.get("files", []) is Array and not s.get("files", []).is_empty(), "%s has files" % id)
		check(AudioScript.BUSES.has(str(s.get("bus", ""))), "%s: bus %s is valid" % [id, s.get("bus")])
		var pv := float(s.get("pitch_var", -1.0))
		check(pv >= 0.0 and pv <= 0.2, "%s: pitch_var in 0..0.2" % id)
		check(int(s.get("max_voices", 0)) >= 1, "%s: max_voices >= 1" % id)
		check(float(s.get("min_interval", -1.0)) >= 0.0, "%s: min_interval >= 0" % id)
		check(s.has("volume_db") and s.has("loop"), "%s: volume_db and loop set" % id)


func test_files_load_and_loops_loop() -> void:
	var sounds := GameConfig.read("sounds")
	for id in sounds:
		var loop := bool(sounds[id].get("loop", false))
		for path in sounds[id]["files"]:
			var exists := ResourceLoader.exists(path)
			check(exists, "%s: %s exists" % [id, path])
			if not exists:
				continue
			var stream = load(path)
			check(stream is AudioStream, "%s: %s loads as AudioStream" % [id, path])
			if loop and stream is AudioStreamWAV:
				check(stream.loop_mode != AudioStreamWAV.LOOP_DISABLED, "%s: %s imports with looping on" % [id, path])
			elif loop and stream is AudioStreamOggVorbis:
				check(stream.loop, "%s: %s imports with looping on" % [id, path])


func test_scene_loops_exist() -> void:
	var sounds := GameConfig.read("sounds")
	for scene in AudioScript.SCENES:
		for id in AudioScript.SCENES[scene]:
			check(sounds.has(id) and bool(sounds[id].get("loop", false)), "scene %s: %s is a loop sound" % [scene, id])


func test_audio_budget() -> void:
	var total := 0
	for sub in ["foley", "synth", "ui"]:
		var dir := "res://audio/%s/" % sub
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".ogg") or f.ends_with(".wav"):
				total += FileAccess.get_file_as_bytes(dir + f).size()
	check(total > 0, "audio files found")
	check(total < BUDGET_BYTES, "audio is %d bytes, budget %d" % [total, BUDGET_BYTES])


## Narration and vocals are OGG (converted with ffmpeg) and have their own allowance.
func test_voice_budget_and_lines() -> void:
	var total := 0
	for dir in ["res://audio/voice/", "res://audio/vocal/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".ogg") or f.ends_with(".wav"):
				total += FileAccess.get_file_as_bytes(dir + f).size()
	check(total < 5 * 1024 * 1024, "voice is %d bytes, budget 5 MiB" % total)
	var missing: Array = []
	_collect_missing(GameConfig.read("story"), missing)
	check(missing.is_empty(), "story lines without a voice file: %s" % str(missing))
	for m in GameConfig.read("mantras"):
		check(GameConfig.read("sounds").has("call_" + m), "battle cry for %s" % m)


## Walks the story script (scenes, beats, choice replies) for voice ids with no file.
func _collect_missing(node, missing: Array) -> void:
	if node is Array:
		for item in node:
			_collect_missing(item, missing)
	elif node is Dictionary:
		if node.has("voice") and not ResourceLoader.exists("res://audio/voice/%s.ogg" % node["voice"]):
			missing.append(node["voice"])
		for key in ["beats", "options", "reply"]:
			if node.has(key):
				_collect_missing(node[key], missing)
		if not node.has("beats") and not node.has("voice"):
			for k in node:
				if not str(k).begins_with("_") and node[k] is Array:
					_collect_missing(node[k], missing)


func test_variant_never_repeats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var last := -1
	var seen := {}
	for i in 200:
		var v: int = AudioScript.pick_variant(3, last, rng)
		check(v != last, "variant repeated at step %d" % i)
		check(v >= 0 and v < 3, "variant in range")
		seen[v] = true
		last = v
	check_eq(seen.size(), 3, "all variants used")
	check_eq(AudioScript.pick_variant(1, 0, rng), 0, "single variant")


## The runner has no live scene tree, so this drives setup by hand instead of _ready().
## Actual playback (voice cap, polyphony, crossfades) needs frames; see tools/audio_smoke.gd.
func test_buses_and_lookup() -> void:
	var audio: Node = AudioScript.new()
	audio._ensure_buses()
	for bus in AudioScript.BUSES:
		check(AudioServer.get_bus_index(bus) >= 0, "bus %s created" % bus)
	audio._defs = GameConfig.read("sounds")
	for id in audio._defs:
		audio._load_streams(id)
		check(not audio._streams[id].is_empty(), "%s has playable streams" % id)
	check(audio._warned.is_empty(), "no load warnings: %s" % str(audio._warned.keys()))
	audio.play("no_such_sound")
	audio.play("no_such_sound")
	check(audio._warned.has("no_such_sound"), "unknown id warned, not fatal")
	audio.set_bus_volume("Music", 0.5)
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	check(absf(db - linear_to_db(0.5)) < 0.01, "music bus volume set")
	audio.set_bus_volume("Music", 1.0)
	audio.free()
