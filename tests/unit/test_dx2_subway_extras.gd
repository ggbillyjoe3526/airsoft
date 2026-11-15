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
