class_name ShopPanel
extends PanelContainer
## Hero skins. Jyoti skins are earned in play; premium ones are shown as "coming soon"
## until a store SDK sits behind Services.store. Cosmetics only.

signal closed

var _grid: HBoxContainer
var _bank: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UiKit.panel_style(0.95))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	var head := HBoxContainer.new()
	_bank = UiKit.stat("jyoti", "", UiKit.JYOTI, 28)
	_bank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bank.alignment = BoxContainer.ALIGNMENT_BEGIN
	head.add_child(_bank)
	var close := UiKit.icon_button("close", 64)
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)
	col.add_child(head)
	_grid = HBoxContainer.new()
	_grid.add_theme_constant_override("separation", 14)
	col.add_child(_grid)
	_rebuild()


func _rebuild() -> void:
	(_bank.get_child(1) as Label).text = str(Game.save.jyoti)
	for c in _grid.get_children():
		c.queue_free()
	var skins: Dictionary = Game.shop_cfg.get("skins", {})
	for id in skins:
		_grid.add_child(_card(str(id), skins[id]))


func _card(id: String, item: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(130, 190)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.2, 0.8) if Game.save.skin != id else Color(0.12, 0.3, 0.3, 0.9)
	UiKit.full_rect(bg)
	stage.add_child(bg)
	var holder := Node2D.new()
	holder.position = Vector2(65, 175)
	holder.scale = Vector2(1.3, 1.3)
	stage.add_child(holder)
	var p := Puppet.new()
	p.build("hero", Game.skin_palette(id))
	p.z_index = 0
	holder.add_child(p)
	col.add_child(stage)
	var premium := bool(item.get("premium", false))
	var owned := Game.save.skins_owned.has(id)
	var b: Button
	if premium:
		b = UiKit.icon_button("hourglass", 64, UiKit.MUTED)
		b.disabled = not Services.store.is_available()
	elif owned:
		b = UiKit.icon_button("check" if Game.save.skin == id else "play", 64, UiKit.ACCENT)
		b.pressed.connect(func() -> void:
			Game.equip_skin(id)
			_rebuild()
		)
	else:
		var cost := int(item.get("cost", 0))
		b = UiKit.button(str(cost), 120)
		b.custom_minimum_size = Vector2(120, 60)
		var icon := UiKit.IconView.new()
		icon.icon = "jyoti"
		icon.color = UiKit.JYOTI
		icon.position = Vector2(8, 14)
		icon.size = Vector2(30, 30)
		b.add_child(icon)
		b.disabled = Game.save.jyoti < cost
		b.pressed.connect(func() -> void:
			if Game.buy_skin(id):
				Sfx.play("mantra_learned")
			_rebuild()
		)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(b)
	return col
