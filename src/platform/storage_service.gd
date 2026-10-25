class_name StorageService
extends RefCounted
## Key/value text storage. The base class stores nothing; see FileStorage.


func read_text(_key: String) -> String:
	return ""


func write_text(_key: String, _text: String) -> bool:
	return false
