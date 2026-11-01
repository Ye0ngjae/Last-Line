class_name Mission
extends RefCounted
## Data-driven scenario: a spawn script + one goal type. A campaign is just a list of these.
## Add goal types in tick()/on_event()/objective_text().

var id := ""
var title := ""
var brief := ""
var type := "intercept"  # intercept | support | detect
var need := 3
var time_limit := 600.0
var needs_weapons := false
var roe := false  # true: missiles need an authorised (declared / correctly reported hostile) target
var spawns: Array = []  # {t, kind, model, bearing?, tag?}
## Scripted radio: {t, from, en, ko, warn? (marks the tagged aircraft as briefed friendly/civil), tag?, every?, until?("tracked"), range_lt?, declare?}.
## {brg} {rng} {alt} {spd} {hdg} in en/ko are filled from the tagged target's current state.
var radio: Array = []
var tags := {}
var status := "active"  # active | won | lost
var why := ""
var kills := 0
var good_reports := 0
var friendly_lost := 0
var _next := 0


func start(_sim: Sim) -> void:
	spawns.sort_custom(func(a, b): return a.t < b.t)


func tick(sim: Sim, _dt: float) -> void:
	if status != "active":
		return
	while _next < spawns.size() and float(spawns[_next].t) <= sim.t:
		var s: Dictionary = spawns[_next]
		_next += 1
		var tg := sim.spawn(s.kind, s.model, s.get("bearing", -1.0))
		if s.has("tag"):
			tags[s.tag] = tg
	_tick_radio(sim)
	var finished := _next >= spawns.size() and sim.live_count() == 0
	if sim.site_hp <= 0:
		_end("lost", "Site destroyed.")
	elif type == "intercept" and kills >= need:
		_end("won", "All required hostiles destroyed.")
	elif type == "detect" and good_reports >= need:
		_end("won", "Required reports delivered.")
	elif type == "support" and friendly_lost > 0:
		_end("lost", "Friendly aircraft shot down.")
	elif finished:
		if type == "support" and good_reports >= need:
			_end("won", "Friendly package safely identified.")
		else:
			_end("lost", "Objective not met.")
	elif sim.t > time_limit:
		_end("lost", "Time expired.")


func _tick_radio(sim: Sim) -> void:
	for e: Dictionary in radio:
		if e.get("done", false) or sim.t < float(e.t):
			continue
		var tg: Target = null
		if e.has("tag"):
			tg = tags.get(e.tag)
			if tg == null:
				continue  # not spawned yet
			if sim.get_target(tg.id) == null:
				e.done = true
				continue
			if e.has("range_lt") and tg.pos.distance_to(sim.site) > float(e.range_lt):
				continue
			if e.get("until", "") == "tracked" and _tracked(sim, tg):
				e.done = true
				continue
		if tg != null and e.get("declare", false):
			tg.auth = true
		if tg != null and e.get("warn", false):
			tg.hq_warned = true
		sim.say(e.from, e.en, e.ko, sim.describe(tg) if tg != null else {})
		if e.has("every"):
			e.t = sim.t + float(e.every)
		else:
			e.done = true


func _tracked(sim: Sim, tg: Target) -> bool:
	for k in sim.radar.tracks:
		if sim.radar.tracks[k].tid == tg.id:
			return true
	return false


func on_event(_sim: Sim, ev: String, tg: Target, ok := true) -> void:
	match ev:
		"killed":
			if tg.kind == Target.Kind.HOSTILE:
				kills += 1
			elif tg.kind == Target.Kind.FRIENDLY:
				friendly_lost += 1
		"reported":
			if ok and (type != "support" or tg.kind == Target.Kind.FRIENDLY):
				good_reports += 1


func objective_text(sim: Sim) -> String:
	var left := maxi(0, int(time_limit - sim.t))
	match type:
		"intercept": return "Destroy hostiles %d/%d  |  %d s left" % [kills, need, left]
		"support": return "Report FRIENDLY aircraft %d/%d, no fratricide  |  %d s left" % [good_reports, need, left]
		_: return "Report targets correctly %d/%d  |  %d s left" % [good_reports, need, left]


func _end(st: String, msg: String) -> void:
	status = st
	why = msg


static func _s(t: float, kind: int, model: String, bearing := -1.0, tag := "") -> Dictionary:
	var d := {"t": t, "kind": kind, "model": model, "bearing": bearing}
	if tag != "":
		d["tag"] = tag
	return d


static func _r(t: float, from: String, en: String, ko: String, extra := {}) -> Dictionary:
	var d := {"t": t, "from": from, "en": en, "ko": ko}
	d.merge(extra)
	return d


static func catalog() -> Array:
	var H := Target.Kind.HOSTILE
	var F := Target.Kind.FRIENDLY
	var C := Target.Kind.CIVIL
	var B := Target.Kind.BIRD

	var a := Mission.new()
	a.id = "intercept"
	a.title = "INTERCEPT"
	a.brief = "HQ-directed air raid. HQ radios bearing/range of bandits; find them on the scope, track, identify, engage once authorised."
	a.type = "intercept"
	a.need = 3
	a.time_limit = 600.0
	a.needs_weapons = true
	a.roe = true
	a.spawns = [_s(5, B, "FLOCK", -1, "B1"), _s(30, H, "FIGHTER-X", 40, "R1"), _s(45, C, "AIRLINER", -1, "C1"),
		_s(90, H, "DRONE-D", 200, "R2"), _s(110, B, "FLOCK"), _s(120, F, "ALLY-F", 300, "F1"), _s(150, H, "BOMBER-B", 320, "R3")]
	a.radio = [
		_r(2, "HQ", "Sentinel, HQ. Enemy air raid indicated. All stations alert. Engage only after HQ declaration or confirmed identification.", "센티넬, HQ. 적 공습 징후 포착. 전 오퍼레이터 경계 태세. 교전은 HQ 선언 또는 식별 확인 후에만 허가한다."),
		_r(8, "Squad Leader", "Everyone to your positions. Start with a wide radar sweep.", "전원 위치로. 레이더 먼저 크게 돌려 봐."),
		_r(15, "HQ", "One civil airliner will transit your sector. Watch for friendly fire.", "민간 항공기 1대가 구역을 통과할 예정이다. 오사에 주의하라."),
		_r(33, "HQ", "Early warning relay. Unknown contact, bearing {brg}, range {rng} kilometers, {alt}, {spd}, {hdg}. Search and report.", "조기경보 정보. 미확인 표적, 방위 {brg}, 거리 {rng}킬로, {alt}, {spd}, {hdg}. 탐색해서 보고하라.", {"tag": "R1", "every": 30, "until": "tracked"}),
		_r(34, "HQ", "Contact bearing {brg}, range {rng} kilometers. Declared hostile. Cleared to engage.", "표적 방위 {brg}, 거리 {rng}킬로. 적기로 선언한다. 교전 허가.", {"tag": "R1", "range_lt": 38000.0, "declare": true}),
		_r(40, "Radar Operator", "Weak slow echo bearing {brg}. Looks like birds.", "방위 {brg} 쪽에 저속 약한 에코. 새 떼 같다.", {"tag": "B1"}),
		_r(48, "HQ", "Airliner bearing {brg}, range {rng} kilometers, {alt}. Hold fire.", "민항기 방위 {brg}, 거리 {rng}킬로, {alt}. 사격 금지.", {"tag": "C1", "warn": true}),
		_r(92, "HQ", "Small contact, bearing {brg}, range {rng} kilometers, {alt}, {spd}. Suspected drone.", "소형 표적, 방위 {brg}, 거리 {rng}킬로, {alt}, {spd}. 드론으로 추정된다.", {"tag": "R2", "every": 35, "until": "tracked"}),
		_r(93, "HQ", "Small contact bearing {brg}, range {rng} kilometers. Declared hostile drone. Cleared to engage.", "방위 {brg}, 거리 {rng}킬로 소형 표적. 적 드론으로 선언한다. 교전 허가.", {"tag": "R2", "range_lt": 30000.0, "declare": true}),
		_r(123, "HQ", "One friendly fighter returning. Bearing {brg}, range {rng} kilometers. Its transponder may be faulty, so verify.", "아군 전투기 1기 복귀 중. 방위 {brg}, 거리 {rng}킬로. 응답기 고장일 수 있으니 확실히 확인하라.", {"tag": "F1", "warn": true}),
		_r(152, "HQ", "Large contact approaching, {alt}. Bearing {brg}, range {rng} kilometers. Suspected bomber.", "대형 표적 접근, {alt}. 방위 {brg}, 거리 {rng}킬로. 폭격기로 추정된다.", {"tag": "R3", "every": 30, "until": "tracked"}),
		_r(153, "HQ", "Bomber bearing {brg}, range {rng} kilometers. Declared hostile. Cleared to engage.", "폭격기 방위 {brg}, 거리 {rng}킬로. 적기로 선언한다. 교전 허가.", {"tag": "R3", "range_lt": 38000.0, "declare": true}),
	]

	var b := Mission.new()
	b.id = "support"
	b.title = "SUPPORT"
	b.brief = "Friendly strike package returning. Identify and report all 3 as FRIENDLY. Do not shoot them."
	b.type = "support"
	b.need = 3
	b.time_limit = 420.0
	b.spawns = [_s(10, F, "ALLY-F", 90, "F1"), _s(25, C, "AIRLINER"), _s(40, B, "FLOCK"), _s(50, F, "ALLY-F", 120, "F2"),
		_s(80, H, "DRONE-D", 250, "H1"), _s(100, F, "ALLY-F", 300, "F3")]
	b.radio = [
		_r(2, "HQ", "Sentinel, HQ. Friendly strike package returning, three aircraft. Identify positively. No friendly fire.", "센티넬, HQ. 아군 타격 편대가 복귀한다. 총 3기. 오사 없도록 식별을 확실히 하라."),
		_r(13, "HQ", "Friendly returnee bearing {brg}, range {rng} kilometers, {alt}. Transponder status uncertain.", "아군 복귀기 방위 {brg}, 거리 {rng}킬로, {alt}. 응답기 상태는 불확실하다.", {"tag": "F1", "warn": true}),
		_r(53, "HQ", "Second returnee bearing {brg}, range {rng} kilometers.", "두 번째 복귀기 방위 {brg}, 거리 {rng}킬로.", {"tag": "F2", "warn": true}),
		_r(83, "HQ", "Warning. An enemy drone may be mixed in with the package. Bearing {brg}, range {rng} kilometers.", "경고. 복귀 편대 주변에 적 드론이 섞였을 수 있다. 방위 {brg}, 거리 {rng}킬로.", {"tag": "H1"}),
		_r(103, "HQ", "Last returnee bearing {brg}, range {rng} kilometers.", "마지막 복귀기 방위 {brg}, 거리 {rng}킬로.", {"tag": "F3", "warn": true}),
	]

	var c := Mission.new()
	c.id = "detect"
	c.title = "DETECT & REPORT"
	c.brief = "Survey the sector. Detect and correctly classify 5 air objects."
	c.type = "detect"
	c.need = 5
	c.time_limit = 420.0
	c.spawns = [_s(5, C, "AIRLINER"), _s(15, B, "FLOCK"), _s(30, F, "ALLY-F"), _s(50, H, "FIGHTER-X"),
		_s(60, B, "FLOCK"), _s(80, H, "DRONE-D"), _s(100, C, "AIRLINER")]
	c.radio = [
		_r(2, "HQ", "Sentinel, HQ. Surveillance tasking for your sector. Identify and report every track.", "센티넬, HQ. 담당 구역 정찰 임무다. 탐지한 항적은 식별해서 보고하라."),
		_r(30, "Squad Leader", "Keep your reports accurate. Wrong calls cost points.", "보고는 정확하게. 오보는 감점이다."),
	]
	return [a, b, c]
