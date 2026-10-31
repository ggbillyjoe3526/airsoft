class_name MapCatalog
extends RefCounted
## Which maps there are and which are listed (data/maps.md, the browser game's map/maps.ts MAPS): each map's name,
## kind (a match field or the practice range), tag, team sizes and round length. A map tagged dev is listed only while the Dev
## settings' Dev content switch is on, and a match on one stays out of the records (docs/DECISIONS.md › Content tags and
## dev content). An unreadable row is left out with a warning; an unreadable team size keeps its built-in value with a
## warning, as does an unreadable round length; with no file at all, Depot alone is listed.

const PATH := "res://data/maps.md"
const FILE_NAME := "maps.md"
const TABLE := "Maps"
const KINDS: Array[StringName] = [&"field", &"range"]
const TAGS: Array[StringName] = [&"public", &"dev"]
## The team size columns, smallest, standard and largest (the browser game's teamSize min, standard and max).
const SIZE_COLUMNS: PackedStringArray = ["Min", "Standard", "Max"]
## The round length column (s), optional: a map without one plays the round tuning's (RoundConfig.round_time).
const ROUND_COLUMN := "Round"


class Entry:
	extends RefCounted
	var id: String = ""
	var display_name: String = ""
	var kind: StringName = &"field"
	var tag: StringName = &"public"
	var blurb: String = ""
	## Players a side it offers, from team_min to team_max, and the size it plays unless another is picked (Skirmish
	## always plays it). Built in: Depot's, the game's first field.
	var team_min: int = 1
	var team_standard: int = 3
	var team_max: int = 3
	## The round's length (s) a Skirmish here plays (WR2: Woodland 3:00), 0 for the round tuning's own. Custom plays
	## its own switch (CustomRules.round_time) wherever it is.
	var round_time: float = 0.0

	## Whether a match of `team_size` a side can be played here.
	func allows(team_size: int) -> bool:
		return team_size >= team_min and team_size <= team_max

	## The size played when `picked` is asked for: it where the map allows it, else the map's standard.
	func team_size_for(picked: int) -> int:
		return picked if allows(picked) else team_standard


## Every readable row, in the file's order.
var entries: Array[Entry] = []
## What couldn't be read, each "maps.md:line: …".
var problems: Array[String] = []

static var _shared: MapCatalog = null


## The catalogue as shipped, read once.
static func shared() -> MapCatalog:
	if _shared == null:
		_shared = read_file()
		for p in _shared.problems:
			push_warning("maps: %s" % p)
	return _shared


static func read_file(path: String = PATH) -> MapCatalog:
	if not FileAccess.file_exists(path):
		var built_in := MapCatalog.new()
		built_in.problems.append("%s can't be read: listing Depot only" % path)
		var depot := Entry.new()
		depot.id = "depot"
		depot.display_name = "Depot"
		built_in.entries.append(depot)
		return built_in
	return parse(FileAccess.get_file_as_string(path))


static func parse(text: String) -> MapCatalog:
	var m := MapCatalog.new()
	var tables := DataTable.read_all(text, FILE_NAME)
	var table := DataTable.find(tables, TABLE)
	if table == null:
		m.problems.append("%s: no \"%s\" table" % [FILE_NAME, TABLE])
		return m
	m.problems.append_array(table.problems)
	for row in table.rows:
		var e := Entry.new()
		e.id = row.key
		e.display_name = row.cell("Name")
		e.kind = StringName(row.cell("Kind"))
		e.tag = StringName(row.cell("Tag"))
		e.blurb = row.cell("Blurb")
		var at := "%s:%d" % [FILE_NAME, row.line]
		if e.id.is_empty() or e.display_name.is_empty():
			m.problems.append("%s: a map needs an Id and a Name" % at)
		elif not KINDS.has(e.kind):
			m.problems.append("%s: Kind \"%s\" is not field or range" % [at, e.kind])
		elif not TAGS.has(e.tag):
			m.problems.append("%s: Tag \"%s\" is not public or dev" % [at, e.tag])
		elif m.find(e.id) != null:
			m.problems.append("%s: %s is listed twice" % [at, e.id])
		else:
			_read_sizes(e, row, at, m.problems, table)
			_read_round(e, row, at, m.problems, table)
			m.entries.append(e)
	for column in SIZE_COLUMNS:
		if not table.has_column(column):
			m.problems.append("%s: no \"%s\" column: every map keeps its built-in team sizes" % [FILE_NAME, column])
	return m


## `e`'s team sizes from `row`: each a size the Match screen offers (CustomRules.TEAM_SIZES), else its built-in value
## kept with a problem; three that aren't smallest, standard, largest in order all keep their built-in values.
## A column the table lacks is reported once, not per row (parse).
static func _read_sizes(e: Entry, row: DataTable.Row, at: String, problems: Array[String], table: DataTable) -> void:
	var sizes := PackedInt32Array([e.team_min, e.team_standard, e.team_max])
	var built_in := sizes.duplicate()
	for i in SIZE_COLUMNS.size():
		if not table.has_column(SIZE_COLUMNS[i]):
			continue
		var raw := row.cell(SIZE_COLUMNS[i])
		if not raw.is_valid_int() or not CustomRules.TEAM_SIZES.has(raw.to_int()):
			problems.append("%s: %s \"%s\" is not a team size of %d to %d: %s keeps %d" % [at, SIZE_COLUMNS[i], raw,
					CustomRules.TEAM_SIZES[0], CustomRules.TEAM_SIZES[-1], e.id, sizes[i]])
			continue
		sizes[i] = raw.to_int()
	if sizes[0] > sizes[1] or sizes[1] > sizes[2]:
		problems.append("%s: team sizes %d, %d, %d are not smallest, standard, largest: %s keeps %d, %d, %d" % [at,
				sizes[0], sizes[1], sizes[2], e.id, built_in[0], built_in[1], built_in[2]])
		sizes = built_in
	e.team_min = sizes[0]
	e.team_standard = sizes[1]
	e.team_max = sizes[2]


## `e`'s round length from `row`'s Round cell: blank keeps the round tuning's; anything but a whole number of seconds the
## Match screen's Round time switch could pick (CustomRules.ROUND_TIME_RANGE, in ROUND_TIME_STEP steps) keeps it too,
## with a problem.
static func _read_round(e: MapCatalog.Entry, row: DataTable.Row, at: String, problems: Array[String],
		table: DataTable) -> void:
	if not table.has_column(ROUND_COLUMN):
		return
	var raw := row.cell(ROUND_COLUMN)
	if raw.is_empty():
		return
	var lo := CustomRules.ROUND_TIME_RANGE.x
	var hi := CustomRules.ROUND_TIME_RANGE.y
	var step := CustomRules.ROUND_TIME_STEP
	if not raw.is_valid_int() or raw.to_int() < lo or raw.to_int() > hi or fposmod(raw.to_int() - lo, step) != 0.0:
		problems.append("%s: Round \"%s\" is not %d to %d s in %d s steps: %s plays the round tuning's"
				% [at, raw, lo, hi, step, e.id])
		return
	e.round_time = float(raw.to_int())


## The entry for `map_id`, or null.
func find(map_id: String) -> Entry:
	for e in entries:
		if e.id == map_id:
			return e
	return null


## The match fields to offer: public ones, and dev ones too while `dev_content` is on.
func fields(dev_content: bool) -> Array[Entry]:
	var out: Array[Entry] = []
	for e in entries:
		if e.kind == &"field" and (dev_content or e.tag == &"public"):
			out.append(e)
	return out


## What the Match page lists: the fields (`fields`) and then the range, in the file's order within each.
func listed(dev_content: bool) -> Array[Entry]:
	var out := fields(dev_content)
	for e in entries:
		if e.kind != &"field" and (dev_content or e.tag == &"public"):
			out.append(e)
	return out


## Whether a match on `map_id` uses dev content: tagged dev, or not in the catalogue at all.
func is_dev(map_id: String) -> bool:
	var e := find(map_id)
	return e == null or e.tag == &"dev"
