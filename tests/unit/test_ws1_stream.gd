extends GutTest
## WS1 (owner, 2026-11-10): a shallow stream in Woodland's dry bed. Wading slows players and bots and every stride
## splashes, walking and crouched too, heard further than a dry step; a BB landing in it splashes at the surface; the
## bots' routes take a dry crossing where one is near; the Ford stays the mid lane's crossing, ankle deep (it splashes,
## it doesn't slow). Water (game/sim/water.gd), MapData's `water`, Footsteps, Movement, BBStep, NavGridBuilder,
## WaterView.

const DT := 1.0 / 60.0
## Woodland's North bridge (world x, z of its deck's middle) and the Ford.
const NORTH_BRIDGE := Vector2(-1.0, -41.5)
const FORD := Vector2(9.5, 0.5)

var tuning: SimTuning = SimTuning.load_default()
var style: MapStyle = PlayTuning.load_default().map_style


## A stream along -z..+z at x = 0, 4 m across, its surface at y = 0.3 over a floor at 0.
func _stream_world() -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(80.0, 0.5, 80.0), RayHit.Surface.EARTH)
	w.add_stream(PackedVector3Array([Vector3(0.0, 0.3, -40.0), Vector3(0.0, 0.3, 40.0)]), 4.0)
	return w


func test_water_has_a_level_over_its_line_out_to_its_half_width() -> void:
	var w := Water.new()
	assert_true(w.is_empty())
	assert_eq(w.depth_at(Vector3.ZERO), 0.0, "no stream, no water")
	assert_true(w.add(PackedVector3Array([Vector3(0.0, 1.0, 0.0), Vector3(10.0, 0.0, 0.0)]), 2.0))
	assert_false(w.add(PackedVector3Array([Vector3.ZERO]), 2.0), "one point is no line")
	assert_false(w.add(PackedVector3Array([Vector3.ZERO, Vector3.ONE]), 0.0), "nor is no width")
	assert_eq(w.size(), 1)
	assert_almost_eq(w.level_at(5.0, 1.5), 0.5, 1e-5, "between its points' levels")
	assert_true(is_nan(w.level_at(5.0, 2.5)), "past its half width")
	assert_true(is_nan(w.level_at(13.0, 0.0)), "past its end")
	assert_almost_eq(w.depth_at(Vector3(5.0, 0.2, 0.0)), 0.3, 1e-5)
	assert_eq(w.depth_at(Vector3(5.0, 0.6, 0.0)), 0.0, "a point over the surface is dry")
	assert_eq(w.depth_at(Vector3(5.0, 0.5 - Water.MIN_DEPTH * 0.5, 0.0)), 0.0, "a damp rim is dry")


func test_a_map_file_reads_its_streams_and_leaves_out_a_bad_one() -> void:
	var text := JSON.stringify({"name": "Brook", "blocks": [{"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0},
		"size": {"x": 40, "y": 0.5, "z": 40}}], "spawns": [[{"x": -10, "z": 0}], [{"x": 10, "z": 0}]],
		"deadZones": [[{"x": -15, "z": 0}], [{"x": 15, "z": 0}]],
		"water": [{"points": [{"x": 0, "y": 0.3, "z": -10}, {"x": 0, "y": 0.3, "z": 10}], "width": 3},
			{"points": [{"x": 0, "z": 0}], "width": 3}]})
	var m := MapData.parse(text, style, 1)
	assert_true(m.ok(), str(m.problems))
	assert_eq(m.water.size(), 1)
	assert_almost_eq(m.water.half_width_of(0), 1.5, 1e-5)
	assert_eq(m.warnings.size(), 1, str(m.warnings))


func test_wading_is_slower_and_every_stride_splashes_further() -> void:
	var w := _stream_world()
	var m := _match(w)
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var move := tuning.movement
	var dry: Array[GameEvent] = []
	var pace := _run_north(sim, s, Vector3(20.0, 0.0, 10.0), 2.0, false, dry)
	assert_almost_eq(pace, move.run_speed, 0.1, "a run on the bank")
	assert_false(s.characters[0].in_water)
	var wet: Array[GameEvent] = []
	var waded := _run_north(sim, s, Vector3(0.0, 0.0, 10.0), 2.0, false, wet)
	assert_true(s.characters[0].in_water, "in the stream")
	assert_almost_eq(waded, move.run_speed * move.wade_speed_scale, 0.1, "slowed by the water")
	assert_eq(dry[-1].value2, RayHit.Surface.EARTH)
	assert_eq(wet[-1].value2, RayHit.Surface.WATER, "a step in the stream is a splash")
	assert_eq(wet[-1].carry, tuning.noise.carry(RayHit.Surface.WATER))
	assert_gt(wet[-1].carry, dry[-1].carry, "heard further than a step on the bank")


func test_walking_through_water_still_splashes_where_on_the_bank_it_is_silent() -> void:
	var w := _stream_world()
	var m := _match(w)
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var bank: Array[GameEvent] = []
	_run_north(sim, s, Vector3(20.0, 0.0, 10.0), 3.0, true, bank)
	assert_eq(bank.size(), 0, "walking on the bank is silent")
	var wet: Array[GameEvent] = []
	_run_north(sim, s, Vector3(0.0, 0.0, 10.0), 3.0, true, wet)
	assert_gt(wet.size(), 0, "walking through water splashes")
	assert_eq(wet[-1].value2, RayHit.Surface.WATER)
	assert_eq(wet[-1].carry, tuning.noise.wade_quiet_carry)
	var bots := BotConfig.load_default()
	assert_gt(bots.footstep_hearing_run * wet[-1].carry, bots.footstep_hearing_rattle, "a bot hears it a way off")


func test_bots_hear_a_splash_out_to_its_carry() -> void:
	var bots := BotConfig.load_default()
	var reach := bots.footstep_hearing_run * tuning.noise.carry(RayHit.Surface.WATER)
	assert_almost_eq(reach, 16.5, 0.01, "a run's splash reaches 16.5 m, a dry run's 11 m")


func test_ankle_deep_water_splashes_without_slowing() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(80.0, 0.5, 80.0), RayHit.Surface.EARTH)
	w.add_stream(PackedVector3Array([Vector3(0.0, 0.08, -40.0), Vector3(0.0, 0.08, 40.0)]), 4.0)
	var m := _match(w)
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var steps: Array[GameEvent] = []
	var pace := _run_north(sim, s, Vector3(0.0, 0.0, 10.0), 2.0, false, steps)
	assert_false(s.characters[0].in_water, "not deep enough to wade")
	assert_almost_eq(pace, tuning.movement.run_speed, 0.1, "full pace over the ford")
	assert_eq(steps[-1].value2, RayHit.Surface.WATER, "but every step splashes")


func test_a_bb_landing_in_the_stream_splashes_at_its_surface_and_stays_down() -> void:
	var w := _stream_world()
	var pool := BBPool.new(4)
	var bb := pool.spawn(0, Vector3(0.5, 1.0, 0.0), Vector3.DOWN, 40.0, 0.0, 0.25e-3, 0.0)
	var events := SimEvents.new()
	var ends: Array[MapEnd] = []
	var people: Array[Character] = []
	for i in 10:
		BBStep.step(pool, people, w, tuning, -10.0, false, ends, events, DT)
		if events.count_of(GameEvent.Kind.BB_IMPACT) > 0:
			break
	assert_eq(events.count_of(GameEvent.Kind.BB_IMPACT), 1)
	var e := events.items[0]
	for i in events.count:
		if events.items[i].kind == GameEvent.Kind.BB_IMPACT:
			e = events.items[i]
	assert_eq(e.value2, RayHit.Surface.WATER)
	assert_almost_eq(e.position.y, 0.3, 0.01, "at the water's surface")
	assert_false(bb.active, "no bounce off the bed")


func test_the_nav_and_movement_agree_on_how_deep_wading_starts() -> void:
	assert_eq(tuning.nav.wade_from, tuning.movement.wade_depth)
	assert_gt(tuning.nav.wade_cost, tuning.nav.splash_cost)
	assert_gt(tuning.nav.splash_cost, 1.0)


func test_woodland_has_its_stream_down_the_bed_with_both_crossings_dry_and_the_ford_ankle_deep() -> void:
	var map := MapData.load_map("woodland", style, 6)
	assert_true(map.ok(), str(map.problems))
	assert_eq(map.water.size(), 1, "one stream")
	assert_true(map.warnings.is_empty(), str(map.warnings))
	var t := map.terrain
	# The water lies flat its whole length (the owner, 2026-11-10: it ran uphill under the North bridge).
	var points := map.water.points_of(0)
	for p: Vector3 in points:
		assert_almost_eq(p.y, points[0].y, 1e-3, "level at %s" % p)
	# Down the bed between the crossings, off the Ford, it is deep enough to wade.
	for at: Vector2 in [Vector2(-1.0, -37.0), Vector2(-5.0, -25.0), Vector2(12.6, 12.0), Vector2(8.6, 30.0)]:
		var depth := map.water.depth_at(Vector3(at.x, t.height_at(at.x, at.y), at.y))
		assert_between(depth, tuning.movement.wade_depth, 0.5, "%s is wading depth (%.2f m)" % [at, depth])
	var ford := map.water.depth_at(Vector3(FORD.x, t.height_at(FORD.x, FORD.y), FORD.y))
	assert_between(ford, Water.MIN_DEPTH, tuning.movement.wade_depth, "the Ford is ankle deep (%.2f m)" % ford)
	# The North bridge's deck and the road over the culvert stand over the water.
	var deck := map.floor_top(NORTH_BRIDGE.x, NORTH_BRIDGE.y)
	assert_eq(map.water.depth_at(Vector3(NORTH_BRIDGE.x, deck, NORTH_BRIDGE.y)), 0.0, "the bridge is dry")
	var road := map.floor_top(8.0, 48.3)
	assert_eq(map.water.depth_at(Vector3(8.0, road, 48.3)), 0.0, "the road over the culvert is dry")
	# Neither camp, flag nor the overtime flag stands in it.
	for e in map.ends:
		for sp in e.spawns:
			assert_eq(map.water.depth_at(sp.position), 0.0)
	assert_eq(map.water.depth_at(map.overtime_flag), 0.0)


func test_bots_cross_by_the_north_bridge_rather_than_wade_beside_it() -> void:
	var map := MapData.load_map("woodland", style, 6)
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	# From the west bank by the slide south of the bridge to the east bank north of it: with wading free, a bot walks
	# down the slide and up the bed under the bridge.
	var a := Vector3(-10.0, 0.0, -32.0)
	var b := Vector3(9.0, 0.0, -44.0)
	a.y = nav.floor_at(Vector3(a.x, 50.0, a.z))
	b.y = nav.floor_at(Vector3(b.x, 50.0, b.z))
	var route := PackedVector3Array()
	assert_true(nav.find_route(a, b, route))
	var wet := _wading_metres(map, nav, a, route)
	gut.p("route over %d waypoints, %.1f m wading" % [route.size(), wet])
	assert_lt(wet, 0.5, "over the bridge, not through the water")
	# With wading free, the same route goes up the bed through the water.
	var free := tuning.nav.duplicate() as NavConfig
	free.wade_cost = 1.0
	free.splash_cost = 1.0
	var plain := NavGrid.build(map, free, tuning.body)
	assert_true(plain.find_route(a, b, route))
	assert_gt(_wading_metres(map, plain, a, route), 2.0, "the bed is the short way")


func test_the_water_view_draws_one_ribbon_and_holds_still_for_reduced_motion() -> void:
	var map := MapData.load_map("woodland", style, 6)
	var view := WaterView.build(map, PlayTuning.load_default().woods)
	assert_not_null(view)
	assert_eq(view.mesh.get_surface_count(), 1)
	assert_eq(view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq(view.materials().size(), 1)
	var still := MotionScale.new()
	still.dust = 0.0
	view.set_motion(still)
	assert_eq(view.materials()[0].get_shader_parameter(&"motion"), 0.0)
	view.free()
	var dry := MapData.load_map("depot", style, 6)
	assert_null(WaterView.build(dry, PlayTuning.load_default().woods), "no stream, no view")


## Metres of `route` from `from` wading (MovementConfig.wade_depth or deeper), sampled every 0.25 m along its legs on
## the floor `nav` puts under them.
func _wading_metres(map: MapData, nav: NavGrid, from: Vector3, route: PackedVector3Array) -> float:
	var wet := 0.0
	var at := from
	for p in route:
		var n := maxi(1, ceili(Vector2(p.x - at.x, p.z - at.z).length() / 0.25))
		for k in n:
			var q := at.lerp(p, (k + 0.5) / n)
			if map.water.depth_at(Vector3(q.x, nav.floor_at(q), q.z)) >= tuning.movement.wade_depth:
				wet += Vector2(p.x - at.x, p.z - at.z).length() / n
		at = p
	return wet


func _match(w: BoxWorld) -> Array:
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-15.0 if e == 0 else 15.0, 0.0, 0.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-18.0 if e == 0 else 18.0, 0.0, 0.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(3, tuning)
	s.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	s.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	sim.start_match(s)
	return [sim, s]


## Runs (or walks, `walk`) character 0 north (-z) from `from` for `seconds`, its footsteps into `steps`; its pace over
## the last half second (m/s).
func _run_north(sim: Simulation, s: GameState, from: Vector3, seconds: float, walk: bool,
		steps: Array[GameEvent]) -> float:
	var c := s.characters[0]
	c.position = from
	c.prev_position = from
	c.yaw = 0.0
	var cmds: Array[PlayerCommand] = [PlayerCommand.new(), PlayerCommand.new()]
	cmds[0].forward = 1.0
	cmds[0].walk = walk
	var ticks := roundi(seconds * 60.0)
	var half_at := Vector3.ZERO
	for i in ticks:
		if i == ticks - 30:
			half_at = c.position
		sim.step(s, cmds, DT)
		for j in s.events.count:
			var e := s.events.items[j]
			if e.kind == GameEvent.Kind.FOOTSTEP and e.actor == 0:
				var copy := GameEvent.new()
				copy.value2 = e.value2
				copy.carry = e.carry
				steps.append(copy)
	return Vector2(c.position.x - half_at.x, c.position.z - half_at.z).length() / 0.5
