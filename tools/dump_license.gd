extends SceneTree
func _init() -> void:
	var t := "Godot Engine - MIT License\n\n" + Engine.get_license_text() + "\n\nThird-party components included in Godot Engine:\n"
	for info in Engine.get_copyright_info():
		t += "- " + str(info.get("name", "")) + "\n"
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(t)
	quit()
