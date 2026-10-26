class_name Fatigue
extends RefCounted
## How tired the hero is, 0..100. He only bends over to catch his breath when he has
## really worked: a long non-stop run, a flurry of strikes, or many jumps in a short
## time. Walking and standing let it drain away. Panting is rare (a cooldown), so it
## stays a small moment of life instead of a habit. Pure logic: Player feeds it,
## tests drive it directly. Numbers come from config/player.json.

var level := 0.0
var _cfg: Dictionary
var _run := 0.0          # seconds of non-stop running
var _since_pant := 999.0
var _last_strike := -99.0
var _jumps: Array[float] = []  # times of recent jumps
var _clock := 0.0


func _init(cfg: Dictionary = {}) -> void:
	_cfg = cfg


func _num(key: String, fallback: float) -> float:
	return float(_cfg.get(key, fallback))


## state: "run" (on the ground at speed), "rest" (walking slowly or standing) or
## "air". Called every physics frame.
func update(delta: float, state: String) -> void:
	_clock += delta
	_since_pant += delta
	match state:
		"run":
			_run += delta
			if _run > _num("fatigue_run_after", 6.0):
				_add(_num("fatigue_run_rate", 12.0) * delta)
		"rest":
			_run = 0.0
			level = maxf(0.0, level - _num("fatigue_decay", 6.0) * delta)
		_:
			pass  # a jump in a run does not break the run


## A swing of the staff. Strikes in quick succession are a fight and tire him.
func on_strike() -> void:
	var quick := _clock - _last_strike < _num("fatigue_combo_window", 1.2)
	_last_strike = _clock
	_add(_num("fatigue_strike", 12.0) if quick else _num("fatigue_strike", 12.0) * 0.25)


## A jump (or an UDAAN leap). Many jumps close together tire him; one now and then
## barely registers.
func on_jump() -> void:
	var window := _num("fatigue_jump_window", 5.0)
	_jumps.append(_clock)
	while not _jumps.is_empty() and _clock - _jumps[0] > window:
		_jumps.pop_front()
	var each := _num("fatigue_jump", 7.0)
	_add(each if _jumps.size() >= 3 else each * 0.2)


## True when he is tired enough, has stopped, and has not panted for a while.
func wants_pant() -> bool:
	return level >= _num("fatigue_threshold", 60.0) and _since_pant >= _num("pant_cooldown", 20.0)


## He bent over and caught his breath: rested.
func panted() -> void:
	level = 0.0
	_run = 0.0
	_since_pant = 0.0
	_jumps.clear()


func _add(amount: float) -> void:
	level = minf(100.0, level + amount)
