class_name ArmoryDots
extends Control
## The Armory's level track (UI concept B v2 `armory.png`): a dot for the starting kit and each level along one line, the
## line teal up to the player's level and on into the next by the share of its XP earned; the reached dots filled teal,
## the next one large and white, the rest rings. KIT and the level numbers sit under them. A click on a dot sends
## `level_picked`, so the cards under it can show that level.

## A dot was clicked: its level (0 for the starting kit).
signal level_picked(number: int)

const HEIGHT := 64.0
const DOT := 9.0
const NEXT_DOT := 13.0
const RING := 2.0
const LINE := 4.0
const LABEL_SIZE := 15
const LABEL_GAP := 10.0
## The room kept at each end, so the end dots and their labels sit inside.
const END_ROOM := 16.0
const RING_COLOUR := Color(1.0, 1.0, 1.0, 0.35)
const FACE := Color(0.06, 0.07, 0.1, 1.0)

var _count: int = 1
var _level: int = 0
var _fraction: float = 0.0
var _font: Font = null
var _words: PackedStringArray = []


## `count` dots (the starting kit and each level), the player at `level`, `fraction` of the way to the next.
func _init(count: int = 1, level: int = 0, fraction_in: float = 0.0) -> void:
	name = "LevelDots"
	_count = maxi(count, 1)
	_level = level
	_fraction = clampf(fraction_in, 0.0, 1.0)
	custom_minimum_size = Vector2(0.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_font = GameTheme.heading_font(700, GameTheme.SPACING_TAB, LABEL_SIZE)
	for i in _count:
		_words.append(tr("ARMORY_DOT_KIT") if i == 0 else str(i))


## The share of the next level's XP earned (0 to 1).
func fraction() -> float:
	return _fraction


func set_fraction(f: float) -> void:
	_fraction = clampf(f, 0.0, 1.0)
	queue_redraw()


## Dot `i`'s centre.
func dot_position(i: int) -> Vector2:
	var y := NEXT_DOT + RING
	if _count == 1:
		return Vector2(size.x * 0.5, y)
	var step := (size.x - END_ROOM * 2.0) / float(_count - 1)
	return Vector2(END_ROOM + step * i, y)


## The dot nearest `x`.
func dot_at(x: float) -> int:
	var best := 0
	for i in _count:
		if absf(dot_position(i).x - x) < absf(dot_position(best).x - x):
			best = i
	return best


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		level_picked.emit(dot_at(click.position.x))
		accept_event()


func _draw() -> void:
	var first := dot_position(0)
	var last := dot_position(_count - 1)
	draw_line(first, last, RING_COLOUR, LINE)
	var reach := dot_position(mini(_level, _count - 1))
	if _level + 1 < _count:
		reach = reach.lerp(dot_position(_level + 1), _fraction)
	draw_line(first, reach, GameTheme.ACCENT, LINE)
	for i in _count:
		var c := dot_position(i)
		if i <= _level:
			draw_circle(c, DOT, GameTheme.ACCENT)
		elif i == _level + 1:
			draw_circle(c, NEXT_DOT, GameTheme.TEXT)
		else:
			draw_circle(c, DOT, FACE)
			draw_arc(c, DOT, 0.0, TAU, 24, RING_COLOUR, RING, true)
		var colour := GameTheme.TEXT if i <= _level + 1 else GameTheme.DIM
		var width := _font.get_string_size(_words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		draw_string(_font, Vector2(c.x - width * 0.5, c.y + NEXT_DOT + LABEL_GAP + LABEL_SIZE), _words[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, colour)
