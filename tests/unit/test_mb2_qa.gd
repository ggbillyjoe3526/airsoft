extends GutTest
## MB2: Woodland's Long road is clear (the owner, 2026-11-12: "I don't want woodpiles over the road ... The road
## should be clear"). Nothing stands on its strip between the camps, it is walked end to end, and only the six camp
## gate screens stand taller than a woodpile's 1.8 m.

const SIDE := 8
## The Long road's centreline between the camps' gates (a copy of tools/woodland/layout.py's ROAD without its two end
## legs inside the camps: when the road moves, this and test_mb1_layouts' ROAD_WEST move with it), the gravel strip's
## half width that everything keeps out of (m; layout.py ROAD_HALF), and how far a block may stand over the road's
## surface before it counts (the culvert's deck and walls are the road).
const ROAD: Array[Vector2] = [Vector2(-66, 27), Vector2(-48, 33), Vector2(-34, 42), Vector2(-26, 45.5),
		Vector2(-20.5, 52.3), Vector2(-16, 55.6), Vector2(-13, 55.6), Vector2(-10.3, 52), Vector2(-8.3, 46),
		Vector2(-6.3, 42.4), Vector2(-3.5, 42.4), Vector2(-0.8, 45), Vector2(3, 48.3), Vector2(14, 48.3), Vector2(22, 43.6),
		Vector2(32, 40), Vector2(44, 33)]
const CLEAR_HALF := 2.5
const OVER_ROAD := 0.3
const STEP := 0.5
## The gate screens stand 2.8 m; every other cordwood stack 1.8 m.
const GATE_SCREENS := 6
const CAMP_X := 70.0

var tuning: SimTuning = SimTuning.load_default()
var style: MapStyle = PlayTuning.load_default().map_style
var map: MapData
var nav: NavGrid


func before_all() -> void:
	map = MapData.load_map("woodland", style, SIDE)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func _stack_height(b: MapData.Block) -> float:
	var top := b.center.y + b.size.y * 0.5
	return top - PropLayout.ground_at(map, b.center.x, b.center.z, top)


func test_only_the_six_camp_gate_screens_stand_taller_than_a_woodpile() -> void:
	var tall := PackedStringArray()
	var count := 0
	for b in map.blocks:
		if b.dress != &"cordwood":
			continue
		if _stack_height(b) < 1.2:
			continue  # a log pile, knee high
		if _stack_height(b) > 2.0:
			count += 1
			if absf(b.center.x) < CAMP_X:
				tall.append(str(b.center))
		else:
			assert_almost_eq(_stack_height(b), 1.8, 0.05, "cordwood at %s" % b.center)
	assert_eq(tall.size(), 0, "a 2.8 m stack outside the camps: %s" % [tall])
	assert_eq(count, GATE_SCREENS, "the gate screens stand 2.8 m")


func _road_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in ROAD.size() - 1:
		var steps := int(ceilf(ROAD[i].distance_to(ROAD[i + 1]) / STEP))
		for k in steps:
			var p := ROAD[i].lerp(ROAD[i + 1], float(k) / float(steps))
			out.append(Vector3(p.x, nav.floor_at(Vector3(p.x, 50.0, p.y)), p.y))
	return out


func test_nothing_stands_on_the_long_road() -> void:
	var on_road := PackedStringArray()
	var points := _road_points()
	for b in map.blocks:
		var box := Rect2(b.center.x - b.size.x * 0.5, b.center.z - b.size.z * 0.5, b.size.x, b.size.z)
		var top := b.center.y + b.size.y * 0.5
		for p in points:
			var near := Vector2(clampf(p.x, box.position.x, box.end.x), clampf(p.z, box.position.y, box.end.y))
			if near.distance_to(Vector2(p.x, p.z)) < CLEAR_HALF and top > p.y + OVER_ROAD:
				on_road.append("%s %s at %s" % [b.kind, b.dress, b.center])
				break
	assert_eq(on_road.size(), 0, "blocks standing on the Long road's strip: %s" % [on_road])


func test_the_long_road_is_walked_end_to_end_on_its_strip() -> void:
	var shut := PackedStringArray()
	for p in _road_points():
		if is_nan(p.y) or not nav.is_walkable_at(p + Vector3(0.0, 0.6, 0.0)):
			shut.append("(%.1f, %.1f)" % [p.x, p.z])
	assert_eq(shut.size(), 0, "the road's centreline is not walkable at %s" % [shut])
	var points := _road_points()
	var route := PackedVector3Array()
	assert_true(nav.find_route(points[0], points[points.size() - 1], route, true), "a route along the road")
	var length := 0.0
	for i in route.size() - 1:
		length += route[i].distance_to(route[i + 1])
	var straight := 0.0
	for i in ROAD.size() - 1:
		straight += ROAD[i].distance_to(ROAD[i + 1])
	assert_lt(length, straight * 1.1, "the way from end to end is the road itself, not a way round")


func _dist_to_road(x: float, z: float) -> float:
	var best := INF
	var p := Vector2(x, z)
	for i in ROAD.size() - 1:
		var a := ROAD[i]
		var ab := ROAD[i + 1] - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


func test_no_bush_stands_on_the_long_road() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/woodland.json"))
	var bushes: Array = (raw as Dictionary).get("foliage", [])
	assert_gt(bushes.size(), 50, "Woodland has bushes")
	var on_road := PackedStringArray()
	for item: Variant in bushes:
		var d := item as Dictionary
		var x := float(d["x"])
		var z := float(d["z"])
		if _dist_to_road(x, z) < CLEAR_HALF + float(d.get("radius", 0.0)):
			on_road.append("(%.1f, %.1f)" % [x, z])
	assert_eq(on_road.size(), 0, "bushes reaching the road's strip: %s" % [on_road])


func test_the_tyre_tracks_run_along_the_new_road() -> void:
	var tracks := 0
	for m in map.marks:
		if m.kind == WearMark.TYRES:
			tracks += 1
			assert_lt(_dist_to_road(m.at.x, m.at.y), CLEAR_HALF, "tyre tracks start on the road: %s" % m.at)
	assert_gt(tracks, 0, "Woodland has tyre tracks")


func test_every_point_along_the_long_road_is_named() -> void:
	var unnamed := PackedStringArray()
	for p in _road_points():
		if MapAreas.area_at(map.areas, p).is_empty():
			unnamed.append("(%.1f, %.1f)" % [p.x, p.z])
	assert_eq(unnamed.size(), 0, "road points with no area name: %s" % [unnamed])


## One seeded match in each mode on Woodland: it finishes and no bot is held up (the road's S bends are walked).
func test_a_seeded_match_in_each_mode_on_woodland_holds_no_bot_up() -> void:
	for mode: RoundState.Mode in [RoundState.Mode.ELIMINATION, RoundState.Mode.ATTACK_DEFEND,
			RoundState.Mode.PLANT_THE_BOMB]:
		var runner := MatchRunner.new(self, "woodland")
		runner.mode = mode
		var t := runner.play(5, 1800.0)
		runner.free_level()
		gut.p("mode %d: %d rounds, %d hits, held up %d" % [mode, t.rounds.size(), t.hits, t.held_up])
		assert_true(t.finished, "mode %d: the match is won" % mode)
		assert_gt(t.hits, 0, "mode %d: BBs land" % mode)
		assert_eq(t.held_up, 0, "mode %d: no bot held up" % mode)
