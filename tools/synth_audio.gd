extends SceneTree
## Generates every synthesized sound (magic, fire, impacts, ambience, drone) as mono WAV.
## Run from the project root, then re-import:
##   godot --headless --path . --script res://tools/synth_audio.gd
##   godot --headless --path . --import
## Add `-- --only=footstep,ui_tap` to write only those sounds (base names).
## Round 5 sounds (udaan_whoosh, glide_wind, fire_whoomph, burn_crackle, heart_pickup,
## lives_lost) ship as OGG to stay under the 3 MB audio budget: after rendering them,
## convert with ../_tools/ffmpeg/ffmpeg.exe -i X.wav -c:a libvorbis -q:a 4 X.ogg and
## delete the WAV.
## Seeds are fixed, so output is reproducible. Loops are rendered so their ends join
## without a click, and their .import files are set to loop forward.

const DEFAULT_RATE := 22050
const LOOP_RATE := 16000  # loops are dark and band-limited; 16 kHz keeps the budget
const OUT := "res://audio/synth/"

# Longest a one-shot may ring, in seconds. Keeps reverb tails from eating the
# audio budget (< 3 MB for all sound files).
const MAX_SECONDS := {
	"death": 2.0, "respawn": 1.5, "hurt": 0.6, "enemy_alert": 0.8, "enemy_burn": 1.4,
	"enemy_dazed": 1.1, "cast_setu": 1.5, "bridge_fade": 1.0, "cast_chhaya": 1.3,
	"cast_kavach": 2.0, "cast_drishti": 1.5, "cast_udaan": 1.2, "cast_tarang": 1.3,
	"cast_bandhan": 1.3, "barrier_burn": 1.7, "ember_pickup": 0.55, "checkpoint": 1.6,
	"goal": 2.4, "mantra_learned": 2.3, "footstep": 0.22, "land": 0.35, "ui_tap": 0.3,
	"ui_back": 0.35, "strike_hit": 0.3, "udaan_whoosh": 1.0, "glide_wind": 1.6,
	"fire_whoomph": 1.0, "burn_crackle": 1.6, "heart_pickup": 1.4, "lives_lost": 2.2,
}

enum { LOW, BAND, HIGH }

# Indian pentatonic scale on Sa = C5, plus octaves used below.
const SA := 523.25
const RE := 587.33
const GA := 659.26
const PA := 783.99
const DHA := 880.0

var rate := DEFAULT_RATE
var rng := RandomNumberGenerator.new()
var _written: Array[String] = []
var _only: PackedStringArray = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var t0 := Time.get_ticks_msec()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.trim_prefix("--only=").split(",", false)
	# Soft foley and UI (round 4: the owner heard the old Kenney clicks as "utensils").
	for v in 6:
		_save("footstep_%d" % v, footstep(v))
	for v in 4:
		_save("land_%d" % v, land(v))
	for v in 3:
		_save("ui_tap_%d" % v, ui_tap(v))
	for v in 2:
		_save("ui_back_%d" % v, ui_back(v))
	for v in 3:
		_save("strike_swing_%d" % v, strike_swing(v))
		_save("strike_hit_%d" % v, strike_hit(v))
	for v in 2:
		_save("land_heavy_%d" % v, land_heavy(v))
		_save("hurt_%d" % v, hurt(v))
		_save("enemy_attack_%d" % v, enemy_attack(v))
		_save("enemy_hurt_%d" % v, enemy_hurt(v))
	_save("death", death())
	_save("respawn", respawn())
	_save("enemy_alert", enemy_alert())
	_save("enemy_burn", enemy_burn())
	_save("enemy_dazed", enemy_dazed())
	_save("stroke_start", stroke_start())
	_save("cast_fail", cast_fail())
	_save("cast_setu", cast_setu())
	_save("bridge_fade", bridge_fade())
	_save("cast_chhaya", cast_chhaya())
	_save("decoy_pop", decoy_pop())
	_save("cast_jwala", cast_jwala())
	_save("jwala_impact", jwala_impact())
	_save("cast_kavach", cast_kavach())
	_save("kavach_block", kavach_block())
	_save("cast_drishti", cast_drishti())
	_save("cast_udaan", cast_udaan())
	_save("cast_tarang", cast_tarang())
	_save("cast_bandhan", cast_bandhan())
	_save("barrier_burn", barrier_burn())
	# Round 5: UDAAN flight, JWALA burning, hearts.
	_save("udaan_whoosh", udaan_whoosh())
	_save("glide_wind", glide_wind())
	_save("fire_whoomph", fire_whoomph())
	_save("burn_crackle", burn_crackle())
	_save("heart_pickup", heart_pickup())
	_save("lives_lost", lives_lost())
	var scale := [SA, RE, GA, PA, DHA]
	for v in scale.size():
		_save("ember_pickup_%d" % v, ember_pickup(scale[v]))
	_save("checkpoint", checkpoint())
	_save("goal", goal())
	_save("mantra_learned", mantra_learned())
	_save("amb_wind", amb_wind(), true)
	_save("amb_fire", amb_fire(), true)
	_save("music_drone", music_drone(), true)
	print("synth_audio: wrote %d files in %.1f s" % [_written.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)


# --- Recipes -----------------------------------------------------------------------

func strike_swing(v: int) -> PackedFloat32Array:
	_seed("strike_swing", v)
	var b := buf(0.34)
	var k := rng.randf_range(0.85, 1.15)
	noise(b, 0.0, 0.34, BAND, func(u: float) -> float: return lerpf(3000.0, 600.0, u) * k, 1.3,
		func(u: float) -> float: return env(u, 0.35, 2.0))
	noise(b, 0.0, 0.3, LOW, func(_u: float) -> float: return 350.0, 0.7,
		func(u: float) -> float: return 0.35 * env(u, 0.4, 2.0))
	return finish(b, 0.8)


## Staff on leather: a muffled thud with a soft slap, no bright click or ring.
func strike_hit(v: int) -> PackedFloat32Array:
	_seed("strike_hit", v)
	var b := buf(0.3)
	var k := rng.randf_range(0.9, 1.12)
	thump(b, 0.0, 150.0 * k, 58.0, 1.0, 0.075)
	noise(b, 0.0, 0.16, LOW, func(u: float) -> float: return lerpf(900.0, 260.0, u) * k, 0.7,
		func(u: float) -> float: return 0.75 * exp(-u * 7.0))
	noise(b, 0.0, 0.04, BAND, func(_u: float) -> float: return 520.0 * k, 0.9,
		func(u: float) -> float: return 0.3 * (1.0 - u))
	return finish(reverb(b, 0.08, 0.5, 0.6, 0.2), 0.9)


## A bare foot on packed ash: a low pad and a little grit, never a click.
func footstep(v: int) -> PackedFloat32Array:
	_seed("footstep", v)
	var b := buf(0.2)
	var k := rng.randf_range(0.85, 1.15)
	thump(b, 0.0, 95.0 * k, 55.0, 0.55, 0.03)
	noise(b, 0.0, 0.14, LOW, func(u: float) -> float: return lerpf(800.0, 300.0, u) * k, 0.7,
		func(u: float) -> float: return 0.55 * exp(-u * 6.0))
	var toe := rng.randf_range(0.025, 0.05)
	noise(b, toe, 0.06, BAND, func(_u: float) -> float: return 1100.0 * k, 0.7,
		func(u: float) -> float: return 0.12 * env(u, 0.2, 2.0))
	return finish(b, 0.55)


## Landing: a soft body thud into dust.
func land(v: int) -> PackedFloat32Array:
	_seed("land", v)
	var b := buf(0.32)
	var k := rng.randf_range(0.9, 1.1)
	thump(b, 0.0, 110.0 * k, 45.0, 0.9, 0.07)
	noise(b, 0.0, 0.26, LOW, func(u: float) -> float: return lerpf(1100.0, 280.0, u) * k, 0.7,
		func(u: float) -> float: return 0.6 * exp(-u * 5.0))
	return finish(b, 0.7)


## UI tap: a muted tabla stroke (dayan "na"), a touch higher for each variant.
func ui_tap(v: int) -> PackedFloat32Array:
	_seed("ui_tap", v)
	var b := buf(0.3)
	var f: float = [392.0, 415.0, 440.0][v % 3]
	tone(b, 0.0, f, 0.6, 0.002, 0.08, f * 0.97, 0.05)
	tone(b, 0.0, f * 2.0, 0.22, 0.002, 0.05)
	tone(b, 0.0, f * 3.0, 0.08, 0.002, 0.03)
	noise(b, 0.0, 0.015, LOW, func(_u: float) -> float: return 2200.0, 0.7,
		func(u: float) -> float: return 0.15 * (1.0 - u))
	return finish(reverb(b, 0.1, 0.5, 0.5, 0.15), 0.55)


## UI back: the bass drum's "ge", a soft low stroke that bends down.
func ui_back(v: int) -> PackedFloat32Array:
	_seed("ui_back", v)
	var b := buf(0.35)
	var f := 150.0 + v * 12.0
	tone(b, 0.0, f, 0.7, 0.003, 0.12, f * 0.78, 0.14)
	tone(b, 0.0, f * 2.0, 0.15, 0.003, 0.06)
	noise(b, 0.0, 0.03, LOW, func(_u: float) -> float: return 500.0, 0.7,
		func(u: float) -> float: return 0.2 * (1.0 - u))
	return finish(reverb(b, 0.1, 0.5, 0.5, 0.15), 0.6)


func land_heavy(v: int) -> PackedFloat32Array:
	_seed("land_heavy", v)
	var b := buf(0.5)
	thump(b, 0.0, 115.0 + v * 12.0, 40.0, 1.0, 0.12)
	noise(b, 0.0, 0.45, LOW, func(u: float) -> float: return lerpf(900.0, 250.0, u), 0.7,
		func(u: float) -> float: return 0.7 * exp(-u * 6.0))
	noise(b, 0.01, 0.15, BAND, func(_u: float) -> float: return 2500.0, 0.8,
		func(u: float) -> float: return 0.15 * exp(-u * 4.0))
	return finish(b, 0.95)


func hurt(v: int) -> PackedFloat32Array:
	_seed("hurt", v)
	var b := buf(0.6)
	var f := 220.0 + v * 25.0
	thump(b, 0.0, 140.0, 60.0, 0.9, 0.1)
	tone(b, 0.0, f, 0.35, 0.02, 0.22, f * 0.8, 0.3)
	tone(b, 0.0, f * 1.06, 0.3, 0.02, 0.22, f * 0.85, 0.3)
	noise(b, 0.0, 0.2, BAND, func(_u: float) -> float: return 900.0, 0.9,
		func(u: float) -> float: return 0.5 * exp(-u * 5.0))
	return finish(reverb(b, 0.2, 0.7, 0.4), 0.9)


func death() -> PackedFloat32Array:
	_seed("death", 0)
	var b := buf(2.2)
	gong(b, 0.0, 110.0, 1.0, 1.0, 0.8, 1.3)
	noise(b, 0.0, 2.0, LOW, func(u: float) -> float: return lerpf(2200.0, 180.0, sqrt(u)), 0.8,
		func(u: float) -> float: return 0.45 * env(u, 0.04, 1.6))
	return finish(reverb(b, 0.35, 0.8, 0.35, 0.8), 0.9)


func respawn() -> PackedFloat32Array:
	_seed("respawn", 0)
	var b := buf(1.4)
	noise(b, 0.0, 0.7, BAND, func(u: float) -> float: return 400.0 * pow(8.0, u), 1.6,
		func(u: float) -> float: return 0.35 * u * u)
	var notes := [SA, RE, GA, PA, SA * 2.0]
	for i in notes.size():
		bell(b, 0.62 + i * 0.07, notes[i], 0.35 + i * 0.05, 0.45)
	return finish(reverb(b, 0.3, 0.78, 0.3, 0.6), 0.85)


func enemy_alert() -> PackedFloat32Array:
	_seed("enemy_alert", 0)
	var b := buf(0.75)
	for h in range(1, 7):
		tone(b, 0.0, 90.0 * h, 0.5 / h, 0.06, 0.3, 130.0 * h, 0.3)
		tone(b, 0.0, 93.5 * h, 0.4 / h, 0.06, 0.3, 135.0 * h, 0.3)
	noise(b, 0.0, 0.65, BAND, func(u: float) -> float: return lerpf(3200.0, 1600.0, u), 2.0,
		func(u: float) -> float: return 0.6 * env(u, 0.2, 1.5))
	return finish(reverb(b, 0.2, 0.7, 0.4), 0.85)


func enemy_attack(v: int) -> PackedFloat32Array:
	_seed("enemy_attack", v)
	var b := buf(0.45)
	var k := rng.randf_range(0.85, 1.1)
	noise(b, 0.0, 0.45, BAND, func(u: float) -> float: return lerpf(1700.0, 350.0, u) * k, 1.0,
		func(u: float) -> float: return env(u, 0.3, 2.0))
	for h in range(1, 5):
		tone(b, 0.05, 72.0 * h, 0.3 / h, 0.05, 0.15, 50.0 * h, 0.3)
	return finish(b, 0.85)


func enemy_hurt(v: int) -> PackedFloat32Array:
	_seed("enemy_hurt", v)
	var b := buf(0.45)
	noise(b, 0.0, 0.4, LOW, func(u: float) -> float: return lerpf(1800.0, 300.0, u), 0.8,
		func(u: float) -> float: return 0.8 * exp(-u * 4.0))
	thump(b, 0.0, 120.0 + v * 15.0, 60.0, 0.7, 0.07)
	tone(b, 0.0, 180.0, 0.3, 0.005, 0.12, 150.0, 0.2)
	tone(b, 0.0, 191.0, 0.3, 0.005, 0.12, 158.0, 0.2)
	return finish(reverb(b, 0.15, 0.6, 0.4), 0.9)


func enemy_burn() -> PackedFloat32Array:
	_seed("enemy_burn", 0)
	var b := buf(1.5)
	noise(b, 0.0, 1.4, BAND, func(u: float) -> float: return 500.0 + 1100.0 * sin(PI * sqrt(u)), 0.7,
		func(u: float) -> float: return 0.8 * env(u, 0.08, 1.2))
	noise(b, 0.0, 1.2, HIGH, func(_u: float) -> float: return 4000.0, 0.7,
		func(u: float) -> float: return 0.3 * env(u, 0.05, 3.0))
	crackle(b, 0.0, 1.3, 45.0, 0.5, func(u: float) -> float: return 1.0 - u)
	for h in range(1, 4):
		tone(b, 0.1, 220.0 * h, 0.25 / h, 0.05, 0.5, 110.0 * h, 1.0)
	return finish(reverb(b, 0.25, 0.75, 0.4), 0.9)


func enemy_dazed() -> PackedFloat32Array:
	_seed("enemy_dazed", 0)
	var b := buf(1.1)
	var notes := [940.0, 800.0, 880.0, 740.0]
	for i in notes.size():
		tone(b, i * 0.17, notes[i], 0.4, 0.004, 0.22, notes[i] * 0.9, 0.2, 8.0, 0.035)
		tone(b, i * 0.17, notes[i] * 2.0, 0.1, 0.004, 0.1)
	return finish(reverb(b, 0.25, 0.7, 0.3), 0.75)


func stroke_start() -> PackedFloat32Array:
	_seed("stroke_start", 0)
	var b := buf(0.3)
	noise(b, 0.0, 0.25, BAND, func(_u: float) -> float: return 3000.0, 0.8,
		func(u: float) -> float: return 0.4 * env(u, 0.15, 2.0))
	tone(b, 0.0, PA * 2.0, 0.25, 0.005, 0.1)
	return finish(reverb(b, 0.15, 0.6, 0.3, 0.4), 0.6)


func cast_fail() -> PackedFloat32Array:
	_seed("cast_fail", 0)
	var b := buf(0.65)
	crackle(b, 0.0, 0.5, 60.0, 0.45, func(u: float) -> float: return 1.0 - u)
	noise(b, 0.0, 0.5, BAND, func(u: float) -> float: return lerpf(1200.0, 300.0, u), 1.0,
		func(u: float) -> float: return 0.5 * env(u, 0.02, 2.0))
	tone(b, 0.0, 330.0, 0.3, 0.01, 0.25, 220.0, 0.4)
	tone(b, 0.0, 349.0, 0.3, 0.01, 0.25, 233.0, 0.4)
	return finish(reverb(b, 0.15, 0.6, 0.4), 0.8)


func cast_setu() -> PackedFloat32Array:
	_seed("cast_setu", 0)
	var b := buf(1.6)
	tone(b, 0.0, 400.0, 0.15, 0.05, 0.25, 1600.0, 0.35)
	var notes := [SA, GA, PA, SA * 2.0]
	for i in notes.size():
		bell(b, 0.05 + i * 0.08, notes[i], 0.5 + i * 0.07, 0.7)
	noise(b, 0.0, 1.0, HIGH, func(_u: float) -> float: return 5000.0, 0.7,
		func(u: float) -> float: return 0.08 * env(u, 0.3, 2.0))
	return finish(reverb(b, 0.35, 0.78, 0.3, 0.7), 0.9)


func bridge_fade() -> PackedFloat32Array:
	_seed("bridge_fade", 0)
	var b := buf(1.0)
	var notes := [SA * 2.0, PA, GA]
	for i in notes.size():
		bell(b, i * 0.09, notes[i], 0.3, 0.4)
	noise(b, 0.0, 0.9, BAND, func(u: float) -> float: return lerpf(2000.0, 600.0, u), 1.0,
		func(u: float) -> float: return 0.25 * env(u, 0.1, 1.5))
	return finish(reverb(b, 0.3, 0.8, 0.3, 0.8), 0.7)


func cast_chhaya() -> PackedFloat32Array:
	_seed("cast_chhaya", 0)
	var b := buf(1.2)
	noise(b, 0.0, 1.1, BAND, func(u: float) -> float: return 500.0 + 1900.0 * sin(PI * u), 1.5,
		func(u: float) -> float: return 0.8 * env(u, 0.35, 1.5))
	for f in [880.0, 886.0, 1320.0, 1327.0]:
		tone(b, 0.1, f, 0.12, 0.25, 0.4, 0.0, 0.0, 5.0, 0.01)
	return finish(reverb(b, 0.4, 0.8, 0.3, 0.7), 0.85)


func decoy_pop() -> PackedFloat32Array:
	_seed("decoy_pop", 0)
	var b := buf(0.4)
	noise(b, 0.0, 0.35, LOW, func(u: float) -> float: return lerpf(2500.0, 400.0, u), 0.8,
		func(u: float) -> float: return 0.8 * exp(-u * 5.0))
	tone(b, 0.0, 700.0, 0.5, 0.003, 0.1, 220.0, 0.12)
	return finish(reverb(b, 0.15, 0.6, 0.3, 0.4), 0.85)


func cast_jwala() -> PackedFloat32Array:
	_seed("cast_jwala", 0)
	var b := buf(0.9)
	noise(b, 0.0, 0.9, BAND, func(u: float) -> float: return 400.0 * pow(5.5, minf(u * 2.0, 1.0)), 0.8,
		func(u: float) -> float: return env(u, 0.08, 1.6))
	noise(b, 0.0, 0.8, LOW, func(_u: float) -> float: return 250.0, 0.7,
		func(u: float) -> float: return 0.5 * env(u, 0.05, 1.5))
	crackle(b, 0.0, 0.8, 50.0, 0.4)
	return finish(reverb(b, 0.15, 0.6, 0.4, 0.5), 0.9)


func jwala_impact() -> PackedFloat32Array:
	_seed("jwala_impact", 0)
	var b := buf(0.8)
	thump(b, 0.0, 100.0, 40.0, 1.0, 0.15)
	noise(b, 0.0, 0.75, LOW, func(u: float) -> float: return lerpf(3500.0, 500.0, u), 0.7,
		func(u: float) -> float: return 0.8 * exp(-u * 4.0))
	crackle(b, 0.02, 0.7, 80.0, 0.5, func(u: float) -> float: return 1.0 - u)
	return finish(reverb(b, 0.2, 0.7, 0.4, 0.6), 0.95)


func cast_kavach() -> PackedFloat32Array:
	_seed("cast_kavach", 0)
	var b := buf(2.3)
	gong(b, 0.0, 196.0, 1.0, 1.2, 1.0, 0.0, 0.03)
	noise(b, 0.0, 0.15, LOW, func(_u: float) -> float: return 600.0, 0.7,
		func(u: float) -> float: return 0.2 * exp(-u * 4.0))
	return finish(reverb(b, 0.35, 0.8, 0.3, 0.8), 0.85)


func kavach_block() -> PackedFloat32Array:
	_seed("kavach_block", 0)
	var b := buf(0.7)
	bell(b, 0.0, 620.0, 0.7, 0.35)
	thump(b, 0.0, 150.0, 70.0, 0.7, 0.06)
	noise(b, 0.0, 0.08, HIGH, func(_u: float) -> float: return 3000.0, 0.7,
		func(u: float) -> float: return 0.3 * exp(-u * 4.0))
	return finish(reverb(b, 0.2, 0.7, 0.3, 0.6), 0.9)


func cast_drishti() -> PackedFloat32Array:
	_seed("cast_drishti", 0)
	var b := buf(1.6)
	var glass := [SA * 4.0, RE * 4.0, GA * 4.0, PA * 4.0, DHA * 4.0, SA * 8.0]
	for i in 10:
		var f: float = glass[rng.randi() % glass.size()] * rng.randf_range(0.998, 1.002)
		tone(b, rng.randf_range(0.0, 0.45), f, 0.12, 0.01, 0.5)
	tone(b, 0.0, PA * 2.0, 0.2, 0.3, 0.6, 0.0, 0.0, 4.0, 0.004)
	tone(b, 0.0, PA * 2.0 + 4.0, 0.2, 0.3, 0.6)
	noise(b, 0.0, 1.0, HIGH, func(_u: float) -> float: return 6000.0, 0.7,
		func(u: float) -> float: return 0.05 * env(u, 0.3, 1.5))
	return finish(reverb(b, 0.45, 0.8, 0.25, 0.7), 0.75)


func cast_udaan() -> PackedFloat32Array:
	_seed("cast_udaan", 0)
	var b := buf(1.0)
	noise(b, 0.0, 1.0, BAND, func(u: float) -> float: return 300.0 * pow(10.0, u), 1.4,
		func(u: float) -> float: return 0.9 * env(u, 0.6, 1.5))
	tone(b, 0.0, 280.0, 0.25, 0.1, 0.4, 950.0, 0.7)
	tone(b, 0.0, 560.0, 0.1, 0.1, 0.4, 1900.0, 0.7)
	return finish(reverb(b, 0.3, 0.8, 0.3, 0.8), 0.85)


## UDAAN's leap: a fast rising rush of air with a soft low push under it.
func udaan_whoosh() -> PackedFloat32Array:
	_seed("udaan_whoosh", 0)
	var b := buf(1.0)
	noise(b, 0.0, 0.9, BAND, func(u: float) -> float: return 250.0 * pow(12.0, sqrt(u)), 1.1,
		func(u: float) -> float: return env(u, 0.3, 2.0))
	noise(b, 0.0, 0.7, LOW, func(_u: float) -> float: return 180.0, 0.8,
		func(u: float) -> float: return 0.7 * env(u, 0.1, 2.5))
	thump(b, 0.0, 95.0, 55.0, 0.45, 0.12)
	return finish(reverb(b, 0.2, 0.7, 0.4, 0.5), 0.9)


## The glide: soft wing beats in a band of moving air.
func glide_wind() -> PackedFloat32Array:
	_seed("glide_wind", 0)
	var b := buf(1.6)
	noise(b, 0.0, 1.55, BAND, func(u: float) -> float: return 700.0 + 300.0 * sin(u * TAU * 2.0), 1.6,
		func(u: float) -> float: return 0.45 * env(u, 0.15, 1.2))
	for k in 4:
		var t0 := 0.05 + k * 0.36
		noise(b, t0, 0.22, LOW, func(_u: float) -> float: return 420.0, 0.9,
			func(u: float) -> float: return 0.9 * env(u, 0.35, 2.0) * (1.0 - k * 0.18))
	return finish(reverb(b, 0.2, 0.6, 0.5, 0.4), 0.7)


## A body catching fire: a deep "whoomph" of air sucked into flame.
func fire_whoomph() -> PackedFloat32Array:
	_seed("fire_whoomph", 0)
	var b := buf(1.0)
	noise(b, 0.0, 0.9, LOW, func(u: float) -> float: return lerpf(300.0, 1400.0, sqrt(u)), 0.9,
		func(u: float) -> float: return env(u, 0.12, 1.8))
	thump(b, 0.0, 70.0, 40.0, 0.8, 0.2)
	noise(b, 0.05, 0.8, HIGH, func(_u: float) -> float: return 3000.0, 0.7,
		func(u: float) -> float: return 0.25 * env(u, 0.2, 2.0))
	return finish(reverb(b, 0.2, 0.7, 0.4, 0.4), 0.95)


## Burning: a fizzing roar thick with crackles that dies down to embers.
func burn_crackle() -> PackedFloat32Array:
	_seed("burn_crackle", 0)
	var b := buf(1.7)
	noise(b, 0.0, 1.6, BAND, func(u: float) -> float: return lerpf(900.0, 400.0, u), 0.6,
		func(u: float) -> float: return 0.55 * env(u, 0.05, 1.4))
	crackle(b, 0.0, 1.6, 90.0, 0.9, func(u: float) -> float: return 1.0 - u * 0.7)
	return finish(b, 0.85)


## The rare heart: a warm low bell and a rising pair of notes.
func heart_pickup() -> PackedFloat32Array:
	_seed("heart_pickup", 0)
	var b := buf(1.4)
	bell(b, 0.0, SA / 2.0, 0.6, 0.9)
	bell(b, 0.12, GA / 2.0, 0.45, 0.8)
	bell(b, 0.24, PA / 2.0, 0.5, 1.0)
	pad(b, 0.0, SA / 4.0, 0.3, 0.1, 0.8)
	return finish(reverb(b, 0.35, 0.8, 0.3, 0.6), 0.85)


## Every heart gone: a slow sinking gong.
func lives_lost() -> PackedFloat32Array:
	_seed("lives_lost", 0)
	var b := buf(2.2)
	gong(b, 0.0, 98.0, 0.8, 1.2, 0.85, 1.5)
	tone(b, 0.15, 196.0, 0.25, 0.05, 0.6, 147.0, 1.2)
	return finish(reverb(b, 0.35, 0.85, 0.3, 0.6), 0.9)


func cast_tarang() -> PackedFloat32Array:
	_seed("cast_tarang", 0)
	var b := buf(1.3)
	thump(b, 0.0, 75.0, 35.0, 1.0, 0.25)
	tone(b, 0.0, 55.0, 0.3, 0.01, 0.5)
	noise(b, 0.0, 1.25, BAND, func(u: float) -> float: return lerpf(3000.0, 250.0, sqrt(u)), 0.7,
		func(u: float) -> float: return 0.7 * env(u, 0.05, 1.3))
	return finish(reverb(b, 0.3, 0.8, 0.35, 0.9), 0.95)


func cast_bandhan() -> PackedFloat32Array:
	_seed("cast_bandhan", 0)
	var b := buf(1.25)
	# Creak: an accelerating pulse train ringing two resonators, like a rope pulled tight.
	var exc := buf(1.1)
	var t := 0.0
	while t < 1.0:
		var i := int(t * rate)
		exc[i] = rng.randf_range(0.6, 1.0)
		t += 1.0 / lerpf(18.0, 45.0, t) * rng.randf_range(0.85, 1.15)
	var r1 := Svf.new()
	var r2 := Svf.new()
	for i in exc.size():
		var u := float(i) / exc.size()
		b[i] += (r1.band(exc[i], 450.0 + 80.0 * u, 8.0, rate) + 0.6 * r2.band(exc[i], 900.0 + 160.0 * u, 6.0, rate)) * env(u, 0.1, 1.0) * 40.0
	for h in range(1, 5):
		tone(b, 0.0, 82.0 * h, 0.35 / h, 0.2, 0.6, 98.0 * h, 1.0)
	thump(b, 1.0, 120.0, 80.0, 0.4, 0.06)
	return finish(reverb(b, 0.2, 0.7, 0.4, 0.6), 0.9)


func barrier_burn() -> PackedFloat32Array:
	_seed("barrier_burn", 0)
	var b := buf(1.8)
	noise(b, 0.0, 1.8, BAND, func(u: float) -> float: return lerpf(300.0, 1500.0, sqrt(u)), 0.6,
		func(u: float) -> float: return env(u, 0.15, 1.0))
	noise(b, 0.0, 1.6, LOW, func(_u: float) -> float: return 200.0, 0.7,
		func(u: float) -> float: return 0.6 * env(u, 0.1, 1.5))
	noise(b, 0.3, 1.4, HIGH, func(_u: float) -> float: return 5000.0, 0.7,
		func(u: float) -> float: return 0.2 * env(u, 0.3, 1.5))
	crackle(b, 0.0, 1.7, 60.0, 0.5)
	return finish(reverb(b, 0.25, 0.75, 0.4, 0.6), 0.9)


## Pickup: a soft chime with harmonic partials (a struck bowl heard from afar), no
## bright transient, so a run of embers does not clatter.
func ember_pickup(f: float) -> PackedFloat32Array:
	_seed("ember_pickup", int(f))
	var b := buf(0.6)
	tone(b, 0.0, f, 0.55, 0.008, 0.3)
	tone(b, 0.0, f * 1.004, 0.2, 0.008, 0.3)
	tone(b, 0.0, f * 2.0, 0.12, 0.008, 0.16)
	tone(b, 0.0, f * 3.0, 0.04, 0.008, 0.08)
	return finish(reverb(b, 0.22, 0.6, 0.4, 0.3), 0.6)


func checkpoint() -> PackedFloat32Array:
	_seed("checkpoint", 0)
	var b := buf(1.8)
	# A diya catching: a soft whoomp, then Sa and Pa bells over a warm pad.
	noise(b, 0.0, 0.35, LOW, func(u: float) -> float: return lerpf(300.0, 1800.0, u), 0.8,
		func(u: float) -> float: return 0.5 * env(u, 0.3, 1.5))
	bell(b, 0.12, SA, 0.6, 0.8)
	bell(b, 0.24, PA, 0.6, 0.8)
	pad(b, 0.1, SA * 0.5, 0.25, 0.2, 0.7)
	return finish(reverb(b, 0.4, 0.8, 0.3, 0.7), 0.85)


func goal() -> PackedFloat32Array:
	_seed("goal", 0)
	var b := buf(2.8)
	var notes := [SA, RE, GA, PA, DHA, SA * 2.0]
	for i in notes.size():
		bell(b, i * 0.08, notes[i], 0.4, 0.8)
	for f in [SA * 0.5, PA * 0.5, SA, GA]:
		pad(b, 0.5, f, 0.18, 0.25, 1.0)
	noise(b, 0.4, 2.0, HIGH, func(_u: float) -> float: return 6000.0, 0.7,
		func(u: float) -> float: return 0.05 * env(u, 0.2, 1.5))
	return finish(reverb(b, 0.45, 0.82, 0.3, 0.9), 0.85)


func mantra_learned() -> PackedFloat32Array:
	_seed("mantra_learned", 0)
	var b := buf(2.6)
	for f in [SA * 0.5, PA * 0.5, SA, GA]:
		pad(b, 0.0, f, 0.2, 0.4, 0.9)
	bell(b, 0.3, SA * 2.0, 0.3, 0.9)
	bell(b, 0.55, PA * 2.0, 0.2, 0.8)
	return finish(reverb(b, 0.5, 0.82, 0.3, 0.9), 0.8)


# --- Loops ---------------------------------------------------------------------------

## Wind: resonant low-passed noise plus a faint narrow whistle, both drifting with LFOs that repeat
## exactly every loop, then the tail is folded into the head.
func amb_wind() -> PackedFloat32Array:
	_seed("amb_wind", 0)
	rate = LOOP_RATE
	var length := 8.0
	var fold := 1.0
	var b := buf(length + fold)
	var low := Svf.new()
	var whistle := Svf.new()
	for i in b.size():
		var t := float(i) / rate
		var w := TAU * t / length
		var drift := 0.5 + 0.3 * sin(w + 0.4) + 0.2 * sin(2.0 * w + 1.3)
		var gust := 0.6 + 0.25 * sin(w * 3.0 + 2.0) + 0.15 * sin(w * 5.0)
		var x := rng.randf_range(-1.0, 1.0)
		var y := low.low(x, 200.0 + 600.0 * drift, 1.4, rate) * gust
		y += whistle.band(x, 700.0 + 700.0 * drift * gust, 7.0, rate) * 0.35 * gust * gust
		b[i] = y
	return finish(fold_loop(b, int(length * rate)), 0.8, false)


## Fire bed: a low roar plus hiss and crackles; random over 5 s so it never sounds tiled.
func amb_fire() -> PackedFloat32Array:
	_seed("amb_fire", 0)
	rate = LOOP_RATE
	var length := 5.0
	var fold := 0.5
	var b := buf(length + fold)
	var roar := Svf.new()
	var hiss := Svf.new()
	var wobble := 0.5
	for i in b.size():
		if i % 64 == 0:
			wobble = clampf(wobble + rng.randf_range(-0.06, 0.06), 0.2, 1.0)
		var x := rng.randf_range(-1.0, 1.0)
		b[i] = roar.low(x, 220.0 + 200.0 * wobble, 0.8, rate) * (0.7 + 0.3 * wobble) * 1.6
		b[i] += hiss.band(x, 2500.0, 0.6, rate) * 0.08 * wobble
	crackle(b, 0.0, length + fold, 14.0, 0.7)
	# A few deeper pops.
	for p in 6:
		thump(b, rng.randf_range(0.0, length), rng.randf_range(250.0, 400.0), 120.0, 0.25, 0.015)
	return finish(fold_loop(b, int(length * rate)), 0.8, false)


## Tanpura drone: Pa, Sa, Sa, low Sa plucked in a cycle. Every partial is a whole
## multiple of 1/length Hz and plucks are written into a ring, so the loop is exact.
## The jawari bridge is modelled as a resonance sweeping down through the harmonics.
func music_drone() -> PackedFloat32Array:
	_seed("music_drone", 0)
	rate = LOOP_RATE
	var length := 12.0
	var n := int(length * rate)
	var b := buf(length)
	var step := 1.0 / length
	var sa := 1572.0 * step  # 131.0 Hz, close to C3
	var strings := [sa * 0.75, sa, sa + step, sa * 0.5]  # Pa, Sa, Sa (slightly sharp: slow beating), low Sa
	var offsets := [0.0, 0.75, 1.5, 2.25]  # one 4 s cycle; the long rest after low Sa is the breath
	for cycle in 3:
		for s in 4:
			var at: float = cycle * 4.0 + offsets[s] + rng.randf_range(-0.02, 0.02)
			_pluck(b, n, wrapf(at, 0.0, length), strings[s], rng.randf_range(0.8, 1.0) * (1.25 if s == 3 else 1.0))
	return finish(b, 0.75, false)


func _pluck(b: PackedFloat32Array, n: int, start: float, f: float, amp: float) -> void:
	var dur := 6.5
	var count := mini(int(3600.0 / f), 24)
	var phases := PackedFloat32Array()
	for h in count:
		phases.append(rng.randf() * TAU)
	var block := 32
	var amps := PackedFloat32Array()
	amps.resize(count)
	var i0 := int(start * rate)
	var total := int(dur * rate)
	for j in total:
		var t := float(j) / rate
		if j % block == 0:
			var centre := 3.0 + 16.0 * exp(-t / 1.1)  # jawari resonance sweeping down
			var body := minf(t / 0.012, 1.0) * exp(-t / 3.2)
			for h in count:
				var hn := float(h + 1)
				var d := (hn - centre) / 2.5
				amps[h] = body * pow(hn, -1.1) * exp(-t * 0.06 * hn) * (1.0 + 2.5 * exp(-d * d))
		# Absolute time keeps every partial phase-continuous across the wrap.
		var ta := float(i0 + j) / rate
		var y := 0.0
		for h in count:
			y += amps[h] * sin(TAU * f * (h + 1) * ta + phases[h])
		var idx := (i0 + j) % n
		b[idx] += y * amp * 0.3


# --- Building blocks ----------------------------------------------------------------

func buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * rate))
	return b


## Normalized envelope: linear rise to 1 at u = attack, then a power-curve fall to 0.
static func env(u: float, attack: float, curve: float) -> float:
	if u < attack:
		return u / attack
	return pow(maxf(0.0, 1.0 - (u - attack) / (1.0 - attack)), curve)


## Sine partial with linear attack and exponential decay (time constant `decay` s).
## Optional exponential glide f0 -> f1 over `glide` s, and vibrato.
func tone(b: PackedFloat32Array, start: float, f0: float, amp: float, attack: float, decay: float,
		f1: float = 0.0, glide: float = 0.0, vib_rate: float = 0.0, vib_depth: float = 0.0) -> void:
	var i0 := int(start * rate)
	var phase := 0.0
	for i in range(i0, b.size()):
		var t := float(i - i0) / rate
		var e := t / attack if t < attack else exp(-(t - attack) / decay)
		if t > attack and e < 0.0005:
			break
		var f := f0
		if f1 > 0.0 and glide > 0.0:
			f = f0 * pow(f1 / f0, minf(t / glide, 1.0))
		if vib_rate > 0.0:
			f *= 1.0 + vib_depth * sin(TAU * vib_rate * t)
		phase += TAU * f / rate
		b[i] += sin(phase) * amp * e


## Fast pitch-dropping sine: the body of a hit or landing.
func thump(b: PackedFloat32Array, start: float, f0: float, f1: float, amp: float, decay: float) -> void:
	tone(b, start, f0, amp, 0.002, decay, f1, decay * 0.8)


## Struck bell: slightly inharmonic partials, higher ones dying faster.
func bell(b: PackedFloat32Array, start: float, f: float, amp: float, decay: float) -> void:
	var ratios := [1.0, 2.0, 2.76, 4.07, 5.4]
	var gains := [1.0, 0.45, 0.3, 0.16, 0.1]
	var decays := [1.0, 0.65, 0.45, 0.3, 0.2]
	for i in ratios.size():
		if f * ratios[i] < rate * 0.45:
			tone(b, start, f * ratios[i], amp * gains[i], 0.002, decay * decays[i])
	tone(b, start, f * 1.003, amp * 0.3, 0.002, decay)  # detuned twin for a slow shimmer


## Gong: clustered inharmonic partials with a soft mallet attack and optional pitch sag.
func gong(b: PackedFloat32Array, start: float, f: float, amp: float, decay: float,
		sag: float = 1.0, sag_time: float = 0.0, attack: float = 0.008) -> void:
	var ratios := [1.0, 1.51, 2.0, 2.42, 2.98, 3.6, 4.22]
	var gains := [1.0, 0.6, 0.5, 0.35, 0.3, 0.2, 0.15]
	var decays := [1.0, 0.7, 0.62, 0.5, 0.4, 0.32, 0.25]
	for i in ratios.size():
		var fr: float = f * ratios[i]
		tone(b, start, fr, amp * gains[i], attack, decay * decays[i], fr * sag if sag_time > 0.0 else 0.0, sag_time)


## Warm sustained note: a few harmonics with a slow swell.
func pad(b: PackedFloat32Array, start: float, f: float, amp: float, attack: float, decay: float) -> void:
	for h in range(1, 4):
		tone(b, start, f * h, amp / pow(h, 1.5), attack, decay / h, 0.0, 0.0, 4.5, 0.002)


## Filtered white noise. cutoff(u) and gain(u) take normalized time u in 0..1.
func noise(b: PackedFloat32Array, start: float, length: float, mode: int, cutoff: Callable,
		q: float, gain: Callable) -> void:
	var i0 := int(start * rate)
	var count := mini(int(length * rate), b.size() - i0)
	var f := Svf.new()
	for j in count:
		var u := float(j) / count
		var x := rng.randf_range(-1.0, 1.0)
		var c: float = cutoff.call(u)
		var y := 0.0
		match mode:
			LOW:
				y = f.low(x, c, q, rate)
			BAND:
				y = f.band(x, c, q, rate)
			_:
				y = f.high(x, c, q, rate)
		b[i0 + j] += y * float(gain.call(u))


## Sparse crackles: tiny decaying noise clicks at random times (`per_second` on average).
func crackle(b: PackedFloat32Array, start: float, length: float, per_second: float, amp: float,
		gain = null) -> void:
	var i0 := int(start * rate)
	var count := mini(int(length * rate), b.size() - i0)
	var p := per_second / rate
	for j in count:
		if rng.randf() >= p:
			continue
		var g := amp * rng.randf_range(0.2, 1.0) * rng.randf_range(0.2, 1.0)
		if gain is Callable:
			g *= float(gain.call(float(j) / count))
		var tau := rng.randf_range(0.0006, 0.003) * rate
		var prev := 0.0
		for k in int(tau * 5.0):
			var idx := i0 + j + k
			if idx >= b.size():
				break
			var x := rng.randf_range(-1.0, 1.0)
			b[idx] += (x - prev) * 0.5 * g * exp(-k / tau)  # differentiated: bright, snappy
			prev = x


## Small mono Schroeder reverb (parallel damped combs into series all-passes). Adds a tail.
func reverb(b: PackedFloat32Array, mix: float, room: float, damp: float, tail: float = 0.5) -> PackedFloat32Array:
	var out := b.duplicate()
	out.resize(b.size() + int(tail * rate))
	var wet := PackedFloat32Array()
	wet.resize(out.size())
	var combs := [1116, 1188, 1277, 1356, 1422, 1491]
	for d0 in combs:
		var d := int(d0 * rate / 44100.0)
		var line := PackedFloat32Array()
		line.resize(d)
		var idx := 0
		var store := 0.0
		for i in out.size():
			var y := line[idx]
			store = y * (1.0 - damp) + store * damp
			line[idx] = out[i] + store * room
			idx = (idx + 1) % d
			wet[i] += y
	for d0 in [556, 441, 341, 225]:
		var d := int(d0 * rate / 44100.0)
		var line := PackedFloat32Array()
		line.resize(d)
		var idx := 0
		for i in wet.size():
			var delayed := line[idx]
			line[idx] = wet[i] + delayed * 0.5
			wet[i] = delayed - wet[i]
			idx = (idx + 1) % d
	var g := mix / (combs.size() * 1.5)
	for i in out.size():
		out[i] += wet[i] * g
	return out


## Crossfades the samples past `loop_len` into the start, so sample loop_len-1 flows into 0.
func fold_loop(b: PackedFloat32Array, loop_len: int) -> PackedFloat32Array:
	var fade := b.size() - loop_len
	var out := b.slice(0, loop_len)
	for i in fade:
		var u := float(i) / fade
		out[i] = b[i] * sin(u * PI * 0.5) + b[loop_len + i] * cos(u * PI * 0.5)
	return out


## Normalizes to `peak`, trims silence and fades the last few ms of one-shots.
func finish(b: PackedFloat32Array, peak: float, one_shot: bool = true) -> PackedFloat32Array:
	var top := 0.0
	for x in b:
		top = maxf(top, absf(x))
	if top <= 0.0:
		return b
	var g := peak / top
	var last := b.size()
	if one_shot:
		var floor_level := top * 0.005  # -46 dB below the peak; the fade hides the cut
		while last > 1 and absf(b[last - 1]) < floor_level:
			last -= 1
	var out := b.slice(0, last)
	var fade := mini(int(0.08 * rate), last / 3)
	for i in last:
		out[i] *= g
		if one_shot and i >= last - fade:
			var u := float(last - i) / fade
			out[i] *= u * u
	return out


## Cuts a one-shot to `seconds` with a long, gentle fade so reverb tails end naturally.
func cap_length(b: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var last := int(seconds * rate)
	if b.size() <= last:
		return b
	var out := b.slice(0, last)
	var fade := mini(int(0.35 * rate), last / 2)
	for i in range(last - fade, last):
		var u := float(last - i) / fade
		out[i] *= u * u
	return out


func _seed(name: String, variant: int) -> void:
	rng.seed = hash("%s:%d" % [name, variant])
	rate = DEFAULT_RATE


func _save(name: String, b: PackedFloat32Array, loop: bool = false) -> void:
	var base := name.rstrip("0123456789").trim_suffix("_")
	if not _only.is_empty() and not _only.has(base):
		return
	if MAX_SECONDS.has(base):
		b = cap_length(b, MAX_SECONDS[base])
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	var path := OUT + name + ".wav"
	var err := wav.save_to_wav(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("synth_audio: could not write %s (%d)" % [path, err])
		return
	if loop:
		_mark_loop(path)
	_written.append(path)
	print("  %-28s %5.2f s" % [name, float(b.size()) / rate])


## WAV files carry no loop points here, so the importer is told to loop the whole file.
func _mark_loop(path: String) -> void:
	var cfg := ConfigFile.new()
	var import_path := ProjectSettings.globalize_path(path + ".import")
	if cfg.load(import_path) != OK:
		cfg.set_value("remap", "importer", "wav")
		cfg.set_value("remap", "type", "AudioStreamWAV")
	cfg.set_value("params", "edit/loop_mode", 2)
	cfg.set_value("params", "edit/loop_begin", 0)
	cfg.set_value("params", "edit/loop_end", -1)
	cfg.save(import_path)


## Topology-preserving state-variable filter (Zavalishin). Cutoff can change every sample.
class Svf:
	var _ic1 := 0.0
	var _ic2 := 0.0
	var _v1 := 0.0
	var _v2 := 0.0
	var _x := 0.0
	var _k := 1.0

	func _tick(x: float, cutoff: float, q: float, sample_rate: int) -> void:
		var g := tan(PI * clampf(cutoff, 20.0, sample_rate * 0.45) / sample_rate)
		_k = 1.0 / q
		var a1 := 1.0 / (1.0 + g * (g + _k))
		var a2 := g * a1
		var a3 := g * a2
		var v3 := x - _ic2
		_v1 = a1 * _ic1 + a2 * v3
		_v2 = _ic2 + a2 * _ic1 + a3 * v3
		_ic1 = 2.0 * _v1 - _ic1
		_ic2 = 2.0 * _v2 - _ic2
		_x = x

	func low(x: float, cutoff: float, q: float, sample_rate: int) -> float:
		_tick(x, cutoff, q, sample_rate)
		return _v2

	## Band-pass with unity gain at the centre, so a narrow band is not louder than a wide one.
	func band(x: float, cutoff: float, q: float, sample_rate: int) -> float:
		_tick(x, cutoff, q, sample_rate)
		return _v1 * _k

	func high(x: float, cutoff: float, q: float, sample_rate: int) -> float:
		_tick(x, cutoff, q, sample_rate)
		return _x - _k * _v1 - _v2
