extends GutTest
## UL3 (owner's 0.1 Beta 2 playtest, 2026-11-20: "lift sounds are still out of sync. should play before doors
## close"): a shut's doors are heard LiftConfig.shut_lead before their leaves move, the leaves meet in shut_time and
## the car still sets off at door_time; an arriving car's doors are heard opening with its chime; a doorway's cue
## plays from the doorway's face on the listener's side, so its own shutting leaves never muffle it from a landing
## (game/sim/lifts.gd, game/config/lift_config.gd, game/play/sim_audio.gd).

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


func _match() -> Array:
	var q := level.query()
	var sim := Simulation.new(tuning, q, level.mover(tuning.body), map.ends, map.kill_y)
	var state := GameState.new(5, tuning)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	sim.start_match(state)
	state.round_state.hold = 0.0
	# Far from every lift, out of every doorway.
	var c := state.characters[0]
	c.position = map.ends[0].spawns[0].position + Vector3(0.0, tuning.body.rest_gap, 0.0)
	c.prev_position = c.position
	return [sim, state]


## Steps `n` ticks; each tick's LIFT events of lift `i` (cue, direction), in order.
func _step(sim: Simulation, state: GameState, n: int, i: int, events: Array = []) -> Array:
	var cmds: Array[PlayerCommand] = [PlayerCommand.new()]
	for t in n:
		cmds[0].reset(state.characters[0].yaw, state.characters[0].pitch)
		sim.step(state, cmds, DT)
		for k in state.events.count:
			var e := state.events.items[k]
			if e.kind == GameEvent.Kind.LIFT and e.target == i:
				events.append([e.value, e.direction])
	return events


func _cues(events: Array) -> Array[int]:
	var cues: Array[int] = []
	for e: Array in events:
		cues.append(e[0])
	return cues


func test_the_lead_is_inside_the_door_time_and_leaves_time_to_shut() -> void:
	assert_gt(cfg.shut_lead, 0.0, "the doors are heard before they move")
	assert_lt(cfg.shut_lead, cfg.door_time * 0.5, "the leaves keep most of the door's time to meet")
	assert_almost_eq(cfg.shut_time(), cfg.door_time - cfg.shut_lead, 1e-6)
	var odd := LiftConfig.new()
	odd.shut_lead = odd.door_time * 2.0
	assert_eq(odd.shut_time(), 0.0, "a lead past the door's time leaves none, never less")


func test_a_shut_is_heard_before_its_leaves_move_and_the_car_sets_off_on_time() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var i := 1
	state.lifts.calls[i] = 1 << (1 - state.lifts.stop[i])
	state.lifts.left[i] = 0.0
	var events := _step(sim, state, 2, i)
	assert_has(_cues(events), Lifts.Cue.SHUTTING)
	assert_eq(state.lifts.phase[i], LiftState.Phase.SHUTTING)
	var lead := roundi(cfg.shut_lead / DT)
	_step(sim, state, lead - 4, i)
	assert_eq(state.lifts.doors[i], 1.0, "the leaves still stand open while the doors are heard")
	_step(sim, state, 8, i)
	assert_lt(state.lifts.doors[i], 1.0, "then they shut")
	var shut_ticks := roundi(cfg.door_time / DT)
	events = _step(sim, state, shut_ticks - lead - 4 + 2, i)
	assert_has(_cues(events), Lifts.Cue.DEPART, "it sets off door_time after the shut began, as before")
	assert_eq(state.lifts.phase[i], LiftState.Phase.MOVING)


func test_an_arriving_car_chimes_and_is_heard_opening_from_its_doorway() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var i := 1
	var spec := level.query().lifts[i]
	state.lifts.calls[i] = 1 << (1 - state.lifts.stop[i])
	state.lifts.left[i] = 0.0
	var events := _step(sim, state, roundi((cfg.door_time + cfg.floor_time) / DT) + 4, i)
	var cues := _cues(events)
	var at := cues.find(Lifts.Cue.ARRIVE)
	assert_gt(at, -1, "it arrives")
	assert_eq(cues.slice(at, at + 2), [Lifts.Cue.ARRIVE, Lifts.Cue.OPENING], "the chime and the doors together")
	var through := Vector3(spec.out.x, 0.0, spec.out.y) * spec.door_depth * 0.5
	for e: Array in events:
		var cue: int = e[0]
		if cue == Lifts.Cue.DEPART:
			assert_eq(e[1], Vector3.ZERO, "the car's motor plays from the car")
		else:
			assert_almost_eq((e[1] as Vector3).distance_to(through), 0.0, 1e-5, "a doorway's cue knows its face")


func test_a_doorway_cue_plays_from_the_face_on_the_listeners_side() -> void:
	var e := GameEvent.new()
	e.reset(GameEvent.Kind.LIFT)
	e.position = Vector3(1.0, 2.0, 3.0)
	assert_eq(SimAudio.doorway_face(e, Vector3(9.0, 9.0, 9.0)), e.position, "no direction: where it is")
	e.direction = Vector3(0.0, 0.0, 0.15)
	assert_almost_eq(SimAudio.doorway_face(e, Vector3(4.0, 1.6, 8.0)).z, 3.15, 1e-6, "out on the landing")
	assert_almost_eq(SimAudio.doorway_face(e, Vector3(0.5, 1.6, 2.0)).z, 2.85, 1e-6, "in the car")


func test_from_a_landing_off_to_the_side_the_shutting_doors_are_never_muffled_by_themselves() -> void:
	var q := level.query()
	var hit := RayHit.new()
	var gap := SoundConfig.new().occlusion_surface_gap
	for i in q.lifts.size():
		var spec := q.lifts[i]
		var k := spec.start
		var out := Vector3(spec.out.x, 0.0, spec.out.y)
		var side := Vector3(out.z, 0.0, -out.x)
		var e := GameEvent.new()
		e.reset(GameEvent.Kind.LIFT)
		e.position = spec.door_center(k)
		e.direction = out * spec.door_depth * 0.5
		q.set_lift_door(i, k, true)
		var ears: Array[Vector3] = [spec.landing_point(k, cfg) + Vector3.UP * 1.6 + side * 1.0,
				spec.landing_point(k, cfg) + Vector3.UP * 1.6 - side * 1.5,
				spec.car_point(spec.stops[k]) + Vector3.UP * 1.6 + side * 0.5]
		var before := 0
		for ear in ears:
			if SoundPath.line_blocked(q, ear, e.position, gap, hit):
				before += 1
			assert_false(SoundPath.line_blocked(q, ear, SimAudio.doorway_face(e, ear), gap, hit),
					"lift %d: from %s the doors' own leaves don't muffle them" % [i, ear])
		assert_gt(before, 0, "lift %d: from the doorway's middle they did (the bug)" % i)
		q.set_lift_door(i, k, false)
