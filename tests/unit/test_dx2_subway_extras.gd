extends GutTest
## DX2: Depot's wall extras in Subway's station (tools/subway/fixtures.py). The station carries the ones a station has
## the like of, never a warehouse's signs; its signs at eye height, call points and fire points at Depot's heights;
## the pipework high on the tall rooms' walls, over the vents and under the conduit, clear of every other fixture.

## Depot's wall extras Subway carries, and the warehouse signs it never does.
const SHARED: Array[StringName] = [&"fire_point", &"call_point", &"pipe_run", &"pipe_run_b", &"pipe_run_2",
		&"pipe_run_1", &"depot_sign_fire_action", &"depot_sign_defib", &"depot_sign_ppe", &"depot_sign_fire_exit"]
const WAREHOUSE: Array[StringName] = [&"depot_sign_assembly", &"depot_sign_no_riding", &"depot_sign_pallet_storage"]
const PIPES: Array[StringName] = [&"pipe_run", &"pipe_run_b", &"pipe_run_2", &"pipe_run_1"]
## Heights over the floor (m) of the models' spots (fixtures.py: FIRE_ACTION_Y, CALL_Y, FIRE_POINT_Y), and the
## platform level's track bed for the cross passage's signs (EXIT_SIGN_Y).
const HEIGHTS: Dictionary[StringName, float] = {
	&"depot_sign_fire_action": 1.6, &"depot_sign_defib": 1.6, &"depot_sign_ppe": 1.6, &"call_point": 1.35,
	&"fire_point": 0.3, &"depot_sign_fire_exit": 1.75,
}
## The wall vents' top over the floor (StationDetailConfig.vent_bottom + vent.y) the pipework's straight lengths stay
## over, and how far under a ceiling its top stays (the conduit's drop and size).
const VENT_TOP := 2.92
const UNDER_CEILING := 0.24
const APART := 0.02

var play: PlayTuning = PlayTuning.load_default()
var _map: MapData = null


func _subway() -> MapData:
	if _map == null:
		_map = MapData.load_map("subway", play.map_style, SimTuning.new().rounds.team_size)
	return _map


func _box(f: StationDressing.Fixture) -> AABB:
	var mesh := PropDressConfig.load_mesh(play.station_fixtures.path_of(f.model))
	return Transform3D(Basis(Vector3.UP, f.yaw).scaled(Vector3.ONE * f.scale), f.position) * mesh.get_aabb()


func _floor(f: StationDressing.Fixture) -> float:
	return _subway().floor_under(f.position.x, f.position.z, f.position.y)


func test_subway_carries_the_station_s_extras_and_no_warehouse_sign() -> void:
	var counts: Dictionary[StringName, int] = {}
	for f in _subway().station.fixtures:
		counts[f.model] = counts.get(f.model, 0) + 1
	for model in SHARED:
		assert_gt(counts.get(model, 0), 0, "%s in the station" % model)
	for model in WAREHOUSE:
		assert_eq(counts.get(model, 0), 0, "no %s underground" % model)
	assert_eq(counts.get(&"call_point", 0), counts.get(&"depot_sign_fire_action", 0),
			"a call point beside each fire action notice")
	assert_eq(_subway().fixtures.size(), 0, "they're the station's fixtures, not a hall's wall extras")


func test_each_sign_call_point_and_fire_point_stands_at_its_height() -> void:
	var bad: Array[String] = []
	for f in _subway().station.fixtures:
		if not HEIGHTS.has(f.model):
			continue
		var over := f.position.y - _floor(f)
		if absf(over - HEIGHTS[f.model]) > 0.01:
			bad.append("%s at %s: %.2f m over the floor" % [f.model, f.position, over])
	assert_eq(bad, [] as Array[String], "eye-height signs, call points at 1.35 m, fire points' boards at 0.3 m")


func test_the_pipework_runs_high_on_the_walls_clear_of_the_vents_the_conduit_and_every_other_fixture() -> void:
	var m := _subway()
	var others: Array[AABB] = []
	var pipes: Array[StationDressing.Fixture] = []
	for f in m.station.fixtures:
		if PIPES.has(f.model):
			pipes.append(f)
		else:
			others.append(_box(f))
	assert_gte(pipes.size(), 16, "the ticket hall's long walls and the stair top's")
	var bad: Array[String] = []
	for f in pipes:
		var box := _box(f)
		var floor_y := _floor(f)
		var zone := m.station.zone_at(box.get_center())
		var tag := "%s at %s" % [f.model, f.position]
		if f.model != &"pipe_run_b" and box.position.y - floor_y < VENT_TOP:
			bad.append("%s: its foot %.2f m up, over a vent's top" % [tag, box.position.y - floor_y])
		if zone == null:
			bad.append("%s: in no room" % tag)
		elif box.end.y > zone.box.end.y - UNDER_CEILING:
			bad.append("%s: its top %.2f m under the ceiling" % [tag, zone.box.end.y - box.end.y])
		var grown := box.grow(-APART)
		for o in others:
			if o.intersects(grown):
				bad.append("%s: meets a fixture at %s" % [tag, o.get_center()])
				break
	assert_eq(bad, [] as Array[String], "over the vents, under the conduit, clear of the signs, cameras and clocks")


func test_the_pipework_lengths_on_a_wall_meet_end_to_end_and_every_third_fitted_is_the_fitted_one() -> void:
	# along the ticket hall's north wall from its street-end corner: lengths end to end, every third the fitted one
	var row: Array[StationDressing.Fixture] = []
	for f in _subway().station.fixtures:
		if PIPES.has(f.model) and f.position.z < -9.9 and f.position.x < -17.0:
			row.append(f)
	row.sort_custom(func(a: StationDressing.Fixture, b: StationDressing.Fixture) -> bool:
		return a.position.x < b.position.x)
	assert_gte(row.size(), 8, "the north wall's run")
	for i in range(1, row.size()):
		assert_almost_eq(row[i].position.x - row[i - 1].position.x, 4.0, 0.001, "end to end")
	var fitted := row.filter(func(f: StationDressing.Fixture) -> bool: return f.model == &"pipe_run_b")
	assert_eq(fitted.size(), 2, "every third length fitted, the one over the ticket office laid plain")


func test_no_extra_overlaps_another_fixture_and_none_is_laid_twice() -> void:
	var fixtures := _subway().station.fixtures
	var boxes: Array[AABB] = []
	for f in fixtures:
		boxes.append(_box(f).grow(-0.002))  # signs are 5 mm thick
	var bad: Array[String] = []
	for i in fixtures.size():
		if not SHARED.has(fixtures[i].model):
			continue
		for j in fixtures.size():
			if i != j and (j < i or not SHARED.has(fixtures[j].model)) and boxes[i].intersects(boxes[j]):
				bad.append("%s at %s meets %s at %s" % [fixtures[i].model, fixtures[i].position,
						fixtures[j].model, fixtures[j].position])
	assert_eq(bad, [] as Array[String], "the station's extras keep clear of every other fixture")


func test_every_pipe_run_ends_at_a_wall_both_ways() -> void:
	# along each wall the lengths meet end to end, and past each run's first and last length (2 cm on, at the pipes'
	# middle) stands a wall: the street end's, the concourse's return, the stair top's corner, the passage's bulkhead
	var m := _subway()
	var runs: Dictionary[String, Array] = {}
	for f in m.station.fixtures:
		if PIPES.has(f.model):
			var key := "wall z %.2f" % f.position.z   # every run lies along x, on a north or south wall
			if not runs.has(key):
				runs[key] = []
			runs[key].append(_box(f))
	assert_eq(runs.size(), 4, "the ticket hall's two long walls and the stair top's two")
	var open_ends: Array[String] = []
	for key: String in runs:
		var boxes: Array = runs[key]
		var lo: AABB = boxes[0]
		var hi: AABB = boxes[0]
		for b: AABB in boxes:
			if b.position.x < lo.position.x:
				lo = b
			if b.end.x > hi.end.x:
				hi = b
		var span := hi.end.x - lo.position.x
		var laid := 0.0
		for b: AABB in boxes:
			laid += b.size.x
		assert_almost_eq(laid, span, 0.01, "%s: end to end, no gap" % key)
		var y := lo.get_center().y
		for p: Vector3 in [Vector3(lo.position.x - 0.02, y, _inner(lo)), Vector3(hi.end.x + 0.02, y, _inner(hi))]:
			if not _solid(m, p):
				open_ends.append("%s at %s" % [key, p])
	assert_eq(open_ends, [] as Array[String], "every run ends at a wall")


## A z 0.15 m in from the wall side of `box` (a length of pipework on a wall running along x, the walls at z of either
## sign): inside a wall's return or a bulkhead where the run ends.
func _inner(box: AABB) -> float:
	var wall_z := box.position.z if absf(box.position.z) > absf(box.end.z) else box.end.z
	return wall_z - signf(wall_z) * 0.15


func _solid(m: MapData, p: Vector3) -> bool:
	for b in m.blocks:
		if AABB(b.center - b.size * 0.5, b.size).has_point(p):
			return true
	return false


func test_the_end_length_s_pipes_are_capped_at_both_ends() -> void:
	# pipe_run_1 finishes a run either way round (north walls end at its far end, south walls at its origin), and past
	# the concourse's 0.5 m return its front stands open to view: each of its seven pipes and cables needs a cap at
	# each end (at least 40 triangles flat in each end's plane: 4 cables of 4, 2 claddings of 8, the main's 8)
	var mesh := PropDressConfig.load_mesh(play.station_fixtures.path_of(&"pipe_run_1"))
	var flat := [0, 0]
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in index.size() / 3:
			for e in 2:
				var x := float(e)
				if absf(pos[index[t * 3]].x - x) < 0.001 and absf(pos[index[t * 3 + 1]].x - x) < 0.001 \
						and absf(pos[index[t * 3 + 2]].x - x) < 0.001:
					flat[e] += 1
	assert_gte(flat[0], 40, "capped at its origin")
	assert_gte(flat[1], 40, "capped at its far end")
