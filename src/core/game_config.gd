class_name GameConfig
extends RefCounted
## Reads tuning data from res://config. Numbers live there so balance changes
## need no code edits.

const DIR := "res://config/"


static func read(name: String) -> Dictionary:
	var path := DIR + name + ".json"
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Config missing or empty: " + path)
		return {}
	var data = JSON.parse_string(text)
	if data is Dictionary:
		return data
	push_error("Config is not a JSON object: " + path)
	return {}


static func level(id: String) -> Dictionary:
	return read("levels/" + id)


static func vec(value, fallback := Vector2.ZERO) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


static func color(value, fallback := Color.WHITE) -> Color:
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback
