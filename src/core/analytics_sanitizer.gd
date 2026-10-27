class_name AnalyticsSanitizer
extends RefCounted
## Cleans event names and parameters to Firebase's rules, so a bad name never silently
## drops an event: names are 1-40 characters of letters, digits and underscores starting
## with a letter, at most 25 parameters, string values at most 100 characters.

const MAX_NAME := 40
const MAX_PARAMS := 25
const MAX_VALUE := 100
const RESERVED_PREFIXES := ["firebase_", "google_", "ga_"]


static func event_name(raw: String) -> String:
	return _identifier(raw, "event", "e_")


static func params(raw: Dictionary) -> Dictionary:
	var out := {}
	for key in raw:
		if out.size() >= MAX_PARAMS:
			break
		var name := _identifier(str(key), "", "p_")
		var value: Variant = _value(raw[key])
		if name == "" or value == null:
			continue
		out[name] = value
	return out


static func _identifier(raw: String, empty_name: String, letter_prefix: String) -> String:
	var s := ""
	for i in raw.length():
		var c := raw[i]
		var ok := (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_"
		s += c if ok else "_"
	if s == "":
		return empty_name
	var first := s[0]
	if not ((first >= "a" and first <= "z") or (first >= "A" and first <= "Z")):
		s = letter_prefix + s
	for prefix in RESERVED_PREFIXES:
		if s.begins_with(prefix):
			s = "app_" + s
			break
	return s.substr(0, MAX_NAME)


static func _value(v: Variant) -> Variant:
	match typeof(v):
		TYPE_NIL:
			return null
		TYPE_BOOL:
			return 1 if v else 0
		TYPE_INT, TYPE_FLOAT:
			return v
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v).substr(0, MAX_VALUE)
		TYPE_ARRAY, TYPE_DICTIONARY:
			return JSON.stringify(v).substr(0, MAX_VALUE)
		_:
			return str(v).substr(0, MAX_VALUE)
