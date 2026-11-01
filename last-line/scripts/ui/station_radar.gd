class_name RadarStation
extends Station
## Search-radar operator: raw echo video (terrain, weather, noise, targets) on a PPI with phosphor afterglow.
## No target markers: the operator finds echoes, hooks them into tracks, then identifies them.

var view := RadarView.new()


func _build() -> void:
	view.setup(sim)
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(view)

	UI.label(panel, "RADAR OPERATOR", UI.AMBER)
	var tx := UI.button(panel, "TRANSMIT", func(on: bool): sim.radar.on = on, true)
	tx.button_pressed = true
	var hb := HBoxContainer.new()
	panel.add_child(hb)
	var max_km: float = float(sim.eq.radar.range) / 1000.0
	for i in RadarView.RANGES.size():
		var b := UI.button(hb, "%d" % RadarView.RANGES[i], func(): sim.radar.range_i = i)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = RadarView.RANGES[i] > max_km
	UI.label(panel, "GAIN  (high: more noise/clutter)", UI.DIM)
	var gain := HSlider.new()
	gain.max_value = 1.0
	gain.step = 0.05
	gain.value = sim.radar.gain
	gain.custom_minimum_size.y = 24
	gain.value_changed.connect(func(v: float):
		sim.radar.gain = v
		Sfx.play("tick"))
	panel.add_child(gain)
	var fb := HBoxContainer.new()
	panel.add_child(fb)
	UI.button(fb, "MTI", func(on: bool): sim.radar.mti = on, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button(fb, "A/C RAIN", func(on: bool): sim.radar.rain_filter = on, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(panel, "Click an echo to track it.", UI.DIM)
	UI.button(panel, "IFF INTERROGATE", func(): sim.interrogate(sim.sel_trk))
	if not sim.eq.eo.is_empty():
		UI.button(panel, "SLAVE EO TO TRACK", func():
			if sim.radar.tracks.has(sim.sel_trk):
				sim.eo.slave = sim.sel_trk
				sim.eo.lock = -1)
	UI.button(panel, "DROP TRACK", func(): sim.drop_track(sim.sel_trk))
	report_buttons(func(k: int): sim.report_track(sim.sel_trk, k))


func tick(dt: float) -> void:
	super(dt)
	view.tick()
	var tr: Dictionary = sim.radar.tracks.get(sim.sel_trk, {})
	if tr.is_empty():
		info.text = "NO TRACK SELECTED"
		return
	var p := sim.trk_pos(tr)
	var v: Vector2 = tr.vel
	var hdg := "---" if v.length() < 1.0 else "%03d" % roundi(fposmod(rad_to_deg(atan2(v.x, -v.y)), 360.0))
	info.text = "TRK %d\nRNG %.1f km  BRG %03d\nALT %d m\nSPD %d m/s  HDG %s\nIFF %s" % [
		sim.sel_trk, sim.site.distance_to(p) / 1000.0, roundi(sim.bearing_deg(sim.site, p)),
		roundi(float(tr.alt)), roundi(v.length()), hdg, tr.iff]


func _draw_screen() -> void:
	screen.draw_rect(Rect2(Vector2.ZERO, screen.size), Color(0.02, 0.03, 0.06))


func _screen_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		view.cursor = (ev as InputEventMouseMotion).position
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var g := view.geom()
		var c: Vector2 = g[0]
		var rad: float = g[1]
		var range_m: float = g[2]
		var n := sim.make_track(sim.site + (mb.position - c) / rad * range_m, 16.0 / rad * range_m)
		if n >= 0:
			sim.sel_trk = n
