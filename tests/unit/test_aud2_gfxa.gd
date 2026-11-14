extends GutTest
## The second audit's graphics fixes on Subway and the lamps (AUD2, gfxa): a station's lights are put on by one
## helper (GraphicsApply.apply_station) that the match and the eye pictures both call, so the pictures light the
## running tunnels' lamps and the lift cars as a match does.

var tuning: SimTuning = SimTuning.new()
var play: PlayTuning = PlayTuning.new()
var map: MapData = null


func before_all() -> void:
	map = MapData.load_map("subway", MapStyle.new(), 6)


func _cars(lifts: LiftView) -> Array[Node]:
	return lifts.find_children("Car*", "Node3D", false, false)


func test_apply_station_lights_the_tunnel_lamps_and_the_cars_on_high_and_not_on_low() -> void:
	var lifts := LiftView.build(map, MapStyle.new(), tuning.lifts, play.lifts)
	var fixtures := StationFixtures.build(map, play.station_fixtures)
	add_child_autofree(lifts)
	add_child_autofree(fixtures)
	assert_gt(fixtures.lamps().size(), 0, "Subway's tunnel lamps have lights")
	assert_gt(_cars(lifts).size(), 0, "Subway has lift cars")
	var table := GraphicsTable.shared()
	GraphicsApply.apply_station(table.preset(&"high"), lifts, fixtures)
	for lamp in fixtures.lamps():
		assert_true(lamp.visible, "High: a tunnel lamp lights its arch")
	for car in _cars(lifts):
		assert_true((car.get_node("Lamp") as Node3D).visible, "High: the car's lamp lit")
		assert_true((car.get_node("Probe") as Node3D).visible, "High: the car's probe shown (Reflections: probes)")
	GraphicsApply.apply_station(table.preset(&"low"), lifts, fixtures)
	for lamp in fixtures.lamps():
		assert_false(lamp.visible, "Low: no lamp lights")
	for car in _cars(lifts):
		assert_false((car.get_node("Lamp") as Node3D).visible, "Low: the car's lamp unlit")
		assert_false((car.get_node("Probe") as Node3D).visible, "Low: no reflections")


func test_apply_station_takes_a_map_without_a_station() -> void:
	GraphicsApply.apply_station(GraphicsTable.shared().preset(&"high"), null, null)
	assert_true(true, "nothing to light, nothing done")


func test_the_eye_pictures_light_the_station_as_a_match_does() -> void:
	# The pictures built the tunnel lamps and the lifts but never switched them, so the running tunnels drew without
	# their lamps' light on High and Ultra (AUD2 row 20).
	var tool := FileAccess.get_file_as_string("res://tools/eye_pictures.gd")
	assert_string_contains(tool, "GraphicsApply.apply_station(values, lifts, station_fixtures)")
	var session := FileAccess.get_file_as_string("res://game/play/play_session.gd")
	assert_string_contains(session, "GraphicsApply.apply_station(values, _lifts, _station_fixtures)")


func test_the_eye_pictures_light_an_underground_field_and_dress_a_station_as_a_match_does() -> void:
	# Without set_underground the pictures lit Subway with the sky's ambient light, so its plant room's props, black in
	# a match on High, drew lit (AUD2 row 19); and they stood a model in every box, unpainted.
	var tool := FileAccess.get_file_as_string("res://tools/eye_pictures.gd")
	assert_string_contains(tool, "lighting.set_underground(map.roof_underground)")
	assert_string_contains(tool, "PropDress.build(map, cfg, play.site_look.prop_paint)")
	assert_string_contains(tool, "play.site_look.props.named_only() if station")


func test_no_roof_lamp_hangs_straight_over_a_tall_model_in_a_ceilinged_room() -> void:
	# Subway's plant room hung a lamp straight over each fan housing: every side of the housing turned away from its
	# lamp and lay past the other's reach, so the housings (and a booth stood there) drew near black in a match on
	# High while the walls and floor were lit (AUD2 row 19). tools/subway/build_map.py now hangs a lamp 1 m clear.
	var plant := AABB(Vector3(4.0, 8.8, -4.0), Vector3(14.0, 3.7, 8.0))
	var lamps := 0
	for i in map.roof_lamps.size():
		var spot := Vector3(map.roof_lamps[i].x, map.roof_lamp_heights[i] - 0.05, map.roof_lamps[i].y)
		if not plant.has_point(spot):
			continue
		lamps += 1
		for b in map.blocks:
			if b.dress == &"" or b.size.y < 1.5:
				continue
			var lo := b.center - b.size * 0.5
			var hi := b.center + b.size * 0.5
			var over := spot.x > lo.x - 1.0 + 1e-3 and spot.x < hi.x + 1.0 - 1e-3 and spot.z >= lo.z and spot.z <= hi.z
			assert_false(over and spot.y > hi.y, "the lamp at %s hangs clear of %s" % [spot, b.dress])
	assert_eq(lamps, 2, "the plant room keeps its two lamps")


func _lift_state(lifts: LiftView, y: float, phase: LiftState.Phase) -> LiftState:
	var state := LiftState.new()
	var n := map.lifts.size()
	state.y.resize(n)
	state.prev_y.resize(n)
	state.stop.resize(n)
	state.doors.resize(n)
	state.calls.resize(n)
	state.phase.resize(n)
	for i in n:
		state.y[i] = map.lifts[i].stops[0]
		state.prev_y[i] = state.y[i]
		state.phase[i] = LiftState.Phase.OPEN
	state.y[0] = y
	state.prev_y[0] = y
	state.phase[0] = phase
	lifts.refresh(state, 1.0)
	return state


func test_a_riding_car_leaves_its_probe_where_it_stopped_and_takes_it_back_at_the_next_stop() -> void:
	# The engine captures a reflection probe again whenever it moves (AUDIT 8, Performance 1).
	var lifts := LiftView.build(map, MapStyle.new(), tuning.lifts, play.lifts)
	add_child_autofree(lifts)
	var spec := map.lifts[0]
	var car := _cars(lifts)[0] as Node3D
	var probe := car.get_node("Probe") as ReflectionProbe
	_lift_state(lifts, spec.stops[0], LiftState.Phase.OPEN)
	var parked := probe.global_position
	_lift_state(lifts, spec.stops[0] + 1.0, LiftState.Phase.MOVING)
	_lift_state(lifts, spec.stops[0] + 2.0, LiftState.Phase.MOVING)
	assert_almost_eq(probe.global_position.distance_to(parked), 0.0, 1e-4, "riding: the probe stays put")
	_lift_state(lifts, spec.stops[1], LiftState.Phase.OPENING)
	var inside := car.global_position + Vector3(0.0, tuning.lifts.car_height * 0.5, 0.0)
	assert_false(probe.top_level, "stopped: the probe is the car's again")
	assert_almost_eq(probe.global_position.distance_to(inside), 0.0, 1e-4, "stopped: the probe fills the car")


func test_the_running_tunnels_arch_alone_is_marked_for_the_fill() -> void:
	var look := play.station_look
	var mesh := StationSurface.mesh(map, play.map_style, look, play.site_look.props.named_only())
	var arrays := mesh.surface_get_arrays(0)
	var at: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var marked := 0
	var stray := 0
	for v in at.size():
		if colours[v].a < 0.25:
			marked += 1
			# the running tunnels' vaults (lining) lie east of the platforms, x 50 to 82
			if at[v].x < 49.9:
				stray += 1
	assert_gt(marked, 0, "the running tunnels' arch is marked")
	assert_eq(stray, 0, "nothing else (the platforms' vaults keep their light)")


func test_the_arch_fill_is_on_only_while_no_lamp_lights_the_tunnels() -> void:
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, play.map_style, tuning.body, play.baked_light, LightingConfig.for_map(play.lighting, null, map,
			LightingConfig.DAY), false, play.site_look, tuning.lifts, play.station_look)
	var table := GraphicsTable.shared()
	for preset: StringName in [&"low", &"medium"]:
		GraphicsApply.apply_field(table.preset(preset), null, null, null, level)
		assert_almost_eq(float(level.station_material().get_shader_parameter(&"arch_fill")),
				play.station_look.arch_fill, 1e-6, "%s: the arch filled" % preset)
	for preset: StringName in [&"high", &"ultra"]:
		GraphicsApply.apply_field(table.preset(preset), null, null, null, level)
		assert_almost_eq(float(level.station_material().get_shader_parameter(&"arch_fill")), 0.0, 1e-6,
				"%s: the tunnel lamps light it" % preset)


func test_the_platform_vaults_take_the_vault_fill_on_every_preset() -> void:
	var look := play.station_look
	var mesh := StationSurface.mesh(map, play.map_style, look, play.site_look.props.named_only())
	var arrays := mesh.surface_get_arrays(0)
	var at: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var marked := 0
	for v in at.size():
		if absf(colours[v].a - StationSurface.VAULT_MARK) < 0.1:
			marked += 1
			assert_lt(at[v].x, 50.1, "only the platforms' vaults (x -52 to 50)")
	assert_gt(marked, 0, "the platform vaults are marked")
	var mat := StationSurface.material(look)
	assert_almost_eq(float(mat.get_shader_parameter(&"vault_fill")), look.vault_fill, 1e-6, "set from the look")


func test_your_replica_and_the_bbs_snap_with_the_retro_filter() -> void:
	# Dev › Retro filter (RF1) wobbled only the field's own shaders: your replica and the BBs stayed steady.
	var call := "VERTEX = retro_vertex(MODEL_MATRIX, VERTEX, retro_snaps(IN_SHADOW_PASS, PROJECTION_MATRIX));"
	for path: String in ["res://game/play/replica_surface.gdshaderinc", "res://game/play/bb_ball.gdshader"]:
		var code := FileAccess.get_file_as_string(path)
		assert_string_contains(code, "#include \"res://game/play/look/retro_vertex.gdshaderinc\"", path)
		assert_string_contains(code, call, path)
	assert_not_null(load("res://game/play/replica_surface.gdshader") as Shader, "the replica's shader loads")
	assert_not_null(load("res://game/play/bb_ball.gdshader") as Shader, "the BB's shader loads")
