class_name StoryFlow
extends RefCounted
## When stories play. Pure logic, no scene nodes (unit tested).
##   - A chapter's story plays every time its first level is opened from the map or Play
##     (skippable); the other levels start straight away.
##   - A brand-new player skips the launch curtain and goes straight into the first story.


## The story to play before this level, or "" when it should start straight away.
## `chapters` is game.json's chapter list, `stories` the story.json dictionary.
static func opening_story(chapters: Array, stories: Dictionary, level_id: String) -> String:
	for ch in chapters:
		var levels: Array = ch.get("levels", [])
		if levels.is_empty() or str(levels[0]) != level_id:
			continue
		var story := str(ch.get("story", ""))
		return story if stories.has(story) else ""
	return ""


## True for a player who has never finished the opening story and has no progress.
## Someone who quit mid-story is still first-run and sees it again; someone who finished
## or skipped it gets the normal launch curtain next time.
static func is_first_run(save: SaveData, opening_seen_key: String) -> bool:
	return save.results.is_empty() and not save.story_seen.has(opening_seen_key)
