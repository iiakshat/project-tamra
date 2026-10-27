extends "res://tests/test_case.gd"
## The analytics rules: events are cleaned to Firebase's limits, nothing leaves the device
## without consent, and a game without the plugin keeps working (events only go to the log).


class FakeFirebase extends RefCounted:
	signal analytics_initialized(success: bool)
	signal core_initialized(success: bool)
	signal crashlytics_initialized(success: bool)
	var sent: Array = []
	var consent_calls: Array = []
	var collection: Array = []
	var inits := 0
	var context: Dictionary = {}

	func initialize() -> void:
		inits += 1

	func log_event(event: String, params: Dictionary) -> void:
		sent.append([event, params])

	func set_consent(c: Dictionary) -> void:
		consent_calls.append(c)

	func set_analytics_collection_enabled(on: bool) -> void:
		collection.append(on)

	func set_crashlytics_collection_enabled(on: bool) -> void:
		collection.append(on)

	func set_custom_value_string(key: String, value: String) -> void:
		context[key] = value


class Local extends AnalyticsService:
	var seen: Array[String] = []

	func log_event(event: String, _params: Dictionary = {}) -> void:
		seen.append(event)


func _make(fb: FakeFirebase, local: Local) -> FirebaseAnalytics:
	return FirebaseAnalytics.new(local, fb, fb, fb)


# --- Sanitizer -------------------------------------------------------------

func test_event_names_are_made_legal() -> void:
	check_eq(AnalyticsSanitizer.event_name("level_start"), "level_start", "legal name kept")
	check_eq(AnalyticsSanitizer.event_name("level start!"), "level_start_", "illegal characters replaced")
	check_eq(AnalyticsSanitizer.event_name("1st_try"), "e_1st_try", "must start with a letter")
	check_eq(AnalyticsSanitizer.event_name("firebase_secret"), "app_firebase_secret", "reserved prefix")
	check_eq(AnalyticsSanitizer.event_name("a".repeat(60)).length(), 40, "name capped at 40")
	check_eq(AnalyticsSanitizer.event_name(""), "event", "empty name")


func test_param_values_are_firebase_types() -> void:
	var p := AnalyticsSanitizer.params({"ok": true, "n": 3, "f": 1.5, "s": "x", "arr": [1, 2], "nothing": null})
	check_eq(p["ok"], 1, "bool becomes 1")
	check_eq(p["n"], 3, "int kept")
	check_eq(p["f"], 1.5, "float kept")
	check_eq(p["s"], "x", "string kept")
	check_eq(p["arr"], "[1,2]", "array becomes a short string")
	check(not p.has("nothing"), "null dropped")


func test_long_strings_and_many_params_are_capped() -> void:
	var p := AnalyticsSanitizer.params({"s": "z".repeat(300)})
	check_eq((p["s"] as String).length(), 100, "string capped at 100")
	var big := {}
	for i in 40:
		big["k%d" % i] = i
	var q := AnalyticsSanitizer.params(big)
	check_eq(q.size(), 25, "at most 25 params")
	check(q.has("k0") and not q.has("k39"), "first ones win")


func test_param_keys_are_made_legal() -> void:
	var p := AnalyticsSanitizer.params({"bad key": 1, "2nd": 2})
	check(p.has("bad_key"), "space replaced")
	check(p.has("p_2nd"), "must start with a letter")


# --- Adapter -----------------------------------------------------------------

func test_without_the_plugin_events_only_reach_the_log() -> void:
	var local := Local.new()
	var a := FirebaseAnalytics.create(local)
	check(a == local, "no plugin: the local service is used as is")
	a.set_consent(true)  # base no-op must not crash
	a.log_event("x", {})
	check_eq(local.seen.size(), 1, "logged locally")


func test_nothing_is_sent_before_consent() -> void:
	var fb := FakeFirebase.new()
	var local := Local.new()
	var a := _make(fb, local)
	a.start()
	fb.core_initialized.emit(true)
	fb.analytics_initialized.emit(true)
	a.log_event("level_start", {"level": "c1_l1"})
	check_eq(fb.sent.size(), 0, "no consent, nothing sent")
	check_eq(local.seen.size(), 1, "still logged locally")
	check(fb.collection.has(false) or fb.collection.is_empty(), "collection stays off")


func test_consent_turns_collection_on_and_sends() -> void:
	var fb := FakeFirebase.new()
	var a := _make(fb, Local.new())
	a.start()
	a.set_consent(true)
	fb.core_initialized.emit(true)
	fb.analytics_initialized.emit(true)
	a.log_event("level start", {"level": "c1_l1", "ok": true})
	check_eq(fb.sent.size(), 1, "sent once")
	check_eq(fb.sent[0][0], "level_start", "name cleaned")
	check_eq(fb.sent[0][1]["ok"], 1, "params cleaned")
	check(fb.collection.has(true), "collection enabled")
	check_eq(fb.consent_calls.back()["analytics_storage"], "granted", "analytics storage granted")
	check_eq(fb.consent_calls.back()["ad_storage"], "denied", "ads storage stays denied")
	check_eq(fb.consent_calls.back()["ad_personalization"], "denied", "no ad personalisation, ever")


func test_withdrawing_consent_stops_sending() -> void:
	var fb := FakeFirebase.new()
	var a := _make(fb, Local.new())
	a.start()
	a.set_consent(true)
	fb.core_initialized.emit(true)
	fb.analytics_initialized.emit(true)
	a.log_event("a", {})
	a.set_consent(false)
	a.log_event("b", {})
	check_eq(fb.sent.size(), 1, "only the event before withdrawal")
	check_eq(fb.collection.back(), false, "collection switched off")
	check_eq(fb.consent_calls.back()["analytics_storage"], "denied", "storage denied again")


func test_events_before_init_are_queued_then_flushed() -> void:
	var fb := FakeFirebase.new()
	var a := _make(fb, Local.new())
	a.start()
	a.set_consent(true)
	a.log_event("early", {})
	check_eq(fb.sent.size(), 0, "held until Firebase is ready")
	fb.core_initialized.emit(true)
	fb.analytics_initialized.emit(true)
	check_eq(fb.sent.size(), 1, "flushed on init")
	check_eq(fb.sent[0][0], "early", "the held event")


func test_failed_init_drops_remote_but_keeps_the_game_running() -> void:
	var fb := FakeFirebase.new()
	var local := Local.new()
	var a := _make(fb, local)
	a.start()
	a.set_consent(true)
	fb.core_initialized.emit(false)
	a.log_event("x", {})
	check_eq(fb.sent.size(), 0, "nothing sent")
	check_eq(local.seen.size(), 1, "log unaffected")


func test_queue_is_bounded() -> void:
	var fb := FakeFirebase.new()
	var a := _make(fb, Local.new())
	a.start()
	a.set_consent(true)
	for i in 500:
		a.log_event("e%d" % i, {})
	fb.core_initialized.emit(true)
	fb.analytics_initialized.emit(true)
	check(fb.sent.size() <= FirebaseAnalytics.MAX_QUEUE, "queue capped")
	check_eq(fb.sent.back()[0], "e499", "newest events survive")


func test_crash_context_only_with_consent() -> void:
	var fb := FakeFirebase.new()
	var a := _make(fb, Local.new())
	a.start()
	fb.core_initialized.emit(true)
	fb.crashlytics_initialized.emit(true)
	a.set_context("level", "c1_l2")
	check(not fb.context.has("level"), "no context without consent")
	a.set_consent(true)
	a.set_context("level", "c1_l2")
	check_eq(fb.context.get("level"), "c1_l2", "context set with consent")


# --- Consent choice (persisted as a string, because JSON turns numbers into floats) ----

func test_share_data_choice_round_trips() -> void:
	var s := SaveData.new()
	check_eq(s.settings["share_data"], "ask", "not asked yet")
	s.settings["share_data"] = "yes"
	check_eq(SaveData.from_dict(s.to_dict()).settings["share_data"], "yes", "kept")
