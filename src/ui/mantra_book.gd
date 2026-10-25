class_name MantraBook
extends Control
## The Mantra Book: every mantra's sign, cost and rank; unlock and empower with jyoti;
## a practice pad; and a recorder for the player's own sign. Icons over words.
## Works over the menu or a paused level.

signal closed

var _list: VBoxContainer
var _bank: HBoxContainer
var _title: Label
var _meaning: Label
var _desc: Label
var _stats: HBoxContainer
var _glyph: GlyphView
var _actions: HBoxContainer
var _pad: PracticePad
var _pad_info: VBoxContainer
var _selected := ""
var _recording: Array[PackedVector2Array] = []
var _recognizer: GestureRecognizer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := UiKit.full_rect(ColorRect.new()) as ColorRect
	dim.color = Color(0.01, 0.0, 0.04, 0.85)
	add_child(dim)

	var margin := UiKit.full_rect(MarginContainer.new())
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(0.95))
	margin.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	var icon := UiKit.IconView.new()
	icon.icon = "book"
	icon.color = UiKit.ACCENT
	icon.custom_minimum_size = Vector2(48, 48)
	header.add_child(icon)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_bank = UiKit.stat("jyoti", "", UiKit.JYOTI, 28)
	header.add_child(_bank)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(20, 0)
	header.add_child(gap)
	var close := UiKit.icon_button("close", 60)
	close.pressed.connect(func() -> void: closed.emit())
	header.add_child(close)
	outer.add_child(header)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	outer.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	body.add_child(detail)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	detail.add_child(top)
	_glyph = GlyphView.new()
	_glyph.custom_minimum_size = Vector2(130, 130)
	_glyph.animate = true
	_glyph.line_width = 6.0
	top.add_child(_glyph)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = UiKit.label("", 46, UiKit.ACCENT, 6)
	names.add_child(_title)
	_meaning = UiKit.label("", 22, UiKit.MUTED, 4)
	names.add_child(_meaning)
	_stats = HBoxContainer.new()
	_stats.add_theme_constant_override("separation", 22)
	names.add_child(_stats)
	top.add_child(names)
	_desc = UiKit.label("", 24, UiKit.TEXT, 4)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_desc)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 12)
	detail.add_child(_actions)

	var pad_row := HBoxContainer.new()
	pad_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad_row.add_theme_constant_override("separation", 14)
	detail.add_child(pad_row)
	_pad = PracticePad.new()
	_pad.custom_minimum_size = Vector2(300, 170)
	_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pad.stroke_done.connect(_on_pad_stroke)
	pad_row.add_child(_pad)
	_pad_info = VBoxContainer.new()
	_pad_info.custom_minimum_size = Vector2(170, 0)
	_pad_info.alignment = BoxContainer.ALIGNMENT_CENTER
	pad_row.add_child(_pad_info)

	Sfx.play("page_turn")
	_rebuild()
	var first := Game.grimoire.ids()[0]
	for id in Game.grimoire.ids():
		if Game.grimoire.is_learned(id):
			first = id
			break
	_select(first)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		closed.emit()


func _rebuild() -> void:
	_recognizer = Game.grimoire.build_recognizer(Game.gesture_min_score())
	(_bank.get_child(1) as Label).text = str(Game.save.jyoti)
	for c in _list.get_children():
		c.queue_free()
	for id in Game.grimoire.ids():
		var m: Dictionary = Game.mantra_cfg[id]
		var state := str(Game.grimoire.state(id)["state"])
		var entry := UiKit.button("", 240)
		entry.custom_minimum_size = Vector2(240, 58)
		entry.add_theme_font_size_override("font_size", 24)
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.text = "         " + str(m.get("label", id))
		entry.modulate = Color.WHITE if state != "locked" else Color(1, 1, 1, 0.5)
		var icon := GlyphView.new()
		icon.position = Vector2(8, 7)
		icon.size = Vector2(44, 44)
		icon.line_width = 2.5
		icon.show_mantra(id)
		entry.add_child(icon)
		if state != "learned":
			var mark := UiKit.IconView.new()
			mark.icon = "lock" if state == "locked" else "jyoti"
			mark.color = UiKit.MUTED if state == "locked" else UiKit.JYOTI
			mark.position = Vector2(206, 16)
			mark.size = Vector2(26, 26)
			entry.add_child(mark)
		entry.pressed.connect(_select.bind(id))
		_list.add_child(entry)


func _select(id: String) -> void:
	_selected = id
	_recording.clear()
	_pad.recording = false
	var m: Dictionary = Game.mantra_cfg[id]
	var s := Game.grimoire.state(id)
	var color := GameConfig.color(m.get("color", ""), UiKit.ACCENT)
	_glyph.show_mantra(id)
	_title.text = str(m.get("label", id))
	_title.add_theme_color_override("font_color", color)
	_meaning.text = str(m.get("meaning", ""))
	_desc.text = str(m.get("description", ""))
	for c in _stats.get_children():
		c.queue_free()
	_stats.add_child(UiKit.stat("prana", str(Game.grimoire.prana_cost(id)), Color(0.5, 1.0, 0.85), 22))
	_stats.add_child(UiKit.stat("hourglass", "%.1fs" % Game.grimoire.cooldown(id), UiKit.MUTED, 22))
	var ranks := HBoxContainer.new()
	for i in 3:
		var star := UiKit.IconView.new()
		star.custom_minimum_size = Vector2(26, 26)
		star.icon = "star" if i < Game.save.rank(id) and s["state"] == "learned" else "star_empty"
		star.color = color
		ranks.add_child(star)
	_stats.add_child(ranks)
	for c in _actions.get_children():
		c.queue_free()
	match str(s["state"]):
		"learned":
			var cost := Game.grimoire.upgrade_cost(id)
			if cost >= 0:
				_actions.add_child(_price_button("up", cost, func() -> void:
					if Game.upgrade_mantra(_selected):
						Sfx.play("mantra_learned")
						_refresh()
				))
			if GlyphShapes.SHAPES.has(str(m.get("gesture", ""))) or Game.grimoire.has_custom_sign(id):
				var own := UiKit.icon_button("pen", 64)
				own.pressed.connect(_start_recording)
				_actions.add_child(own)
			if Game.grimoire.has_custom_sign(id):
				var reset := UiKit.icon_button("restart", 64, UiKit.MUTED)
				reset.pressed.connect(func() -> void:
					Game.clear_custom_sign(_selected)
					_refresh()
				)
				_actions.add_child(reset)
		"buyable":
			_actions.add_child(_price_button("lock", int(s["cost"]), func() -> void:
				if Game.buy_mantra(_selected):
					Sfx.play("mantra_learned")
					Sfx.play("call_" + _selected)
					_refresh()
			))
		_:
			var where := str(s["level"]) if str(s["level"]) != "" else str(s["after"])
			_actions.add_child(UiKit.stat("lock", Game.level_name(where), UiKit.MUTED, 22))
	_show_pad_info("pen", "", UiKit.MUTED)


## A button showing an icon and a jyoti price; disabled if the player can't afford it.
func _price_button(icon: String, cost: int, on_press: Callable) -> Button:
	var b := UiKit.button("", 200)
	b.custom_minimum_size = Vector2(200, 64)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(row)
	var i := UiKit.IconView.new()
	i.icon = icon
	i.custom_minimum_size = Vector2(32, 32)
	row.add_child(i)
	row.add_child(UiKit.stat("jyoti", str(cost), UiKit.JYOTI, 24))
	b.add_child(row)
	b.disabled = Game.save.jyoti < cost
	b.pressed.connect(on_press)
	return b


func _refresh() -> void:
	var keep := _selected
	_rebuild()
	_select(keep)


func _start_recording() -> void:
	_recording.clear()
	_pad.recording = true
	_show_pad_info("pen", "1/%d" % Grimoire.SIGN_SAMPLES, UiKit.ACCENT)


func _show_pad_info(icon: String, text: String, color: Color, glyph_id: String = "") -> void:
	for c in _pad_info.get_children():
		c.queue_free()
	if glyph_id != "":
		var g := GlyphView.new()
		g.custom_minimum_size = Vector2(90, 90)
		g.show_mantra(glyph_id)
		_pad_info.add_child(g)
	elif icon != "":
		var v := UiKit.IconView.new()
		v.icon = icon
		v.color = color
		v.custom_minimum_size = Vector2(64, 64)
		_pad_info.add_child(v)
	if text != "":
		var l := UiKit.label(text, 24, color, 4)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pad_info.add_child(l)


func _on_pad_stroke(points: PackedVector2Array) -> void:
	if _pad.recording:
		_recording.append(points)
		if _recording.size() < Grimoire.SIGN_SAMPLES:
			_show_pad_info("pen", "%d/%d" % [_recording.size() + 1, Grimoire.SIGN_SAMPLES], UiKit.ACCENT)
			return
		_pad.recording = false
		var problem := Game.grimoire.validate_sign(_selected, _recording, Game.gesture_min_score())
		if problem != "":
			# The reason in a few words; the full sentence is in the log for us.
			GameLog.info("book", "sign rejected", {"id": _selected, "why": problem})
			_show_pad_info("close", problem.get_slice(".", 0), UiKit.DANGER)
			_recording.clear()
			return
		Game.set_custom_sign(_selected, _recording)
		var saved := _selected
		_refresh()
		_show_pad_info("check", "", UiKit.ACCENT, saved)
		Sfx.play("mantra_learned")
		return
	var result := _recognizer.recognize(points)
	var id := Game.grimoire.mantra_for(str(result["name"]))
	var score := int(round(float(result["score"]) * 100.0))
	if id != "":
		_show_pad_info("", "%d%%" % score, UiKit.ACCENT if Game.grimoire.is_learned(id) else UiKit.MUTED, id)
		Sfx.play("cast_" + id)
	elif str(result["closest"]) != "" and score > 0:
		_show_pad_info("question", "%d%%" % score, UiKit.MUTED)
		Sfx.play("cast_fail")
	else:
		_show_pad_info("question", "", UiKit.MUTED)


## A box to draw in. Uses mouse events, which touches are converted to.
class PracticePad extends Control:
	signal stroke_done(points: PackedVector2Array)

	var recording := false:
		set(value):
			recording = value
			queue_redraw()

	var _stroke := PackedVector2Array()
	var _last := PackedVector2Array()
	var _drawing := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drawing = true
				_stroke = PackedVector2Array([event.position])
			elif _drawing:
				_drawing = false
				_last = _stroke
				_stroke = PackedVector2Array()
				stroke_done.emit(_last)
			queue_redraw()
			accept_event()
		elif event is InputEventMouseMotion and _drawing:
			if _stroke[_stroke.size() - 1].distance_to(event.position) >= 3.0:
				_stroke.append(event.position)
				queue_redraw()
			accept_event()

	func _draw() -> void:
		var border := UiKit.ACCENT if recording else Color(UiKit.ACCENT, 0.35)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.05, 0.4))
		draw_rect(Rect2(Vector2.ZERO, size), border, false, 2.0)
		if _last.size() >= 2 and not _drawing:
			draw_polyline(_last, Color(0.75, 1.0, 0.92, 0.35), 5.0, true)
		if _stroke.size() >= 2:
			draw_polyline(_stroke, Color(0.75, 1.0, 0.92), 6.0, true)
