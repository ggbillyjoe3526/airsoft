extends GutTest
## QA for FG1 (Attack / Defend's flag rules): half time with either team attacking first, drawn rounds, End the round
## now, the buzzer's edge cases, Elimination untouched and map data without a flag.

const DT := 1.0 / 60.0
const POLE := Vector3(20.0, 0.0, 5.0)

var tuning: SimTuning
var rules: RoundConfig
var flag_cfg: FlagConfig
var ends: Array[MapEnd]
var events: SimEvents
var rs: RoundState
var cs: Array[Character]
var seen: Array[Vector3i] = []


func before_each() -> void:
	tuning = SimTuning.new()
	rules = tuning.rounds
	rules.round_time = 10.0
	rules.reset_delay = 1.0
	rules.wins_needed = 5
	rules.half_time_after = 2
	flag_cfg = tuning.flag
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


func _tick() -> void:
	events.clear()
	Round.step(rs, cs, ends, null, tuning, events, DT)
	for j in events.count:
		var e := events.items[j]
		seen.append(Vector3i(e.kind, e.value, e.value2))


func _run(seconds: float) -> void:
	for i in ceili(seconds / DT - 1e-6):
		_tick()


func _count(kind: GameEvent.Kind, value: int) -> int:
	var n := 0
	for e in seen:
		if e.x == kind and e.y == value:
			n += 1
	return n


func _all_away() -> void:
	for c in cs:
		c.position = POLE + Vector3(-10.0, 0.0, 0.0)


func _to_pole(id: int) -> void:
	cs[id].position = POLE + Vector3(0.5, 0.0, 0.0)


## Lets the live round run out with nobody at the pole (a defenders' win) and waits for the next one.
func _defenders_hold() -> void:
	_all_away()
	_run(rules.round_time + DT)
	_run(rules.reset_delay + DT)


func test_half_time_swaps_attack_and_ends_whichever_team_attacks_first() -> void:
	for first: int in [0, 1]:
		rs.first_attackers = first
		_start()
		for n: int in [1, 2, 3, 4]:
			assert_true(rs.is_live(), "first %d, round %d live" % [first, n])
			assert_eq(rs.number, n)
			var expected := first if n <= rules.half_time_after else 1 - first
			assert_eq(rs.attackers, expected, "first %d, round %d attackers" % [first, n])
			for c in cs:
				assert_eq(c.end, 0 if c.team == expected else 1, "first %d, round %d: the attackers at end 0" % [first, n])
			_defenders_hold()


func test_a_drawn_round_is_replayed_with_the_same_attackers_a_fresh_flag_and_no_overtime_left() -> void:
	rs.first_attackers = 1
	_start()
	_defenders_hold()
	assert_eq(rs.number, 2)
	# Round 2: the attackers raise half way, the buzzer goes with them on the rope, then everyone is out at once.
	_all_away()
	_run(rules.round_time - flag_cfg.raise_time * 0.5)
	_to_pole(2)
	_run(flag_cfg.raise_time * 0.5 + 0.5)
	assert_true(rs.is_live())
	assert_gt(rs.overtime, 0.0, "overtime under way")
	for c in cs:
		c.status = Character.Status.OUT
	_tick()
	assert_true(rs.drawn(), "both out at once: a draw")
	assert_eq(rs.reason, GameEvent.RoundEnd.ELIMINATED)
	assert_eq(rs.score, PackedInt32Array([1, 0]), "round 1 to the defenders; the draw scores nobody")
	assert_eq(rs.draws, 1)
	_run(rules.reset_delay + DT)
	assert_eq(rs.number, 2, "played again under the same number")
	assert_eq(rs.attackers, 1, "a draw doesn't move half time")
	assert_eq(rs.flag.progress, 0.0)
	assert_eq(rs.flag.status, FlagState.Status.IDLE)
	assert_eq(rs.overtime, 0.0)
	assert_almost_eq(rs.clock, rules.round_time, DT * 2.0, "a full clock")


func test_the_last_attacker_hit_on_the_tick_the_flag_would_go_up_loses_by_elimination() -> void:
	_start()
	_all_away()
	cs[1].status = Character.Status.OUT
	_to_pole(0)
	while rs.flag.progress + DT / flag_cfg.raise_time < 1.0:
		_tick()
	assert_true(rs.is_live())
	cs[0].status = Character.Status.CALLING
	_tick()
	assert_eq(rs.winner, 1, "a wipe-out decides it first")
	assert_eq(rs.reason, GameEvent.RoundEnd.ELIMINATED)
	assert_lt(rs.flag.progress, 1.0, "the flag stopped where he was hit")


func test_the_flag_goes_up_in_raise_time_to_within_a_tick() -> void:
	_start()
	_all_away()
	_to_pole(0)
	var ticks := 0
	while rs.is_live() and ticks < 10000:
		_tick()
		ticks += 1
	assert_eq(rs.reason, GameEvent.RoundEnd.CAPTURED)
	assert_almost_eq(ticks, roundi(flag_cfg.raise_time / DT), 1, "ticks to raise")


func test_rope_steps_match_up_and_down_and_never_fire_on_a_still_flag() -> void:
	_start()
	_all_away()
	_to_pole(0)
	_run(flag_cfg.raise_time * 0.5 + DT * 0.5)
	var up := _count(GameEvent.Kind.FLAG_ROPE, 1)
	assert_eq(up, 6, "half way: six steps up")
	_to_pole(2)
	seen.clear()
	_run(2.0)
	assert_eq(seen.size(), 0, "contested: no ratchet")
	_all_away()
	_to_pole(2)
	_run(flag_cfg.lower_time)
	assert_eq(_count(GameEvent.Kind.FLAG_ROPE, 0), up, "as many steps down to the bottom")
	assert_eq(_count(GameEvent.Kind.FLAG_ROPE, 1), 0)


func test_at_the_buzzer_a_lowering_or_empty_pole_ends_it_at_once_and_a_pause_ends_overtime() -> void:
	_start()
	_all_away()
	_to_pole(0)
	_run(1.0)
	_all_away()
	_to_pole(2)
	_run(rules.round_time - 1.0 + DT)
	assert_false(rs.is_live(), "defenders pulling it down at the buzzer: no overtime")
	assert_eq(rs.winner, 1)
	assert_eq(rs.overtime, 0.0)
	_run(rules.reset_delay + DT)
	_all_away()
	_run(rules.round_time - 0.5)
	_to_pole(0)
	_run(1.0)
	assert_true(rs.is_live(), "overtime")
	_all_away()
	_tick()
	assert_false(rs.is_live(), "the rope let go in overtime: over")
	assert_eq(rs.winner, 1)
	assert_eq(rs.reason, GameEvent.RoundEnd.TIME)


func test_contested_at_the_bottom_at_the_buzzer_still_plays_overtime() -> void:
	_start()
	_all_away()
	_to_pole(0)
	_to_pole(2)
	_run(rules.round_time + 1.0)
	assert_true(rs.is_live(), "the browser game's rule: contested is working the rope")
	assert_eq(rs.flag.progress, 0.0)


func test_end_the_round_now_in_attack_defend_goes_to_the_defenders_and_leaves_no_infinite_overtime() -> void:
	_start()
	_all_away()
	_to_pole(0)
	_run(1.0)
	assert_true(Round.run_clock_out(rs))
	_tick()
	assert_false(rs.is_live())
	assert_eq(rs.winner, 1)
	assert_eq(rs.reason, GameEvent.RoundEnd.TIME)
	assert_false(Round.run_clock_out(rs), "nothing live to end")
	_run(rules.reset_delay + DT)
	assert_true(rs.is_live())
	assert_eq(rs.overtime, 0.0, "the next round starts without overtime")


func test_end_the_round_now_in_elimination_is_still_a_draw_on_time() -> void:
	rs.mode = RoundState.Mode.ELIMINATION
	_start()
	_to_pole(0)
	assert_true(Round.run_clock_out(rs))
	_tick()
	assert_true(rs.drawn())
	assert_eq(rs.reason, GameEvent.RoundEnd.TIME)
	assert_eq(_count(GameEvent.Kind.FLAG_ROPE, 1) + _count(GameEvent.Kind.FLAG_ROPE, 0), 0)


func test_elimination_ignores_the_pole_and_draws_on_time() -> void:
	_start()
	_to_pole(0)
	_run(1.0)
	assert_gt(rs.flag.progress, 0.0)
	rs.mode = RoundState.Mode.ELIMINATION
	_start()
	seen.clear()
	assert_eq(rs.attackers, -1)
	assert_eq(rs.flag.progress, 0.0, "a new match resets the flag")
	for c in cs:
		assert_eq(c.end, Round.team_end(c.team, 1, rules), "Elimination's ends")
	_to_pole(0)
	_to_pole(1)
	_run(rules.round_time + DT)
	assert_true(rs.drawn(), "time out level: a draw")
	assert_eq(rs.reason, GameEvent.RoundEnd.TIME)
	assert_eq(rs.overtime, 0.0)
	assert_eq(seen.filter(func(e: Vector3i) -> bool: return e.x == GameEvent.Kind.FLAG_ROPE).size(), 0)


func test_map_data_without_a_flag_has_no_pole() -> void:
	var text := FileAccess.get_file_as_string(MapData.DIR + "depot.json")
	var d: Dictionary = JSON.parse_string(text)
	d.erase("flag")
	d.erase("flags")
	var m := MapData.parse(JSON.stringify(d), MapStyle.new(), rules.team_size)
	assert_true(m.ok(), "a map without a flag still loads")
	assert_false(m.has_pole)
	assert_eq(m.pole, Vector3.ZERO)
	d["flag"] = [1.0, 2.0, 3.0]
	m = MapData.parse(JSON.stringify(d), MapStyle.new(), rules.team_size)
	assert_false(m.has_pole, "a flag that isn't an object is no pole")


func test_the_step_allocates_no_objects() -> void:
	_start()
	_all_away()
	_to_pole(0)
	_to_pole(2)
	_tick()
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 120:
		Flag.step(rs.flag, cs, rs.attackers, flag_cfg, events, DT)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


func test_nobody_can_work_the_rope_from_a_floor_above_the_pole() -> void:
	for id: String in ["depot", "woodland"]:
		var m := MapData.load_map(id, MapStyle.new(), rules.team_size)
		var overhead := 0
		for b in m.blocks:
			if b.kind != &"floor" and b.kind != &"ramp":
				continue
			var lo := b.center - b.size * 0.5
			var hi := b.center + b.size * 0.5
			var nx := clampf(m.pole.x, lo.x, hi.x)
			var nz := clampf(m.pole.z, lo.z, hi.z)
			var flat := Vector2(nx - m.pole.x, nz - m.pole.z).length()
			if flat <= flag_cfg.radius and hi.y > m.pole.y + 1.5:
				overhead += 1
		assert_eq(overhead, 0, "%s: a floor more than 1.5 m above the pole within its reach" % id)
