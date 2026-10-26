class_name ShopPanel
extends PanelContainer
## Hero skins. Jyoti skins are earned in play; premium ones are shown as "coming soon"
## until a store SDK sits behind Services.store. Cosmetics only.

signal closed

var _grid: HBoxContainer
var _bank: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_theme_stylebox_override("panel", UiKit.frame_style(0.6, 10))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	var head := UiKit.header("shop", "Skins", func() -> void: closed.emit())
	_bank = UiKit.jyoti_counter(22)
	_bank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_bank)
	head.move_child(_bank, head.get_child_count() - 2)
	col.add_child(head)
	_grid = HBoxContainer.new()
	_grid.add_theme_constant_override("separation", 12)
	col.add_child(_grid)
	_rebuild()


func _rebuild() -> void:
	(_bank.get_child(0).get_child(1) as Label).text = str(Game.save.jyoti)
	for c in _grid.get_children():
		c.queue_free()
	var skins: Dictionary = Game.shop_cfg.get("skins", {})
	for id in skins:
		_grid.add_child(_card(str(id), skins[id]))


func _card(id: String, item: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(130, 190)
	var sb := UiKit.plate_style(14, 0.7)
	if Game.save.skin == id:
		sb.border_color = UiKit.ACCENT
		sb.set_border_width_all(3)
		sb.bg_color = Color(0.08, 0.22, 0.26, 0.9)
	stage.add_theme_stylebox_override("panel", sb)
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
	var b: Control
	if premium:
		b = UiKit.stat("hourglass", "Soon", UiKit.MUTED, 18)
		b.custom_minimum_size = Vector2(0, 56)
	elif owned and Game.save.skin == id:
		b = UiKit.stat("check", "Worn", UiKit.ACCENT, 18)
		b.custom_minimum_size = Vector2(0, 56)
	elif owned:
		var wear := UiKit.pill("Wear", "", "jade", 56, 124)
		wear.pressed.connect(func() -> void:
			Game.equip_skin(id)
			_rebuild()
		)
		b = wear
	else:
		var cost := int(item.get("cost", 0))
		var buy := UiKit.pill(str(cost), "jyoti", "jade", 56, 124)
		buy.disabled = Game.save.jyoti < cost
		b = buy
		buy.pressed.connect(func() -> void:
			if Game.buy_skin(id):
				Sfx.play("mantra_learned")
			_rebuild()
		)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(b)
	return col
