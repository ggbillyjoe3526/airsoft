class_name HudFeed
extends VBoxContainer
## The hit feed on screen (concept `hud-feed.png`): HitFeed's lines as HudFeedRows, hits and your team's callouts
## (concept `step27/callouts.png`), top right with the newest on top, or bottom left with the newest at the bottom. Rows
## are made once (one per line the feed can hold) and refilled only when the lines change; each frame only the fading
## lines' opacity moves.

enum Place { TOP_RIGHT, BOTTOM_LEFT }

## How much lighter than its team colour a name is (the concepts' name colours).
const NAME_LIGHTEN := 0.3

var corner: Place = Place.TOP_RIGHT
var _rows: Array[HudFeedRow] = []
var _version: int = -1
var _cap: int = -1 # the most lines shown (the newest ones); -1 for no limit
var _teams: TeamConfig = null
var _names := PackedStringArray()
var _shooter := HudFeedRow.Who.new()
var _victim := HudFeedRow.Who.new()


## `lines` rows (at least one), `gap` px apart, names and bars in `teams`' colours.
func setup(lines: int, gap: float, teams: TeamConfig) -> void:
	name = "HudFeed"
	_teams = teams
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", roundi(gap))
	for i in maxi(1, lines):
		var row := HudFeedRow.new()
		row.visible = false
		add_child(row)
		_rows.append(row)
	set_corner(corner)


## Top right (newest on top) or bottom left (newest at the bottom).
func set_corner(where: Place) -> void:
	corner = where
	var right := where == Place.TOP_RIGHT
	alignment = BoxContainer.ALIGNMENT_BEGIN if right else BoxContainer.ALIGNMENT_END
	for row in _rows:
		row.size_flags_horizontal = Control.SIZE_SHRINK_END if right else Control.SIZE_SHRINK_BEGIN
	_version = -1


## Shows only the newest lines that fit in `room` px of height (all of them when `room` is negative): for the bottom-left
## feed while a card hangs over it. The lines come back when the room does.
func fit(room: float) -> void:
	var cap := -1
	if room >= 0.0:
		var row := _rows[0].get_combined_minimum_size().y
		var gap := float(get_theme_constant("separation"))
		cap = maxi(0, floori((room + gap) / (row + gap)))
	if cap != _cap:
		_cap = cap
		_version = -1


## Whether the feed is up and has room for its newest line (not hidden, nor held to none under What got you).
func newest_shows() -> bool:
	return visible and _cap != 0


## The height of the lines showing (px).
func lines_height() -> float:
	var n := shown()
	if n == 0:
		return 0.0
	return n * _rows[0].get_combined_minimum_size().y + (n - 1) * get_theme_constant("separation")


## The names to show, by character id; "" for you (shown as "You").
func set_names(names: PackedStringArray) -> void:
	_names = names
	_version = -1


## Shows `feed` at simulation time `now`, as seen by `you` (a character), with everyone in `characters`.
func refresh(feed: HitFeed, now: float, characters: Array[Character], you: Character) -> void:
	if feed.version != _version:
		_version = feed.version
		_fill(feed, characters, you)
	for i in feed.shown():
		_row_for(i).modulate.a = feed.alpha(i, now)


## The row showing the `i`th line (0 the newest).
func row_of(i: int) -> HudFeedRow:
	return _row_for(i)


## How many lines show.
func shown() -> int:
	var n := 0
	for row in _rows:
		if row.visible:
			n += 1
	return n


func _fill(feed: HitFeed, characters: Array[Character], you: Character) -> void:
	var mate_colour := _teams.colours[you.team]
	for i in _rows.size():
		var row := _row_for(i)
		row.visible = i < feed.shown() and (_cap < 0 or i < _cap)
		if not row.visible:
			continue
		var line := feed.line(i)
		var shooter := characters[line.shooter]
		if line.call:
			_side(_shooter, shooter, you)
			row.show_call(_shooter, line.words, _teams.colours[shooter.team], mate_colour, line.note)
			continue
		var victim := characters[line.victim]
		_side(_shooter, shooter, you)
		_side(_victim, victim, you)
		row.show_line(_shooter, _victim, _teams.colours[shooter.team], mate_colour, _shooter.you or _victim.you)


func _side(side: HudFeedRow.Who, c: Character, you: Character) -> void:
	side.set_to(_name(c, you), _colour(c, you), _is_mate(c, you), c.id == you.id)


func _row_for(i: int) -> HudFeedRow:
	return _rows[i] if corner == Place.TOP_RIGHT else _rows[_rows.size() - 1 - i]


func _name(c: Character, you: Character) -> String:
	return name_of(c, you, _names, _teams)


## The name the feed shows for `c` as seen by `you`: "You", its name in `names` (by character id), or else its team's
## name in `teams`. The screen reader's lines (Announcer) say the same.
static func name_of(c: Character, you: Character, names: PackedStringArray, teams: TeamConfig) -> String:
	if c.id == you.id:
		return TranslationServer.translate(&"HUD_YOU")
	if c.id < names.size() and names[c.id] != "":
		return names[c.id]
	return TranslationServer.translate(teams.names[c.team])


func _colour(c: Character, you: Character) -> Color:
	return GameTheme.TEXT if c.id == you.id else _teams.colours[c.team].lightened(NAME_LIGHTEN)


func _is_mate(c: Character, you: Character) -> bool:
	return c.id != you.id and c.team == you.team
