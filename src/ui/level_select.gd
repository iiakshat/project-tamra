class_name LevelSelect
extends PanelContainer
## Chapter map: every level as a numbered stone with its stars; locked ones show a lock.

signal chosen(level_id: String)
signal closed


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_style(0.95))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	var head := HBoxContainer.new()
	var total := UiKit.stat("star", "%d / %d" % [Game.save.total_stars(), Game.all_levels().size() * 3], UiKit.JYOTI, 28)
	total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.alignment = BoxContainer.ALIGNMENT_BEGIN
	head.add_child(total)
	var close := UiKit.icon_button("close", 64)
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)
	col.add_child(head)
	var n := 0
	for ch in Game.game_cfg.get("chapters", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var name := UiKit.label(str(ch.get("name", "")), 24, UiKit.MUTED, 4)
		name.custom_minimum_size = Vector2(230, 0)
		row.add_child(name)
		for id in ch.get("levels", []):
			n += 1
			row.add_child(_stone(str(id), n))
		col.add_child(row)


func _stone(id: String, number: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var open := Game.save.unlocked.has(id)
	var b := UiKit.icon_button("" if open else "lock", 84, UiKit.MUTED)
	if open:
		var num := UiKit.label(str(number), 34, UiKit.TEXT, 6)
		UiKit.full_rect(num)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(num)
		b.pressed.connect(func() -> void: chosen.emit(id))
	else:
		b.disabled = true
	box.add_child(b)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var s := UiKit.IconView.new()
		s.custom_minimum_size = Vector2(24, 24)
		s.icon = "star" if i < Game.save.stars(id) else "star_empty"
		s.color = UiKit.JYOTI
		stars.add_child(s)
	box.add_child(stars)
	return box
