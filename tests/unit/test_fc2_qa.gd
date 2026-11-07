extends GutTest
## QA for FC2: FieldMeasure's measures held to brute force and to properties (the stand points, the sightline search and
## its stretch, the spawn yards, walks, the middle), and the layout checks on faults the worker's tests don't break (a
## slit only crouched eyes see through, a walled-in flag, a middle spread that warns), on Depot's data and a BoxWorld.

var style: MapStyle
var tuning: SimTuning
var nav: NavGrid = null


func before_all() -> void:
	style = PlayTuning.load_default().map_style
	tuning = SimTuning.load_default()
	nav = NavGrid.build(_depot(), tuning.nav, tuning.body)


func after_all() -> void:
	nav = null


func _depot() -> MapData:
	return MapData.load_map("depot", style, 1)


## Depot's ground floor alone: an open yard.
func _open_yard() -> MapData:
	var m := _depot()
	var floors: Array[MapData.Block] = []
	for b in m.blocks:
		if b.kind == &"floor" and b.center.y < 0.0:
			floors.append(b)
	m.blocks = floors
	return m


func _world(m: MapData) -> BoxWorld:
	var world := BoxWorld.new(tuning.body)
	for b in m.blocks:
		if b.rise == MapData.Rise.NONE:
			world.add_box(b.center, b.size, b.surface)
	return world


func _measure(m: MapData, grid: NavGrid = null) -> FieldMeasure:
	return FieldMeasure.new(m, grid if grid != null else NavGrid.build(m, tuning.nav, tuning.body), _world(m), tuning.body)


static func _wall(c: Vector3, s: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = &"wall"
	b.center = c
	b.size = s
	return b


func test_stand_points_take_one_node_per_square_per_floor_and_leave_no_square_empty() -> void:
	var measure := _measure(_depot(), nav)
	for step: float in [0.6, 1.5]:
		var per := maxi(1, roundi(step / nav.cell))
		var points := measure.stand_points(step)
		var seen: Dictionary[Vector3i, int] = {}
		for p in points:
			var c := nav.cell_index(p.x, p.z)
			assert_gte(c, 0, "a stand point is on the grid")
			var key := Vector3i((c % nav.cols) / per, (c / nav.cols) / per, roundi(p.y / FieldMeasure.FLOOR_BAND))
			assert_false(seen.has(key), "one point a square and floor at %s m: %s" % [step, key])
			seen[key] = 1
		var covered := 0
		for k in nav.node_count():
			if nav.walkable[k] != 1:
				continue
			var c := nav.node_cell[k]
			var key := Vector3i((c % nav.cols) / per, (c / nav.cols) / per, roundi(nav.floor_y[k] / FieldMeasure.FLOOR_BAND))
			if not seen.has(key):
				covered += 1
		assert_eq(covered, 0, "every walkable square and floor has a stand point at %s m" % step)


func test_the_sightline_search_finds_the_brute_force_longest_line() -> void:
	var m := _depot()
	var measure := _measure(m, nav)
	var points := measure.stand_points(3.0)
	var best := 0.0
	for i in points.size():
		for j in range(i + 1, points.size()):
			var d := Vector2(points[i].x - points[j].x, points[i].z - points[j].z).length()
			if d > best and measure.sees(points[i], points[j], measure.stand_eye, measure.stand_eye):
				best = d
	var found := measure.longest_sightline(points)
	assert_not_null(found)
	if found != null:
		assert_almost_eq(found.metres, best, 0.002, "the search and every pair agree over %d points" % points.size())
		assert_true(measure.sees(found.from, found.to, measure.stand_eye, measure.stand_eye), "the line it names is clear")


## BP7 row 65: the quick search (seeded on a share of the points, boxes that blocked tried before a ray) and the plain
## one find one line, on listed boxes (as a map's level lists them) in a BoxWorld and on Depot's own Jolt level.
func test_the_quick_search_finds_the_plain_searchs_line() -> void:
	var m := _depot()
	var world := BoxWorld.new(tuning.body)
	for b in m.blocks:
		if b.rise == MapData.Rise.NONE:
			world.add_prop(b.kind, b.center, b.size, b.surface)
	var measure := FieldMeasure.new(m, nav, world, tuning.body)
	var points := measure.stand_points(3.0)
	assert_gt(points.size(), FieldMeasure.SEED_FROM, "enough points to be seeded")
	var quick := measure.longest_sightline(points)
	measure.quick = false
	var plain := measure.longest_sightline(points)
	assert_not_null(quick)
	assert_not_null(plain)
	if quick != null and plain != null:
		assert_eq([quick.metres, quick.from, quick.to], [plain.metres, plain.from, plain.to], "on a BoxWorld")
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, style, tuning.body)
	var jolt := FieldMeasure.new(m, nav, level.query(), tuning.body)
	var on_jolt := jolt.longest_sightline(points)
	jolt.quick = false
	var plain_jolt := jolt.longest_sightline(points)
	assert_not_null(on_jolt)
	if on_jolt != null and plain_jolt != null:
		assert_eq([on_jolt.metres, on_jolt.from, on_jolt.to], [plain_jolt.metres, plain_jolt.from, plain_jolt.to],
				"on Depot's Jolt level")


func test_a_line_through_a_listed_box_core_is_blocked_and_one_past_its_edge_is_not() -> void:
	var m := _open_yard()
	var world := BoxWorld.new(tuning.body)
	world.add_prop(&"wall", Vector3(0.0, 1.5, 0.0), Vector3(1.0, 3.0, 1.0), RayHit.Surface.CONCRETE)
	var measure := FieldMeasure.new(m, nav, world, tuning.body)
	measure._index_boxes()
	var core := measure._cores[0]
	assert_true(core.intersects_segment(Vector3(-5.0, 1.6, 0.0), Vector3(5.0, 1.6, 0.0)) != null, "through it")
	assert_true(core.intersects_segment(Vector3(-5.0, 1.6, 0.47), Vector3(5.0, 1.6, 0.47)) == null,
			"inside the box but past its core: left to the ray")
	var hit := RayHit.new()
	assert_true(world.ray(Vector3(-5.0, 1.6, 0.47), Vector3(5.0, 1.6, 0.47), hit), "which finds it")
	assert_eq(measure._box_hit(Vector3(-5.0, 1.6, 0.0), Vector3(5.0, 1.6, 0.0), Vector3(-0.5, 1.6, 0.0)), 0,
			"a hit on its face is the box")
	assert_eq(measure._box_hit(Vector3(-0.52, 1.6, 0.0), Vector3(5.0, 1.6, 0.0), Vector3(0.5, 1.6, 0.0)), -1,
			"not from an eye at its face: a ray from inside a box misses it")


func test_stretching_a_line_never_shortens_it_and_leaves_it_clear() -> void:
	var measure := _measure(_depot(), nav)
	var coarse := measure.longest_sightline(measure.stand_points(3.0))
	var stretched := measure.stretch(coarse, 3.0, FieldMeasure.STRETCH_ROUNDS)
	assert_gte(stretched.metres, coarse.metres)
	assert_true(measure.sees(stretched.from, stretched.to, measure.stand_eye, measure.stand_eye), "still a clear line")
	assert_almost_eq(stretched.metres, Vector2(stretched.from.x - stretched.to.x, stretched.from.z - stretched.to.z).length(), 0.001)
	assert_eq(measure.stretch(coarse, 3.0, 0), coarse, "no rounds, no change")


func test_the_spawn_yards_stay_within_the_radius_of_a_spawn_on_its_floor() -> void:
	var m := _depot()
	var measure := _measure(m, nav)
	for end in m.ends:
		var yard := measure.spawn_yard(end.spawns)
		assert_gt(yard.size(), 20, "a yard has places to stand")
		for p in yard:
			var near := false
			for s in end.spawns:
				near = near or (Vector2(p.x - s.position.x, p.z - s.position.z).length() <= FieldStandard.SPAWN_YARD_RADIUS \
						and absf(p.y - s.position.y) < FieldMeasure.FLOOR_BAND)
			assert_true(near, "%s is in the yard of a spawn" % FieldChecks.at(p))
	assert_eq(measure.spawn_yard([] as Array[SpawnPoint]).size(), 0, "no spawns, no yard")


func test_a_slit_only_crouched_eyes_see_through_fails_spawn_sight_as_crouched() -> void:
	var m := _open_yard()
	# A wall across the field with a slit at crouched eye height (1.13 m) but under a standing one (1.66 m).
	m.blocks.append(_wall(Vector3(0, 0.5, 0), Vector3(1, 1.0, 44)))
	m.blocks.append(_wall(Vector3(0, 2.15, 0), Vector3(1, 1.7, 44)))
	var r := FieldChecks.spawn_sight(_measure(m))
	assert_eq(r.status, FieldChecks.Status.FAIL, r.text)
	assert_string_contains(r.text, "crouched")
	m.blocks.append(_wall(Vector3(0, 1.15, 0), Vector3(1, 0.4, 44)))
	var shut := FieldChecks.spawn_sight(_measure(m))
	assert_eq(shut.status, FieldChecks.Status.PASS, "the slit shut: " + shut.text)


func test_a_flag_walled_in_fails_routes_and_flag() -> void:
	var m := _depot()
	var f := m.pole
	m.blocks.append(_wall(f + Vector3(1.2, 1.5, 0), Vector3(0.3, 3, 2.7)))
	m.blocks.append(_wall(f + Vector3(-1.2, 1.5, 0), Vector3(0.3, 3, 2.7)))
	m.blocks.append(_wall(f + Vector3(0, 1.5, 1.2), Vector3(2.1, 3, 0.3)))
	m.blocks.append(_wall(f + Vector3(0, 1.5, -1.2), Vector3(2.1, 3, 0.3)))
	var measure := _measure(m)
	var r := FieldChecks.routes(measure)
	assert_eq(r.status, FieldChecks.Status.FAIL, r.text)
	assert_string_contains(r.text, "can't reach the flag")
	var fr := FieldChecks.flag(measure)
	assert_eq(fr.status, FieldChecks.Status.FAIL, fr.text)
	assert_string_contains(fr.text, "can't walk to the flag")


func test_a_walk_is_no_shorter_than_the_straight_line_and_is_inf_off_the_grid() -> void:
	var m := _depot()
	var measure := _measure(m, nav)
	var a := m.ends[0].spawns[0].position
	var b := m.ends[1].spawns[0].position
	var w := measure.walk(a, b)
	assert_true(is_finite(w))
	assert_gte(w, a.distance_to(b) - 0.5, "a walk is not shorter than the line")
	assert_lt(w, a.distance_to(b) * 2.0, "and on Depot's yard not twice it")
	assert_almost_eq(measure.walk(a, b), measure.walk(a, b), 0.0001, "the shared route buffer leaves a repeat alone")
	assert_eq(measure.walk(a, Vector3(500, 0, 500)), INF, "a goal far off the grid is no walk")
	assert_eq(measure.walk(Vector3(500, 0, 500), b), INF, "nor a start")
	assert_lt(measure.walk(a, a), 0.5, "no distance to yourself")


func test_the_middle_is_walkable_ground_at_the_bounds_centre() -> void:
	var measure := _measure(_depot(), nav)
	var mid := measure.middle()
	assert_true(nav.is_walkable_at(mid), "the middle can be stood on")
	assert_almost_eq(mid.y, 0.0, 0.1, "on the ground floor")
	assert_lt(absf(mid.x - (measure._x0 + measure._x1) * 0.5), 2.0)
	assert_lt(absf(mid.z - (measure._z0 + measure._z1) * 0.5), 2.0)


func test_the_middle_is_the_street_not_a_balcony_over_it() -> void:
	var m := _depot()
	var deck := MapData.Block.new()
	deck.kind = &"floor"
	deck.center = Vector3(0, 2.85, 0)
	deck.size = Vector3(12, 0.3, 12)
	m.blocks.append(deck)
	var measure := _measure(m)
	assert_true(measure.nav.floor_y.size() > 0)
	var over := measure.nav.node_at(Vector3(0, 10, 0))
	assert_gt(measure.nav.floor_y[over], 2.0, "the fixture has a floor over the centre")
	assert_almost_eq(measure.middle().y, 0.0, 0.1, "the middle is still on the ground floor")


func _with_walks(key: String, e0: float, e1: float) -> FieldMeasure:
	var measure := _measure(_depot(), nav)
	var rows: Array[PackedFloat64Array] = [PackedFloat64Array([e0]), PackedFloat64Array([e1])]
	measure._measured[key] = rows
	return measure


func test_the_middle_spread_passes_to_15_percent_warns_to_25_and_fails_past_it() -> void:
	var expect := {20.0: FieldChecks.Status.PASS, 23.0: FieldChecks.Status.PASS, 23.5: FieldChecks.Status.WARN,
			25.0: FieldChecks.Status.WARN, 25.1: FieldChecks.Status.FAIL, 40.0: FieldChecks.Status.FAIL}
	for far: float in expect:
		var r := FieldChecks.middle(_with_walks("middle_walks", 20.0, far))
		assert_eq(r.status, expect[far], "%s against 20: %s" % [far, r.text])
		var swapped := FieldChecks.middle(_with_walks("middle_walks", far, 20.0))
		assert_eq(swapped.status, expect[far], "the nearer end may be either: %s" % swapped.text)
	assert_eq(FieldChecks.middle(_with_walks("middle_walks", 20.0, INF)).status, FieldChecks.Status.FAIL)


func test_the_flag_head_start_passes_at_1_6_and_fails_under_it() -> void:
	assert_eq(FieldChecks.flag(_with_walks("flag_walks", 32.0, 20.0)).status, FieldChecks.Status.PASS)
	assert_eq(FieldChecks.flag(_with_walks("flag_walks", 31.9, 20.0)).status, FieldChecks.Status.FAIL)
	assert_eq(FieldChecks.flag(_with_walks("flag_walks", INF, 20.0)).status, FieldChecks.Status.FAIL)
	assert_eq(FieldChecks.flag(_with_walks("flag_walks", 32.0, INF)).status, FieldChecks.Status.FAIL)


func test_the_check_lists_partition_the_checks_and_known_failing_filters_by_them() -> void:
	var all := PackedStringArray(FieldStandard.RULES)
	all.append_array(PackedStringArray(FieldStandard.LAYOUT))
	all.sort()
	var checks := PackedStringArray(FieldStandard.CHECKS)
	checks.sort()
	assert_eq(all, checks, "RULES and LAYOUT together are CHECKS, each once")
	assert_eq(FieldStandard.known_failing("depot", FieldStandard.RULES), PackedStringArray())
	assert_eq(FieldStandard.known_failing("depot", FieldStandard.LAYOUT), PackedStringArray())
	assert_eq(FieldStandard.known_failing("nowhere"), PackedStringArray())
	assert_eq(FieldStandard.sightline_limit("nowhere"), FieldStandard.LONGEST_SIGHTLINE)
	assert_eq(FieldStandard.sightline_reason("nowhere"), "")
	for id: String in ["depot", "woodland"]:
		assert_gt(FieldStandard.sightline_limit(id), FieldStandard.LONGEST_SIGHTLINE, "%s's hall or woods" % id)
		assert_false(FieldStandard.sightline_reason(id).is_empty(), "%s says why" % id)
