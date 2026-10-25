extends "res://tests/test_case.gd"


class MemoryStorage extends StorageService:
	var data := {}

	func read_text(key: String) -> String:
		return data.get(key, "")

	func write_text(key: String, text: String) -> bool:
		data[key] = text
		return true


func test_round_trip() -> void:
	var store := SaveStore.new(MemoryStorage.new())
	var s := SaveData.new()
	s.unlocked.append("c1_l2")
	s.record_result("c1_l1", 95.5, 7)
	s.story_seen.append("c1_intro")
	s.settings["vibration"] = false
	check(store.save_data(s), "save succeeds")
	var loaded := store.load_data()
	check_eq(loaded.unlocked, s.unlocked, "unlocked")
	check_eq(loaded.results["c1_l1"]["embers"], 7, "embers")
	check_eq(loaded.results["c1_l1"]["time"], 95.5, "time")
	check_eq(loaded.story_seen, s.story_seen, "story_seen")
	check_eq(loaded.settings["vibration"], false, "vibration")


func test_missing_save_gives_defaults() -> void:
	var loaded := SaveStore.new(MemoryStorage.new()).load_data()
	check_eq(loaded.unlocked.size(), 1, "only the first level is unlocked")
	check(loaded.results.is_empty(), "no results")


func test_corrupt_save_gives_defaults() -> void:
	var storage := MemoryStorage.new()
	storage.data[SaveStore.KEY] = "{not json"
	var loaded := SaveStore.new(storage).load_data()
	check_eq(loaded.unlocked, SaveData.new().unlocked, "defaults after corruption")


func test_mistyped_fields_are_ignored() -> void:
	var s := SaveData.from_dict({
		"unlocked": "c1_l9",
		"results": {"c1_l1": "fast"},
		"settings": {"vibration": "yes", "music": 0.3, "unknown": 1},
	})
	check_eq(s.unlocked, SaveData.new().unlocked, "string instead of array ignored")
	check(s.results.is_empty(), "non-dict result ignored")
	check_eq(s.settings["vibration"], true, "wrong type keeps default")
	check_eq(s.settings["music"], 0.3, "valid setting kept")
	check(not s.settings.has("unknown"), "unknown setting dropped")


func test_record_result_keeps_best() -> void:
	var s := SaveData.new()
	s.record_result("c1_l1", 120.0, 4)
	s.record_result("c1_l1", 150.0, 9)
	s.record_result("c1_l1", 90.0, 2)
	check_eq(s.results["c1_l1"]["time"], 90.0, "best time")
	check_eq(s.results["c1_l1"]["embers"], 9, "most embers")


func test_file_storage_round_trip() -> void:
	var dir := "user://test_storage/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var fs := FileStorage.new(dir)
	check(fs.write_text("a.json", "first"), "first write")
	check(fs.write_text("a.json", "second"), "overwrite")
	check_eq(fs.read_text("a.json"), "second", "read back")
	check_eq(fs.read_text("missing.json"), "", "missing key")
