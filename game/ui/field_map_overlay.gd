class_name FieldMapOverlay
extends Control
## Over the full-screen map's field (FM1, FM2): what never moves on it, laid out once per size, storey and round, and the
## pointer. Each end's start in the colour of the team starting there and the dead zones hatched grey, the doors, the
## flags' letters (Attack / Defend) or the overtime flag's spot (Elimination), the named areas' words with none covering
## another (bigger areas first; one with no room is left out), the compass and a scale bar; then the pointer while you
## can ping. Redrawn only when something on it moved; a frame allocates nothing.

## The pointer's ring's points, and its dark ink: this much wider than the ring, and round the dot (px).
const POINTER_ARC_POINTS := 32
const POINTER_INK := 3.0
const DOT_INK := 1.2
## A flag's ring's and badge's points, the badge's ink (px), and where the badge sits from the pole's foot (px, up and
## left of the cloth, as shares of the badge's radius).
const RING_POINTS := 40
const BADGE_POINTS := 24
const BADGE_INK := 2.0
const BADGE_AT := Vector2(-1.5, -1.9)
## The compass: its arrow's length and half width (px), and the scale bar's tick height (px) and ink (px).
const COMPASS_LENGTH := 22.0
const COMPASS_HALF := 7.0
## The gap (px) between the compass or the bar and its word.
const COMPASS_GAP := 4.0
const TICK := 6.0
const BAR_WIDTH := 2.0
const BAR_INK := 4.0
## The gap (px) between a zone's word and its box's edge, past the words' own gap (the word sits outside the box).
const ZONE_WORD_GAP := 1.0
## A dead zone's hatch: its lines' width (px).
const HATCH_WIDTH := 1.4
## Most lines a dead zone's hatch may take (each end).
const HATCH_MOST := 64

## Whether the layout holds (the square's size, the storey shown and the round's colours and mode are as it was laid
## out for); FieldMap clears it when one changes.
var laid_out: bool = false
## The storey's floor (m) whose words show.
var storey_floor: float = 0.0
## What the round shows: Attack / Defend's flags, or Elimination's overtime spot (up or not); each end's colour and
## word ("ALPHA START"); set by set_round.
var _flags_on: bool = false
var _overtime_on: bool = false
var _overtime_up: bool = false
var _end_colours := PackedColorArray([Color.WHITE, Color.WHITE])
var _end_words := PackedStringArray(["", ""])

var _cfg: MinimapConfig = null
var _marks: FieldMapMarks = null
var _font: Font = null
var _big_font: Font = null
var _zone_font: Font = null
var _badge_font: Font = null
var _dead_word: String = ""
var _scale_word: String = ""
var _north_word: String = ""
## The words' boxes once laid out (a zero box: left out), and their text's sizes and fonts' sizes.
var _word_boxes: Array[Rect2] = []
var _word_sizes := PackedVector2Array()
var _word_big := PackedByteArray()
## Laid out: the flags (px), the overtime spot (px), the starts and dead zones (px boxes), the hatch (px, pairs), the
## doors (px, pairs), the compass's foot and the scale bar's left end (px).
var _flags_px := PackedVector2Array()
var _overtime_px := Vector2.ZERO
var _starts_px: Array[Rect2] = []
var _dead_px: Array[Rect2] = []
var _hatch := PackedVector2Array()
var _doors_px := PackedVector2Array()
var _start_words: Array[Rect2] = []
var _dead_words: Array[Rect2] = []
var _compass := Vector2.ZERO
var _arrow := PackedVector2Array()
var _arrow_line := PackedVector2Array()
var _bar := Vector2.ZERO
var _bar_px: float = 0.0
## The field's box on this control (px).
var _field_px := Rect2()
var _pointer := Vector2.ZERO
var _pointing: bool = false
var _colour := Color.WHITE


func setup(cfg: MinimapConfig, marks: FieldMapMarks) -> void:
	_cfg = cfg
	_marks = marks
	name = "Overlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = GameTheme.spaced_font(800, HudStyle.SPACING_AIM, cfg.map_area_size)
	_big_font = GameTheme.spaced_font(800, HudStyle.SPACING_AIM, cfg.map_area_big_size)
	_zone_font = GameTheme.spaced_font(800, HudStyle.SPACING_AIM, cfg.map_zone_size)
	_badge_font = GameTheme.font(800)
	_dead_word = HudStyle.caps("MAP_DEAD_ZONE")
	_scale_word = (tr("MAP_SCALE") % roundi(cfg.map_scale_metres)).to_upper()
	_north_word = HudStyle.caps("MAP_NORTH")
	var n := marks.words.size()
	_word_boxes.resize(n)
	_word_sizes.resize(n)
	_word_big.resize(n)
	for i in n:
		var big := marks.words[i].total >= cfg.map_area_big
		_word_big[i] = 1 if big else 0
		var f := _big_font if big else _font
		var s := cfg.map_area_big_size if big else cfg.map_area_size
		_word_sizes[i] = f.get_string_size(marks.words[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, s)
	_flags_px.resize(marks.flags.size())
	_starts_px.resize(marks.starts.size())
	_dead_px.resize(marks.dead_zones.size())
	_start_words.resize(marks.starts.size())
	_dead_words.resize(marks.dead_zones.size())
	_doors_px.resize(marks.doors.size())


## The round's marks: Attack / Defend's flags (`flags`), or Elimination's overtime spot (`overtime`, `overtime_up` once
## its flag is up); each end's colour and its start's word. Lays out again only when one changed.
func set_round(flags: bool, overtime: bool, overtime_up: bool, end_colours: PackedColorArray,
		end_words: PackedStringArray) -> void:
	if flags == _flags_on and overtime == _overtime_on and overtime_up == _overtime_up \
			and end_colours == _end_colours and end_words == _end_words:
		return
	_flags_on = flags
	_overtime_on = overtime
	_overtime_up = overtime_up
	_end_colours = end_colours
	_end_words = end_words
	laid_out = false


## This frame: the marks' places from `view` (begun; only when not laid_out), and the pointer at `pointer` (px from
## the middle) in `colour` while `pointing`. Redrawn only when something moved.
func place(view: HudMinimap.View, pointer: Vector2, pointing: bool, colour: Color) -> void:
	var mid := size * 0.5
	var moved := not laid_out
	if not laid_out:
		laid_out = true
		_lay_out(view, mid)
	var at := mid + pointer
	if moved or at != _pointer or pointing != _pointing or colour != _colour:
		_pointer = at
		_pointing = pointing
		_colour = colour
		queue_redraw()


func _lay_out(view: HudMinimap.View, mid: Vector2) -> void:
	var world := view.field_size()
	var origin := view.centre() - world * 0.5
	_field_px = Rect2(mid + view.panel_of(origin), world * view.px_per_m())
	var blocked: Array[Rect2] = []
	for i in _marks.flags.size():
		_flags_px[i] = mid + view.panel_of(_marks.flags[i])
		if _flags_on:
			blocked.append(_badge_box(_flags_px[i]))
			blocked.append(_ring_box(_flags_px[i]))
	_overtime_px = mid + view.panel_of(_marks.overtime)
	if _overtime_on and _marks.has_overtime:
		blocked.append(_ring_box(_overtime_px))
	for i in _marks.starts.size():
		_starts_px[i] = _box_px(view, mid, _marks.starts[i]).intersection(_field_px)
		_dead_px[i] = _box_px(view, mid, _marks.dead_zones[i]).intersection(_field_px)
		for r: Rect2 in [_starts_px[i], _dead_px[i]]:
			if r.has_area():
				blocked.append(r)
	# The zones' words: starts first, each just above its box, else below, else beside it, clear of every zone, flag
	# and word placed before it; a word with no room is left out.
	var gap := _cfg.map_area_gap
	for i in _marks.starts.size():
		_start_words[i] = _zone_word(_starts_px[i], _end_words[i] if i < _end_words.size() else "", blocked, gap)
	for i in _marks.dead_zones.size():
		_dead_words[i] = _zone_word(_dead_px[i], _dead_word, blocked, gap)
	_hatch.clear()
	for r in _dead_px:
		_hatch_box(r)
	for i in _marks.doors.size():
		_doors_px[i] = mid + view.panel_of(_marks.doors[i])
	_bar_px = _cfg.map_scale_metres * view.px_per_m()
	var pad := _cfg.map_scale_pad
	_bar = Vector2(_field_px.position.x + pad, _field_px.end.y - pad)
	_compass = _bar + Vector2(COMPASS_HALF, -TICK - pad - _cfg.map_zone_size)
	var tip := _compass + Vector2(0.0, -COMPASS_LENGTH)
	_arrow = PackedVector2Array([tip, _compass + Vector2(COMPASS_HALF, 0.0), _compass + Vector2(0.0, -COMPASS_HALF),
			_compass + Vector2(-COMPASS_HALF, 0.0)])
	_arrow_line = _arrow.duplicate()
	_arrow_line.append(tip)
	blocked.append(Rect2(_bar - Vector2(0.0, COMPASS_LENGTH + TICK + pad * 2.0 + _cfg.map_zone_size),
			Vector2(maxf(_bar_px, COMPASS_HALF * 2.0) + pad * 4.0, COMPASS_LENGTH + TICK + pad * 2.0
			+ _cfg.map_zone_size)))
	var wants: Array[Rect2] = []
	for i in _marks.words.size():
		if not _shows(i):
			wants.append(Rect2())
			continue
		var p := mid + view.panel_of(_marks.words[i].at)
		wants.append(Rect2(p - _word_sizes[i] * 0.5, _word_sizes[i]))
	var placed := FieldMapMarks.lay_out(wants, blocked, _field_px, gap)
	for i in placed.size():
		_word_boxes[i] = placed[i] if wants[i].has_area() else Rect2()


func _box_px(view: HudMinimap.View, mid: Vector2, r: Rect2) -> Rect2:
	if not r.has_area():
		return Rect2()
	var a := mid + view.panel_of(r.position)
	return Rect2(a, r.size * view.px_per_m())


## Where zone `r`'s word goes (a zero box for none), added to `blocked` once placed.
func _zone_word(r: Rect2, word: String, blocked: Array[Rect2], gap: Vector2) -> Rect2:
	if not r.has_area() or word.is_empty():
		return Rect2()
	var s := _zone_font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, _cfg.map_zone_size)
	var x := r.get_center().x - s.x * 0.5
	var y := r.get_center().y - s.y * 0.5
	# Just outside the gap kept round it, so its own box never counts against it.
	var off := gap + Vector2.ONE * ZONE_WORD_GAP
	var tries: Array[Rect2] = [Rect2(Vector2(x, r.position.y - s.y - off.y), s), Rect2(Vector2(x, r.end.y + off.y), s),
			Rect2(Vector2(r.end.x + off.x, y), s), Rect2(Vector2(r.position.x - s.x - off.x, y), s)]
	var got := FieldMapMarks.first_clear(tries, blocked, _field_px, gap)
	if got.has_area():
		blocked.append(got)
	return got


func _badge_box(pole: Vector2) -> Rect2:
	var r := _cfg.map_flag_badge
	return Rect2(pole + BADGE_AT * r - Vector2(r, r), Vector2(r, r) * 2.0)


func _ring_box(at: Vector2) -> Rect2:
	var r := _cfg.map_flag_ring
	return Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0)


## The hatch's lines across box `r` (down to the right), map_dead_hatch px apart.
func _hatch_box(r: Rect2) -> void:
	if not r.has_area():
		return
	var step := maxf(_cfg.map_dead_hatch, 1.0)
	var lines := 0
	var t := step
	while t < r.size.x + r.size.y and lines < HATCH_MOST:
		# A line x + y = t across the box, from where it enters to where it leaves.
		var a := Vector2(minf(t, r.size.x), t - minf(t, r.size.x))
		var b := Vector2(t - minf(t, r.size.y), minf(t, r.size.y))
		_hatch.append(r.position + a)
		_hatch.append(r.position + b)
		t += step
		lines += 1


func _shows(i: int) -> bool:
	var w := _marks.words[i]
	var feet := storey_floor + _cfg.storey_pick
	return feet >= w.floor_from and feet < w.floor_to


## The words shown (laid out and with room), for tests and the key.
func shown_names() -> PackedStringArray:
	var out := PackedStringArray()
	for i in _word_boxes.size():
		if _word_boxes[i].has_area():
			out.append(_marks.words[i].name)
	return out


## Where word `i` was laid out (a zero box when left out), for tests.
func word_box(i: int) -> Rect2:
	return _word_boxes[i]


func _draw() -> void:
	_draw_zones()
	if not _doors_px.is_empty():
		draw_multiline(_doors_px, _cfg.ink, _cfg.map_door_width + BADGE_INK)
		draw_multiline(_doors_px, _cfg.map_door_colour, _cfg.map_door_width)
	if _flags_on:
		for i in _flags_px.size():
			_draw_flag(_flags_px[i], Flag.LETTERS[i] if i < Flag.LETTERS.size() else "")
	if _overtime_on and _marks.has_overtime:
		var a := 1.0 if _overtime_up else _cfg.map_overtime_alpha
		draw_arc(_overtime_px, _cfg.map_flag_ring, 0.0, TAU, RING_POINTS, Color(GameTheme.YELLOW, a),
				_cfg.map_flag_ring_width, true)
	_draw_words()
	_draw_compass()
	if not _pointing:
		return
	var r := _cfg.map_pointer_radius
	draw_arc(_pointer, r, 0.0, TAU, POINTER_ARC_POINTS, _cfg.ink, _cfg.map_pointer_width + POINTER_INK, true)
	draw_arc(_pointer, r, 0.0, TAU, POINTER_ARC_POINTS, _colour, _cfg.map_pointer_width, true)
	draw_circle(_pointer, _cfg.map_pointer_dot + DOT_INK, _cfg.ink)
	draw_circle(_pointer, _cfg.map_pointer_dot, Color.WHITE)


func _draw_zones() -> void:
	var s := _cfg.map_zone_size
	for i in _starts_px.size():
		var r := _starts_px[i]
		if not r.has_area():
			continue
		var c := _end_colours[i] if i < _end_colours.size() else Color.WHITE
		draw_rect(r, Color(c, _cfg.map_start_fill))
		draw_rect(r, c, false, _cfg.map_zone_ring)
		if _start_words[i].has_area():
			_draw_zone_word(_start_words[i], _end_words[i], c, s)
	if not _hatch.is_empty():
		draw_multiline(_hatch, _cfg.map_dead_colour, HATCH_WIDTH)
	for i in _dead_px.size():
		if _dead_px[i].has_area():
			draw_rect(_dead_px[i], _cfg.map_dead_colour, false, _cfg.map_zone_ring)
			if _dead_words[i].has_area():
				_draw_zone_word(_dead_words[i], _dead_word, _cfg.map_dead_colour, s)


func _draw_zone_word(box: Rect2, word: String, colour: Color, s: int) -> void:
	var at := Vector2(box.position.x, box.position.y + _zone_font.get_ascent(s))
	draw_string_outline(_zone_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, s, _cfg.map_area_outline, _cfg.ink)
	draw_string(_zone_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color(colour, 1.0))


## A flag's ring round its pole, and its letter on a yellow badge up and left of it.
func _draw_flag(at: Vector2, letter: String) -> void:
	draw_arc(at, _cfg.map_flag_ring, 0.0, TAU, RING_POINTS, _cfg.ink, _cfg.map_flag_ring_width + BADGE_INK, true)
	draw_arc(at, _cfg.map_flag_ring, 0.0, TAU, RING_POINTS, GameTheme.YELLOW, _cfg.map_flag_ring_width, true)
	var r := _cfg.map_flag_badge
	var c := at + BADGE_AT * r
	draw_circle(c, r + BADGE_INK, _cfg.ink)
	draw_circle(c, r, GameTheme.YELLOW)
	var fs := roundi(r * _cfg.map_badge_type)
	var s := _badge_font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var base := Vector2(c.x - s.x * 0.5, c.y - s.y * 0.5 + _badge_font.get_ascent(fs))
	draw_string(_badge_font, base, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GameTheme.YELLOW_INK)


func _draw_words() -> void:
	for i in _word_boxes.size():
		var box := _word_boxes[i]
		if not box.has_area():
			continue
		var big := _word_big[i] == 1
		var f := _big_font if big else _font
		var s := _cfg.map_area_big_size if big else _cfg.map_area_size
		var at := Vector2(box.position.x, box.position.y + f.get_ascent(s))
		var word := _marks.words[i].name
		draw_string_outline(f, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, s, _cfg.map_area_outline, _cfg.ink)
		draw_string(f, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, s, GameTheme.TEXT if big else GameTheme.MUTED)


## North's arrow over a bar map_scale_metres long, in the field's bottom left.
func _draw_compass() -> void:
	var s := _cfg.map_zone_size
	draw_colored_polygon(_arrow, GameTheme.TEXT)
	draw_polyline(_arrow_line, _cfg.ink, BADGE_INK * 0.5, true)
	var n := Vector2(_compass.x + COMPASS_HALF + COMPASS_GAP, _compass.y - COMPASS_LENGTH + _zone_font.get_ascent(s))
	draw_string_outline(_zone_font, n, _north_word, HORIZONTAL_ALIGNMENT_LEFT, -1, s, _cfg.map_area_outline, _cfg.ink)
	draw_string(_zone_font, n, _north_word, HORIZONTAL_ALIGNMENT_LEFT, -1, s, GameTheme.TEXT)
	var end := _bar + Vector2(_bar_px, 0.0)
	_draw_bar(end, _cfg.ink, BAR_INK + BAR_WIDTH)
	_draw_bar(end, GameTheme.TEXT, BAR_WIDTH)
	var at := end + Vector2(COMPASS_GAP * 2.0, _zone_font.get_ascent(s) * 0.5 - TICK * 0.5)
	draw_string_outline(_zone_font, at, _scale_word, HORIZONTAL_ALIGNMENT_LEFT, -1, s, _cfg.map_area_outline, _cfg.ink)
	draw_string(_zone_font, at, _scale_word, HORIZONTAL_ALIGNMENT_LEFT, -1, s, GameTheme.TEXT)


func _draw_bar(end: Vector2, colour: Color, width: float) -> void:
	draw_line(_bar, end, colour, width)
	draw_line(_bar, _bar - Vector2(0.0, TICK), colour, width)
	draw_line(end, end - Vector2(0.0, TICK), colour, width)
