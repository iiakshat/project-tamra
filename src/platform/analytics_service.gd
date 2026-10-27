class_name AnalyticsService
extends RefCounted
## Analytics interface. The base class drops events. DebugAnalytics writes them to the log;
## FirebaseAnalytics wraps another service and also sends them to Firebase once the player
## agrees. Gameplay code only ever calls this interface.


func log_event(_event: String, _params: Dictionary = {}) -> void:
	pass


## The player's choice to share anonymous play data. Nothing leaves the device without it.
func set_consent(_granted: bool) -> void:
	pass


## Context attached to crash reports (for example the level being played).
func set_context(_key: String, _value: Variant) -> void:
	pass
