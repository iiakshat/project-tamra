class_name DailyPanel
extends PanelContainer
## Today's rewards, each explained in a few words: the 7-day blessing track, three vows
## (small tasks) and the trial (a cleared level with a twist). The top line says what
## the Jyoti is for, so the player knows what they are playing for.

signal play_trial(level_id: String, mod: String)
signal claimed
signal closed

## One line per vow; %d is the goal.
const VOW_TEXT := {
	"strike_kills": "Defeat %d guards with your staff",
	"fire_kills": "Defeat %d guards with JWALA",
	"casts": "Cast %d mantras",
	"jyoti": "Collect %d Jyoti",
	"levels": "Clear %d levels",
	"clean_clear": "Clear a level without falling",
	"setu": "Build %d SETU bridges",
	"udaan": "Leap with UDAAN %d times",
}
const VOW_ICONS := {
	"strike_kills": "trial", "fire_kills": "fire", "casts": "cast", "jyoti": "jyoti",
	"levels": "flag", "clean_clear": "heart", "setu": "bridge", "udaan": "leap",
}
const MOD_TEXT := {"frail": "Only 1 heart", "thin_prana": "Half prana", "fierce": "Fiercer guards"}
const MOD_ICONS := {"frail": "heart", "thin_prana": "prana", "fierce": "skull"}

var _body: VBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.frame_style(0.6, 10))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	add_child(_body)
	_rebuild()


func _rebuild() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var d := Game.daily
	d.refresh(Game.today())

	var head := UiKit.header("gift", "Daily", func() -> void: closed.emit())
	var bank := UiKit.jyoti_counter(22)
	bank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(bank)
	head.move_child(bank, head.get_child_count() - 2)
	_body.add_child(head)
	_body.add_child(_spend_line())

	# Blessing track.
	_body.add_child(_section("Blessing", "a gift for each day you visit"))
	var track := HBoxContainer.new()
	track.add_theme_constant_override("separation", 8)
	var available := d.blessing_available(Game.today())
	var step := d.blessing_step()
	for i in DailyRules.BLESSINGS.size():
		var state := "future"
		if available:
			state = "claimed" if i < step else ("today" if i == step else "future")
		else:
			# Claimed today: everything before the next step is done (all 7 after a full cycle).
			state = "claimed" if (i < step or step == 0) else ("tomorrow" if i == step else "future")
		track.add_child(_day_tile(i, state))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.custom_minimum_size = Vector2(6, 0)
	track.add_child(gap)
	if available:
		var claim := UiKit.pill("Claim", "", "jade", 62, 150)
		claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		claim.pressed.connect(func() -> void:
			if Game.claim_blessing() > 0:
				Sfx.play("mantra_learned")
			claimed.emit()
			_rebuild()
		)
		UiKit.pulse(claim, 0.04, 1.4)
		track.add_child(claim)
	else:
		var later := UiKit.stat("clock", "Tomorrow", UiKit.MUTED, 18)
		later.custom_minimum_size = Vector2(150, 0)
		track.add_child(later)
	_body.add_child(track)

	# Vows and trial, side by side.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	_body.add_child(cols)
	var vows := VBoxContainer.new()
	vows.add_theme_constant_override("separation", 6)
	vows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(vows)
	vows.add_child(_section("Vows", "today's tasks"))
	for v in d.vows():
		vows.add_child(_vow_row(v))
	var all_done := d.vows().all(func(v: Dictionary) -> bool: return bool(v["claimed"]))
	var bonus := UiKit.stat("check" if all_done else "vow", "All three: +%d" % DailyRules.ALL_VOWS_BONUS,
		UiKit.ACCENT if all_done else UiKit.MUTED, 16)
	bonus.alignment = BoxContainer.ALIGNMENT_BEGIN
	vows.add_child(bonus)
	cols.add_child(_trial_box())


## "Jyoti buys:" mantras, upgrades, skins.
func _spend_line() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiKit.stat("jyoti", "Jyoti buys", UiKit.JYOTI, 18))
	for pair in [["book", "Mantras"], ["up", "Upgrades"], ["skin", "Skins"]]:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiKit.plate_style(14, 0.6))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(UiKit.stat(pair[0], pair[1], UiKit.TEXT, 16))
		row.add_child(chip)
	return row


func _section(name: String, hint: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UiKit.title(name, 22, UiKit.COPPER, 5)
	row.add_child(t)
	var h := UiKit.label(hint, 16, UiKit.MUTED, 3)
	h.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(h)
	return row


func _day_tile(i: int, state: String) -> Control:
	var tile := PanelContainer.new()
	var sb := UiKit.plate_style(12, 0.75)
	sb.set_content_margin_all(4)
	if state == "today":
		sb.border_color = UiKit.ACCENT
		sb.set_border_width_all(3)
		sb.bg_color = Color(0.1, 0.24, 0.28, 0.95)
	elif state == "claimed":
		sb.bg_color = Color(0.04, 0.04, 0.1, 0.6)
		sb.border_color = Color(UiKit.COPPER, 0.35)
	tile.add_theme_stylebox_override("panel", sb)
	tile.custom_minimum_size = Vector2(76, 0)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	tile.add_child(col)
	var day_text := "Today" if state == "today" else ("Next" if state == "tomorrow" else "Day %d" % (i + 1))
	var day := UiKit.label(day_text, 14, UiKit.ACCENT if state == "today" else UiKit.MUTED, 3)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(day)
	var icon := UiKit.IconView.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.icon = "check" if state == "claimed" else ("gift" if i == DailyRules.BLESSINGS.size() - 1 else "jyoti")
	icon.color = UiKit.ACCENT if state == "claimed" else UiKit.JYOTI
	col.add_child(icon)
	var amt := UiKit.label("+%d" % DailyRules.BLESSINGS[i], 18, UiKit.MUTED if state == "claimed" else UiKit.TEXT, 3)
	amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(amt)
	if state == "today":
		UiKit.pulse(tile, 0.05, 1.2)
	return tile


func _vow_row(v: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var done := Game.daily.vow_done(v)
	var id := str(v["id"])
	var icon := UiKit.IconView.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.icon = VOW_ICONS.get(id, "vow")
	icon.color = UiKit.ACCENT if done else UiKit.TEXT
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text := str(VOW_TEXT.get(id, id))
	mid.add_child(UiKit.label(text % int(v["goal"]) if text.contains("%d") else text, 18, UiKit.TEXT, 4))
	var prog := HBoxContainer.new()
	prog.add_theme_constant_override("separation", 8)
	prog.add_child(UiKit.bar(int(v["progress"]), int(v["goal"]), UiKit.ACCENT, 190))
	prog.add_child(UiKit.label("%d/%d" % [int(v["progress"]), int(v["goal"])], 15, UiKit.MUTED, 3))
	mid.add_child(prog)
	row.add_child(mid)
	if bool(v["claimed"]):
		var ok := UiKit.stat("check", "Done", UiKit.ACCENT, 16)
		ok.custom_minimum_size = Vector2(100, 0)
		row.add_child(ok)
	elif done:
		var take := UiKit.pill("+%d" % DailyRules.VOW_REWARD, "jyoti", "jade", 46, 100)
		take.pressed.connect(func() -> void:
			if Game.claim_vows() > 0:
				Sfx.play("mantra_learned")
			claimed.emit()
			_rebuild()
		)
		row.add_child(take)
	else:
		var reward := UiKit.stat("jyoti", "+%d" % DailyRules.VOW_REWARD, UiKit.JYOTI, 17)
		reward.custom_minimum_size = Vector2(100, 0)
		row.add_child(reward)
	return row


func _trial_box() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(250, 0)
	box.add_child(_section("Trial", "once a day"))
	var t := Game.daily.trial(Game.today(), Game.cleared_levels())
	if t.is_empty():
		box.add_child(UiKit.stat("lock", "Clear a level first", UiKit.MUTED, 18))
		return box
	var mod := str(t["mod"])
	var name := UiKit.stat("trial", Game.level_name(str(t["level"])), UiKit.TEXT, 20)
	name.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_child(name)
	var twist := UiKit.stat(MOD_ICONS.get(mod, "skull"), MOD_TEXT.get(mod, mod), UiKit.DANGER, 18)
	twist.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_child(twist)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(UiKit.stat("jyoti", "+%d" % DailyRules.TRIAL_REWARD, UiKit.JYOTI, 20))
	if Game.daily.trial_done(Game.today()):
		row.add_child(UiKit.stat("check", "Done", UiKit.ACCENT, 18))
	else:
		var go := UiKit.pill("Play", "play", "red", 54, 130)
		go.pressed.connect(func() -> void: play_trial.emit(str(t["level"]), mod))
		row.add_child(go)
	box.add_child(row)
	return box
