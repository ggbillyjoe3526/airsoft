extends GutTest
## RS1 QA: the edges of respawns the feature's own tests leave: the bomb a carrier drops, a return in the middle of the
## hit call and of the walk, a round that ends with a wait pending, the half-time swap, a missing end, a zero delay, the
## clock with a whole team waiting, a second hit after a return, the dead zone's places and the panel's nodes.

const DT := 1.0 / 60.0
const END_X := 10.0
const DEAD_ZONE_X := 14.0
const FORWARD_X := 8.0

var tuning: SimTuning = SimTuning.new()
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func _ends() -> Array[MapEnd]:
	var ends: Array[MapEnd] = []
	for e in 2:
		var side := -1.0 if e == 0 else 1.0
		var facing := -PI / 2.0 if e == 0 else PI / 2.0
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(Vector3(side * END_X, 0.0, (i - 1) * 2.0), facing))
		for i in 4:
			end.dead_zone.append(SpawnPoint.new(Vector3(side * DEAD_ZONE_X, 0.0, 10.0 + i), facing))
		var f := ForwardSpawn.new()
		f.name = "Forward %d" % e
		for i in 2:
			f.spots.append(SpawnPoint.new(Vector3(side * FORWARD_X, 0.0, -6.0 + i), facing))
		f.centre = Vector3(side * FORWARD_X, 0.0, -5.5)
		end.forward.append(f)
		ends.append(end)
	return ends


## `size` a side (ids alternate teams), `mode`, round 1 live; the rounds' own settings from `tweak` (a Callable on the
## RoundConfig) when given. Returns [sim, state, tuning].
func _match(mode: RoundState.Mode, size: int = 2, tweak: Callable = Callable()) -> Array:
	var t := tuning.duplicate() as SimTuning
	t.rounds = tuning.rounds.duplicate() as RoundConfig
	if tweak.is_valid():
		tweak.call(t.rounds)
	var w := BoxWorld.new(t.body)
	w.add_floor(60.0, 40.0)
	var sim := Simulation.new(t, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(1, t)
	state.round_state.mode = mode
	state.round_state.pole = Vector3(0.0, 0.0, 14.0)
	for i in size * 2:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	# the start countdown, so the round is live
	state.round_state.hold = 0.0
	return [sim, state, t]


func _cmds(n: int) -> Array[PlayerCommand]:
	var cmds: Array[PlayerCommand] = []
	for i in n:
		cmds.append(PlayerCommand.new())
	return cmds


func _hit(sim: Simulation, state: GameState, c: Character) -> void:
	Elimination.eliminate(c, -1, state.characters, sim.ends)


func _respawned(state: GameState, c: Character) -> GameEvent:
	for k in state.events.count:
		var e := state.events.items[k]
		if e.kind == GameEvent.Kind.RESPAWNED and e.actor == c.id:
			return e
	return null


func _until_back(sim: Simulation, state: GameState, cmds: Array[PlayerCommand], c: Character, ticks: int) -> GameEvent:
	for i in ticks:
		sim.step(state, cmds, DT)
		var e := _respawned(state, c)
		if e != null:
			return e
	return null


## Ticks for a zero wait to bring someone back: the hit called, then the fade off the field (TV1: never drawn at its
## spawn mid-walk), and a few to spare.
func _call_and_fade_ticks() -> int:
	return ceili((tuning.hits.call_time + tuning.hits.vanish_time) / DT) + 10


func _zero_delay(r: RoundConfig) -> void:
	r.respawn_delay = 0.0
	r.defender_respawn_delay = 0.0


func test_a_bomb_carrier_hit_drops_the_bomb_and_a_zero_delay_return_does_not_take_it_back() -> void:
	var m := _match(RoundState.Mode.PLANT_THE_BOMB, 2, _zero_delay)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var rs := state.round_state
	var carrier := state.characters[rs.attackers]
	rs.plant.status = PlantState.Status.CARRIED
	rs.plant.carrier = carrier.id
	rs.plant.position = carrier.position
	rs.plant.rest = carrier.position
	var cmds := _cmds(4)
	sim.step(state, cmds, DT)
	_hit(sim, state, carrier)
	var back := _until_back(sim, state, cmds, carrier, _call_and_fade_ticks())
	assert_not_null(back, "a zero delay brings it back once its hit is called and it has faded (TV1)")
	for i in 5:
		sim.step(state, cmds, DT)
	assert_eq(rs.plant.status, PlantState.Status.DOWN, "the bomb stays where it was dropped")
	assert_eq(rs.plant.carrier, -1, "and is not the returned carrier's again")


func test_a_return_in_the_middle_of_the_hit_call_leaves_no_walk_off_behind() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND, 2, func(r: RoundConfig) -> void:
		r.respawn_delay = 0.3
		r.defender_respawn_delay = 0.3)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c := state.characters[1]
	var cmds := _cmds(4)
	_hit(sim, state, c)
	assert_eq(c.status, Character.Status.CALLING)
	var back := _until_back(sim, state, cmds, c, 120)
	assert_not_null(back, "back after 0.3 s, inside the 1.4 s call")
	assert_eq(c.status, Character.Status.ALIVE)
	assert_false(c.walk_off_route_pending, "no route left to plan")
	assert_eq(c.hit_by, -1)
	assert_false(Elimination.plan_walk_off_routes(state.characters), "nothing is planned for it")
	for i in 60:
		sim.step(state, cmds, DT)
	assert_eq(c.status, Character.Status.ALIVE, "no walk off takes it again")
	assert_false(Respawns.waiting(c))


func test_a_return_from_the_dead_zone_unparks_the_character() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND, 2, func(r: RoundConfig) -> void:
		r.respawn_delay = 30.0
		r.defender_respawn_delay = 30.0
		r.round_time = 600.0)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c := state.characters[1]
	var cmds := _cmds(4)
	_hit(sim, state, c)
	var parked := false
	for i in 1500:
		sim.step(state, cmds, DT)
		if Elimination.is_parked(c):
			parked = true
			break
	assert_true(parked, "it reached the dead zone")
	var back := _until_back(sim, state, cmds, c, 40 * 60)
	assert_not_null(back, "and still comes back from there")
	assert_false(Elimination.is_parked(c))
	assert_eq(c.status, Character.Status.ALIVE)
	assert_true(c.position.distance_to(c.spawn_position) < 0.5, "at its start area")


func test_the_clock_ends_the_round_with_a_whole_team_waiting() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND, 2, func(r: RoundConfig) -> void:
		r.respawn_delay = 1000.0
		r.defender_respawn_delay = 1000.0)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var rs := state.round_state
	var cmds := _cmds(4)
	for c in state.characters:
		if c.team == rs.attackers:
			_hit(sim, state, c)
	rs.clock = 0.5
	var ended := false
	for i in 60 * 120:
		sim.step(state, cmds, DT)
		if rs.phase != RoundState.Phase.LIVE:
			ended = true
			break
	assert_true(ended, "a round whose attackers all wait still ends on its clock")
	assert_eq(rs.winner, 1 - rs.attackers, "to the defenders")


func test_a_pick_with_no_end_or_a_missing_end_comes_back_at_the_start_area() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var t: SimTuning = m[2]
	var rs := state.round_state
	var c := state.characters[rs.attackers]
	c.spawn_pick = 1
	c.end = -1
	assert_eq(Respawns.resolve(c, rs, sim.ends, state.characters, t.rounds), 0, "no end")
	c.end = 7
	assert_eq(Respawns.resolve(c, rs, sim.ends, state.characters, t.rounds), 0, "an end past the map's")
	var ends: Array[MapEnd] = [null, null]
	c.end = 0
	assert_eq(Respawns.resolve(c, rs, ends, state.characters, t.rounds), 0, "an end the map leaves out")
	c.spawn_pick = -3
	c.end = 0
	assert_eq(Respawns.resolve(c, rs, sim.ends, state.characters, t.rounds), 0, "a negative pick")


func test_a_zero_or_negative_delay_comes_back_once_called_and_faded() -> void:
	for delay: float in [0.0, -5.0]:
		var m := _match(RoundState.Mode.ATTACK_DEFEND, 2, func(r: RoundConfig) -> void:
			r.respawn_delay = delay
			r.defender_respawn_delay = delay)
		var sim: Simulation = m[0]
		var state: GameState = m[1]
		var c := state.characters[0]
		_hit(sim, state, c)
		assert_not_null(_until_back(sim, state, _cmds(4), c, _call_and_fade_ticks()), "delay %s" % delay)


func test_a_wait_pending_when_the_round_ends_is_gone_in_the_next_round() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var rs := state.round_state
	var cmds := _cmds(4)
	var c := state.characters[1]
	_hit(sim, state, c)
	sim.step(state, cmds, DT)
	assert_true(Respawns.waiting(c))
	rs.phase = RoundState.Phase.OVER
	rs.winner = 0
	rs.score[0] = 1
	rs.timer = 0.01
	for i in 3:
		sim.step(state, cmds, DT)
	assert_eq(rs.number, 2, "the next round began")
	for ch in state.characters:
		assert_true(Elimination.is_in_play(ch), "everyone is back by the round's own respawn")
		assert_false(Respawns.waiting(ch))
		assert_eq(ch.spawn_pick, 0)
	var stray := 0
	for i in 20 * 60:
		sim.step(state, cmds, DT)
		if rs.is_live() and _respawned(state, c) != null:
			stray += 1
	assert_eq(stray, 0, "no return from the old wait fires in the new round")


func test_after_the_half_time_swap_a_forward_pick_is_of_the_end_it_now_holds() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND, 2, func(r: RoundConfig) -> void:
		r.half_time_after = 1
		r.respawn_delay = 1.0)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var rs := state.round_state
	var cmds := _cmds(4)
	var before_end := state.characters[0].end
	rs.phase = RoundState.Phase.OVER
	rs.winner = 0
	rs.score[0] = 1
	rs.timer = 0.01
	for i in 3:
		sim.step(state, cmds, DT)
	rs.hold = 0.0
	assert_eq(rs.number, 2)
	assert_ne(state.characters[0].end, before_end, "the ends swapped")
	var c := state.characters[rs.attackers]
	cmds[c.id].spawn_pick = 1
	_hit(sim, state, c)
	var back := _until_back(sim, state, cmds, c, 10 * 60)
	assert_not_null(back)
	assert_eq(back.value, 1, "at a forward spawn")
	var side := -1.0 if c.end == 0 else 1.0
	assert_true(signf(c.position.x) == side, "on the side of the end it holds, not the one it held")


func test_a_second_hit_after_a_return_starts_a_fresh_wait_and_returns_again() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND, 2, func(r: RoundConfig) -> void:
		r.respawn_delay = 1.0
		r.defender_respawn_delay = 1.0)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmds := _cmds(4)
	var c := state.characters[rs_attackers(state)]
	for n in 3:
		_hit(sim, state, c)
		assert_not_null(_until_back(sim, state, cmds, c, 3 * 60), "return %d" % n)
		assert_eq(c.respawn_left, -1.0)
		assert_true(Elimination.is_in_play(c))


func rs_attackers(state: GameState) -> int:
	return state.round_state.attackers


func test_a_hit_after_the_bomb_is_armed_never_starts_a_wait() -> void:
	var m := _match(RoundState.Mode.PLANT_THE_BOMB)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var rs := state.round_state
	rs.plant.status = PlantState.Status.PLANTED
	rs.plant.fuse_left = 40.0
	var c := state.characters[1 - rs.attackers]
	_hit(sim, state, c)
	sim.step(state, _cmds(4), DT)
	assert_false(Respawns.waiting(c), "the defender hit after the bomb is armed stays out")
	assert_eq(c.respawn_left, -1.0)


func test_the_range_never_respawns_whatever_the_rule() -> void:
	var t := tuning.duplicate() as SimTuning
	t.rounds = tuning.rounds.duplicate() as RoundConfig
	t.rounds.respawns = RoundConfig.RespawnRule.ALWAYS
	var w := BoxWorld.new(t.body)
	w.add_floor(60.0, 40.0)
	var sim := Simulation.new(t, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(1, t)
	state.round_state.practice = true
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	assert_false(state.round_state.respawns)
	assert_false(Respawns.open(state.round_state))


func test_two_teammates_hit_one_after_another_around_a_return_do_not_share_a_dead_zone_spot() -> void:
	# Three a side: a is hit, b is hit, a comes back, c is hit: c must not be sent to b's spot.
	var m := _match(RoundState.Mode.ATTACK_DEFEND, 3, func(r: RoundConfig) -> void:
		r.respawn_delay = 1.0
		r.defender_respawn_delay = 1.0)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmds := _cmds(6)
	var team: Array[Character] = []
	for c in state.characters:
		if c.team == 0:
			team.append(c)
	_hit(sim, state, team[0])
	for i in 30:
		sim.step(state, cmds, DT)
	_hit(sim, state, team[1])
	assert_not_null(_until_back(sim, state, cmds, team[0], 3 * 60), "the first comes back")
	assert_false(Elimination.is_in_play(team[1]), "the second is still out")
	_hit(sim, state, team[2])
	assert_ne(team[2].dead_zone_target, team[1].dead_zone_target, "a place of its own in the dead zone")


func test_the_respawn_panel_leaves_no_nodes_behind() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var t: SimTuning = m[2]
	var you := state.characters[state.round_state.attackers]
	_hit(sim, state, you)
	sim.step(state, _cmds(4), DT)
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 10:
		var panel := HudRespawn.new()
		add_child(panel)
		panel.show_for(you, state.round_state, sim.ends, state.characters, t.rounds)
		remove_child(panel)
		panel.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans)


func test_a_panel_shown_for_a_character_with_no_end_does_not_fail() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var t: SimTuning = m[2]
	var you := state.characters[state.round_state.attackers]
	_hit(sim, state, you)
	sim.step(state, _cmds(4), DT)
	you.end = -1
	var panel := HudRespawn.new()
	add_child_autofree(panel)
	panel.show_for(you, state.round_state, sim.ends, state.characters, t.rounds)
	assert_eq(panel.place_names().size(), 1, "the start area only")
