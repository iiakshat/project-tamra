class_name MantraCaster
extends Node
## Turns recognized gestures into mantra effects. Enforces which mantras the level
## has unlocked and their cooldowns. All numbers come from config/mantras.json.

signal cast(id: String)
signal failed(reason: String)

var level: Level
var cfg: Dictionary
var unlocked: Array[String] = []

var _cooldowns := {}


func _process(delta: float) -> void:
	for id in _cooldowns:
		_cooldowns[id] = maxf(0.0, float(_cooldowns[id]) - delta)


func mantra_for_gesture(gesture: String) -> String:
	for id in cfg:
		if str(cfg[id].get("gesture", "")) == gesture:
			return id
	return ""


## 0 = ready, 1 = just cast.
func cooldown_ratio(id: String) -> float:
	var total := float(cfg.get(id, {}).get("cooldown", 1.0))
	return clampf(float(_cooldowns.get(id, 0.0)) / maxf(total, 0.01), 0.0, 1.0)


func try_gesture(result: Dictionary) -> void:
	var gesture: String = result.get("name", "")
	if gesture == "":
		failed.emit("unrecognized")
		Services.analytics.log_event("gesture_unrecognized", {"score": snappedf(float(result.get("score", 0.0)), 0.01)})
		return
	var id := mantra_for_gesture(gesture)
	if id == "" or not unlocked.has(id):
		failed.emit("locked")
		return
	if float(_cooldowns.get(id, 0.0)) > 0.0:
		failed.emit("cooldown")
		return
	if _execute(id, cfg[id], int(result.get("direction", 0))):
		_cooldowns[id] = float(cfg[id].get("cooldown", 1.0))
		cast.emit(id)
		Services.analytics.log_event("mantra_cast", {"id": id, "level": level.level_id})


func _execute(id: String, m: Dictionary, direction: int) -> bool:
	var p := level.player
	if p == null or not p.alive:
		return false
	var color := GameConfig.color(m.get("color", ""), Color(1, 0.8, 0.4))
	match id:
		"setu":
			var dir := direction if direction != 0 else p.facing
			p.facing = dir
			var bridge := LightBridge.new()
			bridge.dir = dir
			bridge.length = float(m.get("length", 420.0))
			bridge.life = float(m.get("duration", 5.0))
			bridge.color = color
			bridge.position = p.global_position + Vector2(-dir * 24.0, 0.0)
			level.world.add_child(bridge)
		"chhaya":
			var decoy := MayaDecoy.new()
			decoy.dir = p.facing
			decoy.speed = float(m.get("speed", 240.0))
			decoy.life = float(m.get("duration", 4.0))
			decoy.position = p.global_position
			level.world.add_child(decoy)
		"jwala":
			var bolt := JwalaBolt.new()
			bolt.dir = p.facing
			bolt.speed = float(m.get("speed", 950.0))
			bolt.max_range = float(m.get("range", 900.0))
			bolt.color = color
			bolt.position = p.global_position + Vector2(p.facing * 26.0, -50.0)
			level.world.add_child(bolt)
		"kavach":
			p.shield_time = float(m.get("duration", 3.0))
		"drishti":
			level.reveal_maya(float(m.get("duration", 5.0)))
		_:
			return false
	p.puppet.cast()
	Fx.burst(level.world, p.global_position + Vector2(p.facing * 20.0, -55.0), color, 16, 160.0)
	Game.vibrate(25)
	return true
