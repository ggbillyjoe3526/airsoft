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
