extends SceneTree
## Headless playback smoke test for the Audio autoload. It needs real frames (players only
## play inside a live tree), so it is separate from tests/run_tests.gd. Run:
##   godot --headless --path . --script res://tools/audio_smoke.gd
## Exit code is 1 if any check fails.

var _audio: Node
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_audio = root.get_node_or_null("Audio")
	if _audio == null:  # not registered as an autoload yet
		_audio = load("res://src/autoload/audio.gd").new()
		root.add_child(_audio)
	await process_frame

	for bus in ["Music", "SFX", "Ambience", "UI"]:
		_check(AudioServer.get_bus_index(bus) >= 0, "bus %s exists" % bus)
	var game := root.get_node_or_null("Game")
	if game != null:
		var want := linear_to_db(float(game.save.settings.get("music", 0.8)))
		var got := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
		_check(absf(want - got) < 0.01, "Music bus follows saved setting (%.2f dB)" % got)

	_audio.play("footstep")
	_audio.play("footstep")
	_check(_voices("footstep") == 1, "min_interval blocks an instant footstep retrigger (%d)" % _voices("footstep"))

	for i in 10:
		_audio._last_played.erase("ember_pickup")
		_audio.play("ember_pickup", Vector2(200, 100))
	_check(_voices("ember_pickup") == 4, "ember_pickup held to max_voices 4 (%d)" % _voices("ember_pickup"))

	var sounds := GameConfig.read("sounds")
	for round in 4:
		for id in sounds:
			if bool(sounds[id]["loop"]):
				continue
			_audio._last_played.erase(id)
			_audio.play(id, Vector2(round * 50, 0) if round % 2 == 0 else null)
	var playing: int = _audio._playing_voices().size()
	_check(playing > 0 and playing <= 24, "global voice cap holds (%d playing)" % playing)

	_audio.play("no_such_sound")
	_check(_audio._warned.has("no_such_sound"), "unknown id is logged, not fatal")

	paused = true
	_audio._last_played.erase("ui_click")
	_audio.play("ui_click")
	await process_frame
	await process_frame
	_check(_voices("ui_click") >= 1, "ui_click plays while the tree is paused")

	_audio.set_scene_audio("level", 0.2)
	await create_timer(0.4, true).timeout
	for id in ["music_drone", "amb_wind", "amb_fire"]:
		_check(_audio.is_loop_playing(id), "level loop %s playing" % id)
		var p: AudioStreamPlayer = _audio._loops.get(id)
		if p != null:
			_check(p.playing, "%s player is playing" % id)
			_check(absf(p.volume_db - float(sounds[id]["volume_db"])) < 0.5, "%s faded in fully while paused (%.1f dB)" % [id, p.volume_db])
	_audio.set_scene_audio("story", 0.2)
	await create_timer(0.4, true).timeout
	_check(not _audio.is_loop_playing("amb_fire"), "story fades out amb_fire")
	_check(not _audio.is_loop_playing("amb_wind"), "story fades out amb_wind")
	_check(_audio.is_loop_playing("music_drone"), "story keeps music_drone")
	paused = false

	_audio.stop_all()
	_check(_audio._playing_voices().is_empty() and not _audio.is_loop_playing("music_drone"), "stop_all silences everything")
	for i in 30:
		await process_frame  # let the AudioServer drop finished playbacks before exit
	print("audio smoke: %d failures" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


func _voices(id: String) -> int:
	var n := 0
	for p in _audio._playing_voices():
		if p.get_meta("id", "") == id:
			n += 1
	return n


func _check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		_failures.append(message)
