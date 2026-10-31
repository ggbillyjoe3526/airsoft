class_name RoundState
extends RefCounted
## The match's round flow as plain data (the browser game's sim/round.ts RoundState: Elimination and Attack / Defend).
## Round writes it; the HUD reads it.

## LIVE: playing; OVER: the pause between rounds; MATCH_OVER: a team has won the match (until a new match starts).
enum Phase { LIVE, OVER, MATCH_OVER }
## ELIMINATION: a round is won by putting the other team out. ATTACK_DEFEND: also by raising the flag on the defenders'
## pole, and the time-out goes to the defenders.
enum Mode { ELIMINATION, ATTACK_DEFEND }

## The match's mode and, for Attack / Defend, the feet of its poles (map data: flag A's first, AB1) and the team
## attacking in the first half (it follows your team pick). Set before Round.start_match. `pole` is flag A's; setting it
## makes the match's one pole.
var mode: Mode = Mode.ELIMINATION
var poles: PackedVector3Array = PackedVector3Array([Vector3.ZERO])
var pole: Vector3:
	get:
		return poles[0] if not poles.is_empty() else Vector3.ZERO
	set(at):
		poles = PackedVector3Array([at])
var first_attackers: int = 0
## Practice (the range, M21): no rounds, so no clock and no wipe-out; the round stays live from start_match on, the
## targets are stepped and spare magazines stay full (Simulation.step). Off in every match.
var practice: bool = false

var phase: Phase = Phase.LIVE
## The round being played, from 1. A drawn round is played again under the same number (browser audit SIM-19).
var number: int = 1
## Rounds drawn so far this match (each replayed, so not counted in `number`).
var draws: int = 0
## Seconds left in the live round.
var clock: float = 0.0
## Seconds left before the next round starts, while OVER.
var timer: float = 0.0
## The last finished round's winning team, or -1 for a draw or none yet; and why it ended (GameEvent.RoundEnd).
var winner: int = -1
var reason: GameEvent.RoundEnd = GameEvent.RoundEnd.ELIMINATED
## Rounds won per team (0 Alpha, 1 Beta).
var score: PackedInt32Array = PackedInt32Array([0, 0])
## The team that won the match, or -1.
var match_winner: int = -1
## Attack / Defend: the team attacking this round (-1 in Elimination), a flag for each pole (one at least; sized to
## `poles` each round, the same array kept), and the overtime played so far (s; time ran out while the attackers worked
## a rope). `flag` is flag A's.
var attackers: int = -1
var flags: Array[FlagState] = [FlagState.new()]
var flag: FlagState:
	get:
		return flags[0]
var overtime: float = 0.0
## Elimination: the foot of the map's overtime flag (map data; set before Round.start_match on a map with a spot), and
## the flag itself (up, foot, time left, contested), down with all its time at each round's start. Without a spot, a
## clock run out with both teams in play is a draw at once. Never up in Attack / Defend or practice.
var has_overtime_spot: bool = false
var overtime_spot: Vector3 = Vector3.ZERO
var overtime_flag: OvertimeFlag = OvertimeFlag.new()


## Every flag at the bottom of its pole for a new round, one for each pole (one at least).
func reset_flags() -> void:
	var n := maxi(1, poles.size())
	while flags.size() < n:
		flags.append(FlagState.new())
	flags.resize(n)
	for i in n:
		flags[i].reset(poles[i] if i < poles.size() else Vector3.ZERO)


func is_live() -> bool:
	return phase == Phase.LIVE


## The last finished round was a draw (both teams out at once, or the clock ran out, or the overtime flag stood
## untouched): it is played again.
func drawn() -> bool:
	return winner != 0 and winner != 1
