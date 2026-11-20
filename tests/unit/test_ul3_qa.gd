extends GutTest
## UL3 QA: edge cases of the lift's shut lead (a press during it, a lead past the door's time, a listener on the
## doorway's plane) and of the underground field's light (a refresh under way, a preset changed and back).

const DT := 1.0 / 60.0
var tuning: SimTuning = SimTuning.new()
var cfg: LiftConfig = tuning.lifts
var map: MapData = null
var level: MapLevel = null
var table: GraphicsTable = GraphicsTable.shared()


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
	var c := state.characters[0]
	c.position = map.ends[0].spawns[0].position + Vector3(0.0, tuning.body.rest_gap, 0.0)
	c.prev_position = c.position
	return [sim, state]


func _tick(sim: Simulation, state: GameState, n: int) -> void:
	var cmds: Array[PlayerCommand] = [PlayerCommand.new()]
	for t in n:
		cmds[0].reset(state.characters[0].yaw, state.characters[0].pitch)
		sim.step(state, cmds, DT)


func _call_away(state: GameState, i: int) -> void:
	state.lifts.calls[i] = 1 << (1 - state.lifts.stop[i])
	state.lifts.left[i] = 0.0


func test_a_press_during_the_lead_opens_the_doors_again_without_them_ever_moving() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var i := 1
	_call_away(state, i)
	_tick(sim, state, 4)
	assert_eq(state.lifts.phase[i], LiftState.Phase.SHUTTING)
	var spec := level.query().lifts[i]
	var lifts := sim.lifts
	var stop: int = state.lifts.stop[i]
	var presser := state.characters[0]
	presser.position = spec.landing_point(stop, cfg) + Vector3(0.0, tuning.body.rest_gap, 0.0)
	lifts._press_button(i, stop, presser, state)
	assert_eq(state.lifts.phase[i], LiftState.Phase.OPENING)
	assert_eq(state.lifts.left[i], 0.0, "the leaves never moved: nothing to open")
	for t in 5:
		_tick(sim, state, 1)
		assert_eq(state.lifts.doors[i], 1.0, "never dips below open")
	assert_eq(state.lifts.phase[i], LiftState.Phase.OPEN)


func test_a_press_part_way_through_the_shut_opens_from_where_the_leaves_stand() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var i := 1
	_call_away(state, i)
	_tick(sim, state, roundi((cfg.shut_lead + cfg.shut_time() * 0.5) / DT))
	var doors: float = state.lifts.doors[i]
	assert_between(doors, 0.2, 0.8, "the leaves are half shut")
	var stop: int = state.lifts.stop[i]
	var lifts := sim.lifts
	lifts._press_button(i, stop, state.characters[0], state)
	_tick(sim, state, 1)
	assert_between(state.lifts.doors[i], doors, 1.0, "they open from where they stood, no jump")
	assert_almost_eq(state.lifts.doors[i], doors, 0.05)


func test_a_lead_past_the_door_time_shuts_the_leaves_at_once_and_the_car_still_departs_on_time() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var i := 1
	var was := cfg.shut_lead
	cfg.shut_lead = cfg.door_time * 3.0
	_call_away(state, i)
	_tick(sim, state, 4)
	assert_eq(state.lifts.phase[i], LiftState.Phase.SHUTTING)
	assert_false(is_nan(state.lifts.doors[i]), "no division by a zero span")
	assert_eq(state.lifts.doors[i], 0.0)
	_tick(sim, state, roundi(cfg.door_time / DT))
	cfg.shut_lead = was
	assert_eq(state.lifts.phase[i], LiftState.Phase.MOVING)


func test_a_listener_on_the_doorway_plane_hears_it_from_a_real_point() -> void:
	var e := GameEvent.new()
	e.reset(GameEvent.Kind.LIFT)
	e.position = Vector3(1.0, 2.0, 3.0)
	e.direction = Vector3(0.0, 0.0, 0.15)
	var at := SimAudio.doorway_face(e, Vector3(7.0, 1.6, 3.0))
	assert_false(is_nan(at.x) or is_nan(at.y) or is_nan(at.z))
	assert_almost_eq(at.distance_to(e.position), 0.0, 0.2, "the middle or a face, never far off")


func test_a_scene_refresh_under_way_when_the_field_goes_underground_ends_with_no_bounce_light() -> void:
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, GraphicsApply.Server.new())
	lighting.refresh_scene_light()
	assert_true(lighting.refreshing_scene_light())
	lighting.set_underground(true)
	await wait_physics_frames(6)
	assert_false(lighting.refreshing_scene_light())
	assert_false(lighting.environment.sdfgi_enabled, "the refresh ends on the field's own answer")


func test_ultra_to_high_and_back_underground_keeps_the_bounce_off() -> void:
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	lighting.add_probes(MapData.load_map("subway", MapStyle.new(), 6))
	lighting.set_underground(true)
	var ids: Array[StringName] = [&"ultra", &"high", &"ultra", &"low", &"ultra"]
	for name_id: StringName in ids:
		GraphicsApply.apply_field(table.preset(name_id), lighting, null, GraphicsApply.Server.new())
		assert_false(lighting.environment.sdfgi_enabled, "%s underground: no SDFGI" % name_id)
		for node in lighting.find_children("*", "ReflectionProbe", true, false):
			var probe := node as ReflectionProbe
			if probe.interior:
				assert_eq(probe.ambient_mode, ReflectionProbe.AMBIENT_DISABLED, "%s" % name_id)
