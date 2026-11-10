class_name ArmoryDots
extends Control
## The Armory's level track (UI concept B v2 `armory.png`): a dot for the starting kit and each level along one line, the
## line accent up to the player's level and on into the next by the share of its XP earned; the reached dots filled accent,
## the next one large and white, the rest rings. KIT and the level numbers sit under them. A click on a dot sends
## `level_picked`, so the cards under it can show that level, and marks that dot picked: a white ring round it and its
## label in accent under an accent bar (owner, 2026-11-03), until another dot is clicked. It takes keyboard and controller
## focus too (BP6): left and right (ui_left, ui_right) pick the dot beside the picked one (the next level's first), and
## the theme's focus ring shows round the track while it has focus.
## It shows ten levels at a time (owner, 2026-11-10; LV15): the starting kit and levels 1 to 10, then 11 to 20 and so
## on, each page's line starting from the page before's last level. `show_page` turns the page (the summary's arrows);
## the keys turn it on past either end of a page, and the track opens on the page with the next level.

## A dot was clicked: its level (0 for the starting kit).
signal level_picked(number: int)
## The page shown changed (the summary's arrows follow).
signal page_changed(page: int)

## Levels on a page: the first page has the starting kit too.
const PER_PAGE := 10
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
const FACE := GameTheme.BG
## The picked dot: the ring round it (its gap outside the dot and its width), and the bar under its label (width, height,
## gap under the label).
const PICKED_GAP := 4.0
const PICKED_RING := 2.0
const PICKED_BAR := Vector2(22.0, 3.0)
const PICKED_BAR_GAP := 5.0

var _count: int = 1
var _level: int = 0
var _fraction: float = 0.0
var _font: Font = null
var _words: PackedStringArray = []
## The dot clicked last (-1: none yet).
var _picked: int = -1
var _focus_ring: StyleBoxFlat = GameTheme.focus_box()
## The page shown (0: the starting kit and levels 1 to PER_PAGE).
var _page: int = 0


## `count` dots (the starting kit and each level), the player at `level`, `fraction` of the way to the next.
func _init(count: int = 1, level: int = 0, fraction_in: float = 0.0) -> void:
	name = "LevelDots"
	_count = maxi(count, 1)
	_level = level
	_fraction = clampf(fraction_in, 0.0, 1.0)
	custom_minimum_size = Vector2(0.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	accessibility_name = tr("ARMORY_LEVELS_NAME")
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_font = GameTheme.heading_font(700, GameTheme.SPACING_TAB, LABEL_SIZE)
	for i in _count:
		_words.append(tr("ARMORY_DOT_KIT") if i == 0 else str(i))
	_page = page_of(mini(_level + 1, _count - 1))


## The share of the next level's XP earned (0 to 1).
func fraction() -> float:
	return _fraction


func set_fraction(f: float) -> void:
	_fraction = clampf(f, 0.0, 1.0)
	queue_redraw()


## How many pages of levels there are (1 up to PER_PAGE levels).
func page_count() -> int:
	return maxi(1, ceili(float(_count - 1) / float(PER_PAGE)))


## The page shown.
func page() -> int:
	return _page


## The page dot `i` is on: the starting kit and levels 1 to PER_PAGE on the first.
func page_of(i: int) -> int:
	return 0 if i <= 0 else floori(float(i - 1) / float(PER_PAGE))


## The first dot on the page shown (the starting kit on the first page).
func first_shown() -> int:
	return 0 if _page == 0 else _page * PER_PAGE + 1


## The last dot on the page shown.
func last_shown() -> int:
	return mini(_count - 1, (_page + 1) * PER_PAGE)


## Shows page `p` (kept inside the pages there are).
func show_page(p: int) -> void:
	var to := clampi(p, 0, page_count() - 1)
	if to == _page:
		return
	_page = to
	queue_redraw()
	page_changed.emit(_page)


## Dot `i`'s centre on the page shown (`i` may be the page before's last level, where the page's line starts). A page
## spaces its dots as a full page would, so a part page (the cap's) keeps the same steps and leaves room for more.
func dot_position(i: int) -> Vector2:
	var y := NEXT_DOT + RING
	if _count == 1:
		return Vector2(size.x * 0.5, y)
	var slots := mini(PER_PAGE, _count - 1)
	var step := (size.x - END_ROOM * 2.0) / float(slots)
	return Vector2(END_ROOM + step * (i - _page * PER_PAGE), y)


## The dot clicked last (-1: none yet).
func picked() -> int:
	return _picked


## Marks dot `i` picked (-1: none), turning to its page.
func set_picked(i: int) -> void:
	_picked = clampi(i, -1, _count - 1)
	if _picked >= 0:
		show_page(page_of(_picked))
	queue_redraw()


## The dot on the page shown nearest `x`.
func dot_at(x: float) -> int:
	var best := first_shown()
	for i in range(first_shown(), last_shown() + 1):
		if absf(dot_position(i).x - x) < absf(dot_position(best).x - x):
			best = i
	return best


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var i := dot_at(click.position.x)
		set_picked(i)
		level_picked.emit(i)
		accept_event()
		return
	var step := 0
	if event.is_action_pressed(&"ui_left", true):
		step = -1
	elif event.is_action_pressed(&"ui_right", true):
		step = 1
	if step == 0:
		return
	var from := _picked if _picked >= 0 and page_of(_picked) == _page else -1
	if from < 0:
		# nothing picked on this page: the key starts from its next level, or from the end it comes in at
		var next := mini(_level + 1, _count - 1)
		from = next - step if page_of(next) == _page else (last_shown() + 1 if step < 0 else first_shown() - 1)
	var to := from + step
	# past either end the key goes on to the focus beside the track
	if to < 0 or to >= _count:
		return
	set_picked(to)
	level_picked.emit(to)
	accept_event()


func _draw() -> void:
	if has_focus():
		draw_style_box(_focus_ring, Rect2(Vector2.ZERO, size))
	# a later page's line starts where the page before ended, at its last level (no dot there)
	var start := _page * PER_PAGE
	var first := dot_position(start)
	var last := dot_position(last_shown())
	draw_line(first, last, RING_COLOUR, LINE)
	if _level >= start:
		var reach := dot_position(mini(_level, last_shown()))
		if _level < last_shown():
			reach = reach.lerp(dot_position(_level + 1), _fraction)
		draw_line(first, reach, GameTheme.ACCENT, LINE)
	for i in range(first_shown(), last_shown() + 1):
		var c := dot_position(i)
		if i <= _level:
			draw_circle(c, DOT, GameTheme.ACCENT)
		elif i == _level + 1:
			draw_circle(c, NEXT_DOT, GameTheme.TEXT)
		else:
			draw_circle(c, DOT, FACE)
			draw_arc(c, DOT, 0.0, TAU, 24, RING_COLOUR, RING, true)
		var picked := i == _picked
		if picked:
			var r := (NEXT_DOT if i == _level + 1 else DOT) + PICKED_GAP
			draw_arc(c, r, 0.0, TAU, 32, GameTheme.TEXT, PICKED_RING, true)
		var colour := GameTheme.ACCENT if picked else GameTheme.TEXT if i <= _level + 1 else GameTheme.DIM
		var width := _font.get_string_size(_words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		var base := c.y + NEXT_DOT + LABEL_GAP + LABEL_SIZE
		draw_string(_font, Vector2(c.x - width * 0.5, base), _words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE,
				colour)
		if picked:
			draw_rect(Rect2(c.x - PICKED_BAR.x * 0.5, base + PICKED_BAR_GAP, PICKED_BAR.x, PICKED_BAR.y), GameTheme.ACCENT)
