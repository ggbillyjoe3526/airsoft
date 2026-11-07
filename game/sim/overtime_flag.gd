class_name OvertimeFlag
extends RefCounted
## Elimination's overtime flag (the browser game's sim/overtimeFlag.ts, OT1): when a round's clock runs out with both
## teams in play, a flag goes up at the map's spot and the first team to touch it wins the round (Round decides when).
## A touch is a hand on it, no hold: a player in play within OvertimeConfig.reach of its foot, its feet within
## reach_height of the foot's floor. Players of both teams at it hold each other off. Plain data; nothing allocated per
## tick.

## The flag is up: this round is in overtime. It stays up through the pause after the round, until the next starts.
var up: bool = false
## Its foot (the map's `overtimeFlag`, copied there when it goes up).
var foot: Vector3 = Vector3.ZERO
## Seconds of overtime left: OvertimeConfig.time at each round's start, run down while the flag is up and nobody takes
## it.
var left: float = 0.0
## Players of both teams at it this tick: nobody takes it.
var contested: bool = false
## Its time was cut short (the Dev tab's End the round now, Round.run_clock_out): the round ends as a draw on the next
## tick unless a team takes it then, and `left` keeps what was unplayed, so the round's table counts only what was.
var cut: bool = false


## Down again with the whole of its time, for a new round.
func reset(cfg: OvertimeConfig) -> void:
	up = false
	left = cfg.time
	contested = false
	cut = false


## Up at `spot`, with the time it has left.
func raise(spot: Vector3) -> void:
	up = true
	foot = spot
	contested = false


## Whether `c` is in play with a hand on the flag: within reach of its foot, on its floor.
func touched_by(c: Character, cfg: OvertimeConfig) -> bool:
	if not Elimination.is_in_play(c) or absf(c.position.y - foot.y) > cfg.reach_height:
		return false
	var dx := c.position.x - foot.x
	var dz := c.position.z - foot.z
	return dx * dx + dz * dz <= cfg.reach * cfg.reach


## One tick (`dt` s) of the flag while it is up: the team (0 or 1) that took it, or -1 (nobody at it, or both teams:
## contested). Runs its time down only when nobody took it; the caller ends the round when it is out (`left` at 0).
func step(characters: Array[Character], cfg: OvertimeConfig, dt: float) -> int:
	var alpha := false
	var beta := false
	for c in characters:
		if not touched_by(c, cfg):
			continue
		if c.team == 0:
			alpha = true
		else:
			beta = true
	contested = alpha and beta
	if alpha != beta:
		return 0 if alpha else 1
	left = maxf(0.0, left - dt)
	return -1
