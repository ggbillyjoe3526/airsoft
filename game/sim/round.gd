class_name Round
## Match flow in rounds (the browser game's sim/round.ts: Elimination and Attack / Defend; no Extraction yet). Rounds
## against the clock: a team with members but nobody in play loses the round; both out at once is a draw, played again
## under the same number. Elimination: the clock running out with both sides standing puts the overtime flag up at the
## map's spot (OvertimeFlag), and the first team to touch it wins; untouched for OvertimeConfig.time, or on a map with no
## spot, it is a draw too. Attack / Defend (RoundState.mode): the attackers also win by raising their flag on the pole
## (Flag), and the time-out goes to the defenders, after up to FlagConfig.max_overtime while the attackers still work
## the rope. After RoundConfig.reset_delay everyone respawns for the next round, until a team has wins_needed wins and
## a lead of win_by: the match is over until start_match. Ends swap after half_time_after decided rounds, so an uneven
## map is fair over a match. start_match sets a match up before the first tick; step runs once a tick and allocates
## nothing.


## A new match from round 1: scores cleared, fire selectors back to their defaults, every character placed at its team's end and respawned, no BBs in flight,
## and ROUND_START for round 1.
static func start_match(rs: RoundState, characters: Array[Character], ends: Array[MapEnd], pool: BBPool,
		tuning: SimTuning, events: SimEvents) -> void:
	rs.score[0] = 0
	rs.score[1] = 0
	rs.draws = 0
	rs.match_winner = -1
	rs.winner = -1
	rs.reason = GameEvent.RoundEnd.ELIMINATED
	for c in characters:
		c.armament.reset_fire_modes()
		c.armament.reset_hop_ups()
	_start_round(rs, characters, ends, pool, tuning, events, 1)


## One tick (`dt` s) of the round flow: the pause between rounds counting down to the next, or the live round's
## wipe-out check and clock. Nothing moves once the match is over.
static func step(rs: RoundState, characters: Array[Character], ends: Array[MapEnd], pool: BBPool, tuning: SimTuning,
		events: SimEvents, dt: float) -> void:
	if rs.phase == RoundState.Phase.MATCH_OVER:
		return
	if rs.phase == RoundState.Phase.OVER:
		rs.timer -= dt
		# A drawn round is played again (owner, browser audit SIM-19): same number, same ends, so draws never use up the
		# match's rounds or move half time.
		if rs.timer <= 0.0:
			_start_round(rs, characters, ends, pool, tuning, events, rs.number if rs.drawn() else rs.number + 1)
		return
	# Live. A team with members but nobody left in play is wiped out (an empty team never is).
	var alpha := 0
	var beta := 0
	var alpha_in_play := 0
	var beta_in_play := 0
	for c in characters:
		var playing := 1 if Elimination.is_in_play(c) else 0
		if c.team == 0:
			alpha += 1
			alpha_in_play += playing
		else:
			beta += 1
			beta_in_play += playing
	var alpha_out := alpha > 0 and alpha_in_play == 0
	var beta_out := beta > 0 and beta_in_play == 0
	rs.clock = maxf(0.0, rs.clock - dt)
	if alpha_out or beta_out:
		var winner := -1 if alpha_out and beta_out else (1 if alpha_out else 0)
		_end_round(rs, winner, GameEvent.RoundEnd.ELIMINATED, tuning.rounds, events)
	elif rs.mode == RoundState.Mode.ATTACK_DEFEND:
		_step_flag_clock(rs, characters, tuning, events, dt)
	else:
		_step_elimination_clock(rs, characters, tuning, events, dt)


## Attack / Defend once nobody is wiped out: a flag raised (either, on a map with two) wins it for the attackers; at the
## buzzer the defenders win, unless the attackers are working a rope (raising it, or contesting it at the pole): then it
## plays on until they stop or max_overtime has run.
static func _step_flag_clock(rs: RoundState, characters: Array[Character], tuning: SimTuning, events: SimEvents,
		dt: float) -> void:
	if Flag.step_all(rs.flags, characters, rs.attackers, tuning.flag, events, dt):
		_end_round(rs, rs.attackers, GameEvent.RoundEnd.CAPTURED, tuning.rounds, events)
		return
	if rs.clock > 0.0:
		return
	if Flag.rope_worked(rs.flags) and rs.overtime < tuning.flag.max_overtime:
		rs.overtime += dt
	else:
		_end_round(rs, 1 - rs.attackers, GameEvent.RoundEnd.TIME, tuning.rounds, events)


## Elimination once nobody is wiped out: while the overtime flag is up, the first team to touch it wins, and its time
## run out untouched is a draw; at the buzzer the flag goes up at the map's spot (an OVERTIME event at its foot), or on a
## map with no spot, or with its time already out (End the round now), the round is a draw.
static func _step_elimination_clock(rs: RoundState, characters: Array[Character], tuning: SimTuning,
		events: SimEvents, dt: float) -> void:
	var flag := rs.overtime_flag
	if flag.up:
		var taken := flag.step(characters, tuning.overtime, dt)
		if taken >= 0:
			_end_round(rs, taken, GameEvent.RoundEnd.OVERTIME_FLAG, tuning.rounds, events)
		elif flag.left <= 0.0:
			_end_round(rs, -1, GameEvent.RoundEnd.TIME, tuning.rounds, events)
		return
	if rs.clock > 0.0:
		return
	if not rs.has_overtime_spot or flag.left <= 0.0:
		_end_round(rs, -1, GameEvent.RoundEnd.TIME, tuning.rounds, events)
		return
	flag.raise(rs.overtime_spot)
	events.add(GameEvent.Kind.OVERTIME).position = rs.overtime_spot


## Runs a live round's clock and any overtime out, so the next tick ends it as on time by the mode's own rule (the Dev
## tab's End the round now): Elimination's overtime flag doesn't go up for it; if it is up it comes down as a draw,
## unless a team has a hand on it that tick, which takes the round (the touch is checked before the time).
## False when no round is live.
static func run_clock_out(rs: RoundState) -> bool:
	if not rs.is_live():
		return false
	rs.clock = 0.0
	rs.overtime = INF
	rs.overtime_flag.left = 0.0
	return true


## The most a round in `mode` can run past its clock (s): Attack / Defend's rope overtime, or Elimination's flag.
static func longest_overtime(tuning: SimTuning, mode: RoundState.Mode) -> float:
	return tuning.flag.max_overtime if mode == RoundState.Mode.ATTACK_DEFEND else tuning.overtime.time


## Ends the wait between rounds now, so the next tick starts the next round (a click on the round's table). False when
## no round is over and waiting.
static func end_wait(rs: RoundState) -> bool:
	if rs.phase != RoundState.Phase.OVER:
		return false
	rs.timer = 0.0
	return true


## The end of the map (0 or 1) `team` starts from in round `number`. Elimination: Alpha at RoundConfig.first_end,
## Beta at the other. Attack / Defend: the attackers at end 0, the defenders at end 1 by the pole. Either way swapped
## after half_time_after rounds.
static func team_end(team: int, number: int, rounds: RoundConfig, mode: RoundState.Mode = RoundState.Mode.ELIMINATION,
		first_attackers: int = 0) -> int:
	if mode == RoundState.Mode.ATTACK_DEFEND:
		return 0 if team == attackers_in_round(number, rounds, first_attackers) else 1
	var alpha_end := rounds.first_end if number <= rounds.half_time_after else 1 - rounds.first_end
	return alpha_end if team == 0 else 1 - alpha_end


## Attack / Defend: the team attacking in round `number`, `first_attackers` until half time, then the other.
static func attackers_in_round(number: int, rounds: RoundConfig, first_attackers: int) -> int:
	return first_attackers if number <= rounds.half_time_after else 1 - first_attackers


## Whether `winner`, with `score`, has taken the match: wins_needed round wins and a lead of at least win_by.
static func match_won(score: PackedInt32Array, winner: int, rounds: RoundConfig) -> bool:
	var mine := score[winner]
	return mine >= rounds.wins_needed and mine - score[1 - winner] >= rounds.win_by


## Gives every character this round's end and, where the map has spawns there, the spawn of its place among its
## teammates (in character order), resting BodyConfig.rest_gap above the floor. A team smaller than its end's spawn
## line takes the middle of it (browser M20: a 1v1 starts from the middle spawn at both ends). Call respawn() after.
static func place_teams(rs: RoundState, characters: Array[Character], ends: Array[MapEnd], tuning: SimTuning) -> void:
	var alpha_size := 0
	var beta_size := 0
	for c in characters:
		if c.team == 0:
			alpha_size += 1
		else:
			beta_size += 1
	var alpha_slot := 0
	var beta_slot := 0
	for c in characters:
		c.end = team_end(c.team, rs.number, tuning.rounds, rs.mode, rs.first_attackers)
		var size := alpha_size if c.team == 0 else beta_size
		var place := alpha_slot if c.team == 0 else beta_slot
		if c.team == 0:
			alpha_slot += 1
		else:
			beta_slot += 1
		if c.end >= ends.size() or ends[c.end] == null:
			continue
		var spawns := ends[c.end].spawns
		if spawns.is_empty():
			continue
		# A team larger than its spawn line (map data the loader should refuse) doubles up from the start of it rather than
		# keeping a spawn from another end.
		var slot := (maxi(0, floori((spawns.size() - size) / 2.0)) + place) % spawns.size()
		var s := spawns[slot]
		c.spawn_position = s.position + Vector3(0.0, tuning.body.rest_gap, 0.0)
		c.spawn_yaw = s.yaw


static func _end_round(rs: RoundState, winner: int, reason: GameEvent.RoundEnd, rounds: RoundConfig,
		events: SimEvents) -> void:
	rs.winner = winner
	rs.reason = reason
	var over := events.add(GameEvent.Kind.ROUND_OVER)
	over.value = winner
	over.value2 = reason
	if rs.drawn():
		rs.draws += 1
	else:
		rs.score[winner] += 1
		if match_won(rs.score, winner, rounds):
			rs.phase = RoundState.Phase.MATCH_OVER
			rs.match_winner = winner
			events.add(GameEvent.Kind.MATCH_OVER).value = winner
			return
	rs.phase = RoundState.Phase.OVER
	rs.timer = rounds.reset_delay


static func _start_round(rs: RoundState, characters: Array[Character], ends: Array[MapEnd], pool: BBPool,
		tuning: SimTuning, events: SimEvents, number: int) -> void:
	rs.number = number
	rs.phase = RoundState.Phase.LIVE
	rs.clock = tuning.rounds.round_time
	rs.timer = 0.0
	rs.overtime = 0.0
	rs.attackers = attackers_in_round(number, tuning.rounds, rs.first_attackers) \
			if rs.mode == RoundState.Mode.ATTACK_DEFEND else -1
	rs.reset_flags()
	rs.overtime_flag.reset(tuning.overtime)
	place_teams(rs, characters, ends, tuning)
	for c in characters:
		c.respawn()
	if pool != null:
		for bb in pool.bbs:
			bb.active = false
	events.add(GameEvent.Kind.ROUND_START).value = number
