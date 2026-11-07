class_name ControlLayout
extends RefCounted
## Where the on-screen pads sit. Pure maths, so it is unit tested. Offsets are measured from
## the bottom corners and scale together with the radii, so pads never overlap at any size
## and always stay on screen. Left-handed play swaps the two clusters.

const MIN_SCALE := 0.8
const MAX_SCALE := 1.4
## Sizes the Settings button cycles through (small, normal, large, extra large).
const PRESETS: Array[float] = [0.8, 1.0, 1.2, 1.4]

const RADIUS := {"left": 78.0, "right": 78.0, "jump": 92.0, "strike": 68.0}
## Distance of each pad's centre from its screen edge (x) and from the bottom (y), at scale 1.
## "left"/"right" are the move pads (left cluster); "strike"/"jump" the action pads.
const OFFSET := {
	"left": Vector2(115, 115),
	"right": Vector2(285, 115),
	"jump": Vector2(130, 130),
	"strike": Vector2(300, 92),
}


static func clamp_scale(scale: float) -> float:
	return clampf(scale, MIN_SCALE, MAX_SCALE)


## The next size preset above `scale`, wrapping to the smallest after the largest.
static func next_scale(scale: float) -> float:
	for p in PRESETS:
		if p > scale + 0.001:
			return p
	return PRESETS[0]


## {"centers": {role: Vector2}, "radii": {role: float}} for a screen of this size.
static func compute(screen: Vector2, scale: float, left_handed: bool) -> Dictionary:
	var k := clamp_scale(scale)
	var centers := {}
	var radii := {}
	for role in OFFSET:
		var off: Vector2 = OFFSET[role] * k
		var on_left_side: bool = role == "left" or role == "right"
		if left_handed:
			on_left_side = not on_left_side
		var x := off.x if on_left_side else screen.x - off.x
		if left_handed and (role == "left" or role == "right"):
			# Keep the arrows honest: "left" stays to the left of "right".
			var other: Vector2 = OFFSET["right" if role == "left" else "left"] * k
			x = screen.x - other.x
		centers[role] = Vector2(x, screen.y - off.y)
		radii[role] = float(RADIUS[role]) * k
	return {"centers": centers, "radii": radii}
