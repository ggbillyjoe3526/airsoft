class_name BotsFile
extends RefCounted
## The bots' names and personalities (the browser game's config/botsFile.ts): data/bots.md, hand-edited by the owner,
## read once when the game starts. A personality changes how a bot plays, never how well: BotPersonality lays its
## numbers over the bot's difficulty. Never throws: a cell it can't read plays as if the personality changed nothing
## there, a roster row it can't read is left out, and each is listed in `problems` as "bots.md:line: …".

const PATH := "res://data/bots.md"
const FILE_NAME := "bots.md"
## The longest name the roster takes: it shows in the hit feed and on the spectating line.
const NAME_MAX_LENGTH := 12
const ROSTER := "Roster"
const PERSONALITIES := "Personalities"
const MOVES := "How they move"
const HABITS := "Habits"
const PERSONALITY_COLUMN := "Personality"
const NAME_COLUMN := "Name"
const CARD_COLUMN := "Card note"
## The least a Burst (×) may be: at 0 a bot's burst lasts no time, so it aims and never pulls the trigger.
const BURST_LEAST := 0.1
## How they move: each (×) column, the Style field it sets, the most it may be and the least.
const SCALE_COLUMNS: Array[Array] = [
	["Lane pause (×)", &"hold_time", 5.0, 0.0],
	["Cover at a lane point (×)", &"hold_cover_chance", 5.0, 0.0],
	["Cover on contact from (×)", &"contact_cover_min_distance", 5.0, 0.0],
	["Walk the last (×)", &"search_walk_distance", 5.0, 0.0],
	["Burst (×)", &"burst", 3.0, BURST_LEAST],
	["Burst pause (×)", &"burst_pause", 3.0, 0.0],
]
const FLANK_COLUMN := "Flank chance (+)"
const WATCH_COLUMN := "Watch where you ducked (s)"
const WATCH_MAX := 30.0
## Habits: the yes/no columns, with – as the neutral style has it.
const HABIT_COLUMNS: Array[Array] = [
	["Pushes in", &"pushes_in"],
	["Waits for the team", &"waits_for_team"],
	["Own lane", &"own_lane"],
	["Aims from cover", &"aims_from_cover"],
]
const HOLD_COLUMN := "Holds until (s left)"
const HOLD_MAX := 600.0
## Yes, no or – (the difficulty's own).
const LEVEL_HABIT_COLUMNS: Array[Array] = [["Holds angles", &"holds_angles"], ["Slices corners", &"slices_corners"]]
## Optional: a Habits table without it watches nothing first (BotPersonality.overtime_watching, OV2).
const FLAG_COLUMN := "Watches the flag first (s)"
const FLAG_MAX := 60.0
## The cells that mean "nothing here".
const NONE_CELLS: PackedStringArray = ["", "–", "-", "—"]

## A Habits cell for a habit some levels have: as the difficulty plays it, on or off.
enum Habit { SAME, ON, OFF }


## What a personality changes (bots.md › How they move and Habits). The scales multiply the difficulty's BotSkill
## numbers, flank_chance adds to its chance; an on/off habit is one no level has, a Habit (yes, no or none) one it may.
class Style:
	extends RefCounted
	## As the file names it ("Rusher"), and the "What got you" card's line, `{name}` for the bot's.
	var label: String = ""
	var card_note: String = ""
	var hold_time: float = 1.0
	var hold_cover_chance: float = 1.0
	var contact_cover_min_distance: float = 1.0
	var search_walk_distance: float = 1.0
	var flank_chance: float = 0.0
	var burst: float = 1.0
	var burst_pause: float = 1.0
	## In place of BotSkill.peek_watch_time while has_peek_watch.
	var has_peek_watch: bool = false
	var peek_watch_time: Vector2 = Vector2.ZERO
	## Fights closing in, takes no cover on a fresh sighting, runs at where someone was.
	var pushes_in: bool = false
	## Waits at a lane point for teammates it is well ahead of.
	var waits_for_team: bool = true
	## Takes a free lane rather than share one with a teammate.
	var own_lane: bool = false
	## Holds the last lane point short of the middle until the round clock is down to hold_until (s), while holds.
	var holds: bool = false
	var hold_until: float = 0.0
	## Raises its sight standing still to fight or hold.
	var aims_from_cover: bool = false
	## BotSkill.holds_angles and slices_corners: Habit.SAME keeps the difficulty's.
	var holds_angles: Habit = Habit.SAME
	var slices_corners: Habit = Habit.SAME
	## Holds cover by the overtime flag this long (s) before going in, while watches_flag.
	var watches_flag: bool = false
	var flag_watch: float = 0.0

	## Whether it changes nothing at all.
	func is_neutral() -> bool:
		return hold_time == 1.0 and hold_cover_chance == 1.0 and contact_cover_min_distance == 1.0 \
				and search_walk_distance == 1.0 and flank_chance == 0.0 and burst == 1.0 and burst_pause == 1.0 \
				and not has_peek_watch and not pushes_in and waits_for_team and not own_lane and not holds \
				and not aims_from_cover and holds_angles == Habit.SAME and slices_corners == Habit.SAME


## One name on the roster and the personality it always plays (a key of `styles`).
class Entry:
	extends RefCounted
	var bot_name: String = ""
	var personality: StringName = &""


var roster: Array[Entry] = []
## Every personality by its key (its name in lower case), and the keys in the file's order.
var styles: Dictionary[StringName, Style] = {}
var kinds: Array[StringName] = []
var problems: Array[String] = []

static var _shared: BotsFile = null
## What a bot without a personality plays.
static var _neutral: Style = Style.new()


## bots.md as shipped, read once; each problem is a warning.
static func shared() -> BotsFile:
	if _shared == null:
		_shared = read_file()
		for p in _shared.problems:
			push_warning("bots: %s" % p)
	return _shared


## The style that changes nothing.
static func neutral() -> Style:
	return _neutral


static func read_file(path: String = PATH) -> BotsFile:
	if not FileAccess.file_exists(path):
		var none := BotsFile.new()
		none.problems.append("%s can't be read: bots play without names or personalities" % path)
		return none
	return parse(FileAccess.get_file_as_string(path))


static func parse(text: String) -> BotsFile:
	var f := BotsFile.new()
	var tables := DataTable.read_all(text, FILE_NAME)
	for t in tables:
		f.problems.append_array(t.problems)
	f._read_personalities(f._required(tables, PERSONALITIES, [PERSONALITY_COLUMN, CARD_COLUMN]))
	var moves: PackedStringArray = [PERSONALITY_COLUMN]
	for c in SCALE_COLUMNS:
		moves.append(c[0])
	moves.append_array([FLANK_COLUMN, WATCH_COLUMN])
	var moves_table := f._required(tables, MOVES, moves)
	for row in f._rows_of(moves_table):
		f._read_moves(row, moves_table)
	var habits: PackedStringArray = [PERSONALITY_COLUMN]
	for c in HABIT_COLUMNS:
		habits.append(c[0])
	habits.append(HOLD_COLUMN)
	for c in LEVEL_HABIT_COLUMNS:
		habits.append(c[0])
	var habits_table := f._required(tables, HABITS, habits)
	for row in f._rows_of(habits_table):
		f._read_habits(row, habits_table)
	f._read_roster(f._required(tables, ROSTER, [NAME_COLUMN, PERSONALITY_COLUMN]))
	return f


## The style `key` plays, or the neutral one.
func style(key: StringName) -> Style:
	return styles.get(key, _neutral)


func _read_personalities(t: DataTable) -> void:
	if t == null:
		return
	for row in t.rows:
		var label := row.cell(PERSONALITY_COLUMN)
		var key := StringName(label.to_lower())
		if not _is_name(label, false):
			problems.append("%s: \"%s\" is not a personality name (letters, spaces and hyphens)" % [t.where(row.line),
					label])
		elif styles.has(key):
			problems.append("%s: %s is listed twice" % [t.where(row.line), label])
		else:
			var s := Style.new()
			s.label = label
			s.card_note = row.cell(CARD_COLUMN)
			styles[key] = s
			kinds.append(key)


func _read_moves(row: DataTable.Row, t: DataTable) -> void:
	var s := styles[StringName(row.cell(PERSONALITY_COLUMN).to_lower())]
	for c in SCALE_COLUMNS:
		var v := _number(row.cell(c[0]))
		if is_nan(v) or v < c[3] or v > c[2]:
			problems.append("%s: %s: \"%s\" is not a number from %s to %d" % [t.where(row.line), c[0], row.cell(c[0]),
					String.num(c[3]), c[2]])
		else:
			s.set(c[1], v)
	var flank := _number(row.cell(FLANK_COLUMN))
	if is_nan(flank) or flank < -1.0 or flank > 1.0:
		problems.append("%s: %s: \"%s\" is not a number from -1 to 1" % [t.where(row.line), FLANK_COLUMN,
				row.cell(FLANK_COLUMN)])
	else:
		s.flank_chance = flank
	var watch := row.cell(WATCH_COLUMN)
	if NONE_CELLS.has(watch):
		return
	var r := _range(watch)
	if is_nan(r.x) or r.y > WATCH_MAX:
		problems.append("%s: %s: \"%s\" is not a range of seconds like 1.5–3 (at most %d), or –" % [t.where(row.line),
				WATCH_COLUMN, watch, WATCH_MAX])
	else:
		s.has_peek_watch = true
		s.peek_watch_time = r


func _read_habits(row: DataTable.Row, t: DataTable) -> void:
	var s := styles[StringName(row.cell(PERSONALITY_COLUMN).to_lower())]
	for c in HABIT_COLUMNS:
		var v := _habit(row.cell(c[0]))
		if v < 0:
			problems.append("%s: %s: \"%s\" is not yes, no or –" % [t.where(row.line), c[0], row.cell(c[0])])
		elif v != Habit.SAME:
			s.set(c[1], v == Habit.ON)
		# – leaves it as the difficulty plays it: no level has these, so off, except waiting.
		else:
			s.set(c[1], _neutral.get(c[1]))
	var hold := row.cell(HOLD_COLUMN)
	if not NONE_CELLS.has(hold):
		var secs := _number(hold)
		if is_nan(secs) or secs < 0.0 or secs > HOLD_MAX:
			problems.append("%s: %s: \"%s\" is not seconds from 0 to %d, or –" % [t.where(row.line), HOLD_COLUMN, hold,
					HOLD_MAX])
		else:
			s.holds = true
			s.hold_until = secs
	for c in LEVEL_HABIT_COLUMNS:
		var v := _habit(row.cell(c[0]))
		if v < 0:
			problems.append("%s: %s: \"%s\" is not yes, no or –" % [t.where(row.line), c[0], row.cell(c[0])])
		else:
			s.set(c[1], v)
	var flag := row.cell(FLAG_COLUMN)
	if NONE_CELLS.has(flag):
		return
	var watch := _number(flag)
	if is_nan(watch) or watch < 0.0 or watch > FLAG_MAX:
		problems.append("%s: %s: \"%s\" is not seconds from 0 to %d, or –" % [t.where(row.line), FLAG_COLUMN, flag,
				FLAG_MAX])
	else:
		s.watches_flag = true
		s.flag_watch = watch


## Unique made-up names, each playing a personality the file describes.
func _read_roster(t: DataTable) -> void:
	if t == null:
		return
	var taken: Dictionary[String, bool] = {}
	for row in t.rows:
		var bot_name := row.cell(NAME_COLUMN)
		var key := StringName(row.cell(PERSONALITY_COLUMN).to_lower())
		if not _is_name(bot_name, true) or bot_name.length() > NAME_MAX_LENGTH:
			problems.append("%s: \"%s\" is not a name (letters, spaces, hyphens and apostrophes, at most %d)"
					% [t.where(row.line), bot_name, NAME_MAX_LENGTH])
		elif taken.has(bot_name.to_lower()):
			problems.append("%s: %s is on the roster twice" % [t.where(row.line), bot_name])
		elif not styles.has(key):
			problems.append("%s: %s: \"%s\" is not in the Personalities table" % [t.where(row.line), bot_name,
					row.cell(PERSONALITY_COLUMN)])
		else:
			taken[bot_name.to_lower()] = true
			var e := Entry.new()
			e.bot_name = bot_name
			e.personality = key
			roster.append(e)


## The table under `heading_text` with every column in `wanted`, or null (and a problem).
func _required(tables: Array[DataTable], heading_text: String, wanted: PackedStringArray) -> DataTable:
	var t := DataTable.find(tables, heading_text)
	if t == null:
		problems.append("%s:1: no \"%s\" table (a \"## %s\" heading over it)" % [FILE_NAME, heading_text, heading_text])
		return null
	for column in wanted:
		if not t.has_column(column):
			problems.append("%s: %s: no \"%s\" column" % [t.where(t.line), heading_text, column])
			return null
	return t


## The rows of `t` naming a personality the Personalities table has, each once; a personality it leaves out keeps the
## neutral values for its columns, and is reported.
func _rows_of(t: DataTable) -> Array[DataTable.Row]:
	var out: Array[DataTable.Row] = []
	if t == null:
		return out
	var seen: Array[StringName] = []
	for row in t.rows:
		var key := StringName(row.cell(PERSONALITY_COLUMN).to_lower())
		if not styles.has(key):
			problems.append("%s: %s: \"%s\" is not in the Personalities table" % [t.where(row.line), t.heading,
					row.cell(PERSONALITY_COLUMN)])
		elif seen.has(key):
			problems.append("%s: %s: %s is listed twice" % [t.where(row.line), t.heading, row.cell(PERSONALITY_COLUMN)])
		else:
			seen.append(key)
			out.append(row)
	for key in kinds:
		if not seen.has(key):
			problems.append("%s: %s: no row for %s, so it plays neutral there" % [t.where(t.line), t.heading,
					styles[key].label])
	return out


## Letters first, then letters, spaces and hyphens (and apostrophes for a bot's name).
static func _is_name(text: String, apostrophes: bool) -> bool:
	if text == "" or not _is_letter(text.unicode_at(0)):
		return false
	for i in range(1, text.length()):
		var ch := text[i]
		if not (_is_letter(text.unicode_at(i)) or ch == " " or ch == "-" or (apostrophes and ch == "'")):
			return false
	return true


static func _is_letter(code: int) -> bool:
	var ch := String.chr(code)
	return ch.to_lower() != ch.to_upper()


## A plain number (a minus typed as −), NAN for anything else (a % sign included).
static func _number(cell: String) -> float:
	return NAN if cell.ends_with("%") else DataTable.parse_number(cell)


## `1.5–3` (an en dash or a hyphen) from shortest to longest, or Vector2(NAN, NAN).
static func _range(cell: String) -> Vector2:
	var parts := cell.replace("–", "-").split("-")
	if parts.size() != 2:
		return Vector2(NAN, NAN)
	var lo := _number(parts[0])
	var hi := _number(parts[1])
	if is_nan(lo) or is_nan(hi) or lo < 0.0 or lo > hi:
		return Vector2(NAN, NAN)
	return Vector2(lo, hi)


## Yes, no or – as a Habit; -1 for anything else.
static func _habit(cell: String) -> int:
	var t := cell.to_lower()
	if t == "yes":
		return Habit.ON
	if t == "no":
		return Habit.OFF
	return Habit.SAME if NONE_CELLS.has(t) else -1
