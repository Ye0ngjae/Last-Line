class_name FireStation
extends Station
## Fire-control operator: engagement display (tracks + missiles), ARM and LAUNCH.

const RANGE_M := 25000.0
var armed := false
var launch_btn: Button


func _build() -> void:
	UI.label(panel, "FIRE CONTROL", UI.AMBER)
	var hint := UI.label(panel, "Select a track. You may fire on any track the radar/EO operator designated HOSTILE (or HQ declared). Wrong calls are judged after the strike.", UI.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a long unwrapped label would widen the whole panel
	UI.button(panel, "MASTER ARM", func(on: bool): armed = on, true, "clunk")
	launch_btn = UI.button(panel, "LAUNCH", _launch, false, "clunk")
	launch_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	UI.button(panel, "SELF-DESTRUCT MISSILES", func(): sim.abort_missiles(), false, "clunk")


func _launch() -> void:
	sim.launch(sim.sel_trk)
	armed = false


func tick(dt: float) -> void:
	super(dt)
	var why := sim.launch_check(sim.sel_trk)
	launch_btn.disabled = not armed or why != ""
	var tr: Dictionary = sim.radar.tracks.get(sim.sel_trk, {})
	var line := "NO TRACK SELECTED"
	if not tr.is_empty():
		var p := sim.trk_pos(tr)
		line = "TRK %d  IFF %s\nRNG %.1f km  ALT %d m\nCLASS %s" % [sim.sel_trk, tr.iff, sim.site.distance_to(p) / 1000.0,
			roundi(float(tr.alt)), "UNKNOWN" if int(tr.cls) < 0 else Target.KIND_NAMES[int(tr.cls)]]
	info.text = "%s\n\nMISSILES %d\nARM %s\nLAUNCH: %s" % [line, sim.missiles_left, "ON" if armed else "SAFE", "READY" if why == "" else why]


func _draw_screen() -> void:
	var c := screen.size * 0.5
	var rad := minf(screen.size.x, screen.size.y) * 0.5 - 18.0
	ppi_background(c, rad, RANGE_M)
	draw_tracks(c, rad, RANGE_M)
	for w: Dictionary in sim.msl_wakes:  # finished flights fade out; end marker shows the outcome
		var al := clampf(1.0 - (sim.t - float(w.t)) / 15.0, 0.0, 1.0)
		var pts := _px_list(w.pts, c, rad)
		if pts.size() >= 2:
			screen.draw_polyline(pts, Color(1, 0.6, 0.2, al * 0.6), 1.5)
		var e: Vector2 = pts[pts.size() - 1]
		match w.key:
			"":
				var ring := clampf((sim.t - float(w.t)) / 1.2, 0.0, 1.0)  # expanding shock ring
				if ring < 1.0:
					screen.draw_arc(e, 8.0 + ring * 22.0, 0, TAU, 24, Color(1, 0.7, 0.3, 1.0 - ring), 2.0)
				screen.draw_line(e - Vector2(7, 7), e + Vector2(7, 7), Color(1, 0.3, 0.2, al), 2.0)
				screen.draw_line(e - Vector2(7, -7), e + Vector2(7, -7), Color(1, 0.3, 0.2, al), 2.0)
			"terrain":
				screen.draw_rect(Rect2(e - Vector2(4, 4), Vector2(8, 8)), Color(0.7, 0.6, 0.4, al), false, 2.0)
			_:
				screen.draw_arc(e, 6, 0, TAU, 12, Color(0.7, 0.7, 0.7, al), 2.0)
	for m: Dictionary in sim.missiles:
		var q := c + (Vector2(m.pos) - sim.site) / RANGE_M * rad
		var trail: Array = m.trail.duplicate()
		var mpos: Vector2 = m.pos
		trail.append(Vector4(mpos.x, mpos.y, float(m.alt), sim.t))
		var pts := _px_list(trail, c, rad)
		if pts.size() >= 2:
			screen.draw_polyline(pts, Color(1, 0.75, 0.3, 0.95), 2.0)
		var h: float = m.h
		var fwd := Vector2(sin(h), -cos(h))
		var side := Vector2(-fwd.y, fwd.x)
		screen.draw_colored_polygon(PackedVector2Array([q + fwd * 8, q - fwd * 5 + side * 4, q - fwd * 5 - side * 4]), Color(1, 0.9, 0.5))
		text(q + Vector2(9, 12), "M %d s" % int(m.age), Color(1, 0.8, 0.4), 11)
	screen.draw_circle(c, 4, UI.AMBER)
	text(Vector2(8, 18), "ENGAGEMENT DISPLAY  %d km" % (RANGE_M / 1000.0), UI.GREEN)


func _screen_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := ev as InputEventMouseButton
		var c := screen.size * 0.5
		var rad := minf(screen.size.x, screen.size.y) * 0.5 - 18.0
		var n := sim.nearest_track(sim.site + (mb.position - c) / rad * RANGE_M, 16.0 / rad * RANGE_M)
		if n >= 0:
			sim.sel_trk = n


func _px_list(world_pts: Array, c: Vector2, rad: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector4 in world_pts:
		out.append(c + (Vector2(p.x, p.y) - sim.site) / RANGE_M * rad)
	return out
