class_name Pool
extends RefCounted
## The game's items (data/pool.md, the browser game's pool/poolFile.ts): each replica, power source and part with its
## ID, name, Key, Tags, Type, Fits and Access. What goes with what is by tags (pool.md › Tags and Fits): a part fits a
## replica that has any one of the tags in its Fits, or whose ID it names. An unreadable row is left out with a
## warning; a blank Access reads as public and any other word leaves the row out. Plain data, no engine state.

const PATH := "res://data/pool.md"
const FILE_NAME := "pool.md"
const REPLICAS_TABLE := "Replicas"
const POWER_TABLE := "Power sources"
## The Replicas table's optional column of parts fitted as it comes.
const COMES_WITH := "Comes with"
const ACCESS: Array[StringName] = [&"public", &"dev"]
const POWER_TYPES: Array[StringName] = [&"battery", &"gas", &"spring"]
## The part tables and the loadout slot each fills (a replica's standard magazine, barrel and iron sights are built in;
## these are the alternatives). A light (the weapon torch, WL7) is fitted only on a night field (Kit.lights_for).
const PART_TABLES: Dictionary[String, StringName] = {
	"Optics": &"optic", "Grips": &"grip", "Lasers": &"laser", "Magazines": &"magazine", "Barrels": &"barrel",
	"Muzzle parts": &"muzzle", "Lights": &"light",
}
## The slot of a weapon light: never part of a bot kit (every bot carries one on a night field by rule, BotKits).
const LIGHT_SLOT := &"light"
## The tables read but not offered yet, and the slot each will fill (none now: the Lights came into play in WL7).
const WAITING_TABLES: Dictionary[String, StringName] = {}
## A replica tag that means its power source is built in: nothing fits its power slot and it needs nothing.
const BUILT_IN_POWER := "built-in-power"
## Six digits, as pool.md › Identifiers has them.
const ID_LENGTH := 6

enum Kind { REPLICA, POWER, PART }


class Item:
	extends RefCounted
	var id: String = ""
	var kind: Kind = Kind.REPLICA
	var display_name: String = ""
	## A replica's or part's Key (stats.md's row, and a replica's built-in config); "" for a power source.
	var key: StringName = &""
	## A part's slot (PART_TABLES); "" for the rest.
	var slot: StringName = &""
	var tags: PackedStringArray = PackedStringArray()
	## A power source's Type, and what a power source or part fits (tags, or replica IDs).
	var type: StringName = &""
	var fits: PackedStringArray = PackedStringArray()
	var access: StringName = &"public"
	## A replica's parts as it comes (pool.md › Comes with): their Names as written, fitted by LoadoutRules.default_tune.
	var comes_with: PackedStringArray = PackedStringArray()

	func is_dev() -> bool:
		return access == &"dev"

	func has_built_in_power() -> bool:
		return tags.has(BUILT_IN_POWER)


## Every readable row of each table, in the file's order.
var replicas: Array[Item] = []
var powers: Array[Item] = []
var parts: Array[Item] = []
## Items read but not in play yet (WAITING_TABLES): levels.md still names them, nothing offers them.
var waiting: Array[Item] = []
## What couldn't be read, each "pool.md:line: …".
var problems: Array[String] = []

static var _shared: Pool = null


## The pool as shipped, read once.
static func shared() -> Pool:
	if _shared == null:
		_shared = read_file()
		for p in _shared.problems:
			push_warning("pool: %s" % p)
	return _shared


static func read_file(path: String = PATH) -> Pool:
	if not FileAccess.file_exists(path):
		var none := Pool.new()
		none.problems.append("%s can't be read: no items" % path)
		return none
	return parse(FileAccess.get_file_as_string(path))


static func parse(text: String) -> Pool:
	var p := Pool.new()
	var tables := DataTable.read_all(text, FILE_NAME)
	p._read(DataTable.find(tables, REPLICAS_TABLE), Kind.REPLICA, p.replicas)
	p._read(DataTable.find(tables, POWER_TABLE), Kind.POWER, p.powers)
	for heading: String in PART_TABLES:
		# A part table that isn't there offers no parts of its kind (quiet: the rest of the file reads).
		var t := DataTable.find(tables, heading)
		if t != null:
			p._read(t, Kind.PART, p.parts, PART_TABLES[heading])
	for heading: String in WAITING_TABLES:
		var t := DataTable.find(tables, heading)
		if t != null:
			p._read(t, Kind.PART, p.waiting, WAITING_TABLES[heading])
	return p


## The item with `id`, or null.
func item(id: String) -> Item:
	for list: Array[Item] in [replicas, powers, parts]:
		for it in list:
			if it.id == id:
				return it
	return null


## The item named `item_name` (its Name, any case) or with that ID, waiting ones included; the first of two sharing a
## Name; null if none.
func named(item_name: String) -> Item:
	var lower := item_name.to_lower()
	for list: Array[Item] in [replicas, powers, parts, waiting]:
		for it in list:
			if it.id == item_name:
				return it
	for list: Array[Item] in [replicas, powers, parts, waiting]:
		for it in list:
			if it.display_name.to_lower() == lower:
				return it
	return null


## The replica whose Key is `key`, or null.
func replica_by_key(key: StringName) -> Item:
	for it in replicas:
		if it.key == key:
			return it
	return null


## True if `part` goes on `replica`: one of its Fits is a tag of the replica, or the replica's ID. Nothing fits the
## power slot of a replica with its power built in.
func fits(part: Item, replica: Item) -> bool:
	if part.kind == Kind.POWER and replica.has_built_in_power():
		return false
	for f in part.fits:
		if f == replica.id or replica.tags.has(f):
			return true
	return false


## The parts for `slot` that fit `replica`, in the file's order (dev ones only while `dev_content`).
func parts_for(replica: Item, slot: StringName, dev_content: bool) -> Array[Item]:
	var out: Array[Item] = []
	for pt in parts:
		if pt.slot == slot and (dev_content or not pt.is_dev()) and fits(pt, replica):
			out.append(pt)
	return out


## The power sources that fit `replica`, in the file's order (dev ones only while `dev_content`).
func powers_for(replica: Item, dev_content: bool) -> Array[Item]:
	var out: Array[Item] = []
	for pw in powers:
		if (dev_content or not pw.is_dev()) and fits(pw, replica):
			out.append(pw)
	return out


func _read(t: DataTable, kind: Kind, into: Array[Item], slot: StringName = &"") -> void:
	var table_name := REPLICAS_TABLE if kind == Kind.REPLICA else POWER_TABLE
	if t == null:
		problems.append("%s: no \"%s\" table" % [FILE_NAME, table_name])
		return
	problems.append_array(t.problems)
	for row in t.rows:
		var where := t.where(row.line)
		var it := Item.new()
		it.kind = kind
		it.id = row.cell("ID")
		it.display_name = row.cell("Name")
		var access := row.cell("Access").to_lower()
		it.access = &"public" if access == "" else StringName(access)
		if it.id.length() != ID_LENGTH or not it.id.is_valid_int():
			problems.append("%s: ID must be %d digits, not \"%s\"" % [where, ID_LENGTH, it.id])
			continue
		if item(it.id) != null:
			problems.append("%s: ID %s is listed twice" % [where, it.id])
			continue
		if it.display_name == "":
			problems.append("%s: %s has no Name" % [where, it.id])
			continue
		if not ACCESS.has(it.access):
			problems.append("%s: Access must be public or dev, not \"%s\": left out" % [where, access])
			continue
		if kind == Kind.REPLICA:
			it.key = StringName(row.cell("Key"))
			it.tags = _words(row.cell("Tags"))
			it.comes_with = _names(row.cell(COMES_WITH))
			if it.key == &"":
				problems.append("%s: %s has no Key" % [where, it.id])
				continue
		elif kind == Kind.PART:
			it.slot = slot
			it.key = StringName(row.cell("Key"))
			it.fits = _words(row.cell("Fits"))
			if it.key == &"":
				problems.append("%s: %s has no Key" % [where, it.id])
				continue
		else:
			it.type = StringName(row.cell("Type").to_lower())
			it.fits = _words(row.cell("Fits"))
			if not POWER_TYPES.has(it.type):
				problems.append("%s: Type must be battery, gas or spring, not \"%s\"" % [where, it.type])
				continue
		into.append(it)


## The parts `replica` comes with (its Comes with, by Name or ID): each that is a part fitting it, the first for each
## slot; a name that isn't one is left out (tests/unit/test_loadout.gd names it).
func comes_with(replica: Item) -> Array[Item]:
	var out: Array[Item] = []
	var slots: Array[StringName] = []
	for n in replica.comes_with:
		var pt := named(n)
		if pt != null and pt.kind == Kind.PART and not slots.has(pt.slot) and fits(pt, replica):
			out.append(pt)
			slots.append(pt.slot)
	return out


## "2x Scope, Vertical Grip" as its names, as written.
static func _names(cell: String) -> PackedStringArray:
	var out := PackedStringArray()
	for w in cell.split(","):
		var t := w.strip_edges()
		if t != "":
			out.append(t)
	return out


## "pistol, gas, pistol-mag" as its words.
static func _words(cell: String) -> PackedStringArray:
	var out := PackedStringArray()
	for w in cell.split(","):
		var t := w.strip_edges().to_lower()
		if t != "":
			out.append(t)
	return out
