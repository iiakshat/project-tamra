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
		show_menu()
		if args.has("book"):
			(_screen as MenuScreen).open_book()
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
	menu.continue_pressed.connect(_start_level)
	_switch(menu)


func _on_begin() -> void:
	var chapters: Array = Game.game_cfg.get("chapters", [])
	if chapters.is_empty():
		return
	var first: Dictionary = chapters[0]
	_show_story(str(first.get("story", "")), str(first["levels"][0]))


func _show_story(story_id: String, then_level: String) -> void:
	var story := StoryScreen.new()
	story.setup(story_id)
	if then_level == "":
		story.finished.connect(show_menu)
	else:
		story.finished.connect(_start_level.bind(then_level, -1.0))
	_switch(story)


func _start_level(id: String, start_x: float = -1.0) -> void:
	var level := Level.new()
	level.setup(id, start_x)
	level.completed.connect(_on_level_completed)
	level.quit_to_menu.connect(show_menu)
	level.restart_requested.connect(_start_level)
	_switch(level)


func _on_level_completed(id: String) -> void:
	var nxt := Game.next_level(id)
	if nxt == "":
		show_menu()
		return
	# Entering a new chapter: tell its story first, once.
	var chapter := Game.chapter_of(nxt)
	var story := str(chapter.get("story", ""))
	if chapter != Game.chapter_of(id) and story != "" and not Game.save.story_seen.has(story):
		_show_story(story, nxt)
	else:
		_start_level(nxt)


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
