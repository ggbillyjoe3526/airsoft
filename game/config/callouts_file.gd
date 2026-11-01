class_name CalloutsFile
extends RefCounted
## What the bots call to their team, how often and the words (the browser game's config/calloutsFile.ts, CL1):
## data/callouts.md, hand-edited by the owner, read once when the game starts as BotsFile reads bots.md. The director
## (game/ai/callouts.gd) plays it. Never throws: a row it can't read is left out and listed in `problems` as
## "callouts.md:line: …"; an event without a row in When they call is never called.

const PATH := "res://data/callouts.md"
const FILE_NAME := "callouts.md"
## Longest a line may be once filled in (with the longest area name and number word in): one line of the feed.
const LINE_MAX := 48
## Longest gap any Pace, Marks, Asks or Team gap cell may give (s), and the most a personality's Talks (×) may be.
const GAP_MAX := 120.0
const TALKS_MAX := 5.0
const WHEN := "When they call"
const PACE := "Pace"
const MARKS := "Marks"
const ASKS := "Asks"
const PERSONALITIES := "Personalities"
const LINES := "Lines"
const ANY := "any"

## The events a bot calls (callouts.md › The events), in the browser's order.
enum Event {
	CONTACT, CONTACTS, HEARD, DOWN, LAST_ONE, TAGGED, RELOADING, PUSHING, FLANKING, CHECKING, HOLDING, RAISING, FLAG,
	OVERTIME, PING_GOING, PING_WATCHING, NEED_MAG, MAG_COMING, MAG_THANKS, NEED_HELP, GO_ROUND, COVER_ME,
}
## What a line may fill in: the named area, how many were seen, how many are left.
enum Fill { AREA, COUNT, LEFT }
## Each event's name in the file, and what its lines may fill in (by Event).
const EVENT_NAMES: PackedStringArray = [
	"Contact", "Contacts", "Heard", "Down", "Last one", "Tagged", "Reloading", "Pushing", "Flanking", "Checking",
	"Holding", "Raising", "Flag", "Overtime", "Going to your ping", "Watching your ping", "Need a mag", "Mag coming",
	"Thanks for the mag", "Need help", "Go round", "Cover me",
]
const EVENT_FILLS: Array[PackedInt32Array] = [
	[Fill.AREA], [Fill.COUNT, Fill.AREA], [Fill.AREA], [Fill.LEFT], [Fill.AREA], [], [], [Fill.AREA], [Fill.AREA],
	[Fill.AREA], [Fill.AREA], [], [], [Fill.AREA], [Fill.AREA], [Fill.AREA], [], [], [], [Fill.AREA], [Fill.AREA], [],
]
const FILL_NAMES: PackedStringArray = ["area", "count", "left"]
## Numbers to twelve in words, as a sentence starts and inside one; past twelve, the digits.
const NUMBER_WORDS: PackedStringArray = [
	"None", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve",
]
const NUMBER_WORDS_LOWER: PackedStringArray = [
	"none", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
]
## The Pace rows by their first column, with the Pace field each sets (its value without a row is Pace's default).
const PACE_ROWS: Array[Array] = [
	["One bot's calls apart", &"bot_gap"],
	["The team's calls apart", &"team_gap"],
	["The same enemy again after", &"same_enemy_gap"],
	["A call waits at most", &"max_wait"],
]
## The Marks rows: first column, field, the most it may be and what that is in words (without a row: Marks' default).
const MARK_ROWS: Array[Array] = [
	["A sighting is marked (chance)", &"chance", 1.0, "a number from 0 to 1"],
	["The team's marks apart (s)", &"gap", GAP_MAX, "seconds from 0 to 120"],
]
## The Asks rows (BQ2), as MARK_ROWS.
const ASK_ROWS: Array[Array] = [
	["The team's asks apart (s)", &"gap", GAP_MAX, "seconds from 0 to 120"],
	["Asks a round, at most", &"per_round", 10.0, "a whole number from 0 to 10"],
	["You are further than (m)", &"you_further", 100.0, "metres from 0 to 100"],
	["Seen at once to need help", &"outnumbered", 10.0, "a whole number from 0 to 10"],
	["Seen within (s)", &"seen_within", 30.0, "seconds from 0 to 30"],
	["A stand-off after (s)", &"stand_off", GAP_MAX, "seconds from 0 to 120"],
	["Go round beside them (m)", &"round_offset", 40.0, "metres from 0 to 40"],
]


## When an event is called (When they call): the chance (0 to 1) before Talks (×), seconds before the team calls it
## again, and its row (0 first): the lower wins when two calls come at once.
class Rule:
	extends RefCounted
	var chance: float = 0.0
	var team_gap: float = 0.0
	var priority: int = Event.size()


## callouts.md › Pace, in seconds.
class Pace:
	extends RefCounted
	## One bot's calls are at least this far apart; any two of a team's; the same enemy (Contact, Contacts) again.
	var bot_gap: float = 4.0
	var team_gap: float = 1.5
	var same_enemy_gap: float = 10.0
	## A call the team gap holds back is dropped after this.
	var max_wait: float = 1.5


## callouts.md › Marks: how often a sighting call also marks the enemy for the team's players (read here; the pings'
## task plays it).
class Marks:
	extends RefCounted
	var chance: float = 0.35
	var gap: float = 12.0


## callouts.md › Asks (BQ2): when a bot on your team pings a spot for you as it calls Need help, Go round or Cover me.
## The team asks at most once in `gap` and `per_round` times a round, only while you are further than `you_further` m
## from it (or from the pole); Need help when it fights `outnumbered` enemies or more seen within `seen_within` s, Go
## round when it has traded looks with one for `stand_off` s, pinging a spot `round_offset` m to the side of them.
class Asks:
	extends RefCounted
	var gap: float = 30.0
	var per_round: float = 3.0
	var you_further: float = 15.0
	var outnumbered: float = 2.0
	var seen_within: float = 4.0
	var stand_off: float = 8.0
	var round_offset: float = 12.0


## One line: `who` a personality's key (&"rusher") or &"" for Any, the text as written, and the text cut into its
## pieces once: `parts[k]` is literal text where `fills[k]` is -1, else a Fill (its part ""), with `starts[k]` whether a
## sentence starts there (a number is then a capital). The first letter of the said line is a capital.
class Line:
	extends RefCounted
	var who: StringName = &""
	var text: String = ""
	## Whether `text` holds {area}: such a line is skipped when there is no area to name.
	var needs_area: bool = false
	var parts: PackedStringArray = PackedStringArray()
	var fills: PackedInt32Array = PackedInt32Array()
	var starts: PackedByteArray = PackedByteArray()

	## The line with its fills put in.
	func filled(area: String, count: int, left: int) -> String:
		var out := ""
		for k in parts.size():
			match fills[k]:
				-1:
					out += parts[k]
				Fill.AREA:
					out += CalloutsFile.capital(area) if starts[k] == 1 else area
				Fill.COUNT:
					out += CalloutsFile.number_word(count, starts[k] == 1)
				_:
					out += CalloutsFile.number_word(left, starts[k] == 1)
		return out


var rules: Array[Rule] = []
var pace: Pace = Pace.new()
var marks: Marks = Marks.new()
var asks: Asks = Asks.new()
## Talks (×) per personality key; a bot without a personality, or one the table lacks, talks × 1.
var talks: Dictionary[StringName, float] = {}
## Each event's lines (by Event).
var lines: Array[Array] = []
var problems: Array[String] = []

static var _shared: CalloutsFile = null
static var _fill_pattern: RegEx = null


func _init() -> void:
	for e in Event.size():
		rules.append(Rule.new())
		lines.append([] as Array[Line])


## callouts.md as shipped, read once against bots.md's personalities; each problem is a warning.
static func shared() -> CalloutsFile:
	if _shared == null:
		_shared = read_file(PATH, BotsFile.shared().kinds)
		for p in _shared.problems:
			push_warning("callouts: %s" % p)
	return _shared


static func read_file(path: String, personalities: Array[StringName]) -> CalloutsFile:
	if not FileAccess.file_exists(path):
		var none := CalloutsFile.new()
		none.problems.append("%s can't be read: the bots call nothing" % path)
		return none
	return parse(FileAccess.get_file_as_string(path), personalities)


## Reads callouts.md's text. `personalities` are bots.md's keys (&"rusher"): a Who or a Personalities row naming another
## is a problem, and one the Personalities table here leaves out talks × 1 (reported).
static func parse(text: String, personalities: Array[StringName]) -> CalloutsFile:
	var f := CalloutsFile.new()
	var tables := DataTable.read_all(text, FILE_NAME)
	for t in tables:
		f.problems.append_array(t.problems)
	f._read_rules(f._required(tables, WHEN, ["Event", "Chance", "Team gap (s)"]))
	f._read_pace(f._required(tables, PACE, ["Rule", "Seconds"]))
	f._read_values(f._required(tables, MARKS, ["Rule", "Value"]), MARK_ROWS, f.marks, MARKS)
	# Asks (BQ2) are optional: a file without the table asks with Asks' defaults, and only for events it has rows for.
	var asks := DataTable.find(tables, ASKS)
	if asks != null:
		f._read_values(f._required(tables, ASKS, ["Rule", "Value"]), ASK_ROWS, f.asks, ASKS)
	f._read_talks(f._required(tables, PERSONALITIES, ["Personality", "Talks (×)"]), personalities)
	f._read_lines(f._required(tables, LINES, ["Event", "Who", "Line"]), personalities)
	return f


## `n` in words ("Two"), a capital when a sentence starts with it; past twelve (or below none), the digits.
static func number_word(n: int, capital: bool = true) -> String:
	if n < 0 or n >= NUMBER_WORDS.size():
		return str(n)
	return NUMBER_WORDS[n] if capital else NUMBER_WORDS_LOWER[n]


## `text` with its fills put in (for tests and tools; a Line keeps its pieces cut once).
static func fill_line(text: String, area: String, count: int, left: int) -> String:
	return _cut(text).filled(area, count, left)


## `text` with its first letter a capital (itself when it already is one, allocating nothing).
static func capital(text: String) -> String:
	if text == "" or text[0] == text[0].to_upper():
		return text
	return text[0].to_upper() + text.substr(1)


## The event a first-column cell names, or -1.
static func event_of(cell: String) -> int:
	var key := _key_of(cell)
	for e in Event.size():
		if EVENT_NAMES[e].to_lower() == key:
			return e
	return -1


func _read_rules(t: DataTable) -> void:
	if t == null:
		return
	var ruled := 0
	for row in t.rows:
		var e := event_of(row.cell("Event"))
		if e < 0:
			problems.append("%s: \"%s\" is not an event (%s)" % [t.where(row.line), row.cell("Event"),
					", ".join(EVENT_NAMES)])
			continue
		if rules[e].priority < Event.size():
			problems.append("%s: %s is listed twice" % [t.where(row.line), EVENT_NAMES[e]])
			continue
		var chance := _number(row.cell("Chance"))
		var gap := _number(row.cell("Team gap (s)"))
		if not (chance >= 0.0 and chance <= 1.0):
			problems.append("%s: Chance: \"%s\" is not a number from 0 to 1" % [t.where(row.line), row.cell("Chance")])
		elif not (gap >= 0.0 and gap <= GAP_MAX):
			problems.append("%s: Team gap (s): \"%s\" is not seconds from 0 to %d" % [t.where(row.line),
					row.cell("Team gap (s)"), GAP_MAX])
		else:
			rules[e].chance = chance
			rules[e].team_gap = gap
			rules[e].priority = ruled
			ruled += 1
	for e in Event.size():
		if rules[e].priority == Event.size():
			problems.append("%s: When they call: no row for %s, so it is never called" % [t.where(t.line),
					EVENT_NAMES[e]])


func _read_pace(t: DataTable) -> void:
	if t == null:
		return
	var done: Array[StringName] = []
	for row in t.rows:
		var p := _row_named(PACE_ROWS, row.cell("Rule"))
		var s := _number(row.cell("Seconds"))
		if p.is_empty():
			problems.append("%s: \"%s\" is not a pace rule (%s)" % [t.where(row.line), row.cell("Rule"),
					_names(PACE_ROWS)])
		elif done.has(p[1]):
			problems.append("%s: %s is listed twice" % [t.where(row.line), p[0]])
		elif not (s >= 0.0 and s <= GAP_MAX):
			problems.append("%s: %s: \"%s\" is not seconds from 0 to %d" % [t.where(row.line), p[0],
					row.cell("Seconds"), GAP_MAX])
		else:
			done.append(p[1])
			pace.set(p[1], s)
	for p in PACE_ROWS:
		if not done.has(p[1]):
			problems.append("%s: Pace: no row for %s, so it is %s s" % [t.where(t.line), p[0],
					_num_text(float(pace.get(p[1])))])


## A Rule / Value table (Marks, Asks) of `rows` into `into`'s fields; `heading` names it in a problem.
func _read_values(t: DataTable, rows: Array[Array], into: Object, heading: String) -> void:
	if t == null:
		return
	var done: Array[StringName] = []
	for row in t.rows:
		var m := _row_named(rows, row.cell("Rule"))
		var v := _number(row.cell("Value"))
		if m.is_empty():
			problems.append("%s: \"%s\" is not %s rule (%s)" % [t.where(row.line), row.cell("Rule"),
					"a marks" if heading == MARKS else "an asks", _names(rows)])
		elif done.has(m[1]):
			problems.append("%s: %s is listed twice" % [t.where(row.line), m[0]])
		elif not (v >= 0.0 and v <= m[2]) or ((m[3] as String).begins_with("a whole") and v != floorf(v)):
			problems.append("%s: %s: \"%s\" is not %s" % [t.where(row.line), m[0], row.cell("Value"), m[3]])
		else:
			done.append(m[1])
			into.set(m[1], v)
	for m in rows:
		if not done.has(m[1]):
			problems.append("%s: %s: no row for %s, so it is %s" % [t.where(t.line), heading, m[0],
					_num_text(float(into.get(m[1])))])


func _read_talks(t: DataTable, personalities: Array[StringName]) -> void:
	if t == null:
		return
	for row in t.rows:
		var key := StringName(_key_of(row.cell("Personality")))
		var v := _number(row.cell("Talks (×)"))
		if not personalities.has(key):
			problems.append("%s: \"%s\" is not in bots.md's Personalities table" % [t.where(row.line),
					row.cell("Personality")])
		elif talks.has(key):
			problems.append("%s: %s is listed twice" % [t.where(row.line), row.cell("Personality")])
		elif not (v >= 0.0 and v <= TALKS_MAX):
			problems.append("%s: Talks (×): \"%s\" is not a number from 0 to %d" % [t.where(row.line),
					row.cell("Talks (×)"), TALKS_MAX])
		else:
			talks[key] = v
	for key in personalities:
		if not talks.has(key):
			problems.append("%s: Personalities: no row for %s, so it talks × 1" % [t.where(t.line), key])


func _read_lines(t: DataTable, personalities: Array[StringName]) -> void:
	if t == null:
		return
	for row in t.rows:
		var e := event_of(row.cell("Event"))
		var who_cell := _key_of(row.cell("Who"))
		var who := StringName("" if who_cell == ANY else who_cell)
		var text := row.cell("Line").strip_edges()
		if e < 0:
			problems.append("%s: \"%s\" is not an event" % [t.where(row.line), row.cell("Event")])
			continue
		if who != &"" and not personalities.has(who):
			problems.append("%s: Who: \"%s\" is not Any or a personality in bots.md" % [t.where(row.line),
					row.cell("Who")])
			continue
		var problem := _line_problem(text, EVENT_FILLS[e])
		if problem != "":
			problems.append("%s: %s: %s" % [t.where(row.line), EVENT_NAMES[e], problem])
			continue
		var line := _cut(text)
		line.who = who
		lines[e].append(line)
	for e in Event.size():
		if rules[e].chance > 0.0 and not _has_any_line(e):
			problems.append("%s: Lines: no Any line for %s, so a bot whose personality has none never calls it"
					% [t.where(t.line), EVENT_NAMES[e]])


func _has_any_line(e: int) -> bool:
	for l: Line in lines[e]:
		if l.who == &"":
			return true
	return false


## What is wrong with a Lines cell for an event that fills `fills`, or "".
static func _line_problem(text: String, fills: PackedInt32Array) -> String:
	if text == "":
		return "the line is empty"
	for m in _pattern().search_all(text):
		var fill := FILL_NAMES.find(m.get_string(1))
		if fill < 0:
			return "\"{%s}\" is not something a line fills in ({area}, {count}, {left})" % m.get_string(1)
		if not fills.has(fill):
			var can := PackedStringArray()
			for f in fills:
				can.append("{%s}" % FILL_NAMES[f])
			return "\"{%s}\" is not filled in for this event (%s)" % [FILL_NAMES[fill],
					", ".join(can) if not can.is_empty() else "nothing"]
	var rest := text
	for name in FILL_NAMES:
		rest = rest.replace("{%s}" % name, "")
	if rest.contains("{") or rest.contains("}"):
		return "a brace with nothing to fill in"
	var longest := fill_line(text, "x".repeat(MapAreas.NAME_MAX_LENGTH), NUMBER_WORDS.size() - 1,
			NUMBER_WORDS.size() - 1).length()
	if longest > LINE_MAX:
		return "\"%s\" is too long (%d characters with the longest fills in; %d at most)" % [text, longest, LINE_MAX]
	return ""


## `text` cut into its pieces (a Line with no `who`): literal runs and {area}, {count} and {left}, each fill marked
## where a sentence starts (the line's start, or after ". ", "! " or "? "). A literal first piece gets its capital here.
static func _cut(text: String) -> Line:
	var line := Line.new()
	line.text = text
	line.needs_area = text.contains("{area}")
	var at := 0
	for m in _pattern().search_all(text):
		var fill := FILL_NAMES.find(m.get_string(1))
		if fill < 0:
			continue
		if m.get_start() > at:
			_add_part(line, text.substr(at, m.get_start() - at), -1, false)
		_add_part(line, "", fill, _starts_sentence(text, m.get_start()))
		at = m.get_end()
	if at < text.length():
		_add_part(line, text.substr(at), -1, false)
	if not line.parts.is_empty() and line.fills[0] == -1:
		line.parts[0] = capital(line.parts[0])
	return line


static func _add_part(line: Line, part: String, fill: int, starts: bool) -> void:
	line.parts.append(part)
	line.fills.append(fill)
	line.starts.append(1 if starts else 0)


## Whether a sentence starts at `at` in `text`: its start, or after a stop and white space.
static func _starts_sentence(text: String, at: int) -> bool:
	var i := at - 1
	if i < 0:
		return true
	if text[i] != " " and text[i] != "\t":
		return false
	while i >= 0 and (text[i] == " " or text[i] == "\t"):
		i -= 1
	return i >= 0 and (text[i] == "." or text[i] == "!" or text[i] == "?")


static func _pattern() -> RegEx:
	if _fill_pattern == null:
		_fill_pattern = RegEx.create_from_string("\\{([^{}]*)\\}")
	return _fill_pattern


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


## The row of `table` (PACE_ROWS, MARK_ROWS, ASK_ROWS) whose first column is `cell`, or [].
static func _row_named(table: Array[Array], cell: String) -> Array:
	var key := _key_of(cell)
	for r in table:
		if (r[0] as String).to_lower() == key:
			return r
	return []


static func _names(table: Array[Array]) -> String:
	var out := PackedStringArray()
	for r in table:
		out.append(r[0])
	return ", ".join(out)


## A number as a message says it: 4, 1.5, 0.35.
static func _num_text(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)


## A first-column key: trimmed, lower case, curly apostrophes straight.
static func _key_of(cell: String) -> String:
	return cell.strip_edges().to_lower().replace("’", "'")


## A plain number (a minus typed as −), NAN for anything else (a % sign included).
static func _number(cell: String) -> float:
	return NAN if cell.ends_with("%") else DataTable.parse_number(cell)
