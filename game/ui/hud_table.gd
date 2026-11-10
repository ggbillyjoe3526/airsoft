class_name HudTable
extends Control
## A players' table drawn as one node (concepts `round-result.png`, `scoreboard.png`, `summary.png`): an optional title
## line (or a heading: a big name, a muted line after it and a note on the right), then each team's block (its score
## in a team-coloured square, its name, a note on the right) over a header row and one row per player. The first column is the player: their name ("You" for you), the teammate chevron, and an OUT
## chip with a raised hand once they are out this round (the row dimmed). Your row is tinted with a yellow bar. Laid
## out once each time it is filled (add_* calls between begin and finish); _draw allocates nothing. One column can be
## shaded from its header down (the scoreboard's "This round").

const PAD := Vector2(16.0, 14.0)
const TITLE_SIZE := 14
const TITLE_GAP := 10.0
const HEADING_SIZE := 26
const HEADING_SUB_SIZE := 14
const HEADING_GAP := 18.0
const HEADING_BELOW := 12.0
const BAND := Color(1.0, 1.0, 1.0, 0.035)
const TEAM_HEIGHT := 32.0
const TEAM_BADGE := Vector2(38.0, 32.0)
const TEAM_SCORE_SIZE := 22
const TEAM_NAME_SIZE := 18
const TEAM_NOTE_SIZE := 13
const TEAM_GAP := 14.0
const HEAD_HEIGHT := 20.0
const HEAD_SIZE := 12
const ROW_HEIGHT := 30.0
const ROW_SIZE := 16
const CELL_PAD := 12.0
const SECTION_GAP := 10.0
const YOU_BAR := 4.0
const YOU_TINT := 0.10
const RULE_ALPHA := 0.7
const CHEVRON := Vector2(14.0, 11.0)
const NAME_GAP := 10.0
const CHIP_SIZE := 12
const CHIP_GLYPH := 13.0
const CHIP_PAD := Vector2(5.0, 2.0)
const CHIP_EDGE := 1.5
const CHIP_TEXT := Color("cfcac2")
## How much lighter than its team colour a team's name is.
const NAME_LIGHTEN := 0.3

## One player's row as shown.
class Row:
	var name: String = ""
	var you: bool = false
	var mate: bool = false
	var out: bool = false
	var cells := PackedStringArray()
	## A colour per cell (Color.TRANSPARENT for the row's own).
	var colours: Array[Color] = []
	# Laid out: the chevron and the hand, fit once.
	var chevron := ChevronShape.new()
	var hand := HandShape.new()
	var chip := Rect2()
	var team: int = 0
	var y: float = 0.0


## One team's block.
class Team:
	var colour: Color = Color.WHITE
	var name: String = ""
	var score: String = ""
	var note: String = ""
	var y: float = 0.0
	var head_y: float = 0.0


var _columns := PackedStringArray()
var _rights := PackedFloat32Array()
var _widths := PackedFloat32Array()
var _band: int = -1
var _width: float = 0.0
var _title := ""
var _heading := ""
var _heading_sub := ""
var _heading_note := ""
var _teams: Array[Team] = []
var _rows: Array[Row] = []
var _team_pool: Array[Team] = []
var _row_pool: Array[Row] = []
var _mate_colour := Color.WHITE
var _title_font: Font = null
var _head_font: Font = null
var _row_font: Font = null
var _you_font: Font = null
var _team_font: Font = null
var _heading_font: Font = null
var _sub_font: Font = null
var _chip_font: Font = null
var _chip_word := ""
var _player_word := ""


## The player's column `player_width` (px) wide, then the columns after it (their header words) and each one's width
## (px), right-aligned; column `band` (-1: none) shaded.
func setup(player_width: float, columns: PackedStringArray, widths: PackedFloat32Array, mate_colour: Color,
		band: int = -1) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_columns = columns
	_widths = widths
	_band = band
	_mate_colour = mate_colour
	_width = PAD.x * 2.0 + player_width
	for w in widths:
		_width += w
	_rights.resize(widths.size())
	var right := _width - PAD.x
	for i in range(widths.size() - 1, -1, -1):
		_rights[i] = right
		right -= widths[i]
	_title_font = GameTheme.spaced_font(800, HudStyle.SPACING_ROUND, TITLE_SIZE)
	_head_font = GameTheme.spaced_font(800, HudStyle.SPACING_ROUND, HEAD_SIZE)
	_row_font = GameTheme.font(700)
	_you_font = GameTheme.font(800)
	_team_font = GameTheme.spaced_font(800, HudStyle.SPACING_ROUND, TEAM_NAME_SIZE)
	_heading_font = GameTheme.spaced_font(800, HudStyle.SPACING_SUB, HEADING_SIZE)
	_sub_font = GameTheme.spaced_font(700, HudStyle.SPACING_ROUND, HEADING_SUB_SIZE)
	_chip_font = GameTheme.spaced_font(800, HudStyle.SPACING_AIM, CHIP_SIZE)
	_chip_word = HudStyle.caps("HUD_OUT_TAG")
	_player_word = HudStyle.caps("HUD_COL_PLAYER")
	custom_minimum_size.x = _width


## Starts filling: the title line over the table ("" for none).
func begin(title: String) -> void:
	_title = title
	_heading = ""
	_row_pool.append_array(_rows)
	_team_pool.append_array(_teams)
	_rows.clear()
	_teams.clear()


## A heading in place of the title: `big` (the map), `sub` muted after it, `note` on the right.
func heading(big: String, sub: String, note: String) -> void:
	_heading = big
	_heading_sub = sub
	_heading_note = note


func add_team(colour: Color, team_name: String, score: String, note: String) -> void:
	var t: Team = _team_pool.pop_back() if not _team_pool.is_empty() else Team.new()
	t.colour = colour
	t.name = team_name
	t.score = score
	t.note = note
	_teams.append(t)


## A player's row under the last team added, its `cells` in the columns' order (`colours` per cell, TRANSPARENT for the
## row's own).
func add_row(player_name: String, you: bool, mate: bool, out: bool, cells: PackedStringArray,
		colours: Array[Color]) -> void:
	var r: Row = _row_pool.pop_back() if not _row_pool.is_empty() else Row.new()
	r.name = player_name
	r.you = you
	r.mate = mate
	r.out = out
	r.cells = cells
	r.colours = colours
	r.team = _teams.size() - 1
	_rows.append(r)


## Lays the table out and redraws it.
func finish() -> void:
	var y := PAD.y
	if _heading != "":
		y += _heading_font.get_height(HEADING_SIZE) + HEADING_BELOW
	elif _title != "":
		y += _title_font.get_height(TITLE_SIZE) + TITLE_GAP
	var r := 0
	for t in _teams.size():
		var team := _teams[t]
		team.y = y
		y += TEAM_HEIGHT + TITLE_GAP * 0.5
		team.head_y = y
		y += HEAD_HEIGHT
		while r < _rows.size() and _rows[r].team == t:
			_lay_row(_rows[r], y)
			y += ROW_HEIGHT
			r += 1
		y += SECTION_GAP
	custom_minimum_size = Vector2(_width, y - SECTION_GAP + PAD.y)
	size = custom_minimum_size
	queue_redraw()


## The rows' names and cells as shown, one line each ("You | 1 | 9 | 1:30 | Still in"): for tests.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for row in _rows:
		var line := row.name + (" OUT" if row.out else "")
		for c in row.cells:
			line += " | " + c
		out.append(line)
	return out


func title() -> String:
	return _title


## The heading's words ("DEPOT · ELIMINATION · … · ROUND 1 · 2:15 LEFT") and each team's note: for tests.
func heading_text() -> String:
	return "%s · %s · %s" % [_heading, _heading_sub, _heading_note]


## Each team's name, top first: for tests.
func team_names() -> PackedStringArray:
	var out := PackedStringArray()
	for t in _teams:
		out.append(t.name)
	return out


func team_notes() -> PackedStringArray:
	var out := PackedStringArray()
	for t in _teams:
		out.append(t.note)
	return out


func _lay_row(row: Row, y: float) -> void:
	row.y = y
	var x := PAD.x + YOU_BAR + CELL_PAD * 0.5
	if row.mate:
		row.chevron.fit(Rect2(Vector2(x, y + (ROW_HEIGHT - CHEVRON.y) * 0.5), CHEVRON))
		x += CHEVRON.x + NAME_GAP
	var font := _you_font if row.you else _row_font
	x += font.get_string_size(row.name, HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_SIZE).x + NAME_GAP
	var word := _chip_font.get_string_size(_chip_word, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x
	var h := maxf(CHIP_GLYPH, _chip_font.get_height(CHIP_SIZE)) + CHIP_PAD.y * 2.0
	row.chip = Rect2(x, y + (ROW_HEIGHT - h) * 0.5, CHIP_PAD.x * 2.0 + CHIP_GLYPH + CHIP_PAD.x * 0.5 + word, h)
	row.hand.fit(Vector2(x + CHIP_PAD.x, y + (ROW_HEIGHT - CHIP_GLYPH) * 0.5), CHIP_GLYPH)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), HudStyle.backing_on(self, HudStyle.BACKING_CLOCK))
	draw_rect(Rect2(0.0, 0.0, size.x, HudStyle.BANNER_RULE), GameTheme.ACCENT)
	if _heading != "":
		_draw_heading()
	elif _title != "":
		draw_string(_title_font, Vector2(PAD.x, PAD.y + _title_font.get_ascent(TITLE_SIZE)), _title,
				HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, GameTheme.TEXT)
	if _band >= 0:
		_draw_bands()
	for team in _teams:
		_draw_team(team)
	for row in _rows:
		_draw_row(row)


func _draw_heading() -> void:
	var base := PAD.y + _heading_font.get_ascent(HEADING_SIZE)
	draw_string(_heading_font, Vector2(PAD.x, base), _heading, HORIZONTAL_ALIGNMENT_LEFT, -1, HEADING_SIZE, GameTheme.TEXT)
	var x := PAD.x + _heading_font.get_string_size(_heading, HORIZONTAL_ALIGNMENT_LEFT, -1, HEADING_SIZE).x + HEADING_GAP
	draw_string(_sub_font, Vector2(x, base), _heading_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, HEADING_SUB_SIZE, GameTheme.MUTED)
	_right(_sub_font, _heading_note, size.x - PAD.x, base, HEADING_SUB_SIZE, GameTheme.MUTED)


## The shaded column, from each team's header to its last row.
func _draw_bands() -> void:
	var left := _rights[_band] - _widths[_band]
	var r := 0
	for t in _teams.size():
		var top := _teams[t].head_y
		var bottom := top + HEAD_HEIGHT
		while r < _rows.size() and _rows[r].team == t:
			bottom = _rows[r].y + ROW_HEIGHT
			r += 1
		draw_rect(Rect2(left, top, _widths[_band], bottom - top), BAND)


func _draw_team(team: Team) -> void:
	var badge := Rect2(Vector2(PAD.x, team.y), TEAM_BADGE)
	draw_rect(badge, team.colour)
	_centred(_you_font, team.score, badge, TEAM_SCORE_SIZE, HudStyle.ink_on(team.colour, Color.WHITE))
	var base := team.y + (TEAM_HEIGHT + _team_font.get_ascent(TEAM_NAME_SIZE) - _team_font.get_descent(TEAM_NAME_SIZE)) \
			* 0.5
	draw_string(_team_font, Vector2(badge.end.x + TEAM_GAP, base), team.name, HORIZONTAL_ALIGNMENT_LEFT, -1,
			TEAM_NAME_SIZE, team.colour.lightened(NAME_LIGHTEN))
	if team.note != "":
		draw_string(_head_font, Vector2(PAD.x, base), team.note, HORIZONTAL_ALIGNMENT_RIGHT, size.x - PAD.x * 2.0,
				TEAM_NOTE_SIZE, GameTheme.MUTED)
	var head := team.head_y + _head_font.get_ascent(HEAD_SIZE)
	draw_string(_head_font, Vector2(PAD.x + YOU_BAR + CELL_PAD * 0.5, head), _player_word,
			HORIZONTAL_ALIGNMENT_LEFT, -1, HEAD_SIZE, GameTheme.MUTED)
	for c in _columns.size():
		_right(_head_font, _columns[c], _rights[c] - CELL_PAD * 0.5, head, HEAD_SIZE, GameTheme.MUTED)


func _draw_row(row: Row) -> void:
	var line := Rect2(PAD.x, row.y, size.x - PAD.x * 2.0, ROW_HEIGHT)
	draw_rect(Rect2(line.position, Vector2(line.size.x, 1.0)), Color(GameTheme.LINE, RULE_ALPHA))
	if row.you:
		draw_rect(line, Color(GameTheme.ACCENT, YOU_TINT))
		draw_rect(Rect2(line.position, Vector2(YOU_BAR, ROW_HEIGHT)), GameTheme.ACCENT)
	var own := GameTheme.DIM if row.out else GameTheme.TEXT
	var font := _you_font if row.you else _row_font
	var base := row.y + (ROW_HEIGHT + font.get_ascent(ROW_SIZE) - font.get_descent(ROW_SIZE)) * 0.5
	var x := PAD.x + YOU_BAR + CELL_PAD * 0.5
	if row.mate:
		row.chevron.paint(self, GameTheme.DIM if row.out else _mate_colour, false)
		x += CHEVRON.x + NAME_GAP
	draw_string(font, Vector2(x, base), row.name, HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_SIZE, own)
	if row.out:
		draw_rect(row.chip, GameTheme.DIM, false, CHIP_EDGE)
		row.hand.paint(self, CHIP_TEXT)
		var chip_base := row.chip.position.y + (row.chip.size.y + _chip_font.get_ascent(CHIP_SIZE)
				- _chip_font.get_descent(CHIP_SIZE)) * 0.5
		draw_string(_chip_font, Vector2(row.chip.position.x + CHIP_PAD.x + CHIP_GLYPH + CHIP_PAD.x * 0.5, chip_base),
				_chip_word, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE, CHIP_TEXT)
	for c in mini(row.cells.size(), _rights.size()):
		var colour := own
		if c < row.colours.size() and row.colours[c].a > 0.0:
			colour = row.colours[c]
		_right(_row_font, row.cells[c], _rights[c] - CELL_PAD * 0.5, base, ROW_SIZE, colour)


func _right(font: Font, text: String, right: float, base: float, font_size: int, colour: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(right - w, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


func _centred(font: Font, text: String, box: Rect2, font_size: int, colour: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var base := box.position.y + (box.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(box.position.x + (box.size.x - w) * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, colour)
