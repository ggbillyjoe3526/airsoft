extends GutTest
## Elimination's overtime flag (game/sim/overtime_flag.gd and Round, OV1), ported from the browser game's
## sim/overtimeFlag.test.ts and overtimeFlag.edges.test.ts: a clock run out with both teams in play puts the flag up at
## the map's spot, and the first team to touch it wins the round. Contested, nobody takes it; untouched for its time, a
## draw played again (this game has no more-players time-out rule, so the browser's cases under it are left out); a
## wipe-out still ends it. Attack / Defend, practice and a map with no spot play as before.

const DT := 1.0 / 60.0
const SPOT := Vector3(0.0, 0.0, 0.0)
const POLE := Vector3(10.0, 0.0, 0.0)

var tuning: SimTuning
var cfg: OvertimeConfig
var ends: Array[MapEnd]
var events: SimEvents
var rs: RoundState
var cs: Array[Character]
## Every event seen by _run, as (kind, value, value2), and every OVERTIME event's position.
var seen: Array[Vector3i] = []
var raised_at: Array[Vector3] = []


func before_each() -> void:
	tuning = SimTuning.new()
	tuning.body.rest_gap = 0.0
	tuning.rounds.round_time = 5.0
	tuning.rounds.reset_delay = 2.0
	tuning.rounds.wins_needed = 3
	tuning.rounds.win_by = 1
	tuning.rounds.half_time_after = 2
	tuning.rounds.first_end = 0
	cfg = tuning.overtime
	# Two spawns at each end: west (end 0, z 0 and 1) and east (end 1, z 2 and 3), far from the flag.
	ends = [_end(-20.0, [0.0, 1.0]), _end(20.0, [2.0, 3.0])]
	events = SimEvents.new()
	rs = RoundState.new()
	rs.has_overtime_spot = true
	rs.overtime_spot = SPOT
	rs.pole = POLE
	cs = _teams()
	seen.clear()
	raised_at.clear()


func _end(x: float, zs: Array[float]) -> MapEnd:
	var e := MapEnd.new()
	for z in zs:
		e.spawns.append(SpawnPoint.new(Vector3(x, 0.0, z), 0.0))
	return e


## Two a side: Alpha (0, 1) at the west end and Beta (2, 3) at the east.
func _teams() -> Array[Character]:
	var out: Array[Character] = []
	var loadout: Array[ReplicaConfig] = []
	for id in 4:
		out.append(Character.new(id, 0 if id < 2 else 1, Vector3.ZERO, 0.0, loadout))
	return out


func _start() -> void:
	events.clear()
	Round.start_match(rs, cs, ends, null, tuning, events)
	_record()


func _run(seconds: float) -> void:
	for i in roundi(seconds / DT):
		events.clear()
		Round.step(rs, cs, ends, null, tuning, events, DT)
		_record()


func _record() -> void:
	for i in events.count:
		var e := events.items[i]
		seen.append(Vector3i(e.kind, e.value, e.value2))
		if e.kind == GameEvent.Kind.OVERTIME:
			raised_at.append(e.position)


func _count(kind: GameEvent.Kind) -> int:
	var n := 0
	for e in seen:
		if e.x == kind:
			n += 1
	return n


func _over(winner: int, reason: GameEvent.RoundEnd) -> bool:
	return seen.has(Vector3i(GameEvent.Kind.ROUND_OVER, winner, reason))


## A round played to its buzzer with nobody touching anything: the flag goes up on the last tick.
func _to_overtime() -> void:
	_start()
	_run(tuning.rounds.round_time + DT)


static func _put(c: Character, x: float, z: float, y: float = 0.0) -> void:
	c.position = Vector3(x, y, z)


func test_the_config_is_the_browsers_and_in_the_games_tuning() -> void:
	assert_eq([cfg.time, cfg.reach, cfg.reach_height], [30.0, 1.0, 1.0])
	var game := SimTuning.load_default()
	assert_not_null(game.overtime, "sim_tuning.tres carries OvertimeConfig")
	assert_eq(game.overtime.time, 30.0)


func test_goes_up_when_the_clock_runs_out_with_nobody_out_at_the_spot_once_with_no_result_yet() -> void:
	_to_overtime()
	assert_true(rs.is_live())
	assert_true(rs.overtime_flag.up)
	assert_eq(rs.overtime_flag.foot, SPOT)
	assert_eq(raised_at, [SPOT] as Array[Vector3], "one OVERTIME event, at the foot")
	assert_eq(_count(GameEvent.Kind.ROUND_OVER), 0)


func test_goes_up_with_one_team_a_player_short_too_there_is_no_more_players_rule() -> void:
	_start()
	cs[3].status = Character.Status.OUT
	_run(tuning.rounds.round_time + DT)
	assert_true(rs.overtime_flag.up, "a lead in players takes nothing at the buzzer")


func test_never_on_a_map_with_no_spot_a_draw_at_once_as_before() -> void:
	rs.has_overtime_spot = false
	_to_overtime()
	assert_false(rs.overtime_flag.up)
	assert_eq(_count(GameEvent.Kind.OVERTIME), 0)
	assert_true(_over(-1, GameEvent.RoundEnd.TIME))
	assert_eq(rs.draws, 1)


func test_never_in_attack_defend_the_defenders_win_on_time_as_before() -> void:
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	_start()
	_run(tuning.rounds.round_time + DT)
	assert_true(_over(1, GameEvent.RoundEnd.TIME), "nobody at the pole: the defenders (Beta) win at the buzzer")
	_run(tuning.rounds.reset_delay + tuning.rounds.round_time + Round.longest_overtime(tuning, rs.mode))
	assert_false(rs.overtime_flag.up)
	assert_eq(_count(GameEvent.Kind.OVERTIME), 0)


func test_never_in_practice() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var state := GameState.new(1, tuning)
	state.round_state.practice = true
	state.round_state.has_overtime_spot = true
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	sim.start_match(state)
	var cmds: Array[PlayerCommand] = [PlayerCommand.new()]
	var raised := 0
	for i in roundi((tuning.rounds.round_time + cfg.time + 1.0) / DT):
		sim.step(state, cmds, DT)
		raised += state.events.count_of(GameEvent.Kind.OVERTIME)
	assert_eq(raised, 0)
	assert_false(state.round_state.overtime_flag.up)
	assert_true(state.round_state.is_live(), "practice has no rounds")


func test_a_seeded_match_that_never_reaches_overtime_plays_the_same_with_a_spot_or_without() -> void:
	tuning.rounds.round_time = 120.0
	var a := _fight(true)
	var b := _fight(false)
	assert_eq(a.round_state.number, b.round_state.number)
	assert_gt(a.round_state.number + a.round_state.draws, 1, "rounds were decided by hits")
	assert_eq(a.round_state.score, b.round_state.score)
	assert_eq(a.tick, b.tick)
	for i in a.characters.size():
		assert_eq(a.characters[i].position, b.characters[i].position)
		assert_eq(a.characters[i].status, b.characters[i].status)
	assert_false(a.round_state.overtime_flag.up)


## Two a side on a BoxWorld field shooting at each other for 40 s, seed 3, with or without a spot for the flag.
func _fight(spot: bool) -> GameState:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var state := GameState.new(3, tuning)
	state.round_state.has_overtime_spot = spot
	state.round_state.overtime_spot = SPOT
	for i in 4:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	sim.start_match(state)
	var cmds: Array[PlayerCommand] = []
	for c in state.characters:
		cmds.append(PlayerCommand.new())
	for t in roundi(40.0 / DT):
		for c in state.characters:
			var foe := state.characters[(c.id + 1) % state.characters.size()]
			var d := foe.position + Vector3(0.0, 1.3, 0.0) - c.eye(tuning.body)
			cmds[c.id].reset(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
			cmds[c.id].fire = t % 20 < 10
			cmds[c.id].reload = c.armament.mag() == 0
		sim.step(state, cmds, DT)
	return state


func test_the_first_team_with_a_hand_on_it_wins_at_once_and_it_stays_up_through_the_pause() -> void:
	_to_overtime()
	_put(cs[2], SPOT.x + cfg.reach * 0.9, SPOT.z)
	_run(DT)
	assert_true(_over(1, GameEvent.RoundEnd.OVERTIME_FLAG))
	assert_eq(rs.score, PackedInt32Array([0, 1]))
	assert_eq(rs.reason, GameEvent.RoundEnd.OVERTIME_FLAG)
	assert_true(rs.overtime_flag.up, "up through the pause, the winner's")
	_run(tuning.rounds.reset_delay + DT)
	assert_true(rs.is_live())
	assert_false(rs.overtime_flag.up, "down again for the next round")
	assert_eq(rs.overtime_flag.left, cfg.time, "with all its time")


func test_both_teams_at_it_hold_each_other_off_and_its_time_still_runs() -> void:
	_to_overtime()
	_put(cs[0], SPOT.x - 0.5, SPOT.z)
	_put(cs[3], SPOT.x + 0.5, SPOT.z)
	var left := rs.overtime_flag.left
	_run(1.0)
	assert_true(rs.is_live())
	assert_true(rs.overtime_flag.contested)
	assert_almost_eq(rs.overtime_flag.left, left - 1.0, 0.001)
	# One of them hit: the other has it.
	cs[3].status = Character.Status.CALLING
	_run(DT)
	assert_true(_over(0, GameEvent.RoundEnd.OVERTIME_FLAG))


func test_only_a_player_in_play_counts_within_reach_and_on_its_floor() -> void:
	var flag := OvertimeFlag.new()
	flag.reset(cfg)
	flag.raise(SPOT)
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, [] as Array[ReplicaConfig])
	_put(c, cfg.reach, 0.0)
	assert_true(flag.touched_by(c, cfg), "at the edge of its reach")
	_put(c, cfg.reach + 0.05, 0.0)
	assert_false(flag.touched_by(c, cfg))
	_put(c, 0.0, 0.0, cfg.reach_height + 0.5)
	assert_false(flag.touched_by(c, cfg), "the floor above")
	_put(c, 0.0, 0.0, -cfg.reach_height - 0.5)
	assert_false(flag.touched_by(c, cfg), "the floor below")
	_put(c, 0.0, 0.0)
	c.status = Character.Status.CALLING
	assert_false(flag.touched_by(c, cfg), "calling a hit")
	assert_eq(flag.step([c] as Array[Character], cfg, DT), -1)


func test_a_wipe_out_in_overtime_still_ends_the_round_as_a_wipe_out() -> void:
	_to_overtime()
	cs[0].status = Character.Status.OUT
	cs[1].status = Character.Status.OUT
	_run(DT)
	assert_true(_over(1, GameEvent.RoundEnd.ELIMINATED))


func test_untouched_when_its_time_is_up_a_draw_played_again() -> void:
	_to_overtime()
	_run(cfg.time - 0.5)
	assert_true(rs.is_live())
	_run(0.5 + DT)
	assert_true(_over(-1, GameEvent.RoundEnd.TIME))
	assert_eq(rs.draws, 1)


func test_end_the_round_now_before_the_buzzer_keeps_the_flag_down_and_during_it_ends_as_on_time() -> void:
	_start()
	assert_true(Round.run_clock_out(rs))
	_run(DT)
	assert_false(rs.overtime_flag.up)
	assert_true(_over(-1, GameEvent.RoundEnd.TIME))
	seen.clear()
	_run(tuning.rounds.reset_delay + DT)
	_run(tuning.rounds.round_time + DT)
	assert_true(rs.overtime_flag.up, "the next round's flag has all its time again")
	assert_true(Round.run_clock_out(rs))
	_run(DT)
	assert_true(_over(-1, GameEvent.RoundEnd.TIME))


func test_end_the_round_now_during_the_flag_keeps_only_its_played_time_for_the_table() -> void:
	_to_overtime()
	_run(5.0)
	assert_true(Round.run_clock_out(rs))
	_run(DT)
	assert_true(_over(-1, GameEvent.RoundEnd.TIME))
	assert_true(rs.overtime_flag.up, "the flag stays up through the pause")
	assert_almost_eq(cfg.time - rs.overtime_flag.left, 5.0 + DT, 2.0 * DT, "only the flag's played time counts")
	_run(tuning.rounds.reset_delay + DT)
	assert_false(rs.overtime_flag.cut, "the next round's flag is whole again")


func test_a_round_lasts_at_most_its_clock_and_its_overtime() -> void:
	assert_eq(Round.longest_overtime(tuning, RoundState.Mode.ELIMINATION), cfg.time)
	assert_eq(Round.longest_overtime(tuning, RoundState.Mode.ATTACK_DEFEND), tuning.flag.max_overtime)
	_to_overtime()
	_run(cfg.time + DT) # a tick's slack for the clock's own rounding
	assert_false(rs.is_live())


# The edges (overtimeFlag.edges.test.ts).

func test_a_touch_that_takes_a_team_to_its_last_win_ends_the_match_and_the_flag_stays_up() -> void:
	tuning.rounds.wins_needed = 2
	_start()
	rs.score[1] = tuning.rounds.wins_needed - 1
	_run(tuning.rounds.round_time + DT)
	assert_true(rs.overtime_flag.up)
	_put(cs[3], 0.3, 0.0)
	_run(DT)
	assert_eq(rs.phase, RoundState.Phase.MATCH_OVER)
	assert_eq(rs.match_winner, 1)
	assert_eq(rs.reason, GameEvent.RoundEnd.OVERTIME_FLAG)
	assert_true(rs.overtime_flag.up)


func test_a_drawn_overtime_replays_the_same_round_with_the_flag_down_and_up_again_at_the_next_buzzer() -> void:
	_start()
	_run(tuning.rounds.round_time + cfg.time + 0.5)
	assert_eq(rs.phase, RoundState.Phase.OVER)
	assert_eq(rs.reason, GameEvent.RoundEnd.TIME)
	assert_true(rs.overtime_flag.up, "up through the pause")
	assert_lte(rs.overtime_flag.left, 0.0)
	var number := rs.number
	_run(tuning.rounds.reset_delay + 0.2)
	assert_true(rs.is_live())
	assert_eq(rs.number, number, "a draw is played again under the same number")
	assert_false(rs.overtime_flag.up)
	assert_eq(rs.overtime_flag.left, cfg.time)
	assert_gt(rs.clock, tuning.rounds.round_time - 1.0)
	_run(tuning.rounds.round_time + 0.2)
	assert_eq(_count(GameEvent.Kind.OVERTIME), 2, "an event each time it goes up")


func test_both_teams_already_at_the_spot_when_it_goes_up_contest_it_at_once() -> void:
	_start()
	_put(cs[0], 0.4, 0.0)
	_put(cs[2], -0.4, 0.0)
	_run(tuning.rounds.round_time + 0.5)
	assert_true(rs.overtime_flag.contested)
	assert_true(rs.is_live())
	assert_eq(_count(GameEvent.Kind.ROUND_OVER), 0)


func test_a_team_knocked_out_of_a_contest_leaves_the_flag_to_the_survivor() -> void:
	_start()
	_put(cs[0], 0.4, 0.0)
	_put(cs[2], -0.4, 0.0)
	_run(tuning.rounds.round_time + 0.5)
	cs[2].status = Character.Status.CALLING
	_run(DT)
	assert_true(_over(0, GameEvent.RoundEnd.OVERTIME_FLAG))


func test_a_tick_with_the_flag_up_allocates_nothing() -> void:
	cfg.time = 1000.0
	_to_overtime()
	_put(cs[0], 0.4, 0.0)
	_put(cs[2], -0.4, 0.0)
	_run(1.0)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 600:
		events.clear()
		Round.step(rs, cs, ends, null, tuning, events, DT)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
	assert_true(rs.overtime_flag.up and rs.overtime_flag.contested and rs.is_live())
