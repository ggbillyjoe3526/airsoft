extends GutTest
## The Dev settings that change play, in the simulation (game/sim/dev_cheats.gd; the browser game's config/dev.ts and
## its sim): bottomless magazines and ghost on the player alone, the record mark, End the round now; and the pure
## helpers the play loop uses for them, the tick pacer (game speed) and who Spectate any bot follows next.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)

var tuning: SimTuning = null


func before_each() -> void:
	tuning = SimTuning.new()


func _state(n: int = 6) -> GameState:
	var s := GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	for i in n:
		s.characters.append(Character.new(i, 0 if i < n / 2 else 1, Vector3(i, 0.0, 0.0), 0.0, loadout))
	return s


func _cheats(setup: Callable) -> DevCheats:
	var c := DevCheats.new()
	setup.call(c)
	return c


func test_bottomless_magazines_never_run_dry() -> void:
	var s := _state()
	DevCheats.apply(s, _cheats(func(c: DevCheats) -> void: c.bottomless = true), 0)
	var you := s.characters[0]
	var full := you.armament.mag()
	var cmd := PlayerCommand.new()
	cmd.fire = true
	var events := SimEvents.new()
	var pool := BBPool.new(512)
	var shots := 0
	# Long enough for well over a magazine at the AEG's rate.
	for i in 900:
		events.clear()
		Armament.step(you, cmd, EYE, 1.0, true, pool, s.rng, events, tuning, DT)
		shots += events.count_of(GameEvent.Kind.SHOT)
	assert_gt(shots, full, "fired more than a magazine holds")
	assert_eq(you.armament.mag(), full, "the magazine stays full")
	assert_false(s.characters[1].armament.bottomless, "a bot's magazines are as normal")


func test_switching_bottomless_on_fills_a_magazine_already_dry() -> void:
	var s := _state()
	var you := s.characters[0]
	var full := you.armament.mag()
	you.armament.ammo[you.armament.active].mag = 0
	you.armament.dry_fired_this_pull = true
	var spares := you.armament.ammo[you.armament.active].spare_bbs()
	DevCheats.apply(s, _cheats(func(c: DevCheats) -> void: c.bottomless = true), 0)
	assert_eq(you.armament.mag(), full, "the dry magazine in hand is full again")
	assert_false(you.armament.dry_fired_this_pull, "the next pull fires, not a dry click")
	assert_eq(you.armament.ammo[you.armament.active].spare_bbs(), spares, "the spares are untouched")
	var cmd := PlayerCommand.new()
	cmd.fire = true
	var events := SimEvents.new()
	Armament.step(you, cmd, EYE, 1.0, true, BBPool.new(64), s.rng, events, tuning, DT)
	assert_eq(events.count_of(GameEvent.Kind.SHOT), 1, "it fires on the first tick")
	# Applied again with Bottomless still on (a round restart, another switch): nothing more is filled.
	you.armament.ammo[you.armament.active].mag = 3
	DevCheats.apply(s, _cheats(func(c: DevCheats) -> void: c.bottomless = true), 0)
	assert_eq(you.armament.mag(), 3, "only switching it on fills the magazine")
	var bot := s.characters[1]
	bot.armament.ammo[bot.armament.active].mag = 0
	DevCheats.apply(s, _cheats(func(c: DevCheats) -> void: c.bottomless = false), 0)
	DevCheats.apply(s, _cheats(func(c: DevCheats) -> void: c.bottomless = true), 0)
	assert_eq(bot.armament.mag(), 0, "a bot's magazine is left as it is")


func test_ghost_lets_bbs_through_you_onto_whoever_is_behind() -> void:
	var s := _state(3)
	var shooter := s.characters[2]
	shooter.team = 1
	var you := s.characters[0]
	var behind := s.characters[1]
	shooter.position = Vector3.ZERO
	you.position = Vector3(0.0, 0.0, -8.0)
	behind.position = Vector3(0.0, 0.0, -16.0)
	DevCheats.apply(s, _cheats(func(c: DevCheats) -> void: c.ghost = true), you.id)
	assert_true(you.ghost)
	assert_false(behind.ghost)
	var pool := BBPool.new(4)
	var bb := pool.spawn(shooter.id, Vector3(0.0, 1.3, 0.0), Vector3.FORWARD, 88.0, 0.0, 0.25e-3,
			tuning.ballistics.spin_per_hop)
	var events := SimEvents.new()
	var ends: Array[MapEnd] = []
	for i in 60:
		if not bb.active:
			break
		events.clear()
		BBStep.step(pool, s.characters, WorldQuery.new(), tuning, -10.0, false, ends, events, DT)
	assert_eq(you.status, Character.Status.ALIVE, "the BB passed through you")
	assert_eq(behind.status, Character.Status.CALLING, "and hit your teammate behind")


func test_turning_a_cheat_off_gives_the_player_back_as_normal() -> void:
	var s := _state()
	DevCheats.apply(s, _cheats(func(c: DevCheats) -> void:
		c.ghost = true
		c.bottomless = true), 0)
	DevCheats.apply(s, DevCheats.new(), 0)
	assert_false(s.characters[0].ghost)
	assert_false(s.characters[0].armament.bottomless)


func test_a_cheat_keeps_the_match_off_the_record_for_the_rest_of_it() -> void:
	var s := _state()
	DevCheats.apply(s, DevCheats.new(), 0)
	assert_false(s.off_record, "no cheat: on the record")
	DevCheats.apply(s, _cheats(func(c: DevCheats) -> void: c.game_speed = 0.5), 0)
	assert_true(s.off_record)
	DevCheats.apply(s, DevCheats.new(), 0)
	assert_true(s.off_record, "turned off again: the match stays off the record")


func test_each_cheat_counts_and_the_defaults_do_not() -> void:
	assert_false(DevCheats.new().any())
	var each: Array[Callable] = [
		func(c: DevCheats) -> void: c.game_speed = 2.0,
		func(c: DevCheats) -> void: c.bottomless = true,
		func(c: DevCheats) -> void: c.ghost = true,
		func(c: DevCheats) -> void: c.bots_hold_fire = true,
		func(c: DevCheats) -> void: c.watching = true,
	]
	for setup in each:
		assert_true(_cheats(setup).any())


func test_game_speed_is_held_to_its_range() -> void:
	var s := _state()
	DevCheats.apply(s, _cheats(func(c: DevCheats) -> void: c.game_speed = 9.0), 0)
	assert_eq(s.cheats.game_speed, DevCheats.SPEED_MAX)
	DevCheats.apply(s, _cheats(func(c: DevCheats) -> void: c.game_speed = 0.0), 0)
	assert_eq(s.cheats.game_speed, DevCheats.SPEED_MIN)


func test_a_new_match_is_on_the_record_unless_a_cheat_or_dev_content_is_on() -> void:
	var s := _state()
	var sim := Simulation.new(tuning, WorldQuery.new(), null, _ends(), -10.0)
	s.off_record = true
	sim.start_match(s)
	assert_false(s.off_record, "a fresh match with nothing on")
	DevCheats.apply(s, _cheats(func(c: DevCheats) -> void: c.bots_hold_fire = true), 0)
	sim.start_match(s)
	assert_true(s.off_record, "a cheat still on")
	DevCheats.apply(s, DevCheats.new(), 0)
	s.dev_content = true
	sim.start_match(s)
	assert_true(s.off_record, "a dev map")


func test_end_the_round_runs_the_clock_out_and_it_ends_as_on_time() -> void:
	var s := _state()
	var ends := _ends()
	var sim := Simulation.new(tuning, WorldQuery.new(), null, ends, -10.0)
	sim.start_match(s)
	assert_true(s.round_state.is_live())
	assert_gt(s.round_state.clock, 0.0)
	assert_true(DevCheats.end_round(s))
	assert_true(s.off_record)
	var events := SimEvents.new()
	Round.step(s.round_state, s.characters, ends, s.bbs, tuning, events, DT)
	var over := events.first(GameEvent.Kind.ROUND_OVER)
	assert_not_null(over)
	assert_eq(over.value2, GameEvent.RoundEnd.TIME)
	assert_false(DevCheats.end_round(s), "no round live between rounds")


func test_the_pacer_runs_fixed_ticks_at_any_rate() -> void:
	var p := TickPacer.new()
	var cases: Dictionary[float, int] = {0.25: 2, 0.5: 4, 0.75: 6, 1.0: 8, 1.5: 12, 2.0: 16, 8.0: 64}
	for rate: float in cases:
		p = TickPacer.new()
		p.rate = rate
		var total := 0
		for i in 8:
			total += p.ticks()
		assert_eq(total, cases[rate], "8 physics ticks at %s" % rate)


func test_the_pacer_draws_smoothly_between_slowed_ticks() -> void:
	var p := TickPacer.new()
	p.rate = 0.25
	var last := -1.0
	var ran := 0
	# Across one simulated tick (4 physics ticks), drawing moves forward through it and never jumps back mid-way.
	for i in 4:
		ran += p.ticks()
		for f: float in [0.0, 0.5, 0.99]:
			var at := p.fraction(f)
			assert_between(at, 0.0, 1.0)
			if ran == 0:
				assert_gt(at, last)
				last = at
	assert_eq(ran, 1)
	p.rate = 1.0
	assert_eq(p.fraction(0.3), 0.3, "real time: the engine's own fraction")


func test_spectate_any_bot_follows_bots_on_either_team_in_turn() -> void:
	var s := _state(4)
	var cs := s.characters
	assert_eq(Spectate.next_bot(cs, -1, 0), 1, "the first bot")
	assert_eq(Spectate.next_bot(cs, 1, 0), 2)
	assert_eq(Spectate.next_bot(cs, 3, 0), 1, "wraps round, never to you")
	cs[2].status = Character.Status.OUT
	assert_eq(Spectate.next_bot(cs, 1, 0), 3, "skips anyone out")
	for c in cs:
		c.status = Character.Status.OUT
	assert_eq(Spectate.next_bot(cs, 1, 0), -1, "nobody in play")


## Two ends with spawns enough for three a side, each with a dead-zone spot.
func _ends() -> Array[MapEnd]:
	var out: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(Vector3(i * 2.0, 0.0, -20.0 if e == 0 else 20.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(30.0, 0.0, -20.0 if e == 0 else 20.0), 0.0))
		out.append(end)
	return out
