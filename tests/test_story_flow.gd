extends "res://tests/test_case.gd"


func test_chapter_first_levels_open_with_story() -> void:
	var game := GameConfig.read("game")
	var stories := GameConfig.read("story")
	for ch in game["chapters"]:
		var first := str(ch["levels"][0])
		check_eq(StoryFlow.opening_story(game["chapters"], stories, first), str(ch["story"]), "story before " + first)
		for i in range(1, (ch["levels"] as Array).size()):
			var later := str(ch["levels"][i])
			check_eq(StoryFlow.opening_story(game["chapters"], stories, later), "", "no story before " + later)


func test_unknown_story_or_level_is_ignored() -> void:
	var chapters := [{"levels": ["a1", "a2"], "story": "missing"}]
	check_eq(StoryFlow.opening_story(chapters, {}, "a1"), "", "story not in config")
	check_eq(StoryFlow.opening_story(chapters, {"missing": []}, "zz"), "", "unknown level")


func test_first_run() -> void:
	var key := StoryScreen.seen_key("c1_intro")
	var s := SaveData.new()
	check(StoryFlow.is_first_run(s, key), "fresh save is first run")
	s.story_seen.append(key)
	check(not StoryFlow.is_first_run(s, key), "opening story seen -> curtain next time")
	var s2 := SaveData.new()
	s2.record_result("c1_l1", 50.0, 3)
	check(not StoryFlow.is_first_run(s2, key), "existing progress is never first run")


func test_ending_card_config() -> void:
	var cfg := GameConfig.read("game")
	var ending: Dictionary = cfg.get("ending", {})
	for key in ["title", "hi", "line", "plate"]:
		check(not str(ending.get(key, "")).is_empty(), "game.json ending." + key)
	check(ResourceLoader.exists("res://assets/story/%s.jpg" % str(ending.get("plate", ""))), "ending plate exists")
