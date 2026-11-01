class_name Target
extends RefCounted
## Air object (hostile / friendly / civil / bird). Position in metres, heading in radians from north.

enum Kind { HOSTILE, FRIENDLY, CIVIL, BIRD }
const KIND_NAMES := ["HOSTILE", "FRIENDLY", "CIVIL", "BIRD"]
## alt = AGL range for terrain followers (tf), ASL otherwise. turn = max turn rate, rad/s (airliner ~3 deg/s, fighter ~17 deg/s).
const MODELS := {
	"FIGHTER-X": {"speed": 280.0, "turn": 0.3, "rcs": 3.0, "ir": 0.9, "size": 15.0, "alt": Vector2(120, 500), "tf": true, "shape": "jet"},
	"BOMBER-B": {"speed": 210.0, "turn": 0.08, "rcs": 12.0, "ir": 0.8, "size": 35.0, "alt": Vector2(4000, 6000), "tf": false, "shape": "bomber"},
	"DRONE-D": {"speed": 55.0, "turn": 0.15, "rcs": 0.15, "ir": 0.3, "size": 4.0, "alt": Vector2(150, 600), "tf": true, "shape": "uav"},
	"ALLY-F": {"speed": 250.0, "turn": 0.3, "rcs": 3.0, "ir": 0.9, "size": 14.0, "alt": Vector2(2500, 4500), "tf": false, "shape": "ally"},
	"AIRLINER": {"speed": 230.0, "turn": 0.05, "rcs": 40.0, "ir": 0.6, "size": 45.0, "alt": Vector2(8500, 10500), "tf": false, "shape": "liner"},
	"FLOCK": {"speed": 14.0, "turn": 0.5, "rcs": 0.002, "ir": 0.12, "size": 1.5, "alt": Vector2(80, 400), "tf": true, "shape": "bird"},
}

var id := 0
var kind := 0
var model := ""
var shape := "jet"
var pos := Vector2.ZERO
var alt := 0.0
var agl := 0.0
var heading := 0.0
var speed := 0.0
var turn := 0.3
var rcs := 1.0
var ir := 0.5
var size := 10.0
var tf := false
var wander := false
var iff_fault := false
var waypoints: Array[Vector2] = []
var age := 0.0
var done := false
var killed := false
var hq_warned := false  # HQ briefed the crew about this friendly/civil aircraft
var auth := false  # engagement authorised (HQ declared hostile or correctly reported)
var echo_t := -1000.0  # last time its echo was strong enough to track
var echo_pos := Vector2.ZERO
var los_rev := -1  # radar revolution the LOS/fluctuation below were computed for
var los_ok := false
var fl := 1.0


func vel() -> Vector2:
	return Vector2(sin(heading), -cos(heading)) * speed


func step(dt: float, rng: RandomNumberGenerator) -> void:
	age += dt
	if wander:
		heading += rng.randf_range(-1.0, 1.0) * 1.5 * dt
		if age > 150.0:
			done = true
	elif waypoints.is_empty():
		done = true
	else:
		var d := waypoints[0] - pos
		var want := atan2(d.x, -d.y)
		heading += clampf(wrapf(want - heading, -PI, PI), -turn * dt, turn * dt)
		if d.length() < maxf(700.0, speed / turn):  # a slow-turning aircraft can't hit a point closer than its turn radius
			waypoints.pop_front()
	pos += vel() * dt
	if pos.x < -2000.0 or pos.y < -2000.0 or pos.x > WorldGen.SIZE + 2000.0 or pos.y > WorldGen.SIZE + 2000.0:
		done = true
