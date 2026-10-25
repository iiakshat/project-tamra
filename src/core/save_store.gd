class_name SaveStore
extends RefCounted
## Loads and saves SaveData through a StorageService. A missing or corrupt save
## gives a fresh SaveData instead of crashing.

const KEY := "save.json"

var _storage: StorageService


func _init(storage: StorageService) -> void:
	_storage = storage


func load_data() -> SaveData:
	var text := _storage.read_text(KEY)
	if text.is_empty():
		return SaveData.new()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Save file unreadable, starting fresh.")
		return SaveData.new()
	return SaveData.from_dict(parsed)


func save_data(data: SaveData) -> bool:
	return _storage.write_text(KEY, JSON.stringify(data.to_dict()))
