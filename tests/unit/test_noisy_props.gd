extends GutTest
## Noisy props and loud ground (DP4; the browser game's NP1, sim/propNoise.test.ts and ai/propNoiseHearing.test.ts):
## running or sprinting into a noisy prop knocks it, a BB landing hard on steel rings it, one quiet time a prop, nothing
## random; bots hear a knock as a step and a ring faintly; run, sprint and landing steps on gravel and steel plate carry
## 1.35 times as far (game/sim/prop_noise.gd, footsteps.gd, game/ai/bot_hearing.gd, game/config/noise_config.gd).
## Headless, on BoxWorld fields, Depot's own props read from its level.

const DT := 1.0 / 60.0
const GAP := 0.04
## Yaw that looks along +X (forward is -sin, -cos of the yaw).
const EAST := -PI * 0.5

var tuning: SimTuning = SimTuning.new()
var noise: NoiseConfig = tuning.noise
var loadout: Array[ReplicaConfig] = []
var _bot_map: MapData = null
var _bot_nav: NavGrid = null


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


## A 40 m field with a crate, a skip, a wall and a container, each 3 m north (-Z) of a lane, and two ends.
func _yard() -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	w.add_prop(&"crate", Vector3(0.0, 0.4, -3.0), Vector3(1.2, 0.8, 1.2), RayHit.Surface.WOOD)
	w.add_prop(&"skip", Vector3(8.0, 0.75, -3.5), Vector3(3.0, 1.5, 2.0), RayHit.Surface.METAL)
	w.add_prop(&"wall", Vector3(-8.0, 1.5, -3.2), Vector3(4.0, 3.0, 0.4), RayHit.Surface.CONCRETE)
	w.add_prop(&"container", Vector3(0.0, 1.3, -14.0), Vector3(12.0, 2.6, 2.4), RayHit.Surface.METAL)
	return w


func _ends() -> Array[MapEnd]:
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-15.0 if e == 0 else 15.0, 0.0, 15.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-18.0 if e == 0 else 18.0, 0.0, 18.0), 0.0))
		ends.append(end)
	return ends


## [Simulation, GameState] on `w`: character 0 (team 0) at `at` facing `yaw`, character 1 (team 1) far off.
func _match(w: BoxWorld, at: Vector3, yaw: float = 0.0) -> Array:
	var sim := Simulation.new(tuning, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(3, tuning)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	var c := state.characters[0]
	c.position = at + Vector3(0.0, GAP, 0.0)
	c.prev_position = c.position
	c.yaw = yaw
	c.grounded = true
	return [sim, state]


## Steps `ticks` ticks with character 0 driven by `cmd` (forward, sprint, walk, crouch already set); returns its knocks.
func _drive(sim: Simulation, state: GameState, cmd: PlayerCommand, ticks: int,
		knocks: Array[GameEvent] = []) -> int:
	var cmds: Array[PlayerCommand] = [cmd, null]
	var n := 0
	for t in ticks:
		sim.step(state, cmds, DT)
		for i in state.events.count:
			var e := state.events.items[i]
			if e.kind == GameEvent.Kind.PROP_KNOCK:
				n += 1
				var copy := GameEvent.new()
				copy.reset(e.kind)
				copy.actor = e.actor
				copy.target = e.target
				copy.value = e.value
				copy.value2 = e.value2
				copy.position = e.position
				copy.reach = e.reach
				knocks.append(copy)
	return n


func _cmd(yaw: float, forward: float = 1.0) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	cmd.reset(yaw, 0.0)
	cmd.forward = forward
	return cmd


# --- The table ---


func test_the_np1_table_kinds_reaches_and_silent_kinds() -> void:
	var expect := {
		&"skip": [NoiseConfig.Sound.STEEL, 20.0, 12.0], &"container": [NoiseConfig.Sound.STEEL, 20.0, 12.0],
		&"generator": [NoiseConfig.Sound.CLANK, 17.0, 10.0], &"ibc": [NoiseConfig.Sound.CLANK, 17.0, 10.0],
		&"rack": [NoiseConfig.Sound.RATTLE, 16.0, 0.0], &"toilet": [NoiseConfig.Sound.PLASTIC, 14.0, 0.0],
		&"crate": [NoiseConfig.Sound.WOOD, 13.0, 0.0], &"wrapped": [NoiseConfig.Sound.WOOD, 13.0, 0.0],
	}
	for kind: StringName in expect:
		var row: Array = expect[kind]
		var s: int = noise.props[kind]
		assert_eq(s, row[0], "%s's sound" % kind)
		assert_eq(noise.knock_reach_of(s), row[1], "%s's knock reach" % kind)
		assert_eq(noise.ring_reach_of(s), row[2], "%s's ring reach" % kind)
	for kind: StringName in [&"wall", &"barrier", &"gabion", &"sandbags", &"plywood", &"floor", &"ramp"]:
		assert_false(noise.props.has(kind), "%s is silent" % kind)
	assert_eq(noise.knock_speed, 3.0)
	assert_eq(noise.quiet, 1.2)
	for s: String in NoiseConfig.SOUND_NAMES:
		assert_true(ResourceLoader.exists("%sprop_%s_1.wav" % [SoundConfig.CUE_DIR, s]), "prop_%s has its cue" % s)


func test_gravel_and_steel_plate_carry_1_35_and_the_rest_1() -> void:
	assert_eq(noise.carry(RayHit.Surface.GRAVEL), 1.35)
	assert_eq(noise.carry(RayHit.Surface.METAL), 1.35)
	for s: int in [RayHit.Surface.NONE, RayHit.Surface.CONCRETE, RayHit.Surface.WOOD, RayHit.Surface.EARTH]:
		assert_eq(noise.carry(s), 1.0)


func test_the_halls_drums_barrels_containers_racks_and_crates_are_noisy_and_its_plywood_is_not() -> void:
	var map := MapData.load_map("depot", MapStyle.new(), tuning.rounds.team_size)
	var level := MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body)
	var props := PropNoise.new(noise, level.query())
	var kinds: Dictionary[StringName, int] = {}
	for i in props.count():
		# A block naming its own sound (Depot's steel lockers, a plywood box that clanks, AUD2) counts as that, not its kind.
		if level.query().block_noises[props.block[i]] == &"":
			kinds[level.query().block_kinds[props.block[i]]] = 1
	for k: StringName in [&"drum", &"barrel", &"container", &"rack", &"crate"]:
		assert_true(kinds.has(k), "the hall's %s is noisy" % k)
	for k: StringName in [&"plywood", &"pillar", &"net", &"wall"]:
		assert_false(kinds.has(k), "the hall's %s is silent" % k)
	assert_true(props.rings, "the hall's steel rings")
	level.free()


# The old Depot (the yard fixture since DR1) and its skip, generator, IBC, toilet and pallet loads.
func test_depots_level_lists_its_noisy_props_and_none_of_its_walls() -> void:
	var map := YardMap.load_map(MapStyle.new(), 3)
	var level := MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body)
	var props := PropNoise.new(noise, level.query())
	var kinds: Dictionary[StringName, int] = {}
	for i in props.count():
		var k := level.query().block_kinds[props.block[i]]
		kinds[k] = kinds.get(k, 0) + 1
	for k: StringName in [&"skip", &"container", &"generator", &"ibc", &"rack", &"toilet", &"crate", &"wrapped"]:
		assert_true(kinds.has(k), "Depot's %s is noisy" % k)
	for k: StringName in kinds:
		assert_true(noise.props.has(k), "%s is a noisy kind" % k)
	assert_true(props.rings, "Depot's steel rings")
	level.free()


# --- Knocks ---


func test_running_into_a_crate_knocks_it_once_from_its_face() -> void:
	var m := _match(_yard(), Vector3.ZERO)
	var knocks: Array[GameEvent] = []
	assert_eq(_drive(m[0], m[1], _cmd(0.0), 150, knocks), 1, "one knock, however long the push is held")
	var e := knocks[0]
	assert_eq(e.actor, 0)
	assert_eq(e.value, NoiseConfig.Sound.WOOD)
	assert_eq(e.value2, RayHit.Surface.WOOD)
	assert_eq(e.reach, 13.0)
	assert_almost_eq(e.position.z, -2.4, 0.01, "on the crate's face")
	assert_almost_eq(e.position.y, 0.8, 0.01, "noise_height, held within the crate's 0.8 m")
	var w := _yard()
	assert_eq(w.block_kinds[e.target], &"crate", "the event names the crate's block")


func test_sprinting_into_a_skip_knocks_it_out_to_20_m() -> void:
	var m := _match(_yard(), Vector3(8.0, 0.0, 0.0))
	var cmd := _cmd(0.0)
	cmd.sprint = true
	var knocks: Array[GameEvent] = []
	assert_eq(_drive(m[0], m[1], cmd, 50, knocks), 1)
	assert_eq(knocks[0].value, NoiseConfig.Sound.STEEL)
	assert_eq(knocks[0].reach, 20.0)


func test_walking_crouching_or_running_into_a_wall_is_silent() -> void:
	var walk := _cmd(0.0)
	walk.walk = true
	var m := _match(_yard(), Vector3.ZERO)
	assert_eq(_drive(m[0], m[1], walk, 90), 0, "a walk (2.3 m/s) into the crate")
	m = _match(_yard(), Vector3.ZERO)
	var crouch := _cmd(0.0)
	crouch.crouch = true
	assert_eq(_drive(m[0], m[1], crouch, 120), 0, "a crouch (2.1 m/s)")
	m = _match(_yard(), Vector3(-8.0, 0.0, 0.0))
	assert_eq(_drive(m[0], m[1], _cmd(0.0), 60), 0, "a run into a wall")


func test_a_run_glancing_along_a_container_is_silent_and_one_into_it_knocks() -> void:
	# The container's south face is at z = -12.8; run from 2 m short of it at 30° to it, then at 60°.
	var glancing := -PI / 3.0 # moving along (cos 30°, 0, -sin 30°)
	var m := _match(_yard(), Vector3(-5.0, 0.0, -10.0), glancing)
	assert_eq(_drive(m[0], m[1], _cmd(glancing), 90), 0, "30° to its face: 2.1 m/s into it")
	var steep := -PI / 6.0 # moving along (cos 60°, 0, -sin 60°)
	m = _match(_yard(), Vector3(-5.0, 0.0, -10.0), steep)
	assert_eq(_drive(m[0], m[1], _cmd(steep), 90), 1, "60° to its face: 3.6 m/s into it")


func test_one_quiet_time_a_prop_whoever_sets_it_off() -> void:
	var w := _yard()
	var props := PropNoise.new(noise, w)
	var state := GameState.new(1, tuning)
	props.prepare(state)
	var c := Character.new(4, 0)
	c.position = Vector3(0.0, GAP, -2.4 + tuning.body.radius + 0.01)
	c.wanted_move = Vector3(0.0, 0.0, -4.2 * DT)
	c.made_move = Vector3.ZERO
	props.knock(c, tuning.body, DT, state)
	assert_eq(state.events.count_of(GameEvent.Kind.PROP_KNOCK), 1)
	var d := Character.new(5, 1)
	d.position = Vector3(0.0, GAP, -3.6 - tuning.body.radius - 0.01)
	d.wanted_move = Vector3(0.0, 0.0, 4.2 * DT)
	state.time = 1.1
	state.events.clear()
	props.knock(d, tuning.body, DT, state)
	assert_eq(state.events.count_of(GameEvent.Kind.PROP_KNOCK), 0, "still quiet 1.1 s on, from the other side")
	state.time = 1.25
	props.knock(d, tuning.body, DT, state)
	assert_eq(state.events.count_of(GameEvent.Kind.PROP_KNOCK), 1, "sounds again after 1.2 s")
	assert_eq(state.events.first(GameEvent.Kind.PROP_KNOCK).actor, 5)


func test_standing_on_a_crate_is_not_running_into_it() -> void:
	var w := _yard()
	var props := PropNoise.new(noise, w)
	var state := GameState.new(1, tuning)
	props.prepare(state)
	var c := Character.new(0, 0)
	c.position = Vector3(0.0, 0.8 + GAP, -3.0) # on top, stopped by something ahead
	c.wanted_move = Vector3(0.0, 0.0, -6.3 * DT)
	props.knock(c, tuning.body, DT, state)
	assert_eq(state.events.count, 0)


func test_knocks_are_the_same_on_every_run() -> void:
	var at: Array[float] = []
	for run in 2:
		var m := _match(_yard(), Vector3(8.0, 0.0, 0.0))
		var state: GameState = m[1]
		var cmd := _cmd(0.0)
		cmd.sprint = true
		var knocks: Array[GameEvent] = []
		_drive(m[0], state, cmd, 50, knocks)
		at.append(knocks[0].position.x + knocks[0].position.z * 100.0 + state.tick * 1e4)
	assert_eq(at[0], at[1])


# --- Rings ---


func _impact(state: GameState, at: Vector3, speed: float, actor: int = 0, target: int = -1) -> void:
	var e := state.events.add(GameEvent.Kind.BB_IMPACT)
	e.actor = actor
	e.target = target
	e.position = at
	e.direction = Vector3(0.0, 0.0, -speed)


func test_a_bb_landing_hard_on_steel_rings_it_and_not_on_wood_or_spent() -> void:
	var props := PropNoise.new(noise, _yard())
	var state := GameState.new(1, tuning)
	props.prepare(state)
	_impact(state, Vector3(8.0, 1.0, -2.5), 60.0, 3)
	props.ring(state, 0)
	var ring := state.events.first(GameEvent.Kind.PROP_RING)
	assert_not_null(ring, "a BB at 60 m/s on the skip's face rings it")
	assert_eq(ring.actor, 3)
	assert_eq(ring.reach, 12.0)
	assert_eq(ring.value, NoiseConfig.Sound.STEEL)
	assert_eq(ring.position, Vector3(8.0, 1.0, -2.5), "heard where it rang")
	state = GameState.new(1, tuning)
	props.prepare(state)
	_impact(state, Vector3(0.0, 0.5, -2.4), 60.0)
	_impact(state, Vector3(8.0, 1.0, -2.5), 14.0)
	_impact(state, Vector3(8.0, 1.0, -2.5), 60.0, 0, 1)
	props.ring(state, 0)
	assert_eq(state.events.count_of(GameEvent.Kind.PROP_RING), 0, "wood, a spent BB and a body never ring")


func test_a_ring_and_a_knock_share_the_quiet_time() -> void:
	var props := PropNoise.new(noise, _yard())
	var state := GameState.new(1, tuning)
	props.prepare(state)
	_impact(state, Vector3(8.0, 1.0, -2.5), 60.0)
	_impact(state, Vector3(8.2, 1.1, -2.5), 60.0)
	props.ring(state, 0)
	assert_eq(state.events.count_of(GameEvent.Kind.PROP_RING), 1, "two BBs in one tick: one ring")
	state.events.clear()
	var c := Character.new(0, 0)
	c.position = Vector3(8.0, GAP, -2.5 + tuning.body.radius + 0.01)
	c.wanted_move = Vector3(0.0, 0.0, -6.3 * DT)
	state.time = 0.5
	props.knock(c, tuning.body, DT, state)
	assert_eq(state.events.count_of(GameEvent.Kind.PROP_KNOCK), 0, "the ring's quiet time holds the knock")


func test_a_bb_fired_at_a_skip_rings_it_in_play() -> void:
	var m := _match(_yard(), Vector3(8.0, 0.0, 4.0))
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmd := PlayerCommand.new()
	cmd.reset(0.0, -0.1) # at the skip's face, about 1 m up
	var rings := 0
	var landed := 0
	var cmds: Array[PlayerCommand] = [cmd, null]
	for t in 66:
		cmd.fire = t % 2 == 0
		sim.step(state, cmds, DT)
		rings += state.events.count_of(GameEvent.Kind.PROP_RING)
		landed += state.events.count_of(GameEvent.Kind.BB_IMPACT)
	assert_gt(landed, 1, "several BBs land on it")
	assert_eq(rings, 1, "the skip 6 m ahead rings once in 1.1 s, however many BBs land")


# --- Loud ground ---


func test_run_sprint_and_landing_steps_on_gravel_carry_further_and_a_rattle_does_not() -> void:
	var gravel := BoxWorld.new(tuning.body)
	gravel.add_box(Vector3(0.0, -0.25, 0.0), Vector3(20.0, 0.5, 20.0), RayHit.Surface.GRAVEL)
	var events := SimEvents.new()
	var c := Character.new()
	c.position = Vector3(0.0, GAP, 0.0)
	c.prev_position = c.position
	c.grounded = true
	c.step_distance = tuning.footsteps.stride_run
	Footsteps.step(c, tuning.footsteps, events, gravel, noise)
	assert_eq(events.first(GameEvent.Kind.FOOTSTEP).carry, 1.35, "a run on gravel")
	events.clear()
	c.grounded = false
	c.velocity.y = -6.0
	Footsteps.step(c, tuning.footsteps, events, gravel, noise)
	c.grounded = true
	Footsteps.step(c, tuning.footsteps, events, gravel, noise)
	var land := events.first(GameEvent.Kind.FOOTSTEP)
	assert_eq(land.value, GameEvent.Footstep.LAND)
	assert_eq(land.carry, 1.35, "a landing on gravel")
	events.clear()
	c.walking = true
	c.step_distance = 0.0
	for i in 60:
		c.prev_position = c.position
		c.position.z -= 0.1
		Footsteps.step(c, tuning.footsteps, events, gravel, noise)
	assert_eq(events.count_of(GameEvent.Kind.FOOTSTEP), 0, "walking stays silent on gravel")
	var concrete := BoxWorld.new(tuning.body)
	concrete.add_box(Vector3(0.0, -0.25, 0.0), Vector3(20.0, 0.5, 20.0), RayHit.Surface.CONCRETE)
	c.walking = false
	c.step_distance = tuning.footsteps.stride_run
	Footsteps.step(c, tuning.footsteps, events, concrete, noise)
	assert_eq(events.first(GameEvent.Kind.FOOTSTEP).carry, 1.0, "a run on concrete")


# --- What the bots hear ---


## Team 0's bots (ids 0 and 1, Hard: they play as a team) at the field's west, team 1's knocker (id 2) `away` m east.
func _bots(away: float) -> Array:
	if _bot_map == null:
		_bot_map = MapData.new()
		_bot_map.id = "noise field"
		var floor_block := MapData.Block.new()
		floor_block.kind = &"floor"
		floor_block.center = Vector3(0.0, -0.25, 0.0)
		floor_block.size = Vector3(40.0, 0.5, 12.0)
		_bot_map.blocks.append(floor_block)
		_bot_map.ends = _ends()
		_bot_nav = NavGrid.build(_bot_map, tuning.nav, tuning.body)
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(40.0, 0.5, 12.0))
	var state := GameState.new(9, tuning)
	state.characters.append(Character.new(0, 0, Vector3(-15.0, GAP, 0.0), EAST, loadout))
	state.characters.append(Character.new(1, 0, Vector3(-15.0, GAP, 3.0), EAST, loadout))
	state.characters.append(Character.new(2, 1, Vector3(-15.0 + away, GAP, 0.0), -EAST, loadout))
	var levels: Dictionary[int, StringName] = {0: &"hard", 1: &"easy"}
	var bots := BotController.new(state, -1, _bot_map, _bot_nav, w, tuning, BotConfig.load_default(), levels)
	bots.world.time = 10.0
	state.time = 10.0
	return [state, bots]


func _event(state: GameState, bots: BotController, kind: GameEvent.Kind, at: Vector3, reach_m: float,
		carry: float = 1.0) -> void:
	state.events.clear()
	var e := state.events.add(kind)
	e.actor = 2
	e.position = at
	e.reach = reach_m
	e.carry = carry
	e.value = GameEvent.Footstep.SPRINT
	BotHearing.observe(state, bots.world)


func test_bots_hear_a_knock_as_a_step_out_to_the_props_reach() -> void:
	var b: Array = _bots(15.0)
	var state: GameState = b[0]
	var bots: BotController = b[1]
	var knocker := state.characters[2]
	_event(state, bots, GameEvent.Kind.PROP_KNOCK, knocker.position + Vector3(0.4, 0.9, 0.0), 13.0)
	assert_false(bots.world.bots[0].has_last_known, "a crate's knock 15 m off is not heard")
	_event(state, bots, GameEvent.Kind.PROP_KNOCK, knocker.position + Vector3(0.4, 0.9, 0.0), 20.0)
	var hearer := bots.world.bots[0]
	assert_true(hearer.has_last_known, "a skip's knock 15 m off is")
	assert_eq(hearer.heard_at, 10.0)
	var off := Vector2(hearer.last_known.x - knocker.position.x, hearer.last_known.z - knocker.position.z).length()
	assert_lte(off, 15.5 * BotConfig.load_default().hearing_error + 0.01, "a guess of where the knocker is")
	assert_true(bots.world.bots[1].has_last_known, "its teammate too")


func test_a_ring_turns_only_an_idle_bots_head_and_is_not_shared() -> void:
	var b: Array = _bots(30.0)
	var state: GameState = b[0]
	var bots: BotController = b[1]
	var hearer := bots.world.bots[0]
	var mate := bots.world.bots[1]
	mate.heard_at = 9.5 # fresh news of its own
	var at := Vector3(-6.0, 1.0, 0.0)
	_event(state, bots, GameEvent.Kind.PROP_RING, at, 12.0)
	assert_true(hearer.has_last_known, "an idle bot 9 m off hears it")
	assert_lte(Vector2(hearer.last_known.x - at.x, hearer.last_known.z - at.z).length(), 9.0 * 0.5,
			"a guess of where it rang, not of the shooter 30 m off")
	assert_false(mate.has_last_known, "a bot with fresher news ignores it, and nobody shares it")
	var again: Array = _bots(30.0)
	var quiet_state: GameState = again[0]
	var quiet_bots: BotController = again[1]
	var busy := quiet_bots.world.bots[0]
	busy.heard_at = 8.5
	_event(quiet_state, quiet_bots, GameEvent.Kind.PROP_RING, at, 12.0)
	assert_eq(busy.heard_at, 8.5, "news 1.5 s old is fresher than a ring")


func test_bots_hear_a_sprint_on_loud_ground_1_35_times_as_far() -> void:
	var b: Array = _bots(18.0)
	var state: GameState = b[0]
	var bots: BotController = b[1]
	var walker := state.characters[2]
	_event(state, bots, GameEvent.Kind.FOOTSTEP, walker.position, 0.0)
	assert_false(bots.world.bots[0].has_last_known, "a sprint 18 m off carries 16 m on concrete")
	_event(state, bots, GameEvent.Kind.FOOTSTEP, walker.position, 0.0, 1.35)
	assert_true(bots.world.bots[0].has_last_known, "and 21.6 m on gravel")


# --- Cost ---


func test_knocks_and_rings_allocate_nothing_once_warm() -> void:
	var m := _match(_yard(), Vector3(8.0, 0.0, 4.0))
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmd := _cmd(0.0)
	cmd.sprint = true
	cmd.fire = true
	var cmds: Array[PlayerCommand] = [cmd, null]
	for t in 120:
		sim.step(state, cmds, DT)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for t in 240:
		cmd.forward = 1.0 if (t / 30) % 2 == 0 else -1.0
		cmd.reload = state.characters[0].armament.mag() == 0
		sim.step(state, cmds, DT)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
