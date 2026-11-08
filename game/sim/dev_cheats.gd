class_name DevCheats
extends RefCounted
## The Dev settings that change play (the browser game's config/dev.ts devCheating), as the simulation takes them. A
## match played with any of them on is kept out of the records for the rest of that match (docs/DECISIONS.md › Content
## tags and dev content): `GameState.off_record`. Ghost and bottomless magazines are the player's own, written onto
## their character; Lasers is everyone's (Character.lasers: the player's and every bot's replica); the bots' controller
## reads `bots_hold_fire` and `bots_run_low` (run_low); the play loop reads `game_speed`.

const SPEED_MIN := 0.25
const SPEED_MAX := 2.0

## Simulated time per real second (1: as normal); the simulation still steps a fixed 60 Hz tick.
var game_speed: float = 1.0
var bottomless: bool = false
var ghost: bool = false
var bots_hold_fire: bool = false
## Bots run low on BBs (MH2): some time into each round one bot a team in turn is put on its last magazine (run_low), so
## the magazine hand-off can be watched.
var bots_run_low: bool = false
## A cheat that only changes what you see or follow (spectate any bot, bot intentions): no rule changes, but the
## match still stays out of the records.
var watching: bool = false
## Lasers (LZ1, the Easter egg): everyone's replica fires lasers, instant hits, instead of BBs (Character.lasers).
var lasers: bool = false
## Disable levelling: every item unlocked to carry, so the match gives no XP (the loadout reads it, not the rules).
var levelling_off: bool = false


## Any cheat on.
func any() -> bool:
	return game_speed != 1.0 or bottomless or ghost or bots_hold_fire or bots_run_low or watching or levelling_off \
			or lasers


## Puts `cheats` into `state` (a copy is kept): the player `player_id`'s ghost and bottomless magazines, the rest read
## from `state.cheats`; and a cheat on now marks the match off the record. Switching Bottomless on fills the magazine in
## hand, so one already run dry fires at once instead of clicking until a reload (DV2).
static func apply(state: GameState, cheats: DevCheats, player_id: int) -> void:
	var kept := state.cheats
	kept.game_speed = clampf(cheats.game_speed, SPEED_MIN, SPEED_MAX)
	kept.bottomless = cheats.bottomless
	kept.ghost = cheats.ghost
	kept.bots_hold_fire = cheats.bots_hold_fire
	kept.bots_run_low = cheats.bots_run_low
	kept.watching = cheats.watching
	kept.levelling_off = cheats.levelling_off
	kept.lasers = cheats.lasers
	for c in state.characters:
		var mine := c.id == player_id
		c.ghost = mine and kept.ghost
		c.lasers = kept.lasers
		var switched_on := mine and kept.bottomless and not c.armament.bottomless
		c.armament.bottomless = mine and kept.bottomless
		if switched_on:
			c.armament.top_up_in_hand()
	if kept.any():
		state.off_record = true


## The Dev tab's End the round now: the live round's clock runs out (Round.run_clock_out) and the match stays out of the
## records. False when no round is live.
static func end_round(state: GameState) -> bool:
	if not Round.run_clock_out(state.round_state):
		return false
	state.off_record = true
	return true


## Bots run low on BBs: in the round under way, one character a team in turn (by round, in id order), leaving out
## `player_id`, is put on its last magazine: every spare for its primary emptied (the magazine in it kept). The
## bots' controller calls it, once a round (BotController.think).
static func run_low(state: GameState, player_id: int) -> void:
	for team in 2:
		var pick := low_pick(state, team, player_id)
		if pick != null and not pick.armament.ammo.is_empty():
			pick.armament.ammo[0].pouch.fill(0) # slot 0: the primary


## Whom run_low puts low on `team` this round: its characters but `player_id`, in id order, the round's turn of them
## (round 1 the first); null if the team has none.
static func low_pick(state: GameState, team: int, player_id: int) -> Character:
	var count := 0
	for c in state.characters:
		if c.team == team and c.id != player_id:
			count += 1
	if count == 0:
		return null
	var turn := (state.round_state.number - 1) % count
	for c in state.characters:
		if c.team == team and c.id != player_id:
			if turn == 0:
				return c
			turn -= 1
	return null
