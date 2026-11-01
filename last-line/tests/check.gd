extends SceneTree
## Headless self-check: godot --headless -s tests/check.gd

func _init() -> void:
	var a := WorldGen.new()
	a.generate(42, "Mixed")
	var b := WorldGen.new()
	b.generate(42, "Mixed")
	var c := WorldGen.new()
	c.generate(43, "Mixed")
	assert(a.heights == b.heights and a.biomes == b.biomes)  # same seed -> same map
	assert(a.heights != c.heights)
	var site := Vector2(WorldGen.SIZE, WorldGen.SIZE) * 0.5
	for i in 200:
		if a.biome_at(site) != WorldGen.Biome.SEA:
			break
		site += Vector2(WorldGen.CELL, 0)
	for eq: Equipment in Equipment.catalog():
		for m: Mission in Mission.catalog():
			var sim := Sim.new()
			var heard := []
			sim.radio_msg.connect(func(m: Dictionary): heard.append(m.who + ": " + m.en))
			sim.setup(a, eq, m, site, 12.0, 42, "Rain", 15.0)
			for i in 6000:  # 300 s
				sim.step(0.05)
				if not eq.radar.is_empty() and sim.radar.tracks.is_empty() and i % 20 == 0:
					for tg: Target in sim.targets:
						if sim.t - tg.echo_t < 5.0:
							sim.make_track(tg.echo_pos, 500.0)
				if sim.missiles_left > 0 and not sim.radar.tracks.is_empty() and i % 100 == 0:
					sim.sel_trk = sim.radar.tracks.keys()[0]
					sim.launch(sim.sel_trk)
			print("%s / %s: %s score=%d echo_px=%d trk=%d radio=%d" % [eq.title, m.title, m.status, sim.score, _lit(sim), sim.next_trk - 1, heard.size()])
	_roe_check(a, site)
	# high-altitude short path must be clear
	var flat := WorldGen.new()
	flat.generate(1, "Plains")
	assert(flat.los(Vector2(1000, 1000), 5000.0, Vector2(2000, 1000), 5000.0))
	print("CHECK OK")
	quit()


func _lit(sim: Sim) -> int:
	var n := 0
	for b in sim.video:
		if b > 80:
			n += 1
	return n


## Operators' HOSTILE call authorises fire even on a civil airliner; firing against IFF triggers a warning
## and a harsher post-strike assessment.
func _roe_check(world: WorldGen, site: Vector2) -> void:
	var sim := Sim.new()
	var heard := []
	sim.radio_msg.connect(func(m: Dictionary): heard.append(m.en))
	sim.setup(world, Equipment.catalog()[0], Mission.catalog()[0], site, 12.0, 42)
	var tg := sim.spawn(Target.Kind.CIVIL, "AIRLINER", 0.0)
	tg.pos = sim.site + Vector2(0, -9000)
	tg.speed = 20.0
	for i in 400:
		sim.step(0.05)
		tg.pos = sim.site + Vector2(0, -9000)
		if sim.t - tg.echo_t < 3.0:
			break
	var n := sim.make_track(tg.echo_pos, 1500.0)
	assert(n >= 0)
	assert(sim.launch_check(n).begins_with("WEAPONS HOLD"))
	sim.report_track(n, Target.Kind.HOSTILE)  # operator designates the airliner hostile
	assert(sim.launch_check(n) == "")
	sim.report_track(n, Target.Kind.CIVIL)  # ...and may correct it
	assert(sim.launch_check(n).begins_with("WEAPONS HOLD"))
	sim.report_track(n, Target.Kind.HOSTILE)
	sim.interrogate(n)  # IFF says CIVIL, but the operator fires anyway
	assert(sim.warning_for(sim.radar.tracks[n]) == "civil")
	for k in 4:
		sim.sel_trk = n
		sim.launch(n)
		for i in 1000:
			sim.step(0.05)
			tg.pos = sim.site + Vector2(0, -9000)
			if sim.missiles.is_empty():
				break
		if sim.stats.civil > 0 or not sim.radar.tracks.has(n):
			break
	assert(sim.stats.warned >= 1)
	assert(heard.any(func(h: String): return "civil" in h.to_lower()))
	print("ROE OK: warned=%d civil=%d willful=%d score=%d" % [sim.stats.warned, sim.stats.civil, sim.stats.willful, sim.score])
