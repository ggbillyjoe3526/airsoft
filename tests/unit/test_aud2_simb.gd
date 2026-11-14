extends GutTest
## The second audit's fixes to play, physics and rules (AUD2, group simb): Depot's steel lockers knock and ring as a
## steel prop (a block's own `noise`, PropNoise).

const DT := 1.0 / 60.0
const GAP := 0.04

var tuning: SimTuning = SimTuning.new()
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func _ends() -> Array[MapEnd]:
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-15.0 if e == 0 else 15.0, 0.0, 15.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-18.0 if e == 0 else 18.0, 0.0, 18.0), 0.0))
		ends.append(end)
	return ends


# --- KNOWN_ISSUES 27: Depot's steel lockers ---


func test_depots_steel_lockers_clank_and_ring_as_a_steel_prop() -> void:
	var map := MapData.load_map("depot", MapStyle.new(), tuning.rounds.team_size)
	var level := MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body)
	var q := level.query()
	var props := PropNoise.new(tuning.noise, q)
	var lockers := 0
	for i in props.count():
		if q.block_noises[props.block[i]] == &"":
			continue
		lockers += 1
		assert_eq(q.block_kinds[props.block[i]], &"plywood", "still a plywood box to the rest of the game")
		assert_eq(props.sound[i], NoiseConfig.Sound.CLANK, "sounds as the hall's other smaller steel")
		assert_eq(props.surface[i], RayHit.Surface.METAL)
		assert_eq(props.knock_reach[i], tuning.noise.knock_reach_of(NoiseConfig.Sound.CLANK))
		assert_gt(props.ring_reach[i], 0.0, "a BB rings it")
		assert_true(props.ringing.has(i))
	assert_eq(lockers, 1, "Depot's one bank of steel lockers")
	level.free()


func test_a_run_into_a_block_naming_its_own_sound_knocks_it_as_that() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	var at := Vector3(0.0, 1.1, -3.0)
	var size := Vector3(2.0, 2.2, 1.0)
	w.add_box(at, size, RayHit.Surface.METAL)
	w.add_block(&"plywood", at, size, RayHit.Surface.METAL, &"clank")
	var sim := Simulation.new(tuning, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(3, tuning)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	var c := state.characters[0]
	c.position = Vector3(0.0, GAP, 0.0)
	c.prev_position = c.position
	c.grounded = true
	var cmd := PlayerCommand.new()
	cmd.reset(0.0, 0.0)
	cmd.forward = 1.0
	var cmds: Array[PlayerCommand] = [cmd, null]
	var knocks := 0
	for t in 150:
		sim.step(state, cmds, DT)
		for k in state.events.count:
			var e := state.events.items[k]
			if e.kind == GameEvent.Kind.PROP_KNOCK:
				knocks += 1
				assert_eq(e.value, NoiseConfig.Sound.CLANK)
				assert_eq(e.reach, tuning.noise.knock_reach_of(NoiseConfig.Sound.CLANK))
	assert_eq(knocks, 1, "a run into it knocks it once (a plain plywood box is silent)")


func test_a_blocks_unknown_noise_warns_and_keeps_its_kinds() -> void:
	var m := MapData.new()
	var blocks: Array = [{"kind": "plywood", "center": {"x": 0, "y": 1, "z": 0}, "size": {"x": 1, "y": 2, "z": 1},
			"noise": "gong"}]
	m._read_blocks(blocks, MapStyle.new())
	assert_eq(m.blocks.size(), 1)
	assert_eq(m.blocks[0].noise, &"", "its kind's sound kept")
	assert_eq(m.warnings.size(), 1)


# --- KNOWN_ISSUES 18: a lift's doorway stops a BB only where its leaves stand ---


## The test shaft of test_lifts (a 2 m well at the origin, its 1 m door in the north face, stops at 0 and 4 m).
func _lift_world() -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, -6.0), Vector3(20.0, 0.5, 9.4))
	w.add_box(Vector3(0.0, 3.85, -6.0), Vector3(20.0, 0.3, 9.4))
	w.add_box(Vector3(-0.9, 3.0, -1.15), Vector3(0.8, 8.0, 0.3))
	w.add_box(Vector3(0.9, 3.0, -1.15), Vector3(0.8, 8.0, 0.3))
	w.add_box(Vector3(0.0, -0.5, -1.15), Vector3(1.0, 1.0, 0.3))
	w.add_box(Vector3(0.0, 3.05, -1.15), Vector3(1.0, 1.9, 0.3))
	w.add_box(Vector3(0.0, 6.55, -1.15), Vector3(1.0, 0.9, 0.3))
	w.add_box(Vector3(0.0, 3.0, 1.15), Vector3(2.6, 8.0, 0.3))
	w.add_box(Vector3(-1.15, 3.0, 0.0), Vector3(0.3, 8.0, 2.0))
	w.add_box(Vector3(1.15, 3.0, 0.0), Vector3(0.3, 8.0, 2.0))
	var s := LiftSpec.new()
	s.name = "test"
	s.well = Rect2(-1.0, -1.0, 2.0, 2.0)
	s.out = Vector2(0.0, -1.0)
	s.door_from = -0.5
	s.door_to = 0.5
	s.door_height = 2.1
	s.door_depth = 0.3
	s.stops = PackedFloat32Array([0.0, 4.0])
	s.stop_names = PackedStringArray(["Ground", "Upper"])
	w.add_lift(s, tuning.lifts)
	return w


func test_a_bb_flies_a_half_shut_lift_doorways_gap_and_meets_its_leaves_beside_it() -> void:
	var w := _lift_world()
	var sim := Simulation.new(tuning, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(3, tuning)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	for c in state.characters:
		c.position = Vector3(-8.0 + c.id, GAP, -9.0)
		c.prev_position = c.position
	state.lifts.calls[0] = 1 << 1
	var cmds: Array[PlayerCommand] = [null, null]
	var shutting := 0
	while shutting < 200 and not (state.lifts.phase[0] == LiftState.Phase.SHUTTING and state.lifts.doors[0] <= 0.5):
		sim.step(state, cmds, DT)
		shutting += 1
	assert_eq(state.lifts.phase[0], LiftState.Phase.SHUTTING, "the car shuts its doors for the call")
	var open := state.lifts.doors[0]
	assert_almost_eq(open, 0.5, 0.02, "half shut")
	var hit := RayHit.new()
	var y := 1.0
	assert_true(w.ray(Vector3(0.0, y, -2.0), Vector3(0.0, y, 0.5), hit), "to bodies and sight the doorway is whole")
	assert_true(w.bb_ray(Vector3(0.0, y, -2.0), Vector3(0.0, y, 1.5), hit), "a BB through the gap flies on")
	assert_gt(hit.position.z, 0.9, "into the car, to its back wall")
	var gap := open * 0.5
	assert_true(w.bb_ray(Vector3(gap + 0.05, y, -2.0), Vector3(gap + 0.05, y, 0.5), hit), "beside the gap: a leaf")
	assert_almost_eq(hit.position.z, -1.3, 1e-3, "on the leaf's face")
	assert_eq(hit.surface, RayHit.Surface.METAL)
	# In through the gap, slanting into the far leaf's edge inside the doorway's depth.
	var from := Vector3(-0.3, y, -1.6)
	var to := Vector3(0.6, y, -0.7)
	assert_true(w.bb_ray(from, to, hit))
	assert_almost_eq(hit.position.x, gap, 1e-3, "on the far leaf's edge")
	assert_between(hit.position.z, -1.3, -1.0)
	assert_eq(hit.normal, Vector3(-1.0, 0.0, 0.0))
	# Shut, then riding: the whole doorway again.
	while state.lifts.phase[0] == LiftState.Phase.SHUTTING:
		sim.step(state, cmds, DT)
	assert_eq(w.lift_ajar_stop[0], -1)
	assert_true(w.bb_ray(Vector3(0.0, y, -2.0), Vector3(0.0, y, 0.5), hit))
	assert_almost_eq(hit.position.z, -1.3, 1e-3, "shut: the doorway's face")


func test_a_bb_from_inside_an_ajar_doorways_gap_flies_on() -> void:
	var w := _lift_world()
	w.set_lift_door(0, 0, true)
	w.set_lift_ajar(0, 0, 0.6)
	var hit := RayHit.new()
	assert_true(w.bb_ray(Vector3(0.0, 1.0, -1.15), Vector3(0.0, 1.0, 1.5), hit), "ended its last tick in the gap")
	assert_gt(hit.position.z, 0.9)
	w.set_lift_ajar(0, -1, 0.0)
	assert_true(w.bb_ray(Vector3(0.0, 1.0, -2.0), Vector3(0.0, 1.0, 1.5), hit))
	assert_almost_eq(hit.position.z, -1.3, 1e-3, "none ajar: the shut doorway")


func test_jolt_flies_a_bb_through_subways_ajar_lift_doorway() -> void:
	var map := MapData.load_map("subway", MapStyle.new(), 6)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, MapStyle.new(), tuning.body, null, null, false, null, tuning.lifts)
	var q := level.query()
	var spec := q.lifts[0]
	q.set_lift_car(0, spec.stops[1])
	q.set_lift_door(0, 1, true)
	q.set_lift_ajar(0, 1, 0.5)
	var door := spec.door_center(1) + Vector3(0.0, -0.5, 0.0)
	var out := Vector3(spec.out.x, 0.0, spec.out.y)
	var side := Vector3(1.0, 0.0, 0.0) if spec.along_x() else Vector3(0.0, 0.0, 1.0)
	var half := (spec.door_to - spec.door_from) * 0.5
	var hit := RayHit.new()
	assert_true(q.ray(door + out, door - out * 0.6, hit), "to bodies the doorway is whole")
	var through := q.bb_ray(door + out, door - out * 0.6, hit)
	assert_true(not through or hit.position.distance_to(door) > spec.door_depth, "a BB through the gap flies on")
	var leaf := door + side * half * 0.75
	assert_true(q.bb_ray(leaf + out, leaf - out * 0.6, hit), "beside it, a leaf")
	assert_almost_eq((hit.position - door).dot(out), spec.door_depth * 0.5, 2e-3, "on the leaf's landing face")
