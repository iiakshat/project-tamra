extends "res://tests/test_case.gd"

const SCREEN := Vector2(1280, 720)


func test_default_matches_the_original_layout() -> void:
	var l := ControlLayout.compute(SCREEN, 1.0, false)
	check_eq(l["centers"]["left"], Vector2(115, 605), "left pad")
	check_eq(l["centers"]["right"], Vector2(285, 605), "right pad")
	check_eq(l["centers"]["jump"], Vector2(1150, 590), "jump pad")
	check_eq(l["centers"]["strike"], Vector2(980, 628), "strike pad")
	check_eq(l["radii"]["jump"], 92.0, "jump radius")


func test_scale_grows_radii_and_keeps_pads_on_screen() -> void:
	var l := ControlLayout.compute(SCREEN, 1.4, false)
	check_eq(l["radii"]["left"], 78.0 * 1.4, "left radius scales")
	for role in l["centers"]:
		var c: Vector2 = l["centers"][role]
		var r: float = l["radii"][role]
		check(c.x - r >= 0.0 and c.x + r <= SCREEN.x, "%s inside horizontally" % role)
		check(c.y - r >= 0.0 and c.y + r <= SCREEN.y, "%s inside vertically" % role)


func test_pads_never_overlap_at_any_size() -> void:
	for scale in [ControlLayout.MIN_SCALE, 1.0, ControlLayout.MAX_SCALE]:
		for swapped in [false, true]:
			var l := ControlLayout.compute(SCREEN, scale, swapped)
			var roles: Array = l["centers"].keys()
			for i in roles.size():
				for j in range(i + 1, roles.size()):
					var d: float = (l["centers"][roles[i]] as Vector2).distance_to(l["centers"][roles[j]])
					var need: float = float(l["radii"][roles[i]]) + float(l["radii"][roles[j]])
					check(d >= need, "%s and %s overlap at scale %s swapped %s" % [roles[i], roles[j], scale, swapped])


func test_left_handed_swaps_the_two_clusters() -> void:
	var a := ControlLayout.compute(SCREEN, 1.0, false)
	var b := ControlLayout.compute(SCREEN, 1.0, true)
	# Action pads mirror across the screen.
	for role in ["jump", "strike"]:
		check_eq(b["centers"][role].x, SCREEN.x - a["centers"][role].x, "%s mirrored x" % role)
		check_eq(b["centers"][role].y, a["centers"][role].y, "%s same y" % role)
	# The move cluster mirrors as a block, so the arrows keep pointing the right way:
	# the pad that moves the hero left stays to the left of the one that moves right.
	check_eq(b["centers"]["left"].x, SCREEN.x - a["centers"]["right"].x, "left pad x")
	check_eq(b["centers"]["right"].x, SCREEN.x - a["centers"]["left"].x, "right pad x")
	check(b["centers"]["left"].x < b["centers"]["right"].x, "left pad stays left of right pad")


func test_scale_is_clamped() -> void:
	check_eq(ControlLayout.clamp_scale(0.1), ControlLayout.MIN_SCALE, "min")
	check_eq(ControlLayout.clamp_scale(9.0), ControlLayout.MAX_SCALE, "max")
	check_eq(ControlLayout.clamp_scale(1.2), 1.2, "inside range is kept")


func test_next_size_cycles_through_presets() -> void:
	var s := 1.0
	var seen := []
	for i in ControlLayout.PRESETS.size():
		s = ControlLayout.next_scale(s)
		seen.append(s)
	check_eq(seen.size(), ControlLayout.PRESETS.size(), "one step per preset")
	check_eq(ControlLayout.next_scale(ControlLayout.PRESETS[ControlLayout.PRESETS.size() - 1]), ControlLayout.PRESETS[0], "wraps around")
	# An unknown stored value moves to the next preset above it.
	check_eq(ControlLayout.next_scale(1.05), 1.2, "snaps up from an off-preset value")


func test_new_settings_survive_a_save_round_trip() -> void:
	var s := SaveData.new()
	check_eq(s.settings["pad_scale"], 1.0, "default pad scale")
	check_eq(s.settings["left_handed"], false, "default hand")
	s.settings["pad_scale"] = 1.2
	s.settings["left_handed"] = true
	var loaded := SaveData.from_dict(s.to_dict())
	check_eq(loaded.settings["pad_scale"], 1.2, "scale kept")
	check_eq(loaded.settings["left_handed"], true, "hand kept")
