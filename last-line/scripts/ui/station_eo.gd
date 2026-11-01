class_name EOStation
extends Station
## EO/IR turret operator: TV/thermal view with terrain horizon + tree line, slew, zoom, lock, LRF, report.

const COLS := 128
const MAXR := 35000.0
const DEG := 57.2958
var s_col := PackedInt32Array()
var s_lo := PackedFloat32Array()
var s_hi := PackedFloat32Array()
var s_r := PackedFloat32Array()
var s_tree := PackedFloat32Array()
var s_color := PackedColorArray()
var s_az := 0.0
var _key := ""
var _cool := 0.0
var s_fov := 14.0
var _slew := Vector2.ZERO
var _zoom := 0.0  # +1 zooming in, -1 out (held button)
var pip: RadarView


func _build() -> void:
	UI.label(panel, "EO OPERATOR", UI.AMBER)
	var hb := HBoxContainer.new()
	panel.add_child(hb)
	UI.button(hb, "TV/IR", func(on: bool): sim.eo.ir = on, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button(hb, "WHT/BLK", func(on: bool): sim.eo.white_hot = not on, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var zb := HBoxContainer.new()
	panel.add_child(zb)
	for i in Sim.FOVS.size():
		UI.button(zb, ["WIDE", "MED", "NAR"][i], func(): sim.eo.fov = Sim.FOVS[i]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var zz := HBoxContainer.new()
	panel.add_child(zz)
	for cell in [["ZOOM -", -1.0], ["ZOOM +", 1.0]]:
		var dirz: float = cell[1]
		var zbtn := UI.button(zz, cell[0], func(): pass)
		zbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zbtn.button_down.connect(func(): _zoom = dirz)
		zbtn.button_up.connect(func(): _zoom = 0.0)
	var pad := GridContainer.new()
	pad.columns = 3
	panel.add_child(pad)
	for cell in [["", Vector2.ZERO], ["UP", Vector2(0, 1)], ["", Vector2.ZERO], ["<", Vector2(-1, 0)], ["", Vector2.ZERO],
			[">", Vector2(1, 0)], ["", Vector2.ZERO], ["DN", Vector2(0, -1)], ["", Vector2.ZERO]]:
		if cell[0] == "":
			pad.add_child(Control.new())
			continue
		var v: Vector2 = cell[1]
		var b := UI.button(pad, cell[0], func(): pass)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_down.connect(func(): _slew = v)
		b.button_up.connect(func(): _slew = Vector2.ZERO)
	UI.label(panel, "Click view: slew / pick target", UI.DIM)
	UI.button(panel, "LOCK TARGET", func(): sim.eo_lock())
	UI.button(panel, "FREE", func():
		sim.eo.lock = -1
		sim.eo.slave = -1)
	UI.button(panel, "LASER RANGE", func(): sim.eo_lrf())
	report_buttons(func(k: int): sim.report(sim.eo.sel, k))
	if not sim.eq.radar.is_empty():
		_build_pip()


## Small translucent mirror of the radar operator's scope in the screen corner, with a show/hide button.
func _build_pip() -> void:
	pip = RadarView.new()
	pip.setup(sim, true)
	pip.modulate = Color(1, 1, 1, 0.5)
	pip.anchor_left = 1.0
	pip.anchor_right = 1.0
	pip.anchor_top = 1.0
	pip.anchor_bottom = 1.0
	pip.offset_left = -208
	pip.offset_right = -8
	pip.offset_top = -244
	pip.offset_bottom = -44
	screen.add_child(pip)
	var b := UI.button(screen, "RDR", func(on: bool): pip.visible = on, true)
	b.button_pressed = true
	b.custom_minimum_size = Vector2(56, 26)
	b.modulate = Color(1, 1, 1, 0.7)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = -64
	b.offset_right = -8
	b.offset_top = -34
	b.offset_bottom = -8


func tick(dt: float) -> void:
	super(dt)
	if pip != null and pip.visible:
		pip.tick()
	if _zoom != 0.0:
		sim.eo.fov = clampf(float(sim.eo.fov) * exp(-_zoom * dt * 1.2), Sim.FOV_MIN, Sim.FOV_MAX)
	Sfx.loop("motor", _slew != Vector2.ZERO or _zoom != 0.0)
	if _slew != Vector2.ZERO:
		sim.eo.lock = -1
		sim.eo.slave = -1
		var rate: float = float(sim.eo.fov) * 0.8 + 0.3
		sim.eo.az = fposmod(float(sim.eo.az) + _slew.x * rate * dt, 360.0)
		sim.eo.el = clampf(float(sim.eo.el) + _slew.y * rate * dt, -10.0, 60.0)
	_cool -= dt
	var key := "%.2f|%.2f|%s|%s|%d" % [float(sim.eo.az), float(sim.eo.fov), sim.eo.ir, sim.eo.white_hot, int(sim.daylight() * 30.0)]
	if key != _key and _cool <= 0.0:
		_key = key
		_cool = 0.08
		_rebuild()
	var mode := "LOCK" if sim.eo.lock >= 0 else ("SLAVED T%d" % sim.eo.slave if sim.eo.slave >= 0 else "MANUAL")
	var lrf := "---" if float(sim.eo.lrf) < 0.0 else "%.0f m  ALT %d m" % [sim.eo.lrf, roundi(float(sim.eo.lrf_alt))]
	info.text = "MODE %s\nSEL %s\nLRF %s" % [mode, "-" if sim.eo.sel < 0 else "TGT-%03d" % sim.eo.sel, lrf]


# ---- colours (raw = white-hot / natural; _pol flips for black-hot)

func _pol(c: Color) -> Color:
	return Color(1.0 - c.r, 1.0 - c.g, 1.0 - c.b) if sim.eo.ir and not sim.eo.white_hot else c


func _sky_raw() -> Color:
	if sim.eo.ir:
		return Color(0.1, 0.1, 0.1)
	return Color(0.02, 0.03, 0.08).lerp(Color(0.5, 0.7, 0.95), sim.daylight())


func _ground(biome: int, r: float) -> Color:
	var day := sim.daylight()
	var c: Color
	if sim.eo.ir:
		var g: float = [0.12, 0.38, 0.30, 0.5, 0.34][biome] + 0.1 * day
		c = Color(g, g, g)
	else:
		var base: Color = [Color(0.1, 0.25, 0.4), Color(0.45, 0.5, 0.25), Color(0.12, 0.3, 0.12), Color(0.42, 0.38, 0.34), Color(0.25, 0.4, 0.2)][biome]
		c = base.darkened(0.88 * (1.0 - day))
	return _pol(c.lerp(_sky_raw(), clampf(r / MAXR, 0.0, 1.0) * 0.8))


## Horizon-scan terrain: per column march a ray outward, emit a strip each time the skyline rises.
func _rebuild() -> void:
	s_col.clear(); s_lo.clear(); s_hi.clear(); s_r.clear(); s_tree.clear(); s_color.clear()
	var fov: float = sim.eo.fov
	var cam := sim.cam_alt()
	s_az = sim.eo.az
	s_fov = fov
	for i in COLS:
		var az := deg_to_rad(s_az + ((i + 0.5) / COLS - 0.5) * fov)
		var dir := Vector2(sin(az), -cos(az))
		var maxe := -89.0
		var r := 200.0
		while r < MAXR:
			var p := sim.site + dir * r
			var e := rad_to_deg(atan2(sim.world.elev_at(p) - cam, r))
			if e > maxe:
				s_col.append(i)
				s_lo.append(maxe)
				s_hi.append(e)
				s_r.append(r)
				s_tree.append(sim.world.tree_density(p) if r < 9000.0 else 0.0)
				s_color.append(_ground(sim.world.biome_at(p), r))
				maxe = e
			r += maxf(120.0, r * 0.06)


# ---- projection

func _ppd() -> float:
	return screen.size.x / float(sim.eo.fov)


func _project(tg: Target) -> Vector2:
	var d := tg.pos - sim.site
	var ex := wrapf(sim.bearing_deg(sim.site, tg.pos) - float(sim.eo.az), -180.0, 180.0)
	var ey := rad_to_deg(atan2(tg.alt - sim.cam_alt(), d.length())) - float(sim.eo.el)
	var ppd := _ppd()
	return Vector2(screen.size.x * 0.5 + ex * ppd, screen.size.y * 0.5 - ey * ppd)


func _draw_screen() -> void:
	var W := screen.size.x
	var H := screen.size.y
	var ppd := _ppd()
	var el0: float = sim.eo.el
	var ir: bool = sim.eo.ir
	screen.draw_rect(Rect2(0, 0, W, H), _pol(_sky_raw()))
	var off := wrapf(s_az - float(sim.eo.az), -180.0, 180.0)  # terrain strips are placed by angle so zoom stays smooth
	var cw := s_fov / COLS * ppd
	for k in s_col.size():
		var y_top := H * 0.5 - (s_hi[k] - el0) * ppd
		var y_bot := H * 0.5 - (s_lo[k] - el0) * ppd
		if y_bot < 0.0 or y_top > H:
			continue
		var x := W * 0.5 + (off + (float(s_col[k]) / COLS - 0.5) * s_fov) * ppd
		screen.draw_rect(Rect2(x, y_top, cw + 1.0, y_bot - y_top + 1.0), s_color[k])
		var dens := s_tree[k]
		if dens > 0.0:
			var h := fposmod(sin(float(s_col[k]) * 12.9898 + s_r[k] * 0.0731) * 43758.5453, 1.0)
			if h < dens:
				var th := minf(rad_to_deg(18.0 / s_r[k]) * ppd * (0.5 + h / dens), 40.0)
				screen.draw_rect(Rect2(x, y_top - th, cw + 1.0, th), s_color[k].darkened(0.35))
	for tg: Target in sim.targets:
		if tg.pos.distance_to(sim.site) < 50.0 or not sim.eo_sees(tg):
			continue
		var q := _project(tg)
		if q.x < -40 or q.x > W + 40 or q.y < -40 or q.y > H + 40:
			continue
		_draw_target(tg, q, ppd)
	_draw_missiles(W, H, ppd)
	_draw_overlay(W, H)


## World point -> screen position in this camera (x, y), same projection as targets.
func _proj(p: Vector2, alt: float) -> Vector2:
	var d := p - sim.site
	var ex := wrapf(sim.bearing_deg(sim.site, p) - float(sim.eo.az), -180.0, 180.0)
	var ey := rad_to_deg(atan2(alt - sim.cam_alt(), d.length())) - float(sim.eo.el)
	var ppd := _ppd()
	return Vector2(screen.size.x * 0.5 + ex * ppd, screen.size.y * 0.5 - ey * ppd)


## Missiles seen from the turret: motor glow, a smoke trail that widens and fades, and the burst at the end.
## The camera never leaves the equipment; this is purely what the turret can see.
func _draw_missiles(W: float, H: float, ppd: float) -> void:
	var day := sim.daylight()
	var ir: bool = sim.eo.ir
	var vis: float = sim.wx.vis
	var max_r: float = float(sim.eq.eo.ir_range) * sqrt(vis) if ir else float(sim.eq.eo.tv_range) * (0.08 + 0.92 * day) * vis
	var smoke := Color(0.35, 0.35, 0.35) if ir else (Color(0.92, 0.92, 0.92) if day > 0.3 else Color(0.5, 0.5, 0.55))
	var glow := _pol(Color(1, 1, 1)) if ir else Color(1.0, 0.8, 0.4)
	var lists: Array = []
	for m: Dictionary in sim.missiles:
		lists.append(m.trail)
	for w: Dictionary in sim.msl_wakes:
		lists.append(w.pts)
	for pts: Array in lists:  # smoke puffs, older = bigger and fainter
		for p: Vector4 in pts:
			var age := sim.t - p.w
			if age > 12.0:
				continue
			var pw := Vector2(p.x, p.y)
			var r := pw.distance_to(sim.site)
			if r < 250.0 or r > max_r:
				continue
			var q := _proj(pw, p.z)
			if q.x < -30 or q.x > W + 30 or q.y < -30 or q.y > H + 30:
				continue
			var px := clampf((4.0 + 2.2 * age) / r * DEG * ppd, 1.5, 45.0)
			screen.draw_circle(q, px, Color(smoke, clampf(1.0 - age / 12.0, 0.0, 1.0) * 0.55))
	for m: Dictionary in sim.missiles:  # the missile itself (hot motor)
		var mp: Vector2 = m.pos
		var r := mp.distance_to(sim.site)
		if r < 40.0 or r > max_r:
			continue
		var q := _proj(mp, float(m.alt))
		if q.x < -30 or q.x > W + 30 or q.y < -30 or q.y > H + 30:
			continue
		screen.draw_circle(q, clampf(8.0 / r * DEG * ppd, 4.0, 22.0), Color(glow, 0.3))
		screen.draw_circle(q, 2.5, Color(1, 1, 0.9) if not ir else glow)
	for w: Dictionary in sim.msl_wakes:
		_draw_burst(w, W, H, ppd, max_r, ir)


static func _h(n: float) -> float:
	return fposmod(sin(n * 12.9898) * 43758.5453, 1.0)


## Layered detonation seen from the turret: flash, fireball, shock ring, flying sparks/debris, rising smoke.
## Everything is a function of the burst's age, so it needs no extra simulation state.
func _draw_burst(w: Dictionary, W: float, H: float, ppd: float, max_r: float, ir: bool) -> void:
	var age := sim.t - float(w.t)
	var key: String = w.key
	var kill := key == ""
	var life := 12.0 if kill else (7.0 if key == "terrain" else 4.0)
	if age > life:
		return
	var pts: Array = w.pts
	var e: Vector4 = pts[pts.size() - 1]
	var ep := Vector2(e.x, e.y)
	var r := ep.distance_to(sim.site)
	if r < 250.0 or r > max_r:
		return
	var q := _proj(ep, e.z)
	if q.x < -200 or q.x > W + 200 or q.y < -200 or q.y > H + 200:
		return
	var k := DEG * ppd / r  # pixels per metre at the burst
	var seed := float(w.t) * 31.0
	var hot := Color(1, 1, 1) if ir else Color(1.0, 0.75, 0.3)
	if kill and age < 0.18:  # camera glare
		screen.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 0.92, 0.2 * (1.0 - age / 0.18)))
	var n_puffs := 11 if kill else (7 if key == "terrain" else 4)
	for i in n_puffs:  # smoke / dust column: puffs appear in sequence, rise, swell and fade
		var pa := age - i * (0.12 if kill else 0.1)
		if pa < 0.0:
			continue
		var pl := life - i * 0.3
		if pa > pl:
			continue
		var drift := Vector2((_h(seed + i * 2.3) - 0.5) * 16.0 + pa * 2.5, 0.0)
		var rise := pa * (5.0 if kill else 3.0)
		var rad_m := (12.0 if kill else 8.0) + pa * (7.0 if kill else 5.0)
		var c: Color
		if key == "terrain":
			c = Color(0.55, 0.45, 0.32) if not ir else _pol(Color(0.5, 0.5, 0.5))
		elif ir:
			var g := clampf(1.0 - pa / 6.0, 0.15, 1.0)
			c = _pol(Color(g, g, g))
		else:
			c = Color(0.18, 0.17, 0.16).lerp(Color(0.62, 0.62, 0.62), clampf(pa / 3.0, 0.0, 1.0)) if kill else Color(0.7, 0.7, 0.7)
		var al := 0.55 * (1.0 - pa / pl)
		screen.draw_circle(q + Vector2(drift.x * k, -(rise + 6.0) * k), maxf(rad_m * k, 2.0), Color(c.r, c.g, c.b, al))
	var fb_life := 1.5 if kill else 0.6
	if age < fb_life or (ir and kill and age < 5.0):
		var size_m := (50.0 if kill else 14.0) * (1.0 - exp(-age * 5.0))
		var u := clampf(age / fb_life, 0.0, 1.0)
		if ir:  # thermal: a white-hot ball that cools slowly
			var cool := clampf(1.0 - age / (5.0 if kill else 0.6), 0.0, 1.0)
			screen.draw_circle(q, maxf(size_m * k, 3.0), _pol(Color(1, 1, 1, 0.8 * cool)))
			screen.draw_circle(q, maxf(size_m * k * 0.55, 2.0), _pol(Color(1, 1, 1, cool)))
		else:
			screen.draw_circle(q, maxf(size_m * k * 1.15, 3.0), Color(0.55, 0.15, 0.05, 0.55 * (1.0 - u)))  # dark red rim
			screen.draw_circle(q, maxf(size_m * k, 3.0), Color(1.0, 0.45, 0.1, 0.8 * (1.0 - u * 0.7)))  # orange body
			screen.draw_circle(q, maxf(size_m * k * 0.6 * (1.0 - u * 0.5), 2.0), Color(1.0, 0.85, 0.4, 1.0 - u))  # yellow
			screen.draw_circle(q, maxf(size_m * k * 0.3 * (1.0 - u), 1.5), Color(1, 1, 0.95, 1.0 - u * 0.5))  # white core
	if kill and age < 1.0:  # shock ring
		var ru := age / 1.0
		screen.draw_arc(q, maxf(160.0 * ru * k, 3.0), 0, TAU, 40, Color(1, 1, 1, 0.65 * (1.0 - ru)), 2.0)
	var n_sparks := 16 if kill else 6
	for i in n_sparks:  # sparks and debris: ballistic, with a short glowing tail
		var ang := _h(seed + i * 3.1) * TAU
		var spd := 25.0 + _h(seed + i * 7.7) * 70.0
		var up := (_h(seed + i * 5.3) - 0.3) * spd * 0.9
		var side := cos(ang) * spd
		var sl := 2.2 + _h(seed + i) * 1.2
		if age > sl:
			continue
		for tpos: float in [0.0, 0.06, 0.12]:
			var ta := maxf(age - tpos, 0.0)
			var pp := q + Vector2(side * ta * k, -(up * ta - 4.9 * ta * ta) * k)
			var al := (1.0 - age / sl) * (1.0 - tpos * 4.0)
			var col := hot if ta < 0.6 else (Color(0.25, 0.25, 0.25) if not ir else _pol(Color(0.8, 0.8, 0.8)))
			screen.draw_rect(Rect2(pp - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), Color(col, al))

func _palette(tg: Target) -> Dictionary:
	var v := 0.5 + 0.5 * tg.ir
	if sim.eo.ir:  # thermal: brightness from the heat signature, engines hottest
		return {"base": _pol(Color(v, v, v)), "dark": _pol(Color(v * 0.7, v * 0.7, v * 0.7)), "light": _pol(Color(minf(v * 1.2, 1.0), minf(v * 1.2, 1.0), minf(v * 1.2, 1.0))),
			"glass": _pol(Color(v * 0.4, v * 0.4, v * 0.4)), "hot": _pol(Color(1, 1, 1)), "plume": _pol(Color(1, 1, 1)), "window": _pol(Color(v * 0.85, v * 0.85, v * 0.85))}
	if sim.daylight() > 0.3:  # day TV: dark airframe against the sky, glass catches the sky
		return {"base": Color(0.14, 0.15, 0.17), "dark": Color(0.08, 0.09, 0.1), "light": Color(0.3, 0.32, 0.36), "glass": Color(0.35, 0.46, 0.62),
			"hot": Color(0.1, 0.09, 0.09), "plume": Color(0, 0, 0, 0), "window": Color(0.5, 0.54, 0.6)}
	return {"base": Color(0.35, 0.35, 0.4), "dark": Color(0.25, 0.25, 0.3), "light": Color(0.45, 0.45, 0.5), "glass": Color(0.3, 0.32, 0.4),
		"hot": Color(0.5, 0.35, 0.25), "plume": Color(0, 0, 0, 0), "window": Color(0.5, 0.5, 0.45)}


func _draw_target(tg: Target, q: Vector2, ppd: float) -> void:
	var d := tg.pos - sim.site
	var r := d.length()
	var s := tg.size / r * DEG * ppd
	var pal := _palette(tg)
	if sim.eo.ir and tg.ir > 0.6:
		screen.draw_circle(q, maxf(s * 0.35, 3.0), Color(pal.base, 0.25))
	var los := atan2(d.x, -d.y)
	var lat := sin(tg.heading - los)
	var elev := atan2(tg.alt - sim.cam_alt(), r)
	var high := tg.alt - sim.world.elev_at(tg.pos) > 6000.0
	if high and not sim.eo.ir and sim.daylight() > 0.3 and s > 6.0 and tg.shape != "bird" and absf(lat) > 0.4:  # contrail betrays high flyers
		var back := -signf(lat) * 1.0
		for i in 6:
			var u := float(i) / 6.0
			screen.draw_circle(q + Vector2(back * s * (0.55 + u * 4.5), 0.0), maxf(s * (0.05 + u * 0.1), 1.5), Color(1, 1, 1, 0.55 * (1.0 - u)))
	if s < 5.0 and tg.shape != "bird":
		screen.draw_rect(Rect2(q - Vector2(1.5, 1.5), Vector2(3, 3)), pal.base)
	else:
		var rear := tg.vel().dot(d) > 0.0
		var overhead := rad_to_deg(elev) > 40.0  # steep look-up: underside planform, rotated by how it moves on screen
		var rot := atan2(cos(tg.heading - los) * sin(elev), lat)
		AircraftArt.draw(screen, tg.shape, q, s, 1.0 if lat >= 0.0 else -1.0, absf(lat), clampf(absf(sin(elev)) * 1.4 + 0.12, 0.12, 1.0),
			pal, sim.eo.ir, tg.ir, rear, sim.t, tg.id, overhead, rot)
	if tg.id == sim.eo.sel:
		var b := maxf(s * 0.6, 12.0)
		var c := Color.RED if sim.eo.lock == tg.id else UI.AMBER
		screen.draw_rect(Rect2(q - Vector2(b, b), Vector2(b, b) * 2.0), c, false, 1.5)


## Azimuth tape: scrolls with the camera heading, cardinals in amber, a marker for the selected radar track.
func _draw_compass(W: float, c: Color) -> void:
	var az: float = sim.eo.az
	var ppd := 6.0
	var tw := minf(W - 280.0, 520.0)
	var y0 := 6.0
	var mid := W * 0.5
	screen.draw_rect(Rect2(mid - tw * 0.5, y0, tw, 30), Color(0, 0, 0, 0.45))
	screen.draw_rect(Rect2(mid - tw * 0.5, y0, tw, 30), Color(c, 0.5), false, 1.0)
	var span := tw / ppd * 0.5
	var a := floorf((az - span) / 5.0) * 5.0
	while a <= az + span:
		var x := mid + (a - az) * ppd
		if x > mid - tw * 0.5 + 2.0 and x < mid + tw * 0.5 - 2.0:
			var d := int(fposmod(a, 360.0))
			var major := d % 10 == 0
			screen.draw_line(Vector2(x, y0 + 30), Vector2(x, y0 + 30 - (11.0 if major else 6.0)), c, 1.0)
			if d % 30 == 0:
				var card := {0: "N", 90: "E", 180: "S", 270: "W"}
				_t(Vector2(x - (4.0 if card.has(d) else 10.0), y0 + 13), card.get(d, "%03d" % d), UI.AMBER if card.has(d) else c, 12)
		a += 5.0
	if sim.radar.tracks.has(sim.sel_trk):  # where the radar operator's selected track lies
		var tb := sim.bearing_deg(sim.site, sim.trk_pos(sim.radar.tracks[sim.sel_trk]))
		var dx := wrapf(tb - az, -180.0, 180.0) * ppd
		var tx := clampf(mid + dx, mid - tw * 0.5 + 6.0, mid + tw * 0.5 - 6.0)
		screen.draw_colored_polygon(PackedVector2Array([Vector2(tx, y0 + 30), Vector2(tx - 5, y0 + 38), Vector2(tx + 5, y0 + 38)]), Color(1, 0.4, 0.3))
		text(Vector2(tx + 7, y0 + 48), "T%d" % sim.sel_trk, Color(1, 0.4, 0.3), 11)
	screen.draw_colored_polygon(PackedVector2Array([Vector2(mid - 6, y0 - 2), Vector2(mid + 6, y0 - 2), Vector2(mid, y0 + 8)]), Color.WHITE)
	_t(Vector2(mid - 22, y0 + 54), "%05.1f" % az, Color.WHITE, 13)


## Overlay text with a dark drop shadow so it stays readable over bright sky.
func _t(pos: Vector2, s: String, color: Color, fs := 14) -> void:
	text(pos + Vector2(1, 1), s, Color(0, 0, 0, 0.85), fs)
	text(pos, s, color, fs)


func _draw_overlay(W: float, H: float) -> void:
	var c := UI.GREEN if not sim.eo.ir else Color(0.9, 0.9, 0.9)
	_draw_compass(W, c)
	var m := Vector2(W, H) * 0.5
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		screen.draw_line(m + dir * 10.0, m + dir * 34.0, c, 1.0)
	var y := 0.0
	while y < H:
		screen.draw_line(Vector2(0, y), Vector2(W, y), Color(0, 0, 0, 0.12))
		y += 3.0
	_t(Vector2(8, 18), "%s%s   FOV %.1f deg  x%.1f" % ["IR" if sim.eo.ir else "TV", (" WHT" if sim.eo.white_hot else " BLK") if sim.eo.ir else "", sim.eo.fov, Sim.FOV_MAX / float(sim.eo.fov)], c)
	_t(Vector2(8, H - 10), "AZ %05.1f  EL %+05.1f" % [sim.eo.az, sim.eo.el], c)
	_t(Vector2(W - 100, 18), sim.clock(), c)
	if sim.daylight() < 0.15 and not sim.eo.ir:
		_t(Vector2(W * 0.5 - 70, H - 30), "TV: LOW LIGHT - USE IR", UI.AMBER)


func _screen_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var f := 0.85 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.85
			sim.eo.fov = clampf(float(sim.eo.fov) * f, Sim.FOV_MIN, Sim.FOV_MAX)
			Sfx.play("tick")
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var best: Target = null
		var bd := 18.0
		for tg: Target in sim.targets:
			if not sim.eo_sees(tg):
				continue
			var d := _project(tg).distance_to(mb.position)
			if d < bd:
				bd = d
				best = tg
		if best != null:
			sim.eo.sel = best.id
			return
		var ppd := _ppd()
		sim.eo.lock = -1
		sim.eo.slave = -1
		sim.eo.az = fposmod(float(sim.eo.az) + (mb.position.x - screen.size.x * 0.5) / ppd, 360.0)
		sim.eo.el = clampf(float(sim.eo.el) - (mb.position.y - screen.size.y * 0.5) / ppd, -10.0, 60.0)
