class_name LevelTable
extends RefCounted
## The levels (owner, 2026-10-13): what each level unlocks, the XP it takes and what a match gives, read from
## data/levels.md against the pool (the browser game's progress/levels.ts). The owner edits that file by hand; its guide
## explains the columns. Never throws: what it can't read is left out and listed in `problems`, each "levels.md:line: …".

const PATH := "res://data/levels.md"
const FILE_NAME := "levels.md"
## The tables, by their first column's header.
const LEVELS_COLUMN := "Level"
const EVENTS_COLUMN := "Event"
const DIFFICULTY_COLUMN := "Difficulty"
## The most XP one cell may hold (a level's, or a match event's): far beyond any sane value, a typo guard.
const MAX_XP_CELL := 1000000
## The least a Difficulty multiplier may be: a 0 would give nothing at that difficulty, with no warning to say why.
const MIN_MULTIPLIER := 0.1
const MAX_MULTIPLIER := 100.0
## Level 0's XP cell may be left empty or hold a dash.
const NO_XP: PackedStringArray = ["", "0", "-", "–"]
## The Difficulty table's Custom row: the most a Custom match's multiplier may be (MatchXp).
const CUSTOM := &"custom"
## levels.md's XP numbers as shipped: used for any the file is missing.
const DEFAULT_EARN: Dictionary[StringName, int] = {
	&"match_played": 100, &"match_won": 100, &"round_won": 20, &"hit": 10,
}
const DEFAULT_MULTIPLIERS: Dictionary[StringName, float] = {&"easy": 0.5, &"normal": 1.0, &"hard": 1.5, CUSTOM: 1.5}
## The XP table's Event labels (lower case) and the earn key each one sets.
const EVENT_LABELS: Dictionary[String, StringName] = {
	"match played": &"match_played", "match won": &"match_won", "round won": &"round_won",
	"hit on an opponent": &"hit",
}


## One level: the XP it takes on top of the level before (0 for level 0), the running total from nothing, and the pool
## IDs it unlocks in the order its row names them.
class Level:
	extends RefCounted
	var number: int = 0
	var xp: int = 0
	var total: int = 0
	var unlocks: PackedStringArray = PackedStringArray()


## Where an XP total stands: its level, the XP past that level's total (0 at the cap: XP stops there), and what the
## next level takes on top of this one (0 at the cap).
class Standing:
	extends RefCounted
	var level: int = 0
	var into: int = 0
	var next: int = 0

	func at_cap() -> bool:
		return next == 0


## By number, from 0 to the cap: never empty.
var levels: Array[Level] = []
## XP for each event (DEFAULT_EARN's keys) and each difficulty's multiplier (MatchOptions.BOT_LEVELS).
var earn: Dictionary[StringName, int] = DEFAULT_EARN.duplicate()
var multipliers: Dictionary[StringName, float] = DEFAULT_MULTIPLIERS.duplicate()
var problems: Array[String] = []
## No readable level 0: level 0 stands in with every item, for this session alone (Progress neither grants nor saves
## those unlocks, so a fixed levels.md finds the player's own list as it was).
var everything_unlocked: bool = false
## The level each item unlocks at, by pool ID. An item no row names is absent: no level unlocks it.
var _unlock_level: Dictionary[String, int] = {}

static var _shared: LevelTable = null


## The levels as shipped, read once against the shared pool.
static func shared() -> LevelTable:
	if _shared == null:
		_shared = read_file(Pool.shared())
		for p in _shared.problems:
			push_warning("levels: %s" % p)
	return _shared


static func read_file(pool: Pool, path: String = PATH) -> LevelTable:
	if not FileAccess.file_exists(path):
		var none := parse("", pool)
		none.problems.push_front("%s can't be read" % path)
		return none
	return parse(FileAccess.get_file_as_string(path), pool)


static func parse(text: String, pool: Pool) -> LevelTable:
	var t := LevelTable.new()
	var tables := DataTable.read_all(text, FILE_NAME)
	for table in tables:
		t.problems.append_array(table.problems)
	t._read_earn(_first_column(tables, EVENTS_COLUMN))
	t._read_multipliers(_first_column(tables, DIFFICULTY_COLUMN))
	var named := t._read_levels(_first_column(tables, LEVELS_COLUMN), pool)
	if t.levels.is_empty():
		# Nothing to go on: everything from the start, rather than nothing at all.
		t.problems.append("%s: no readable level 0: every item is unlocked from the start" % FILE_NAME)
		var all := Level.new()
		for it in _items(pool):
			all.unlocks.append(it.id)
		t.levels.append(all)
		t.everything_unlocked = true
	for l in t.levels:
		for id in l.unlocks:
			t._unlock_level[id] = l.number
	for it in _items(pool):
		if not named.has(it.id):
			t.problems.append("%s: no level unlocks the %s (pool.md ID %s): add its Name to a level's Unlocks"
					% [FILE_NAME, it.display_name, it.id])
	return t


## The top level.
func cap() -> int:
	return levels.size() - 1


## The level `id` unlocks at, or -1 if no level does.
func unlock_level(id: String) -> int:
	return _unlock_level.get(id, -1)


## The level `xp` reaches, never past the cap.
func level_of(xp: int) -> int:
	var reached := 0
	for l in levels:
		if xp >= l.total:
			reached = l.number
	return reached


func standing(xp: int) -> Standing:
	var s := Standing.new()
	s.level = level_of(xp)
	if s.level < cap():
		s.into = xp - levels[s.level].total
		s.next = levels[s.level + 1].xp
	return s


## Every item the levels up to `level` unlock, lowest level first.
func unlocks_up_to(level: int) -> PackedStringArray:
	var out := PackedStringArray()
	for l in levels:
		if l.number <= level:
			out.append_array(l.unlocks)
	return out


## A difficulty's multiplier (1 for one the table doesn't know).
func multiplier(difficulty: StringName) -> float:
	return multipliers.get(difficulty, 1.0)


## The Levels table, in order: each row the next level, from 0. The first row that can't be read ends it (the levels
## from there up are left out, so the numbers never skip); a name it can't place is left out of its row alone. Returns
## every pool ID some row names, read or not.
func _read_levels(t: DataTable, pool: Pool) -> Dictionary[String, bool]:
	var named: Dictionary[String, bool] = {}
	if t == null:
		problems.append("%s: no Levels table" % FILE_NAME)
		return named
	var stopped := false
	for row in t.rows:
		var names := DataTable.names(row.cell("Unlocks"))
		for n in names:
			var found := pool.named(n)
			if found != null:
				named[found.id] = true
		if stopped:
			continue
		var number := levels.size()
		if row.cell(LEVELS_COLUMN) != str(number):
			problems.append("%s: Level must be %d here (levels count up from 0 with no gaps), not \"%s\": the levels from here up are left out"
					% [t.where(row.line), number, row.cell(LEVELS_COLUMN)])
			stopped = true
			continue
		var xp := _level_xp(t, row, number)
		if xp < 0:
			stopped = true
			continue
		var l := Level.new()
		l.number = number
		l.xp = xp
		l.total = xp + (levels[number - 1].total if number > 0 else 0)
		for n in names:
			var it := pool.named(n)
			if it == null:
				problems.append("%s: \"%s\" isn't a Name or ID in pool.md" % [t.where(row.line), n])
				continue
			var at := _placed_at(it.id)
			if at >= 0 or l.unlocks.has(it.id):
				problems.append("%s: the %s is already unlocked at level %d"
						% [t.where(row.line), it.display_name, at if at >= 0 else number])
				continue
			l.unlocks.append(it.id)
		levels.append(l)
	return named


## A level's XP cell: none for level 0, else a whole number from 1; -1 (and a problem) otherwise.
func _level_xp(t: DataTable, row: DataTable.Row, number: int) -> int:
	var raw := row.cell("XP").replace(",", "").strip_edges()
	if number == 0:
		if NO_XP.has(raw):
			return 0
		problems.append("%s: level 0 is the starting kit and takes no XP, not \"%s\"" % [t.where(row.line), raw])
		return -1
	if raw.is_valid_int() and int(raw) >= 1 and int(raw) <= MAX_XP_CELL:
		return int(raw)
	problems.append("%s: XP must be a whole number from 1 to %d, not \"%s\": the levels from here up are left out"
			% [t.where(row.line), MAX_XP_CELL, raw])
	return -1


func _read_earn(t: DataTable) -> void:
	if t == null:
		problems.append("%s: no XP table (Event, XP): using the built-in numbers" % FILE_NAME)
		return
	var seen: Dictionary[StringName, bool] = {}
	for row in t.rows:
		var key: StringName = EVENT_LABELS.get(row.cell(EVENTS_COLUMN).to_lower(), &"")
		if key == &"":
			problems.append("%s: \"%s\" isn't one of %s" % [t.where(row.line), row.cell(EVENTS_COLUMN),
					", ".join(EVENT_LABELS.keys())])
			continue
		if seen.has(key):
			problems.append("%s: \"%s\" is listed twice" % [t.where(row.line), row.cell(EVENTS_COLUMN)])
			continue
		seen[key] = true
		var v := DataTable.parse_number(row.cell("XP").replace(",", ""))
		if is_nan(v) or v < 0.0 or v > MAX_XP_CELL or v != roundf(v):
			problems.append("%s: XP must be a whole number from 0 to %d, not \"%s\"" % [t.where(row.line),
					MAX_XP_CELL, row.cell("XP")])
			continue
		earn[key] = int(v)
	for label: String in EVENT_LABELS:
		if not seen.has(EVENT_LABELS[label]):
			problems.append("%s: the XP table has no %s row: using the built-in number" % [FILE_NAME, label])


func _read_multipliers(t: DataTable) -> void:
	if t == null:
		problems.append("%s: no Difficulty table: using the built-in multipliers" % FILE_NAME)
		return
	var seen: Dictionary[StringName, bool] = {}
	for row in t.rows:
		var key := StringName(row.cell(DIFFICULTY_COLUMN).to_lower())
		if not DEFAULT_MULTIPLIERS.has(key):
			problems.append("%s: \"%s\" isn't a difficulty (Easy, Normal, Hard or Custom)" % [t.where(row.line),
					row.cell(DIFFICULTY_COLUMN)])
			continue
		if seen.has(key):
			problems.append("%s: \"%s\" is listed twice" % [t.where(row.line), row.cell(DIFFICULTY_COLUMN)])
			continue
		seen[key] = true
		var v := DataTable.parse_number(row.cell("Multiplier"))
		if is_nan(v) or v < MIN_MULTIPLIER or v > MAX_MULTIPLIER:
			problems.append("%s: Multiplier must be a number from %s to %s, not \"%s\"" % [t.where(row.line),
					MIN_MULTIPLIER, MAX_MULTIPLIER, row.cell("Multiplier")])
			continue
		multipliers[key] = v
	for key: StringName in DEFAULT_MULTIPLIERS:
		if not seen.has(key):
			problems.append("%s: the Difficulty table has no %s row: using the built-in number" % [FILE_NAME, key])


func _placed_at(id: String) -> int:
	for l in levels:
		if l.unlocks.has(id):
			return l.number
	return -1


## The first table whose first column is `header`, or null.
static func _first_column(tables: Array[DataTable], header: String) -> DataTable:
	for t in tables:
		if not t.headers.is_empty() and t.headers[0] == header:
			return t
	return null


static func _items(pool: Pool) -> Array[Pool.Item]:
	var out: Array[Pool.Item] = []
	out.append_array(pool.replicas)
	out.append_array(pool.powers)
	out.append_array(pool.parts)
	out.append_array(pool.waiting)
	return out
