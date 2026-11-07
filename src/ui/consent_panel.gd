class_name ConsentPanel
extends PanelContainer
## One-time card on the title screen: may the game share anonymous play data? Two big
## choices, equal weight, and the answer can be changed any time in Settings. `closed`
## fires after either choice; dismissing without choosing leaves the question open.

signal closed

## Plain words, no jargon. Keep in step with docs/PRIVACY.md.
const TEXT := "Share anonymous play data to help improve the game?\nNo name, no contacts, never used for ads. Change it any time in Settings."


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_theme_stylebox_override("panel", UiKit.frame_style(0.6, 10))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.custom_minimum_size = Vector2(500, 0)
	add_child(body)
	body.add_child(UiKit.header("info", "Help us improve", func() -> void: closed.emit()))
	var l := UiKit.label(TEXT, 22, UiKit.TEXT, 4)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	body.add_child(row)
	var no := UiKit.pill("No thanks", "", "red", 72, 210)
	no.pressed.connect(_choose.bind(false))
	row.add_child(no)
	var yes := UiKit.pill("Share", "check", "jade", 72, 210)
	yes.pressed.connect(_choose.bind(true))
	row.add_child(yes)


func _choose(granted: bool) -> void:
	Game.set_analytics_consent(granted)
	closed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_visible_in_tree():
		closed.emit()
