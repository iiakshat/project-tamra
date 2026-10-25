class_name DailyPanel
extends PanelContainer
## Today's gifts: the blessing cycle, three vows and the trial. Few words, mostly icons.

signal play_trial(level_id: String, mod: String)
signal closed

const VOW_NAMES := {
	"strike_kills": "Staff", "fire_kills": "Fire", "casts": "Cast", "jyoti": "Gather",
	"levels": "Clear", "clean_clear": "No fall", "setu": "Bridges", "udaan": "Leaps",
}
const MOD_ICONS := {"frail": "heart", "thin_prana": "prana", "fierce": "skull"}

var _body: VBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_style(0.95))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 18)
	add_child(_body)
	_rebuild()


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var d := Game.daily
	d.refresh(Game.today())
	var head := HBoxContainer.new()
	var bank := UiKit.stat("jyoti", str(Game.save.jyoti), UiKit.JYOTI, 28)
	bank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank.alignment = BoxContainer.ALIGNMENT_BEGIN
	head.add_child(bank)
	var close := UiKit.icon_button("close", 64)
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)
	_body.add_child(head)

	# Blessing: seven steps, the next one highlighted.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var available := d.blessing_available(Game.today())
	for i in DailyRules.BLESSINGS.size():
		var step := VBoxContainer.new()
		var is_next := i == d.blessing_step()
		var icon := UiKit.IconView.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.icon = "gift" if i == DailyRules.BLESSINGS.size() - 1 else "jyoti"
		icon.color = UiKit.ACCENT if is_next and available else (UiKit.JYOTI if i >= d.blessing_step() else UiKit.MUTED)
		step.add_child(icon)
		var amt := UiKit.label(str(DailyRules.BLESSINGS[i]), 18, icon.color, 3)
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		step.add_child(amt)
		row.add_child(step)
	var claim := UiKit.icon_button("gift", 76, UiKit.ACCENT if available else UiKit.MUTED)
	claim.disabled = not available
	claim.pressed.connect(func() -> void:
		var r := Game.claim_blessing()
		if r > 0:
			Sfx.play("mantra_learned")
		_rebuild()
	)
	row.add_child(claim)
	_body.add_child(row)

	# Vows.
	for v in d.vows():
		var vr := HBoxContainer.new()
		vr.add_theme_constant_override("separation", 12)
		var icon := UiKit.IconView.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.icon = str(v["icon"])
		icon.color = UiKit.ACCENT if d.vow_done(v) else UiKit.TEXT
		vr.add_child(icon)
		var name := UiKit.label(VOW_NAMES.get(v["id"], ""), 22, UiKit.TEXT, 3)
		name.custom_minimum_size = Vector2(120, 0)
		vr.add_child(name)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(240, 18)
		bar.max_value = int(v["goal"])
		bar.value = int(v["progress"])
		bar.show_percentage = false
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = UiKit.ACCENT
		bar.add_theme_stylebox_override("fill", fill)
		vr.add_child(bar)
		vr.add_child(UiKit.label("%d/%d" % [int(v["progress"]), int(v["goal"])], 20, UiKit.MUTED, 3))
		if bool(v["claimed"]):
			var done := UiKit.IconView.new()
			done.custom_minimum_size = Vector2(34, 34)
			done.icon = "check"
			done.color = UiKit.ACCENT
			vr.add_child(done)
		_body.add_child(vr)
	var waiting := d.unclaimed_vows()
	if waiting > 0:
		var take := UiKit.icon_button("vow", 72, UiKit.ACCENT)
		take.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		take.pressed.connect(func() -> void:
			if Game.claim_vows() > 0:
				Sfx.play("mantra_learned")
			_rebuild()
		)
		_body.add_child(take)

	# Trial.
	var t := d.trial(Game.today(), Game.cleared_levels())
	if not t.is_empty():
		var tr := HBoxContainer.new()
		tr.add_theme_constant_override("separation", 14)
		tr.alignment = BoxContainer.ALIGNMENT_CENTER
		var ti := UiKit.IconView.new()
		ti.custom_minimum_size = Vector2(52, 52)
		ti.icon = "trial"
		ti.color = UiKit.DANGER
		tr.add_child(ti)
		tr.add_child(UiKit.label(Game.level_name(str(t["level"])), 24, UiKit.TEXT, 4))
		var mi := UiKit.IconView.new()
		mi.custom_minimum_size = Vector2(40, 40)
		mi.icon = MOD_ICONS.get(t["mod"], "skull")
		mi.color = UiKit.DANGER
		tr.add_child(mi)
		tr.add_child(UiKit.stat("jyoti", "+%d" % DailyRules.TRIAL_REWARD, UiKit.JYOTI, 22))
		if d.trial_done(Game.today()):
			var ok := UiKit.IconView.new()
			ok.custom_minimum_size = Vector2(44, 44)
			ok.icon = "check"
			ok.color = UiKit.ACCENT
			tr.add_child(ok)
		else:
			var go := UiKit.icon_button("play", 72, UiKit.DANGER)
			go.pressed.connect(func() -> void: play_trial.emit(str(t["level"]), str(t["mod"])))
			tr.add_child(go)
		_body.add_child(tr)
