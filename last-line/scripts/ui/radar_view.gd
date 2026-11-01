class_name RadarView
extends Control
## The radar scope picture (echo video shader + rings + tracks). Used full-size by the radar operator
## and as a small mirror (picture-in-picture) on the EO screen. It reads the shared range from the Sim,
## so the mirror always shows what the radar operator set.

const RANGES := [10.0, 25.0, 50.0, 90.0]  # km
const SHADER := """
shader_type canvas_item;
uniform sampler2D video : filter_linear, repeat_enable;
uniform vec2 view_size;
uniform float rad;
uniform float range_frac;
uniform float sweep;
uniform float decay;
uniform float power;
uniform float t;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 p = UV * view_size - view_size * 0.5;
	float r = length(p) / rad;
	vec3 bg = vec3(0.01, 0.03, 0.10);
	if (r > 1.0) { COLOR = vec4(0.0, 0.0, 0.0, 0.0); }
	else {
		float az = atan(p.x, -p.y);
		if (az < 0.0) az += TAU;
		float s = texture(video, vec2(az / TAU, r * range_frac)).r;
		float behind = mod(sweep - az, TAU) / TAU;
		float v = s * exp(-behind * decay) * power;
		float grain = hash(floor(FRAGCOORD.xy / 2.0) + floor(t * 25.0)) * 0.05 * power;
		vec3 col = mix(vec3(0.1, 0.9, 0.3), vec3(1.0, 0.92, 0.15), smoothstep(0.35, 0.85, v));
		COLOR = vec4(bg + col * clamp(v * 1.3, 0.0, 1.0) + vec3(0.0, grain, 0.0), 1.0);
	}
}
"""

var sim: Sim
var compact := false
var cursor := Vector2(-1, -1)
var font := ThemeDB.fallback_font
var _video_rect := ColorRect.new()
var _overlay := Control.new()
var _mat := ShaderMaterial.new()
var _img: Image
var _tex: ImageTexture
var _ver := -1


func setup(p_sim: Sim, p_compact := false) -> void:
	sim = p_sim
	compact = p_compact
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_img = Image.create_from_data(Sim.AZ_BINS, Sim.RANGE_BINS, false, Image.FORMAT_R8, sim.video)
	_tex = ImageTexture.create_from_image(_img)
	_mat.set_shader_parameter("video", _tex)
	_video_rect.material = _mat
	_video_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_video_rect)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


## [center, radius px, range m]
func geom() -> Array:
	return [size * 0.5, minf(size.x, size.y) * 0.5 - (4.0 if compact else 18.0), float(RANGES[sim.radar.range_i]) * 1000.0]


func tick() -> void:
	if _ver != sim.video_ver:
		_ver = sim.video_ver
		_img.set_data(Sim.AZ_BINS, Sim.RANGE_BINS, false, Image.FORMAT_R8, sim.video)
		_tex.update(_img)
	var g := geom()
	_mat.set_shader_parameter("view_size", size)
	_mat.set_shader_parameter("rad", g[1])
	_mat.set_shader_parameter("range_frac", minf(float(g[2]) / sim.video_range, 1.0))
	_mat.set_shader_parameter("sweep", sim.radar.az)
	_mat.set_shader_parameter("decay", 2.2)
	_mat.set_shader_parameter("power", 1.0 if sim.radar.on else 0.0)
	_mat.set_shader_parameter("t", sim.t)
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	var g := geom()
	var c: Vector2 = g[0]
	var rad: float = g[1]
	var range_m: float = g[2]
	var ring := Color(0.3, 0.5, 0.8, 0.5)
	for i in range(1, 5):
		_overlay.draw_arc(c, rad * i / 4.0, 0, TAU, 64, ring, 1.0)
		if not compact:
			_overlay.draw_string(font, c + Vector2(4, -rad * i / 4.0 - 2), "%d" % roundi(range_m * i / 4000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
	if not compact:
		for a in range(0, 360, 10):
			var dir := Vector2(sin(deg_to_rad(a)), -cos(deg_to_rad(a)))
			_overlay.draw_line(c + dir * rad, c + dir * (rad + (10.0 if a % 30 == 0 else 5.0)), ring, 1.0)
			if a % 30 == 0:
				_overlay.draw_string(font, c + dir * (rad + 14.0) - Vector2(10, -4), "%03d" % a, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.DIM)
	else:
		_overlay.draw_arc(c, rad, 0, TAU, 64, Color(0.4, 0.6, 0.9, 0.8), 1.5)
	draw_tracks(_overlay, sim, c, rad, range_m)
	_overlay.draw_string(font, Vector2(8, 16), ("RDR %d km" % (range_m / 1000.0)) if compact else
		"RANGE %d km  GAIN %.2f  %s%s%s" % [range_m / 1000.0, sim.radar.gain, "TX" if sim.radar.on else "STBY",
		"  MTI" if sim.radar.mti else "", "  RAIN-F" if sim.radar.rain_filter else ""],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11 if compact else 14, UI.GREEN)
	if not compact and cursor.x >= 0.0 and cursor.distance_to(c) < rad:
		var w := (cursor - c) / rad * range_m
		_overlay.draw_string(font, Vector2(8, size.y - 10), "CURSOR  RNG %.1f km  BRG %03d" % [w.length() / 1000.0,
			roundi(fposmod(rad_to_deg(atan2(w.x, -w.y)), 360.0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.AMBER)


static func draw_tracks(c: Control, p_sim: Sim, center: Vector2, rad: float, range_m: float) -> void:
	var f := ThemeDB.fallback_font
	for k in p_sim.radar.tracks:
		var tr: Dictionary = p_sim.radar.tracks[k]
		var q := center + (p_sim.trk_pos(tr) - p_sim.site) / range_m * rad
		if q.distance_to(center) > rad:
			continue
		var col: Color = Station.CLS_COLORS[int(tr.cls) + 1]
		c.draw_rect(Rect2(q - Vector2(6, 6), Vector2(12, 12)), col, false, 2.0)
		var v: Vector2 = tr.vel
		c.draw_line(q, q + v / range_m * rad * 60.0, col, 1.5)
		c.draw_string(f, q + Vector2(10, -8), "T%d" % k, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		if k == p_sim.sel_trk:
			c.draw_arc(q, 13, 0, TAU, 20, Color.WHITE, 1.5)
