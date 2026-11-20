extends GutTest
## TV1 QA: edges of the respawn fade (a delay shorter than the hit call, the bomb armed mid-fade, never a visible pop)
## (TV1).

const DT := 1.0 / 60.0
const END_X := 10.0

var tuning: SimTuning = SimTuning.new()
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func _ends() -> Array[MapEnd]:
	var ends: Array[MapEnd] = []
	for e in 2:
		var side := -1.0 if e == 0 else 1.0
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(Vector3(side * END_X, 0.0, (i - 1) * 2.0), 0.0))
			end.dead_zone.append(SpawnPoint.new(Vector3(side * 14.0, 0.0, 10.0 + i), 0.0))
		ends.append(end)
	return ends


func _match(mode: RoundState.Mode, delay: float) -> Array:
	var t := tuning.duplicate() as SimTuning
	t.rounds = tuning.rounds.duplicate() as RoundConfig
	t.rounds.respawn_delay = delay
	t.rounds.defender_respawn_delay = delay
	t.rounds.plant_defender_respawn_delay = delay
	var w := BoxWorld.new(t.body)
	w.add_floor(60.0, 40.0)
	var sim := Simulation.new(t, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(1, t)
	state.round_state.mode = mode
	state.round_state.pole = Vector3(0.0, 0.0, 14.0)
	for i in 4:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	return [sim, state]


func _cmds() -> Array[PlayerCommand]:
	var cmds: Array[PlayerCommand] = []
	for i in 4:
		cmds.append(PlayerCommand.new())
	return cmds


func test_a_zero_delay_still_calls_walks_off_and_comes_back_without_a_pop() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND, 0.0)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmds := _cmds()
	var c := state.characters[1]
	Elimination.eliminate(c, -1, state.characters, sim.ends)
	var back := false
	for i in 30 * 60:
		var before := c.position
		var was_drawn := c.status == Character.Status.WALKING_OFF or c.status == Character.Status.CALLING
		sim.step(state, cmds, DT)
		if Elimination.is_in_play(c):
			back = true
			break
		if was_drawn and c.status != Character.Status.LEAVING:
			assert_lt(before.distance_to(c.position), 1.0, "no jump while it is drawn at full strength")
	assert_true(back, "a zero delay still brings it back")
	assert_gte(c.respawn_left, -1.0)


func test_a_wait_shorter_than_the_call_and_the_fade_still_ends_out_before_it_returns() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND, 0.2)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmds := _cmds()
	var c := state.characters[1]
	Elimination.eliminate(c, -1, state.characters, sim.ends)
	var seen_leaving := false
	for i in 30 * 60:
		sim.step(state, cmds, DT)
		if c.status == Character.Status.LEAVING:
			seen_leaving = true
		if Elimination.is_in_play(c):
			break
	assert_true(Elimination.is_in_play(c), "back in play")
	assert_true(seen_leaving or c.status == Character.Status.ALIVE, "it came back")


func test_the_bomb_armed_mid_fade_keeps_the_leaver_out_and_it_finishes_leaving() -> void:
	var m := _match(RoundState.Mode.PLANT_THE_BOMB, 5.0)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmds := _cmds()
	var c := state.characters[1]
	Elimination.eliminate(c, -1, state.characters, sim.ends)
	Elimination.leave(c)
	assert_eq(c.status, Character.Status.CALLING, "a character still calling is not made to leave")
	c.status = Character.Status.WALKING_OFF
	Elimination.leave(c)
	assert_eq(c.status, Character.Status.LEAVING)
	state.round_state.plant.status = PlantState.Status.PLANTED
	state.round_state.plant.fuse_left = 1000.0
	for i in 20 * 60:
		sim.step(state, cmds, DT)
	assert_eq(c.status, Character.Status.OUT, "the fade ran to its end")
	assert_false(Elimination.is_in_play(c), "with respawns shut it stays out")
	assert_lt(c.respawn_left, 0.0)
