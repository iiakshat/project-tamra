class_name PuppetPreview
extends Node2D
## Debug-only character sheet: every puppet in several poses, large, for checking art.
## Open with `-- --preview=puppets`.

var _figures: Array[Dictionary] = []


func _ready() -> void:
	var backdrop := Backdrop.new()
	add_child(backdrop)
	backdrop.build(3000.0, "ember", 5)
	add_child(Fx.polygon(PackedVector2Array([Vector2(0, 600), Vector2(1280, 600), Vector2(1280, 720), Vector2(0, 720)]), Fx.INK))
	_add("hero", Vector2(170, 600), 0.0, true, "")
	_add("hero", Vector2(420, 600), 1.0, true, "")
	_add("hero", Vector2(660, 560), 0.0, false, "strike")
	_add("soldier", Vector2(900, 600), 0.0, true, "windup")
	_add("mother", Vector2(1060, 600), 0.0, true, "")
	_add("king", Vector2(1200, 600), 0.0, true, "")


func _add(style: String, pos: Vector2, move: float, floor: bool, action: String) -> void:
	var holder := Node2D.new()
	holder.position = pos
	holder.scale = Vector2(2.1, 2.1)
	add_child(holder)
	var aura := Fx.glow(Color(1.0, 0.5, 0.22, 0.3), 60.0)
	aura.position = Vector2(0, -50)
	holder.add_child(aura)
	var p := Puppet.new()
	p.build(style)
	holder.add_child(p)
	_figures.append({"puppet": p, "move": move, "floor": floor, "action": action})


func _process(delta: float) -> void:
	for f in _figures:
		var p: Puppet = f["puppet"]
		if f["action"] != "" and p._action == "":
			if f["action"] == "strike":
				p.strike()
			else:
				p.windup()
		p.animate(delta, f["move"], f["floor"], -100.0)
