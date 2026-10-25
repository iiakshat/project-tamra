extends RefCounted
## Minimal assertion helpers for the headless test runner (tests/run_tests.gd).

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual, expected, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: expected <%s>, got <%s>" % [message, str(expected), str(actual)])
