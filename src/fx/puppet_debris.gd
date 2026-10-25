class_name PuppetDebris
extends Node2D
## When a puppet dies, its leather pieces come apart: each piece flies, spins,
## bounces once off the ground line and fades. Frees itself when done.

const LIFE := 1.6

var ground_y := 0.0

var _pieces: Array[Node2D] = []
var _vel: Array[Vector2] = []
var _spin: Array[float] = []
var _t := 0.0


func add_piece(piece: Node2D, velocity: Vector2, spin: float) -> void:
	add_child(piece)
	_pieces.append(piece)
	_vel.append(velocity)
	_spin.append(spin)


func _process(delta: float) -> void:
	_t += delta
	for i in _pieces.size():
		var p := _pieces[i]
		_vel[i].y += 1400.0 * delta
		p.position += _vel[i] * delta
		p.rotation += _spin[i] * delta
		if p.position.y > ground_y and _vel[i].y > 0.0:
			p.position.y = ground_y
			_vel[i] = Vector2(_vel[i].x * 0.5, -_vel[i].y * 0.3)
			_spin[i] *= 0.5
	modulate.a = clampf((LIFE - _t) / 0.5, 0.0, 1.0)
	if _t >= LIFE:
		queue_free()
