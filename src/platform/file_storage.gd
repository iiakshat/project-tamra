class_name FileStorage
extends StorageService
## Stores each key as a file under base_dir. Writes go to a temp file first, so a crash
## mid-write leaves either the old save or the new one, never half of each.

var base_dir: String


func _init(dir: String = "user://") -> void:
	base_dir = dir if dir.ends_with("/") else dir + "/"


func read_text(key: String) -> String:
	var path := base_dir + key
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	# A crash between removing the old file and renaming the new one leaves only the temp.
	if FileAccess.file_exists(path + ".tmp"):
		return FileAccess.get_file_as_string(path + ".tmp")
	return ""


func write_text(key: String, text: String) -> bool:
	var path := ProjectSettings.globalize_path(base_dir + key)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK
