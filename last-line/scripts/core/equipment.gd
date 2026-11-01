class_name Equipment
extends RefCounted
## Equipment definition = data only. Add a new system by adding an entry to catalog()
## and (if needed) a new station script. All figures are FICTIONAL test values.

var id := ""
var title := ""
var desc := ""
var stations: Array = []  # station ids, one operator each: "radar" | "eo" | "fire"
var radar: Dictionary = {}  # range (m @ 1 m2 RCS), period (s/rev), ant_h (m)
var eo: Dictionary = {}  # h (m), tv_range, ir_range (m)
var missiles := 0
var msl_range := 20000.0


static func catalog() -> Array:
	var a := Equipment.new()
	a.id = "t1"
	a.title = "TEST-1 SENTINEL"
	a.desc = "Fictional mobile SHORAD post. 3 operators: search radar, EO/IR turret, fire control (8 missiles)."
	a.stations = ["radar", "eo", "fire"]
	a.radar = {"range": 60000.0, "period": 4.0, "ant_h": 8.0}
	a.eo = {"h": 6.0, "tv_range": 18000.0, "ir_range": 14000.0}
	a.missiles = 8

	var b := Equipment.new()
	b.id = "t2"
	b.title = "TEST-2 LONGEYE"
	b.desc = "Fictional early-warning radar. 1 operator, no weapons. Report tracks by IFF and kinematics."
	b.stations = ["radar"]
	b.radar = {"range": 90000.0, "period": 6.0, "ant_h": 14.0}

	var c := Equipment.new()
	c.id = "t3"
	c.title = "TEST-3 WATCHPOST"
	c.desc = "Fictional EO observation post. 1 operator, TV/IR turret only, no radar, no weapons."
	c.stations = ["eo"]
	c.eo = {"h": 10.0, "tv_range": 22000.0, "ir_range": 16000.0}
	return [a, b, c]
