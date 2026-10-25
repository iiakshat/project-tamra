class_name Icons
extends RefCounted
## Vector icons drawn in code: crisp at any size, no image files. `r` is the half-size
## of the box the icon fills.


static func draw(ci: CanvasItem, name: String, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(2.0, r * 0.11)
	var s := r * 0.62
	match name:
		"play", "next":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, -s), c + Vector2(s, 0), c + Vector2(-s * 0.6, s)]), col)
			if name == "next":
				ci.draw_line(c + Vector2(s * 1.05, -s), c + Vector2(s * 1.05, s), col, w * 1.4)
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s), Vector2(s * 0.5, s * 2)), col)
			ci.draw_rect(Rect2(c + Vector2(s * 0.2, -s), Vector2(s * 0.5, s * 2)), col)
		"restart":
			ci.draw_arc(c, s * 0.85, -PI * 0.35, PI * 1.45, 28, col, w, true)
			var tip := c + Vector2.from_angle(-PI * 0.35) * s * 0.85
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.45, -s * 0.15), tip + Vector2(s * 0.15, -s * 0.45), tip + Vector2(s * 0.25, s * 0.2)]), col)
		"home":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, -s * 0.05), c + Vector2(-s, -s * 0.05)]), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.05), Vector2(s * 1.4, s * 1.0)), col, false, w)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.18, s * 0.35), Vector2(s * 0.36, s * 0.6)), col)
		"close":
			ci.draw_line(c + Vector2(-s, -s) * 0.75, c + Vector2(s, s) * 0.75, col, w * 1.3, true)
			ci.draw_line(c + Vector2(s, -s) * 0.75, c + Vector2(-s, s) * 0.75, col, w * 1.3, true)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.8, 0), c + Vector2(-s * 0.2, s * 0.6), c + Vector2(s * 0.85, -s * 0.6)]), col, w * 1.4, true)
		"book":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.6), c + Vector2(-s, -s * 0.85), c + Vector2(-s, s * 0.75), c + Vector2(0, s)]), Color(col, 0.85))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.6), c + Vector2(s, -s * 0.85), c + Vector2(s, s * 0.75), c + Vector2(0, s)]), col)
			ci.draw_arc(c + Vector2(s * 0.5, 0), s * 0.22, 0, TAU, 12, Color(0.05, 0.05, 0.12), w * 0.8)
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2.from_angle(a) * s * 0.55, c + Vector2.from_angle(a) * s * 1.0, col, w * 1.8)
			ci.draw_circle(c, s * 0.62, col)
			ci.draw_circle(c, s * 0.26, Color(0.05, 0.05, 0.12))
		"music", "music_off":
			ci.draw_line(c + Vector2(-s * 0.2, s * 0.6), c + Vector2(-s * 0.2, -s * 0.8), col, w)
			ci.draw_line(c + Vector2(s * 0.7, s * 0.4), c + Vector2(s * 0.7, -s), col, w)
			ci.draw_line(c + Vector2(-s * 0.2, -s * 0.8), c + Vector2(s * 0.7, -s), col, w * 1.6)
			ci.draw_circle(c + Vector2(-s * 0.45, s * 0.65), s * 0.3, col)
			ci.draw_circle(c + Vector2(s * 0.45, s * 0.45), s * 0.3, col)
			if name == "music_off":
				ci.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), UiKit.DANGER, w * 1.4, true)
		"sound", "sound_off":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.35), c + Vector2(-s * 0.45, -s * 0.35), c + Vector2(s * 0.1, -s * 0.9),
				c + Vector2(s * 0.1, s * 0.9), c + Vector2(-s * 0.45, s * 0.35), c + Vector2(-s, s * 0.35)]), col)
			if name == "sound":
				ci.draw_arc(c + Vector2(s * 0.15, 0), s * 0.5, -0.8, 0.8, 10, col, w, true)
				ci.draw_arc(c + Vector2(s * 0.15, 0), s * 0.85, -0.8, 0.8, 10, col, w, true)
			else:
				ci.draw_line(c + Vector2(s * 0.4, -s * 0.4), c + Vector2(s, s * 0.4), UiKit.DANGER, w * 1.3, true)
				ci.draw_line(c + Vector2(s, -s * 0.4), c + Vector2(s * 0.4, s * 0.4), UiKit.DANGER, w * 1.3, true)
		"lock":
			ci.draw_arc(c + Vector2(0, -s * 0.25), s * 0.45, PI, TAU, 14, col, w * 1.2, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.25), Vector2(s * 1.4, s * 1.15)), col)
		"jyoti":
			# A lamp flame: the collectible light.
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 1.05), c + Vector2(s * 0.5, s * 0.1), c + Vector2(s * 0.3, s * 0.6),
				c + Vector2(0, s * 0.75), c + Vector2(-s * 0.3, s * 0.6), c + Vector2(-s * 0.5, s * 0.1)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.3), c + Vector2(s * 0.22, s * 0.3), c + Vector2(0, s * 0.5),
				c + Vector2(-s * 0.22, s * 0.3)]), Color(1, 1, 1, 0.9))
		"prana":
			ci.draw_arc(c, s * 0.8, 0, TAU, 24, col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.15, -s * 0.75), c + Vector2(-s * 0.35, s * 0.1), c + Vector2(0, s * 0.1),
				c + Vector2(-s * 0.15, s * 0.75), c + Vector2(s * 0.35, -s * 0.1), c + Vector2(0, -s * 0.1)]), col)
		"star", "star_empty":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + TAU * i / 10.0
				pts.append(c + Vector2.from_angle(a) * (s if i % 2 == 0 else s * 0.45))
			if name == "star":
				ci.draw_colored_polygon(pts, col)
			else:
				pts.append(pts[0])
				ci.draw_polyline(pts, Color(col, 0.5), w, true)
		"clock":
			ci.draw_arc(c, s * 0.9, 0, TAU, 28, col, w, true)
			ci.draw_line(c, c + Vector2(0, -s * 0.6), col, w)
			ci.draw_line(c, c + Vector2(s * 0.45, 0), col, w)
		"skull":
			ci.draw_circle(c + Vector2(0, -s * 0.15), s * 0.7, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, s * 0.3), Vector2(s * 0.8, s * 0.5)), col)
			ci.draw_circle(c + Vector2(-s * 0.28, -s * 0.15), s * 0.18, Color(0.05, 0.05, 0.12))
			ci.draw_circle(c + Vector2(s * 0.28, -s * 0.15), s * 0.18, Color(0.05, 0.05, 0.12))
		"gift":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.85, -s * 0.2), Vector2(s * 1.7, s * 1.1)), col)
			ci.draw_rect(Rect2(c + Vector2(-s, -s * 0.55), Vector2(s * 2, s * 0.38)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.13, -s * 0.55), Vector2(s * 0.26, s * 1.45)), Color(0.05, 0.05, 0.12))
			ci.draw_arc(c + Vector2(-s * 0.3, -s * 0.7), s * 0.28, 0, TAU, 12, col, w, true)
			ci.draw_arc(c + Vector2(s * 0.3, -s * 0.7), s * 0.28, 0, TAU, 12, col, w, true)
		"shop":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.85, -s * 0.3), c + Vector2(s * 0.85, -s * 0.3), c + Vector2(s * 0.65, s * 0.9),
				c + Vector2(-s * 0.65, s * 0.9)]), col)
			ci.draw_arc(c + Vector2(0, -s * 0.3), s * 0.45, PI, TAU, 14, col, w * 1.2, true)
		"trial":
			# Crossed staff and flame: the daily trial.
			ci.draw_line(c + Vector2(-s, s), c + Vector2(s * 0.6, -s * 0.6), col, w * 1.4, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.6, -s * 1.05), c + Vector2(s * 0.95, -s * 0.45), c + Vector2(s * 0.6, -s * 0.2),
				c + Vector2(s * 0.25, -s * 0.45)]), col)
		"vow":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.85), Vector2(s * 1.4, s * 1.7)), col, false, w)
			for i in 3:
				ci.draw_line(c + Vector2(-s * 0.4, -s * 0.4 + i * s * 0.4), c + Vector2(s * 0.4, -s * 0.4 + i * s * 0.4), col, w * 0.8)
		"heart":
			ci.draw_circle(c + Vector2(-s * 0.38, -s * 0.2), s * 0.45, col)
			ci.draw_circle(c + Vector2(s * 0.38, -s * 0.2), s * 0.45, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.82, -s * 0.05), c + Vector2(s * 0.82, -s * 0.05), c + Vector2(0, s * 0.9)]), col)
		"up":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, 0), c + Vector2(s * 0.3, 0), c + Vector2(s * 0.3, s),
				c + Vector2(-s * 0.3, s), c + Vector2(-s * 0.3, 0), c + Vector2(-s * 0.8, 0)]), col)
		"hourglass":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.7, -s), c + Vector2(s * 0.7, -s), c + Vector2(0, 0)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.7, s), c + Vector2(s * 0.7, s), c + Vector2(0, 0)]), Color(col, 0.6))
		"question":
			ci.draw_arc(c + Vector2(0, -s * 0.35), s * 0.45, PI, TAU + PI * 0.4, 16, col, w * 1.3, true)
			ci.draw_line(c + Vector2(s * 0.12, s * 0.05), c + Vector2(0, s * 0.35), col, w * 1.3)
			ci.draw_circle(c + Vector2(0, s * 0.75), w * 0.9, col)
		"pen":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.55, -s), c + Vector2(s, -s * 0.55), c + Vector2(-s * 0.45, s * 0.9),
				c + Vector2(-s * 0.95, s * 0.95), c + Vector2(-s * 0.9, s * 0.45)]), col)
		"log":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.9), Vector2(s * 1.4, s * 1.8)), col, false, w)
			ci.draw_line(c + Vector2(-s * 0.35, -s * 0.4), c + Vector2(s * 0.35, -s * 0.4), col, w)
			ci.draw_line(c + Vector2(-s * 0.35, 0), c + Vector2(s * 0.35, 0), col, w)
			ci.draw_line(c + Vector2(-s * 0.35, s * 0.4), c + Vector2(s * 0.1, s * 0.4), col, w)
