class_name LogBuffer
extends RefCounted
## Fixed-size ring of formatted log lines. Pure logic, so it is unit tested;
## the GameLog autoload adds the file and engine hooks around it.

var capacity: int
var _lines: Array[String] = []
var _mutex := Mutex.new()


func _init(max_lines: int = 500) -> void:
	capacity = max_lines


static func format_line(t_ms: int, level: String, tag: String, message: String, data: Dictionary = {}) -> String:
	var secs := t_ms / 1000.0
	var line := "%9.3f %-5s [%s] %s" % [secs, level, tag, message]
	if not data.is_empty():
		line += " " + JSON.stringify(data)
	return line


## Thread-safe: engine errors can arrive from any thread.
func add(line: String) -> void:
	_mutex.lock()
	_lines.append(line)
	if _lines.size() > capacity:
		_lines.pop_front()
	_mutex.unlock()


func lines() -> Array[String]:
	_mutex.lock()
	var copy := _lines.duplicate()
	_mutex.unlock()
	return copy


func dump() -> String:
	return "\n".join(lines())
