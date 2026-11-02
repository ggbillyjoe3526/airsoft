class_name CustomRules
extends RefCounted
## The Custom rule set's switches (concept `rules-custom.png`; the browser game's config/matchRules.ts MatchRules):
## players per team, rounds to win, the round's length, friendly fire and whether ricochets count. Saved with the
## settings under "custom_rules", each value checked on its own; they start as Skirmish's, the match the game always
## had. A Custom match plays them (applied_to), stays out of the records and gives XP at no more than the Custom
## multiplier (data/levels.md).

## The Match screen's choices: players per team (each map offers its own run of them, data/maps.md: every field 5v5 to
## 8v8, 6v6 its standard; nothing offers 9v9), rounds to win, and the round time's range and step (s; the browser game's
## TEAM_SIZE_CHOICES, WINS_NEEDED_CHOICES and ROUND_TIME_SETTING). A saved team size is kept whatever map is picked:
## a map that doesn't offer it plays its standard size (MatchOptions.team_size).
const TEAM_SIZES: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
const WINS_NEEDED: Array[int] = [3, 5, 7, 10]
const ROUND_TIME_RANGE := Vector2(90.0, 300.0)
const ROUND_TIME_STEP := 30.0

var team_size: int = 0
var wins_needed: int = 0
var round_time: float = 0.0
var friendly_fire: bool = false
var ricochets_count: bool = false


func _init() -> void:
	var rounds := RoundConfig.new()
	var hits := HitConfig.new()
	team_size = rounds.team_size
	wins_needed = rounds.wins_needed
	round_time = rounds.round_time
	friendly_fire = hits.friendly_fire
	ricochets_count = hits.ricochets_count


## `tuning` with these rules in force: a copy, rounds and hits copied too, so the loaded tuning (shared by every
## load_default) keeps Skirmish's. The ends swap one round short of the rounds to win (first to 5: after 4, as
## Skirmish), so a full-length match's decider is always played in the second half (the browser game's roundRulesFor).
func applied_to(tuning: SimTuning) -> SimTuning:
	var t := tuning.duplicate() as SimTuning
	t.rounds = tuning.rounds.duplicate() as RoundConfig
	t.hits = tuning.hits.duplicate() as HitConfig
	t.rounds.team_size = team_size
	t.rounds.wins_needed = wins_needed
	t.rounds.round_time = round_time
	t.rounds.half_time_after = maxi(1, wins_needed - 1)
	t.hits.friendly_fire = friendly_fire
	t.hits.ricochets_count = ricochets_count
	return t


## A snapshot: the same switches in an object of their own, so a match plays what was picked at Play whatever the
## settings change after.
func copy() -> CustomRules:
	var c := CustomRules.new()
	c.from_dict(to_dict())
	return c


func to_dict() -> Dictionary:
	return {
		"team_size": team_size, "wins_needed": wins_needed, "round_time": round_time, "friendly_fire": friendly_fire,
		"ricochets_count": ricochets_count,
	}


## Takes saved values over the defaults, each checked on its own: a count must be one of the choices and the round
## time on a step of its range.
func from_dict(data: Dictionary) -> void:
	var d := CustomRules.new()
	team_size = _choice(data, "team_size", d.team_size, TEAM_SIZES)
	wins_needed = _choice(data, "wins_needed", d.wins_needed, WINS_NEEDED)
	round_time = _round_time(data, d.round_time)
	friendly_fire = _flag(data, "friendly_fire", d.friendly_fire)
	ricochets_count = _flag(data, "ricochets_count", d.ricochets_count)


static func _choice(data: Dictionary, key: String, fallback: int, choices: Array[int]) -> int:
	var v: Variant = data.get(key)
	if not (v is int or v is float) or float(v) != floorf(float(v)) or not choices.has(int(v)):
		return fallback
	return int(v)


static func _round_time(data: Dictionary, fallback: float) -> float:
	var v: Variant = data.get("round_time")
	if not (v is int or v is float) or is_nan(float(v)):
		return fallback
	var s := float(v)
	if s < ROUND_TIME_RANGE.x or s > ROUND_TIME_RANGE.y or fmod(s - ROUND_TIME_RANGE.x, ROUND_TIME_STEP) != 0.0:
		return fallback
	return s


static func _flag(data: Dictionary, key: String, fallback: bool) -> bool:
	var v: Variant = data.get(key)
	return v if v is bool else fallback
