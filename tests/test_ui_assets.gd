extends "res://tests/test_case.gd"
## The UI's data contracts: every icon name the code or configs ask for exists as a file,
## and the journey map config places every level.

## Icon names used across src/ui (keep in step when adding a new one).
const USED_ICONS := [
	"play", "next", "pause", "restart", "home", "close", "check", "gear", "music", "music_off",
	"sound", "sound_off", "vibration", "lock", "star", "star_empty", "clock", "hourglass",
	"question", "pen", "log", "up", "map", "info", "shop", "heart", "back", "chevron", "gift",
	"book", "story", "vow", "jyoti", "prana", "trial", "skull", "fire", "cast", "flag", "bridge",
	"leap", "skin",
]


func test_every_used_icon_exists() -> void:
	for name in USED_ICONS:
		check(Icons.exists(name), "icon file for '%s'" % name)


func test_vow_and_story_icons_exist() -> void:
	for v in DailyRules.VOW_POOL:
		check(Icons.exists(str(v["icon"])), "vow icon '%s'" % v["icon"])
	for id in DailyPanel.VOW_ICONS:
		check(Icons.exists(str(DailyPanel.VOW_ICONS[id])), "daily vow icon for " + id)
	# Story choices may carry an icon (or a glyph name); walk the whole file for them.
	var icons: Array[String] = []
	_collect_option_icons(GameConfig.read("story"), icons)
	for icon in icons:
		if not GlyphShapes.NAMES.has(icon):
			check(Icons.exists(icon), "story choice icon '%s'" % icon)


func _collect_option_icons(node: Variant, out: Array[String]) -> void:
	if node is Dictionary:
		for opt in node.get("options", []):
			if opt is Dictionary and str(opt.get("icon", "")) != "":
				out.append(str(opt["icon"]))
		for k in node:
			_collect_option_icons(node[k], out)
	elif node is Array:
		for v in node:
			_collect_option_icons(v, out)


func test_map_places_every_level_inside_the_image() -> void:
	var map := GameConfig.read("map")
	var nodes: Dictionary = map.get("nodes", {})
	for id in Game.all_levels():
		check(nodes.has(id), "map node for " + id)
	var points: Array = nodes.values() + map.get("path", [])
	for p in points:
		var v := GameConfig.vec(p, Vector2(-1, -1))
		check(v.x >= 0.0 and v.x <= 1.0 and v.y >= 0.0 and v.y <= 1.0, "map point %s is 0..1" % str(p))
	check(map.get("path", []).size() >= 2, "a route to draw")
	for ch in Game.game_cfg.get("chapters", []):
		check(map.get("chapter_labels", {}).has(str(ch["id"])), "label for chapter " + str(ch["id"]))
