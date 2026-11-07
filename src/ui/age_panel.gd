class_name AgePanel
extends PanelContainer
## One-time neutral age screen, shown before the data-sharing card. It asks for a birth
## year, starting from a neutral year (not near the cut-off), keeps only "13 or older" or
## not (see AgeGate), and never keeps the year. Dismissing without answering leaves the
## question open; it is asked again next launch. Everything in the game works either way.

signal closed
signal answered(is_13_or_older: bool)

const TEXT := "What year were you born?\nWe don't keep it. It only decides whether the game may ask to share play data."

var _year := AgeGate.START_YEAR
var _year_label: Label
var _this_year := int(Time.get_date_dict_from_system()["year"])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_theme_stylebox_override("panel", UiKit.frame_style(0.6, 10))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.custom_minimum_size = Vector2(560, 0)
	add_child(body)
	body.add_child(UiKit.header("info", "Before we start", func() -> void: closed.emit()))
	var l := UiKit.label(TEXT, 22, UiKit.TEXT, 4)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(l)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	row.add_child(_step_button("-10", -10))
	row.add_child(_step_button("-1", -1))
	_year_label = UiKit.title(str(_year), 64, UiKit.TEXT, 8)
	_year_label.custom_minimum_size = Vector2(170, 0)
	_year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_year_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_year_label)
	row.add_child(_step_button("+1", 1))
	row.add_child(_step_button("+10", 10))

	var ok := UiKit.pill("OK", "check", "jade", 72, 240)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_confirm)
	body.add_child(ok)


func _step_button(text: String, delta: int) -> Button:
	var b := UiKit.pill(text, "", "red", 60, 84)
	b.pressed.connect(func() -> void:
		_year = AgeGate.clamp_year(_year + delta, _this_year)
		_year_label.text = str(_year)
	)
	return b


func _confirm() -> void:
	var state := Game.answer_age(_year)
	answered.emit(state == "ok")
	closed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_visible_in_tree():
		closed.emit()
