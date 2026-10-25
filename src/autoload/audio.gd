extends Node
## Sound playback. Gameplay calls Audio.play("id") or Audio.play("id", global_pos); files,
## buses, volumes, variation and voice limits live in res://config/sounds.json, so sounds
## can be tuned without code changes. Keeps running while the tree is paused, so
## pause-menu clicks still sound. Unknown ids and missing files are logged once, never fatal.
##
## sounds.json entry: {"files": [...], "bus": "SFX"|"UI"|"Ambience"|"Music", "volume_db": n,
## "pitch_var": 0..0.2, "max_voices": n, "min_interval": s, "loop": bool, "pitch": n (optional base pitch)}

const CONFIG := "sounds"
const BUSES: Array[String] = ["Music", "SFX", "Ambience", "UI"]
const MAX_VOICES := 24  # one-shots playing at once, positional and flat together
const MAX_DISTANCE := 1500.0
const ATTENUATION := 1.2
const PANNING := 0.6  # phone speakers sit close together; hard pans sound odd
const SILENT_DB := -80.0

## Loops that belong to each screen. set_scene_audio() crossfades between them.
const SCENES := {
	"menu": ["music_drone", "amb_wind"],
	"story": ["music_drone"],
	"level": ["music_drone", "amb_wind", "amb_fire"],
}

var _defs: Dictionary = {}  # id -> config entry
var _streams: Dictionary = {}  # id -> Array of AudioStream, loaded at start
var _last_variant: Dictionary = {}  # id -> index played last
var _last_played: Dictionary = {}  # id -> msec
var _warned: Dictionary = {}
var _flat: Array[AudioStreamPlayer] = []
var _positional: Array[AudioStreamPlayer2D] = []
var _loops: Dictionary = {}  # id -> AudioStreamPlayer
var _fades: Dictionary = {}  # id -> Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_buses()
	_defs = GameConfig.read(CONFIG)
	for id in _defs:
		_load_streams(str(id))
	_apply_saved_volumes.call_deferred()  # Game may be registered after Audio


## Plays a one-shot. A Vector2 `pos` (global) makes it positional; anything else plays flat.
func play(id: String, pos: Variant = null, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var def := _def(id)
	if def.is_empty():
		return
	var now := Time.get_ticks_msec()
	if _last_played.has(id) and now - int(_last_played[id]) < int(float(def.get("min_interval", 0.0)) * 1000.0):
		return
	var stream := _pick_stream(id)
	if stream == null:
		return
	_last_played[id] = now
	var bus := _bus_of(def)
	var db := float(def.get("volume_db", 0.0)) + volume_db
	var spread := float(def.get("pitch_var", 0.0))
	var scale := maxf(0.05, float(def.get("pitch", 1.0)) * pitch * (1.0 + _rng.randf_range(-spread, spread)))
	var limit := maxi(1, int(def.get("max_voices", 4)))
	if pos is Vector2:
		var p2 := _voice(_positional, id, limit, true) as AudioStreamPlayer2D
		p2.stream = stream
		p2.bus = bus
		p2.volume_db = db
		p2.pitch_scale = scale
		p2.global_position = pos
		_tag(p2, id, now)
		p2.play()
	else:
		var p := _voice(_flat, id, limit, false) as AudioStreamPlayer
		p.stream = stream
		p.bus = bus
		p.volume_db = db
		p.pitch_scale = scale
		_tag(p, id, now)
		p.play()


## Starts (or resumes, if it was fading out) a looping sound with a fade-in.
func play_loop(id: String, fade: float = 1.0) -> void:
	var def := _def(id)
	if def.is_empty():
		return
	if not _loops.has(id):
		var stream := _pick_stream(id)
		if stream == null:
			return
		_ensure_looping(stream)
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = _bus_of(def)
		add_child(player)
		_loops[id] = player
		_set_loop_gain(0.0, id)
		player.play()
	_fade_loop(id, 1.0, fade, false)


func stop_loop(id: String, fade: float = 0.6) -> void:
	if _loops.has(id):
		_fade_loop(id, 0.0, fade, true)


## Crossfades to the loops of a screen: "menu", "story" or "level".
func set_scene_audio(scene: String, fade: float = 1.5) -> void:
	if not SCENES.has(scene):
		_warn_once("scene:" + scene, "unknown audio scene", {"scene": scene})
	var wanted: Array = SCENES.get(scene, [])
	for id in _loops.keys():
		if not wanted.has(id):
			stop_loop(id, fade)
	for id in wanted:
		play_loop(id, fade)


## linear is 0..1 (a settings slider value). 0 mutes the bus.
func set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		_warn_once("bus:" + bus, "unknown bus", {"bus": bus})
		return
	var v := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(v) if v > 0.0 else SILENT_DB)
	AudioServer.set_bus_mute(idx, v <= 0.0)


## Silences every one-shot and loop at once, without fades.
func stop_all() -> void:
	for p in _playing_voices():
		p.call("stop")
	for id in _loops.keys():
		stop_loop(id, 0.0)


func is_loop_playing(id: String) -> bool:
	return _loops.has(id)


## Never returns the same index twice in a row when there is more than one variant.
static func pick_variant(count: int, last: int, rng: RandomNumberGenerator) -> int:
	if count <= 1:
		return 0
	if last < 0 or last >= count:
		return rng.randi_range(0, count - 1)
	var i := rng.randi_range(0, count - 2)
	return i + 1 if i >= last else i


# --- Voices --------------------------------------------------------------------------

## A player to use for `id`: restarts this id's oldest voice if it is at its polyphony
## limit, steals the oldest voice anywhere if the global cap is reached, else a free one.
func _voice(pool: Array, id: String, limit: int, positional: bool) -> Node:
	var playing := _playing_voices()
	var same: Array[Node] = []
	for p in playing:
		if p.get_meta("id", "") == id:
			same.append(p)
	var victim: Node = null
	if same.size() >= limit:
		victim = _oldest(same)
	elif playing.size() >= MAX_VOICES:
		victim = _oldest(playing)
	if victim != null:
		victim.call("stop")
		if (victim is AudioStreamPlayer2D) == positional:
			return victim
	for p: Node in pool:
		if not p.get("playing"):
			return p
	var player: Node
	if positional:
		var p2 := AudioStreamPlayer2D.new()
		p2.max_distance = MAX_DISTANCE
		p2.attenuation = ATTENUATION
		p2.panning_strength = PANNING
		_positional.append(p2)
		player = p2
	else:
		var p := AudioStreamPlayer.new()
		_flat.append(p)
		player = p
	add_child(player)
	return player


func _playing_voices() -> Array[Node]:
	var out: Array[Node] = []
	for p in _flat:
		if p.playing:
			out.append(p)
	for p in _positional:
		if p.playing:
			out.append(p)
	return out


func _oldest(players: Array[Node]) -> Node:
	var best: Node = players[0]
	for p in players:
		if int(p.get_meta("started", 0)) < int(best.get_meta("started", 0)):
			best = p
	return best


func _tag(player: Node, id: String, now: int) -> void:
	player.set_meta("id", id)
	player.set_meta("started", now)


# --- Loops ---------------------------------------------------------------------------

func _fade_loop(id: String, target: float, seconds: float, release: bool) -> void:
	if _fades.has(id):
		(_fades[id] as Tween).kill()
		_fades.erase(id)
	var player: AudioStreamPlayer = _loops[id]
	var from := float(player.get_meta("gain", 0.0))
	if seconds <= 0.0:
		_set_loop_gain(target, id)
		if release:
			_release_loop(id)
		return
	var tween := create_tween()
	tween.tween_method(_set_loop_gain.bind(id), from, target, seconds)
	tween.tween_callback((_release_loop if release else _fade_done).bind(id))
	_fades[id] = tween


func _fade_done(id: String) -> void:
	_fades.erase(id)


func _set_loop_gain(gain: float, id: String) -> void:
	var player: AudioStreamPlayer = _loops.get(id)
	if player == null:
		return
	player.set_meta("gain", gain)
	var base := float(_def(id).get("volume_db", 0.0))
	player.volume_db = base + linear_to_db(gain) if gain > 0.0001 else SILENT_DB


func _release_loop(id: String) -> void:
	_fades.erase(id)
	var player: AudioStreamPlayer = _loops.get(id)
	_loops.erase(id)
	if player != null:
		player.stop()
		player.queue_free()


## Imported loops already loop; this covers a file whose import flags were lost.
func _ensure_looping(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


# --- Config and setup ----------------------------------------------------------------

func _def(id: String) -> Dictionary:
	var def = _defs.get(id)
	if def is Dictionary:
		return def
	_warn_once(id, "unknown sound id", {"id": id})
	return {}


func _load_streams(id: String) -> void:
	var list: Array[AudioStream] = []
	var missing: Array[String] = []
	var def = _defs[id]
	var files = def.get("files", []) if def is Dictionary else []
	for path in files:
		var res: Resource = load(str(path)) if ResourceLoader.exists(str(path)) else null
		if res is AudioStream:
			list.append(res)
		else:
			missing.append(str(path))
	if not missing.is_empty():
		_warn_once(id, "sound files missing", {"id": id, "files": missing})
	_streams[id] = list


func _pick_stream(id: String) -> AudioStream:
	var list: Array[AudioStream] = _streams.get(id, [] as Array[AudioStream])
	if list.is_empty():
		_warn_once(id, "sound has no playable files", {"id": id})
		return null
	var i := pick_variant(list.size(), int(_last_variant.get(id, -1)), _rng)
	_last_variant[id] = i
	return list[i]


func _bus_of(def: Dictionary) -> String:
	var bus := str(def.get("bus", "SFX"))
	return bus if BUSES.has(bus) else "SFX"


func _ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		AudioServer.add_bus_effect(0, limiter)  # many overlapping sounds must not clip


func _apply_saved_volumes() -> void:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	if game.has_method("apply_audio_settings"):
		game.apply_audio_settings()  # knows about the music/sound mute toggles
		return
	var save = game.get("save")
	if save == null:
		return
	var settings = save.get("settings")
	if settings is Dictionary:
		set_bus_volume("Music", float(settings.get("music", 0.8)))
		set_bus_volume("SFX", float(settings.get("sfx", 1.0)))


func _warn_once(key: String, message: String, data: Dictionary) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	GameLog.warn("audio", message, data)
