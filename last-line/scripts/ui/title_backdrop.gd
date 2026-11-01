class_name TitleBackdrop
extends Control
## Animated main-menu backdrop: a drifting contour map, a rotating radar scope with blips and tracks,
## aircraft crossing with contrails, HUD brackets, and a typewriter radio ticker. Only redraws while visible.

const PLANES := [  # shape, start (fraction of screen), end, seconds per crossing, phase
	["jet", Vector2(-0.1, 0.78), Vector2(1.1, 0.22), 26.0, 0.15],
	["liner", Vector2(1.1, 0.12), Vector2(-0.1, 0.55), 52.0, 0.6],
	["bomber", Vector2(-0.1, 0.35), Vector2(1.1, 0.9), 38.0, 0.85],
]
const BLIPS := [  # angle (rad), radius fraction, drift (rad/s), tracked label
	[0.6, 0.35, 0.02, "T1"], [1.4, 0.62, -0.015, ""], [2.3, 0.48, 0.01, "T2"], [3.4, 0.78, 0.0, ""],
	[4.1, 0.28, 0.03, ""], [4.9, 0.7, -0.02, ""], [5.6, 0.52, 0.015, ""],
]

var _t := 0.0
var _tex: ImageTexture
var _lines: Array = []
var font := ThemeDB.fallback_font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := WorldGen.new()
	w.generate(4242, "Highlands")
	_tex = ImageTexture.create_from_image(w.topo_image())
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for l in Radio.AMBIENT:
		_lines.append("[%s] %s" % [l[0], l[1]])
	for k in ["track_new", "launch", "kill_h", "ducting"]:
		var l: Array = Radio.LINES[k][0]
		_lines.append("[%s] %s" % [l[0], String(l[1]).format({"n": 3})])


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.015, 0.03, 0.045))
	var side := maxf(sz.x, sz.y) * 1.35  # slowly drifting terrain contours
	var off := Vector2(-side * 0.15 + cos(_t * 0.03) * 70.0, -side * 0.25 + sin(_t * 0.04) * 55.0)
	draw_texture_rect(_tex, Rect2(off, Vector2(side, side)), false, Color(0.28, 0.6, 0.4, 0.3))
	_draw_scope(sz)
	_draw_planes(sz)
	_draw_overlay(sz)


func _draw_scope(sz: Vector2) -> void:
	var c := Vector2(sz.x * 0.7, sz.y * 0.5)
	var rad := minf(sz.x * 0.33, sz.y * 0.43)
	draw_circle(c, rad, Color(0.01, 0.05, 0.04, 0.55))
	var ring := Color(0.3, 0.55, 0.85, 0.45)
	for i in range(1, 5):
		draw_arc(c, rad * i / 4.0, 0, TAU, 96, ring, 1.0)
	draw_arc(c, rad, 0, TAU, 128, Color(0.4, 0.7, 1.0, 0.8), 2.0)
	for a in range(0, 360, 10):
		var dir := Vector2(sin(deg_to_rad(a)), -cos(deg_to_rad(a)))
		draw_line(c + dir * rad, c + dir * (rad + (12.0 if a % 30 == 0 else 5.0)), ring, 1.0)
		if a % 30 == 0:
			draw_line(c, c + dir * rad, Color(0.2, 0.4, 0.6, 0.25), 1.0)
			draw_string(font, c + dir * (rad + 26.0) - Vector2(12, -4), "%03d" % a, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.65, 0.8, 0.8))
	var sweep := fposmod(_t * 0.9, TAU)
	for i in 48:  # sweep wedge with falloff
		var a := sweep - i * 0.012
		draw_line(c, c + Vector2(sin(a), -cos(a)) * rad, Color(0.3, 1.0, 0.45, 0.42 * (1.0 - float(i) / 48.0)), 3.0)
	draw_line(c, c + Vector2(sin(sweep), -cos(sweep)) * rad, Color(0.6, 1.0, 0.7, 0.9), 2.0)
	for b in BLIPS:  # echoes light up as the beam passes and fade over a revolution
		var ang: float = float(b[0]) + float(b[2]) * _t
		var p := c + Vector2(sin(ang), -cos(ang)) * rad * float(b[1])
		var behind := fposmod(sweep - fposmod(ang, TAU), TAU) / TAU
		var al := exp(-behind * 2.6)
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.5, 1.0, 0.6, al))
		draw_circle(p, 7.0 + 6.0 * (1.0 - behind), Color(0.4, 1.0, 0.5, 0.25 * al))
		if String(b[3]) != "":
			var v := Vector2(cos(ang) * 0.3, sin(ang) * 0.3)
			draw_rect(Rect2(p - Vector2(8, 8), Vector2(16, 16)), Color(1.0, 0.8, 0.2, 0.35 + 0.65 * al), false, 1.5)
			draw_line(p, p + v * 60.0, Color(1.0, 0.8, 0.2, 0.35 + 0.65 * al), 1.5)
			draw_string(font, p + Vector2(12, -10), String(b[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.8, 0.2, 0.5 + 0.5 * al))


func _draw_planes(sz: Vector2) -> void:
	var pal := {"base": Color(0.75, 0.92, 0.8, 0.55), "dark": Color(0.55, 0.75, 0.62, 0.55), "light": Color(0.85, 1.0, 0.9, 0.55),
		"glass": Color(0.5, 0.7, 0.8, 0.55), "hot": Color(1.0, 0.8, 0.5, 0.7), "plume": Color(0, 0, 0, 0), "window": Color(0.8, 0.9, 0.9, 0.55)}
	for p in PLANES:
		var u := fposmod(_t / float(p[3]) + float(p[4]), 1.0)
		var a: Vector2 = Vector2(p[1]) * sz
		var b: Vector2 = Vector2(p[2]) * sz
		var pos := a.lerp(b, u)
		var dir := (b - a).normalized()
		for i in range(1, 22):  # contrail
			var tp := pos - dir * (float(i) * 14.0)
			draw_circle(tp, 1.5 + i * 0.25, Color(0.85, 0.95, 0.9, 0.26 * (1.0 - float(i) / 22.0)))
		AircraftArt.draw(self, p[0], pos, 58.0, 1.0, 1.0, 1.0, pal, false, 0.5, false, _t, 1, true, dir.angle())


func _draw_overlay(sz: Vector2) -> void:
	for i in 10:  # vignette
		var a := 0.07 * float(10 - i) / 10.0
		draw_rect(Rect2(0, 0, sz.x, 22.0 * (i + 1)), Color(0, 0, 0, a * 0.7))
		draw_rect(Rect2(0, sz.y - 22.0 * (i + 1), sz.x, 22.0 * (i + 1)), Color(0, 0, 0, a))
		draw_rect(Rect2(0, 0, 30.0 * (i + 1), sz.y), Color(0, 0, 0, a))
		draw_rect(Rect2(sz.x - 30.0 * (i + 1), 0, 30.0 * (i + 1), sz.y), Color(0, 0, 0, a * 0.6))
	var y := 0.0
	while y < sz.y:  # scanlines
		draw_line(Vector2(0, y), Vector2(sz.x, y), Color(0, 0, 0, 0.1))
		y += 3.0
	var am := Color(1.0, 0.75, 0.2, 0.85)  # HUD corner brackets
	var m := 26.0
	var l := 38.0
	for corner in [Vector2(m, m), Vector2(sz.x - m, m), Vector2(m, sz.y - m), Vector2(sz.x - m, sz.y - m)]:
		var sx := 1.0 if corner.x < sz.x * 0.5 else -1.0
		var sy := 1.0 if corner.y < sz.y * 0.5 else -1.0
		draw_line(corner, corner + Vector2(l * sx, 0), am, 2.0)
		draw_line(corner, corner + Vector2(0, l * sy), am, 2.0)
	draw_string(font, Vector2(m + 14, m + 22), "AIR DEFENCE OPERATOR SIMULATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.8, 0.65, 0.8))
	var s := int(_t) + 43200
	draw_string(font, Vector2(sz.x - m - 190, m + 22), "SYS %02d:%02d:%02d  READY" % [s / 3600 % 24, s / 60 % 60, s % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.8, 0.65, 0.8))
	if not _lines.is_empty():  # typewriter radio ticker
		var idx := int(_t / 7.0) % _lines.size()
		var line: String = _lines[idx]
		var chars := clampi(int(fposmod(_t, 7.0) * 30.0), 0, line.length())
		var cursor := "_" if int(_t * 2.0) % 2 == 0 else ""
		draw_rect(Rect2(m, sz.y - m - 44, sz.x - m * 2, 30), Color(0, 0, 0, 0.45))
		draw_string(font, Vector2(m + 12, sz.y - m - 23), "RADIO > " + line.substr(0, chars) + cursor, HORIZONTAL_ALIGNMENT_LEFT, sz.x - m * 2 - 24, 16, Color(0.7, 1.0, 0.75, 0.95))
