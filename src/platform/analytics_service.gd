class_name AnalyticsService
extends RefCounted
## Analytics interface. The base class drops events. A Firebase-backed subclass
## replaces it later without any gameplay code changing.


func log_event(_event: String, _params: Dictionary = {}) -> void:
	pass
