extends GutTest
## LZ1 QA: Dev > Lasers at the seams test_lasers.gd leaves: the switch through a real saved file, range targets, friendly
## fire, a laser fired from inside a bush, a stale pooled BB, the Armament's SHOT, a new match, the beam node's
## on_tick, update and clear, and the laser's own sound.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
const MASS := 0.25e-3
const SPEED := 88.0
const CHEST := 1.3
const Targets := preload("res://tests/unit/test_range_targets.gd")

var tuning: SimTuning = SimTuning.new()
var events: SimEvents = SimEvents.new()
var ends: Array[MapEnd] = []


func before_each() -> void:
	tuning = SimTuning.new()
	tuning.hits.fit = null
	events = SimEvents.new()


func _pair(gap: float, team: int = 1) -> Array[Character]:
	var roster: Array[Character] = [Character.new(0, 0, Vector3.ZERO, 0.0),
			Character.new(1, team, Vector3(0.0, 0.0, -gap), 0.0)]
	return roster


func _fire(roster: Array[Character], query: WorldQuery, from: Vector3, as_laser: bool = true, cease: bool = false,
		targets: Array[RangeTarget] = []) -> BB:
	var pool := BBPool.new(4)
	var bb := pool.spawn(0, from, Vector3.FORWARD, SPEED, 0.0, MASS, tuning.ballistics.spin_per_hop, 0)
	bb.laser = as_laser
	BBStep.step(pool, roster, query, tuning, KILL_Y, cease, ends, events, DT, Vector3.ZERO, null, targets)
	return bb


# --- The switch ---


func test_the_switch_survives_a_real_saved_settings_file() -> void:
	var dir := "user://test-lasers-qa"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("settings.save")
	var s := Settings.new(PlayTuning.new())
	assert_false(s.dev.lasers, "off in a fresh settings")
	s.dev.lasers = true
	assert_true(s.save(path))
	var again := Settings.new(PlayTuning.new())
	again.load_file(path)
	assert_true(again.dev.lasers)
	assert_true(again.dev.cheats().lasers)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)


func test_lasers_alone_make_a_match_off_the_record_and_survive_a_new_match() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	var sim := Simulation.new(tuning, w, w.mover(), ends, KILL_Y)
	var state := GameState.new(3, tuning)
	for i in 4:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	var cheats := DevCheats.new()
	cheats.lasers = true
	DevCheats.apply(state, cheats, 0)
	sim.start_match(state)
	assert_true(state.off_record)
	sim.start_match(state)
	for c in state.characters:
		assert_true(c.lasers, "a new match keeps the switch")


# --- Hits ---


func test_a_laser_knocks_out_a_teammate_when_friendly_fire_is_on() -> void:
	tuning.hits.friendly_fire = true
	var roster := _pair(15.0, 0)
	_fire(roster, WorldQuery.new(), Vector3(0.0, CHEST, 0.0))
	assert_eq(events.count_of(GameEvent.Kind.CHARACTER_HIT), 1)
	assert_ne(roster[1].status, Character.Status.ALIVE)


func test_a_laser_stops_on_the_first_of_two_bodies_in_line() -> void:
	var roster := _pair(10.0)
	roster.append(Character.new(2, 1, Vector3(0.0, 0.0, -20.0), 0.0))
	_fire(roster, WorldQuery.new(), Vector3(0.0, CHEST, 0.0))
	assert_ne(roster[1].status, Character.Status.ALIVE)
	assert_eq(roster[2].status, Character.Status.ALIVE, "one laser, one body")
	assert_eq(events.count_of(GameEvent.Kind.CHARACTER_HIT), 1)


func test_a_laser_on_a_body_already_out_knocks_nobody_further_along() -> void:
	var roster := _pair(10.0)
	roster.append(Character.new(2, 1, Vector3(0.0, 0.0, -20.0), 0.0))
	Elimination.eliminate(roster[1], 0, roster, ends)
	roster[1].position = Vector3(0.0, 0.0, -10.0)
	_fire(roster, WorldQuery.new(), Vector3(0.0, CHEST, 0.0))
	assert_eq(events.count_of(GameEvent.Kind.CHARACTER_HIT), 0, "no second knock-out")
	assert_eq(roster[2].status, Character.Status.ALIVE)


func _plate() -> Array[RangeTarget]:
	var spec := Targets.spec(RangeTarget.Kind.STEEL, Vector3(0.0, CHEST, -25.0), "plate", 25.0)
	var specs: Array[RangeTarget.Spec] = [spec]
	return RangeTargets.create(specs, tuning)


func test_a_laser_hits_a_range_plate_instantly_and_ends_the_beam_on_it() -> void:
	_fire(_pair(60.0), WorldQuery.new(), Vector3(0.0, CHEST, 0.0), true, false, _plate())
	assert_eq(events.count_of(GameEvent.Kind.TARGET_HIT), 1)
	assert_almost_eq(events.first(GameEvent.Kind.LASER).position.z, -25.0, 0.05)
	assert_eq(events.count_of(GameEvent.Kind.CHARACTER_HIT), 0, "the plate was nearer than the body")


func test_a_laser_passes_a_range_plate_in_a_cease_fire() -> void:
	_fire(_pair(60.0), WorldQuery.new(), Vector3(0.0, CHEST, 0.0), true, true, _plate())
	assert_eq(events.count_of(GameEvent.Kind.TARGET_HIT), 0)
	assert_eq(events.count_of(GameEvent.Kind.CHARACTER_HIT), 0, "cease-fire: nobody out")


func test_a_laser_fired_from_inside_a_bush_leaves_it_and_hits_beyond() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_bush(Vector3(0.0, 0.0, 0.0), 0.3, 2.0)
	var roster := _pair(20.0)
	# Muzzle in the bush's middle: only the 0.3 m radius to cross, under the 0.6 m that stops it.
	_fire(roster, w, Vector3(0.0, 1.0, 0.0))
	assert_ne(roster[1].status, Character.Status.ALIVE)


func test_a_laser_fired_from_deep_inside_a_big_bush_stops_in_its_leaves() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_bush(Vector3(0.0, 0.0, 0.0), 2.0, 3.0)
	var roster := _pair(20.0)
	_fire(roster, w, Vector3(0.0, 1.0, 0.0))
	assert_eq(roster[1].status, Character.Status.ALIVE)
	var stop := events.first(GameEvent.Kind.BB_IMPACT)
	assert_not_null(stop)
	if stop != null:
		assert_eq(stop.value, BBStep.IN_LEAVES)
		assert_almost_eq(stop.position.z, -tuning.ballistics.leaf_stop_depth, 0.05)


func test_a_full_pool_of_lasers_leaves_no_bb_in_flight() -> void:
	var pool := BBPool.new(2)
	for i in 3:
		var bb := pool.spawn(0, Vector3(0.0, CHEST, 0.0), Vector3.FORWARD, SPEED, 0.0, MASS, 1.0, 0)
		bb.laser = true
	BBStep.step(pool, _pair(10.0), WorldQuery.new(), tuning, KILL_Y, false, ends, events, DT)
	for bb in pool.bbs:
		assert_false(bb.active, "every laser is free again")


func test_a_bb_spawned_after_a_laser_in_the_same_slot_flies() -> void:
	var pool := BBPool.new(1)
	pool.spawn(0, Vector3.ZERO, Vector3.FORWARD, SPEED, 0.0, MASS, 1.0).laser = true
	var bb := pool.spawn(0, Vector3(0.0, CHEST, 0.0), Vector3.FORWARD, SPEED, 0.0, MASS, 1.0)
	BBStep.step(pool, _pair(10.0), WorldQuery.new(), tuning, KILL_Y, false, ends, events, DT)
	assert_eq(events.count_of(GameEvent.Kind.LASER), 0, "not resolved at once")
	assert_true(bb.active or events.count_of(GameEvent.Kind.CHARACTER_HIT) > 0)
	assert_lt(bb.position.z, 0.0, "it moved a tick's flight, no more")
	assert_gt(bb.position.z, -2.0)


# --- Armament ---


func _shoot_once(lasers: bool) -> Array:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.lasers = lasers
	var cmd := PlayerCommand.new()
	cmd.fire = true
	var pool := BBPool.new(8)
	for i in 120:
		events.clear()
		Armament.step(c, cmd, Vector3(0.0, 1.6, 0.0), 1.0, true, pool, RandomNumberGenerator.new(), events, tuning, DT)
		if events.count_of(GameEvent.Kind.SHOT) > 0:
			return [events.first(GameEvent.Kind.SHOT), pool]
	return []


func test_a_laser_shot_event_is_marked_and_a_bb_shot_is_not() -> void:
	var l := _shoot_once(true)
	assert_eq(l.size(), 2, "it fired")
	var live := 0
	if l.size() == 2:
		assert_eq((l[0] as GameEvent).value2, GameEvent.SHOT_LASER)
		for bb: BB in (l[1] as BBPool).bbs:
			if bb.active:
				assert_true(bb.laser)
				live += 1
		assert_eq(live, 1)
	var b := _shoot_once(false)
	assert_eq(b.size(), 2, "it fired")
	if b.size() == 2:
		assert_eq((b[0] as GameEvent).value2, 0)
		for bb: BB in (b[1] as BBPool).bbs:
			assert_false(bb.laser)


# --- The beam node ---


func _beams(count: int = 3) -> LaserBeams:
	var b := LaserBeams.new()
	add_child_autofree(b)
	b.setup(EffectsConfig.new(), count, PackedColorArray([Color.RED, Color.BLUE]), BodyConfig.new())
	return b


func _laser_state(actor: int, end: Vector3) -> GameState:
	var s := GameState.new(1, tuning)
	for i in 3:
		s.characters.append(Character.new(i, i % 2, Vector3(float(i), 0.0, 0.0), 0.0, ReplicaStats.default_loadout()))
	var e := s.events.add(GameEvent.Kind.LASER)
	e.actor = actor
	e.slot = 0
	e.position = end
	return s


func _camera() -> Camera3D:
	var cam := Camera3D.new()
	add_child_autofree(cam)
	cam.position = Vector3(0.0, 1.6, 5.0)
	return cam


func _draw(b: LaserBeams, s: GameState, cam: Camera3D, dt: float) -> void:
	var figs: Array[FigureView] = []
	b.update(s.characters, s.characters[0], Vector3(0.0, 1.3, 0.0), true, cam, 1.0, dt, figs)


func test_a_beam_shows_after_a_laser_event_and_goes_out_after_its_hold_time() -> void:
	var b := _beams()
	var s := _laser_state(0, Vector3(0.0, 1.3, -30.0))
	var cam := _camera()
	b.on_tick(s)
	_draw(b, s, cam, DT)
	assert_eq(b.shown_count(), 1)
	_draw(b, s, cam, 1.0)
	_draw(b, s, cam, DT)
	assert_eq(b.shown_count(), 0, "off once its time is up")


func test_clear_puts_every_beam_out_at_once() -> void:
	var b := _beams()
	var s := _laser_state(1, Vector3(0.0, 1.3, -30.0))
	var cam := _camera()
	b.on_tick(s)
	_draw(b, s, cam, DT)
	assert_eq(b.shown_count(), 1)
	b.clear()
	assert_eq(b.shown_count(), 0)
	_draw(b, s, cam, DT)
	assert_eq(b.shown_count(), 0, "a cleared beam does not come back")


func test_a_laser_event_of_an_unknown_shooter_is_ignored() -> void:
	var b := _beams()
	var s := _laser_state(9, Vector3(0.0, 1.3, -30.0))
	b.on_tick(s)
	s.events.items[0].actor = -1
	b.on_tick(s)
	_draw(b, s, _camera(), DT)
	assert_eq(b.shown_count(), 0)


func test_spectating_a_bot_draws_its_beam_from_under_the_camera() -> void:
	var b := _beams()
	var s := _laser_state(1, Vector3(0.0, 1.3, -30.0))
	var cam := _camera()
	b.on_tick(s)
	var figs: Array[FigureView] = []
	b.update(s.characters, s.characters[1], Vector3.ZERO, false, cam, 1.0, DT, figs)
	assert_eq(b.shown_count(), 1, "drawn though the watched bot's replica is not the player's in hand")


func test_updating_beams_allocates_no_objects_once_warm() -> void:
	var b := _beams()
	var s := _laser_state(0, Vector3(0.0, 1.3, -30.0))
	var cam := _camera()
	var figs: Array[FigureView] = []
	for i in 30:
		b.on_tick(s)
		b.update(s.characters, s.characters[0], Vector3(0.0, 1.3, 0.0), true, cam, 1.0, DT, figs)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 600:
		b.on_tick(s)
		b.update(s.characters, s.characters[0], Vector3(0.0, 1.3, 0.0), true, cam, 0.5, DT, figs)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


func test_hold_time_of_a_replica_with_no_fire_rate_is_still_a_flash() -> void:
	var cfg := EffectsConfig.new()
	for mode: ReplicaConfig.FireMode in [ReplicaConfig.FireMode.AUTO, ReplicaConfig.FireMode.BURST,
			ReplicaConfig.FireMode.SEMI]:
		var t := LaserBeams.hold_time(cfg, mode, 0.0)
		assert_gt(t, 0.0)
		assert_lte(t, cfg.laser_flash_time + 1e-6)


# --- The sound ---


func _heard(audio: SimAudio, cue: StringName) -> int:
	var n := 0
	var streams: Array = audio._streams.get(cue, [])
	for v in audio._field:
		if v.playing and streams.has(v.stream):
			n += 1
	for v in audio._own:
		if v.playing and streams.has(v.stream):
			n += 1
	return n


func _shot(state: GameState, laser: bool) -> void:
	state.events.clear()
	var shot := state.events.add(GameEvent.Kind.SHOT)
	shot.actor = 0
	shot.slot = 0
	shot.position = Vector3(0.0, 1.6, 0.0)
	if laser:
		shot.value2 = GameEvent.SHOT_LASER


func test_a_laser_shot_plays_the_laser_cue_and_a_bb_shot_does_not() -> void:
	var state := GameState.new(1, tuning)
	var you := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	state.characters.append(you)
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [&"aeg"] as Array[StringName], BodyConfig.new(), BoxWorld.new(BodyConfig.new()), null)
	assert_true(audio._streams.has(SimAudio.LASER_CUE), "loaded")
	_shot(state, false)
	audio.on_tick(state, 0, you)
	assert_eq(_heard(audio, SimAudio.LASER_CUE), 0, "a BB's shot")
	_shot(state, true)
	audio.on_tick(state, 0, you)
	assert_eq(_heard(audio, SimAudio.LASER_CUE), 1, "a laser's shot")
