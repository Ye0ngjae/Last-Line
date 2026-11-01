class_name AircraftArt
extends RefCounted
## Vector aircraft silhouettes for the EO view. Each type has a side profile (fuselage, canopy, fins, engines,
## wings seen from below as a plan view whose height follows the viewing elevation) and a nose/tail-on view.
## Coordinates are fractions of the aircraft length: x forward (+ = nose), y down; plan parts use y = half-span.

# part = [kind, shade, points]; kind: "s" side view, "p" plan view (drawn mirrored about the fuselage)
# shade: 0 base, 1 dark, 2 light, 3 glass, 4 hot (engine), 5 plume (IR only), 6 windows, 7 prop disc
const SIDE := {
	"jet": [  # hostile fighter: twin canted fins, big wing, side intakes
		["p", 0, [Vector2(0.14, 0.0), Vector2(-0.16, 0.46), Vector2(-0.30, 0.46), Vector2(-0.27, 0.0)]],
		["p", 0, [Vector2(-0.34, 0.0), Vector2(-0.46, 0.2), Vector2(-0.52, 0.2), Vector2(-0.48, 0.0)]],
		["p", 2, [Vector2(0.30, 0.0), Vector2(0.08, 0.11), Vector2(0.05, 0.0)]],
		["s", 1, [Vector2(-0.24, -0.05), Vector2(-0.32, -0.17), Vector2(-0.37, -0.17), Vector2(-0.35, -0.046)]],
		["s", 0, [Vector2(0.50, 0.005), Vector2(0.44, -0.012), Vector2(0.36, -0.03), Vector2(0.20, -0.045), Vector2(-0.10, -0.05), Vector2(-0.38, -0.045), Vector2(-0.47, -0.035),
			Vector2(-0.47, 0.03), Vector2(-0.38, 0.045), Vector2(-0.10, 0.05), Vector2(0.15, 0.04), Vector2(0.38, 0.02)]],
		["s", 2, [Vector2(0.34, -0.03), Vector2(0.20, -0.046), Vector2(-0.10, -0.05), Vector2(-0.10, -0.042), Vector2(0.20, -0.036)]],
		["s", 1, [Vector2(0.22, 0.012), Vector2(0.20, 0.048), Vector2(0.02, 0.052), Vector2(0.0, 0.015)]],
		["s", 3, [Vector2(0.34, -0.032), Vector2(0.28, -0.066), Vector2(0.17, -0.072), Vector2(0.12, -0.048)]],
		["s", 0, [Vector2(-0.29, -0.048), Vector2(-0.39, -0.20), Vector2(-0.47, -0.20), Vector2(-0.45, -0.04)]],
		["s", 4, [Vector2(-0.46, -0.032), Vector2(-0.52, -0.026), Vector2(-0.52, 0.022), Vector2(-0.46, 0.034)]],
		["s", 5, [Vector2(-0.52, -0.022), Vector2(-0.80, 0.0), Vector2(-0.52, 0.02)]],
	],
	"ally": [  # friendly fighter: single fin, bubble canopy, belly intake, wingtip rails
		["p", 0, [Vector2(0.06, 0.0), Vector2(-0.20, 0.34), Vector2(-0.33, 0.34), Vector2(-0.33, 0.0)]],
		["p", 0, [Vector2(-0.36, 0.0), Vector2(-0.46, 0.15), Vector2(-0.51, 0.15), Vector2(-0.49, 0.0)]],
		["p", 1, [Vector2(-0.12, 0.335), Vector2(-0.12, 0.35), Vector2(-0.30, 0.35), Vector2(-0.30, 0.335)]],
		["s", 0, [Vector2(0.50, 0.0), Vector2(0.42, -0.016), Vector2(0.30, -0.036), Vector2(0.10, -0.05), Vector2(-0.20, -0.046), Vector2(-0.45, -0.032), Vector2(-0.48, -0.005),
			Vector2(-0.45, 0.035), Vector2(-0.20, 0.056), Vector2(0.05, 0.062), Vector2(0.25, 0.036), Vector2(0.40, 0.014)]],
		["s", 2, [Vector2(0.30, -0.036), Vector2(0.10, -0.05), Vector2(-0.20, -0.046), Vector2(-0.20, -0.04), Vector2(0.10, -0.043)]],
		["s", 1, [Vector2(0.18, 0.03), Vector2(0.14, 0.066), Vector2(0.0, 0.07), Vector2(0.02, 0.04)]],
		["s", 3, [Vector2(0.31, -0.036), Vector2(0.26, -0.078), Vector2(0.14, -0.084), Vector2(0.08, -0.05)]],
		["s", 1, [Vector2(-0.30, 0.054), Vector2(-0.37, 0.095), Vector2(-0.41, 0.05)]],
		["s", 0, [Vector2(-0.25, -0.046), Vector2(-0.36, -0.20), Vector2(-0.46, -0.20), Vector2(-0.45, -0.03)]],
		["s", 4, [Vector2(-0.46, -0.026), Vector2(-0.51, -0.022), Vector2(-0.51, 0.026), Vector2(-0.46, 0.032)]],
		["s", 5, [Vector2(-0.51, -0.02), Vector2(-0.78, 0.002), Vector2(-0.51, 0.02)]],
	],
	"bomber": [  # swept-wing bomber, engines in belly nacelles
		["p", 0, [Vector2(0.14, 0.0), Vector2(-0.22, 0.5), Vector2(-0.36, 0.5), Vector2(-0.32, 0.0)]],
		["p", 0, [Vector2(-0.40, 0.0), Vector2(-0.50, 0.2), Vector2(-0.55, 0.2), Vector2(-0.52, 0.0)]],
		["s", 0, [Vector2(0.50, 0.0), Vector2(0.43, -0.02), Vector2(0.32, -0.04), Vector2(0.10, -0.052), Vector2(-0.30, -0.052), Vector2(-0.48, -0.032), Vector2(-0.50, 0.0),
			Vector2(-0.48, 0.04), Vector2(-0.30, 0.056), Vector2(0.10, 0.056), Vector2(0.30, 0.036), Vector2(0.42, 0.016)]],
		["s", 1, [Vector2(-0.05, 0.03), Vector2(-0.06, 0.085), Vector2(-0.40, 0.09), Vector2(-0.46, 0.055), Vector2(-0.42, 0.03)]],
		["s", 2, [Vector2(-0.05, 0.04), Vector2(-0.06, 0.085), Vector2(-0.10, 0.085), Vector2(-0.09, 0.04)]],
		["s", 3, [Vector2(0.40, -0.026), Vector2(0.34, -0.052), Vector2(0.26, -0.055), Vector2(0.22, -0.04)]],
		["s", 0, [Vector2(-0.30, -0.05), Vector2(-0.43, -0.17), Vector2(-0.51, -0.17), Vector2(-0.49, -0.04)]],
		["s", 4, [Vector2(-0.43, 0.05), Vector2(-0.49, 0.055), Vector2(-0.49, 0.085), Vector2(-0.43, 0.088)]],
		["s", 5, [Vector2(-0.49, 0.058), Vector2(-0.78, 0.07), Vector2(-0.49, 0.082)]],
	],
	"liner": [  # airliner: tube fuselage, window row, underwing engines, tall fin
		["p", 0, [Vector2(0.10, 0.0), Vector2(-0.18, 0.46), Vector2(-0.27, 0.46), Vector2(-0.22, 0.0)]],
		["p", 0, [Vector2(-0.38, 0.0), Vector2(-0.49, 0.17), Vector2(-0.53, 0.17), Vector2(-0.51, 0.0)]],
		["s", 0, [Vector2(0.50, 0.006), Vector2(0.46, -0.026), Vector2(0.40, -0.046), Vector2(0.30, -0.054), Vector2(-0.25, -0.054), Vector2(-0.36, -0.046), Vector2(-0.50, -0.02),
			Vector2(-0.50, -0.004), Vector2(-0.38, 0.022), Vector2(-0.2, 0.05), Vector2(0.30, 0.054), Vector2(0.42, 0.036)]],
		["s", 6, [Vector2(0.36, -0.024), Vector2(-0.30, -0.024), Vector2(-0.30, -0.016), Vector2(0.36, -0.016)]],
		["s", 3, [Vector2(0.43, -0.034), Vector2(0.47, -0.022), Vector2(0.45, -0.012), Vector2(0.41, -0.026)]],
		["s", 1, [Vector2(0.10, 0.03), Vector2(0.075, 0.078), Vector2(-0.02, 0.084), Vector2(-0.12, 0.078), Vector2(-0.12, 0.03)]],
		["s", 2, [Vector2(0.10, 0.034), Vector2(0.078, 0.078), Vector2(0.05, 0.078), Vector2(0.06, 0.034)]],
		["s", 0, [Vector2(-0.30, -0.052), Vector2(-0.41, -0.20), Vector2(-0.49, -0.20), Vector2(-0.47, -0.034)]],
		["s", 4, [Vector2(-0.12, 0.036), Vector2(-0.15, 0.038), Vector2(-0.15, 0.074), Vector2(-0.12, 0.076)]],
	],
	"uav": [  # long-wing surveillance drone: bulbous nose, sensor ball, pusher prop
		["p", 0, [Vector2(0.06, 0.0), Vector2(0.02, 0.9), Vector2(-0.08, 0.9), Vector2(-0.10, 0.0)]],
		["p", 0, [Vector2(-0.38, 0.0), Vector2(-0.44, 0.2), Vector2(-0.48, 0.2), Vector2(-0.46, 0.0)]],
		["s", 0, [Vector2(0.50, 0.02), Vector2(0.46, -0.02), Vector2(0.38, -0.045), Vector2(0.25, -0.05), Vector2(-0.10, -0.03), Vector2(-0.40, -0.012), Vector2(-0.42, 0.01),
			Vector2(-0.10, 0.035), Vector2(0.20, 0.055), Vector2(0.40, 0.05)]],
		["s", 1, [Vector2(0.44, 0.05), Vector2(0.47, 0.07), Vector2(0.44, 0.095), Vector2(0.40, 0.075)]],
		["s", 0, [Vector2(-0.36, 0.0), Vector2(-0.44, 0.13), Vector2(-0.50, 0.13), Vector2(-0.43, 0.0)]],
		["s", 4, [Vector2(-0.42, -0.01), Vector2(-0.45, -0.008), Vector2(-0.45, 0.01), Vector2(-0.42, 0.012)]],
		["s", 7, [Vector2(-0.45, -0.07), Vector2(-0.44, 0.0), Vector2(-0.45, 0.07), Vector2(-0.46, 0.0)]],
	],
}

# part = [shade, points, mirrored]; x = lateral, y = down
const FRONT := {
	"jet": [
		[0, [Vector2(0.0, -0.012), Vector2(0.46, 0.012), Vector2(0.46, 0.02), Vector2(0.0, 0.02)], true],
		[0, [Vector2(-0.045, -0.02), Vector2(-0.025, -0.05), Vector2(0.025, -0.05), Vector2(0.045, -0.02), Vector2(0.045, 0.03), Vector2(0.0, 0.055), Vector2(-0.045, 0.03)], false],
		[1, [Vector2(0.02, 0.0), Vector2(0.07, 0.0), Vector2(0.075, 0.04), Vector2(0.02, 0.045)], true],
		[0, [Vector2(0.06, -0.03), Vector2(0.09, -0.2), Vector2(0.105, -0.2), Vector2(0.09, -0.03)], true],
		[3, [Vector2(-0.018, -0.046), Vector2(0.0, -0.075), Vector2(0.018, -0.046)], false],
	],
	"ally": [
		[0, [Vector2(0.0, -0.012), Vector2(0.33, 0.012), Vector2(0.33, 0.02), Vector2(0.0, 0.02)], true],
		[0, [Vector2(-0.04, -0.02), Vector2(-0.025, -0.05), Vector2(0.025, -0.05), Vector2(0.04, -0.02), Vector2(0.04, 0.03), Vector2(0.0, 0.06), Vector2(-0.04, 0.03)], false],
		[1, [Vector2(-0.04, 0.02), Vector2(0.04, 0.02), Vector2(0.035, 0.065), Vector2(-0.035, 0.065)], false],
		[0, [Vector2(-0.012, -0.045), Vector2(-0.014, -0.21), Vector2(0.014, -0.21), Vector2(0.012, -0.045)], false],
		[3, [Vector2(-0.018, -0.046), Vector2(0.0, -0.08), Vector2(0.018, -0.046)], false],
	],
	"bomber": [
		[0, [Vector2(0.0, -0.012), Vector2(0.5, 0.015), Vector2(0.5, 0.024), Vector2(0.0, 0.022)], true],
		[1, [Vector2(0.1, 0.02), Vector2(0.16, 0.02), Vector2(0.16, 0.075), Vector2(0.1, 0.075)], true],
		[0, [Vector2(-0.05, -0.02), Vector2(-0.03, -0.052), Vector2(0.03, -0.052), Vector2(0.05, -0.02), Vector2(0.05, 0.035), Vector2(0.0, 0.06), Vector2(-0.05, 0.035)], false],
		[0, [Vector2(-0.012, -0.05), Vector2(-0.016, -0.18), Vector2(0.016, -0.18), Vector2(0.012, -0.05)], false],
		[3, [Vector2(-0.02, -0.046), Vector2(0.0, -0.07), Vector2(0.02, -0.046)], false],
	],
	"liner": [
		[0, [Vector2(0.0, 0.0), Vector2(0.46, -0.03), Vector2(0.46, -0.018), Vector2(0.0, 0.025)], true],
		[1, [Vector2(0.12, 0.01), Vector2(0.19, 0.01), Vector2(0.19, 0.075), Vector2(0.12, 0.075)], true],
		[0, [Vector2(-0.03, -0.054), Vector2(0.03, -0.054), Vector2(0.055, -0.02), Vector2(0.055, 0.02), Vector2(0.03, 0.054), Vector2(-0.03, 0.054), Vector2(-0.055, 0.02), Vector2(-0.055, -0.02)], false],
		[0, [Vector2(-0.012, -0.05), Vector2(-0.016, -0.2), Vector2(0.016, -0.2), Vector2(0.012, -0.05)], false],
		[3, [Vector2(-0.02, -0.046), Vector2(0.02, -0.046), Vector2(0.02, -0.026), Vector2(-0.02, -0.026)], false],
	],
	"uav": [
		[0, [Vector2(0.0, -0.01), Vector2(0.9, 0.0), Vector2(0.9, 0.015), Vector2(0.0, 0.012)], true],
		[0, [Vector2(-0.03, -0.02), Vector2(0.03, -0.02), Vector2(0.035, 0.02), Vector2(0.0, 0.05), Vector2(-0.035, 0.02)], false],
		[1, [Vector2(0.0, 0.0), Vector2(0.16, 0.1), Vector2(0.18, 0.1), Vector2(0.03, 0.0)], true],
	],
}


# Underside planform (looking up at an aircraft almost overhead): one half, mirrored about the centreline.
# part = [shade, points]; x forward, y = half-width
const PLAN := {
	"jet": [
		[0, [Vector2(0.14, 0.04), Vector2(-0.16, 0.46), Vector2(-0.30, 0.46), Vector2(-0.27, 0.05)]],
		[0, [Vector2(-0.34, 0.03), Vector2(-0.46, 0.2), Vector2(-0.52, 0.2), Vector2(-0.48, 0.03)]],
		[0, [Vector2(0.5, 0.0), Vector2(0.42, 0.015), Vector2(0.3, 0.04), Vector2(0.1, 0.055), Vector2(-0.2, 0.055), Vector2(-0.45, 0.045), Vector2(-0.5, 0.03), Vector2(-0.5, 0.0)]],
		[1, [Vector2(0.2, 0.03), Vector2(0.18, 0.06), Vector2(0.0, 0.06), Vector2(0.0, 0.03)]],
		[3, [Vector2(0.34, 0.0), Vector2(0.3, 0.02), Vector2(0.18, 0.022), Vector2(0.12, 0.0)]],
		[4, [Vector2(-0.5, 0.012), Vector2(-0.54, 0.018), Vector2(-0.54, 0.042), Vector2(-0.5, 0.042)]],
	],
	"ally": [
		[0, [Vector2(0.06, 0.04), Vector2(-0.20, 0.34), Vector2(-0.33, 0.34), Vector2(-0.33, 0.05)]],
		[0, [Vector2(-0.36, 0.03), Vector2(-0.46, 0.15), Vector2(-0.51, 0.15), Vector2(-0.49, 0.03)]],
		[0, [Vector2(0.5, 0.0), Vector2(0.42, 0.014), Vector2(0.3, 0.035), Vector2(0.1, 0.05), Vector2(-0.2, 0.05), Vector2(-0.46, 0.035), Vector2(-0.48, 0.0)]],
		[1, [Vector2(0.18, 0.0), Vector2(0.16, 0.04), Vector2(0.0, 0.04), Vector2(0.0, 0.0)]],
		[3, [Vector2(0.31, 0.0), Vector2(0.27, 0.025), Vector2(0.14, 0.028), Vector2(0.08, 0.0)]],
		[4, [Vector2(-0.48, 0.0), Vector2(-0.52, 0.01), Vector2(-0.52, 0.03), Vector2(-0.48, 0.03)]],
	],
	"bomber": [
		[0, [Vector2(0.14, 0.05), Vector2(-0.22, 0.5), Vector2(-0.36, 0.5), Vector2(-0.32, 0.05)]],
		[0, [Vector2(-0.40, 0.04), Vector2(-0.5, 0.2), Vector2(-0.55, 0.2), Vector2(-0.52, 0.04)]],
		[0, [Vector2(0.5, 0.0), Vector2(0.43, 0.02), Vector2(0.32, 0.045), Vector2(0.1, 0.06), Vector2(-0.3, 0.06), Vector2(-0.48, 0.04), Vector2(-0.5, 0.0)]],
		[1, [Vector2(-0.05, 0.1), Vector2(-0.44, 0.1), Vector2(-0.44, 0.16), Vector2(-0.05, 0.16)]],
		[3, [Vector2(0.4, 0.0), Vector2(0.34, 0.025), Vector2(0.26, 0.028), Vector2(0.22, 0.0)]],
		[4, [Vector2(-0.44, 0.11), Vector2(-0.49, 0.115), Vector2(-0.49, 0.155), Vector2(-0.44, 0.155)]],
	],
	"liner": [
		[0, [Vector2(0.10, 0.05), Vector2(-0.18, 0.46), Vector2(-0.27, 0.46), Vector2(-0.22, 0.05)]],
		[0, [Vector2(-0.38, 0.03), Vector2(-0.49, 0.17), Vector2(-0.53, 0.17), Vector2(-0.51, 0.03)]],
		[0, [Vector2(0.5, 0.0), Vector2(0.46, 0.02), Vector2(0.38, 0.045), Vector2(0.3, 0.052), Vector2(-0.25, 0.052), Vector2(-0.4, 0.03), Vector2(-0.5, 0.012), Vector2(-0.5, 0.0)]],
		[1, [Vector2(0.12, 0.16), Vector2(0.12, 0.2), Vector2(-0.04, 0.2), Vector2(-0.04, 0.16)]],
		[2, [Vector2(0.12, 0.16), Vector2(0.12, 0.2), Vector2(0.09, 0.2), Vector2(0.09, 0.16)]],
		[3, [Vector2(0.47, 0.0), Vector2(0.44, 0.02), Vector2(0.4, 0.02), Vector2(0.4, 0.0)]],
	],
	"uav": [
		[0, [Vector2(0.06, 0.02), Vector2(0.02, 0.9), Vector2(-0.08, 0.9), Vector2(-0.10, 0.02)]],
		[0, [Vector2(-0.38, 0.01), Vector2(-0.44, 0.2), Vector2(-0.48, 0.2), Vector2(-0.46, 0.01)]],
		[0, [Vector2(0.5, 0.0), Vector2(0.46, 0.02), Vector2(0.38, 0.035), Vector2(-0.1, 0.025), Vector2(-0.4, 0.012), Vector2(-0.42, 0.0)]],
		[3, [Vector2(0.4, 0.0), Vector2(0.36, 0.02), Vector2(0.3, 0.022), Vector2(0.28, 0.0)]],
	],
}


static func _hash(n: float) -> float:
	return fposmod(sin(n * 12.9898) * 43758.5453, 1.0)


static func _tint(shade: int, pal: Dictionary) -> Color:
	match shade:
		1: return pal.dark
		2: return pal.light
		3: return pal.glass
		4: return pal.hot
		5: return pal.plume
		6: return pal.window
		7: return Color(pal.dark, 0.3)
		_: return pal.base


## pal: base/dark/light/glass/hot/plume/window colours (already polarity-corrected for IR).
## s = length in px, face = +1/-1 (nose direction on screen), lat = |sin(angle between heading and line of sight)|,
## ap = how much of the underside planform is visible (0.12 low elevation .. 1 overhead), rear = flying away.
static func draw(c: Control, shape: String, q: Vector2, s: float, face: float, lat: float, ap: float, pal: Dictionary,
		ir: bool, hot: float, rear: bool, t: float, seed: int, underside := false, rot := 0.0) -> void:
	if shape == "bird":
		_flock(c, q, s, pal, t, seed)
		return
	if s < 10.0:
		return
	var plume_on := ir and hot > 0.6
	if underside:  # almost overhead: we see the underside; `rot` is the heading as it appears on screen
		var cs := cos(rot)
		var sn := sin(rot)
		for part in PLAN[shape]:
			for sign in [-1.0, 1.0]:
				var pts := PackedVector2Array()
				for p: Vector2 in part[1]:
					var u: float = p.x * s
					var w: float = p.y * sign * s
					pts.append(q + Vector2(u * cs - w * sn, u * sn + w * cs))
				if sign < 0.0:
					pts.reverse()
				c.draw_colored_polygon(pts, _tint(part[0], pal))
		return
	if lat < 0.3:  # nose-on / tail-on
		for part in FRONT[shape]:
			var pts := PackedVector2Array()
			for p: Vector2 in part[1]:
				pts.append(q + Vector2(p.x * s, p.y * s))
			c.draw_colored_polygon(pts, _tint(part[0], pal))
			if part[2]:
				var m := PackedVector2Array()
				for p: Vector2 in part[1]:
					m.append(q + Vector2(-p.x * s, p.y * s))
				m.reverse()
				c.draw_colored_polygon(m, _tint(part[0], pal))
		if rear and (plume_on or hot > 0.4):
			c.draw_circle(q + Vector2(0, s * 0.01), maxf(s * 0.04, 2.0), pal.hot)
		return
	var sx := s * maxf(lat, 0.3)
	var apv := clampf(ap, 0.12, 0.55)
	for part in SIDE[shape]:
		var shade: int = part[1]
		if shade == 5 and not plume_on:
			continue
		var col := _tint(shade, pal)
		if shade == 5:
			col = Color(col, 0.55)
		var plan: bool = part[0] == "p"
		for sign in ([-1.0, 1.0] if plan else [1.0]):
			var pts := PackedVector2Array()
			for p: Vector2 in part[2]:
				pts.append(q + Vector2(p.x * face * sx, (p.y * sign * s * apv) if plan else (p.y * s)))
			if plan and sign < 0.0:
				pts.reverse()  # keep winding consistent for the mirrored copy
			c.draw_colored_polygon(pts, col)
	if s > 40.0:  # fuselage outline for crispness at close range
		for part in SIDE[shape]:
			if part[0] == "s" and part[1] == 0:
				var o := PackedVector2Array()
				for p: Vector2 in part[2]:
					o.append(q + Vector2(p.x * face * sx, p.y * s))
				o.append(o[0])
				c.draw_polyline(o, Color(pal.dark, 0.9), 1.0)
				break
	if ir and hot > 0.4:  # engine glow
		c.draw_circle(q + Vector2(-0.5 * face * sx, 0.0), maxf(s * 0.03, 2.0), Color(pal.hot, 0.6))


static func _flock(c: Control, q: Vector2, s: float, pal: Dictionary, t: float, seed: int) -> void:
	var b := maxf(s, 3.0)  # one bird, px
	var spread := b * 18.0
	for i in 9:
		var off := Vector2((_hash(seed * 13.0 + i) - 0.5) * 2.0 * spread, (_hash(seed * 7.0 + i * 3.0) - 0.5) * spread)
		var fl := sin(t * 9.0 + i * 1.7) * 0.45
		var p0 := q + off
		var w := 2.0 if b > 8.0 else 1.0
		c.draw_polyline(PackedVector2Array([p0 + Vector2(-b * 0.5, -fl * b * 0.5), p0 + Vector2(-b * 0.22, -fl * b * 0.2 - b * 0.04),
			p0, p0 + Vector2(b * 0.22, -fl * b * 0.2 - b * 0.04), p0 + Vector2(b * 0.5, -fl * b * 0.5)]), pal.base, w)
