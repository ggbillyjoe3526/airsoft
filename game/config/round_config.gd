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
