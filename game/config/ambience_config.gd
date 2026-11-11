class_name AmbienceConfig
extends Resource
## Every field's sound by day and by night (the browser game's config/audio.ts AMBIENCES, M33j and M86): for each
## ambience a set of beds (loops under everything) and calls (a bird, a dog, an owl now and then round the listener).
## A map names its ambience (MapData.ambience); the lighting preset's night flag picks the night set, never a map's
## name (owner, 2026-10-05). The browser's per-field echo is left out (the sound pass plan's question 6). Tested: no
## call louder than a bird and no bed louder than the yard's (DECISIONS 2026-10-05).

## The ambiences a map may name; a map naming none, or one not listed, plays DEFAULT_ID.
## indoor and street are the owner's recordings (AU5): Depot's big room, and a street by day and night
## (the Range's sound, owner 2026-11-05); tunnel his tunnel (2026-11-11), Subway's.
const IDS: Array[StringName] = [&"yard", &"woods", &"indoor", &"street", &"tunnel"]
const DEFAULT_ID := &"yard"

## Each ambience's set by day and by night, keyed by its id in IDS.
@export var day: Dictionary[StringName, AmbienceSet] = {}
@export var night: Dictionary[StringName, AmbienceSet] = {}


## Whether a map may name `ambience`.
static func known(ambience: StringName) -> bool:
	return IDS.has(ambience)


## The set `ambience` plays by day, or at night when `at_night`: the default ambience's for an id with none, and an
## empty set (with a warning) when that is missing too.
func set_for(ambience: StringName, at_night: bool) -> AmbienceSet:
	var sets: Dictionary[StringName, AmbienceSet] = night if at_night else day
	if sets.get(ambience) != null:
		return sets[ambience]
	if sets.get(DEFAULT_ID) != null:
		return sets[DEFAULT_ID]
	push_warning("AmbienceConfig: no %s set for %s or %s" % ["night" if at_night else "day", ambience, DEFAULT_ID])
	return AmbienceSet.new()
