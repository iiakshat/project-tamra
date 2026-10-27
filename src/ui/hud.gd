class_name Hud
extends CanvasLayer
## In-level UI, mostly icons: life lamps, prana, light, mantra slots, tutorial glyphs,
## cast feedback, the new-mantra popup, vow chips, pause, settings and results.
## Keeps working while the game is paused.

signal pause_pressed
signal resume_pressed
signal restart_pressed
signal menu_pressed
signal next_pressed
signal copy_log_pressed

const TRIAL_ICONS := {"frail": "heart", "thin_prana": "prana", "fierce": "skull"}

var caster: MantraCaster
var mantra_cfg: Dictionary

var _root: Control
var _hearts: HeartsView
var _prana: PranaBar
var _ember_label: Label
var _slots: Array[SlotView] = []
var _slot_row: HBoxContainer
var _prompt: PanelContainer
var _prompt_label: Label
var _prompt_glyph: GlyphView
var _toast: Label
var _toast_icon: UiKit.IconView
var _toast_tween: Tween
var _chip: PanelContainer
var _pause_button: Button
var _overlay: Control
var _popup: Control
var _popup_queue: Array[String] = []
var _book: MantraBook
var _flash: ColorRect
var _tint: ColorRect
var _error_badge: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = UiKit.full_rect(Control.new())
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_tint = UiKit.full_rect(ColorRect.new()) as ColorRect
	_tint.color = Color(0.3, 0.9, 1.0, 0.0)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tint)
	_flash = UiKit.full_rect(ColorRect.new()) as ColorRect
	_flash.color = Color(0.7, 0.05, 0.2, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	# Status plate, top-left: hearts, prana, light gathered. Clear of the touch pads.
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiKit.frame_style(0.3, 4))
	plate.position = Vector2(12, 10)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_root.add_child(plate)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(stack)
	_hearts = HeartsView.new()
	_hearts.custom_minimum_size = Vector2(196, 44)
	stack.add_child(_hearts)
	_prana = PranaBar.new()
	_prana.custom_minimum_size = Vector2(196, 26)
	stack.add_child(_prana)
	var ember_row := UiKit.stat("jyoti", "0", UiKit.JYOTI, 20)
	ember_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_ember_label = ember_row.get_child(1)
	UiKit.glint(ember_row.get_child(0), 4.0)
	stack.add_child(ember_row)

	_error_badge = UiKit.label("", 16, UiKit.DANGER, 4)
	_error_badge.position = Vector2(24, 150)
	_error_badge.visible = false
	_root.add_child(_error_badge)

	_pause_button = UiKit.icon_button("pause", 64)
	_pause_button.anchor_left = 1.0
	_pause_button.anchor_right = 1.0
	_pause_button.offset_left = -84
	_pause_button.offset_right = -20
	_pause_button.offset_top = 14
	_pause_button.offset_bottom = 78
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_root.add_child(_pause_button)

	_slot_row = HBoxContainer.new()
	_slot_row.anchor_left = 1.0
	_slot_row.anchor_right = 1.0
	_slot_row.offset_right = -98
	_slot_row.offset_left = -98
	_slot_row.offset_top = 18
	_slot_row.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_slot_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_slot_row.add_theme_constant_override("separation", 8)
	_slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_slot_row)

	_build_prompt()
	_build_toast()
	_build_chip()
	Game.mantras_changed.connect(refresh_slots)
	Game.vow_completed.connect(_on_vow_completed)


func setup(mantra_caster: MantraCaster, mantras: Dictionary) -> void:
	caster = mantra_caster
	mantra_cfg = mantras
	refresh_slots()


## One slot per learned mantra, showing the sign that currently casts it.
func refresh_slots() -> void:
	for slot in _slots:
		slot.queue_free()
	_slots.clear()
	for id in Game.grimoire.ids():
		if not Game.grimoire.is_learned(id):
			continue
		var m: Dictionary = mantra_cfg.get(id, {})
		var slot := SlotView.new()
		slot.id = id
		slot.glyph = str(m.get("gesture", ""))
		var strokes := Game.save.sign_strokes(id)
		slot.custom = strokes[0] if not strokes.is_empty() else PackedVector2Array()
		slot.color = GameConfig.color(m.get("color", ""), UiKit.ACCENT)
		slot.custom_minimum_size = Vector2(56, 56)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slot_row.add_child(slot)
		_slots.append(slot)


func _process(_delta: float) -> void:
	if OS.is_debug_build() and GameLog.error_count > 0:
		_error_badge.visible = true
		_error_badge.text = "%d error(s) - pause > log" % GameLog.error_count
	if caster == null:
		return
	var prana := _prana.value
	for slot in _slots:
		var r := caster.cooldown_ratio(slot.id)
		var starved := prana < float(Game.grimoire.prana_cost(slot.id))
		if not is_equal_approx(r, slot.ratio) or starved != slot.starved:
			slot.ratio = r
			slot.starved = starved
			slot.queue_redraw()


## True where a touch belongs to the HUD instead of gameplay.
func blocks(pos: Vector2) -> bool:
	if (_overlay != null and _overlay.visible) or _book != null or _popup != null:
		return true
	return _pause_button.get_global_rect().grow(10).has_point(pos)


func set_hearts(hearts: int, max_hearts: int) -> void:
	_hearts.hearts = hearts
	_hearts.max_hearts = max_hearts
	_hearts.queue_redraw()


## A heart lost (-1) or healed (+1): the heart itself bursts or swells, the row shakes,
## and the screen edge flashes, so a hit can never go unnoticed.
func on_heart_delta(delta: int) -> void:
	_hearts.animate(delta)
	if delta < 0:
		_flash.color = Color(0.7, 0.05, 0.2, 0.3)
		create_tween().tween_property(_flash, "color:a", 0.0, 0.45)
	else:
		_flash.color = Color(1.0, 0.55, 0.65, 0.18)
		create_tween().tween_property(_flash, "color:a", 0.0, 0.6)


## Every heart is gone: a dark band with three empty hearts and two words, held for a
## moment before the level starts over.
func show_lives_lost() -> void:
	var band := ColorRect.new()
	band.color = Color(0.02, 0.01, 0.05, 0.0)
	UiKit.full_rect(band)
	band.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(band)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	UiKit.full_rect(box)
	box.add_theme_constant_override("separation", 12)
	band.add_child(box)
	var row := HeartsView.new()
	row.hearts = 0
	row.max_hearts = _hearts.max_hearts
	row.big = true
	row.custom_minimum_size = Vector2(row.max_hearts * 80.0, 80)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(row)
	var text := UiKit.title("Lives lost", 52, UiKit.DANGER, 8)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	box.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(band, "color:a", 0.72, 0.35)
	t.parallel().tween_property(box, "modulate:a", 1.0, 0.35)
	row.animate(-1)


func set_prana(value: float, max_value: float) -> void:
	_prana.value = value
	_prana.max_value = max_value
	_prana.queue_redraw()


func set_embers(count: int, total: int) -> void:
	_ember_label.text = "%d/%d" % [count, total]


## Banner for the daily trial's twist.
func show_trial(mod: String) -> void:
	_show_chip(TRIAL_ICONS.get(mod, "trial"), UiKit.DANGER, 4.0)


func show_prompt(text: String, glyph: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = text != ""
	var id := Game.grimoire.mantra_with_default(glyph)
	if id != "":
		_prompt_glyph.show_mantra(id)
	else:
		_prompt_glyph.custom = PackedVector2Array()
		_prompt_glyph.glyph = glyph
	_prompt_glyph.visible = glyph != ""
	_prompt.visible = true
	_prompt.modulate.a = 0.0
	create_tween().tween_property(_prompt, "modulate:a", 1.0, 0.25)


func hide_prompt() -> void:
	var t := create_tween()
	t.tween_property(_prompt, "modulate:a", 0.0, 0.3)
	t.tween_callback(func() -> void: _prompt.visible = false)


## New mantras appear one at a time in a popup that pauses play until tapped.
func show_learned(ids: Array[String]) -> void:
	_popup_queue.append_array(ids)
	if _popup == null:
		_next_popup()


func on_cast(id: String) -> void:
	var m: Dictionary = mantra_cfg.get(id, {})
	_show_toast(str(m.get("label", id.to_upper())), GameConfig.color(m.get("color", ""), UiKit.ACCENT), "")


func on_cast_failed(reason: String, _detail: String) -> void:
	match reason:
		"unrecognized", "unknown":
			_show_toast("", UiKit.MUTED, "question")
		"locked":
			_show_toast("", UiKit.MUTED, "lock")
			Sfx.play("cast_fail")
		"cooldown":
			_show_toast("", UiKit.MUTED, "hourglass")
		"prana":
			_prana.flash()
			_show_toast("", UiKit.DANGER, "prana")
			Sfx.play("cast_fail")
		"far":
			_show_toast("", UiKit.MUTED, "close")


## Short confirmation message in the middle of the screen.
func notify(text: String) -> void:
	_show_toast(text, UiKit.TEXT, "")


func flash_death() -> void:
	_flash.color.a = 0.45
	create_tween().tween_property(_flash, "color:a", 0.0, 0.7)


func set_maya_tint(on: bool) -> void:
	create_tween().tween_property(_tint, "color:a", 0.12 if on else 0.0, 0.3)


func show_pause(on: bool) -> void:
	_clear_overlay()
	if not on:
		return
	var box := _overlay_box()
	var title := UiKit.title("Paused", 46, UiKit.TEXT, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var resume := UiKit.pill("Resume", "play", "jade", 76, 280)
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	box.add_child(resume)
	var row := _icon_row()
	row.add_child(UiKit.labeled(_icon("restart", restart_pressed, 72), "Restart"))
	var book := UiKit.icon_button("book", 72)
	book.pressed.connect(open_book)
	row.add_child(UiKit.labeled(book, "Mantras"))
	var gear := UiKit.icon_button("gear", 72)
	gear.pressed.connect(_open_settings)
	row.add_child(UiKit.labeled(gear, "Settings"))
	row.add_child(UiKit.labeled(_icon("home", menu_pressed, 72), "Menu"))
	box.add_child(row)


## outcome: from Game.complete_level.
## `has_next` shows the Next pill (on the very last level it leads to the ending card).
func show_results(outcome: Dictionary, time: float, embers: int, total: int, deaths: int, has_next: bool) -> void:
	_clear_overlay()
	var box := _overlay_box()
	var title := UiKit.title("Cleared!", 46, UiKit.TEXT, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var stars := _icon_row()
	stars.add_theme_constant_override("separation", 8)
	for i in 3:
		var view := UiKit.IconView.new()
		view.custom_minimum_size = Vector2(76, 76)
		var lit := i < int(outcome.get("stars", 1))
		view.icon = "star" if lit else "star_empty"
		view.color = UiKit.STAR if lit else Color(UiKit.TEXT, 0.5)
		view.pivot_offset = Vector2(38, 38)
		view.scale = Vector2.ZERO
		stars.add_child(view)
		var t := view.create_tween()
		t.tween_interval(0.25 + i * 0.25)
		t.tween_property(view, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i < int(outcome.get("stars", 1)):
			t.tween_callback(func() -> void: Sfx.play("ember_pickup"))
	box.add_child(stars)
	var stats := _icon_row()
	stats.add_theme_constant_override("separation", 34)
	stats.add_child(UiKit.stat("clock", UiKit.format_time(time), UiKit.TEXT, 26))
	stats.add_child(UiKit.stat("jyoti", "%d/%d" % [embers, total], UiKit.JYOTI, 26))
	stats.add_child(UiKit.stat("skull", str(deaths), UiKit.MUTED, 26))
	box.add_child(stats)
	var gained := int(outcome.get("banked", 0)) + int(outcome.get("trial_reward", 0))
	if gained > 0:
		box.add_child(UiKit.stat("jyoti", "+%d" % gained, UiKit.ACCENT, 26))
	var buyable: Array = outcome.get("buyable", [])
	if not buyable.is_empty():
		var row := _icon_row()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UiKit.stat("book", "Can learn:", UiKit.TEXT, 20))
		for id in buyable:
			var g := GlyphView.new()
			g.custom_minimum_size = Vector2(56, 56)
			g.show_mantra(str(id))
			row.add_child(g)
		box.add_child(row)
	if has_next:
		var next := UiKit.pill("Next", "next", "red", 76, 260)
		next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next.pressed.connect(func() -> void: next_pressed.emit())
		UiKit.pulse(next, 0.035, 1.6)
		box.add_child(next)
	var buttons := _icon_row()
	buttons.add_child(UiKit.labeled(_icon("restart", restart_pressed, 68), "Again"))
	var book := UiKit.icon_button("book", 68)
	book.pressed.connect(open_book)
	buttons.add_child(UiKit.labeled(book, "Mantras"))
	buttons.add_child(UiKit.labeled(_icon("home", menu_pressed, 68), "Menu"))
	box.add_child(buttons)


func open_book() -> void:
	if _book != null:
		return
	_book = MantraBook.new()
	UiKit.full_rect(_book)
	_root.add_child(_book)
	_book.closed.connect(func() -> void:
		_book.queue_free()
		_book = null
	)


func _open_settings() -> void:
	var holder := UiKit.full_rect(CenterContainer.new())
	var panel := SettingsPanel.new()
	holder.add_child(panel)
	_root.add_child(holder)
	panel.closed.connect(holder.queue_free)


func _next_popup() -> void:
	if _popup != null:
		_popup.queue_free()
		_popup = null
	if _popup_queue.is_empty():
		get_tree().paused = false
		return
	var id: String = _popup_queue.pop_front()
	var m: Dictionary = mantra_cfg.get(id, {})
	var color := GameConfig.color(m.get("color", ""), UiKit.ACCENT)
	get_tree().paused = true
	_popup = UiKit.full_rect(Control.new())
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := UiKit.full_rect(ColorRect.new()) as ColorRect
	dim.color = Color(0.01, 0.0, 0.04, 0.75)
	_popup.add_child(dim)
	var center := UiKit.full_rect(CenterContainer.new())
	_popup.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	center.add_child(col)
	var halo := Control.new()
	halo.custom_minimum_size = Vector2(260, 260)
	var disc := Disc.new()
	disc.color = Color(color, 0.16)
	UiKit.full_rect(disc)
	halo.add_child(disc)
	var glyph := GlyphView.new()
	glyph.animate = true
	glyph.line_width = 8.0
	glyph.show_mantra(id)
	UiKit.full_rect(glyph)
	halo.add_child(glyph)
	col.add_child(halo)
	var name := UiKit.label(str(m.get("label", id)), 52, color, 10)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name)
	var meaning := UiKit.label(str(m.get("meaning", "")), 22, UiKit.MUTED, 4)
	meaning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(meaning)
	var ok := UiKit.pill("Got it", "check", "jade", 64, 200)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_next_popup)
	col.add_child(ok)
	_root.add_child(_popup)
	Sfx.play("mantra_learned")
	Sfx.play("call_" + id)


func _on_vow_completed(_vow: Dictionary) -> void:
	_show_chip("vow", UiKit.ACCENT, 2.2)
	Sfx.play("checkpoint")


func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", UiKit.panel_style(0.7))
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.offset_left = -260
	_prompt.offset_right = 260
	_prompt.offset_top = 96
	_prompt.offset_bottom = 112
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_prompt_glyph = GlyphView.new()
	_prompt_glyph.custom_minimum_size = Vector2(96, 96)
	_prompt_glyph.animate = true
	row.add_child(_prompt_glyph)
	_prompt_label = UiKit.label("", 26, UiKit.TEXT, 4)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.custom_minimum_size = Vector2(300, 0)
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_prompt_label)
	_prompt.add_child(row)
	_root.add_child(_prompt)


func _build_toast() -> void:
	_toast = UiKit.label("", 52, UiKit.ACCENT, 10)
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = -90
	_toast.offset_bottom = -30
	_toast.modulate.a = 0.0
	_root.add_child(_toast)
	_toast_icon = UiKit.IconView.new()
	_toast_icon.set_anchors_preset(Control.PRESET_CENTER)
	_toast_icon.offset_left = -40
	_toast_icon.offset_right = 40
	_toast_icon.offset_top = -110
	_toast_icon.offset_bottom = -30
	_toast_icon.pivot_offset = Vector2(40, 40)
	_toast_icon.modulate.a = 0.0
	_toast_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_icon)


func _build_chip() -> void:
	_chip = PanelContainer.new()
	var style := UiKit.panel_style(0.85)
	style.set_corner_radius_all(30)
	style.set_content_margin_all(10)
	_chip.add_theme_stylebox_override("panel", style)
	_chip.anchor_left = 0.5
	_chip.anchor_right = 0.5
	_chip.offset_left = -40
	_chip.offset_right = 40
	_chip.offset_top = 20
	_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var a := UiKit.IconView.new()
	a.custom_minimum_size = Vector2(44, 44)
	row.add_child(a)
	var b := UiKit.IconView.new()
	b.custom_minimum_size = Vector2(44, 44)
	b.icon = "check"
	row.add_child(b)
	_chip.add_child(row)
	_root.add_child(_chip)


func _show_chip(icon: String, color: Color, seconds: float) -> void:
	var row := _chip.get_child(0)
	var a: UiKit.IconView = row.get_child(0)
	var b: UiKit.IconView = row.get_child(1)
	a.icon = icon
	a.color = color
	b.color = color
	b.visible = icon == "vow"
	_chip.visible = true
	_chip.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(seconds)
	t.tween_property(_chip, "modulate:a", 0.0, 0.4)
	t.tween_callback(func() -> void: _chip.visible = false)


func _show_toast(text: String, color: Color, icon: String) -> void:
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.pivot_offset = _toast.size / 2.0
	_toast.modulate.a = 1.0 if text != "" else 0.0
	_toast.scale = Vector2.ONE * 1.25
	_toast_icon.icon = icon
	_toast_icon.color = color
	_toast_icon.modulate.a = 1.0 if icon != "" else 0.0
	_toast_icon.scale = Vector2.ONE * 1.3
	_toast_tween = create_tween().set_parallel()
	_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.2)
	_toast_tween.tween_property(_toast_icon, "scale", Vector2.ONE, 0.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5).set_delay(0.9)
	_toast_tween.tween_property(_toast_icon, "modulate:a", 0.0, 0.5).set_delay(0.7)


func _overlay_box() -> VBoxContainer:
	_overlay = UiKit.full_rect(Control.new())
	var dim := UiKit.full_rect(ColorRect.new()) as ColorRect
	dim.color = Color(0.01, 0.0, 0.04, 0.62)
	_overlay.add_child(dim)
	var center := UiKit.full_rect(CenterContainer.new())
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.frame_style(0.6, 12))
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(440, 0)
	panel.add_child(box)
	_root.add_child(_overlay)
	UiKit.pop_in(panel)
	if _book != null:
		_root.move_child(_book, -1)
	return box


func _icon_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	return row


func _icon(icon: String, sig: Signal, diameter: float = 96.0, color: Color = UiKit.TEXT) -> Button:
	var b := UiKit.icon_button(icon, diameter, color)
	b.pressed.connect(func() -> void: sig.emit())
	return b


func _clear_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


## Life as hearts: lit ones are solid crimson and beat faintly; spent ones are empty
## crimson-rimmed shells, clearly still there (round 5: the owner could not see the old
## dark shells, so a lost heart looked like nothing had happened). A lost heart bursts
## and the row shakes; a healed one swells in.
class HeartsView extends Control:
	var hearts := 3
	var max_hearts := 3
	var big := false
	var _t := 0.0
	var _anim := 0.0  # 1 -> 0 after a change
	var _anim_dir := 0
	var _anim_slot := -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func animate(delta: int) -> void:
		_anim = 1.0
		_anim_dir = delta
		_anim_slot = hearts if delta < 0 else hearts - 1

	func _process(delta: float) -> void:
		_t += delta
		_anim = maxf(0.0, _anim - delta * 1.6)
		queue_redraw()

	func _draw() -> void:
		var r := 30.0 if big else 18.0
		var step := r * 2.3
		var shake := Vector2.ZERO
		if _anim_dir < 0 and _anim > 0.4:
			shake.x = sin(_t * 70.0) * 5.0 * _anim
		for i in max_hearts:
			var c := Vector2(r + 2.0 + i * step, size.y / 2.0) + shake
			var k := 1.0
			if i == _anim_slot and _anim > 0.0 and _anim_dir > 0:
				k = 1.0 + 0.5 * _anim
			if i < hearts:
				var f := maxf(0.0, sin(_t * 4.2 + i * 1.3))
				Icons.draw(self, "heart", c, (r + 2.0) * k, Color(0.02, 0.01, 0.05, 0.95))
				Icons.draw(self, "heart", c, (r - 1.0 + f * 1.0) * k, UiKit.DANGER)
			else:
				Icons.draw(self, "heart", c, r + 2.0, Color(0.02, 0.01, 0.05, 0.95))
				Icons.draw(self, "heart", c, r - 1.0, Color(UiKit.DANGER, 0.85))
				Icons.draw(self, "heart", c, r - 5.0, Color(0.1, 0.06, 0.14))
				if i == _anim_slot and _anim > 0.0 and _anim_dir < 0:
					# The lost heart flies apart: a swelling crimson ghost fading out.
					Icons.draw(self, "heart", c - shake, r * (1.0 + 1.2 * (1.0 - _anim)), Color(UiKit.DANGER, _anim * 0.8))


## The prana meter: a lotus and a copper-rimmed bar with a shimmer running through it;
## it flashes crimson when a cast is short of prana.
class PranaBar extends Control:
	var value := 100.0
	var max_value := 100.0
	var _flash := 0.0
	var _t := 0.0
	var _frame: StyleBoxFlat
	var _fill: StyleBoxFlat

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_frame = StyleBoxFlat.new()
		_frame.bg_color = Color(0.02, 0.02, 0.07, 0.9)
		_frame.border_color = UiKit.COPPER
		_frame.set_border_width_all(2)
		_frame.set_corner_radius_all(8)
		_fill = StyleBoxFlat.new()
		_fill.set_corner_radius_all(6)

	func flash() -> void:
		_flash = 1.0

	func _process(delta: float) -> void:
		_t += delta
		_flash = maxf(0.0, _flash - delta * 2.0)
		queue_redraw()

	func _draw() -> void:
		Icons.draw(self, "prana", Vector2(13, size.y / 2.0), 13.0, Color(0.5, 1.0, 0.85))
		var r := Rect2(32, size.y / 2.0 - 8.0, size.x - 34, 16)
		draw_style_box(_frame, r)
		var k := clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
		var inner := r.grow(-3.0)
		if k <= 0.0:
			return
		var w := inner.size.x * k
		_fill.bg_color = Color(0.35, 0.95, 0.8).lerp(UiKit.DANGER, _flash)
		draw_style_box(_fill, Rect2(inner.position, Vector2(maxf(w, 8.0), inner.size.y)))
		# Shimmer: a pale band sweeping along the filled part every few seconds.
		var x := fposmod(_t * 0.5, 1.4) * inner.size.x - 20.0
		var a := clampf(x, 0.0, w)
		var b := clampf(x + 18.0, 0.0, w)
		if b > a:
			draw_rect(Rect2(inner.position + Vector2(a, 2), Vector2(b - a, inner.size.y - 4)), Color(1, 1, 1, 0.35))


## A flat disc behind the new-mantra glyph.
class Disc extends Control:
	var color := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size / 2.0, minf(size.x, size.y) * 0.46, color)
		draw_arc(size / 2.0, minf(size.x, size.y) * 0.46, 0.0, TAU, 64, Color(color, 0.5), 2.0, true)


## A learned mantra in a copper medallion: its sign, a dark sweep while it recharges,
## dimmed if prana is short.
class SlotView extends Control:
	var id := ""
	var glyph := ""
	var custom := PackedVector2Array()
	var color := Color.WHITE
	var ratio := 0.0
	var starved := false

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.5
		var ready := ratio <= 0.0 and not starved
		draw_texture_rect(UiKit.ROUND_TEX, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color.WHITE if ready else Color(0.6, 0.6, 0.66))
		var inner := r * 0.7
		var src := custom if not custom.is_empty() else GlyphShapes.canonical(glyph)
		if src.size() >= 2:
			var box := Rect2(src[0], Vector2.ZERO)
			for p in src:
				box = box.expand(p)
			var half := maxf(maxf(box.size.x, box.size.y) / 2.0, 0.001)
			var pts := PackedVector2Array()
			for p in src:
				pts.append(c + (p - box.get_center()) / half * inner * 0.68)
			draw_polyline(pts, Color(color, 1.0 if ready else 0.35), 2.6, true)
		if ratio > 0.01:
			var pie := PackedVector2Array([c])
			var steps := maxi(2, int(ratio * 32))
			for i in steps + 1:
				pie.append(c + Vector2.from_angle(-PI / 2.0 + TAU * ratio * i / steps) * inner)
			draw_colored_polygon(pie, Color(0, 0, 0, 0.55))
