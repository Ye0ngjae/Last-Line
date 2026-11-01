class_name Settings
extends RefCounted
## Player options, persisted to user:// (IndexedDB on web).

const PATH := "user://settings.cfg"
const BASE := Vector2i(1280, 720)
## Zero size = fill the whole window; otherwise letterboxed to that logical size.
const ASPECTS := {"Auto (fill window)": Vector2i.ZERO, "16:9": Vector2i(1280, 720), "16:10": Vector2i(1152, 720),
	"4:3": Vector2i(960, 720), "21:9": Vector2i(1680, 720)}

static var aspect := 0
static var fullscreen := false
static var master := 0.8
static var voice := 0.8
static var sfx := 0.8


static func load_all() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	aspect = clampi(int(c.get_value("video", "aspect", 0)), 0, ASPECTS.size() - 1)
	fullscreen = bool(c.get_value("video", "fullscreen", false))
	master = clampf(float(c.get_value("audio", "master", 0.8)), 0.0, 1.0)
	voice = clampf(float(c.get_value("audio", "voice", 0.8)), 0.0, 1.0)
	sfx = clampf(float(c.get_value("audio", "sfx", 0.8)), 0.0, 1.0)


static func save_all() -> void:
	var c := ConfigFile.new()
	c.set_value("video", "aspect", aspect)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("audio", "master", master)
	c.set_value("audio", "voice", voice)
	c.set_value("audio", "sfx", sfx)
	c.save(PATH)


static func apply(win: Window) -> void:
	win.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	var sz: Vector2i = ASPECTS.values()[aspect]
	if sz == Vector2i.ZERO:
		win.content_scale_size = BASE
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	else:
		win.content_scale_size = sz
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	apply_audio()


static func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
	var r := AudioServer.get_bus_index(RadioVoice.BUS)
	if r >= 0:
		AudioServer.set_bus_volume_db(r, linear_to_db(maxf(voice, 0.0001)))
	var e := AudioServer.get_bus_index(Sfx.BUS)
	if e >= 0:
		AudioServer.set_bus_volume_db(e, linear_to_db(maxf(sfx, 0.0001)))
