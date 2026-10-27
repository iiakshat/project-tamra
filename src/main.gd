extends Node
## Screen router: menu -> story -> level -> results.
##
## Debug builds accept user args after "--" for testing without touching a phone:
##   --level=c1_l1      start straight in a level
##   --x=2500           drop the hero at this x
##   --story=c1_intro   open a story screen
##   --ending=1         show the "To be continued" card
##   --firstrun=1       behave as a brand-new player when the save is empty (otherwise any arg disables it)
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
	if (args.is_empty() or args.has("firstrun")) and StoryFlow.is_first_run(Game.save, StoryScreen.seen_key("c1_intro")):
		# Brand-new player: no launch curtain, straight into the story and then level 1.
		# The curtain is skipped for the rest of this session too; it shows from the next launch.
		MenuScreen._intro_shown = true
		_play_stories(["c1_intro"], _start_level.bind(Game.all_levels()[0], -1.0, ""))
	elif args.has("preview"):
		_switch(PuppetPreview.new())
	elif args.has("level"):
		_start_level(args["level"], float(args.get("x", "-1")))
	elif args.has("story"):
		_show_story(args["story"], "")
	elif args.has("ending"):
		_show_ending()
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
	menu.continue_pressed.connect(_enter_level)
	menu.level_chosen.connect(func(id: String, mod: String) -> void: _enter_level(id, mod))
	menu.story_chosen.connect(func(id: String) -> void: _play_stories([id], _show_map))
	_switch(menu)


## Back to the journey map (after replaying a chapter's story from it).
func _show_map() -> void:
	show_menu()
	(_screen as MenuScreen).open_map()


func _on_begin() -> void:
	var levels := Game.all_levels()
	if not levels.is_empty():
		_enter_level(levels[0])


## Opens a level. The first level of each chapter starts with that chapter's story
## (every time, skippable); other levels, retries and daily trials start straight away.
func _enter_level(id: String, mod: String = "") -> void:
	var story := ""
	if mod == "":
		story = StoryFlow.opening_story(Game.game_cfg.get("chapters", []), GameConfig.read("story"), id)
	_play_stories([story] if story != "" else [], _start_level.bind(id, -1.0, mod))


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


## After a level: its short story beat (first time), then the journey map, where Tamra
## walks to the next level. After the last level the story beat is followed by the
## "To be continued" card. Chapter openings play when their first level is opened.
func _on_level_completed(id: String) -> void:
	var stories: Array = []
	if _unseen("after_" + id):
		stories.append("after_" + id)
	if Game.next_level(id) == "":
		_play_stories(stories, _show_ending)
		return
	_play_stories(stories, _walk_on_map.bind(id))


func _show_ending() -> void:
	var card := EndingScreen.new()
	card.finished.connect(show_menu)
	_switch(card)


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
