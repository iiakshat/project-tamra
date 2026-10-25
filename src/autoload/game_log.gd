extends Node
## Diagnostic log. Every line goes to user://logs/game.log (flushed immediately, so it
## survives a crash) and to an in-memory buffer the player can copy from the pause menu.
## Engine errors and warnings are captured through a custom Logger. If the previous
## session never closed cleanly, that is recorded and its log is kept as game.prev.log.

const DIR := "user://logs/"
const LOG_FILE := DIR + "game.log"
const PREV_FILE := DIR + "game.prev.log"
const LOCK_FILE := DIR + "session.lock"

var error_count := 0
var previous_session_crashed := false

var _buffer := LogBuffer.new(600)
var _file: FileAccess
var _mutex := Mutex.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	previous_session_crashed = FileAccess.file_exists(LOCK_FILE)
	if FileAccess.file_exists(LOG_FILE):
		if FileAccess.file_exists(PREV_FILE):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PREV_FILE))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(LOG_FILE), ProjectSettings.globalize_path(PREV_FILE))
	_file = FileAccess.open(LOG_FILE, FileAccess.WRITE)
	var lock := FileAccess.open(LOCK_FILE, FileAccess.WRITE)
	if lock != null:
		lock.store_string(Time.get_datetime_string_from_system())
	OS.add_logger(EngineLogger.new(self))
	_log_device_info()
	if previous_session_crashed:
		warn("log", "Previous session did not close cleanly (crash or force-close). See game.prev.log.")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE:
			_close()
		NOTIFICATION_APPLICATION_PAUSED:
			info("app", "paused")
		NOTIFICATION_APPLICATION_RESUMED:
			info("app", "resumed")


func info(tag: String, message: String, data: Dictionary = {}) -> void:
	_write("INFO", tag, message, data)


func warn(tag: String, message: String, data: Dictionary = {}) -> void:
	_write("WARN", tag, message, data)


func error(tag: String, message: String, data: Dictionary = {}) -> void:
	error_count += 1
	_write("ERROR", tag, message, data)


## Current session plus the tail of the previous one, ready to paste into a bug report.
func report() -> String:
	var parts: Array[String] = ["=== %s %s | errors this session: %d ===" % [
		ProjectSettings.get_setting("application/config/name", ""),
		ProjectSettings.get_setting("application/config/version", ""), error_count]]
	parts.append(_buffer.dump())
	if FileAccess.file_exists(PREV_FILE):
		var prev := FileAccess.get_file_as_string(PREV_FILE).split("\n")
		parts.append("\n=== previous session (last 80 lines)%s ===" % (" - DID NOT CLOSE CLEANLY" if previous_session_crashed else ""))
		parts.append("\n".join(prev.slice(maxi(0, prev.size() - 80))))
	return "\n".join(parts)


func copy_report_to_clipboard() -> void:
	DisplayServer.clipboard_set(report())
	info("log", "report copied to clipboard")


func _write(level: String, tag: String, message: String, data: Dictionary) -> void:
	var line := LogBuffer.format_line(Time.get_ticks_msec(), level, tag, message, data)
	_buffer.add(line)
	_mutex.lock()
	if _file != null:
		_file.store_line(line)
		_file.flush()
	_mutex.unlock()
	if OS.is_debug_build() and level != "ERROR" and level != "WARN":
		print(line)  # stdout only; errors already reach the console through the engine


func _close() -> void:
	if _file == null:
		return
	info("app", "session end")
	_mutex.lock()
	_file.close()
	_file = null
	_mutex.unlock()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCK_FILE))


func _log_device_info() -> void:
	info("boot", "session start", {
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"debug": OS.is_debug_build(),
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"model": OS.get_model_name(),
		"cpu_cores": OS.get_processor_count(),
		"locale": OS.get_locale(),
		"screen": str(DisplayServer.screen_get_size()),
		"time": Time.get_datetime_string_from_system(),
	})


func log_renderer() -> void:
	info("boot", "renderer", {
		"gpu": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
	})


## Receives every engine error and warning, including script errors with backtraces.
## May be called from any thread.
class EngineLogger extends Logger:
	var _log: Node

	func _init(owner_log: Node) -> void:
		_log = owner_log

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var message := rationale if rationale != "" else code
		var data := {"at": "%s:%d %s()" % [file, line, function]}
		if not script_backtraces.is_empty():
			data["script"] = script_backtraces[0].format()
		if error_type == ERROR_TYPE_WARNING:
			_log.warn("engine", message, data)
		else:
			_log.error("engine", message, data)

	func _log_message(_message: String, _error: bool) -> void:
		pass  # Plain prints are not diagnostics; GameLog writes its own lines.
