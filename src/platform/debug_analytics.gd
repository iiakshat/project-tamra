class_name DebugAnalytics
extends AnalyticsService
## Prints events in debug builds and keeps the latest ones in memory for inspection.

const MAX_KEPT := 200

var events: Array[Dictionary] = []


func log_event(event: String, params: Dictionary = {}) -> void:
	events.append({"event": event, "params": params, "t": Time.get_ticks_msec()})
	if events.size() > MAX_KEPT:
		events.pop_front()
	if OS.is_debug_build():
		print("[analytics] ", event, " ", params)
