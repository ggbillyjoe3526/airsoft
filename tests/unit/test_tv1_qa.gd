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


# --- attempt 2: the walk-on (Respawns.seen), the drops' reach and the thickets' shape owners ---

## A 4-character match (2 s waits) with the first character, `c`, out and walking off at 4 m, the others 6 m off facing it.
func _watched_match(hits_seen_most: float = -1.0) -> Array:
	var m := _match(RoundState.Mode.ATTACK_DEFEND, 2.0)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	if hits_seen_most >= 0.0:
		sim.tuning.hits = sim.tuning.hits.duplicate() as HitConfig
		sim.tuning.hits.seen_most = hits_seen_most
	var c := state.characters[1]
	c.position = Vector3(0.0, tuning.body.rest_gap, 4.0)
	for i: int in [0, 2, 3]:
		state.characters[i].position = Vector3(0.0, tuning.body.rest_gap, -6.0)
		state.characters[i].yaw = PI
	Elimination.eliminate(c, 0, state.characters, sim.ends)
	return [sim, state, c]


func _walk_cmds() -> Array[PlayerCommand]:
	var cmds := _cmds()
	for p in cmds:
		p.yaw = PI
	return cmds


func test_seen_most_zero_fades_at_the_wait_even_when_watched() -> void:
	var m := _watched_match(0.0)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c: Character = m[2]
	var cmds := _walk_cmds()
	var ticks := 0
	while not Elimination.is_in_play(c) and ticks < 20 * 60:
		sim.step(state, cmds, DT)
		ticks += 1
	assert_true(Elimination.is_in_play(c), "it comes back")
	assert_lt(ticks * DT, 2.0 + 0.2, "no walk-on past its wait")


func test_a_watcher_walking_off_does_not_count() -> void:
	var m := _watched_match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c: Character = m[2]
	var hit := RayHit.new()
	assert_true(Respawns.seen(c, state.characters, tuning, sim.query, hit), "baseline: the watchers see it")
	for i: int in [0, 2, 3]:
		state.characters[i].status = Character.Status.WALKING_OFF
	assert_false(Respawns.seen(c, state.characters, tuning, sim.query, hit), "walking off or out, they do not watch")
	state.characters[0].status = Character.Status.OUT
	assert_false(Respawns.seen(c, state.characters, tuning, sim.query, hit))


func test_a_lone_walk_off_is_not_seen_by_itself() -> void:
	var m := _watched_match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c: Character = m[2]
	c.status = Character.Status.ALIVE # in play, facing itself: still itself
	c.yaw = PI
	var only: Array[Character] = [c]
	assert_false(Respawns.seen(c, only, tuning, sim.query, RayHit.new()))


func test_a_watcher_behind_a_closed_lift_car_or_door_does_not_see() -> void:
	# a box between stands for a car's wall or a shut door: sight_ray is what judges
	var m := _watched_match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c: Character = m[2]
	(sim.query as BoxWorld).add_box(Vector3(0.0, 1.5, -1.0), Vector3(20.0, 3.0, 0.2))
	assert_false(Respawns.seen(c, state.characters, tuning, sim.query, RayHit.new()))


func test_seen_needs_a_hit_buffer_and_a_level() -> void:
	var m := _watched_match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c: Character = m[2]
	assert_false(Respawns.seen(c, state.characters, tuning, sim.query, null))
	assert_false(Respawns.seen(c, state.characters, tuning, null, RayHit.new()))


func test_step_without_a_query_fades_at_the_wait_as_before() -> void:
	var m := _watched_match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c: Character = m[2]
	var cmds := _cmds()
	var events := SimEvents.new()
	c.status = Character.Status.WALKING_OFF
	c.respawn_left = tuning.hits.vanish_time
	c.respawn_seen = 0.0
	Respawns.step(state.round_state, state.characters, cmds, sim.ends, tuning, events, DT)
	assert_eq(c.status, Character.Status.LEAVING, "nobody sees with no level: it fades at once")
	assert_eq(c.respawn_seen, 0.0, "nothing counted watching")


func test_a_wait_starting_zeroes_a_left_over_walk_on_count() -> void:
	var m := _watched_match()
	var state: GameState = m[1]
	var sim: Simulation = m[0]
	var c: Character = m[2]
	c.respawn_seen = 2.9
	c.respawn_left = -1.0
	Respawns.step(state.round_state, state.characters, _cmds(), sim.ends, tuning, SimEvents.new(), DT, sim.query, RayHit.new())
	assert_eq(c.respawn_seen, 0.0, "a wait starting zeroes what was left over")
	assert_gt(c.respawn_left, 0.0)


func test_a_character_coming_back_has_no_walk_on_count_left() -> void:
	var m := _watched_match()
	var c: Character = m[2]
	c.respawn_seen = 2.9
	c.respawn_at(Vector3.ZERO, 0.0)
	assert_eq(c.respawn_seen, 0.0)
	assert_lt(c.respawn_left, 0.0)


func test_a_bomb_armed_during_the_walk_on_drops_the_wait_and_the_next_life_counts_afresh() -> void:
	var m := _match(RoundState.Mode.PLANT_THE_BOMB, 2.0)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c := state.characters[1]
	Elimination.eliminate(c, 0, state.characters, sim.ends)
	c.respawn_left = 0.5
	c.respawn_seen = 2.5
	state.round_state.plant.status = PlantState.Status.PLANTED
	state.round_state.plant.fuse_left = 1000.0
	var cmds := _cmds()
	for i in 10 * 60:
		sim.step(state, cmds, DT)
	assert_lt(c.respawn_left, 0.0, "the wait is dropped")
	assert_false(Elimination.is_in_play(c), "and it stays out")
	assert_eq(c.status, Character.Status.OUT)
	# if it ever waits again (a new round), the count starts at 0
	c.respawn_left = -1.0
	state.round_state.plant.status = PlantState.Status.DOWN
	Respawns.step(state.round_state, state.characters, cmds, sim.ends, tuning, SimEvents.new(), DT, sim.query, RayHit.new())
	assert_eq(c.respawn_seen, 0.0)


func test_drops_reach_walks_a_cycle_of_regions_and_stops() -> void:
	var g := NavGrid.new()
	g.drop_regions[1] = PackedInt32Array([2])
	g.drop_regions[2] = PackedInt32Array([3])
	g.drop_regions[3] = PackedInt32Array([1])
	assert_true(g.drops_reach(1, 3), "through a region")
	assert_true(g.drops_reach(2, 1), "round the cycle")
	assert_false(g.drops_reach(1, 4), "a region no drop leads to, the cycle ends")
	assert_false(g.drops_reach(4, 1), "a region with no drops")


func test_drops_reach_from_a_region_to_itself_needs_a_way_back() -> void:
	var g := NavGrid.new()
	assert_false(g.drops_reach(0, 0), "no drops at all")
	g.drop_regions[0] = PackedInt32Array([1])
	assert_false(g.drops_reach(0, 0), "one way only: no way back to itself")
	g.drop_regions[1] = PackedInt32Array([0])
	assert_true(g.drops_reach(0, 0), "a drop and back round")


func test_drops_are_one_way() -> void:
	var g := NavGrid.new()
	g.drop_regions[5] = PackedInt32Array([6])
	assert_true(g.drops_reach(5, 6))
	assert_false(g.drops_reach(6, 5))


func test_thicket_boxes_as_shape_owners_leave_no_nodes_and_free_with_the_body() -> void:
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var body := StaticBody3D.new()
	var boxes: Array[AABB] = []
	for i in 50:
		boxes.append(AABB(Vector3(i, 0.0, 0.0), Vector3(1.0, 2.0, 1.0)))
	MapLevel._add_owned_boxes(body, boxes)
	assert_eq(body.get_child_count(), 0, "no node a box")
	assert_eq(body.get_shape_owners().size(), 50)
	var owner_id: int = body.get_shape_owners()[7]
	assert_eq(body.shape_owner_get_shape_count(owner_id), 1)
	assert_eq(body.shape_owner_get_transform(owner_id).origin, boxes[7].get_center(), "placed at the box's middle")
	body.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes_before, "freed with it")
	_add_empty_check()


func _add_empty_check() -> void:
	var body := StaticBody3D.new()
	var none: Array[AABB] = []
	MapLevel._add_owned_boxes(body, none)
	assert_eq(body.get_shape_owners().size(), 0)
	body.free()
