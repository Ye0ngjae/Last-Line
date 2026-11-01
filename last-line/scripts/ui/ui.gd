class_name UI
extends RefCounted
## Tiny widget helpers + the one shared retro theme.

const GREEN := Color(0.35, 1.0, 0.45)
const AMBER := Color(1.0, 0.75, 0.2)
const DIM := Color(0.45, 0.6, 0.5)


static func label(parent: Node, text := "", color := GREEN) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


## Toggle buttons call cb(bool); plain buttons call cb(). Plays a switch/click sound (override with `sfx`).
static func button(parent: Node, text: String, cb: Callable, toggle := false, sfx := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 30
	b.toggle_mode = toggle
	if toggle:
		b.toggled.connect(cb)
		b.toggled.connect(func(on: bool): Sfx.play(sfx if sfx != "" else ("on" if on else "off")))
	else:
		b.pressed.connect(cb)
		b.pressed.connect(func(): Sfx.play(sfx if sfx != "" else "click"))
	parent.add_child(b)
	return b


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(2)
	s.border_color = border
	s.set_corner_radius_all(3)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 15
	for cls in ["Button", "OptionButton"]:
		th.set_stylebox("normal", cls, _box(Color(0.09, 0.12, 0.09), Color(0.3, 0.55, 0.35)))
		th.set_stylebox("hover", cls, _box(Color(0.13, 0.2, 0.13), GREEN))
		th.set_stylebox("pressed", cls, _box(Color(0.2, 0.45, 0.25), GREEN))
		th.set_stylebox("hover_pressed", cls, _box(Color(0.2, 0.45, 0.25), GREEN))
		th.set_stylebox("disabled", cls, _box(Color(0.07, 0.07, 0.07), Color(0.2, 0.2, 0.2)))
		th.set_stylebox("focus", cls, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			th.set_color(c, cls, GREEN)
		th.set_color("font_disabled_color", cls, Color(0.35, 0.35, 0.35))
	th.set_stylebox("normal", "LineEdit", _box(Color(0.05, 0.07, 0.05), Color(0.3, 0.55, 0.35)))
	th.set_color("font_color", "LineEdit", GREEN)
	th.set_color("font_color", "Label", GREEN)
	return th
