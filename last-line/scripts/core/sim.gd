class_name Sim
extends RefCounted
## Authoritative game state: targets, missiles, radar video, EO, weather, radio.
## UI stations only read it and call its actions.

signal log_added(text: String)
## msg = {who (display), voice (speaker), tpl (English template), vars, en, ko}
signal radio_msg(msg: Dictionary)
signal sfx(sound: String)

const FOVS := [14.0, 5.0, 1.8]  # EO zoom presets: horizontal field of view, deg (wide/medium/narrow)
const FOV_MIN := 0.8
const FOV_MAX := 20.0
const SPAWN_R := 28000.0
const AZ_BINS := 720  # radar video: x = azimuth bin (0.5 deg), y = range bin
const RANGE_BINS := 400
const BEAM := 0.03  # rad, ~1.7 deg beamwidth
const WEATHERS := {
	"Clear": {"rain": 0.0, "vis": 1.0},
	"Rain": {"rain": 0.6, "vis": 0.6},
	"Storm": {"rain": 1.0, "vis": 0.35},
	"Fog": {"rain": 0.0, "vis": 0.3},
}

var world: WorldGen
var eq: Equipment
var mission: Mission
var site := Vector2.ZERO
var site_elev := 0.0
var hour := 12.0
var weather := "Clear"
var wx: Dictionary = WEATHERS["Clear"]
var temp := 15.0  # deg C
var wind := Vector2(8.0, 5.0)  # m/s, drifts rain cells
var t := 0.0
var score := 0
var site_hp := 100
var missiles_left := 0
var rng := RandomNumberGenerator.new()
var vrng := RandomNumberGenerator.new()  # visual noise only, keeps scenario rng deterministic
var targets: Array = []
var missiles: Array = []
var msl_wakes: Array = []  # finished flights kept briefly for the fire-control display: {pts, t, key}
var reported := {}  # tid -> designation given by the operators (re-designation allowed)
var stats := {"hostile": 0, "friendly": 0, "civil": 0, "bird": 0, "willful": 0, "warned": 0}
var next_tid := 1
var next_trk := 1
var sel_trk := -1
var radar := {"on": true, "az": 0.0, "gain": 0.6, "mti": false, "rain_filter": false, "range_i": 2, "tracks": {}}
var eo := {"az": 0.0, "el": 1.0, "fov": 14.0, "ir": false, "white_hot": true, "lock": -1, "slave": -1,
	"sel": -1, "lrf": -1.0, "lrf_alt": 0.0}
var video := PackedByteArray()
var video_ver := 0  # bumped whenever the radar picture changes; views re-upload on mismatch
var video_range := 60000.0
var video_bin := 150.0
var _clutter: Array = []
var _bin := 0
var _rev := 0
var _duct := false
var _rain_noise := FastNoiseLite.new()
var _ambient_t := 40.0
var _last_say := -100.0
var _ended := false


func setup(p_world: WorldGen, p_eq: Equipment, p_mission: Mission, p_site: Vector2, p_hour: float, p_seed: int,
		p_weather := "Clear", p_temp := 15.0) -> void:
	world = p_world
	eq = p_eq
	mission = p_mission
	site = p_site
	site_elev = world.elev_at(site)
	hour = p_hour
	weather = p_weather
	wx = WEATHERS[weather]
	temp = p_temp
	missiles_left = eq.missiles
	rng.seed = p_seed
	vrng.seed = p_seed + 7
	_rain_noise.seed = p_seed + 3
	_rain_noise.frequency = 1.0 / 9000.0
	_rain_noise.fractal_octaves = 3
	if not eq.radar.is_empty():
		video_range = float(eq.radar.range)
		video_bin = video_range / RANGE_BINS
		radar.range_i = 3 if video_range >= 90000.0 else 2  # start at the largest scale the radar supports
		video.resize(AZ_BINS * RANGE_BINS)
		video.fill(0)
		_clutter.resize(AZ_BINS)
	mission.start(self)
	if Radio.WEATHER_LINES.has(weather):
		_say_at(3.0, Radio.WEATHER_LINES[weather])


func add_log(text: String) -> void:
	log_added.emit("%s  %s" % [clock(), text])


func clock() -> String:
	var s := int(hour * 3600.0)
	return "%02d:%02d:%02d" % [floori(s / 3600.0), floori(s / 60.0) % 60, s % 60]


func daylight() -> float:
	return clampf(sin((hour - 6.0) / 12.0 * PI) * 1.6, 0.0, 1.0)


## Temperature-inversion ducting: clear calm night/dawn air bends the beam, ground echoes appear far beyond the horizon.
func ducting() -> bool:
	return daylight() < 0.35 and float(wx.rain) == 0.0


func earth_r() -> float:
	return 2.0e7 if _duct else 8.5e6


func get_target(tid: int) -> Target:
	for tg: Target in targets:
		if tg.id == tid:
			return tg
	return null


func live_count() -> int:
	var n := 0
	for tg: Target in targets:
		if tg.kind != Target.Kind.BIRD:
			n += 1
	return n


# ---------------------------------------------------------------- radio

func say(who: String, en: String, ko: String, vars := {}) -> void:
	var disp := who
	if Radio.ROLES.has(who) and not eq.stations.has(Radio.ROLES[who]):
		disp = "Squad Leader"  # that role is not manned on this equipment
	var ve: Dictionary = vars.get("en", {})
	var vk: Dictionary = vars.get("ko", {})
	_last_say = t
	radio_msg.emit({"who": disp, "voice": who, "tpl": en, "vars": ve, "en": en.format(ve), "ko": ko.format(vk)})


func say_key(key: String, n := 0) -> void:
	var l := Radio.pick(key, rng)
	say(l[0], l[1], l[2], {"en": {"n": n}, "ko": {"n": n}})


var _timed: Array = []  # [time, line]


func _say_at(at: float, line: Array) -> void:
	_timed.append([at, line])


## Numbers HQ would read out about a target (rounded + jittered, like a real report).
## Returns {"en": {...}, "ko": {...}} for Sim.say().
func describe(tg: Target) -> Dictionary:
	var d := tg.pos - site
	var brg := (int(roundf((bearing_deg(site, tg.pos) + rng.randf_range(-4.0, 4.0)) / 5.0)) * 5 + 360) % 360
	var agl := tg.alt - world.elev_at(tg.pos)
	var closing := tg.vel().dot(-d.normalized()) / maxf(tg.speed, 1.0)
	var ai := 0 if agl < 300.0 else (1 if agl < 1500.0 else (2 if agl < 6000.0 else 3))
	var si := 0 if tg.speed > 200.0 else (1 if tg.speed > 100.0 else 2)
	var hi := 0 if closing > 0.5 else (1 if closing < -0.5 else 2)
	var common := {"brg": "%03d" % brg, "rng": maxi(1, roundi(d.length() / 1000.0 + rng.randf_range(-2.0, 2.0)))}
	var en := common.duplicate()
	en.merge({"alt": Radio.ALT_EN[ai], "spd": Radio.SPD_EN[si], "hdg": Radio.HDG_EN[hi]})
	var ko := common.duplicate()
	ko.merge({"alt": Radio.ALT_KO[ai], "spd": Radio.SPD_KO[si], "hdg": Radio.HDG_KO[hi]})
	return {"en": en, "ko": ko}


# ---------------------------------------------------------------- spawning

func spawn(kind: int, model: String, bearing_deg := -1.0) -> Target:
	var m: Dictionary = Target.MODELS[model]
	var tg := Target.new()
	tg.id = next_tid
	next_tid += 1
	tg.kind = kind
	tg.model = model
	tg.shape = m.shape
	tg.speed = m.speed
	tg.turn = m.turn
	tg.rcs = m.rcs
	tg.ir = m.ir
	tg.size = m.size
	tg.tf = m.tf
	var arng: Vector2 = m.alt
	tg.agl = rng.randf_range(arng.x, arng.y)
	var b := deg_to_rad(bearing_deg if bearing_deg >= 0.0 else rng.randf_range(0.0, 360.0))
	var dir := Vector2(sin(b), -cos(b))
	var far := Vector2(WorldGen.SIZE, WorldGen.SIZE)
	match kind:
		Target.Kind.BIRD:
			tg.pos = site + dir * rng.randf_range(4000.0, 12000.0)
			tg.wander = true
			tg.heading = rng.randf_range(0.0, TAU)
		Target.Kind.HOSTILE:
			tg.pos = (site + dir * SPAWN_R).clamp(Vector2.ZERO, far)
			tg.waypoints = [site + Vector2(rng.randf_range(-400.0, 400.0), rng.randf_range(-400.0, 400.0))]
		_:
			var side := Vector2(-dir.y, dir.x) * rng.randf_range(-6000.0, 6000.0)
			tg.pos = (site + dir * SPAWN_R + side).clamp(Vector2.ZERO, far)
			tg.waypoints = [site + side, site - dir * SPAWN_R * 2.0 + side]
			tg.iff_fault = kind == Target.Kind.FRIENDLY and rng.randf() < 0.2
	if not tg.waypoints.is_empty():
		var d := tg.waypoints[0] - tg.pos
		tg.heading = atan2(d.x, -d.y)
	tg.alt = world.elev_at(tg.pos) + tg.agl if tg.tf else tg.agl
	targets.append(tg)
	return tg


# ---------------------------------------------------------------- tick

func step(dt: float) -> void:
	t += dt
	hour = fposmod(hour + dt / 3600.0, 24.0)
	var keep := []
	for tg: Target in targets:
		tg.step(dt, rng)
		if tg.tf:
			tg.alt = world.elev_at(tg.pos) + tg.agl
		if tg.done:
			_retire(tg)
		else:
			keep.append(tg)
	targets = keep
	_step_missiles(dt)
	_step_radar(dt)
	_step_eo(dt)
	mission.tick(self, dt)
	_step_radio()


func _step_radio() -> void:
	for e in _timed.duplicate():
		if t >= float(e[0]):
			_timed.erase(e)
			var l: Array = e[1]
			say(l[0], l[1], l[2])
	if t > _ambient_t and t - _last_say > 8.0 and mission.status == "active":
		_ambient_t = t + rng.randf_range(45.0, 90.0)
		var l: Array = Radio.AMBIENT[rng.randi() % Radio.AMBIENT.size()]
		if not Radio.ROLES.has(l[0]) or eq.stations.has(Radio.ROLES[l[0]]):
			say(l[0], l[1], l[2])
	if mission.status != "active" and not _ended:
		_ended = true
		say_key(mission.status)


## `knowing`: why the shooter was already warned (""/"friend"/"civil"/"briefed"). Post-strike assessment:
## wrongful kills cost points either way, firing despite a warning costs extra and HQ says so.
func _retire(tg: Target, knowing := "") -> void:
	if tg.killed:
		var w := "_w" if knowing != "" else ""
		if knowing != "" and tg.kind != Target.Kind.HOSTILE:
			stats.willful += 1
		match tg.kind:
			Target.Kind.HOSTILE:
				stats.hostile += 1
				score += 150
				add_log("TGT-%03d DESTROYED" % tg.id)
				say_key("kill_h")
			Target.Kind.FRIENDLY:
				stats.friendly += 1
				score -= 300 + (200 if w != "" else 0)
				add_log("FRATRICIDE - friendly aircraft destroyed!" + (" (fired despite warning)" if w != "" else ""))
				say_key("kill_f" + w)
			Target.Kind.CIVIL:
				stats.civil += 1
				score -= 500 + (300 if w != "" else 0)
				add_log("CIVIL AIRCRAFT DESTROYED!" + (" (fired despite warning)" if w != "" else ""))
				say_key("kill_c" + w)
			_:
				stats.bird += 1
				score -= 50 if w != "" else 0
				add_log("Bird flock hit - missile wasted")
				say_key("kill_b" + w)
		mission.on_event(self, "killed", tg)
	elif tg.kind == Target.Kind.HOSTILE and tg.pos.distance_to(site) < 3000.0:
		site_hp -= 34
		score -= 200
		add_log("SITE HIT BY HOSTILE!")
		say_key("site_hit")
		sfx.emit("alarm")
		mission.on_event(self, "leak", tg)
	else:
		mission.on_event(self, "left", tg)


## Post-mission engagement assessment shown on the result screen.
func engagement_summary() -> String:
	var wrong: int = int(stats.friendly) + int(stats.civil) + int(stats.bird)
	return "Engagements: %d hostile destroyed, %d wrongful (%d friendly, %d civil, %d birds)\nFired despite a warning: %d" % [
		stats.hostile, wrong, stats.friendly, stats.civil, stats.bird, stats.willful]


# ---------------------------------------------------------------- radar video
# The beam sweeps; each azimuth column is rewritten as the beam passes it: terrain clutter (with shadows),
# weather clutter, receiver noise and target echoes. The display only fades columns by angle-behind-beam.

func _step_radar(dt: float) -> void:
	if eq.radar.is_empty():
		return
	var duct := ducting()
	if duct != _duct:
		_duct = duct
		_clutter.fill(null)  # shadow zones fill in / vanish with the new propagation
		if duct:
			say_key("ducting")
	for k in radar.tracks.keys():
		var tr: Dictionary = radar.tracks[k]
		if t - float(tr.last_t) > 12.0:
			radar.tracks.erase(k)
			add_log("TRK %d LOST" % k)
			say_key("track_lost", k)
			sfx.emit("lost")
			if sel_trk == k:
				sel_trk = -1
			if eo.slave == k:
				eo.slave = -1
	if not radar.on:
		return
	var period: float = eq.radar.period
	var a0: float = radar.az
	radar.az = fposmod(a0 + TAU / period * dt, TAU)
	var tb := int(float(radar.az) / TAU * AZ_BINS) % AZ_BINS
	var guard := 0
	while _bin != tb and guard < AZ_BINS:
		_bin = (_bin + 1) % AZ_BINS
		if _bin == 0:
			_rev += 1
		_paint_column(_bin)
		guard += 1
	video_ver += 1


const ROUGH := [0.05, 0.25, 0.6, 0.8, 0.3]  # ground clutter reflectivity per biome


## Static terrain return for one azimuth: horizon scan so ground behind a ridge is in radar shadow.
func _clutter_col(j: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(RANGE_BINS)
	var az := (j + 0.5) / AZ_BINS * TAU
	var dir := Vector2(sin(az), -cos(az))
	var cam := site_elev + float(eq.radar.ant_h)
	var er := earth_r()
	var max_t := -INF
	var prev_h := site_elev
	for r in RANGE_BINS:
		var d := (r + 0.5) * video_bin
		var p := site + dir * d
		if p.x < 0.0 or p.y < 0.0 or p.x > WorldGen.SIZE or p.y > WorldGen.SIZE:
			continue
		var h := world.elev_at(p)
		var tn := (h - d * d / (2.0 * er) - cam) / d
		var face := clampf((h - prev_h) / video_bin * 3.0, 0.0, 1.0)
		var v: float = ROUGH[world.biome_at(p)] * (0.35 + 0.65 * face) / (1.0 + d / 25000.0)
		if tn > max_t:
			max_t = tn
		else:
			v = v * 0.25 if _duct else 0.0  # radar shadow (ducting leaks a weak return in)
		out[r] = int(clampf(v, 0.0, 1.0) * 255.0)
		prev_h = h
	return out


func _paint_column(j: int) -> void:
	if _clutter[j] == null:
		_clutter[j] = _clutter_col(j)
	var col: PackedByteArray = _clutter[j]
	var gain: float = radar.gain
	var mti: bool = radar.mti
	var rain_f: bool = radar.rain_filter
	var rain: float = wx.rain
	var cg := gain * gain * 2.4 * (0.12 if mti else 1.0)
	# thermal receiver noise rises with temperature and with gain
	var nz := (0.04 + 0.45 * gain) * clampf(1.0 + (temp - 15.0) / 60.0, 0.7, 1.5)
	var az_c := (j + 0.5) / AZ_BINS * TAU
	var dir := Vector2(sin(az_c), -cos(az_c))
	var spike := 0.5 if weather == "Storm" and vrng.randf() < 0.01 else 0.0  # lightning sferics
	var buf := PackedFloat32Array()
	buf.resize(RANGE_BINS)
	for r in RANGE_BINS:
		var v := float(col[r]) / 255.0 * cg + vrng.randf() * vrng.randf() * nz + spike * vrng.randf()
		if rain > 0.0:
			var p := site + dir * ((r + 0.5) * video_bin) + wind * t
			var n := _rain_noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			v += clampf((n - (1.0 - rain * 0.55)) / 0.25, 0.0, 1.0) * 0.55 * rain * (0.15 if rain_f else 1.0)
		buf[r] = v
	for tg: Target in targets:
		var d := tg.pos - site
		var da := wrapf(atan2(d.x, -d.y) - az_c, -PI, PI)
		if absf(da) > BEAM * 1.6:
			continue
		var r := d.length()
		if r < 1500.0 or r >= video_range:
			continue
		var amp := _echo_amp(tg, r, d)
		var prof := exp(-pow(da / BEAM, 2.0) * 1.2) * amp
		var rb := int(r / video_bin)
		for k in range(-1, 2):
			if rb + k >= 0 and rb + k < RANGE_BINS:
				buf[rb + k] += prof * (1.0 if k == 0 else 0.55)
		if prof > 0.4 and absf(da) < BEAM * 0.6:
			_detect(tg)
	for r in RANGE_BINS:
		video[r * AZ_BINS + j] = int(clampf(buf[r], 0.0, 1.0) * 255.0)


func _echo_amp(tg: Target, r: float, d: Vector2) -> float:
	if tg.los_rev != _rev:  # once per revolution: terrain masking + Swerling-like fluctuation
		tg.los_rev = _rev
		tg.los_ok = world.los(site, site_elev + float(eq.radar.ant_h), tg.pos, tg.alt, earth_r())
		tg.fl = 0.6 + 0.8 * vrng.randf()
	if not tg.los_ok:
		return 0.0
	var rmax: float = float(eq.radar.range) * pow(tg.rcs, 0.25) * lerpf(0.6, 1.1, radar.gain)
	var a := pow(rmax / r, 2.0) * 0.6 * tg.fl
	a *= exp(-float(wx.rain) * r / 60000.0 * 0.8)  # two-way rain attenuation
	if radar.rain_filter:
		a *= 0.85
	if radar.mti:  # moving-target indicator: blind to tangential / slow movers
		a *= clampf(absf(tg.vel().dot(d / r)) / 20.0, 0.05, 1.0)
	return minf(a, 1.3)


## Echo strong enough: refresh the target's echo position and any track on it.
func _detect(tg: Target) -> void:
	tg.echo_t = t
	tg.echo_pos = tg.pos + Vector2(vrng.randf_range(-80.0, 80.0), vrng.randf_range(-80.0, 80.0))
	for k in radar.tracks:
		var tr: Dictionary = radar.tracks[k]
		if tr.tid == tg.id:
			var dtt: float = t - float(tr.last_t)
			if dtt > 0.5:
				var old: Vector2 = tr.pos
				var nv := (tg.echo_pos - old) / dtt
				var ov: Vector2 = tr.vel
				tr.vel = nv if ov == Vector2.ZERO else ov.lerp(nv, 0.6)
				tr.pos = tg.echo_pos
				tr.alt = tg.alt + vrng.randf_range(-150.0, 150.0)
				tr.last_t = t


func video_at(world_pos: Vector2) -> float:
	var d := world_pos - site
	var rb := int(d.length() / video_bin)
	if rb >= RANGE_BINS or video.is_empty():
		return 0.0
	var j := int(fposmod(atan2(d.x, -d.y), TAU) / TAU * AZ_BINS) % AZ_BINS
	return float(video[rb * AZ_BINS + j]) / 255.0


func trk_pos(tr: Dictionary) -> Vector2:
	var p: Vector2 = tr.pos
	var v: Vector2 = tr.vel
	return p + v * minf(t - float(tr.last_t), 12.0)


func nearest_track(world_pos: Vector2, radius: float) -> int:
	var best := -1
	var bd := radius
	for k in radar.tracks:
		var d := trk_pos(radar.tracks[k]).distance_to(world_pos)
		if d < bd:
			bd = d
			best = k
	return best


## Operator hooks an echo on the scope. Real targets with a fresh echo become tracks; bright
## clutter/rain/noise can be hooked too (false track).
func make_track(world_pos: Vector2, radius: float) -> int:
	var ex := nearest_track(world_pos, radius)
	if ex >= 0:
		return ex
	var best: Target = null
	var bd := radius
	var period: float = eq.radar.period
	for tg: Target in targets:
		if t - tg.echo_t > period * 1.5:
			continue
		var d := tg.echo_pos.distance_to(world_pos)
		if d < bd:
			bd = d
			best = tg
	var tid := -1
	var pos := world_pos
	var alt := 0.0
	if best != null:
		tid = best.id
		pos = best.echo_pos
		alt = best.alt + rng.randf_range(-150.0, 150.0)
	elif video_at(world_pos) < 0.3:
		return -1
	var n := next_trk
	next_trk += 1
	radar.tracks[n] = {"num": n, "tid": tid, "pos": pos, "alt": alt, "vel": Vector2.ZERO,
		"last_t": t, "cls": int(reported.get(tid, -1)), "iff": "---"}
	add_log("TRK %d INITIATED" % n)
	say_key("track_new", n)
	sfx.emit("beep")
	return n


func drop_track(num: int) -> void:
	if radar.tracks.erase(num):
		add_log("TRK %d DROPPED" % num)
	if sel_trk == num:
		sel_trk = -1
	if eo.slave == num:
		eo.slave = -1


func interrogate(num: int) -> void:
	if not radar.tracks.has(num):
		return
	var tr: Dictionary = radar.tracks[num]
	var tg := get_target(tr.tid)
	var reply := "NO REPLY"
	var key := "iff_none"
	if tg != null and not tg.iff_fault:
		if tg.kind == Target.Kind.FRIENDLY:
			reply = "FRIEND"
			key = "iff_friend"
		elif tg.kind == Target.Kind.CIVIL:
			reply = "CIVIL"
			key = "iff_civil"
	tr.iff = reply
	add_log("IFF TRK %d: %s" % [num, reply])
	say_key(key)
	sfx.emit("chirp")


# ---------------------------------------------------------------- reports

func report(tid: int, cls: int) -> void:
	var tg := get_target(tid)
	if tg == null:
		return
	if reported.has(tid):  # operators may change their designation; no extra score
		if reported[tid] == cls:
			add_log("Already designated %s" % Target.KIND_NAMES[cls])
			return
		reported[tid] = cls
		for k in radar.tracks:
			if radar.tracks[k].tid == tid:
				radar.tracks[k].cls = cls
		add_log("DESIGNATION CHANGED: %s" % Target.KIND_NAMES[cls])
		return
	reported[tid] = cls
	var ok := tg.kind == cls
	score += 100 if ok else -50
	add_log("REPORT %s: %s" % [Target.KIND_NAMES[cls], "CORRECT" if ok else "INCORRECT"])
	for k in radar.tracks:
		if radar.tracks[k].tid == tid:
			radar.tracks[k].cls = cls
	if ok and cls == Target.Kind.HOSTILE:
		tg.auth = true
		say_key("hostile_auth")
	else:
		say_key("report_ok" if ok else "report_bad")
	mission.on_event(self, "reported", tg, ok)


func report_track(num: int, cls: int) -> void:
	if not radar.tracks.has(num):
		return
	var tr: Dictionary = radar.tracks[num]
	if int(tr.tid) < 0:
		score -= 50
		tr.cls = cls
		add_log("REPORT on FALSE TRACK - penalty")
		say_key("report_bad")
	else:
		report(tr.tid, cls)


# ---------------------------------------------------------------- weapons

func launch_check(trk: int) -> String:
	if eq.missiles == 0:
		return "NO WEAPONS"
	if missiles_left <= 0:
		return "NO MISSILES"
	if not radar.tracks.has(trk):
		return "NO TRACK"
	var tr: Dictionary = radar.tracks[trk]
	if t - float(tr.last_t) > 4.0:
		return "TRACK STALE"
	var r := site.distance_to(trk_pos(tr))
	if r > eq.msl_range:
		return "OUT OF RANGE"
	if r < 1500.0:
		return "TOO CLOSE"
	if mission.roe:
		var tg := get_target(tr.tid)
		var designated := int(tr.cls) == Target.Kind.HOSTILE  # radar/EO operator called it hostile
		if not designated and (tg == null or not tg.auth):
			return "WEAPONS HOLD - NOT DESIGNATED HOSTILE"
	return ""


## Information the operators already have against firing on this track: "friend" / "civil" (IFF reply),
## "briefed" (HQ told them about this aircraft), or "".
func warning_for(tr: Dictionary) -> String:
	if tr.iff == "FRIEND":
		return "friend"
	if tr.iff == "CIVIL":
		return "civil"
	var tg := get_target(tr.tid)
	if tg != null and tg.hq_warned and tg.kind != Target.Kind.HOSTILE:
		return "briefed"
	return ""


## Operator command: destroy every missile in flight (e.g. after HQ calls check-fire).
func abort_missiles() -> void:
	for m: Dictionary in missiles:
		if not m.dead:
			_msl_end(m, "MISSILE SELF-DESTRUCT BY OPERATOR", "miss")
	missiles = missiles.filter(func(m): return not m.dead)


func launch(trk: int) -> void:
	if launch_check(trk) != "":
		return
	var tr: Dictionary = radar.tracks[trk]
	var d := trk_pos(tr) - site
	missiles.append({"pos": site, "alt": site_elev + 3.0, "h": atan2(d.x, -d.y), "speed": 0.0,
		"tid": tr.tid, "trk": trk, "age": 0.0, "dead": false, "trail": [Vector4(site.x, site.y, site_elev + 3.0, t)], "last_trail": 0.0, "knowing": warning_for(tr)})
	missiles_left -= 1
	add_log("MISSILE AWAY on TRK %d (%d left)" % [trk, missiles_left])
	sfx.emit("launch")
	say_key("launch")
	var warn := warning_for(tr)
	if warn != "":  # HQ / early warning object when the shooter has contrary information
		stats.warned += 1
		say_key("warn_" + warn)
		add_log("HQ WARNING: track is not hostile - self-destruct the missile!")
	if missiles_left == 0:
		say_key("no_ammo")
	elif missiles_left <= 2:
		say_key("low_ammo", missiles_left)


func _step_missiles(dt: float) -> void:
	for m: Dictionary in missiles:
		m.age += dt
		m.speed = minf(float(m.speed) + 350.0 * dt, 750.0)
		var mp: Vector2 = m.pos
		var spd: float = m.speed
		var tg := get_target(m.tid)
		var tr: Dictionary = radar.tracks.get(m.trk, {})
		var aim := Vector2.ZERO
		var aim_alt: float = m.alt
		var vel := Vector2.ZERO
		var guided := true
		if tg != null and mp.distance_to(tg.pos) < 4000.0:  # active seeker
			aim = tg.pos
			aim_alt = tg.alt
			vel = tg.vel()
		elif not tr.is_empty():  # radar command guidance
			aim = trk_pos(tr)
			aim_alt = tr.alt
			vel = tr.vel
		else:
			guided = false
		if guided:
			if mp.distance_to(aim) > 2500.0:  # terrain following: stay 80 m above the highest ground from here to 1.2 s ahead
				var hd: float = m.h
				var ahead := Vector2(sin(hd), -cos(hd)) * spd
				var gmax := 0.0
				for k in 4:
					gmax = maxf(gmax, world.elev_at(mp + ahead * (0.4 * k)))
				aim_alt = maxf(aim_alt, gmax + 80.0)
			aim += vel * (mp.distance_to(aim) / maxf(spd, 1.0))
			var d := aim - mp
			var want := atan2(d.x, -d.y)
			m.h = float(m.h) + clampf(wrapf(want - float(m.h), -PI, PI), -1.2 * dt, 1.2 * dt)
			# launch boost: at least 150 m/s of climb so a slow, just-launched missile clears the terrain ahead
			m.alt = float(m.alt) + clampf(aim_alt - float(m.alt), -0.4 * spd * dt, maxf(0.4 * spd, 150.0) * dt)
		var h: float = m.h
		mp += Vector2(sin(h), -cos(h)) * spd * dt
		m.pos = mp
		if float(m.age) - float(m.last_trail) > 0.4:
			m.last_trail = m.age
			m.trail.append(Vector4(mp.x, mp.y, float(m.alt), t))  # x, y, altitude, time (EO smoke trail + fire display)
		if float(m.alt) < world.elev_at(mp):
			_msl_end(m, "MISSILE IMPACTED TERRAIN", "terrain")
			continue
		for tt: Target in targets:
			if mp.distance_to(tt.pos) < 150.0 and absf(float(m.alt) - tt.alt) < 120.0:
				if rng.randf() < 0.85:
					tt.done = true
					tt.killed = true
					_retire(tt, String(m.knowing))
					targets.erase(tt)
					_msl_end(m, "", "")
				else:
					_msl_end(m, "WARHEAD DETONATED - NO KILL", "miss")
				break
		if not m.dead and (float(m.age) > 35.0 or mp.x < 0.0 or mp.y < 0.0 or mp.x > WorldGen.SIZE or mp.y > WorldGen.SIZE):
			_msl_end(m, "MISSILE SELF-DESTRUCT", "miss")
	missiles = missiles.filter(func(m): return not m.dead)
	while not msl_wakes.is_empty() and t - float(msl_wakes[0].t) > 15.0:
		msl_wakes.pop_front()


func _msl_end(m: Dictionary, msg: String, key: String) -> void:
	m.dead = true
	var pts: Array = m.trail.duplicate()
	var mpos: Vector2 = m.pos
	pts.append(Vector4(mpos.x, mpos.y, float(m.alt), t))
	msl_wakes.append({"pts": pts, "t": t, "key": key})
	sfx.emit({"": "explosion", "miss": "pop", "terrain": "thud"}.get(key, "pop"))
	if msg != "":
		add_log(msg)
	if key != "":
		say_key(key)


# ---------------------------------------------------------------- EO

func cam_alt() -> float:
	return site_elev + float(eq.eo.h)


func eo_range(tg: Target) -> float:
	var vis: float = wx.vis
	if eo.ir:  # thermal: better when cold, fog hurts less than for TV
		return float(eq.eo.ir_range) * (0.35 + 0.65 * tg.ir) * sqrt(vis) * lerpf(1.15, 0.8, clampf(temp / 40.0, 0.0, 1.0))
	return float(eq.eo.tv_range) * (0.08 + 0.92 * daylight()) * vis


func eo_sees(tg: Target) -> bool:
	return tg.pos.distance_to(site) < eo_range(tg) and world.los(site, cam_alt(), tg.pos, tg.alt)


func bearing_deg(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return fposmod(rad_to_deg(atan2(d.x, -d.y)), 360.0)


func eo_lrf() -> void:
	var tg := get_target(eo.sel)
	if tg != null and eo_sees(tg):
		var r := tg.pos.distance_to(site) + rng.randf_range(-5.0, 5.0)
		eo.lrf = r
		eo.lrf_alt = tg.alt + rng.randf_range(-20.0, 20.0)
		say_key("lrf", roundi(r / 10.0) * 10)
		sfx.emit("beep")
	else:
		eo.lrf = -1.0


func eo_lock() -> void:
	var tg := get_target(eo.sel)
	if tg != null and eo_sees(tg):
		eo.lock = tg.id
		eo.slave = -1
		add_log("EO LOCK ON")
		say_key("lock")
		sfx.emit("lock")


func _step_eo(dt: float) -> void:
	if eq.eo.is_empty():
		return
	if eo.lock >= 0:
		var tg := get_target(eo.lock)
		if tg == null or not eo_sees(tg):
			eo.lock = -1
			add_log("EO LOCK LOST")
			say_key("lock_lost")
			sfx.emit("lost")
		else:
			eo.az = bearing_deg(site, tg.pos)
			eo.el = rad_to_deg(atan2(tg.alt - cam_alt(), site.distance_to(tg.pos)))
	elif eo.slave >= 0:
		if not radar.tracks.has(eo.slave):
			eo.slave = -1
			return
		var tr: Dictionary = radar.tracks[eo.slave]
		var p := trk_pos(tr)
		var waz := bearing_deg(site, p)
		var wel := rad_to_deg(atan2(float(tr.alt) - cam_alt(), site.distance_to(p)))
		eo.az = fposmod(float(eo.az) + clampf(wrapf(waz - float(eo.az), -180.0, 180.0), -30.0 * dt, 30.0 * dt), 360.0)
		eo.el = float(eo.el) + clampf(wel - float(eo.el), -15.0 * dt, 15.0 * dt)
