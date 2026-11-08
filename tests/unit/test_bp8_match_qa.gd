extends GutTest
## QA for BP8 match: the hold through the buzzer, SIMULATE at match point and twice, grenade picks that are two of a
## kind or badly saved, bot kits' bombs, and the bush's slowdown across gaits and on leaving it.

const DT := 1.0 / 60.0
const POLE := Vector3(20.0, 0.0, 5.0)

var tuning: SimTuning = SimTuning.load_default()


func _end(x: float, zs: Array[float]) -> MapEnd:
	var e := MapEnd.new()
	for z in zs:
		e.spawns.append(SpawnPoint.new(Vector3(x, 0.0, z), 0.0))
	return e


## Attack / Defend with two attackers (team 0) and two defenders, the clock short.
func _flag_round() -> Array:
	var t := SimTuning.new()
	t.rounds.round_time = 10.0
	t.rounds.reset_delay = 1.0
	t.rounds.wins_needed = 5
	t.rounds.half_time_after = 9
	var ends: Array[MapEnd] = [_end(-20.0, [0.0, 1.0]), _end(20.0, [2.0, 3.0])]
	var rs := RoundState.new()
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	rs.pole = POLE
	var none: Array[ReplicaConfig] = []
	var cs: Array[Character] = []
	for id in 4:
		cs.append(Character.new(id, 0 if id < 2 else 1, Vector3.ZERO, 0.0, none))
	var events := SimEvents.new()
	Round.start_match(rs, cs, ends, null, t, events)
	return [t, rs, cs, ends, events]


func _tick_round(m: Array) -> void:
	var ev: SimEvents = m[4]
	ev.clear()
	Round.step(m[1], m[2], m[3], null, m[0], ev, DT)


func _park(cs: Array[Character]) -> void:
	for c in cs:
		c.position = POLE + Vector3(-10.0, 0.0, 0.0)


func test_a_flag_still_being_held_at_the_buzzer_wins_the_round_for_the_attackers() -> void:
	var m := _flag_round()
	var rs: RoundState = m[1]
	var cs: Array[Character] = m[2]
	_park(cs)
	var attackers := rs.attackers
	cs[0 if attackers == 0 else 2].position = POLE + Vector3(0.5, 0.0, 0.0)
	var ticks := 0
	while rs.is_live() and ticks < 60 * 40:
		_tick_round(m)
		ticks += 1
	var t: SimTuning = m[0]
	assert_eq(rs.winner, attackers, "raised at 7.5 s, held 5 s: past the 10 s clock, the attackers still win")
	assert_gt(ticks * DT, t.rounds.round_time + 2.0, "overtime ran while the raised flag was held")


func test_a_defender_on_the_rope_in_overtime_breaks_the_hold_and_the_defenders_take_the_round() -> void:
	var m := _flag_round()
	var rs: RoundState = m[1]
	var cs: Array[Character] = m[2]
	_park(cs)
	var att := cs[0 if rs.attackers == 0 else 2]
	var def := cs[2 if rs.attackers == 0 else 0]
	att.position = POLE + Vector3(0.5, 0.0, 0.0)
	var ticks := 0
	while rs.is_live() and ticks < 60 * 40:
		if ticks * DT > 8.5:
			def.position = POLE + Vector3(-0.5, 0.0, 0.0)
			att.position = POLE + Vector3(-10.0, 0.0, 0.0)
		_tick_round(m)
		ticks += 1
	assert_eq(rs.winner, 1 - rs.attackers, "pulled off the top alone by a defender")


func test_simulating_the_deciding_round_ends_the_match_and_a_second_press_changes_nothing() -> void:
	var m := _flag_round()
	var t: SimTuning = m[0]
	var rs: RoundState = m[1]
	var cs: Array[Character] = m[2]
	rs.score = PackedInt32Array([t.rounds.wins_needed - 1, t.rounds.wins_needed - 1])
	var ev := SimEvents.new()
	var won := Round.simulate(rs, cs, t, ev, Seeds.stream(3))
	assert_eq(rs.phase, RoundState.Phase.MATCH_OVER, "the last round: the match is decided")
	assert_eq(rs.match_winner, won)
	assert_eq(rs.score[won], t.rounds.wins_needed)
	var before := rs.score.duplicate()
	assert_eq(Round.simulate(rs, cs, t, ev, Seeds.stream(3)), -1)
	assert_eq(rs.score, before, "no second point")


func test_simulating_in_overtime_still_decides_the_round() -> void:
	var m := _flag_round()
	var rs: RoundState = m[1]
	rs.clock = 10.5
	rs.overtime = 3.0
	rs.flags[0].progress = 1.0
	rs.flags[0].held = 2.0
	var won := Round.simulate(rs, m[2], m[0], m[4], Seeds.stream(9))
	assert_ne(won, -1)
	assert_false(rs.is_live())


func test_simulate_with_one_team_wiped_out_never_gives_it_the_round() -> void:
	for seed_value in 50:
		var m := _flag_round()
		var cs: Array[Character] = m[2]
		cs[2].status = Character.Status.OUT
		cs[3].status = Character.Status.OUT
		assert_eq(Round.simulate(m[1], cs, m[0], m[4], Seeds.stream(seed_value)), 0)


# --- grenades ---


func test_a_loadout_with_the_wrong_number_of_bombs_or_a_none_falls_back_and_says_so() -> void:
	var cases: Array = [["smoke"], ["smoke", "flash", "smoke"], ["none", "smoke"], [], "smoke", [1, 2]]
	for bad: Variant in cases:
		var saved := SavedLoadouts.new(LoadoutRules.standard())
		var problems := saved.from_dict({"slots": [{"name": "X", "equipped": ["000002", "000001"], "bombs": bad}]})
		assert_eq(problems.size(), 1, "reported: %s" % [bad])
		assert_eq(Array(saved.rules.bombs_of(saved.carried())), [Grenade.Kind.SMOKE, Grenade.Kind.FLASH])


func test_two_of_a_kind_are_carried_counted_and_come_back_each_round() -> void:
	var cfg := tuning.grenades
	var hand := Grenades.Hand.new()
	hand.picks = [Grenade.Kind.SMOKE, Grenade.Kind.SMOKE]
	hand.carry_picked(cfg)
	assert_eq(hand.left(Grenade.Kind.SMOKE), 2)
	assert_eq(hand.left(Grenade.Kind.FLASH), 0, "no flash with two smokes")
	hand.smoke = 0
	hand.refill()
	assert_eq(hand.left(Grenade.Kind.SMOKE), 2, "refilled at a respawn")
	hand.picks = [Grenade.Kind.FLASH, Grenade.Kind.NONE]
	hand.carry_picked(cfg)
	assert_eq(hand.left(Grenade.Kind.FLASH), 1, "a bad pick is the default pick")
	assert_eq(hand.left(Grenade.Kind.SMOKE), 1)


func test_every_bot_kit_carries_exactly_two_valid_bombs() -> void:
	var rules := LoadoutRules.standard()
	var kits := BotKits.shared()
	assert_gt(kits.kits.size(), 0)
	for plan in kits.kits:
		var k := BotKits.kit_of(plan, rules)
		assert_eq(k.bombs.size(), rules.bombs.slots, plan.kit_name)
		for b in k.bombs:
			assert_true(b == Grenade.Kind.SMOKE or b == Grenade.Kind.FLASH)


func test_a_match_hands_two_flashes_to_a_character_that_picked_them_and_the_pool_has_room() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 60.0)
	var ends: Array[MapEnd] = [_end(-15.0, [0.0]), _end(15.0, [0.0])]
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(3, tuning)
	for i in 16:
		var c := Character.new(i, i % 2, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
		c.grenades.picks = [Grenade.Kind.FLASH, Grenade.Kind.FLASH]
		s.characters.append(c)
	sim.start_match(s)
	assert_eq(s.characters[5].grenades.left(Grenade.Kind.FLASH), 2)
	assert_eq(s.characters[5].grenades.left(Grenade.Kind.SMOKE), 0)
	assert_gte(s.grenades.size(), 32)


# --- bushes ---


func _world(big: bool = false) -> Array:
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(120.0, 0.5, 120.0), RayHit.Surface.EARTH)
	w.add_bush(Vector3(0.0, 0.0, -10.0), 6.0, 1.6)
	if big:
		w.add_bush(Vector3(0.0, 0.0, -30.0), 14.0, 1.6)
	var ends: Array[MapEnd] = [_end(-15.0, [0.0]), _end(15.0, [0.0])]
	for e in ends:
		e.dead_zone.append(SpawnPoint.new(Vector3(e.spawns[0].position.x * 1.2, 0.0, 0.0), 0.0))
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(3, tuning)
	s.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	s.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	sim.start_match(s)
	return [sim, s]


## Runs character 0 north from `from`; its pace over the last half second and the footsteps it made.
func _go(m: Array, from: Vector3, seconds: float, set_cmd: Callable, steps: Array[GameEvent]) -> float:
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var c := s.characters[0]
	c.position = from
	c.prev_position = from
	var cmds: Array[PlayerCommand] = [PlayerCommand.new(), PlayerCommand.new()]
	cmds[0].forward = 1.0
	set_cmd.call(cmds[0])
	var ticks := roundi(seconds * 60.0)
	var mark := Vector3.ZERO
	for i in ticks:
		if i == ticks - 30:
			mark = c.position
		sim.step(s, cmds, DT)
		for j in s.events.count:
			var e := s.events.items[j]
			if e.kind == GameEvent.Kind.FOOTSTEP and e.actor == 0:
				var copy := GameEvent.new()
				copy.value = e.value
				copy.value2 = e.value2
				copy.carry = e.carry
				steps.append(copy)
	return Vector2(c.position.x - mark.x, c.position.z - mark.z).length() / 0.5


func test_the_bush_slows_a_sprint_and_a_crouch_by_the_same_share_and_walking_stays_silent() -> void:
	var m := _world(true)
	var scale := tuning.movement.bush_speed_scale
	var open: Array[GameEvent] = []
	var leaf: Array[GameEvent] = []
	var sprint := func(c: PlayerCommand) -> void: c.sprint = true
	var crouch := func(c: PlayerCommand) -> void: c.crouch = true
	var walk := func(c: PlayerCommand) -> void: c.walk = true
	var s_open := _go(m, Vector3(25.0, 0.0, 10.0), 3.0, sprint, open)
	var s_bush := _go(m, Vector3(0.0, 0.0, -18.0), 3.0, sprint, leaf)
	assert_almost_eq(s_bush / s_open, scale, 0.05, "sprint")
	assert_eq(leaf[-1].value2, RayHit.Surface.LEAVES)
	assert_eq(leaf[-1].carry, tuning.noise.bush_carry)
	var c_open := _go(m, Vector3(25.0, 0.0, 10.0), 3.0, crouch, [] as Array[GameEvent])
	var quiet: Array[GameEvent] = []
	var c_bush := _go(m, Vector3(0.0, 0.0, -18.0), 3.0, crouch, quiet)
	assert_almost_eq(c_bush / c_open, scale, 0.05, "crouch")
	assert_eq(quiet.size(), 0, "a crouch in a bush stays silent")
	var walking: Array[GameEvent] = []
	_go(m, Vector3(0.0, 0.0, -18.0), 2.0, walk, walking)
	assert_eq(walking.size(), 0, "a walk in a bush stays silent")


func test_back_in_the_open_the_pace_and_the_sound_come_back() -> void:
	var m := _world()
	var s: GameState = m[1]
	var steps: Array[GameEvent] = []
	# starts at the bush's far edge heading north out of it (the bush ends at z = -16)
	var out := _go(m, Vector3(0.0, 0.0, -12.0), 6.0, func(_c: PlayerCommand) -> void: pass, steps)
	assert_false(s.characters[0].in_bush)
	assert_almost_eq(out, tuning.movement.run_speed, 0.1)
	assert_eq(steps[-1].value2, RayHit.Surface.EARTH)
	assert_eq(steps[-1].carry, 1.0)


func test_a_low_fern_under_the_probe_height_does_not_slow_anyone() -> void:
	var m := _world()
	var w: BoxWorld = BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(120.0, 0.5, 120.0), RayHit.Surface.EARTH)
	w.add_bush(Vector3(0.0, 0.0, -10.0), 6.0, 0.4)
	assert_false(w.foliage.holds(Vector3(0.0, tuning.movement.bush_probe_height, -10.0)))
	assert_not_null(m)
