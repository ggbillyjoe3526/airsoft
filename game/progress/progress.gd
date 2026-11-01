class_name Progress
extends RefCounted
## The player's level progress (the browser game's progress/progress.ts): the XP earned and every item unlocked, saved
## through SaveFile at user://progress.save (kind "progress", version 1), apart from the settings and the loadouts.
## Unlocks are kept as a list, never worked out again from the level alone, so an item levels.md later moves up a level
## stays with whoever has it, and one moved down reaches everyone already past it (`grant_reached`). A missing file is a
## new player; a damaged one is set aside and a new player's progress used, with `load_message`; one from a newer build
## is used for nothing and never written over (the new one lasts for the session). Fields this build doesn't know are
## kept. It also keeps the map and team of the last match played (`remember_picks`), so the Match page opens on them
## at the next launch (MatchPicks.recall); they are no options, so not in Settings.

const PATH := "user://progress.save"
const KIND := "progress"
const VERSION := 1
const KNOWN_KEYS: Array[String] = ["xp", "unlocked", "last_map", "last_team"]
## The most XP a save may hold: far beyond any cap, a guard against a garbled number.
const MAX_XP := 1000000000


## What one change of XP reached: the level before and after, and what it unlocked (pool IDs, lowest level first).
class LevelUp:
	extends RefCounted
	var from: int = 0
	var to: int = 0
	var unlocked: PackedStringArray = PackedStringArray()


var table: LevelTable = null
## XP earned, counted up to the cap's total (XP stops at the cap until levels.md raises it).
var xp: int = 0
## Every item unlocked, by pool ID, in the order they were unlocked. Never taken away.
var unlocked: PackedStringArray = PackedStringArray()
## The map id and team (0 or 1) of the last match played from the Match page; "" and -1 before the first.
var last_map: String = ""
var last_team: int = -1
var dirty: bool = false
## Why the file couldn't be used, for the menus to show; "" when it was fine or missing, or once a save wrote a good one.
var load_message: String = ""
## The file is from a newer build: it is never written over.
var _newer_on_disk: bool = false
var _extra: Dictionary = {}

static var _shared: Progress = null


func _init(table_in: LevelTable) -> void:
	table = table_in
	from_dict({})


## The player's progress: read from PATH on first use, then the same object.
static func shared() -> Progress:
	if _shared == null:
		_shared = Progress.new(LevelTable.shared())
		_shared.load_file()
	return _shared


func level() -> int:
	return table.level_of(xp)


func standing() -> LevelTable.Standing:
	return table.standing(xp)


## Whether `id` is the player's: unlocked, or everything while levels.md has no readable level 0
## (LevelTable.everything_unlocked).
func has(id: String) -> bool:
	return table.everything_unlocked or unlocked.has(id)


## Adds what every level up to the player's own unlocks and they lack (a new player's kit, an item levels.md added to a
## level they are past, or one it moved down); returns what was added, lowest level first. Nothing while levels.md has
## no readable level 0: its stand-in unlocks everything for the session (`has`), never into the save.
func grant_reached() -> PackedStringArray:
	var added := PackedStringArray()
	if table.everything_unlocked:
		return added
	for id in table.unlocks_up_to(level()):
		if not unlocked.has(id):
			unlocked.append(id)
			added.append(id)
	if not added.is_empty():
		dirty = true
	return added


## Adds `amount` XP (never negative) and unlocks what the levels it reaches give. XP stops at the cap's total: past it
## there is nothing to count towards until the cap goes up, and a total over a cap since brought down is kept.
func add_xp(amount: int) -> LevelUp:
	var up := LevelUp.new()
	up.from = level()
	var top := table.levels[table.cap()].total
	if xp < top and amount > 0:
		xp = mini(top, xp + amount)
		dirty = true
	up.unlocked = grant_reached()
	up.to = level()
	return up


## Level 0's kit; none from a levels.md with no readable level 0 (its stand-in's everything never reaches the save).
func _starting_kit() -> PackedStringArray:
	return PackedStringArray() if table.everything_unlocked else table.unlocks_up_to(0)


## Keeps `map_id` and `team` as the last match's picks (marked to save if they changed).
func remember_picks(map_id: String, team: int) -> void:
	if map_id != last_map or team != last_team:
		last_map = map_id
		last_team = team
		dirty = true


## Back to level 0 (Settings › Dev › Reset level): no XP, and the starting kit alone.
func reset() -> void:
	xp = 0
	unlocked = _starting_kit()
	dirty = true


## Reads `path`. Silent when there is no file; otherwise a message if it can't be used.
func load_file(path: String = PATH) -> void:
	load_message = ""
	_newer_on_disk = false
	var r := SaveFile.read(path, KIND)
	if not r.ok:
		if r.found:
			load_message = TranslationServer.translate("PROGRESS_DAMAGED")
			push_warning("progress: %s is damaged; starting from level 0" % path)
			SaveFile.quarantine(path)
		grant_reached()
		return
	if int(r.version) < 1 or int(r.version) > VERSION:
		load_message = TranslationServer.translate("PROGRESS_NEWER")
		push_warning("progress: %s is version %d; it is kept and not written over" % [path, int(r.version)])
		_newer_on_disk = int(r.version) > VERSION
		grant_reached()
		return
	for p in from_dict(r.data):
		push_warning("progress: " + p)
	# What levels.md now gives up to this level is the player's at once, and saved with the next change.
	grant_reached()


## Writes `path`; false if it could not be written (or holds a newer build's progress).
func save(path: String = PATH) -> bool:
	if _newer_on_disk:
		return false
	var ok := SaveFile.write(path, KIND, VERSION, to_dict())
	dirty = not ok
	if ok:
		# the file is good again: what was wrong with the last one is said no more
		load_message = ""
	return ok


func save_if_dirty(path: String = PATH) -> void:
	if dirty:
		save(path)


func to_dict() -> Dictionary:
	var out := _extra.duplicate(true)
	out["xp"] = xp
	out["unlocked"] = Array(unlocked)
	if not last_map.is_empty():
		out["last_map"] = last_map
	if last_team >= 0:
		out["last_team"] = last_team
	return out


## Takes saved values, each checked; what won't do is listed and left out. Nothing saved is a new player.
func from_dict(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	_extra = {}
	for k: Variant in data:
		if not KNOWN_KEYS.has(str(k)):
			_extra[k] = data[k]
	xp = 0
	var saved_xp: Variant = data.get("xp")
	if saved_xp is int or saved_xp is float:
		var v := float(saved_xp)
		if v >= 0.0 and v <= MAX_XP and v == floorf(v):
			xp = int(v)
		else:
			problems.append("xp %s isn't a whole number from 0 to %d: starting from 0" % [str(saved_xp), MAX_XP])
	elif saved_xp != null:
		problems.append("xp isn't a number: starting from 0")
	unlocked = _starting_kit()
	var saved: Variant = data.get("unlocked")
	if saved is Array:
		for id: Variant in saved:
			if id is String and (id as String).length() == Pool.ID_LENGTH and (id as String).is_valid_int():
				if not unlocked.has(id):
					unlocked.append(id)
			else:
				problems.append("an unlocked item \"%s\" isn't a pool ID: left out" % str(id))
	var saved_map: Variant = data.get("last_map", "")
	last_map = saved_map if saved_map is String else ""
	var saved_team: Variant = data.get("last_team", -1)
	last_team = int(saved_team) if (saved_team is int or saved_team is float) and float(saved_team) in [0.0, 1.0] else -1
	dirty = false
	return problems
