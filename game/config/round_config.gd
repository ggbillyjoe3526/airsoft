class_name RoundConfig
extends Resource
## Elimination match flow (the browser game's config/hits.ts ROUNDS): rounds against the clock, first to 5 round
## wins, ends swapped at half time. Read by game/sim/round.gd.

## Players per team, the player's included: a map the catalogue doesn't list. A listed map plays its own standard
## size, or the Custom size it offers (data/maps.md, MatchOptions.team_size).
@export var team_size: int = 3
## Round length (s). A round that runs out with players left on both sides is a draw, played again.
@export var round_time: float = 150.0
## Seconds from a round's end to everyone respawning (the result, then the round's table; RE1).
@export var reset_delay: float = 6.0
## The countdown at every round's start (s, whole seconds read 3, 2, 1, then GO): everyone is held still and the clock
## waits, the referee's whistle blows at GO. 0: none, the round is live at once. A match gets PlayTuning.round_countdown.
@export var start_countdown: float = 0.0
## Round wins needed, and the lead needed once there (1: the first there wins).
@export var wins_needed: int = 5
@export var win_by: int = 1
## Ends swap after this many decided rounds (first to 5 is at most 9, so the decider is in the second half).
@export var half_time_after: int = 4
## The end (0 or 1) Alpha starts at: the east, which wins a little over half Depot's rounds (DECISIONS 2026-10-03).
@export var first_end: int = 1
## A skipped round simulated at once (Round.simulate, BP8): each team's chance is its players in play raised to this
## power (2: Lanchester's square law, so a man up counts for more than his share), times one plus this share of the
## attackers' highest flag in Attack / Defend (a flag going up favours them).
@export var simulate_power: float = 2.0
@export var simulate_flag_lead: float = 2.0

## Respawns (RS1, owner 2026-11-17: "matches should let players/bots respawn", so a round runs its clock): a hit
## character calls it and walks off as ever, then comes back into the round at its start area, or at a forward spawn of
## its end it picked, a delay after the hit. BY_MODE (Skirmish): in Attack / Defend, and in Plant The Bomb until the bomb
## is armed; never in Elimination, where one life is the mode. ALWAYS and NEVER: the Custom rule's On and Off (in Plant
## The Bomb On still ends at the plant).
enum RespawnRule { BY_MODE, ALWAYS, NEVER }
@export var respawns: RespawnRule = RespawnRule.BY_MODE
## Seconds from a hit to coming back: the attackers' (and either team's in Elimination), and the defenders' in Attack /
## Defend, where a field may set its own (data/maps.md Defender respawn: bot matches put the
## attackers near half the rounds with Depot 15, Woodland 11, Subway 7).
@export var respawn_delay: float = 10.0
@export var defender_respawn_delay: float = 10.0
## ... times the bots' level (MatchOptions.level_tuning, BP10): with respawns Hard defenders held Attack / Defend's
## poles far longer than Normal's and Easy's far shorter (bot matches at the fields' waits, 8 seeds: the attackers took
## 24 to 37 % on Hard, 57 to 72 % on Easy), so a level waits the field's time this many times. A level not named waits
## the field's.
@export var defender_respawn_scale: Dictionary[StringName, float] = {&"easy": 0.75, &"hard": 1.9}
## ... but a level's scale never takes the wait past this (s), nor below the field's own when that is longer: Depot's
## 15 s at 1.9 (28.5 s) let the attackers take 62 % on Hard, and 25 s gave 47.9 % (BP10, bot matches, 16 seeds); a half-minute wait
## after a hit is too long to be fun.
@export var defender_respawn_most: float = 25.0
## ... unless the field sets its own wait against Hard bots (data/maps.md Defender respawn at Hard, applied by
## MatchOptions.match_tuning and level_tuning), 0 for the field's times the Hard scale: on Subway the Hard scale's 13.3 s
## let Hard defenders hold the poles (the attackers took 41.7 %, bot matches, BP11) while Normal's 7 s is about even.
@export var defender_respawn_hard: float = 0.0
## ... and Plant The Bomb's defenders' (no field sets its own): until the bomb is armed the attackers keep coming, and
## at 10 s they took 63 % on Depot and 71 % on Woodland (5 s: 56 % and 66 %, bot matches, 6 seeds).
@export var plant_defender_respawn_delay: float = 5.0
## ... but against Hard bots this (s) where a field sets it (data/maps.md Bomb defender respawn at Hard, applied by
## MatchOptions.match_tuning and level_tuning), 0 for the same as every level: on Depot's close sites Hard defenders held
## the bomb off at 5 s (the attackers took 35 %, bot matches, BP10), and a Hard scale on every field put Subway's at 70 %.
@export var plant_defender_respawn_hard: float = 0.0
## Whether the defenders in Attack / Defend and Plant The Bomb may come back at their end's forward spawns too (the
## attackers and either team in Elimination always may).
@export var defender_forward_spawns: bool = true
## A forward spawn with an enemy in play within this many metres of its middle is shut: a pick of it comes back at the
## start area instead (no coming back in someone's sights).
@export var forward_block_radius: float = 15.0
