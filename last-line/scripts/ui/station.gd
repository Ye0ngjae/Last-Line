class_name Station
extends Control
## One operator position: a metal bezel, a clipped `screen` (subclass draws on it) and a control `panel`.
## Hidden stations are not ticked/drawn - keeps the web build light.

const CLS_COLORS := [Color(1, 0.8, 0.2), Color(1, 0.3, 0.25), Color(0.3, 0.85, 1), Color(0.95, 0.95, 0.95), Color(0.6, 0.6, 0.6)]
const PANEL_W := 250.0

var sim: Sim
var screen := Control.new()
var panel := VBoxContainer.new()
var info := Label.new()
var font := ThemeDB.fallback_font


func _init() -> void:
	add_child(screen)
	add_child(panel)
	screen.clip_contents = true
	screen.draw.connect(_draw_screen)
	screen.gui_input.connect(_screen_input)
	resized.connect(_layout)
	panel.add_theme_constant_override("separation", 6)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # long status lines wrap inside the panel


func setup(p_sim: Sim) -> void:
	sim = p_sim
	_build()
	panel.add_child(info)
	panel.move_child(info, 1)  # readout right under the title


func _layout() -> void:
	screen.position = Vector2(24, 24)
	screen.size = Vector2(size.x - 48.0 - PANEL_W - 12.0, size.y - 48.0)
	panel.position = Vector2(size.x - 24.0 - PANEL_W, 24)
	panel.size = Vector2(PANEL_W, size.y - 48.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.17, 0.18, 0.15))
	draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(0.34, 0.35, 0.3), false, 3.0)
	draw_rect(Rect2(screen.position - Vector2(4, 4), screen.size + Vector2(8, 8)), Color(0.05, 0.05, 0.05), false, 4.0)
	for c in [Vector2(12, 12), Vector2(size.x - 12, 12), Vector2(12, size.y - 12), Vector2(size.x - 12, size.y - 12)]:
		draw_circle(c, 5, Color(0.5, 0.5, 0.45))
		draw_line(c - Vector2(3, 3), c + Vector2(3, 3), Color(0.2, 0.2, 0.2), 1.5)


func tick(_dt: float) -> void:
	screen.queue_redraw()


func _build() -> void:
	pass


func _draw_screen() -> void:
	pass


func _screen_input(_ev: InputEvent) -> void:
	pass


func text(pos: Vector2, s: String, color := UI.GREEN, fs := 14) -> void:
	screen.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func report_buttons(report_cb: Callable) -> void:
	UI.label(panel, "REPORT", UI.AMBER)
	var g := GridContainer.new()
	g.columns = 2
	panel.add_child(g)
	for k in Target.KIND_NAMES.size():
		var b := UI.button(g, Target.KIND_NAMES[k], report_cb.bind(k))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func draw_tracks(center: Vector2, rad: float, range_m: float) -> void:
	draw_tracks_on(screen, center, rad, range_m)


func draw_tracks_on(c: Control, center: Vector2, rad: float, range_m: float) -> void:
	RadarView.draw_tracks(c, sim, center, rad, range_m)


func ppi_background(center: Vector2, rad: float, range_m: float) -> void:
	screen.draw_rect(Rect2(Vector2.ZERO, screen.size), Color(0.02, 0.05, 0.03))
	screen.draw_circle(center, rad, Color(0.03, 0.09, 0.05))
	for i in range(1, 5):
		screen.draw_arc(center, rad * i / 4.0, 0, TAU, 64, Color(0.1, 0.4, 0.2), 1.0)
		text(center + Vector2(4, -rad * i / 4.0 - 2), "%d" % roundi(range_m * i / 4000.0), UI.DIM, 12)
	for a in range(0, 360, 10):
		var dir := Vector2(sin(deg_to_rad(a)), -cos(deg_to_rad(a)))
		var len := 10.0 if a % 30 == 0 else 5.0
		screen.draw_line(center + dir * rad, center + dir * (rad + len), Color(0.2, 0.6, 0.3), 1.0)
		if a % 30 == 0:
			screen.draw_line(center, center + dir * rad, Color(0.08, 0.25, 0.14), 1.0)
	text(center + Vector2(-5, -rad - 14), "N", UI.AMBER)
