extends GutTest
## BP12, the third pass before 0.1 Beta 2: a walk-off hidden in leaves or smoke is not seen (Respawns.seen), so it leaves
## the field on time instead of walking on.

const DT := 1.0 / 60.0

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
			end.spawns.append(SpawnPoint.new(Vector3(side * 10.0, 0.0, (i - 1) * 2.0), 0.0))
			end.dead_zone.append(SpawnPoint.new(Vector3(side * 14.0, 0.0, 10.0 + i), 0.0))
		ends.append(end)
	return ends


## A respawn match with character 1 hit at z 4 and the other three 10 m north of it, facing it: [sim, state, it].
func _watched() -> Array:
	var t := tuning.duplicate() as SimTuning
	t.rounds = tuning.rounds.duplicate() as RoundConfig
	t.rounds.respawn_delay = 2.0
	t.rounds.defender_respawn_delay = 2.0
	var w := BoxWorld.new(t.body)
	w.add_floor(60.0, 40.0)
	var sim := Simulation.new(t, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(1, t)
	state.round_state.mode = RoundState.Mode.ATTACK_DEFEND
	state.round_state.pole = Vector3(0.0, 0.0, 14.0)
	for i in 4:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	var c := state.characters[1]
	c.position = Vector3(0.0, t.body.rest_gap, 4.0)
	for i: int in [0, 2, 3]:
		state.characters[i].position = Vector3(0.0, t.body.rest_gap, -6.0)
		state.characters[i].yaw = PI
	Elimination.eliminate(c, 0, state.characters, sim.ends)
	return [sim, state, c]


func test_a_walk_off_behind_a_bush_is_not_seen() -> void:
	var m := _watched()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c: Character = m[2]
	assert_true(Respawns.seen(c, state.characters, sim.tuning, sim.query, RayHit.new()), "in the open it is seen")
	# a bush 2 m across between them, as tall as a body
	sim.query.foliage.add(Vector3(0.0, 0.0, -1.0), 1.0, 2.0)
	assert_false(Respawns.seen(c, state.characters, sim.tuning, sim.query, RayHit.new()), "the leaves hide it")


func test_a_thin_sprig_still_lets_it_be_seen() -> void:
	var m := _watched()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c: Character = m[2]
	# 0.4 m of leaves on the line: under seen_leaves, as the bots' sight rules see through it
	var r := sim.tuning.hits.seen_leaves / 3.0
	sim.query.foliage.add(Vector3(0.0, 0.0, -1.0), r, 2.0)
	assert_true(Respawns.seen(c, state.characters, sim.tuning, sim.query, RayHit.new()))


func test_a_walk_off_in_smoke_is_not_seen_and_leaves_on_time() -> void:
	var m := _watched()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c: Character = m[2]
	var g := state.grenades[0]
	g.launch(Grenade.Kind.SMOKE, 0, Vector3(0.0, 0.0, -1.0), Vector3.ZERO)
	g.resting = true
	g.popped = true
	g.smoking = sim.tuning.grenades.smoke_grow + 1.0
	assert_false(Respawns.seen(c, state.characters, sim.tuning, sim.query, RayHit.new(), state.grenades),
			"the cloud hides it")
	assert_true(Respawns.seen(c, state.characters, sim.tuning, sim.query, RayHit.new()), "without the smoke, seen")
	# the match itself hands the round's smoke over: it comes back at its wait, no walk-on
	var cmds: Array[PlayerCommand] = []
	for i in 4:
		var p := PlayerCommand.new()
		p.yaw = PI
		cmds.append(p)
	var ticks := 0
	while not Elimination.is_in_play(c) and ticks < 20 * 60:
		g.smoking = sim.tuning.grenades.smoke_grow + 1.0 # keep the cloud standing
		sim.step(state, cmds, DT)
		ticks += 1
	assert_true(Elimination.is_in_play(c), "it comes back")
	assert_lt(ticks * DT, 2.0 + 0.2, "at its wait: no walk-on")


# --- The loadout strip's Remove panel: Keep ends its row, no gap after it ---


func test_the_remove_panels_links_sit_evenly_in_it() -> void:
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	while saved.slots.size() < 2:
		saved.create()
	var strip := LoadoutStrip.new(saved)
	strip.position = Vector2(100.0, 100.0)
	add_child_autofree(strip)
	await wait_physics_frames(2)
	strip.open_menu(1, Vector2(20.0, 20.0))
	await wait_physics_frames(2)
	strip.menu().id_pressed.emit(LoadoutStrip.MenuItem.REMOVE)
	await wait_physics_frames(2)
	var keep := strip.action(&"keep")
	var row := keep.get_parent()
	assert_eq(row.get_child(row.get_child_count() - 1), keep, "Keep is the row's last: no gap after it")
	assert_eq(row.get_child(0), strip.action(&"remove_yes"), "Remove first")
	assert_eq(row.get_child_count(), 3, "Remove, the gap between, Keep")
	# asked again, the row is built afresh the same way
	strip.cancel()
	await wait_physics_frames(2)
	strip.open_menu(1, Vector2(20.0, 20.0))
	strip.menu().id_pressed.emit(LoadoutStrip.MenuItem.REMOVE)
	await wait_physics_frames(2)
	row = strip.action(&"keep").get_parent()
	assert_eq(row.get_child_count(), 3)


# --- QA: edges of the hide-in-cover rule ---


func _smoke(m: Array, popped: bool, smoking: float) -> void:
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var g := state.grenades[0]
	g.launch(Grenade.Kind.SMOKE, 0, Vector3(0.0, 0.0, -1.0), Vector3.ZERO)
	g.resting = true
	g.popped = popped
	g.smoking = smoking


func test_a_smoke_not_yet_popped_hides_nothing() -> void:
	var m := _watched()
	_smoke(m, false, 0.0)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	assert_true(Respawns.seen(m[2], state.characters, sim.tuning, sim.query, RayHit.new(), state.grenades))


func test_a_cloud_thinned_away_hides_nothing() -> void:
	var m := _watched()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	_smoke(m, true, sim.tuning.grenades.smoke_time - 0.01) # almost gone: density near 0
	assert_true(Respawns.seen(m[2], state.characters, sim.tuning, sim.query, RayHit.new(), state.grenades),
			"a wisp is under seen_smoke")


func test_a_cloud_still_growing_hides_less_than_a_full_one() -> void:
	var m := _watched()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	_smoke(m, true, 0.0) # popped, zero size
	assert_true(Respawns.seen(m[2], state.characters, sim.tuning, sim.query, RayHit.new(), state.grenades))


func test_a_bush_beside_the_line_and_a_map_without_foliage_do_not_hide() -> void:
	var m := _watched()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	assert_true(Respawns.seen(m[2], state.characters, sim.tuning, sim.query, RayHit.new()), "no foliage")
	sim.query.foliage.add(Vector3(5.0, 0.0, -1.0), 1.0, 2.0)
	assert_true(Respawns.seen(m[2], state.characters, sim.tuning, sim.query, RayHit.new()), "bush off the line")


func test_a_bush_the_watcher_stands_at_the_edge_of_does_not_hide() -> void:
	var m := _watched()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	# a thin bush right at the watchers' feet, the line barely clips its edge
	sim.query.foliage.add(Vector3(0.9, 0.0, -6.0), 1.0, 2.0)
	assert_true(Respawns.seen(m[2], state.characters, sim.tuning, sim.query, RayHit.new()))


func test_zero_wait_respawns_at_once_with_smoke_around() -> void:
	var m := _watched()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c: Character = m[2]
	sim.tuning.rounds.respawn_delay = 0.0
	sim.tuning.rounds.defender_respawn_delay = 0.0
	_smoke(m, true, sim.tuning.grenades.smoke_grow + 1.0)
	var cmds: Array[PlayerCommand] = []
	for i in 4:
		cmds.append(PlayerCommand.new())
	for i in 600:
		sim.step(state, cmds, DT)
		if Elimination.is_in_play(c):
			break
	assert_true(Elimination.is_in_play(c), "it never sticks")
