class_name LevelSelect
extends Control
## The journey map (level select): a painted panorama wider than the screen, dragged or
## flung sideways. A dotted route links the nine levels; the part already walked is jade.
## Each level is a copper medallion with its number and stars (a lock until reached).
## The hero stands on the current level. Tapping a level opens a card: Play, or replay
## the chapter's story. Layout lives in config/map.json so new art needs no code change.

signal chosen(level_id: String)
signal story_chosen(story_id: String)
signal closed

const NODE_D := 72.0
const DRAG_SLOP := 12.0
const HERO_PNG := "res://assets/chars/hero/idle.png"

var _cfg: Dictionary
var _tex: Texture2D
var _world: Control
var _map: TextureRect
var _route: Route
var _nodes := {}        # level id -> medallion holder (Control centred on the node)
var _labels := {}       # chapter id -> label plate
var _hero: Control
var _current := ""
var _scale := 1.0
var _offset := 0.0
var _vel := 0.0
var _pressing := false
var _dragged := false
var _press_x := 0.0
var _last_x := 0.0
var _card: Control
var _intro: Tween
var _focus := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cfg = GameConfig.read("map")
	_tex = load(str(_cfg.get("image", "res://assets/ui/journey_map.png")))
	var bg := UiKit.full_rect(ColorRect.new()) as ColorRect
	bg.color = Color(0.03, 0.02, 0.08)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)
	_map = TextureRect.new()
	_map.texture = _tex
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_map)
	_route = Route.new()
	_world.add_child(_route)

	_current = Game.continue_level()
	var n := 0
	for ch in Game.game_cfg.get("chapters", []):
		var plate := _chapter_label(str(ch.get("name", "")))
		_world.add_child(plate)
		_labels[str(ch.get("id", ""))] = plate
		for id in ch.get("levels", []):
			n += 1
			var node := _node(str(id), n)
			_world.add_child(node)
			_nodes[str(id)] = node
	_hero = _hero_marker()
	_world.add_child(_hero)

	_build_top_bar()
	resized.connect(_layout)
	_layout.call_deferred()
	Sfx.play("page_turn")


func _process(delta: float) -> void:
	if not _pressing and absf(_vel) > 1.0:
		_offset += _vel * delta
		_vel *= pow(0.03, delta)
		_apply_offset()


func _input(event: InputEvent) -> void:
	if _card != null or not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragged = false
				_press_x = mb.position.x
				_last_x = mb.position.x
				_vel = 0.0
				if _intro != null:
					_intro.kill()
			else:
				_pressing = false
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_vel = 900.0 * (1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
	elif event is InputEventMouseMotion and _pressing:
		var mm := event as InputEventMouseMotion
		if absf(mm.position.x - _press_x) > DRAG_SLOP:
			_dragged = true
		if _dragged:
			_offset += mm.position.x - _last_x
			_vel = mm.velocity.x
			_apply_offset()
		_last_x = mm.position.x


## Map position of a 0..1 point, in world (unscrolled) pixels.
func _px(p: Vector2) -> Vector2:
	return Vector2(p.x * _tex.get_width(), p.y * _tex.get_height()) * _scale


func _layout() -> void:
	if size.y <= 0.0:
		return
	var top := float(_cfg.get("view_top", 0.0))
	_scale = size.y / (_tex.get_height() * (1.0 - top))
	_world.position.y = -top * _tex.get_height() * _scale
	_map.size = Vector2(_tex.get_size()) * _scale
	_world.size = _map.size
	_route.size = _map.size

	var pts := PackedVector2Array()
	for p in _cfg.get("path", []):
		pts.append(_px(GameConfig.vec(p)))
	_route.build(pts)
	for id in _nodes:
		var at := _px(GameConfig.vec(_cfg.get("nodes", {}).get(id, [0.5, 0.5])))
		(_nodes[id] as Control).position = at
	for ch in _labels:
		var plate := _labels[ch] as Control
		plate.position = _px(GameConfig.vec(_cfg.get("chapter_labels", {}).get(ch, [0.5, 0.3]))) - plate.size / 2.0
	var cur := _nodes.get(_current) as Control
	if cur != null:
		_hero.position = cur.position
		_route.lit_until = _route.distance_at(cur.position)
	# Open centred on the current level (or a focused one), easing in from the side.
	var aim := _nodes.get(_focus, cur) as Control
	var target := _offset_for(aim.position.x if aim != null else 0.0)
	_offset = target + 160.0
	_apply_offset()
	_intro = create_tween()
	_intro.tween_method(func(v: float) -> void:
		_offset = v
		_apply_offset(), _offset, target, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _offset_for(world_x: float) -> float:
	return size.x * 0.5 - world_x


func _apply_offset() -> void:
	var w := _map.size.x
	if w <= size.x:
		_offset = (size.x - w) / 2.0
		_vel = 0.0
	else:
		var clamped := clampf(_offset, size.x - w, 0.0)
		if clamped != _offset:
			_vel = 0.0
		_offset = clamped
	_world.position.x = _offset


# --- pieces ---------------------------------------------------------------------------

func _node(id: String, number: int) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var open := Game.save.unlocked.has(id)
	if id == _current:
		var ring := Ring.new()
		ring.position = -Vector2(NODE_D, NODE_D) * 0.75
		ring.size = Vector2(NODE_D, NODE_D) * 1.5
		holder.add_child(ring)
	var b := UiKit.icon_button("" if open else "lock", NODE_D, UiKit.MUTED)
	b.position = -Vector2(NODE_D, NODE_D) / 2.0
	b.size = Vector2(NODE_D, NODE_D)
	if open:
		var num := UiKit.title(str(number), 34, UiKit.TEXT if Game.save.results.has(id) else UiKit.ACCENT, 6)
		UiKit.full_rect(num)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.offset_top = -2
		b.add_child(num)
		b.pressed.connect(func() -> void:
			if not _dragged:
				_open_card(id, number)
		)
	else:
		b.disabled = true
	holder.add_child(b)
	if open:
		# Earned stars sit in a small arc under the medallion.
		var got := Game.save.stars(id)
		for i in 3:
			var s := UiKit.IconView.new()
			s.icon = "star" if i < got else "star_empty"
			s.color = UiKit.STAR if i < got else Color(UiKit.TEXT, 0.7)
			s.size = Vector2(24, 24)
			s.position = Vector2(-12 + (i - 1) * 23, NODE_D * 0.42 + (6 if i == 1 else 0))
			holder.add_child(s)
	return holder


func _chapter_label(text: String) -> Control:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiKit.plate_style(16, 0.7))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(UiKit.title(text, 24, UiKit.TEXT, 5))
	plate.size = plate.get_combined_minimum_size()
	return plate


## The hero's painted idle frame standing on the current level, bobbing gently.
func _hero_marker() -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(art)
	var tex := _hero_frame()
	var h := 120.0
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var w := h * tex.get_width() / float(tex.get_height())
		tr.size = Vector2(w, h)
		tr.position = Vector2(-w / 2.0, -h)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(tr)
	else:
		var v := UiKit.IconView.new()
		v.icon = "jyoti"
		v.color = UiKit.ACCENT
		v.size = Vector2(48, 48)
		v.position = Vector2(-24, -48)
		art.add_child(v)
	art.position.y = -NODE_D * 0.42
	var t := art.create_tween().set_loops()
	t.tween_property(art, "position:y", -NODE_D * 0.42 - 8.0, 0.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(art, "position:y", -NODE_D * 0.42, 0.8).set_trans(Tween.TRANS_SINE)
	return holder


## First frame of the hero's idle strip; frame size from config/actors.json if present.
func _hero_frame() -> Texture2D:
	if not ResourceLoader.exists(HERO_PNG):
		return null
	var tex: Texture2D = load(HERO_PNG)
	var fw := 0
	var fh := 0
	if FileAccess.file_exists("res://config/actors.json"):
		var idle: Dictionary = GameConfig.read("actors").get("hero", {}).get("anims", {}).get("idle", {})
		fw = int(idle.get("frame_w", 0))
		fh = int(idle.get("frame_h", 0))
	if fw <= 0 or fh <= 0 or fw > tex.get_width() or fh > tex.get_height():
		return tex
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, fw, fh)
	return at


func _build_top_bar() -> void:
	var back := UiKit.icon_button("close", 60)
	back.position = Vector2(18, 16)
	back.pressed.connect(func() -> void: closed.emit())
	add_child(back)
	var right := HBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -360
	right.offset_right = -20
	right.offset_top = 22
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 10)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	var stars := PanelContainer.new()
	stars.add_theme_stylebox_override("panel", UiKit.plate_style(26))
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.add_child(UiKit.stat("star", "%d/%d" % [Game.save.total_stars(), Game.all_levels().size() * 3], UiKit.STAR, 24))
	right.add_child(stars)
	right.add_child(UiKit.jyoti_counter(24))


# --- level card -------------------------------------------------------------------------

## Centres the map on a level when it opens (debug and deep links).
func focus(id: String) -> void:
	_focus = id
	if is_inside_tree():
		_layout()


## Opens the level card for `id` (also a debug entry point).
func open_card(id: String) -> void:
	var levels := Game.all_levels()
	if levels.has(id):
		_open_card(id, levels.find(id) + 1)


func _open_card(id: String, number: int) -> void:
	_card = UiKit.full_rect(Control.new())
	var dim := UiKit.full_rect(ColorRect.new()) as ColorRect
	dim.color = Color(0.01, 0.0, 0.04, 0.55)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_card()
	)
	_card.add_child(dim)
	var center := UiKit.full_rect(CenterContainer.new())
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.frame_style(0.55, 12))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(420, 0)
	panel.add_child(col)

	var chapter := Game.chapter_of(id)
	var head := UiKit.header("", "%s  ·  %d" % [str(chapter.get("name", "")), number], _close_card)
	(head.get_child(0) as Label).add_theme_font_size_override("font_size", 22)
	(head.get_child(0) as Label).add_theme_color_override("font_color", UiKit.COPPER)
	col.add_child(head)
	var name := UiKit.title(Game.level_name(id), 40, UiKit.TEXT, 8)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name)

	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 6)
	var got := Game.save.stars(id)
	for i in 3:
		var s := UiKit.IconView.new()
		s.icon = "star" if i < got else "star_empty"
		s.color = UiKit.STAR if i < got else Color(UiKit.TEXT, 0.6)
		s.custom_minimum_size = Vector2(44, 44)
		stars.add_child(s)
	col.add_child(stars)

	var result: Dictionary = Game.save.results.get(id, {})
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 28)
	if result.is_empty():
		stats.add_child(UiKit.label("Not cleared yet", 20, UiKit.MUTED, 4))
	else:
		stats.add_child(UiKit.stat("clock", UiKit.format_time(float(result.get("time", 0.0))), UiKit.TEXT, 22))
		stats.add_child(UiKit.stat("jyoti", str(int(result.get("embers", 0))), UiKit.JYOTI, 22))
	col.add_child(stats)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 22)
	var story_id := str(chapter.get("story", ""))
	if story_id != "" and GameConfig.read("story").has(story_id):
		var story := UiKit.icon_button("story", 62)
		story.pressed.connect(func() -> void: story_chosen.emit(story_id))
		actions.add_child(UiKit.labeled(story, "Story", 16))
	var play := UiKit.pill("PLAY", "play", "red", 72, 220)
	play.pressed.connect(func() -> void: chosen.emit(id))
	actions.add_child(play)
	col.add_child(actions)
	add_child(_card)
	UiKit.pop_in(panel)
	Sfx.play("page_turn")


func _close_card() -> void:
	if _card != null:
		_card.queue_free()
		_card = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _card != null:
			_close_card()
		else:
			closed.emit()


## The route: evenly spaced dots along a smoothed path. Dots up to `lit_until` (the
## walked part) are jade with a slow travelling shimmer; the rest are faint ivory.
class Route extends Control:
	const SPACING := 15.0
	var dots := PackedVector2Array()
	var dist := PackedFloat32Array()
	var lit_until := 0.0
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func build(points: PackedVector2Array) -> void:
		dots.clear()
		dist.clear()
		if points.size() < 2:
			return
		var smooth := PackedVector2Array()
		for i in points.size() - 1:
			var p0 := points[maxi(i - 1, 0)]
			var p1 := points[i]
			var p2 := points[i + 1]
			var p3 := points[mini(i + 2, points.size() - 1)]
			for s in 16:
				var t := s / 16.0
				smooth.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
		smooth.append(points[points.size() - 1])
		var travelled := 0.0
		var next := 0.0
		for i in smooth.size() - 1:
			var a := smooth[i]
			var b := smooth[i + 1]
			var seg := a.distance_to(b)
			while next <= travelled + seg:
				dots.append(a.lerp(b, (next - travelled) / maxf(seg, 0.001)))
				dist.append(next)
				next += SPACING
			travelled += seg
		queue_redraw()

	## Distance along the route of the dot closest to `p`.
	func distance_at(p: Vector2) -> float:
		var best := 0.0
		var best_d := INF
		for i in dots.size():
			var d := dots[i].distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = dist[i]
		return best

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for i in dots.size():
			var lit := dist[i] <= lit_until + 0.5
			var p := dots[i]
			if lit:
				var wave := fposmod(dist[i] - _t * 70.0, 260.0)
				var r := 4.6 + (1.6 if wave < 30.0 else 0.0)
				draw_circle(p, r + 1.8, Color(0.02, 0.03, 0.06, 0.85))
				draw_circle(p, r, UiKit.ACCENT.lerp(Color.WHITE, 0.45 if wave < 30.0 else 0.0))
			else:
				draw_circle(p, 4.8, Color(0.96, 0.94, 1.0, 0.8))
				draw_circle(p, 3.4, Color(0.16, 0.12, 0.3))


## A flat jade ring that swells and fades around the current level.
class Ring extends Control:
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var base := size.x / 3.0
		for k in 2:
			var f := fposmod(_t * 0.6 + k * 0.5, 1.0)
			draw_arc(c, base + f * base * 0.5, 0.0, TAU, 48, Color(UiKit.ACCENT, 0.9 * (1.0 - f)), 3.0, true)
