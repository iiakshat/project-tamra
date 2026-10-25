extends "res://tests/test_case.gd"


func test_format_line() -> void:
	var line := LogBuffer.format_line(12345, "WARN", "level", "fell", {"x": 10})
	check(line.contains("12.345"), "seconds in line: " + line)
	check(line.contains("WARN"), "level in line")
	check(line.contains("[level] fell"), "tag and message in line")
	check(line.ends_with("{\"x\":10}"), "data as JSON: " + line)


func test_ring_buffer_keeps_newest() -> void:
	var b := LogBuffer.new(3)
	for i in 5:
		b.add("line %d" % i)
	check_eq(b.lines().size(), 3, "capped at capacity")
	check_eq(b.lines()[0], "line 2", "oldest dropped")
	check_eq(b.dump(), "line 2\nline 3\nline 4", "dump joins lines")


func test_game_log_captures_engine_errors() -> void:
	var before: int = GameLog.error_count
	push_error("test: deliberate error for the logger")
	check(GameLog.error_count > before, "push_error reached GameLog")
	check(GameLog.report().contains("deliberate error"), "error text in report")
