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


# --- KNOWN_ISSUES 35: a moving range target is swept through its move as a body is ---


## A plate 0.1 m across facing the firing line (+z) at 10 m, which moved 0.15 m along +x this tick (to x 0).
func _moved_plate() -> Array[RangeTarget]:
	var s := RangeTarget.Spec.new()
	s.kind = RangeTarget.Kind.STEEL
	s.position = Vector3(0.0, 1.0, -10.0)
	s.radius = 0.1
	var specs: Array[RangeTarget.Spec] = [s]
	var targets := RangeTargets.create(specs, tuning)
	targets[0].prev_position = targets[0].position - Vector3(0.15, 0.0, 0.0)
	return targets


## Where a BB flying 4 m from (`x`, 1, -8) along -z this tick meets `targets` (-1 none, -2 a post), unswept or swept.
func _plate_hit(targets: Array[RangeTarget], x: float, swept: bool) -> int:
	var out := RangeTargets.Hit.new()
	RangeTargets.first_hit(Vector3(x, 1.0, -8.0), Vector3(0.0, 0.0, -1.0), 4.0, targets, tuning.targets, out,
			4.0 if swept else 0.0, tuning.hits.max_stride)
	return -2 if out.index >= 0 and out.post else out.index


func test_a_bb_meets_a_moving_plate_where_it_was_as_the_bb_crossed() -> void:
	var targets := _moved_plate()
	# The BB crosses the plate's face halfway through the tick, when the plate stood at x -0.075.
	assert_eq(_plate_hit(targets, -0.15, false), -1, "at the tick's end the plate is 0.15 m off: a miss")
	assert_eq(_plate_hit(targets, -0.15, true), 0, "swept, it was 0.075 m off as the BB crossed: a hit")
	assert_eq(_plate_hit(targets, 0.08, false), 0, "where it stands at the tick's end: a hit")
	assert_ne(_plate_hit(targets, 0.08, true), 0, "swept, it was 0.155 m off as the BB crossed: no plate hit")
	targets[0].prev_position = targets[0].position
	assert_eq(_plate_hit(targets, 0.08, true), 0, "a still plate is met where it stands")
	targets[0].prev_position = targets[0].position - Vector3(tuning.hits.max_stride + 0.5, 0.0, 0.0)
	assert_eq(_plate_hit(targets, 0.08, true), 0, "a jump past max_stride (a reset) is no move to sweep")


func test_a_swinger_in_flight_is_swept_by_the_bbs_path() -> void:
	var s := RangeTarget.Spec.new()
	s.kind = RangeTarget.Kind.STEEL
	s.motion = RangeTarget.Motion.SWINGER
	s.position = Vector3(0.0, 1.0, -10.0)
	s.radius = 0.1
	var specs: Array[RangeTarget.Spec] = [s]
	var targets := RangeTargets.create(specs, tuning)
	RangeTargets.step(targets, tuning, DT)
	var t := targets[0]
	var moved := t.position - t.prev_position
	assert_gt(moved.length(), 0.0, "it swings from the off")
	# Aimed at where the plate was halfway through the tick, just past its rim from where it ends the tick.
	var mid := t.prev_position + moved * 0.5
	var aim := mid - moved.normalized() * (t.radius * 0.9)
	assert_gt(Vector2(aim.x - t.position.x, aim.y - t.position.y).length(), t.radius, "a miss at the tick's end")
	var out := RangeTargets.Hit.new()
	var o := Vector3(aim.x, aim.y, -8.0)
	RangeTargets.first_hit(o, Vector3(0.0, 0.0, -1.0), 4.0, targets, tuning.targets, out, 4.0, tuning.hits.max_stride)
	assert_eq(out.index, 0)
	assert_false(out.post)
	assert_almost_eq(out.at, 2.0, 1e-3, "on its face")


# --- KNOWN_ISSUES 84: a rifle over a top just under the wall ray ---


## The lowest point (m) of the held replica's vertices over the cover (z under `face`), and how many lie under `top`,
## for a standing figure holding replica `slot` 3 cm behind a `top` m wall, firing or not.
func _over_cover(slot: int, top: float, fire: bool) -> Vector3:
	var cfg := FigureConfig.new()
	var models := FigureModels.new(cfg)
	models.load_kinds()
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	c.armament.active = slot
	var face := -tuning.body.radius - 0.03
	var world := BoxWorld.new(tuning.body)
	world.add_box(Vector3(0.0, top * 0.5, face - 0.6), Vector3(3.0, top, 1.2))
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, tuning.hits, null)
	v.set_body(models, FigureMix.HUMAN, cfg.lod_high)
	v.set_world(world, tuning.body)
	for i in 24:
		if fire:
			v.on_shot()
		v.update(c, 1.0)
		v.animate(c, 1.0, DT, Vector3(0.0, 1.6, 5.0))
		await wait_process_frames(1)
	var held := v.body().hands.replica(slot)
	var faces := held.mesh.get_faces()
	var low := INF
	var under := 0
	for p in faces:
		var w := held.global_transform * p
		if w.z < face:
			low = minf(low, w.y)
			under += int(w.y < top)
	return Vector3(v._pose.raise_target, low, under)


func test_a_rifle_over_a_1_4_m_top_is_raised_clear_and_lifts_clear_firing() -> void:
	var cfg := FigureConfig.new()
	var level: Vector3 = await _over_cover(0, 1.3, false)
	assert_eq(level.x, 0.0, "a 1.3 m top is under the rifle: no raise")
	assert_eq(int(level.z), 0)
	var idle: Vector3 = await _over_cover(0, 1.4, false)
	assert_eq(idle.x, 1.0, "the second ray meets a 1.4 m top under the first: the high ready")
	assert_eq(int(idle.z), 0, "nothing of the rifle in the top")
	var firing: Vector3 = await _over_cover(0, 1.4, true)
	assert_almost_eq(firing.x, cfg.raise_fire_most, 1e-6, "firing, lifted only the approved share")
	assert_eq(int(firing.z), 0, "and that lifts it clear of a 1.4 m top")
	assert_gt(firing.y, 1.4)


# --- KNOWN_ISSUES 32 (owner 2026-11-14): a Hi-Cap's rattle carries with a run's and a sprint's steps ---


## The footstep events `c` makes over 20 m of moving (sprinting or not) with a magazine that rattles or not.
func _strides(rattling: bool, sprinting: bool, walking: bool = false) -> Array[GameEvent]:
	var r := loadout[0].duplicate() as ReplicaConfig
	r.rattles = rattling
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])
	c.grounded = true
	c.sprinting = sprinting
	c.walking = walking
	var events := SimEvents.new()
	var out: Array[GameEvent] = []
	for i in 400:
		events.clear()
		c.prev_position = c.position
		c.position.z -= 0.05
		Footsteps.step(c, tuning.footsteps, events, BoxWorld.new(tuning.body), tuning.noise)
		for k in events.count:
			var copy := GameEvent.new()
			copy.reset(events.items[k].kind)
			copy.value = events.items[k].value
			copy.slot = events.items[k].slot
			copy.carry = events.items[k].carry
			out.append(copy)
	return out


func test_a_rattling_magazine_adds_its_reach_to_a_run_and_a_sprint() -> void:
	var bots := BotConfig.new()
	var rattle := bots.footstep_hearing_rattle
	for sprinting: bool in [false, true]:
		var plain := _strides(false, sprinting)
		var loud := _strides(true, sprinting)
		assert_eq(loud.size(), plain.size(), "the same strides, sprinting %s" % sprinting)
		assert_gt(plain.size(), 0)
		var step := bots.footstep_hearing_sprint if sprinting else bots.footstep_hearing_run
		assert_eq(plain[0].slot, -1, "nothing rattles")
		assert_almost_eq(BotHearing.footstep_reach(plain[0], bots), step, 1e-4)
		assert_eq(loud[0].slot, 0, "the slot whose magazine rattles")
		assert_almost_eq(BotHearing.footstep_reach(loud[0], bots), step + rattle, 1e-4,
				"run 11 to 18 m, sprint 16 to 23 m")
	# On loud ground the step's own reach carries further and the rattle's is added as it is.
	var gravel := _strides(true, true)[0]
	gravel.carry = tuning.noise.carry(RayHit.Surface.GRAVEL)
	assert_almost_eq(BotHearing.footstep_reach(gravel, bots), bots.footstep_hearing_sprint * gravel.carry + rattle, 1e-4)
	# A walk's rattle is the rattle alone, as before.
	var walk := _strides(true, false, true)
	assert_gt(walk.size(), 0)
	assert_eq(walk[0].value, GameEvent.Footstep.RATTLE)
	assert_almost_eq(BotHearing.footstep_reach(walk[0], bots), rattle, 1e-4)


func test_your_own_run_with_a_rattling_magazine_plays_the_rattle_with_the_step() -> void:
	var sound := SoundConfig.new()
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(sound, [] as Array[StringName], BodyConfig.new(), null, null, tuning.footsteps)
	var state := GameState.new(1)
	var you := Character.new(0, 0, Vector3.ZERO)
	state.characters.append(you)
	var rattle := audio._streams[&"magRattle"] as Array
	for slot: int in [-1, 0]:
		state.time += 1.0
		state.events.clear()
		for v in audio._own:
			v.stop()
		var e := state.events.add(GameEvent.Kind.FOOTSTEP)
		e.actor = 0
		e.value = GameEvent.Footstep.RUN
		e.slot = slot
		e.position = you.position
		audio.on_tick(state, 0, you)
		var rattled := false
		for v in audio._own:
			rattled = rattled or (v.playing and rattle.has(v.stream))
		assert_eq(rattled, slot >= 0, "the rattle with the step only with a rattling magazine (slot %d)" % slot)


# --- KNOWN_ISSUES 58 (owner 2026-11-14): a simulated round keeps its score, gives no XP and sets no records ---


func _tick_events(state: GameState, list: Array) -> void:
	state.events.clear()
	for spec: Array in list:
		var e := state.events.add(spec[0])
		e.actor = spec[1]
		e.target = spec[2]
		e.value = spec[3]
		e.value2 = spec[4] if spec.size() > 4 else 0


func test_a_simulated_round_gives_no_round_won_and_its_hits_and_bbs_count_for_nothing() -> void:
	var state := GameState.new(1)
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var them := Character.new(1, 1, Vector3.ZERO, 0.0, loadout)
	state.characters.append_array([me, them])
	var tally := PlayerTally.new(0)
	var played := GameEvent.RoundEnd.ELIMINATED
	# Round 1, played out and won: one shot, one hit.
	_tick_events(state, [[GameEvent.Kind.ROUND_START, -1, -1, 1], [GameEvent.Kind.SHOT, 0, -1, 0],
			[GameEvent.Kind.CHARACTER_HIT, 0, 1, 0]])
	tally.on_tick(state)
	_tick_events(state, [[GameEvent.Kind.ROUND_OVER, -1, -1, 0, played]])
	tally.on_tick(state)
	# Round 2: two shots and a hit, then out, skipped and simulated as a win for your team.
	_tick_events(state, [[GameEvent.Kind.ROUND_START, -1, -1, 2], [GameEvent.Kind.SHOT, 0, -1, 0],
			[GameEvent.Kind.SHOT, 0, -1, 0], [GameEvent.Kind.CHARACTER_HIT, 0, 1, 0]])
	tally.on_tick(state)
	me.status = Character.Status.OUT
	_tick_events(state, [[GameEvent.Kind.ROUND_OVER, -1, -1, 0, GameEvent.RoundEnd.SIMULATED],
			[GameEvent.Kind.MATCH_OVER, -1, -1, 0]])
	tally.on_tick(state)
	assert_eq([tally.hits, tally.bbs_fired, tally.rounds_won], [1, 1, 1], "only the round played out counts")
	assert_true(tally.is_over(), "the match still ends")
	var table := LevelTable.read_file(Pool.read_file())
	var p := Progress.new(table)
	var r := Records.new()
	var s := tally.settle(p, r, false, 0, 5, "elimination", &"normal", &"normal")
	assert_not_null(s.earned, "the match settles and gives its XP")
	var round_won := 0
	for line in s.earned.lines:
		if line.key == &"round_won":
			round_won = line.count
	assert_eq(round_won, 1, "Round won only for the round played out")
	assert_eq(r.win_loss(&"normal", "elimination"), PackedInt32Array([1, 0]), "the match's win is kept: its score counts")
	assert_eq(r.streak, 1)
