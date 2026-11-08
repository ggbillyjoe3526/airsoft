extends GutTest
## Attack / Defend (game/sim/flag.gd and round.gd's flag mode), ported from the browser game's sim/flag.test.ts and
## round.test.ts flag cases: the rope, the flag raised winning for the attackers, the time-out for the defenders with
## overtime while the rope is worked, and the ends. Characters are put at the pole by hand.

const DT := 1.0 / 60.0
const POLE := Vector3(20.0, 0.0, 5.0)

var tuning: SimTuning
var rules: RoundConfig
var flag_cfg: FlagConfig
var ends: Array[MapEnd]
var events: SimEvents
var rs: RoundState
var cs: Array[Character]
## Every event seen by _run, as (kind, value, value2).
var seen: Array[Vector3i] = []


func before_each() -> void:
	tuning = SimTuning.new()
	rules = tuning.rounds
	rules.round_time = 10.0
	rules.reset_delay = 2.0
	rules.wins_needed = 3
	rules.half_time_after = 2
	flag_cfg = tuning.flag
	# The raise wins at once here; the hold after it (BP8) is test_bp8_match.gd's.
	flag_cfg.hold_time = 0.0
	ends = [_end(-20.0, [0.0, 1.0]), _end(20.0, [2.0, 3.0])]
	events = SimEvents.new()
	rs = RoundState.new()
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	rs.pole = POLE
	cs = []
	var loadout: Array[ReplicaConfig] = []
	for id in 4:
		cs.append(Character.new(id, 0 if id < 2 else 1, Vector3.ZERO, 0.0, loadout))
	seen.clear()


func _end(x: float, zs: Array[float]) -> MapEnd:
	var e := MapEnd.new()
	for z in zs:
		e.spawns.append(SpawnPoint.new(Vector3(x, 0.0, z), 0.0))
	return e


func _start() -> void:
	events.clear()
	Round.start_match(rs, cs, ends, null, tuning, events)


func _run(seconds: float) -> void:
	for i in ceili(seconds / DT - 1e-6):
		events.clear()
		Round.step(rs, cs, ends, null, tuning, events, DT)
		for j in events.count:
			var e := events.items[j]
			seen.append(Vector3i(e.kind, e.value, e.value2))


func _count(kind: GameEvent.Kind, value: int) -> int:
	var n := 0
	for e in seen:
		if e.x == kind and e.y == value:
			n += 1
	return n


func _to_pole(id: int) -> void:
	cs[id].position = POLE + Vector3(flag_cfg.radius - 0.1, 0.0, 0.0)


func _away(id: int) -> void:
	cs[id].position = POLE + Vector3(-10.0, 0.0, 0.0)


func test_the_attackers_start_at_end_0_the_defenders_by_the_pole_and_they_swap_at_half_time() -> void:
	_start()
	assert_eq(rs.attackers, 0, "Alpha attacks first")
	assert_eq([cs[0].end, cs[2].end], [0, 1])
	assert_eq(rs.flag.position, POLE)
	for n: int in [1, 2, 3]:
		var attackers := Round.attackers_in_round(n, rules, 0)
		assert_eq(attackers, 0 if n <= rules.half_time_after else 1, "round %d" % n)
		assert_eq(Round.team_end(attackers, n, rules, rs.mode, 0), 0, "the attackers at end 0 in round %d" % n)
		assert_eq(Round.team_end(1 - attackers, n, rules, rs.mode, 0), 1)
	rs.first_attackers = 1
	_start()
	assert_eq(rs.attackers, 1, "your team pick decides who attacks first")
	assert_eq([cs[0].end, cs[2].end], [1, 0])


func test_attackers_at_the_pole_raise_the_flag_in_raise_time_with_a_rope_step_each_twelfth_and_win() -> void:
	_start()
	_away(1)
	_away(2)
	_away(3)
	_to_pole(0)
	_run(flag_cfg.raise_time - 0.5)
	assert_true(rs.is_live())
	assert_eq(rs.flag.status, FlagState.Status.RAISING)
	assert_almost_eq(rs.flag.progress, (flag_cfg.raise_time - 0.5) / flag_cfg.raise_time, 0.01)
	_run(0.6)
	assert_false(rs.is_live(), "raised")
	assert_eq(rs.winner, 0)
	assert_eq(rs.reason, GameEvent.RoundEnd.CAPTURED)
	assert_eq(rs.score[0], 1)
	assert_eq(_count(GameEvent.Kind.FLAG_ROPE, 1), roundi(1.0 / flag_cfg.rope_step), "a ratchet each step up")


func test_defenders_pull_it_down_quicker_and_an_empty_pole_is_idle() -> void:
	_start()
	_away(1)
	_away(3)
	_to_pole(0)
	_away(2)
	_run(flag_cfg.raise_time * 0.6)
	_away(0)
	_to_pole(2)
	_run(flag_cfg.lower_time * 0.3)
	assert_eq(rs.flag.status, FlagState.Status.LOWERING)
	assert_almost_eq(rs.flag.progress, 0.3, 0.02)
	assert_gt(_count(GameEvent.Kind.FLAG_ROPE, 0), 0, "a ratchet coming down")
	_run(flag_cfg.lower_time)
	assert_eq(rs.flag.progress, 0.0)
	assert_eq(rs.flag.status, FlagState.Status.IDLE, "nothing to pull at the bottom")
	_away(2)
	_to_pole(0)
	_run(1.0)
	_away(0)
	var left := rs.flag.progress
	_run(1.0)
	assert_eq(rs.flag.progress, left, "nobody at the pole: it stays")
	assert_eq(rs.flag.status, FlagState.Status.IDLE)


func test_both_teams_at_the_pole_hold_it_still_and_someone_out_or_out_of_reach_works_nothing() -> void:
	_start()
	_to_pole(0)
	_to_pole(2)
	_away(1)
	_away(3)
	_run(1.0)
	assert_eq(rs.flag.status, FlagState.Status.CONTESTED)
	assert_eq(rs.flag.progress, 0.0)
	cs[2].status = Character.Status.CALLING
	_run(1.0)
	assert_eq(rs.flag.status, FlagState.Status.RAISING, "a hit defender is out of it")
	cs[0].position = POLE + Vector3(flag_cfg.radius + 0.1, 3.0, 0.0)
	var held := rs.flag.progress
	_run(0.5)
	assert_eq(rs.flag.progress, held, "a step beyond reach")


func test_the_time_out_goes_to_the_defenders() -> void:
	_start()
	for id in 4:
		_away(id)
	_run(rules.round_time + DT)
	assert_false(rs.is_live())
	assert_eq(rs.winner, 1, "the defenders hold out")
	assert_eq(rs.reason, GameEvent.RoundEnd.TIME)


func test_attackers_on_the_rope_at_the_buzzer_play_on_to_finish_the_raise() -> void:
	_start()
	for id in 4:
		_away(id)
	_run(rules.round_time - 2.0)
	_to_pole(0)
	_run(2.0 + 1.0)
	assert_true(rs.is_live(), "overtime while they raise")
	assert_gt(rs.overtime, 0.0)
	_run(flag_cfg.raise_time)
	assert_eq(rs.winner, 0)
	assert_eq(rs.reason, GameEvent.RoundEnd.CAPTURED)


func test_overtime_ends_when_the_attackers_stop_or_at_max_overtime() -> void:
	_start()
	for id in 4:
		_away(id)
	_run(rules.round_time + 0.5)
	assert_false(rs.is_live(), "nobody on the rope at the buzzer: over at once")
	assert_eq(rs.winner, 1)
	# A contested pole at the buzzer still plays on, but for max_overtime at most.
	flag_cfg.raise_time = 1000.0
	_run(rules.reset_delay + 0.1)
	assert_true(rs.is_live())
	_to_pole(cs.find(_attacker()))
	_to_pole(2 if rs.attackers == 0 else 0)
	_run(rules.round_time + 1.0)
	assert_true(rs.is_live(), "contested at the buzzer: overtime")
	_run(flag_cfg.max_overtime)
	assert_false(rs.is_live(), "no longer than max_overtime")
	assert_eq(rs.winner, 1 - rs.attackers)
	assert_eq(rs.reason, GameEvent.RoundEnd.TIME)


func _attacker() -> Character:
	for c in cs:
		if c.team == rs.attackers:
			return c
	return null


func test_ending_the_round_now_ends_it_even_in_overtime() -> void:
	_start()
	for id in 4:
		_away(id)
	_run(rules.round_time - 0.5)
	_to_pole(0)
	_run(1.0)
	assert_true(rs.is_live())
	assert_true(Round.run_clock_out(rs))
	_run(DT)
	assert_false(rs.is_live())
	assert_eq(rs.winner, 1)


func test_a_wipe_out_still_decides_the_round_and_elimination_never_works_the_flag() -> void:
	_start()
	_to_pole(0)
	cs[0].status = Character.Status.OUT
	cs[1].status = Character.Status.OUT
	_run(DT)
	assert_eq(rs.winner, 1)
	assert_eq(rs.reason, GameEvent.RoundEnd.ELIMINATED)
	rs.mode = RoundState.Mode.ELIMINATION
	_start()
	assert_eq(rs.attackers, -1)
	_to_pole(0)
	_to_pole(1)
	_run(flag_cfg.raise_time + 1.0)
	assert_eq(rs.flag.progress, 0.0, "no flag in Elimination")
	assert_true(rs.is_live())


func test_every_map_has_its_pole_by_end_1() -> void:
	for id: String in ["depot", "woodland"]:
		var m := MapData.load_map(id, MapStyle.new(), rules.team_size)
		assert_true(m.has_pole, id)
		var spawn := m.ends[1].spawns[0].position
		var other := m.ends[0].spawns[0].position
		assert_lt(m.pole.distance_to(spawn), m.pole.distance_to(other), "%s: the pole is on the defenders' side" % id)
