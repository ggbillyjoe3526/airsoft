class_name HudScore
extends Control
## The score bar at the top (the concept's `.score`): each team's pip block (one slanted pip per win needed, filled up
## to its wins), the team's colour block with its score, and the clock panel with the round under it. In Attack / Defend
## an ATK tag (yellow) and a DEF tag (dark) sit on the two blocks, and the clock reads "OT" and the overtime left once
## time has run out while the attackers work the rope. With gauge patterns on (set_patterned), Beta's filled pips and
## score block are striped (HudStyle.STRIPED_TEAM; GaugePattern, built once at setup) and the block's number gets a dark
## edge. Your team sits on the left (setup's `first`), the other on the right, each in its own colour, through half time
## too (owner, 2026-10-30). Everything redraws or retypes only when a value changes; nothing is allocated per frame.

var _teams: TeamConfig = null
var _count: int = 0
var _side_width: float = 0.0
var _clock_x: float = 0.0
## The team on the left, and each team's colour block's x (by team).
var _first: int = 0
var _block_x: Array[float] = [0.0, 0.0]
## Both teams' pips, team 0 first, each laid out on its own end: the filled shape and the closed outline.
var _shapes: Array[PackedVector2Array] = []
var _outlines: Array[PackedVector2Array] = []
var _filled: Vector2i = Vector2i.ZERO
var _score: Vector2i = Vector2i(-1, -1)
var _clock: int = -1
var _round: int = -1
var _score_labels: Array[Label] = []
var _clock_label: Label = null
var _round_label: Label = null
var _ot_label: Label = null
## The team attacking (-1: no tags) and whether the clock shows overtime.
var _attackers: int = -2
var _overtime: bool = false
var _tags: Array[Label] = []
var _patterned: bool = false
## The striped team's block and pips (one per pip, in order), built once at setup.
var _block_stripes := GaugePattern.new()
var _pip_stripes: Array[GaugePattern] = []


## `first` is the team drawn on the left (yours); every other call here still names teams, never ends.
func setup(teams: TeamConfig, wins_needed: int, first: int = 0) -> void:
	_teams = teams
	_first = clampi(first, 0, 1)
	name = "HudScore"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count = maxi(1, wins_needed)
	_side_width = HudStyle.side_width(_count)
	var block := HudStyle.BLOCK_WIDTH
	var height := HudStyle.SCORE_HEIGHT
	_clock_x = _side_width + block
	custom_minimum_size = Vector2(_side_width * 2.0 + block * 2.0 + HudStyle.CLOCK_WIDTH, height)
	# by end: left, right
	var end_block_x: Array[float] = [_side_width, _clock_x + HudStyle.CLOCK_WIDTH]
	var end_pips_x: Array[float] = [0.0, end_block_x[1] + block]
	for side in 2:
		var end := _end_of(side)
		_block_x[side] = end_block_x[end]
		for i in _count:
			_add_pip(end_pips_x[end] + HudStyle.SIDE_PAD + i * (HudStyle.PIP_SIZE.x + HudStyle.PIP_GAP))
		var l := HudStyle.label(self, HudStyle.SCORE_SIZE, 800, HudStyle.ink_on(teams.colours[side]),
				HORIZONTAL_ALIGNMENT_CENTER)
		l.position = Vector2(_block_x[side], 0.0)
		l.size = Vector2(block, height)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_score_labels.append(l)
		if side == HudStyle.STRIPED_TEAM:
			_block_stripes.set_rect(Rect2(_block_x[side], 0.0, block, height))
			for i in _count:
				var stripes := GaugePattern.new()
				stripes.set_shape(_shapes[side * _count + i])
				_pip_stripes.append(stripes)
	var clock_row := HBoxContainer.new()
	clock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_row.add_theme_constant_override("separation", roundi(HudStyle.OT_GAP))
	clock_row.position = Vector2(_clock_x, 4.0)
	clock_row.size = Vector2(HudStyle.CLOCK_WIDTH, 46.0)
	add_child(clock_row)
	_ot_label = HudStyle.label(clock_row, HudStyle.OT_SIZE, 800, GameTheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_ot_label.text = HudStyle.caps("HUD_OT")
	_ot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ot_label.size_flags_vertical = Control.SIZE_FILL
	_ot_label.visible = false
	_clock_label = HudStyle.label(clock_row, HudStyle.CLOCK_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_label.size_flags_vertical = Control.SIZE_FILL
	for side in 2:
		var tag := HudStyle.label(self, HudStyle.TAG_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER,
				HudStyle.SPACING_ROUND)
		tag.position = Vector2(_block_x[side], -HudStyle.TAG_HEIGHT)
		tag.size = Vector2(block, HudStyle.TAG_HEIGHT)
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.visible = false
		_tags.append(tag)
	_round_label = HudStyle.label(self, HudStyle.ROUND_SIZE, 700, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER,
			HudStyle.SPACING_ROUND)
	_round_label.position = Vector2(_clock_x, 50.0)
	_round_label.size = Vector2(HudStyle.CLOCK_WIDTH, 18.0)
	_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## Gauge patterns on or off: the striped team's block and pips.
func set_patterned(on: bool) -> void:
	if on == _patterned:
		return
	_patterned = on
	HudStyle.edge_number(_score_labels[HudStyle.STRIPED_TEAM], on)
	queue_redraw()


## Whether `side`'s block and filled pips are drawn striped.
func striped(side: int) -> bool:
	return _patterned and side == HudStyle.STRIPED_TEAM


## How many pips there are on each side.
func pip_count() -> int:
	return _count


## How many of `side`'s pips are filled.
func pips_filled(side: int) -> int:
	return _filled.x if side == 0 else _filled.y


## The team drawn on the left.
func first_team() -> int:
	return _first


## Which end `side` (a team) is drawn at: 0 left, 1 right.
func _end_of(side: int) -> int:
	return side ^ _first


## The x of `side`'s colour block: for tests.
func block_x(side: int) -> float:
	return _block_x[side]


## The number `side`'s block shows.
func score_text(side: int) -> String:
	return _score_labels[side].text


func set_score(alpha: int, beta: int) -> void:
	var score := Vector2i(alpha, beta)
	if score == _score:
		return
	_score = score
	_filled = Vector2i(HudStyle.pips_filled(alpha, _count), HudStyle.pips_filled(beta, _count))
	_score_labels[0].text = str(alpha)
	_score_labels[1].text = str(beta)
	queue_redraw()


## The clock at `seconds`; with `overtime`, the overtime left, after "OT".
func set_clock(seconds: int, overtime: bool = false) -> void:
	if seconds == _clock and overtime == _overtime:
		return
	_clock = seconds
	_overtime = overtime
	_ot_label.visible = overtime
	_clock_label.text = HudStyle.clock_text(seconds)


## Attack / Defend's tags: ATK on `attackers`' block, DEF on the other's; none when `attackers` is -1.
func set_sides(attackers: int) -> void:
	if attackers == _attackers:
		return
	_attackers = attackers
	for side in 2:
		var tag := _tags[side]
		tag.visible = attackers >= 0
		var attacking := side == attackers
		tag.text = HudStyle.caps("HUD_ATK" if attacking else "HUD_DEF")
		tag.add_theme_color_override("font_color", GameTheme.ACCENT_INK if attacking else GameTheme.TEXT)
	queue_redraw()


## The tag on `side`'s block ("" when none shows), and whether the clock shows overtime: for tests.
func tag_text(side: int) -> String:
	return _tags[side].text if _tags[side].visible else ""


func clock_text() -> String:
	return ("%s %s" % [_ot_label.text, _clock_label.text]) if _overtime else _clock_label.text


func set_round(number: int) -> void:
	if number == _round:
		return
	_round = number
	_round_label.text = HudStyle.round_title(number)


func _draw() -> void:
	var h := HudStyle.SCORE_HEIGHT
	var block := HudStyle.BLOCK_WIDTH
	var side_back := HudStyle.backing_on(self, HudStyle.BACKING_SIDE)
	var right := _clock_x + HudStyle.CLOCK_WIDTH
	draw_rect(Rect2(0.0, 0.0, _side_width, h), side_back)
	draw_rect(Rect2(_clock_x, 0.0, HudStyle.CLOCK_WIDTH, h), HudStyle.backing_on(self, HudStyle.BACKING_CLOCK))
	for side in 2:
		draw_rect(Rect2(_block_x[side], 0.0, block, h), _teams.colours[side])
	if _patterned:
		_block_stripes.draw(self)
	draw_rect(Rect2(right + block, 0.0, _side_width, h), side_back)
	if _attackers >= 0:
		for side in 2:
			var tag := _tags[side]
			var fill := GameTheme.ACCENT if side == _attackers else HudStyle.backing_on(self, HudStyle.BACKING_CLOCK)
			draw_rect(Rect2(tag.position, tag.size), fill)
	var empty := Color(GameTheme.TEXT, HudStyle.PIP_EMPTY_ALPHA)
	for side in 2:
		var filled := pips_filled(side)
		for i in _count:
			var k := side * _count + i
			if i < filled:
				draw_colored_polygon(_shapes[k], _teams.colours[side])
				if striped(side):
					_pip_stripes[i].draw(self)
			else:
				draw_polyline(_outlines[k], empty, HudStyle.PIP_BORDER)


## One pip at `x` (HudStyle.pip_shape), centred in the bar's height: the filled shape and the closed outline.
func _add_pip(x: float) -> void:
	var pts := HudStyle.pip_shape(Vector2(x, (HudStyle.SCORE_HEIGHT - HudStyle.PIP_SIZE.y) * 0.5))
	_shapes.append(pts)
	var line := pts.duplicate()
	line.append(pts[0])
	_outlines.append(line)
