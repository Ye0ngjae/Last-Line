class_name Sfx
extends Node
## Procedural sound effects (no audio assets): switches, relays, motors, beeps, alarm, missile launch, explosions.
## Sounds are synthesised on first use and cached. Call Sfx.play("name") / Sfx.loop("motor", on) from anywhere.

const BUS := "SFX"
const RATE := 22050

static var inst: Sfx

var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _loop := AudioStreamPlayer.new()
var _loop_name := ""
var _rng := RandomNumberGenerator.new()


static func play(sound: String, vol_db := 0.0) -> void:
	if inst != null:
		inst._play(sound, vol_db)


## Start/stop a looping sound (idempotent, safe to call every frame).
static func loop(sound: String, on: bool) -> void:
	if inst != null:
		inst._set_loop(sound, on)


func _ready() -> void:
	inst = self
	_rng.seed = 11
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, "Master")
	for n in 8:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_pool.append(p)
	_loop.bus = BUS
	add_child(_loop)
	Settings.apply_audio()


func _exit_tree() -> void:
	if inst == self:
		inst = null


func _play(sound: String, vol_db: float) -> void:
	var st := _stream(sound)
	if st == null:
		return
	var pl := _pool[0]
	for p in _pool:
		if not p.playing:
			pl = p
			break
	pl.stream = st
	pl.volume_db = vol_db
	pl.play()


func _set_loop(sound: String, on: bool) -> void:
	if not on:
		if _loop_name != "":
			_loop.stop()
			_loop_name = ""
		return
	if _loop_name == sound:
		return
	var st := _stream(sound)
	if st == null:
		return
	_loop_name = sound
	_loop.stream = st
	_loop.volume_db = -8.0
	_loop.play()


func _stream(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = _make(sound)
	return _cache[sound]


# ---------------------------------------------------------------- synthesis

func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b


## Add a decaying sine (optionally gliding f -> f_end) starting at `at` seconds.
func _tone(b: PackedFloat32Array, f: float, at: float, dur: float, amp: float, decay := 8.0, f_end := -1.0) -> void:
	var n := int(dur * RATE)
	var s0 := int(at * RATE)
	var ph := 0.0
	for i in n:
		if s0 + i >= b.size():
			break
		var u := float(i) / n
		var fr := f if f_end < 0.0 else lerpf(f, f_end, u)
		ph += TAU * fr / RATE
		b[s0 + i] += sin(ph) * amp * exp(-decay * u * dur)


## Add low-passed noise with an exponential decay envelope.
func _noise(b: PackedFloat32Array, at: float, dur: float, amp: float, decay: float, lp := 0.3) -> void:
	var n := int(dur * RATE)
	var s0 := int(at * RATE)
	var y := 0.0
	for i in n:
		if s0 + i >= b.size():
			break
		y += (_rng.randf_range(-1.0, 1.0) - y) * lp
		b[s0 + i] += y * amp * exp(-decay * float(i) / RATE)


func _wav(b: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = b.size()
	return w


func _make(sound: String) -> AudioStreamWAV:
	var b := _buf(0.2)
	match sound:
		"click":  # push-button
			_tone(b, 1900.0, 0.0, 0.02, 0.5, 60.0)
			_noise(b, 0.0, 0.01, 0.4, 300.0, 0.6)
		"on":  # toggle switch up
			_tone(b, 1500.0, 0.0, 0.03, 0.45, 70.0)
			_noise(b, 0.0, 0.01, 0.4, 300.0, 0.6)
			_tone(b, 2100.0, 0.05, 0.03, 0.3, 70.0)
		"off":  # toggle switch down
			_tone(b, 1100.0, 0.0, 0.03, 0.45, 70.0)
			_noise(b, 0.0, 0.01, 0.4, 300.0, 0.5)
			_tone(b, 750.0, 0.05, 0.04, 0.3, 60.0)
		"tick":  # detent / slider step
			_tone(b, 2600.0, 0.0, 0.01, 0.25, 200.0)
		"clunk":  # heavy arm switch / launch button
			b = _buf(0.3)
			_tone(b, 95.0, 0.0, 0.2, 0.9, 18.0)
			_noise(b, 0.0, 0.05, 0.7, 70.0, 0.15)
			_tone(b, 1700.0, 0.0, 0.015, 0.4, 100.0)
		"beep":
			b = _buf(0.15)
			_tone(b, 900.0, 0.0, 0.1, 0.4, 10.0)
		"lock":
			b = _buf(0.3)
			_tone(b, 1000.0, 0.0, 0.08, 0.4, 10.0)
			_tone(b, 1500.0, 0.12, 0.1, 0.4, 10.0)
		"lost":
			b = _buf(0.35)
			_tone(b, 650.0, 0.0, 0.3, 0.4, 5.0, 280.0)
		"chirp":
			b = _buf(0.2)
			_tone(b, 1200.0, 0.0, 0.14, 0.35, 6.0, 2400.0)
		"alarm":
			b = _buf(1.0)
			for k in 3:
				_tone(b, 820.0, k * 0.33, 0.16, 0.5, 2.0)
				_tone(b, 520.0, k * 0.33 + 0.16, 0.16, 0.5, 2.0)
		"launch":  # ignition thump, then a rising rocket whoosh and rumble
			b = _buf(2.4)
			_tone(b, 70.0, 0.0, 0.3, 0.8, 12.0)
			_noise(b, 0.0, 0.06, 0.8, 50.0, 0.25)
			var y := 0.0
			for i in b.size():
				var tt := float(i) / RATE
				y += (_rng.randf_range(-1.0, 1.0) - y) * lerpf(0.05, 0.45, minf(tt / 1.5, 1.0))
				b[i] += y * 0.9 * minf(tt / 0.1, 1.0) * exp(-tt * 1.4)
			_tone(b, 55.0, 0.05, 2.0, 0.5, 1.6)
		"explosion":  # sharp crack, low boom, rolling rumble, then debris crackle
			b = _buf(2.6)
			_noise(b, 0.0, 0.04, 1.0, 90.0, 0.8)
			_noise(b, 0.0, 0.6, 0.9, 6.0, 0.25)
			_noise(b, 0.05, 2.4, 0.7, 1.7, 0.06)
			_tone(b, 42.0, 0.0, 1.6, 0.9, 2.8, 28.0)
			_tone(b, 85.0, 0.0, 0.4, 0.5, 9.0)
			for i in 26:
				_noise(b, 0.25 + _rng.randf() * 1.9, 0.012, 0.3 * (1.0 - float(i) / 30.0), 120.0, 0.7)
		"pop":  # warhead fizzles
			b = _buf(0.4)
			_noise(b, 0.0, 0.35, 0.7, 12.0, 0.3)
		"thud":  # missile hits terrain
			b = _buf(0.5)
			_tone(b, 60.0, 0.0, 0.4, 0.9, 12.0)
			_noise(b, 0.0, 0.2, 0.6, 18.0, 0.1)
		"buzz":  # refused action
			b = _buf(0.22)
			for i in b.size():
				b[i] = (0.25 if fmod(float(i) * 140.0 / RATE, 1.0) < 0.5 else -0.25) * (1.0 - float(i) / b.size())
		"motor":  # servo whirr; integer cycles so the loop is seamless
			b = _buf(0.4)
			var y2 := 0.0
			for i in b.size():
				var tt2 := float(i) / RATE
				y2 += (_rng.randf_range(-1.0, 1.0) - y2) * 0.3
				b[i] = sin(TAU * 110.0 * tt2) * 0.25 + sin(TAU * 220.0 * tt2) * 0.12 + sin(TAU * 330.0 * tt2) * 0.06 + y2 * 0.1
			return _wav(b, true)
	return _wav(b)
