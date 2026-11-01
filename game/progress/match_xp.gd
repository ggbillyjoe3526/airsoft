class_name MatchXp
extends RefCounted
## What a finished match gives (the browser game's progress/xp.ts), by levels.md's XP tables: Match played, Match won and
## each Round won scaled to the match's length (rounds to win ÷ 5, at most 1), each hit on an opponent, then the lower of
## the two teams' difficulty multipliers, held to the Custom row's in a Custom match. A round sat out gives nothing
## (PlayerTally counts only those you took part in). Pure.

## The standard match's rounds to win: Match played, Match won and Round won are given in full from here on.
const FULL_MATCH_WINS := 5
## Where a match's multiplier came from (Earned.multiplier_from): the opponents' level, the teammates' (lower) or the
## Custom rule set's cap (lower still).
const FROM_OPPONENTS := &"opponents"
const FROM_TEAMMATES := &"teammates"
const FROM_CUSTOM := &"custom"


## What a finished match was, for its XP.
class Outcome:
	extends RefCounted
	var won: bool = false
	## Rounds your team won that you took part in.
	var rounds_won: int = 0
	## Your BBs on an opponent.
	var hits: int = 0
	## The match's rounds to win.
	var wins_needed: int = FULL_MATCH_WINS
	## The opponents' difficulty, and your teammates' (&"" with none: the opponents' alone counts).
	var difficulty: StringName = &"normal"
	var teammate_difficulty: StringName = &""
	## Played under the Custom rule set: the multiplier is at most LevelTable.CUSTOM's.
	var custom: bool = false


## One line of a match's XP: what it was for (LevelTable.DEFAULT_EARN's keys), how many, and its XP before the
## multiplier.
class Line:
	extends RefCounted
	var key: StringName = &""
	var count: int = 1
	var xp: int = 0


## A match's XP, line by line, the multiplier (and the row it came from) and the total after it.
class Earned:
	extends RefCounted
	var lines: Array[Line] = []
	var multiplier: float = 1.0
	## FROM_OPPONENTS, FROM_TEAMMATES or FROM_CUSTOM, and that row's level (LevelTable.CUSTOM for the cap).
	var multiplier_from: StringName = FROM_OPPONENTS
	var multiplier_level: StringName = &"normal"
	var total: int = 0


static func earned(table: LevelTable, o: Outcome) -> Earned:
	var e := Earned.new()
	var scale := clampf(float(o.wins_needed) / FULL_MATCH_WINS, 0.0, 1.0)
	e.lines.append(_line(&"match_played", 1, roundi(table.earn[&"match_played"] * scale)))
	if o.won:
		e.lines.append(_line(&"match_won", 1, roundi(table.earn[&"match_won"] * scale)))
	# Scaled like the match lines: a short match is no richer a farm than the standard one.
	if o.rounds_won > 0:
		e.lines.append(_line(&"round_won", o.rounds_won, roundi(table.earn[&"round_won"] * o.rounds_won * scale)))
	if o.hits > 0:
		e.lines.append(_line(&"hit", o.hits, table.earn[&"hit"] * o.hits))
	e.multiplier = multiplier(table, o.difficulty, o.teammate_difficulty, o.custom)
	e.multiplier_from = multiplier_from(table, o.difficulty, o.teammate_difficulty, o.custom)
	e.multiplier_level = o.difficulty
	if e.multiplier_from == FROM_TEAMMATES:
		e.multiplier_level = o.teammate_difficulty
	elif e.multiplier_from == FROM_CUSTOM:
		e.multiplier_level = LevelTable.CUSTOM
	var sum := 0
	for l in e.lines:
		sum += l.xp
	e.total = maxi(0, roundi(sum * e.multiplier))
	return e


static func _line(key: StringName, count: int, xp: int) -> Line:
	var l := Line.new()
	l.key = key
	l.count = count
	l.xp = xp
	return l


## The XP multiplier of a match: the lower of the two teams', so Hard teammates against Easy opponents never count as
## Hard (`mates` is &"" with none: the opponents' alone counts), held to the Custom row's when `custom`. The Match page
## shows the same number before the match.
static func multiplier(table: LevelTable, opponents: StringName, mates: StringName, custom: bool) -> float:
	var m := table.multiplier(opponents)
	if mates != &"":
		m = minf(m, table.multiplier(mates))
	if custom:
		m = minf(m, table.multiplier(LevelTable.CUSTOM))
	return m


## Which row multiplier() took: the opponents' unless the teammates' is lower, the Custom cap when lower still (a tie
## names the earlier, so Hard against Hard says the opponents).
static func multiplier_from(table: LevelTable, opponents: StringName, mates: StringName, custom: bool) -> StringName:
	var from := FROM_OPPONENTS
	var m := table.multiplier(opponents)
	if mates != &"" and table.multiplier(mates) < m:
		from = FROM_TEAMMATES
		m = table.multiplier(mates)
	if custom and table.multiplier(LevelTable.CUSTOM) < m:
		from = FROM_CUSTOM
	return from
