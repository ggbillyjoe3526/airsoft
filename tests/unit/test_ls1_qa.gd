extends GutTest
## LS1 QA: edge cases around the unsealed shut (several bodies aboard in the doorway, a round reset mid-shut, a press
## during the lead, a hit body aboard).

const DT := 1.0 / 60.0
var tuning: SimTuning = SimTuning.new()
var cfg: LiftConfig = tuning.lifts
var map: MapData = null
var level: MapLevel = null


func before_all() -> void:
	map = MapData.load_map("subway", MapStyle.new(), 6)
	level = MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body, null, null, false, null, cfg)


func after_all() -> void:
	level.free()


func _match(n: int) -> Array:
	var sim := Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	var state := GameState.new(5, tuning)
	for i in n:
		state.characters.append(Character.new(i, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	sim.start_match(state)
	state.round_state.hold = 0.0
	for c in state.characters:
		_stand(c, map.ends[0].spawns[0].position)
	return [sim, state]


func _stand(c: Character, at: Vector3) -> void:
	c.position = at + Vector3(0.0, tuning.body.rest_gap, 0.0)
	c.prev_position = c.position
	c.velocity = Vector3.ZERO
	c.grounded = true


func _in_from_face(spec: LiftSpec, k: int, depth: float, along: float = 0.5) -> Vector3:
	return spec.on_face(lerpf(spec.door_from, spec.door_to, along), -depth, spec.stops[k])


func _step(sim: Simulation, state: GameState, n: int, press: Vector2i = Lifts.NONE) -> void:
	var cmds: Array[PlayerCommand] = []
	for c in state.characters:
		cmds.append(PlayerCommand.new())
	for t in n:
		for c in state.characters.size():
			cmds[c].reset(state.characters[c].yaw, state.characters[c].pitch)
		if t == 0 and press != Lifts.NONE:
			cmds[0].use_door = true
			cmds[0].lift_to_use = press.x
			cmds[0].lift_stop = press.y
		sim.step(state, cmds, DT)


func test_two_bodies_aboard_in_the_doorway_both_step_clear_and_the_doors_seal() -> void:
	var m := _match(2)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var i := 1
	var spec := level.query().lifts[i]
	var k := state.lifts.stop[i]
	_stand(state.characters[0], _in_from_face(spec, k, 0.05, 0.3))
	_stand(state.characters[1], _in_from_face(spec, k, 0.1, 0.7))
	_step(sim, state, roundi(cfg.shut_lead / DT) - 1, Vector2i(i, 1 - k))
	assert_false(sim.lifts.doorway_blocked(i, k, state.characters), "both stepped in clear within the lead")
	assert_eq(state.lifts.sealed[i], 1)
	assert_eq(state.lifts.phase[i], LiftState.Phase.SHUTTING)


func test_a_round_reset_mid_shut_leaves_the_car_open_and_sealed() -> void:
	var m := _match(1)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var i := 1
	var spec := level.query().lifts[i]
	var k := state.lifts.stop[i]
	_stand(state.characters[0], _in_from_face(spec, k, 0.05))
	var was := cfg.step_in_speed
	cfg.step_in_speed = 0.0
	_step(sim, state, 5, Vector2i(i, 1 - k))
	cfg.step_in_speed = was
	assert_eq(state.lifts.sealed[i], 0, "unsealed mid-shut")
	sim.lifts.reset(state.lifts)
	assert_eq(state.lifts.sealed[i], 1)
	assert_eq(state.lifts.phase[i], LiftState.Phase.OPEN)
	assert_eq(state.lifts.doors[i], 1.0)


func test_a_press_of_the_cars_panel_during_the_lead_opens_it_and_a_later_press_shuts_it_again() -> void:
	var m := _match(1)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var i := 1
	var spec := level.query().lifts[i]
	var k := state.lifts.stop[i]
	_stand(state.characters[0], _in_from_face(spec, k, 0.05))
	var was := cfg.step_in_speed
	cfg.step_in_speed = 0.0
	_step(sim, state, 3, Vector2i(i, 1 - k))
	assert_eq(state.lifts.phase[i], LiftState.Phase.SHUTTING)
	cfg.step_in_speed = was
	_step(sim, state, 1, Vector2i(i, k))
	_step(sim, state, 5)
	assert_ne(state.lifts.phase[i], LiftState.Phase.MOVING, "never rides off with the presser mid-doorway")
	assert_eq(state.lifts.sealed[i], 1, "sealed again, whichever way it went")


func test_a_hit_body_aboard_in_the_doorway_keeps_the_doors_open() -> void:
	var m := _match(2)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var i := 1
	var spec := level.query().lifts[i]
	var k := state.lifts.stop[i]
	_stand(state.characters[0], spec.car_point(state.lifts.y[i]))
	_stand(state.characters[1], _in_from_face(spec, k, 0.05))
	state.characters[1].hit_by = 0
	state.characters[1].status = Character.Status.CALLING
	if Elimination.is_in_play(state.characters[1]):
		pending("could not mark the body hit")
		return
	_step(sim, state, roundi(cfg.door_time / DT) + 60, Vector2i(i, 1 - k))
	assert_eq(state.lifts.phase[i], LiftState.Phase.OPEN, "no shutting on the walk-off")
