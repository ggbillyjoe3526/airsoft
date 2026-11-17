extends GutTest
## QA hunt on SW2: a press from inside a car (panel_dwell) against a body in the doorway, a full car and a press from
## the landing; a bot waiting on a teammate who never boards; the lift's motor voice riding with its car; the bend's
## malformed settings and what the shut end hides (game/sim/lifts.gd, game/ai/bot_lifts.gd, game/play/sim_audio.gd,
## game/map/station_dressing.gd).

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var cfg: LiftConfig = tuning.lifts
var config: BotConfig = BotConfig.load_default()
var map: MapData = null
var level: MapLevel = null
var nav: NavGrid = null


func before_all() -> void:
	map = MapData.load_map("subway", MapStyle.new(), 6)
	level = MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body, null, null, false, null, cfg)
	nav = NavGrid.build(map, tuning.nav, tuning.body)
	NavLifts.link(nav, level.query(), cfg, tuning.movement.run_speed, config.lift_wait)


func after_all() -> void:
	level.free()


func _match(n: int) -> Array:
	var q := level.query()
	var sim := Simulation.new(tuning, q, level.mover(tuning.body), map.ends, map.kill_y)
	var state := GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	for i in n:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	state.round_state.hold = 0.0
	return [sim, state]


func _stand(c: Character, at: Vector3) -> void:
	c.position = at + Vector3(0.0, tuning.body.rest_gap, 0.0)
	c.prev_position = c.position
	c.velocity = Vector3.ZERO
	c.grounded = true


func _step(sim: Simulation, state: GameState, n: int, press: Array = []) -> Array[int]:
	var cmds: Array[PlayerCommand] = []
	for c in state.characters:
		cmds.append(PlayerCommand.new())
	var cues: Array[int] = []
	for t in n:
		for i in cmds.size():
			var c := state.characters[i]
			cmds[i].reset(c.yaw, c.pitch)
			if t == 0 and i < press.size() and press[i] != Lifts.NONE:
				cmds[i].use_door = true
				cmds[i].lift_to_use = press[i].x
				cmds[i].lift_stop = press[i].y
		sim.step(state, cmds, DT)
		for k in state.events.count:
			var e := state.events.items[k]
			if e.kind == GameEvent.Kind.LIFT:
				cues.append(e.value)
	return cues


func test_a_press_from_inside_shuts_the_doors_at_once_but_one_from_the_landing_keeps_the_dwell() -> void:
	var m := _match(2)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var spec := level.query().lifts[1]
	_stand(state.characters[0], spec.car_point(spec.stops[0]))
	_stand(state.characters[1], spec.landing_point(0, cfg))
	state.lifts.left[1] = cfg.dwell
	var cues := _step(sim, state, 1, [Vector2i(1, 1), Lifts.NONE])
	assert_true(Lifts.Cue.BUTTON in cues)
	cues.append_array(_step(sim, state, 3))
	assert_true(Lifts.Cue.SHUTTING in cues, "from inside: the doors start to shut within a few ticks")
	# The same call from the landing waits the dwell.
	var m2 := _match(2)
	var sim2: Simulation = m2[0]
	var state2: GameState = m2[1]
	_stand(state2.characters[0], spec.landing_point(1, cfg))
	_stand(state2.characters[1], spec.landing_point(1, cfg) + Vector3(0.5, 0.0, 0.0))
	state2.lifts.left[1] = cfg.dwell
	var cues2 := _step(sim2, state2, 3, [Vector2i(1, 1), Lifts.NONE])
	assert_false(Lifts.Cue.SHUTTING in cues2, "from the landing: still in its dwell")
	assert_true(state2.lifts.called(1, 1))


func test_a_press_from_inside_never_shuts_the_doors_on_a_body_in_the_doorway() -> void:
	var m := _match(2)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var spec := level.query().lifts[1]
	_stand(state.characters[0], spec.car_point(spec.stops[0]))
	var door := spec.door_center(0)
	_stand(state.characters[1], Vector3(door.x, spec.stops[0], door.z))
	var cues := _step(sim, state, 1, [Vector2i(1, 1), Lifts.NONE])
	cues.append_array(_step(sim, state, 120))
	assert_false(Lifts.Cue.SHUTTING in cues, "a body stands in the doorway")
	assert_eq(state.lifts.phase[1], LiftState.Phase.OPEN)
	_stand(state.characters[1], spec.landing_point(0, cfg) + (Vector3(spec.out.x, 0.0, spec.out.y)) * 1.5)
	cues = _step(sim, state, 5)
	assert_true(Lifts.Cue.SHUTTING in cues, "it shuts once the doorway is clear")


func test_a_full_car_pressed_from_inside_buzzes_and_stays_open() -> void:
	var m := _match(cfg.capacity + 1)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var spec := level.query().lifts[1]
	for c in state.characters:
		_stand(c, spec.car_point(spec.stops[0]))
	var cues := _step(sim, state, 1, [Vector2i(1, 1)])
	cues.append_array(_step(sim, state, 90))
	assert_true(Lifts.Cue.BUZZ in cues)
	assert_false(Lifts.Cue.SHUTTING in cues)
	assert_eq(state.lifts.phase[1], LiftState.Phase.OPEN)


func test_a_bot_aboard_presses_within_the_dwell_when_a_teammate_in_reach_never_boards() -> void:
	var m := _match(3)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var q := level.query()
	var bots := BotController.new(state, -1, map, nav, q, tuning, config)
	bots.world.lifts = state.lifts
	var spec := q.lifts[0]
	var link := -1
	for l in nav.lift_to.size():
		if nav.lift_of[l] == 0 and nav.lift_stop_from[l] == 1 and nav.lift_stop_to[l] == 0:
			link = l
	assert_gte(link, 0)
	# Bot 0 aboard; bot 2 (same team) idle on the landing beside the door; bot 1 (other team) far off.
	_stand(state.characters[0], spec.car_point(spec.stops[1]))
	_stand(state.characters[2], spec.landing_point(1, cfg))
	var b: Bot = null
	for x: Bot in bots.world.bots:
		if x.character.id == 0:
			b = x
	var pressed := -1.0
	for t in roundi((cfg.dwell + 2.0) / DT):
		bots.world.time = state.time
		BotLifts.ride(b, bots.world, link, DT)
		if b.lift_press != Lifts.NONE:
			pressed = state.time
			break
		sim.step(state, _idle(3), DT)
	assert_gt(pressed, -0.5, "it presses, it does not wait for a teammate who never comes")
	assert_lte(pressed, cfg.dwell + 0.2)


func _idle(n: int) -> Array[PlayerCommand]:
	var cmds: Array[PlayerCommand] = []
	for i in n:
		cmds.append(PlayerCommand.new())
	return cmds


func test_a_lone_bot_aboard_presses_on_its_first_tick() -> void:
	var m := _match(2)
	var state: GameState = m[1]
	var q := level.query()
	var bots := BotController.new(state, -1, map, nav, q, tuning, config)
	bots.world.lifts = state.lifts
	var spec := q.lifts[0]
	var link := -1
	for l in nav.lift_to.size():
		if nav.lift_of[l] == 0 and nav.lift_stop_from[l] == 1 and nav.lift_stop_to[l] == 0:
			link = l
	_stand(state.characters[0], spec.car_point(spec.stops[1]))
	var b: Bot = null
	for x: Bot in bots.world.bots:
		if x.character.id == 0:
			b = x
	BotLifts.ride(b, bots.world, link, DT)
	assert_eq(b.lift_press, Vector2i(0, 0), "no teammate outside: it presses at once")


func test_a_lift_motor_voice_rides_with_its_car_and_is_let_go_when_the_lifts_are_gone() -> void:
	var sound := SoundConfig.new()
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(sound, [] as Array[StringName], BodyConfig.new(), null, null, null)
	var state := GameState.new(1)
	state.characters.append(Character.new(0, 0, Vector3.ZERO))
	state.lifts.y.resize(1)
	state.lifts.y[0] = 3.0
	var e := state.events.add(GameEvent.Kind.LIFT)
	e.value = Lifts.Cue.DEPART
	e.target = 0
	e.position = Vector3(1.0, 0.0, 1.0)
	e.reach = 40.0
	audio.on_tick(state, 0, state.characters[0])
	state.events.clear()
	state.lifts.y[0] = 7.0
	audio.on_tick(state, 0, state.characters[0])
	var moved := 0
	for v in audio._field:
		if v.playing and absf(v.global_position.y - (7.0 + sound.lift_motor_rise)) < 1e-3:
			moved += 1
	assert_eq(moved, 1, "one motor voice follows the car")
	# Lifts gone (a map without any): no index error, voice slot let go.
	state.lifts.y.resize(0)
	audio.on_tick(state, 0, state.characters[0])
	assert_eq(audio._motor_voice[0], -1)


func test_a_lift_motor_still_playing_stops_as_the_round_ends() -> void:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [] as Array[StringName], BodyConfig.new(), null, null, null)
	var state := GameState.new(1)
	state.characters.append(Character.new(0, 0, Vector3.ZERO))
	state.lifts.y.resize(1)
	state.lifts.y[0] = 3.0
	var e := state.events.add(GameEvent.Kind.LIFT)
	e.value = Lifts.Cue.DEPART
	e.target = 0
	e.position = Vector3(1.0, 0.0, 1.0)
	e.reach = 40.0
	audio.on_tick(state, 0, state.characters[0])
	var v := audio._motor_voice[0]
	assert_gte(v, 0, "the motor plays")
	state.events.clear()
	state.events.add(GameEvent.Kind.ROUND_OVER)
	audio.on_tick(state, 0, state.characters[0])
	assert_eq(audio._motor_voice[0], -1, "let go as the round ends")
	assert_false(audio._field[v].playing, "and cut short: the next round puts the car back at its start stop")


func test_a_bend_with_a_bad_radius_angle_or_turn_leaves_its_vault_out_with_one_warning() -> void:
	var base := {"x0": 0, "x1": 9, "z0": 0, "z1": 7, "y": 4, "rise": 2, "thick": 0.3}
	var good := {"radius": 40, "angle": 60, "turn": 1, "floor": 0, "track": 1.5}
	var cases: Array = [[{}, true], [{"radius": 0}, false], [{"radius": -3}, false], [{"angle": 0}, false],
			[{"angle": 270}, false], [{"turn": 0}, false], [{"turn": 0.5}, false], [{"turn": -1}, true],
			[{"floor": "x"}, false]]
	for case: Array in cases:
		var bend: Dictionary = good.merged(case[0] as Dictionary, true)
		var warnings: Array[String] = []
		var d := StationDressing.read({"station": {"vaults": [base.merged({"bend": bend})]}}, warnings)
		var kept := d != null and d.vaults.size() == 1
		assert_eq(kept, case[1], "bend with %s" % [case[0]])
		if not kept:
			assert_eq(warnings.size(), 1, "one warning: %s" % [case[0]])
	var warnings2: Array[String] = []
	var d2 := StationDressing.read({"station": {"vaults": [base.merged({"bend": 5})]}}, warnings2)
	assert_true(d2 == null or d2.vaults.is_empty(), "a bend that is not a table leaves the vault out")


func test_the_shut_end_hides_only_end_walls_not_floors_or_cover() -> void:
	for v in map.station.vaults:
		if v.bend == null:
			continue
		var shut := v.shut_end()
		for b in map.blocks:
			var box := AABB(b.center - b.size * 0.5, b.size)
			if shut.encloses(box) and not v.lid().encloses(box):
				assert_eq(b.kind, &"wall", "only a wall is hidden by the bend's shut end: %s at %s" % [b.kind, b.center])
				assert_gte(b.center.x, v.area.end.x - 0.01, "it stands at the end, not along the tunnel")


func test_a_plain_vault_hides_nothing_through_the_shut_end() -> void:
	var d := StationDressing.read({"station": {"vaults": [
			{"x0": 0, "x1": 9, "z0": 0, "z1": 7, "y": 4, "rise": 2, "thick": 0.3}]}}, [] as Array[String])
	assert_false(d.in_vault(AABB(Vector3(8.8, 0.0, 3.0), Vector3(0.3, 4.0, 1.0))), "no bend: the end wall is drawn")


func test_underground_shows_no_sky_behind_the_station() -> void:
	# SW2: a hairline where two of the station's faces meet showed the sky's blue (the owner's 6.png); underground the
	# background is near black, and the sky comes back above ground.
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	lighting.set_underground(true)
	assert_eq(lighting.environment.background_mode, Environment.BG_COLOR)
	assert_lt(lighting.environment.background_color.get_luminance(), 0.05, "near black")
	lighting.set_underground(false)
	assert_eq(lighting.environment.background_mode, Environment.BG_SKY, "the sky back above ground")
