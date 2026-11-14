class_name PlayerTally
extends RefCounted
## One player's numbers over a match, for its XP and the records (the browser game's stats/matchStats.ts, the player's
## row): hits on opponents, BBs fired and the rounds their team won that they took part in (hit an opponent in it, or
## were still in when it ended). A simulated round counts none of these (its score still counts for the match). Read from each tick's events; round 1's start begins a new match (a rematch too). When
## the match is over, `settle` gives its XP and adds it to the records, once.


## What settling a match did: the XP it gave (null when it gave none, with `why_none`), the levels it reached and the
## bests it beat.
class Settled:
	extends RefCounted
	var earned: MatchXp.Earned = null
	var level_up: Progress.LevelUp = null
	var news: Records.News = null
	## Why the match gave no XP (a translation key); "" when it gave some.
	var why_none: String = ""


var player_id: int = 0
var hits: int = 0
var bbs_fired: int = 0
var rounds_won: int = 0
## The match is over and its winner, or -1 while it is played.
var winner: int = -1
var _hit_this_round: bool = false
## This round's hits and BBs, taken back off the match's when the round is simulated (BP8's SIMULATE).
var _round_hits: int = 0
var _round_bbs: int = 0
var _settled: bool = false


func _init(player: int) -> void:
	player_id = player


## A new match starts: everything back to nothing.
func begin() -> void:
	hits = 0
	bbs_fired = 0
	rounds_won = 0
	winner = -1
	_hit_this_round = false
	_round_hits = 0
	_round_bbs = 0
	_settled = false


## Counts this tick's events (after the tick, before the next clears them).
func on_tick(state: GameState) -> void:
	var me := state.character(player_id)
	if me == null:
		return
	var events := state.events
	for i in events.count:
		var e := events.items[i]
		match e.kind:
			GameEvent.Kind.SHOT:
				if e.actor == player_id:
					bbs_fired += 1
					_round_bbs += 1
			GameEvent.Kind.CHARACTER_HIT:
				if e.actor == player_id:
					var target := state.character(e.target)
					if target != null and target.team != me.team:
						hits += 1
						_round_hits += 1
						_hit_this_round = true
			GameEvent.Kind.ROUND_START:
				# A drawn round 1 played again is the same match.
				if e.value == 1 and state.round_state.draws == 0:
					begin()
				_hit_this_round = false
				_round_hits = 0
				_round_bbs = 0
			GameEvent.Kind.ROUND_OVER:
				# A simulated round (SIMULATE on a skip) keeps its score but gives no XP and sets no records (owner,
				# 2026-11-14): no Round won, and its hits and BBs come off the match's.
				if e.value2 == GameEvent.RoundEnd.SIMULATED:
					hits -= _round_hits
					bbs_fired -= _round_bbs
				elif e.value == me.team and (_hit_this_round or me.status == Character.Status.ALIVE):
					rounds_won += 1
				_round_hits = 0
				_round_bbs = 0
			GameEvent.Kind.MATCH_OVER:
				winner = e.value


func is_over() -> bool:
	return winner >= 0


## Gives the finished match's XP to `progress` and adds it to `records` (null: it isn't one for the records), once (a
## second call gives null). A match off the record (dev content, a Dev setting) gives no XP and isn't a record. `team`
## is the player's, `wins_needed` the match's, `mode` its mode and `difficulty` and `teammate_difficulty` the two
## teams' (&"" with no teammates); `custom`, played under the Custom rule set (its XP capped, MatchXp).
func settle(progress: Progress, records: Records, off_record: bool, team: int, wins_needed: int, mode: String,
		difficulty: StringName, teammate_difficulty: StringName, custom: bool = false) -> Settled:
	if not is_over() or _settled:
		return null
	_settled = true
	var s := Settled.new()
	if off_record:
		s.why_none = "XP_NONE_DEV"
		return s
	var o := MatchXp.Outcome.new()
	o.won = winner == team
	o.rounds_won = rounds_won
	o.hits = hits
	o.wins_needed = wins_needed
	o.difficulty = difficulty
	o.teammate_difficulty = teammate_difficulty
	o.custom = custom
	s.earned = MatchXp.earned(progress.table, o)
	s.level_up = progress.add_xp(s.earned.total)
	if records == null:
		return s
	var r := Records.Result.new()
	r.difficulty = difficulty
	r.mode = mode
	r.won = o.won
	r.hits = hits
	r.bbs_fired = bbs_fired
	s.news = records.add(r)
	return s
