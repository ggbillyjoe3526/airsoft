class_name SavedLoadouts
extends RefCounted
## The player's saved loadouts (the browser game's pool/savedLoadouts.ts): up to five, named, one of them current. The
## current one is the loadout carried and every edit goes to it, so there is no Save button (docs/DECISIONS.md ›
## Loadout). Saved through SaveFile at user://loadouts.save (kind "loadouts", version 1), apart from the settings.
## A missing file is one default loadout. A damaged file, or one of a newer version, falls back to that with
## `load_message` (a newer one is never written over: the default lasts for the session); a saved value that won't do
## keeps its default and warns. Fields this build doesn't know are kept. A
## loadout saved before Glowing BBs (WL8) loads them At Night on every replica.

## Sent after any change to the loadouts or which one is current.
signal changed

const PATH := "user://loadouts.save"
const KIND := "loadouts"
const VERSION := 1
const MAX_SLOTS := 5
## The longest name a loadout may have (characters).
const NAME_MAX := 20
## The keys this build reads; any other key in the file is kept as it was.
const KNOWN_KEYS: Array[String] = ["slots", "current"]

var rules: LoadoutRules = null
var slots: Array[Loadout] = []
var current: int = 0
## Changed since the last save.
var dirty: bool = false
## Why the file couldn't be used, for the menus to show; "" when it was fine or missing.
var load_message: String = ""
## The file is from a newer build: it is never written over.
var _newer_on_disk: bool = false
var _extra: Dictionary = {}

static var _shared: SavedLoadouts = null


func _init(rules_in: LoadoutRules) -> void:
	rules = rules_in
	from_dict({})


## The player's loadouts: read from PATH on first use, then the same object.
static func shared() -> SavedLoadouts:
	if _shared == null:
		_shared = SavedLoadouts.new(LoadoutRules.standard())
		_shared.load_file()
	return _shared


## The loadout carried now.
func carried() -> Loadout:
	return slots[current]


## What the carried loadout plays as, with dev items on offer only while `dev_content`.
func carried_kit(dev_content: bool) -> Kit:
	var was := rules.dev_content
	rules.dev_content = dev_content
	var kit := rules.carried(carried())
	rules.dev_content = was
	return kit


## "Loadout 3": the first such name no loadout has.
func fresh_name() -> String:
	var taken := PackedStringArray()
	for l in slots:
		taken.append(l.name)
	var n := 1
	while taken.has(TranslationServer.translate("LOADOUT_NAME") % n):
		n += 1
	return TranslationServer.translate("LOADOUT_NAME") % n


## Carries loadout `index`.
func use(index: int) -> void:
	if index < 0 or index >= slots.size() or index == current:
		return
	current = index
	_changed()


## A new loadout, a copy of the carried one under a fresh name, carried from now on; its index, or -1 when all five
## are taken.
func create() -> int:
	if slots.size() >= MAX_SLOTS:
		return -1
	slots.append(carried().copy(fresh_name()))
	current = slots.size() - 1
	_changed()
	return current


## Names loadout `index`; the name is trimmed and cut to NAME_MAX, and an empty one is refused.
func rename(index: int, new_name: String) -> bool:
	var n := clean_name(new_name)
	if index < 0 or index >= slots.size() or n == "":
		return false
	slots[index].name = n
	_changed()
	return true


## A copy of loadout `index` in the first free place, under a fresh name (the carried one stays as it was); its index,
## or -1 when all five are taken.
func duplicate_slot(index: int) -> int:
	if index < 0 or index >= slots.size() or slots.size() >= MAX_SLOTS:
		return -1
	slots.append(slots[index].copy(fresh_name()))
	_changed()
	return slots.size() - 1


## Copies the carried loadout over loadout `index` (another one), keeping that one's name.
func replace(index: int) -> bool:
	if index < 0 or index >= slots.size() or index == current:
		return false
	slots[index] = carried().copy(slots[index].name)
	_changed()
	return true


## Removes loadout `index`; never the last one. The one carried stays carried; if it was removed, the next one is
## (the one before it when it was last), as the browser game.
func remove(index: int) -> bool:
	if index < 0 or index >= slots.size() or slots.size() <= 1:
		return false
	slots.remove_at(index)
	if current > index or current >= slots.size():
		current = maxi(0, current - 1)
	_changed()
	return true


## Marks an edit to the carried loadout (the Loadout calls this after LoadoutRules changed it).
func mark_changed() -> void:
	_changed()


## A name as kept: trimmed, at most NAME_MAX characters.
static func clean_name(text: String) -> String:
	return text.strip_edges().left(NAME_MAX).strip_edges()


## Reads `path`. Silent when there is no file; otherwise a message if it can't be used.
func load_file(path: String = PATH) -> void:
	load_message = ""
	_newer_on_disk = false
	var r := SaveFile.read(path, KIND)
	if not r.ok:
		if r.found:
			load_message = TranslationServer.translate("LOADOUTS_DAMAGED")
			push_warning("loadouts: %s is damaged; using the default loadout" % path)
			SaveFile.quarantine(path)
		return
	if int(r.version) < 1 or int(r.version) > VERSION:
		load_message = TranslationServer.translate("LOADOUTS_NEWER")
		push_warning("loadouts: %s is version %d; using the default loadout" % [path, int(r.version)])
		_newer_on_disk = int(r.version) > VERSION
		return
	for p in from_dict(r.data):
		push_warning("loadouts: " + p)


## Writes `path`; false if it could not be written (or holds a newer build's loadouts).
func save(path: String = PATH) -> bool:
	if _newer_on_disk:
		return false
	var ok := SaveFile.write(path, KIND, VERSION, to_dict())
	dirty = not ok
	return ok


func save_if_dirty(path: String = PATH) -> void:
	if dirty:
		save(path)


func to_dict() -> Dictionary:
	var out := _extra.duplicate(true)
	var list: Array = []
	for l in slots:
		list.append(l.to_dict())
	out["slots"] = list
	out["current"] = current
	return out


## Takes saved loadouts, each checked by the rules; what won't do keeps its default and is listed. No loadout at all
## is one default loadout.
func from_dict(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	_extra = {}
	for k: Variant in data:
		if not KNOWN_KEYS.has(str(k)):
			_extra[k] = data[k]
	slots = []
	var saved: Variant = data.get("slots")
	if saved is Array:
		for entry: Variant in saved:
			if slots.size() >= MAX_SLOTS:
				problems.append("more than %d loadouts saved: the rest left out" % MAX_SLOTS)
				break
			if not entry is Dictionary:
				problems.append("a saved loadout isn't one: left out")
				continue
			slots.append(_loadout_from(entry, problems))
	if slots.is_empty():
		slots.append(rules.default_loadout(TranslationServer.translate("LOADOUT_NAME") % 1))
	var c: Variant = data.get("current")
	current = clampi(int(c), 0, slots.size() - 1) if (c is int or c is float) else 0
	dirty = false
	return problems


func _loadout_from(entry: Dictionary, problems: Array[String]) -> Loadout:
	var l := Loadout.new()
	var n: Variant = entry.get("name")
	l.name = clean_name(n) if n is String else ""
	if l.name == "":
		l.name = fresh_name()
	var eq: Variant = entry.get("equipped")
	for slot: Loadout.Slot in [Loadout.Slot.PRIMARY, Loadout.Slot.SECONDARY]:
		var id: Variant = eq[slot] if eq is Array and (eq as Array).size() > slot else null
		l.equipped[slot] = id if id is String else ""
	var tunes: Variant = entry.get("tunes")
	if tunes is Dictionary:
		for id: Variant in tunes:
			var t: Variant = tunes[id]
			var it := rules.pool.item(str(id))
			if t is Dictionary and it != null:
				l.tunes[str(id)] = ReplicaTune.from_dict(t, rules.default_tune(it))
			else:
				problems.append("%s: a setup for \"%s\" won't read: dropped" % [l.name, id])
	# Glowing BBs (WL8): a save from before them has none, so every replica loads them At Night. Only a replica has them.
	var glow: Variant = entry.get("glow")
	if glow is Dictionary:
		var picks := glow as Dictionary
		for id: Variant in picks:
			var choice := Loadout.GLOW_NAMES.find(str(picks[id])) if picks[id] is String else -1
			var it := rules.pool.item(str(id))
			if choice >= 0 and it != null and it.kind == Pool.Kind.REPLICA:
				l.glow[str(id)] = choice as Loadout.Glow
			else:
				problems.append("%s: Glowing BBs \"%s\" for \"%s\" won't read: At Night" % [l.name, picks[id], id])
	elif glow != null:
		problems.append("%s: Glowing BBs won't read: At Night" % l.name)
	problems.append_array(rules.clean(l))
	return l


func _changed() -> void:
	dirty = true
	changed.emit()
