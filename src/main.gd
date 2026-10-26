extends Node
## Screen router: menu -> story -> level -> results.
##
## Debug builds accept user args after "--" for testing without touching a phone:
##   --level=c1_l1      start straight in a level
##   --x=2500           drop the hero at this x
##   --story=c1_intro   open a story screen
##   --hold=move_right  hold an input action
##   --cast=line        draw this mantra glyph after --cast_frame frames (default 60)
##   --screenshot=path  save a PNG after --frames frames, then quit
##   --frames=N         quit after N frames
##   --panel=daily      open a menu panel: map, daily, shop, settings, book
##   --card=c1_l2       open the journey map with this level's card
##   --focus=c3_l3      open the journey map centred on this level

var _screen: Node


func _ready() -> void:
	GameLog.log_renderer()
	var args := _debug_args()
	if args.has("preview"):
		_switch(PuppetPreview.new())
	elif args.has("level"):
		_start_level(args["level"], float(args.get("x", "-1")))
	elif args.has("story"):
		_show_story(args["story"], "")
	else:
		# Debug runs open screens directly; the launch intro only with --intro=1.
		if not args.is_empty() and not args.has("intro"):
			MenuScreen._intro_shown = true
		show_menu()
		if args.has("book"):
			(_screen as MenuScreen).open_book()
		if args.has("panel"):
			(_screen as MenuScreen).open_panel(args["panel"])
		if args.has("focus"):
			(_screen as MenuScreen).open_map().focus(args["focus"])
		elif args.has("walk"):
			(_screen as MenuScreen).open_map(args["walk"])
		if args.has("card"):
			(_screen as MenuScreen).open_map().open_card(args["card"])
	if args.has("hold"):
		Input.action_press(args["hold"])
	if args.has("cast"):
		_cast_after(int(args.get("cast_frame", "60")), args["cast"])
	if args.has("screenshot"):
		_screenshot_after(int(args.get("frames", "90")), args["screenshot"])
	elif args.has("frames"):
		_quit_after(int(args["frames"]))


func show_menu() -> void:
	var menu := MenuScreen.new()
	menu.begin_pressed.connect(_on_begin)
	menu.continue_pressed.connect(_continue)
	menu.level_chosen.connect(func(id: String, mod: String) -> void: _start_level(id, -1.0, mod))
	menu.story_chosen.connect(func(id: String) -> void: _play_stories([id], _show_map))
	_switch(menu)


## Back to the journey map (after replaying a chapter's story from it).
func _show_map() -> void:
	show_menu()
	(_screen as MenuScreen).open_map()


func _on_begin() -> void:
	var levels := Game.all_levels()
	if not levels.is_empty():
		_continue(levels[0])


## Plays a level, preceded by its chapter's opening scene the first time.
## The opening story always plays once (also for players who continue mid-game after
## the story was rewritten), so everyone meets Tamra, Maa and the Smoke King.
func _continue(id: String) -> void:
	var stories: Array = []
	if _unseen("c1_intro"):
		stories.append("c1_intro")
	var story := str(Game.chapter_of(id).get("story", ""))
	var first_of_chapter: bool = Game.chapter_of(id).get("levels", [""])[0] == id
	if first_of_chapter and _unseen(story) and not stories.has(story):
		stories.append(story)
	_play_stories(stories, _start_level.bind(id, -1.0, ""))


func _show_story(story_id: String, then_level: String) -> void:
	if then_level == "":
		_play_stories([story_id], show_menu)
	else:
		_play_stories([story_id], _start_level.bind(then_level, -1.0, ""))


## Plays story scenes back to back, then calls `then`.
func _play_stories(ids: Array, then: Callable) -> void:
	if ids.is_empty():
		then.call()
		return
	var story := StoryScreen.new()
	story.setup(str(ids[0]))
	story.finished.connect(_play_stories.bind(ids.slice(1), then))
	_switch(story)


func _unseen(story_id: String) -> bool:
	return story_id != "" and GameConfig.read("story").has(story_id) and not StoryScreen.is_seen(story_id)


func _start_level(id: String, start_x: float = -1.0, mod: String = "") -> void:
	var level := Level.new()
	level.setup(id, start_x, mod)
	level.completed.connect(_on_level_completed)
	level.quit_to_menu.connect(show_menu)
	level.restart_requested.connect(func(lid: String) -> void: _start_level(lid, -1.0, mod))
	_switch(level)


## After a level: its short story beat (first time), the next chapter's opening if one
## begins, then the journey map, where Tamra walks to the next level and its card opens.
func _on_level_completed(id: String) -> void:
	var nxt := Game.next_level(id)
	var stories: Array = []
	if _unseen("after_" + id):
		stories.append("after_" + id)
	if nxt == "":
		_play_stories(stories, show_menu)
		return
	var chapter := Game.chapter_of(nxt)
	if chapter != Game.chapter_of(id) and _unseen(str(chapter.get("story", ""))):
		stories.append(str(chapter["story"]))
	_play_stories(stories, _walk_on_map.bind(id))


func _walk_on_map(from_id: String) -> void:
	show_menu()
	(_screen as MenuScreen).open_map(from_id)


func _switch(node: Node) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if _screen != null:
		_screen.queue_free()
	_screen = node
	GameLog.info("screen", node.get_script().get_global_name())
	add_child(node)


func _debug_args() -> Dictionary:
	var out := {}
	if not OS.is_debug_build():
		return out
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out


func _screenshot_after(frames: int, path: String) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _cast_after(frames: int, glyph: String) -> void:
	for i in frames:
		await get_tree().process_frame
	var level := _screen as Level
	if level == null:
		return
	var canon := GlyphShapes.canonical(glyph)
	var pts := PackedVector2Array()
	for i in range(canon.size() - 1):
		for s in 12:
			pts.append(Vector2(640, 360) + canon[i].lerp(canon[i + 1], s / 12.0) * 120.0)
	pts.append(Vector2(640, 360) + canon[canon.size() - 1] * 120.0)
	level.cast_stroke(pts)


func _quit_after(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	get_tree().quit()
