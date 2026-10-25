class_name Hud
extends CanvasLayer
## In-level UI: lamps for health, embers, mantra slots with cooldowns, tutorial
## prompts, cast feedback, pause and results. Keeps working while the game is paused.

signal pause_pressed
signal resume_pressed
signal restart_pressed
signal menu_pressed
signal next_pressed
signal copy_log_pressed

const FAIL_TEXT := {
	"unrecognized": "The sign was unclear",
	"locked": "You have not learned that mantra yet",
	"cooldown": "Not ready yet",
}

var caster: MantraCaster
var mantra_cfg: Dictionary

var _root: Control
var _hearts: HeartsView
var _ember_label: Label
var _slots: Array[SlotView] = []
var _slot_row: HBoxContainer
var _prompt: PanelContainer
var _prompt_label: Label
var _prompt_glyph: GlyphView
var _toast: Label
var _toast_tween: Tween
var _pause_button: Button
var _overlay: Control
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
	_flash.color = Color(0.7, 0.08, 0.04, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	_hearts = HeartsView.new()
	_hearts.position = Vector2(20, 14)
	_hearts.size = Vector2(200, 60)
	_root.add_child(_hearts)

	var ember_row := HBoxContainer.new()
	ember_row.position = Vector2(30, 76)
	ember_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ember_icon := TextureRect.new()
	ember_icon.texture = Fx.glow_texture()
	ember_icon.custom_minimum_size = Vector2(30, 30)
	ember_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ember_icon.modulate = Color(1.0, 0.6, 0.25)
	ember_row.add_child(ember_icon)
	_ember_label = UiKit.label("0", 24)
	ember_row.add_child(_ember_label)
	_root.add_child(ember_row)

	# Debug builds only: a visible count of logged errors, so testers notice and report.
	_error_badge = UiKit.label("", 18, Color(1.0, 0.35, 0.3), 4)
	_error_badge.position = Vector2(30, 112)
	_error_badge.visible = false
	_root.add_child(_error_badge)

	_pause_button = UiKit.button("II", 72)
	_pause_button.custom_minimum_size = Vector2(72, 72)
	_pause_button.anchor_left = 1.0
	_pause_button.anchor_right = 1.0
	_pause_button.offset_left = -96
	_pause_button.offset_right = -24
	_pause_button.offset_top = 18
	_pause_button.offset_bottom = 90
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_root.add_child(_pause_button)

	_slot_row = HBoxContainer.new()
	_slot_row.anchor_left = 1.0
	_slot_row.anchor_right = 1.0
	_slot_row.offset_right = -116
	_slot_row.offset_left = -116
	_slot_row.offset_top = 18
	_slot_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_slot_row.add_theme_constant_override("separation", 12)
	_slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_slot_row)

	_build_prompt()
	_toast = UiKit.label("", 44, UiKit.GOLD, 10)
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = -90
	_toast.offset_bottom = -30
	_toast.modulate.a = 0.0
	_root.add_child(_toast)


func setup(mantra_caster: MantraCaster, mantras: Dictionary, unlocked: Array[String]) -> void:
	caster = mantra_caster
	mantra_cfg = mantras
	for id in unlocked:
		var m: Dictionary = mantras.get(id, {})
		var slot := SlotView.new()
		slot.id = id
		slot.glyph = str(m.get("gesture", ""))
		slot.color = GameConfig.color(m.get("color", ""), UiKit.GOLD)
		slot.custom_minimum_size = Vector2(64, 64)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slot_row.add_child(slot)
		_slots.append(slot)


func _process(_delta: float) -> void:
	if OS.is_debug_build() and GameLog.error_count > 0:
		_error_badge.visible = true
		_error_badge.text = "%d error(s) logged. Pause > Copy debug log" % GameLog.error_count
	if caster == null:
		return
	for slot in _slots:
		var r := caster.cooldown_ratio(slot.id)
		if not is_equal_approx(r, slot.ratio):
			slot.ratio = r
			slot.queue_redraw()


## True where a touch belongs to the HUD instead of gameplay.
func blocks(pos: Vector2) -> bool:
	if _overlay != null and _overlay.visible:
		return true
	return _pause_button.get_global_rect().grow(10).has_point(pos)


func set_hearts(hearts: int, max_hearts: int) -> void:
	_hearts.hearts = hearts
	_hearts.max_hearts = max_hearts
	_hearts.queue_redraw()


func set_embers(count: int, total: int) -> void:
	_ember_label.text = "%d / %d" % [count, total]


func show_prompt(text: String, glyph: String) -> void:
	_prompt_label.text = text
	_prompt_glyph.glyph = glyph
	_prompt_glyph.visible = glyph != ""
	_prompt.visible = true
	_prompt.modulate.a = 0.0
	create_tween().tween_property(_prompt, "modulate:a", 1.0, 0.25)


func hide_prompt() -> void:
	var t := create_tween()
	t.tween_property(_prompt, "modulate:a", 0.0, 0.3)
	t.tween_callback(func() -> void: _prompt.visible = false)


func on_cast(id: String) -> void:
	var m: Dictionary = mantra_cfg.get(id, {})
	_show_toast(str(m.get("label", id.to_upper())), GameConfig.color(m.get("color", ""), UiKit.GOLD), 52)


func on_cast_failed(reason: String) -> void:
	_show_toast(FAIL_TEXT.get(reason, ""), Color(0.85, 0.8, 0.75), 28)


func flash_death() -> void:
	_flash.color.a = 0.5
	create_tween().tween_property(_flash, "color:a", 0.0, 0.7)


func set_maya_tint(on: bool) -> void:
	create_tween().tween_property(_tint, "color:a", 0.12 if on else 0.0, 0.3)


func show_pause(on: bool) -> void:
	_clear_overlay()
	if not on:
		return
	var box := _overlay_box("Paused")
	box.add_child(_button("Resume", resume_pressed))
	box.add_child(_button("Restart from checkpoint", restart_pressed))
	box.add_child(_button("Main menu", menu_pressed))
	box.add_child(_button("Copy debug log", copy_log_pressed))


## Short confirmation message in the middle of the screen.
func notify(text: String) -> void:
	_show_toast(text, UiKit.TEXT, 26)


func show_results(level_name: String, time: float, embers: int, total: int, has_next: bool) -> void:
	_clear_overlay()
	var box := _overlay_box(level_name)
	box.add_child(_centered(UiKit.label("Cleared in " + UiKit.format_time(time), 30)))
	box.add_child(_centered(UiKit.label("Embers  %d / %d" % [embers, total], 30, Color(1.0, 0.7, 0.35))))
	if has_next:
		box.add_child(_button("Continue", next_pressed))
	else:
		box.add_child(_centered(UiKit.label("More of the story is coming.", 24, Color(0.9, 0.85, 0.8))))
	box.add_child(_button("Play again", restart_pressed))
	box.add_child(_button("Main menu", menu_pressed))


func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", UiKit.panel_style(0.72))
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.offset_left = -380
	_prompt.offset_right = 380
	_prompt.offset_top = 104
	_prompt.offset_bottom = 120
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_prompt_glyph = GlyphView.new()
	_prompt_glyph.custom_minimum_size = Vector2(96, 96)
	_prompt_glyph.animate = true
	row.add_child(_prompt_glyph)
	_prompt_label = UiKit.label("", 26, UiKit.TEXT, 4)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.custom_minimum_size = Vector2(560, 0)
	_prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_prompt_label)
	_prompt.add_child(row)
	_root.add_child(_prompt)


func _show_toast(text: String, color: Color, size: int) -> void:
	if text == "":
		return
	_toast.text = text
	_toast.add_theme_font_size_override("font_size", size)
	_toast.add_theme_color_override("font_color", color)
	_toast.pivot_offset = _toast.size / 2.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast.scale = Vector2.ONE * 1.25
	_toast_tween = create_tween().set_parallel()
	_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5).set_delay(0.7)


func _overlay_box(title: String) -> VBoxContainer:
	_overlay = UiKit.full_rect(Control.new())
	var dim := UiKit.full_rect(ColorRect.new()) as ColorRect
	dim.color = Color(0.02, 0.0, 0.01, 0.6)
	_overlay.add_child(dim)
	var center := UiKit.full_rect(CenterContainer.new())
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(_centered(UiKit.label(title, 42, UiKit.GOLD, 8)))
	_root.add_child(_overlay)
	return box


func _clear_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _button(text: String, sig: Signal) -> Button:
	var b := UiKit.button(text, 380)
	b.pressed.connect(func() -> void: sig.emit())
	return b


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Health shown as oil lamps: lit ones burn, spent ones smoke.
class HeartsView extends Control:
	var hearts := 3
	var max_hearts := 3

	func _draw() -> void:
		for i in max_hearts:
			var x := 28.0 + i * 56.0
			var y := 40.0
			var lit := i < hearts
			if lit:
				draw_texture_rect(Fx.glow_texture(), Rect2(x - 26, y - 46, 52, 52), false, Color(1.0, 0.55, 0.2, 0.85))
				draw_colored_polygon(PackedVector2Array([Vector2(x - 5, y - 2), Vector2(x, y - 22), Vector2(x + 5, y - 2)]), Color(1.0, 0.86, 0.5))
			else:
				draw_line(Vector2(x, y - 4), Vector2(x + 3, y - 16), Color(0.5, 0.45, 0.45, 0.6), 2.0)
			var bowl := PackedVector2Array([Vector2(x - 19, y), Vector2(x + 19, y), Vector2(x + 10, y + 12), Vector2(x - 10, y + 12)])
			draw_colored_polygon(bowl, Color(0.16, 0.06, 0.05) if lit else Color(0.1, 0.07, 0.07))
			draw_polyline(PackedVector2Array([bowl[0], bowl[1], bowl[2], bowl[3], bowl[0]]), Color(UiKit.GOLD, 0.8 if lit else 0.3), 1.5, true)


## A learned mantra: its sign, and a dark sweep while it recharges.
class SlotView extends Control:
	var id := ""
	var glyph := ""
	var color := Color.WHITE
	var ratio := 0.0

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var ready := ratio <= 0.0
		draw_circle(c, r, Color(0.05, 0.02, 0.03, 0.75))
		draw_arc(c, r, 0.0, TAU, 40, Color(color, 0.85 if ready else 0.3), 2.0, true)
		var pts := PackedVector2Array()
		for p in GlyphShapes.canonical(glyph):
			pts.append(c + p * r * 0.55)
		if pts.size() >= 2:
			draw_polyline(pts, Color(color, 1.0 if ready else 0.35), 3.0, true)
		if ratio > 0.01:
			var pie := PackedVector2Array([c])
			var steps := maxi(2, int(ratio * 32))
			for i in steps + 1:
				pie.append(c + Vector2.from_angle(-PI / 2.0 + TAU * ratio * i / steps) * r)
			draw_colored_polygon(pie, Color(0, 0, 0, 0.5))
