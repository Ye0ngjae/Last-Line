class_name RadioVoice
extends Node
## Plays pre-rendered speech clips chained into one transmission, through a "Radio" bus
## (band-limited + light distortion) with squelch bursts. Numbers are spoken digit by digit.

const BUS := "Radio"
const VOICES := {"HQ": "hq", "Squad Leader": "squad", "Comms": "comms", "Radar Operator": "radar",
	"EO Operator": "eo", "Fire Control": "fire"}
const DIGITS := ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "niner"]
const DIGIT_KEYS := ["brg", "rng", "n"]
const WORDS := {"alt": Radio.ALT_EN, "spd": Radio.SPD_EN, "hdg": Radio.HDG_EN}

signal finished

var busy := false
var _player := AudioStreamPlayer.new()
var _queue: Array = []
var _on: AudioStreamWAV
var _off: AudioStreamWAV


static func clip_path(voice: String, text: String) -> String:
	return "res://audio/radio/%s/%s.ogg" % [VOICES.get(voice, "hq"), text.md5_text().substr(0, 10)]


## Static text pieces of a template, cleaned the same way for synthesis and playback.
static func pieces(tpl: String) -> Array:
	var out: Array = []
	var re := RegEx.create_from_string("\\{(\\w+)\\}")
	var pos := 0
	for m in re.search_all(tpl):
		out.append(_clean(tpl.substr(pos, m.get_start() - pos)))
		out.append("{" + m.get_string(1) + "}")
		pos = m.get_end()
	out.append(_clean(tpl.substr(pos)))
	return out.filter(func(p: String): return p != "")


static func _clean(s: String) -> String:
	s = s.strip_edges()
	while s != "" and s[0] in ",;: ":
		s = s.substr(1)
	return s if s.to_lower() != s.to_upper() else ""  # punctuation-only -> nothing to say


## Every clip text a template may need (static pieces + digits + all descriptor words).
static func needed(tpl: String) -> Array:
	var out: Array = []
	for p: String in pieces(tpl):
		if p.begins_with("{"):
			var k := p.substr(1, p.length() - 2)
			if k in DIGIT_KEYS:
				out.append_array(DIGITS)
			elif WORDS.has(k):
				out.append_array(WORDS[k])
		else:
			out.append(p)
	return out


func _ready() -> void:
	_make_bus()
	_player.bus = BUS
	_player.finished.connect(_next)
	add_child(_player)
	_on = _noise(0.09, 0.22)
	_off = _noise(0.05, 0.16)
	Settings.apply_audio()


func _make_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, "Master")
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 420.0
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 3200.0
	var ds := AudioEffectDistortion.new()
	ds.mode = AudioEffectDistortion.MODE_OVERDRIVE
	ds.drive = 0.18
	ds.post_gain = -2.0
	for e in [hp, lp, ds]:
		AudioServer.add_bus_effect(i, e)


## Squelch: a short decaying noise burst.
static func _noise(len_s: float, amp: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(len_s * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in n:
		var v := int(r.randf_range(-1.0, 1.0) * amp * (1.0 - float(i) / n) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func _clip(voice: String, text: String) -> AudioStream:
	var path := clip_path(voice, text)
	return load(path) as AudioStream if ResourceLoader.exists(path) else null


## Returns false when no audio could be built (caller falls back to subtitle timing).
func speak(voice: String, tpl: String, vars: Dictionary) -> bool:
	stop()
	var clips: Array = []
	for p: String in pieces(tpl):
		if p.begins_with("{"):
			var k := p.substr(1, p.length() - 2)
			var v := str(vars.get(k, ""))
			if k in DIGIT_KEYS:
				for ch in v:
					if ch.is_valid_int():
						clips.append(_clip(voice, DIGITS[int(ch)]))
			else:
				clips.append(_clip(voice, v))
		else:
			clips.append(_clip(voice, p))
	clips = clips.filter(func(c): return c != null)
	if clips.is_empty():
		return false
	_queue = [_on] + clips + [_off]
	busy = true
	_next()
	return true


func stop() -> void:
	_queue.clear()
	_player.stop()
	busy = false


func _next() -> void:
	if _queue.is_empty():
		if busy:
			busy = false
			finished.emit()
		return
	_player.stream = _queue.pop_front()
	_player.play()
