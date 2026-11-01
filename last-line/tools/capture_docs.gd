extends SceneTree
## Scripted walk-through that captures tutorial screenshots + control positions.
##   godot --path last-line --resolution 1280x720 -s tools/capture_docs.gd -- <out_dir> [sections]
## sections: any of  briefing sentinel rain longeye watch  (default: all). Then:
##   python last-line/tools/annotate_docs.py <out_dir> docs/images     (numbered callouts)
## The walk-through tweaks a few things (e.g. the hostile flies high and slow) so the contact stays followable.

var main: Control
var out := ""
var marks := {}
var sim: Sim


func frames(n := 3) -> void:
	for i in n:
		await process_frame


func adv(seconds: float) -> void:
	for i in int(seconds / 0.05):
		sim.step(0.05)
	await frames(3)


func find_btn(node: Node, text: String) -> Control:
	if node is Button and (node as Button).text == text:
		return node as Control
	for c in node.get_children():
		var r := find_btn(c, text)
		if r != null:
			return r
	return null


func shoot(name: String, items: Array, keep_sub := false) -> void:
	await frames(4)
	if main.sub_box != null and not keep_sub:  # subtitles only in the dedicated radio shot
		main.radio_q.clear()
		main.sub_box.visible = false
		await frames(2)
	await RenderingServer.frame_post_draw  # make sure the frame has really been drawn before reading it back
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	var m: Array = marks.get(name, [])
	m.clear()
	for it in items:  # [label, Control (control) | Vector2 (point on the picture)]
		if it[1] is Vector2:
			m.append([it[0], it[1].x, it[1].y, 0.0])
		elif it[1] != null:
			var r: Rect2 = (it[1] as Control).get_global_rect()
			m.append([it[0], r.position.x, r.position.y + r.size.y * 0.5, r.size.x])
	marks[name] = m


func deploy(eq_i: int, mission_i: int, hour_i: int, weather_i: int) -> void:
	main.eq_opt.select(eq_i); main._on_equipment()
	main.mission_opt.select(mission_i); main._on_mission()
	main.time_opt.select(hour_i)
	main.weather_opt.select(weather_i)
	main.speed = 0.0
	main._deploy()
	sim = main.sim
	await frames(3)


func end_play() -> void:
	main._end_play()
	await frames(3)


func scope_point(st: RadarStation, world: Vector2) -> Vector2:
	var g: Array = st.view.geom()
	var c: Vector2 = g[0]
	return st.screen.global_position + c + (world - sim.site) / float(g[2]) * float(g[1])


## Step until the tagged mission target has been spawned and its echo is on the scope.
func track_target(tag: String, max_s := 150.0) -> Target:
	var t := 0.0
	while t < max_s and not sim.mission.tags.has(tag):
		sim.step(0.05)
		t += 0.05
	var tg: Target = sim.mission.tags[tag]
	tg.agl = 1500.0  # demo tweak: fly high and slow so the walk-through has time to follow the contact
	tg.speed = 120.0
	t = 0.0
	while t < max_s and sim.t - tg.echo_t > 2.0:
		sim.step(0.05)
		t += 0.05
	return tg


## Step until a non-bird target satisfying `pred` shows up in the EO.
func wait_eo(pred: Callable, max_s := 400.0) -> Target:
	var t := 0.0
	while t < max_s:
		for tg: Target in sim.targets:
			if tg.kind != Target.Kind.BIRD and sim.eo_sees(tg) and pred.call(tg):
				return tg
		sim.step(0.05)
		t += 0.05
	return null


func aim(es: EOStation, tg: Target, fov: float) -> void:
	sim.eo.az = sim.bearing_deg(sim.site, tg.pos)
	sim.eo.el = rad_to_deg(atan2(tg.alt - sim.cam_alt(), sim.site.distance_to(tg.pos)))
	sim.eo.sel = tg.id
	sim.eo.fov = fov


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var only: String = args[1] if args.size() > 1 else "briefing sentinel rain longeye watch"
	var prev := FileAccess.open(out + "/marks.json", FileAccess.READ)
	if prev != null:
		marks = JSON.parse_string(prev.get_as_text())
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(5)
	main._show(main.setup_ui)
	await frames(3)
	main.site = Vector2(WorldGen.SIZE, WorldGen.SIZE) * 0.5
	for i in 300:
		if main.world.biome_at(main.site) != WorldGen.Biome.SEA and main.world.elev_at(main.site) > 300.0:
			break
		main.site += Vector2(200, 200)
	main.deploy_btn.disabled = false
	main.map.queue_redraw()
	if "briefing" in only:
		var mr: Rect2 = main._map_rect()
		var mp: Vector2 = mr.position + Vector2(main.site) / WorldGen.SIZE * mr.size + Vector2(main.map.global_position)
		await shoot("01_briefing", [["site", mp], ["deploy", main.deploy_btn], ["equip", main.eq_opt], ["mission", main.mission_opt], ["weather", main.weather_opt]])
	if "sentinel" in only:
		await sec_sentinel()
	if "rain" in only:
		await sec_rain()
	if "longeye" in only:
		await sec_longeye()
	if "watch" in only:
		await sec_watch()
	var f := FileAccess.open(out + "/marks.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(marks))
	f.close()
	print("CAPTURE DONE ", marks.keys())
	quit()


func sec_sentinel() -> void:
	await deploy(0, 0, 0, 0)
	var rs: RadarStation = main.stations[0]
	var es: EOStation = main.stations[1]
	var fs: FireStation = main.stations[2]
	await adv(10.0)
	await shoot("02_radar_idle", [["transmit", find_btn(rs.panel, "TRANSMIT")], ["range", find_btn(rs.panel, "50")], ["mti", find_btn(rs.panel, "MTI")], ["rain", find_btn(rs.panel, "A/C RAIN")]])
	var tg := track_target("R1")
	await adv(1.0)
	await shoot("03_radar_echo", [["echo", scope_point(rs, tg.echo_pos)], ["range", find_btn(rs.panel, "50")]])
	var n := sim.make_track(tg.echo_pos, 800.0)
	sim.sel_trk = n
	await adv(9.0)
	sim.interrogate(n)
	await adv(1.0)
	var trk: Dictionary = sim.radar.tracks.get(n, {})
	await shoot("04_radar_track", [["track", scope_point(rs, sim.trk_pos(trk)) if not trk.is_empty() else Vector2(500, 340)], ["iff", find_btn(rs.panel, "IFF INTERROGATE")], ["slave", find_btn(rs.panel, "SLAVE EO TO TRACK")], ["report", find_btn(rs.panel, "HOSTILE")], ["drop", find_btn(rs.panel, "DROP TRACK")]])
	sim.eo.slave = n
	var guard := 0
	while not sim.eo_sees(tg) and guard < 3000:
		sim.step(0.05)
		guard += 1
	await adv(6.0)
	rs.visible = false
	es.visible = true
	await frames(4)
	await shoot("05_eo_wide", [["target", es._project(tg) + es.screen.global_position], ["ir", find_btn(es.panel, "TV/IR")], ["zoom", find_btn(es.panel, "ZOOM +")], ["pad", find_btn(es.panel, "UP")], ["rdr", find_btn(es.screen, "RDR")]])
	sim.eo.sel = tg.id
	sim.eo.lrf = -1.0
	sim.eo.fov = 14.0
	sim.eo_lock()
	sim.eo.fov = 1.2
	sim.eo_lrf()
	await adv(1.5)
	await shoot("06_eo_lock", [["target", es._project(tg) + es.screen.global_position], ["lock", find_btn(es.panel, "LOCK TARGET")], ["lrf", find_btn(es.panel, "LASER RANGE")], ["report", find_btn(es.panel, "HOSTILE")]])
	es.visible = false
	fs.visible = true
	fs.armed = true
	sim.sel_trk = n
	await adv(1.0)
	await shoot("07_fire_ready", [["arm", find_btn(fs.panel, "MASTER ARM")], ["launch", find_btn(fs.panel, "LAUNCH")]])
	var tries := 0
	var shot_done := false
	while sim.mission.kills == 0 and tries < 4 and sim.radar.tracks.has(n):  # a miss is realistic, but the tutorial shows a kill
		fs.armed = true
		sim.launch(n)
		await adv(3.0)
		if not shot_done and not sim.missiles.is_empty() and sim.msl_wakes.is_empty():  # still flying, nothing has burst yet
			await shoot("08_fire_launch", [["launch", find_btn(fs.panel, "LAUNCH")]])
			fs.visible = false
			es.visible = true
			sim.eo.lock = -1  # the turret stays on the site; just point it up at the climbing missile
			sim.eo.slave = -1
			sim.eo.fov = 8.0
			await adv(0.5)
			if not sim.missiles.is_empty() and sim.msl_wakes.is_empty():
				var mm: Dictionary = sim.missiles[0]
				var mp: Vector2 = mm.pos
				sim.eo.az = sim.bearing_deg(sim.site, mp)
				sim.eo.el = rad_to_deg(atan2(float(mm.alt) - sim.cam_alt(), sim.site.distance_to(mp)))
				await frames(4)
				await shoot("08b_eo_missile", [])
				shot_done = true
			else:
				print("CAPTURE note: missile ended early, retrying")
			es.visible = false
			fs.visible = true
		var g2 := 0
		while not sim.missiles.is_empty() and g2 < 60:
			await adv(1.0)
			g2 += 1
		tries += 1
	await adv(1.0)
	await shoot("09_fire_kill", [])
	main._on_radio({"who": "HQ", "voice": "HQ", "tpl": "x", "vars": {}, "en": "Splash one hostile. Good work.", "ko": "적기 격추 확인. 잘했다."})
	await frames(6)
	await shoot("15_radio_subtitle", [], true)
	await end_play()


func sec_rain() -> void:
	await deploy(0, 0, 0, 1)
	var rs: RadarStation = main.stations[0]
	await adv(30.0)
	await shoot("10_radar_rain", [["rain", find_btn(rs.panel, "A/C RAIN")]])
	sim.radar.rain_filter = true
	await adv(8.0)
	await shoot("11_radar_rain_filter", [["rain", find_btn(rs.panel, "A/C RAIN")]])
	await end_play()


func sec_longeye() -> void:
	await deploy(1, 2, 3, 0)
	var rs: RadarStation = main.stations[0]
	await adv(75.0)
	var tg: Target = null
	for t in sim.targets:  # an aircraft whose echo was refreshed on the last sweep
		if t.kind != Target.Kind.BIRD and sim.t - t.echo_t < 6.0:
			tg = t
	var pt := Vector2(500, 340)
	if tg != null:
		var n := sim.make_track(tg.echo_pos, 2500.0)
		sim.sel_trk = n
		await adv(14.0)
		sim.interrogate(n)
		await adv(1.0)
		var trk: Dictionary = sim.radar.tracks.get(n, {})
		if not trk.is_empty():
			pt = scope_point(rs, sim.trk_pos(trk))
	await shoot("12_longeye_night", [["track", pt], ["range", find_btn(rs.panel, "90")], ["iff", find_btn(rs.panel, "IFF INTERROGATE")], ["report", find_btn(rs.panel, "FRIENDLY")]])
	await end_play()


func sec_watch() -> void:
	# day / TV: wait until a real aircraft is within 10 km, then zoom in on it
	await deploy(2, 2, 0, 0)
	var es: EOStation = main.stations[0]
	var tgt := wait_eo(func(t: Target): return t.pos.distance_to(sim.site) < 10000.0)
	if tgt != null:
		aim(es, tgt, 1.0)
		sim.eo_lrf()
		await adv(0.3)
		aim(es, tgt, 1.0)
		await shoot("13_watchpost_tv", [["target", es._project(tgt) + es.screen.global_position], ["report", find_btn(es.panel, "CIVIL")], ["lrf", find_btn(es.panel, "LASER RANGE")], ["zoom", find_btn(es.panel, "ZOOM +")]])
	await end_play()
	# night / IR: hostile fighter shows white-hot against the cold sky
	await deploy(2, 2, 3, 0)
	es = main.stations[0]
	sim.eo.ir = true
	tgt = wait_eo(func(t: Target): return t.model == "FIGHTER-X" and t.pos.distance_to(sim.site) < 9000.0)
	if tgt != null:
		tgt.speed = 40.0  # keep it in frame for the capture
		aim(es, tgt, 1.2)
		await adv(0.3)
		aim(es, tgt, 1.2)
		await shoot("14_watchpost_ir", [["target", es._project(tgt) + es.screen.global_position], ["ir", find_btn(es.panel, "TV/IR")], ["pol", find_btn(es.panel, "WHT/BLK")]])
	await end_play()
