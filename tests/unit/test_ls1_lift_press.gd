extends GutTest
## LS1 (owner, 2026-11-21: "lift sound timing still off. should play just after the player presses a button. should
## also only play when the player is inside the lift"): a press from just inside a car's door shuts its doors on the
## next tick, heard then, instead of waiting silently for the presser to step further in; the presser is eased clear of
## the doorway while the leaves still stand open; a body walking into the doorway from outside before it is sealed
## opens the doors again; a car's own sounds are heard only from inside it, its buttons' beeps wherever in reach
## (game/sim/lifts.gd, game/config/lift_config.gd, game/play/sim_audio.gd, minimap_hearing.gd, sound_cues.gd).

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


func _match(n: int = 1) -> Array:
	var q := level.query()
	var sim := Simulation.new(tuning, q, level.mover(tuning.body), map.ends, map.kill_y)
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


## Feet `depth` m in from lift `spec`'s door face at stop `k`, mid door (negative: out on the landing).
func _in_from_face(spec: LiftSpec, k: int, depth: float) -> Vector3:
	return spec.on_face((spec.door_from + spec.door_to) * 0.5, -depth, spec.stops[k])


## Steps `n` ticks, character 0 pressing `press` (lift, stop) on the first; each tick's LIFT cues of lift `i`, a list a
## tick.
func _step(sim: Simulation, state: GameState, n: int, i: int, press: Vector2i = Lifts.NONE) -> Array:
	var cmds: Array[PlayerCommand] = []
	for c in state.characters:
		cmds.append(PlayerCommand.new())
	var ticks: Array = []
	for t in n:
		for c in state.characters.size():
			cmds[c].reset(state.characters[c].yaw, state.characters[c].pitch)
		if t == 0 and press != Lifts.NONE:
			cmds[0].use_door = true
			cmds[0].lift_to_use = press.x
			cmds[0].lift_stop = press.y
		sim.step(state, cmds, DT)
		var cues: Array[int] = []
		for k in state.events.count:
			var e := state.events.items[k]
			if e.kind == GameEvent.Kind.LIFT and e.target == i:
				cues.append(e.value)
		ticks.append(cues)
	return ticks


func _first(ticks: Array, cue: int) -> int:
	for t in ticks.size():
		if cue in (ticks[t] as Array[int]):
			return t
	return -1


func test_a_press_from_just_inside_the_door_is_heard_shutting_at_once_and_the_presser_steps_in() -> void:
	var q := level.query()
	for i in q.lifts.size():
		var spec := q.lifts[i]
		for depth: float in [0.02, 0.1, 0.2, 0.3]:
			var m := _match()
			var sim: Simulation = m[0]
			var state: GameState = m[1]
			var k := state.lifts.stop[i]
			var me := state.characters[0]
			_stand(me, _in_from_face(spec, k, depth))
			assert_true(spec.holds(me.position, state.lifts.y[i], cfg), "aboard")
			assert_true(sim.lifts.doorway_blocked(i, k, state.characters), "%.2f m in: in the doorway" % depth)
			var lead := roundi(cfg.shut_lead / DT)
			var ticks := _step(sim, state, lead - 1, i, Vector2i(i, 1 - k))
			assert_eq(_first(ticks, Lifts.Cue.BUTTON), 0, "the beep on the press")
			assert_eq(_first(ticks, Lifts.Cue.SHUTTING), 1, "lift %d, %.2f m in: the doors heard the tick after" % [i, depth])
			assert_false(sim.lifts.doorway_blocked(i, k, state.characters), "stepped in clear within the lead")
			assert_eq(state.lifts.sealed[i], 1, "the doorway is solid to bodies again")
			assert_eq(state.lifts.doors[i], 1.0, "the leaves still stand open")
			var depart := _step(sim, state, roundi(cfg.door_time / DT) - lead + 8, i)
			assert_gt(_first(depart, Lifts.Cue.DEPART), -1, "and the car sets off on time")
			assert_true(spec.holds(me.position, state.lifts.y[i], cfg), "with the presser aboard")


func test_a_press_from_well_inside_seals_the_doorway_as_the_doors_are_heard() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var spec := level.query().lifts[1]
	var k := state.lifts.stop[1]
	var me := state.characters[0]
	_stand(me, spec.car_point(spec.stops[k]))
	var before := me.position
	var ticks := _step(sim, state, 2, 1, Vector2i(1, 1 - k))
	assert_eq(_first(ticks, Lifts.Cue.SHUTTING), 1)
	assert_eq(state.lifts.sealed[1], 1, "nobody in the doorway: solid from the start, as before")
	assert_almost_eq(Vector2(me.position.x - before.x, me.position.z - before.z).length(), 0.0, 1e-4, "nobody is moved")


func test_a_body_walking_into_the_doorway_from_the_landing_before_it_is_sealed_opens_the_doors() -> void:
	var m := _match(2)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var i := 1
	var spec := level.query().lifts[i]
	var k := state.lifts.stop[i]
	_stand(state.characters[0], _in_from_face(spec, k, 0.05))
	_stand(state.characters[1], spec.landing_point(k, cfg) + Vector3(spec.out.x, 0.0, spec.out.y) * 2.0)
	var ticks := _step(sim, state, 2, i, Vector2i(i, 1 - k))
	assert_eq(_first(ticks, Lifts.Cue.SHUTTING), 1)
	assert_eq(state.lifts.sealed[i], 0, "the presser still steps in")
	# The other walks into the doorway from the landing while it is still open to bodies.
	_stand(state.characters[1], _in_from_face(spec, k, -0.15))
	ticks = _step(sim, state, 1, i)
	assert_eq(_first(ticks, Lifts.Cue.OPENING), 0, "heard opening again")
	assert_eq(state.lifts.phase[i], LiftState.Phase.OPENING)
	assert_true(state.lifts.called(i, 1 - k), "the call kept for after")
	_step(sim, state, 3, i)
	assert_eq(state.lifts.phase[i], LiftState.Phase.OPEN, "the leaves had not moved: open at once")


func test_a_body_aboard_that_never_clears_holds_the_leaves_open_past_the_lead() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var i := 1
	var spec := level.query().lifts[i]
	var k := state.lifts.stop[i]
	var at := _in_from_face(spec, k, 0.05)
	_stand(state.characters[0], at)
	var was := cfg.step_in_speed
	cfg.step_in_speed = 0.0
	_step(sim, state, roundi(cfg.door_time / DT) + 10, i, Vector2i(i, 1 - k))
	cfg.step_in_speed = was
	assert_eq(state.lifts.phase[i], LiftState.Phase.SHUTTING, "still shutting, the leaves waiting")
	assert_eq(state.lifts.doors[i], 1.0, "never shut on the body")
	assert_eq(state.lifts.sealed[i], 0)


func _event(cue: int, i: int) -> GameEvent:
	var e := GameEvent.new()
	e.reset(GameEvent.Kind.LIFT)
	e.value = cue
	e.target = i
	return e


func test_a_cars_sounds_are_heard_only_inside_it_and_a_button_anywhere() -> void:
	var q := level.query()
	var m := _match()
	var state: GameState = m[1]
	var me := state.characters[0]
	for i in q.lifts.size():
		var spec := q.lifts[i]
		var k := state.lifts.stop[i]
		_stand(me, spec.car_point(state.lifts.y[i]))
		for cue: int in [Lifts.Cue.OPENING, Lifts.Cue.SHUTTING, Lifts.Cue.DEPART, Lifts.Cue.ARRIVE, Lifts.Cue.BUZZ]:
			assert_true(SimAudio.heard_in_car(_event(cue, i), q, cfg, state.lifts, me), "in car %d: cue %d" % [i, cue])
			assert_false(SimAudio.heard_in_car(_event(cue, 1 - i), q, cfg, state.lifts, me), "not the other car's")
			assert_false(SimAudio.heard_in_car(_event(cue, i), q, cfg, state.lifts, null), "nobody's ears")
			assert_false(SimAudio.heard_in_car(_event(cue, i), null, cfg, state.lifts, me), "no level")
		_stand(me, spec.landing_point(k, cfg))
		for cue: int in [Lifts.Cue.OPENING, Lifts.Cue.SHUTTING, Lifts.Cue.DEPART, Lifts.Cue.ARRIVE, Lifts.Cue.BUZZ]:
			assert_false(SimAudio.heard_in_car(_event(cue, i), q, cfg, state.lifts, me), "on its landing: cue %d" % cue)
		assert_true(SimAudio.heard_in_car(_event(Lifts.Cue.BUTTON, i), q, cfg, state.lifts, me), "its call button")
		# Over the car standing below, on the stop above: not in it.
		var other := 1 - k
		_stand(me, spec.car_point(spec.stops[other]))
		assert_false(SimAudio.heard_in_car(_event(Lifts.Cue.SHUTTING, i), q, cfg, state.lifts, me),
				"in the shaft a storey away from the car")


func test_from_a_landing_no_car_sound_plays_and_inside_the_shut_does() -> void:
	var q := level.query()
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [] as Array[StringName], tuning.body, q, null, null, 0, cfg)
	var m := _match()
	var state: GameState = m[1]
	var me := state.characters[0]
	var spec := q.lifts[1]
	var k := state.lifts.stop[1]
	for inside: bool in [false, true]:
		_stand(me, spec.car_point(state.lifts.y[1]) if inside else spec.landing_point(k, cfg))
		audio._ear = me.eye(tuning.body)
		var playing := _playing(audio)
		state.events.clear()
		var e := state.events.add(GameEvent.Kind.LIFT)
		e.value = Lifts.Cue.SHUTTING
		e.target = 1
		e.value2 = k
		e.position = spec.door_center(k)
		e.reach = cfg.heard
		audio.on_tick(state, 0, me)
		assert_eq(_playing(audio) - playing, 1 if inside else 0, "inside %s" % inside)


func _playing(audio: SimAudio) -> int:
	var n := 0
	for v in audio._field:
		if v.playing:
			n += 1
	return n


func test_the_minimap_and_the_sound_cues_take_only_a_lifts_buttons() -> void:
	var s := GameState.new(5)
	s.match_number = 1
	var plain: Array[ReplicaConfig] = [ReplicaConfig.new()]
	s.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, plain))
	s.characters.append(Character.new(1, 1, Vector3(4.0, 0.0, 0.0), 0.0, plain))
	var you := s.characters[0]
	for cue: int in [Lifts.Cue.OPENING, Lifts.Cue.SHUTTING, Lifts.Cue.DEPART, Lifts.Cue.ARRIVE, Lifts.Cue.BUZZ,
			Lifts.Cue.BUTTON]:
		var map_hear := MinimapHearing.new(MinimapConfig.new())
		var cues := SoundCues.new(AccessibilityConfig.new(), SoundConfig.new())
		var e := s.events.add(GameEvent.Kind.LIFT)
		e.value = cue
		e.actor = 1
		e.target = 0
		e.position = Vector3(4.0, 1.0, 0.0)
		e.reach = cfg.heard
		s.time += DT
		map_hear.on_tick(s, you)
		cues.on_tick(s, you)
		s.events.clear()
		var heard := 1 if cue == Lifts.Cue.BUTTON else 0
		assert_eq(map_hear.live_count(), heard, "minimap, cue %d" % cue)
		assert_eq(cues.live_count(), heard, "sound cues, cue %d" % cue)
