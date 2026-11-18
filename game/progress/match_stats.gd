class_name MatchStats
extends RefCounted
## Every player's numbers for the match so far and for the round in play, or the one just played (the browser game's
## stats/matchStats.ts), read from each tick's events: what the scoreboard, the round result and the match summary show.
## Reads the simulation, never writes it. Round 1's start begins a new match (a rematch too), unless it is a drawn
## round 1 played again.


## One player's numbers over a round or a match.
class Stats:
	extends RefCounted
	## Opponents this player's BBs hit.
	var hits: int = 0
	## Times this player was hit (at most once a round).
	var times_hit: int = 0
	## Teammates this player's BBs hit.
	var friendly_hits: int = 0
	var bbs_fired: int = 0
	## Seconds in play while rounds were live.
	var time_in_play: float = 0.0
	## Who hit this player last (their BB, or their own bounced one), -1 if nobody yet.
	var hit_by: int = -1

	func clear() -> void:
		hits = 0
		times_hit = 0
		friendly_hits = 0
		bbs_fired = 0
		time_in_play = 0.0
		hit_by = -1

	## The share of BBs fired that hit an opponent (0..1), or -1 before the first BB. Friendly hits don't count.
	func accuracy() -> float:
		return float(hits) / bbs_fired if bbs_fired > 0 else -1.0


## Goes up whenever a count changes (not the time in play): a table redraws on it.
var version: int = 0
## By character id.
var _match: Array[Stats] = []
var _round: Array[Stats] = []
var _rounds_won_with: PackedInt32Array = PackedInt32Array()
## What an unknown id reads (shared: callers only read what these functions return).
var _empty: Stats = Stats.new()


## `id`'s numbers over the match so far (all zero for an id it doesn't know).
func match_of(id: int) -> Stats:
	return _match[id] if id >= 0 and id < _match.size() else _empty


## `id`'s numbers in the round in play, or the one just played while the next waits.
func round_of(id: int) -> Stats:
	return _round[id] if id >= 0 and id < _round.size() else _empty


## Rounds `id`'s team won with `id` taking part: an opponent hit in the round, or still in play (or waiting to come
## back, RS1) at its end.
func rounds_won_with(id: int) -> int:
	return _rounds_won_with[id] if id >= 0 and id < _rounds_won_with.size() else 0


## Counts the tick of `dt` seconds just stepped, while its events are still in `state`.
func after_tick(state: GameState, dt: float) -> void:
	_fit(state)
	var started := false
	var events := state.events
	for i in events.count:
		var e := events.items[i]
		match e.kind:
			GameEvent.Kind.ROUND_START:
				if e.value == 1 and state.round_state.draws == 0:
					_reset()
				for s in _round:
					s.clear()
				started = true
				version += 1
			GameEvent.Kind.SHOT:
				_add_shot(e.actor)
			GameEvent.Kind.CHARACTER_HIT:
				_add_hit(state, e.actor, e.target)
			GameEvent.Kind.ROUND_OVER:
				for c in state.characters:
					# Waiting to come back (RS1) counts as on the team when it wins (BP10).
					if c.team == e.value and (_round[c.id].hits > 0 or Elimination.is_in_play(c)
							or Respawns.waiting(c)):
						_rounds_won_with[c.id] += 1
				version += 1
	# Time in play counts live play only: not the wait between rounds, nor the tick that set up a new round.
	if started or not state.round_state.is_live():
		return
	for c in state.characters:
		if Elimination.is_in_play(c):
			_match[c.id].time_in_play += dt
			_round[c.id].time_in_play += dt


## Room for every character id in `state` (a match's characters are fixed, so this grows once).
func _fit(state: GameState) -> void:
	var n := 0
	for c in state.characters:
		n = maxi(n, c.id + 1)
	while _match.size() < n:
		_match.append(Stats.new())
		_round.append(Stats.new())
	if _rounds_won_with.size() < n:
		_rounds_won_with.resize(n)


func _reset() -> void:
	for s in _match:
		s.clear()
	_rounds_won_with.fill(0)


func _add_shot(id: int) -> void:
	if id < 0 or id >= _match.size():
		return
	_match[id].bbs_fired += 1
	_round[id].bbs_fired += 1
	version += 1


func _add_hit(state: GameState, shooter_id: int, victim_id: int) -> void:
	var victim := state.character(victim_id)
	var shooter := state.character(shooter_id)
	if victim == null:
		return
	_match[victim_id].times_hit += 1
	_round[victim_id].times_hit += 1
	_match[victim_id].hit_by = shooter_id
	_round[victim_id].hit_by = shooter_id
	version += 1
	# Your own bounced BB is a time you were hit, not a hit on anyone.
	if shooter == null or shooter_id == victim_id:
		return
	if shooter.team == victim.team:
		_match[shooter_id].friendly_hits += 1
		_round[shooter_id].friendly_hits += 1
	else:
		_match[shooter_id].hits += 1
		_round[shooter_id].hits += 1
