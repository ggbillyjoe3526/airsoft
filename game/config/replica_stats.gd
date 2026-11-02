class_name ReplicaStats
extends RefCounted
## data/stats.md's replica numbers and site limits (the browser game's config/statsFile.ts and withStats): the file is
## what plays, and the built-in replicas (game/config/replicas/<id>.tres) only fill in where it can't be read. A cell
## that won't read or is out of range keeps the built-in number and is reported with its line ("stats.md:55: …").

const PATH := "res://data/stats.md"
const FILE_NAME := "stats.md"
const REPLICA_DIR := "res://game/config/replicas/"
## The loadout bots and tests carry and a new player starts with: primary, then secondary.
const DEFAULT_LOADOUT: Array[StringName] = [&"aeg", &"pistol"]
const REPLICAS_TABLE := "Replicas"
const LIMITS_TABLE := "Site limits"
const POWER_TABLE := "Power sources"
## A power source's percentage columns (stats.md › Power sources) and the range each cell must fall in.
const POWER_COLUMNS: Array[String] = ["Energy %", "Fire rate %", "Recoil %"]
const POWER_PERCENT_MIN := -90.0
const POWER_PERCENT_MAX := 200.0
const KEY_HEADER := "Key"
const CLASS_HEADER := "Class"
const LIMIT_HEADER := "Limit (J)"
## The Limit (J) column's range, and the limits as shipped (J) when the table can't be read.
const LIMIT_MIN := 0.1
const LIMIT_MAX := 10.0
const DEFAULT_SITE_LIMITS: Dictionary[StringName, float] = {&"rifle": 1.2, &"pistol": 1.0, &"sniper": 2.3}

enum Kind { NUMBER, WHOLE, WORD }

## The Replicas table's columns (statsFile.ts REPLICA_COLUMNS): the ReplicaConfig property each sets, how it is read and
## the range a number must fall in. An optional column (added after the browser game's) may be left out quietly: every
## replica then keeps its built-in number.
const COLUMNS: Array[Dictionary] = [
	{"header": "Class", "field": &"site_class", "kind": Kind.WORD},
	{"header": "Energy (J)", "field": &"muzzle_energy", "kind": Kind.NUMBER, "min": 0.05, "max": 5.0},
	{"header": "BB (g)", "field": &"bb_weight", "kind": Kind.NUMBER, "min": 0.1, "max": 0.5},
	{"header": "Fire rate (BBs/s)", "field": &"fire_rate", "kind": Kind.NUMBER, "min": 0.5, "max": 50.0},
	{"header": "Magazine (BBs)", "field": &"mag_size", "kind": Kind.WHOLE, "min": 1.0, "max": 1000.0},
	{"header": "Magazines", "field": &"mags", "kind": Kind.WHOLE, "min": 1.0, "max": 20.0},
	{"header": "Reload (s)", "field": &"reload_time", "kind": Kind.NUMBER, "min": 0.1, "max": 10.0},
	{"header": "Draw (s)", "field": &"draw_time", "kind": Kind.NUMBER, "min": 0.05, "max": 5.0},
	{"header": "Spread (°)", "field": &"spread_deg", "kind": Kind.NUMBER, "min": 0.0, "max": 10.0},
	{"header": "Recoil (°)", "field": &"recoil_deg", "kind": Kind.NUMBER, "min": 0.0, "max": 5.0},
	{"header": "Hip spread (×)", "field": &"hip_spread", "kind": Kind.NUMBER, "min": 1.0, "max": 20.0, "optional": true},
]

## What a power source changes, as shares (0.15 is +15 %): energy (gas, spring), rate of fire (battery) and kick.
class Power:
	extends RefCounted
	var energy: float = 0.0
	var fire_rate: float = 0.0
	var recoil: float = 0.0


## Each replica Key's readable cells: ReplicaConfig property → value.
var replicas: Dictionary[String, Dictionary] = {}
## Energy limit (J) by site class.
var site_limits: Dictionary[StringName, float] = {}
## Each power source's row by its pool.md ID; a source with no row (or no table) changes nothing.
var powers: Dictionary[String, Power] = {}
## The part tables (optics, grips, lasers, magazines, barrels, muzzle parts).
var parts: PartStats = PartStats.new()
## What couldn't be read, each "stats.md:line: …".
var problems: Array[String] = []


## Reads stats.md's `text`. Never fails: what it can't read is left out (the built-in number stays) and listed.
static func parse(text: String) -> ReplicaStats:
	var s := ReplicaStats.new()
	var tables := DataTable.read_all(text, FILE_NAME)
	for t in tables:
		if t.heading == REPLICAS_TABLE or t.heading == LIMITS_TABLE or t.heading == POWER_TABLE:
			s.problems.append_array(t.problems)
	s._read_replicas(DataTable.find(tables, REPLICAS_TABLE))
	s._read_limits(DataTable.find(tables, LIMITS_TABLE))
	s._read_powers(DataTable.find(tables, POWER_TABLE))
	s.parts = PartStats.read(tables)
	s.problems.append_array(s.parts.problems)
	return s


## stats.md as shipped (PATH), or no numbers and one problem if it can't be read.
static func read_file(path: String = PATH) -> ReplicaStats:
	if not FileAccess.file_exists(path):
		var none := ReplicaStats.new()
		none.site_limits = DEFAULT_SITE_LIMITS.duplicate()
		none.problems.append("%s can't be read: using the built-in numbers" % path)
		return none
	return parse(FileAccess.get_file_as_string(path))


## `base` with stats.md's `text` laid over it (a duplicate; `base` is left alone), warning about what it couldn't read.
static func apply(base: ReplicaConfig, text: String) -> ReplicaConfig:
	var s := parse(text)
	s.warn()
	return s.overlay(base)


## The built-in replica `id` with stats.md's row laid over it, or null (and an error) if there is no such replica.
static func load_replica(id: StringName) -> ReplicaConfig:
	var s := read_file()
	s.warn()
	return _built_in_with(id, s)


## The default loadout (DEFAULT_LOADOUT), each through stats.md, the file read once.
static func default_loadout() -> Array[ReplicaConfig]:
	var s := read_file()
	s.warn()
	var out: Array[ReplicaConfig] = []
	for id in DEFAULT_LOADOUT:
		var r := _built_in_with(id, s)
		if r != null:
			out.append(r)
	return out


## A duplicate of `base` with its row's readable numbers; a replica the file has no row for keeps every built-in number.
func overlay(base: ReplicaConfig) -> ReplicaConfig:
	var r := base.duplicate() as ReplicaConfig
	var fields: Dictionary = replicas.get(String(base.id), {})
	for field: StringName in fields:
		r.set(field, fields[field])
	return r


## The built-in replica `key` with its row laid over it, or null (quietly) if the game has no built-in config for it:
## a replica the pool lists but the game can't play yet.
func replica_config(key: StringName) -> ReplicaConfig:
	var path := "%s%s.tres" % [REPLICA_DIR, key]
	if not ResourceLoader.exists(path):
		return null
	var base := load(path) as ReplicaConfig
	return overlay(base) if base != null else null


## What the power source `id` changes; nothing for a source with no row.
func power(id: String) -> Power:
	return powers.get(id, Power.new())


## The energy limit (J) of `site_class`: unlimited if the file and the built-in limits name none.
func energy_limit(site_class: StringName) -> float:
	var fallback: float = DEFAULT_SITE_LIMITS.get(site_class, INF)
	var limit: float = site_limits.get(site_class, fallback)
	return limit


## Each problem as a warning.
func warn() -> void:
	for p in problems:
		push_warning("ReplicaStats: " + p)


static func _built_in_with(id: StringName, s: ReplicaStats) -> ReplicaConfig:
	var path := "%s%s.tres" % [REPLICA_DIR, id]
	var base := load(path) as ReplicaConfig
	if base == null:
		push_error("ReplicaStats: no built-in replica at %s" % path)
		return null
	return s.overlay(base)


func _read_replicas(t: DataTable) -> void:
	if t == null:
		problems.append("%s: no \"%s\" table: using the built-in numbers" % [FILE_NAME, REPLICAS_TABLE])
		return
	for col in COLUMNS:
		if not t.has_column(col["header"]) and not col.get("optional", false):
			problems.append("%s: the %s table has no \"%s\" column: using the built-in numbers" % [t.where(t.line),
					REPLICAS_TABLE, col["header"]])
	for row in t.rows:
		var key := row.cell(KEY_HEADER)
		if not _is_key(key):
			problems.append("%s: Key must be a Key as in pool.md's Key column, not \"%s\"" % [t.where(row.line), key])
			continue
		if replicas.has(key):
			problems.append("%s: %s is listed twice in %s" % [t.where(row.line), key, REPLICAS_TABLE])
			continue
		var fields: Dictionary = {}
		for col in COLUMNS:
			var header: String = col["header"]
			if not t.has_column(header):
				continue
			var raw := row.cell(header)
			var where := t.where(row.line)
			match col["kind"]:
				Kind.WORD:
					if _is_class(raw):
						fields[col["field"]] = StringName(raw)
					else:
						problems.append("%s: %s must be a lower case word, not \"%s\"" % [where, header, raw])
				_:
					var v := DataTable.parse_number(raw)
					var lo: float = col["min"]
					var hi: float = col["max"]
					var whole: bool = col["kind"] == Kind.WHOLE
					if is_nan(v) or v < lo or v > hi or (whole and v != floorf(v)):
						problems.append("%s: %s must be a %s from %s to %s, not \"%s\"" % [where, header,
								"whole number" if whole else "number", _shown(lo), _shown(hi), raw])
					elif whole:
						fields[col["field"]] = int(v)
					else:
						fields[col["field"]] = v
		replicas[key] = fields


func _read_limits(t: DataTable) -> void:
	if t == null:
		problems.append("%s: no \"%s\" table: using the built-in limits" % [FILE_NAME, LIMITS_TABLE])
		site_limits = DEFAULT_SITE_LIMITS.duplicate()
		return
	for row in t.rows:
		var c := row.cell(CLASS_HEADER).to_lower()
		if not _is_class(c):
			problems.append("%s: Class must be a lower case word, not \"%s\"" % [t.where(row.line), row.cell(CLASS_HEADER)])
			continue
		if site_limits.has(StringName(c)):
			problems.append("%s: class %s is listed twice" % [t.where(row.line), c])
			continue
		var raw := row.cell(LIMIT_HEADER)
		var v := DataTable.parse_number(raw)
		if is_nan(v) or v < LIMIT_MIN or v > LIMIT_MAX:
			problems.append("%s: %s must be a number from %s to %s, not \"%s\"" % [t.where(row.line), LIMIT_HEADER,
					_shown(LIMIT_MIN), _shown(LIMIT_MAX), raw])
			continue
		site_limits[StringName(c)] = v


func _read_powers(t: DataTable) -> void:
	# No table: every power source changes nothing, as the Standard Battery doesn't (quiet; the rest of the file reads).
	if t == null:
		return
	for row in t.rows:
		var id := row.key
		if powers.has(id):
			problems.append("%s: power source %s is listed twice" % [t.where(row.line), id])
			continue
		var shares := PackedFloat64Array()
		for header in POWER_COLUMNS:
			var raw := row.cell(header)
			var v := DataTable.parse_number(raw)
			if is_nan(v) or v < POWER_PERCENT_MIN or v > POWER_PERCENT_MAX:
				problems.append("%s: %s must be a number from %s to %s, not \"%s\": counted as 0" % [
						t.where(row.line), header, _shown(POWER_PERCENT_MIN), _shown(POWER_PERCENT_MAX), raw])
				v = 0.0
			shares.append(v / 100.0)
		var p := Power.new()
		p.energy = shares[0]
		p.fire_rate = shares[1]
		p.recoil = shares[2]
		powers[id] = p


## A Key: a letter, then letters and digits (statsFile.ts KEY_PATTERN).
static func _is_key(text: String) -> bool:
	if text == "" or not _is_letter(text[0]):
		return false
	for ch in text:
		if not (_is_letter(ch) or (ch >= "0" and ch <= "9")):
			return false
	return true


## A site class: lower case words joined by single hyphens (statsFile.ts CLASS_PATTERN).
static func _is_class(text: String) -> bool:
	if text == "":
		return false
	for part in text.split("-"):
		if part == "":
			return false
		for ch in part:
			if ch < "a" or ch > "z":
				return false
	return true


static func _is_letter(ch: String) -> bool:
	return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z")


## `v` as the file would have it: 20, not 20.0.
static func _shown(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)
