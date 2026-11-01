extends Control
## Briefing screen (equipment / mission / environment / seed / site pick) and the play screen shell.

const STATIONS := {
	"radar": preload("res://scripts/ui/station_radar.gd"),
	"eo": preload("res://scripts/ui/station_eo.gd"),
	"fire": preload("res://scripts/ui/station_fire.gd"),
}
const STATION_TITLES := {"radar": "RADAR OPERATOR", "eo": "EO OPERATOR", "fire": "FIRE CONTROL"}
const TEMPS := {"Cold -5C": -5.0, "Mild 15C": 15.0, "Hot 35C": 35.0}
const HOURS := {"Noon 12:00": 12.0, "Dawn 06:30": 6.5, "Dusk 18:30": 18.5, "Night 00:00": 0.0}

var equipment: Array = Equipment.catalog()
var mission_defs: Array = Mission.catalog()
var world := WorldGen.new()
var site := Vector2(-1, -1)
var map_tex: ImageTexture
var sim: Sim
var stations: Array[Station] = []
var speed := 1.0
var log_lines: Array[String] = []

var title_ui: Control
var options_ui: Control
var setup_ui: Control
var brief_lbl: Label
var _map_ready := false
var map: Control
var eq_opt: OptionButton
var mission_opt: OptionButton
var time_opt: OptionButton
var terrain_opt: OptionButton
var weather_opt: OptionButton
var temp_opt: OptionButton
var seed_edit: LineEdit
var desc_lbl: Label
var hover_lbl: Label
var deploy_btn: Button
var play_ui: Control
var hud_lbl: Label
var obj_lbl: Label
var log_lbl: Label
var result_box: PanelContainer
var result_lbl: Label
var sub_box: PanelContainer
var sub_who: Label
var sub_text: Label
var sub_ko: Label
var radio_voice: RadioVoice
var radio_q: Array = []
var radio_on := false
var radio_el := 0.0
var radio_len := 0
var radio_voiced := false


func _ready() -> void:
	var kfont := load("res://fonts/NotoSansKR-subset.ttf") as Font
	ThemeDB.fallback_font = kfont  # Hangul for subtitles; the web build has no system fonts
	theme = UI.theme()
	theme.default_font = kfont
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	Settings.load_all()
	Settings.apply(get_window())
	radio_voice = RadioVoice.new()
	add_child(radio_voice)
	add_child(Sfx.new())
	_build_title()
	_build_options()
	_build_setup()
	_show(title_ui)


func _show(ui: Control) -> void:
	for u in [title_ui, options_ui, setup_ui]:
		u.visible = u == ui
	if ui == setup_ui and not _map_ready:
		_map_ready = true
		_generate()


func _screen_root() -> MarginContainer:
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 12)
	add_child(mc)
	return mc


# ------------------------------------------------------------------ title / options

func _build_title() -> void:
	title_ui = _screen_root()
	for side in ["left", "right", "top", "bottom"]:
		title_ui.add_theme_constant_override("margin_" + side, 0)
	var back := TitleBackdrop.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_ui.add_child(back)
	var mc := MarginContainer.new()
	mc.mouse_filter = Control.MOUSE_FILTER_PASS
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 90 if side == "left" else 40)
	title_ui.add_child(mc)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 340
	vb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.add_theme_constant_override("separation", 10)
	mc.add_child(vb)
	var t := UI.label(vb, "LAST LINE", UI.AMBER)
	t.add_theme_font_size_override("font_size", 84)
	t.add_theme_constant_override("outline_size", 8)
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	var rule := ColorRect.new()  # amber underline
	rule.color = Color(1.0, 0.75, 0.2, 0.9)
	rule.custom_minimum_size = Vector2(340, 3)
	vb.add_child(rule)
	var st := UI.label(vb, "AIR DEFENCE OPERATOR SIMULATOR", Color(0.7, 0.9, 0.75))
	st.add_theme_font_size_override("font_size", 17)
	var gap := Control.new()
	gap.custom_minimum_size.y = 26
	vb.add_child(gap)
	for item in [["START", func(): _show(setup_ui)], ["OPTIONS", func(): _show(options_ui)]]:
		var b := UI.button(vb, item[0], item[1])
		b.custom_minimum_size = Vector2(340, 54)
		b.add_theme_font_size_override("font_size", 22)
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 14
	vb.add_child(gap2)
	UI.label(vb, "Radar  /  EO-IR  /  Fire control", UI.DIM)
	UI.label(vb, "Seeded terrain  -  weather-driven sensors", UI.DIM)


func _build_options() -> void:
	options_ui = _screen_root()
	var c := CenterContainer.new()
	options_ui.add_child(c)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 420
	vb.add_theme_constant_override("separation", 8)
	c.add_child(vb)
	UI.label(vb, "OPTIONS", UI.AMBER).add_theme_font_size_override("font_size", 28)
	UI.label(vb, "SCREEN ASPECT RATIO", UI.AMBER)
	var ao := OptionButton.new()
	for k in Settings.ASPECTS:
		ao.add_item(k)
	ao.select(Settings.aspect)
	ao.item_selected.connect(func(i: int):
		Settings.aspect = i
		Settings.apply(get_window())
		Settings.save_all())
	vb.add_child(ao)
	UI.label(vb, "DISPLAY MODE", UI.AMBER)
	var fs := UI.button(vb, "FULLSCREEN", func(on: bool):
		Settings.fullscreen = on
		Settings.apply(get_window())
		Settings.save_all(), true)
	fs.button_pressed = Settings.fullscreen
	_slider(vb, "MASTER VOLUME", Settings.master, func(v: float): Settings.master = v)
	_slider(vb, "RADIO VOICE VOLUME", Settings.voice, func(v: float): Settings.voice = v)
	_slider(vb, "EFFECTS VOLUME", Settings.sfx, func(v: float): Settings.sfx = v)
	UI.button(vb, "TEST RADIO VOICE", func(): radio_voice.speak(Radio.TEST[0], Radio.TEST[1], {}))
	UI.button(vb, "BACK", func(): _show(title_ui))


func _slider(parent: Node, caption: String, val: float, cb: Callable) -> void:
	var l := UI.label(parent, "%s  %d%%" % [caption, roundi(val * 100.0)], UI.AMBER)
	var h := HSlider.new()
	h.max_value = 1.0
	h.step = 0.05
	h.value = val
	h.custom_minimum_size.y = 24
	h.value_changed.connect(func(v: float):
		cb.call(v)
		Sfx.play("tick")
		l.text = "%s  %d%%" % [caption, roundi(v * 100.0)]
		Settings.apply(get_window())
		Settings.save_all())
	parent.add_child(h)


# ------------------------------------------------------------------ briefing

func _opt(parent: Node, caption: String, items: Array, cb: Callable) -> OptionButton:
	UI.label(parent, caption, UI.AMBER)
	var o := OptionButton.new()
	for i in items:
		o.add_item(i)
	o.item_selected.connect(cb)
	o.item_selected.connect(func(_i): Sfx.play("click"))
	parent.add_child(o)
	return o


func _build_setup() -> void:
	setup_ui = _screen_root()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	setup_ui.add_child(hb)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 340
	col.add_theme_constant_override("separation", 6)
	hb.add_child(col)
	UI.label(col, "MISSION BRIEFING", UI.AMBER).add_theme_font_size_override("font_size", 24)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	scroll.add_child(left)
	eq_opt = _opt(left, "EQUIPMENT", equipment.map(func(e: Equipment): return e.title), func(_i): _on_equipment())
	desc_lbl = UI.label(left, "", UI.DIM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_opt = _opt(left, "MISSION", mission_defs.map(func(m: Mission): return m.title), func(_i): _on_mission())
	brief_lbl = UI.label(left, "", UI.DIM)
	brief_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	time_opt = _opt(left, "TIME OF DAY", HOURS.keys(), func(_i): pass)
	terrain_opt = _opt(left, "TERRAIN", WorldGen.PRESETS.keys(), func(_i): _generate())
	weather_opt = _opt(left, "WEATHER (radar clutter / attenuation)", Sim.WEATHERS.keys(), func(_i): pass)
	temp_opt = _opt(left, "TEMPERATURE (receiver noise / IR)", TEMPS.keys(), func(_i): pass)
	temp_opt.select(1)
	UI.label(left, "SEED (number or any text)", UI.AMBER)
	var sb := HBoxContainer.new()
	left.add_child(sb)
	seed_edit = LineEdit.new()
	seed_edit.text = "1337"
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_edit.text_submitted.connect(func(_s): _generate())
	sb.add_child(seed_edit)
	UI.button(sb, "RND", func():
		seed_edit.text = str(randi() % 1000000)
		_generate())
	UI.button(left, "GENERATE MAP", func(): _generate())
	hover_lbl = UI.label(col, "Click the map to choose the site.", UI.GREEN)
	deploy_btn = UI.button(col, "DEPLOY", func(): _deploy())
	deploy_btn.disabled = true
	UI.button(col, "BACK", func(): _show(title_ui))
	map = Control.new()
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.draw.connect(_draw_map)
	map.gui_input.connect(_map_input)
	hb.add_child(map)
	_on_equipment()
	_on_mission()


func _on_equipment() -> void:
	var eq: Equipment = equipment[eq_opt.selected]
	desc_lbl.text = eq.desc
	for i in mission_defs.size():
		var m: Mission = mission_defs[i]
		mission_opt.set_item_disabled(i, m.needs_weapons and eq.missiles == 0)
	if mission_opt.is_item_disabled(mission_opt.selected):
		for i in mission_defs.size():
			if not mission_opt.is_item_disabled(i):
				mission_opt.select(i)
				break
	_on_mission()


func _on_mission() -> void:
	var m: Mission = mission_defs[mission_opt.selected]
	brief_lbl.text = m.brief


func _seed() -> int:
	var s := seed_edit.text.strip_edges()
	return int(s) if s.is_valid_int() else s.hash()


func _generate() -> void:
	world.generate(_seed(), WorldGen.PRESETS.keys()[terrain_opt.selected])
	map_tex = ImageTexture.create_from_image(world.topo_image())
	site = Vector2(-1, -1)
	deploy_btn.disabled = true
	map.queue_redraw()


func _map_rect() -> Rect2:
	var s := minf(map.size.x, map.size.y) - 16.0
	return Rect2((map.size - Vector2(s, s)) * 0.5, Vector2(s, s))


func _draw_map() -> void:
	var r := _map_rect()
	var f := ThemeDB.fallback_font
	map.draw_texture_rect(map_tex, r, false)
	map.draw_rect(r, UI.GREEN, false, 2.0)
	var km := int(WorldGen.SIZE / 1000.0)
	for i in range(0, km + 1, 10):
		var u := float(i) / km
		map.draw_line(r.position + Vector2(u * r.size.x, 0), r.position + Vector2(u * r.size.x, r.size.y), Color(0, 0, 0, 0.25))
		map.draw_line(r.position + Vector2(0, u * r.size.y), r.position + Vector2(r.size.x, u * r.size.y), Color(0, 0, 0, 0.25))
		map.draw_string(f, r.position + Vector2(u * r.size.x + 2, r.size.y + 14), "%d" % i, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.DIM)
		map.draw_string(f, r.position + Vector2(-22, u * r.size.y + 4), "%d" % i, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.DIM)
	map.draw_string(f, r.position + Vector2(6, 16), "SEED %d  |  contour 100 m, index 500 m  |  grid 10 km  |  max elev %d m" % [world.seed_value, world.max_elev], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	if site.x >= 0.0:
		var q := r.position + site / WorldGen.SIZE * r.size
		map.draw_arc(q, 9, 0, TAU, 24, Color.RED, 2.0)
		map.draw_line(q - Vector2(14, 0), q + Vector2(14, 0), Color.RED, 2.0)
		map.draw_line(q - Vector2(0, 14), q + Vector2(0, 14), Color.RED, 2.0)


func _map_input(ev: InputEvent) -> void:
	if not ev is InputEventMouse:
		return
	var pos := (ev as InputEventMouse).position
	var r := _map_rect()
	var u := (pos - r.position) / r.size
	if u.x < 0.0 or u.y < 0.0 or u.x > 1.0 or u.y > 1.0:
		return
	var p := u * WorldGen.SIZE
	hover_lbl.text = "%.1f, %.1f km  ELEV %d m  %s" % [p.x / 1000.0, p.y / 1000.0, roundi(world.elev_at(p)), WorldGen.BIOME_NAMES[world.biome_at(p)]]
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if world.biome_at(p) == WorldGen.Biome.SEA:
			hover_lbl.text = "Cannot deploy at sea."
			Sfx.play("buzz")
			return
		Sfx.play("beep")
		site = p
		deploy_btn.disabled = false
		map.queue_redraw()


# ------------------------------------------------------------------ play

func _deploy() -> void:
	var eq: Equipment = equipment[eq_opt.selected]
	var hour: float = HOURS.values()[time_opt.selected]
	sim = Sim.new()
	sim.setup(world, eq, Mission.catalog()[mission_opt.selected], site, hour, world.seed_value,
		Sim.WEATHERS.keys()[weather_opt.selected], TEMPS.values()[temp_opt.selected])
	sim.log_added.connect(_on_log)
	sim.radio_msg.connect(_on_radio)
	sim.sfx.connect(func(n: String): Sfx.play(n))
	radio_q.clear()
	radio_on = false
	log_lines.clear()
	speed = 1.0
	for u in [title_ui, options_ui, setup_ui]:
		u.visible = false

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vb)
	play_ui = vb
	var top := HBoxContainer.new()
	vb.add_child(top)
	var grp := ButtonGroup.new()
	for i in eq.stations.size():
		var id: String = eq.stations[i]
		var st: Station = STATIONS[id].new()
		st.size_flags_vertical = Control.SIZE_EXPAND_FILL
		st.setup(sim)
		st.visible = i == 0
		stations.append(st)
		var tb := UI.button(top, STATION_TITLES[id], func(on: bool): st.visible = on, true)
		tb.button_group = grp
		tb.button_pressed = i == 0
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	hud_lbl = UI.label(top, "", UI.GREEN)
	for s in [0.0, 1.0, 2.0, 4.0]:
		UI.button(top, "||" if s == 0.0 else "x%d" % s, func(): speed = s)
	UI.button(top, "ABORT", func(): _end_play())
	obj_lbl = UI.label(vb, "", UI.AMBER)
	for st in stations:
		vb.add_child(st)
	log_lbl = UI.label(vb, "", UI.DIM)
	log_lbl.custom_minimum_size.y = 90

	result_box = PanelContainer.new()
	result_box.set_anchors_preset(Control.PRESET_CENTER)
	result_box.visible = false
	var rv := VBoxContainer.new()
	result_box.add_child(rv)
	result_lbl = UI.label(rv, "", UI.AMBER)
	UI.button(rv, "RETURN TO BRIEFING", func(): _end_play())
	add_child(result_box)
	_build_subtitle()


# ------------------------------------------------------------------ radio subtitles + voice

func _build_subtitle() -> void:
	sub_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sub_box.add_theme_stylebox_override("panel", sb)
	sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_box.anchor_left = 0.03
	sub_box.anchor_right = 0.74
	sub_box.anchor_top = 1.0
	sub_box.anchor_bottom = 1.0
	sub_box.offset_top = -210
	sub_box.offset_bottom = -92
	sub_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sub_box.visible = false
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_box.add_child(vb)
	sub_who = UI.label(vb, "", UI.AMBER)
	sub_text = UI.label(vb, "", Color.WHITE)
	sub_text.add_theme_font_size_override("font_size", 20)
	sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_text.custom_minimum_size.x = 300
	sub_ko = UI.label(vb, "", UI.DIM)
	sub_ko.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(sub_box)


func _on_radio(msg: Dictionary) -> void:
	radio_q.append(msg)
	if radio_q.size() > 6:
		radio_q.pop_front()


func _update_radio(delta: float) -> void:
	if radio_on:
		radio_el += delta
		var done: bool
		if radio_voiced:  # audio decides; the cap only guards against a stuck player
			done = (radio_el > 0.4 and not radio_voice.busy) or radio_el > 3.0 + radio_len * 0.15
		else:
			done = radio_el > 1.5 + radio_len * 0.06
		if not done:
			return
		radio_on = false
		sub_box.visible = false
	if radio_q.is_empty():
		return
	var m: Dictionary = radio_q.pop_front()
	sub_who.text = "[%s]" % m.who
	sub_text.text = m.en
	sub_ko.text = m.ko
	sub_box.visible = true
	radio_len = String(m.en).length()
	radio_el = 0.0
	radio_on = true
	radio_voiced = radio_voice.speak(m.voice, m.tpl, m.vars)


func _on_log(s: String) -> void:
	log_lines.append(s)
	if log_lines.size() > 5:
		log_lines.pop_front()
	if log_lbl:
		log_lbl.text = "\n".join(log_lines)


func _end_play() -> void:
	radio_voice.stop()
	Sfx.loop("motor", false)
	sub_box.queue_free()
	play_ui.queue_free()
	result_box.queue_free()
	stations.clear()
	sim = null
	_show(setup_ui)
	_on_mission()


func _process(delta: float) -> void:
	if sim == null:
		return
	var m := sim.mission
	if m.status == "active":
		var rem := minf(delta, 0.1) * speed
		while rem > 0.0001:
			var s := minf(rem, 0.05)
			sim.step(s)
			rem -= s
	elif not result_box.visible:
		result_lbl.text = "MISSION %s\n%s\n%s\nSCORE %d" % [m.status.to_upper(), m.why, sim.engagement_summary(), sim.score]
		result_box.visible = true
	for st in stations:
		if st.visible:
			st.tick(delta)
	_update_radio(delta)
	hud_lbl.text = "%s  SCORE %d  SITE %d%%  MSL %d   " % [sim.clock(), sim.score, sim.site_hp, sim.missiles_left]
	obj_lbl.text = "%s: %s" % [m.title, m.objective_text(sim)]
