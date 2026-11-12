class_name PartStats
extends RefCounted
## data/stats.md's part tables (the browser game's config/optics.ts, lasers.ts and attachments.ts over its stats file):
## what each optic, grip, laser, magazine, barrel and muzzle part changes, and how far and wide each light shines, by
## its Key. A part with no row, or a cell that won't read or is out of range, changes nothing there and is reported with
## its line ("stats.md:80: …").

const KEY_HEADER := "Key"
const RATTLES_YES := "yes"
const RATTLES_NO := "no"

enum Kind { SCALE, ADD, PERCENT, YES_NO }

## Each part table: its slot (Pool.PART_TABLES), and its columns with the Part field each sets, how it reads and the
## range a number must fall in. A percentage is stored as a share (10 % is 0.1).
const TABLES: Array[Dictionary] = [
	{"heading": "Optics", "slot": &"optic", "columns": [
		{"header": "Zoom (×)", "field": &"zoom", "kind": Kind.SCALE, "min": 1.0, "max": 8.0},
		{"header": "Raise time (×)", "field": &"raise", "kind": Kind.SCALE, "min": 0.2, "max": 5.0},
		{"header": "In the glass", "field": &"in_glass", "kind": Kind.YES_NO},
		{"header": "Zoom to (×)", "field": &"zoom_to", "kind": Kind.SCALE, "min": 1.0, "max": 8.0},
	]},
	{"heading": "Grips", "slot": &"grip", "columns": [
		{"header": "Handling (×)", "field": &"handling", "kind": Kind.SCALE, "min": 0.2, "max": 5.0},
		{"header": "Shake (×)", "field": &"shake", "kind": Kind.SCALE, "min": 0.0, "max": 5.0},
		{"header": "Moving spread (×)", "field": &"move_spread", "kind": Kind.SCALE, "min": 0.2, "max": 2.0},
	]},
	{"heading": "Lasers", "slot": &"laser", "columns": [
		{"header": "Hip spread (×)", "field": &"hip", "kind": Kind.SCALE, "min": 0.1, "max": 5.0},
		{"header": "Handling (×)", "field": &"handling", "kind": Kind.SCALE, "min": 0.2, "max": 5.0},
	]},
	{"heading": "Magazines", "slot": &"magazine", "columns": [
		{"header": "Capacity (×)", "field": &"capacity", "kind": Kind.SCALE, "min": 0.1, "max": 10.0},
		{"header": "Carried (+)", "field": &"carried", "kind": Kind.ADD, "min": -10.0, "max": 10.0},
		{"header": "Reload (×)", "field": &"reload", "kind": Kind.SCALE, "min": 0.2, "max": 5.0},
		{"header": "Draw (×)", "field": &"draw", "kind": Kind.SCALE, "min": 0.2, "max": 5.0},
		{"header": "Rattles", "field": &"rattles", "kind": Kind.YES_NO},
	]},
	{"heading": "Barrels", "slot": &"barrel", "columns": [
		{"header": "Energy %", "field": &"energy", "kind": Kind.PERCENT, "min": -50.0, "max": 50.0},
		{"header": "Spread (×)", "field": &"spread", "kind": Kind.SCALE, "min": 0.1, "max": 5.0},
		{"header": "Handling (×)", "field": &"handling", "kind": Kind.SCALE, "min": 0.2, "max": 5.0},
	]},
	{"heading": "Muzzle parts", "slot": &"muzzle", "columns": [
		{"header": "Energy %", "field": &"energy", "kind": Kind.PERCENT, "min": -50.0, "max": 50.0},
		{"header": "Handling (×)", "field": &"handling", "kind": Kind.SCALE, "min": 0.2, "max": 5.0},
		{"header": "Heard from (×)", "field": &"heard", "kind": Kind.SCALE, "min": 0.0, "max": 5.0},
	]},
	{"heading": "Lights", "slot": &"light", "columns": [
		{"header": "Reach (m)", "field": &"reach", "kind": Kind.SCALE, "min": 1.0, "max": 200.0},
		{"header": "Beam (°)", "field": &"beam", "kind": Kind.SCALE, "min": 1.0, "max": 120.0},
		{"header": "Spill (°)", "field": &"spill", "kind": Kind.SCALE, "min": 1.0, "max": 170.0},
	]},
]


## What one part changes; every field starts as "nothing".
class Part:
	extends RefCounted
	## Aiming through it narrows the view this much (1: no zoom of its own), over this share of the raise time.
	var zoom: float = 1.0
	var raise: float = 1.0
	## Only the view inside its glass is zoomed (a scope); the rest stays as the iron sights'.
	var in_glass: bool = false
	## A variable optic's top zoom (SN2): its zoom turns from `zoom` up to this. At or below `zoom` (0 with no row): fixed.
	var zoom_to: float = 0.0
	## The time to bring the replica up and raise a sight; how long a sprint's or landing's shake stays in the aim.
	var handling: float = 1.0
	var shake: float = 1.0
	## A barrel's share of the spread; a laser's of the spread with the sight down (on top of the replica's own hip
	## spread, RP1); a grip's of the spread that moving adds (on top of the replica's own).
	var spread: float = 1.0
	var hip: float = 1.0
	var move_spread: float = 1.0
	## A magazine's capacity, magazines added to those carried, and its reload and draw times.
	var capacity: float = 1.0
	var carried: int = 0
	var reload: float = 1.0
	var draw: float = 1.0
	var rattles: bool = false
	## Energy as a share (0.1 is +10 %), and how far its shots are heard.
	var energy: float = 0.0
	var heard: float = 1.0
	## A light's reach (m) and its hotspot's and spill's full angles (degrees); 0: it lights nothing.
	var reach: float = 0.0
	var beam: float = 0.0
	var spill: float = 0.0


## Each slot's rows: slot → Key → Part.
var parts: Dictionary[StringName, Dictionary] = {}
var problems: Array[String] = []

## The part tables among `tables`. Never fails: a missing table offers nothing to change (quiet; pool.md decides what
## exists), and an unreadable cell keeps "nothing" and is listed.
static func read(tables: Array[DataTable]) -> PartStats:
	var s := PartStats.new()
	for spec: Dictionary in TABLES:
		var rows: Dictionary = {}
		s.parts[spec["slot"]] = rows
		var t := DataTable.find(tables, spec["heading"])
		if t != null:
			s.problems.append_array(t.problems)
			s._read(t, spec, rows)
	return s


## What the part `key` in `slot` changes; nothing for one with no row.
func part(slot: StringName, key: StringName) -> Part:
	var rows: Dictionary = parts.get(slot, {})
	return rows.get(String(key)) if rows.has(String(key)) else Part.new()


## True if the part `key` in `slot` has a row.
func has(slot: StringName, key: StringName) -> bool:
	var rows: Dictionary = parts.get(slot, {})
	return rows.has(String(key))


func _read(t: DataTable, spec: Dictionary, rows: Dictionary) -> void:
	for col: Dictionary in spec["columns"]:
		if not t.has_column(col["header"]):
			problems.append("%s: the %s table has no \"%s\" column: it changes nothing" % [t.where(t.line),
					spec["heading"], col["header"]])
	for row in t.rows:
		var key := row.cell(KEY_HEADER)
		var where := t.where(row.line)
		if key == "":
			problems.append("%s: a row with no Key" % where)
			continue
		if rows.has(key):
			problems.append("%s: %s is listed twice in %s" % [where, key, spec["heading"]])
			continue
		var p := Part.new()
		for col: Dictionary in spec["columns"]:
			var header: String = col["header"]
			if not t.has_column(header):
				continue
			var raw := row.cell(header)
			if col["kind"] == Kind.YES_NO:
				var word := raw.to_lower()
				if word == RATTLES_YES or word == RATTLES_NO:
					p.set(col["field"], word == RATTLES_YES)
				else:
					problems.append("%s: %s must be yes or no, not \"%s\"" % [where, header, raw])
				continue
			var v := DataTable.parse_number(raw)
			var lo: float = col["min"]
			var hi: float = col["max"]
			var whole: bool = col["kind"] == Kind.ADD
			if is_nan(v) or v < lo or v > hi or (whole and v != floorf(v)):
				problems.append("%s: %s must be a %s from %s to %s, not \"%s\": it changes nothing" % [where,
						header, "whole number" if whole else "number", _shown(lo), _shown(hi), raw])
				continue
			match col["kind"]:
				Kind.ADD:
					p.set(col["field"], int(v))
				Kind.PERCENT:
					p.set(col["field"], v / 100.0)
				_:
					p.set(col["field"], v)
		rows[key] = p


## `v` as the file would have it: 20, not 20.0.
static func _shown(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)
