class_name SaveKeeper
extends RefCounted
## Restore points, Undo and delete for the save as one (SaveBundle; the browser game's M31). Restore points live in
## POINTS_PATH: at start, the save as it was, at most one per calendar day (the player's local day) and only when it
## differs from the newest, RESTORE_POINTS in all, newest first; none for an empty save. `replace` puts a restore
## point's save, the Undo slot's or an empty one (delete) in place of the save: the save as it stands goes to the Undo
## slot (UNDO_PATH) first, then each store is written, and a store that won't write puts every store and the slot back
## as they were (never half one save, half another). After a replace the stores are held (SaveFile.hold) until the
## restart. A file a newer build wrote is read for nothing and never written over. The clock and every path are
## injected for tests.

## What a replace puts in place: a restore point's save, the Undo slot's, or none (delete).
enum What { RESTORE, UNDO, DELETE }
const WHAT_NAMES: Array[String] = ["restore", "undo", "delete"]
## Why the last replace, Undo or delete didn't happen (`refusal`), for the player's words; NONE after one that worked.
enum Refusal { NONE, REPLACED_THIS_RUN, NEWER_SAVE, HOLDS_NEWER, UNREADABLE, NOT_WRITTEN, NOT_PUT_BACK,
		NOTHING_TO_UNDO, NOTHING_TO_DELETE }
## How many restore points are kept (the browser game's rule).
const RESTORE_POINTS := 3
const POINTS_PATH := "user://restore_points.save"
const POINTS_KIND := "restore_points"
const POINTS_VERSION := 1
const UNDO_PATH := "user://undo.save"
const UNDO_KIND := "undo"
const UNDO_VERSION := 1


## A restore point: the player's local day it was taken ("2026-10-23"), when (Unix seconds) and the save.
class Point:
	extends RefCounted
	var day: String = ""
	var taken_at: int = 0
	var save: SaveBundle = null


## The Undo slot: what the replace was, when, and the save it replaced.
class UndoSlot:
	extends RefCounted
	var what: What = What.RESTORE
	var taken_at: int = 0
	var save: SaveBundle = null


## The four stores' paths, in SaveBundle.KINDS order.
var store_paths: Array[String] = SaveBundle.PATHS
var points_path: String = POINTS_PATH
var undo_path: String = UNDO_PATH
## Now, in Unix seconds (Time.get_unix_time_from_system).
var clock: Callable = Callable(Time, &"get_unix_time_from_system")
## The player's time zone, in minutes east of UTC (Time.get_time_zone_from_system's bias).
var utc_offset_minutes: int = int(Time.get_time_zone_from_system().get("bias", 0))
## Why the last replace was refused or failed, naming the version for a newer save; "" after one that worked.
var last_error: String = ""
## The kind of the last refusal or failure (last_error's), NONE after a replace that worked.
var refusal: Refusal = Refusal.NONE


## At start: keeps the save as it is as today's restore point, unless today has one, the save is empty, it is the same
## as the newest point, or the file is a newer build's. A damaged file is set aside (SaveFile.quarantine) before a new
## list replaces it. A full disk drops the oldest first. True if one was kept.
func keep_today() -> bool:
	var read := SaveFile.read(points_path, POINTS_KIND)
	if read.ok and int(read.version) > POINTS_VERSION:
		return false
	var points: Array[Point] = []
	if read.ok:
		points = _points_from(read.data)
	var now := _now()
	var today := day_of(now)
	var save := SaveBundle.read(store_paths)
	if save.is_empty():
		return false
	for p: Point in points:
		if p.day == today:
			return false
	if not points.is_empty() and points[0].save.same_as(save):
		return false
	var point := Point.new()
	point.day = today
	point.taken_at = now
	point.save = save
	points.push_front(point)
	points.resize(mini(points.size(), RESTORE_POINTS))
	if not read.ok and read.found:
		push_warning("restore points: %s is damaged; set aside for a new list" % points_path)
		SaveFile.quarantine(points_path)
	while not points.is_empty():
		if _write_points(points):
			print("[save] restore point kept for %s" % today)
			return true
		points.pop_back()
	return false


## The restore points, newest first; none when the file is missing, damaged or a newer build's.
func restore_points() -> Array[Point]:
	var read := SaveFile.read(points_path, POINTS_KIND)
	if not read.ok or int(read.version) > POINTS_VERSION:
		return []
	return _points_from(read.data)


## The Undo slot, or null when there is nothing to undo (or the slot is a newer build's).
func undo_slot() -> UndoSlot:
	var read := SaveFile.read(undo_path, UNDO_KIND)
	if not read.ok or int(read.version) > UNDO_VERSION:
		return null
	var data: Dictionary = read.data
	var what := WHAT_NAMES.find(str(data.get("what", "")))
	var raw: Variant = data.get("save")
	if what < 0 or not raw is Dictionary:
		return null
	var slot := UndoSlot.new()
	slot.what = what as What
	slot.taken_at = SaveBundle.whole(data.get("taken_at"))
	slot.save = SaveBundle.from_dict(raw)
	return slot


## Puts `bundle` in place of the save: a restore point's (RESTORE), the Undo slot's (UNDO) or an empty one (DELETE). The
## save as it stands goes to the Undo slot first, and nothing changes if that write fails; Undo instead uses the slot up
## (the save it replaces is not kept). Then each store is written, or every copy removed where `bundle` has none; a
## store that won't write puts every store and the slot back as they were and returns false. On success the stores are
## held until the restart. Refused, with `last_error` saying why (and `refusal` its kind): after a replace this run
## (restart first), a save from a newer version (named), and any replace over a save holding a store from a newer
## version (this build couldn't keep it for Undo, and Undo keeps nothing). An empty save as it stands (nothing, or only
## damaged stores) leaves the Undo slot as it was, so a delete is still undone after a restore over nothing. A damaged
## store is set aside (SaveFile.quarantine) before it is replaced, never destroyed.
func replace(bundle: SaveBundle, what: What) -> bool:
	refusal = Refusal.NONE
	last_error = ""
	for path: String in store_paths:
		if SaveFile.held(path):
			return _fail("the save was already replaced this run; restart first", Refusal.REPLACED_THIS_RUN)
	var refused := bundle.refusal()
	if refused != "":
		return _fail(refused, Refusal.NEWER_SAVE)
	var current := SaveBundle.read(store_paths)
	if current.refusal() != "":
		return _fail("the save now holds a store from a newer version (%s); this build won't replace it" % current.refusal(),
				Refusal.HOLDS_NEWER)
	# The copies as they are, a damaged store's too, before anything moves: a refusal below then leaves the save
	# exactly as it was found (a damaged store still in its place, so the next start still says it is damaged).
	var snaps: Array[SaveFile.Snapshot] = []
	for path: String in store_paths:
		snaps.append(SaveFile.snapshot(path))
	snaps.append(SaveFile.snapshot(undo_path))
	for snap: SaveFile.Snapshot in snaps:
		if not snap.ok:
			return _fail("a copy of %s couldn't be read to keep it" % snap.path, Refusal.UNREADABLE)
	if what != What.UNDO and not current.is_empty():
		var slot := {"what": WHAT_NAMES[what], "taken_at": _now(), "save": current.to_dict()}
		if not SaveFile.write(undo_path, UNDO_KIND, UNDO_VERSION, slot):
			return _fail("the save couldn't be kept for Undo", Refusal.NOT_WRITTEN)
	# Only now, with nothing left that can refuse before the stores are written: a damaged store goes aside.
	for kind: String in current.damaged:
		push_warning("save: %s is damaged; set aside before it is replaced" % kind)
		SaveFile.quarantine(store_paths[SaveBundle.KINDS.find(kind)])
	if not bundle.write(store_paths) or (what == What.UNDO and not SaveFile.remove(undo_path)):
		var back := true
		for snap: SaveFile.Snapshot in snaps:
			back = SaveFile.put_back(snap) and back
		if back:
			return _fail("a store wouldn't write; the save was put back", Refusal.NOT_WRITTEN)
		return _fail("a store wouldn't write and the save couldn't all be put back", Refusal.NOT_PUT_BACK)
	SaveFile.hold(PackedStringArray(store_paths))
	print("[save] replaced (%s)" % WHAT_NAMES[what])
	return true


## The Undo slot's save back in place; false when there is nothing to undo.
func undo() -> bool:
	var slot := undo_slot()
	if slot == null:
		return _refuse("nothing to undo", Refusal.NOTHING_TO_UNDO)
	return replace(slot.save, What.UNDO)


## Removes the save (every copy of each store); Undo brings it back. An empty save has nothing to delete, and the Undo
## slot is kept.
func delete_save() -> bool:
	if SaveBundle.read(store_paths).is_empty():
		return _refuse("nothing to delete", Refusal.NOTHING_TO_DELETE)
	return replace(SaveBundle.new(), What.DELETE)


## The player's local calendar day of `unix` ("2026-10-23").
func day_of(unix: int) -> String:
	return Time.get_date_string_from_unix_time(unix + utc_offset_minutes * 60)


## Writes the list; false when it couldn't be (a full disk).
func _write_points(points: Array[Point]) -> bool:
	return SaveFile.write(points_path, POINTS_KIND, POINTS_VERSION, _points_to(points))


func _now() -> int:
	return int(clock.call())


func _fail(why: String, kind: Refusal) -> bool:
	push_warning("save: not replaced: %s" % why)
	return _refuse(why, kind)


func _refuse(why: String, kind: Refusal) -> bool:
	last_error = why
	refusal = kind
	return false


## Points as written: {"points": [{day, taken_at, save}]}; one that doesn't fit is left out.
static func _points_from(data: Dictionary) -> Array[Point]:
	var out: Array[Point] = []
	var raw: Variant = data.get("points", [])
	if not raw is Array:
		return out
	for entry: Variant in raw:
		if not entry is Dictionary or not entry.get("save") is Dictionary or not entry.get("day") is String:
			continue
		var p := Point.new()
		p.day = entry["day"]
		p.taken_at = SaveBundle.whole(entry.get("taken_at"))
		p.save = SaveBundle.from_dict(entry["save"])
		out.append(p)
		if out.size() == RESTORE_POINTS:
			break
	return out


static func _points_to(points: Array[Point]) -> Dictionary:
	var out: Array[Dictionary] = []
	for p: Point in points:
		out.append({"day": p.day, "taken_at": p.taken_at, "save": p.save.to_dict()})
	return {"points": out}
