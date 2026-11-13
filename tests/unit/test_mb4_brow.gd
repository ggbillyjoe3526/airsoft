extends GutTest
## MB4: the Brow hazel is back. The middle hazel of the front row on Woodland's Ridge brow stands 0.7 m off the north
## lane, across the gap in the row behind it: it is the west's screen from the Tower's side, where the two squads
## first meet. MB2 moved it 2.3 m north after two opposing bots ended inside it and walked into each other; that left
## the gap open and cost the west end its share of Elimination (MB3). BU1 has bots in one bush shoot it out, so the
## hazel stands in its place again.

const SIDE := 8
## The hazel's foot (m; tools/woodland/layout.py BUSHES, "Brow hazel") and how near a bush must stand to be it.
const HAZEL := Vector2(-16.3, -40.5)
const NEAR := 0.2
## Where an east player comes off the North bridge towards the brow, north of the lane's line round the hazel (m).
const EAST_X: Array[float] = [-12.0, -10.0, -8.0]
const EAST_Z: Array[float] = [-41.6, -40.8, -40.0]
## The gap in the back row of hazels, where the north lane comes through (m): x of the row, z across the gap.
const GAP_X := -20.4
const GAP_Z: Array[float] = [-41.0, -40.5, -40.0]
const CHEST := 1.1

var tuning: SimTuning = SimTuning.load_default()
var style: MapStyle = PlayTuning.load_default().map_style
var map: MapData
var nav: NavGrid


func before_all() -> void:
	map = MapData.load_map("woodland", style, SIDE)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func _at(x: float, z: float, up: float) -> Vector3:
	return Vector3(x, nav.floor_at(Vector3(x, 50.0, z)) + up, z)


func test_the_hazel_stands_across_the_gap() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/woodland.json"))
	var bushes: Array = (raw as Dictionary).get("foliage", [])
	assert_gt(bushes.size(), 100, "the field's bushes are read")
	var found := 0
	for f: Dictionary in bushes:
		if Vector2(f["x"], f["z"]).distance_to(HAZEL) <= NEAR:
			found += 1
	assert_eq(found, 1, "one bush at (%.1f, %.1f)" % [HAZEL.x, HAZEL.y])


## Every line from the bridge's side to the gap runs through more leaves than a BB crosses or a bot sees through
## (BallisticsConfig.leaf_stop_depth), or into something solid.
func test_nobody_east_of_the_brow_sees_through_the_gap_in_the_back_row() -> void:
	var level := MapLevel.new()
	add_child(level)
	level.build(map, style, tuning.body)
	var q := level.query()
	var hit := RayHit.new()
	var eye := tuning.body.stand_eye_height
	var most := tuning.ballistics.leaf_stop_depth
	var seen := PackedStringArray()
	var lines := 0
	for x: float in EAST_X:
		for z: float in EAST_Z:
			var from := _at(x, z, eye)
			for gz: float in GAP_Z:
				var to := _at(GAP_X, gz, CHEST)
				lines += 1
				if not q.ray(from, to, hit) and q.foliage.depth(from, to, most) <= most:
					seen.append("(%.1f, %.1f) sees (%.1f, %.1f)" % [x, z, GAP_X, gz])
	level.free()
	assert_eq(lines, 27)
	assert_eq(seen, PackedStringArray(), "the hazel stands across every line")


func test_the_north_lane_still_passes_the_brow_by_the_hazel() -> void:
	var lane: PackedVector3Array = map.lanes[0]
	var route := PackedVector3Array()
	assert_true(nav.find_route(lane[0], lane[lane.size() - 1], route, true), "the north lane is walked end to end")
	var nearest := INF
	for p in route:
		nearest = minf(nearest, Vector2(p.x, p.z).distance_to(HAZEL))
	assert_lt(nearest, 6.0, "past the hazel (%.1f m)" % nearest)
