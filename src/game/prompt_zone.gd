class_name PromptZone
extends Area2D
## Shows a tutorial hint while the hero stands in this stretch of the level.

signal shown(text: String, glyph: String)
signal hidden_again

var text := ""
var glyph := ""
var width := 360.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 900)
	shape.shape = rect
	shape.position = Vector2(width / 2.0, -350)
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		shown.emit(text, glyph)


func _on_body_exited(body: Node) -> void:
	if body is Player:
		hidden_again.emit()
