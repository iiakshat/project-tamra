class_name FirebaseAnalytics
extends AnalyticsService
## Sends events to Firebase through the "Godotx Firebase" Android plugin (MIT, see
## docs/RELEASE.md). It wraps a local service, so events always reach the log, and it does
## nothing at all unless the plugin is in the build, which only the release job does.
##
## Privacy rules, all enforced here:
##  - nothing is sent before the player says yes (set_consent(true));
##  - saying no later switches collection off again and drops anything still queued;
##  - ad storage, ad user data and ad personalisation are always "denied";
##  - events are cleaned to Firebase's limits (AnalyticsSanitizer).

const MAX_QUEUE := 100

var _local: AnalyticsService
var _core: Object
var _analytics: Object
var _crashlytics: Object
var _consent := false
var _failed := false
var _analytics_ready := false
var _crash_ready := false
var _queue: Array = []  # [name, params] pairs waiting for Firebase to finish starting


## The local service on its own when the plugin is absent (desktop, debug APK, tests);
## otherwise a FirebaseAnalytics wrapped around it, already starting up.
static func create(local: AnalyticsService) -> AnalyticsService:
	if not (Engine.has_singleton("GodotxFirebaseCore") and Engine.has_singleton("GodotxFirebaseAnalytics")):
		return local
	var crash: Object = null
	if Engine.has_singleton("GodotxFirebaseCrashlytics"):
		crash = Engine.get_singleton("GodotxFirebaseCrashlytics")
	var service := FirebaseAnalytics.new(local, Engine.get_singleton("GodotxFirebaseCore"),
		Engine.get_singleton("GodotxFirebaseAnalytics"), crash)
	service.start()
	return service


func _init(local: AnalyticsService, core: Object, analytics: Object, crashlytics: Object = null) -> void:
	_local = local
	_core = core
	_analytics = analytics
	_crashlytics = crashlytics


func start() -> void:
	_core.connect("core_initialized", _on_core)
	_core.call("initialize")


func log_event(event: String, params: Dictionary = {}) -> void:
	_local.log_event(event, params)
	if not _consent or _failed:
		return
	var item := [AnalyticsSanitizer.event_name(event), AnalyticsSanitizer.params(params)]
	if _analytics_ready:
		_analytics.call("log_event", item[0], item[1])
		return
	_queue.append(item)
	if _queue.size() > MAX_QUEUE:
		_queue.pop_front()


func set_consent(granted: bool) -> void:
	_local.set_consent(granted)
	_consent = granted
	if not granted:
		_queue.clear()
	_apply_consent()


func set_context(key: String, value: Variant) -> void:
	_local.set_context(key, value)
	if _consent and _crash_ready:
		_crashlytics.call("set_custom_value_string", key, str(value).substr(0, AnalyticsSanitizer.MAX_VALUE))


func _on_core(success: bool) -> void:
	if not success:
		_failed = true
		GameLog.warn("analytics", "Firebase core failed to start; events stay local")
		return
	_analytics.connect("analytics_initialized", _on_analytics)
	_analytics.call("initialize")
	if _crashlytics != null:
		_crashlytics.connect("crashlytics_initialized", _on_crashlytics)
		_crashlytics.call("initialize")


func _on_analytics(success: bool) -> void:
	if not success:
		_failed = true
		_queue.clear()
		GameLog.warn("analytics", "Firebase analytics failed to start; events stay local")
		return
	_analytics_ready = true
	_apply_consent()
	for item in _queue:
		_analytics.call("log_event", item[0], item[1])
	_queue.clear()


func _on_crashlytics(success: bool) -> void:
	_crash_ready = success
	_apply_consent()


## Pushes the current choice to the plugin. Collection follows the choice exactly.
func _apply_consent() -> void:
	if _analytics_ready:
		var state := "granted" if _consent else "denied"
		_analytics.call("set_consent", {"analytics_storage": state, "ad_storage": "denied",
			"ad_user_data": "denied", "ad_personalization": "denied"})
		_analytics.call("set_analytics_collection_enabled", _consent)
	if _crash_ready:
		_crashlytics.call("set_crashlytics_collection_enabled", _consent)
