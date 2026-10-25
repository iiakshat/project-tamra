class_name MantraBook
extends Control
## The Mantra Book: every mantra, what it does, how to unlock it, a practice pad to try
## signs, and a recorder for the player's own sign. Works over the menu or a paused level.

signal closed

var _list: VBoxContainer
var _bank_label: Label
var _title: Label
var _meaning: Label
var _desc: Label
var _status: Label
var _glyph: GlyphView
var _actions: HBoxContainer
var _pad: PracticePad
var _pad_label: Label
var _selected := ""
var _recording: Array[PackedVector2Array] = []
var _recognizer: GestureRecognizer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := UiKit.full_rect(ColorRect.new()) as ColorRect
	dim.color = Color(0.02, 0.0, 0.01, 0.82)
	add_child(dim)

	var margin := UiKit.full_rect(MarginContainer.new())
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(0.94))
	margin.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	var title := UiKit.label("MANTRA BOOK", 34, UiKit.GOLD, 6)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_bank_label = UiKit.label("", 24, Color(1.0, 0.7, 0.35), 4)
	header.add_child(_bank_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(24, 0)
	header.add_child(spacer)
	var close := UiKit.button("Close", 150)
	close.custom_minimum_size = Vector2(150, 56)
	close.pressed.connect(func() -> void: closed.emit())
	header.add_child(close)
	outer.add_child(header)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	outer.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 0)
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
	_glyph.custom_minimum_size = Vector2(120, 120)
	_glyph.animate = true
	_glyph.line_width = 5.0
	top.add_child(_glyph)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = UiKit.label("", 40, UiKit.GOLD, 6)
	names.add_child(_title)
	_meaning = UiKit.label("", 22, Color(1.0, 0.85, 0.6, 0.8), 4)
	names.add_child(_meaning)
	_status = UiKit.label("", 20, UiKit.TEXT, 4)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(_status)
	top.add_child(names)
	_desc = UiKit.label("", 22, UiKit.TEXT, 4)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(400, 0)
	detail.add_child(_desc)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 10)
	detail.add_child(_actions)

	var pad_row := HBoxContainer.new()
	pad_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad_row.add_theme_constant_override("separation", 14)
	detail.add_child(pad_row)
	_pad = PracticePad.new()
	_pad.custom_minimum_size = Vector2(300, 180)
	_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pad.stroke_done.connect(_on_pad_stroke)
	pad_row.add_child(_pad)
	_pad_label = UiKit.label("", 20, UiKit.TEXT, 4)
	_pad_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pad_label.custom_minimum_size = Vector2(220, 0)
	_pad_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pad_row.add_child(_pad_label)

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
	_bank_label.text = "%d embers" % Game.save.embers_bank
	for c in _list.get_children():
		c.queue_free()
	for id in Game.grimoire.ids():
		var m: Dictionary = Game.mantra_cfg[id]
		var state := str(Game.grimoire.state(id)["state"])
		var entry := UiKit.button("", 320)
		entry.custom_minimum_size = Vector2(320, 62)
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tag: String = {"learned": "", "buyable": "  (unlock)", "locked": "  (locked)"}[state]
		entry.text = "          %s%s" % [m.get("label", id), tag]
		entry.modulate = Color.WHITE if state != "locked" else Color(1, 1, 1, 0.55)
		var icon := GlyphView.new()
		icon.custom_minimum_size = Vector2(44, 44)
		icon.position = Vector2(8, 9)
		icon.size = Vector2(44, 44)
		icon.line_width = 2.5
		icon.show_mantra(id)
		entry.add_child(icon)
		entry.pressed.connect(_select.bind(id))
		_list.add_child(entry)


func _select(id: String) -> void:
	_selected = id
	_recording.clear()
	_pad.recording = false
	var m: Dictionary = Game.mantra_cfg[id]
	var s := Game.grimoire.state(id)
	_glyph.show_mantra(id)
	_title.text = str(m.get("label", id))
	_title.add_theme_color_override("font_color", GameConfig.color(m.get("color", ""), UiKit.GOLD))
	_meaning.text = str(m.get("meaning", "")).to_upper() + "   |   recharges in %s s" % str(m.get("cooldown", "?"))
	_desc.text = str(m.get("description", ""))
	for c in _actions.get_children():
		c.queue_free()
	match str(s["state"]):
		"learned":
			_status.text = "Learned. " + ("Cast with your own sign." if Game.grimoire.has_custom_sign(id) else "Cast with the sign shown.")
			if GlyphShapes.SHAPES.has(str(m.get("gesture", ""))) or Game.grimoire.has_custom_sign(id):
				var own := UiKit.button("Draw my own sign", 280)
				own.pressed.connect(_start_recording)
				_actions.add_child(own)
			if Game.grimoire.has_custom_sign(id):
				var reset := UiKit.button("Use original sign", 260)
				reset.pressed.connect(func() -> void:
					Game.clear_custom_sign(_selected)
					_refresh()
				)
				_actions.add_child(reset)
		"buyable":
			var cost := int(s["cost"])
			_status.text = "Can be unlocked with embers you have collected."
			var buy := UiKit.button("Unlock for %d embers" % cost, 320)
			buy.disabled = not Game.grimoire.can_afford(id)
			buy.pressed.connect(func() -> void:
				if Game.buy_mantra(_selected):
					Sfx.play("mantra_learned")
					_refresh()
			)
			_actions.add_child(buy)
			if not Game.grimoire.can_afford(id):
				_status.text = "Needs %d embers. You have %d. Collect more embers in levels." % [cost, Game.save.embers_bank]
		_:
			if str(s["level"]) != "":
				_status.text = "Learned in the story: %s." % Game.level_name(str(s["level"]))
			else:
				_status.text = "Finish %s to unlock it with embers (%d)." % [Game.level_name(str(s["after"])), int(s["cost"])]
	_pad_label.text = "Practice: draw any sign in the box to see what it casts."


func _refresh() -> void:
	var keep := _selected
	_rebuild()
	_select(keep)


func _start_recording() -> void:
	_recording.clear()
	_pad.recording = true
	_pad_label.text = "Draw your new sign for %s in the box. 1 of %d." % [Game.mantra_cfg[_selected].get("label", ""), Grimoire.SIGN_SAMPLES]


func _on_pad_stroke(points: PackedVector2Array) -> void:
	if _pad.recording:
		_recording.append(points)
		if _recording.size() < Grimoire.SIGN_SAMPLES:
			_pad_label.text = "Again, the same way. %d of %d." % [_recording.size() + 1, Grimoire.SIGN_SAMPLES]
			return
		_pad.recording = false
		var problem := Game.grimoire.validate_sign(_selected, _recording, Game.gesture_min_score())
		if problem != "":
			_pad_label.text = problem + " Tap 'Draw my own sign' to try again."
			_recording.clear()
			return
		Game.set_custom_sign(_selected, _recording)
		var label := str(Game.mantra_cfg[_selected].get("label", ""))
		_refresh()
		_pad_label.text = "Saved. Your sign now casts %s." % label
		Sfx.play("mantra_learned")
		return
	var result := _recognizer.recognize(points)
	var id := Game.grimoire.mantra_for(str(result["name"]))
	var score := int(round(float(result["score"]) * 100.0))
	if id != "":
		var known := "" if Game.grimoire.is_learned(id) else " (not learned yet)"
		_pad_label.text = "%s%s\nclarity %d%%" % [Game.mantra_cfg[id].get("label", id), known, score]
		Sfx.play("cast_" + id)
	elif str(result["closest"]) != "" and score > 0:
		var near := Game.grimoire.mantra_for(str(result["closest"]))
		_pad_label.text = "Unclear (clarity %d%%).%s" % [score,
			(" Closest: %s." % Game.mantra_cfg[near].get("label", near)) if near != "" else ""]
		Sfx.play("cast_fail")
	else:
		_pad_label.text = "Draw a larger sign."


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
		var border := UiKit.GOLD if recording else Color(UiKit.GOLD, 0.4)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.35))
		draw_rect(Rect2(Vector2.ZERO, size), border, false, 2.0)
		if _last.size() >= 2 and not _drawing:
			draw_polyline(_last, Color(1.0, 0.8, 0.45, 0.35), 5.0, true)
		if _stroke.size() >= 2:
			draw_polyline(_stroke, Color(1.0, 0.85, 0.5), 6.0, true)
