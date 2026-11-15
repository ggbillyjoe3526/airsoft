extends GutTest
## WB1 (Woodland's Concept B layout): each pole's ring is open floor clear of blocks and trees and off the road's
## gravel, the bomb sites are the flags, the areas name the poles' ground, the six lanes are joined point to point from
## both ends, the two moved night lights stand clear, and a seeded match in each flag mode holds no bot up.

const SIDE := 6
## Woodland's Long road (tools/woodland/layout.py ROAD) and the gravel strip's half width (ROAD_HALF, m).
const ROAD: Array[Vector2] = [Vector2(-90, 24), Vector2(-66, 27), Vector2(-48, 33), Vector2(-34, 42),
		Vector2(-26, 45.5), Vector2(-20.5, 52.3), Vector2(-16, 55.6), Vector2(-13, 55.6), Vector2(-10.3, 52),
		Vector2(-8.3, 46), Vector2(-6.3, 42.4), Vector2(-3.5, 42.4), Vector2(-0.8, 45), Vector2(3, 48.3),
		Vector2(14, 48.3), Vector2(22, 43.6), Vector2(32, 40), Vector2(44, 33), Vector2(48, 31)]
const ROAD_HALF := 2.5
const RING_SAMPLES := 16
## How much longer than the straight line a walk between neighbouring lane points may be (a lane point is a step on
## the way to the next, not across a wall).
const DETOUR := 3.0
const DETOUR_PLUS := 12.0

var tuning: SimTuning = SimTuning.load_default()
var style: MapStyle = PlayTuning.load_default().map_style
var map: MapData
var nav: NavGrid
var ring: float = FlagConfig.new().radius


func before_all() -> void:
	map = MapData.load_map("woodland", style, SIDE)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func _road_distance(p: Vector2) -> float:
	var best := INF
	for i in ROAD.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, ROAD[i], ROAD[i + 1])
		best = minf(best, p.distance_to(q))
	return best


## Blocks a standing body at `p` (feet `feet`, head `head`) overlaps: solid pieces, trees and thickets included.
func _blocks_at(p: Vector2, feet: float, head: float, r: float) -> PackedStringArray:
	var hit := PackedStringArray()
	for b in map.blocks:
		if b.kind == &"floor" or b.rise != MapData.Rise.NONE:
			continue
		var h := b.size * 0.5
		if absf(p.x - b.center.x) < h.x + r and absf(p.y - b.center.z) < h.z + r \
				and feet < b.center.y + h.y and head > b.center.y - h.y:
			hit.append("%s %s" % [b.kind, b.center])
	return hit


func _ring_points(f: Vector3) -> Array[Vector2]:
	var out: Array[Vector2] = [Vector2(f.x, f.z)]
	for i in RING_SAMPLES:
		var a := TAU * float(i) / float(RING_SAMPLES)
		out.append(Vector2(f.x + cos(a) * ring, f.z + sin(a) * ring))
	return out


func test_woodland_has_two_poles_and_six_lanes() -> void:
	assert_eq(map.poles.size(), 2, "two poles")
	assert_eq(map.lanes.size(), 6, "six lanes")


## The pole's own spot is open floor and a body stands at most places of the ring round it (flag B's pocket between
## the cordwood stacks closes its west side by design: the ring may lose a quarter of its points, never the centre).
func test_each_pole_stands_on_open_floor_and_most_of_its_ring_is_standable() -> void:
	for n in map.poles.size():
		var f := map.poles[n]
		var open := 0
		var points := _ring_points(f)
		for i in points.size():
			var p := points[i]
			var y := nav.floor_at(Vector3(p.x, f.y + 1.0, p.y))
			var free := nav.is_walkable_at(Vector3(p.x, y + 0.6, p.y)) \
					and _blocks_at(p, y + 0.2, y + tuning.body.stand_eye_height, tuning.body.radius).is_empty()
			if i == 0:
				assert_true(free, "pole %d: its own spot is open floor clear of blocks and trees" % n)
			elif free:
				open += 1
		assert_gte(open, RING_SAMPLES * 3 / 4, "pole %d: %d of %d ring points standable" % [n, open, RING_SAMPLES])


func test_each_pole_ring_keeps_off_the_road_gravel() -> void:
	for n in map.poles.size():
		var f := map.poles[n]
		for p in _ring_points(f):
			assert_gte(_road_distance(p), ROAD_HALF, "pole %d ring point %s is on the road's strip" % [n, p])


func test_bomb_sites_are_the_flags() -> void:
	assert_true(map.has_bomb_sites, "Woodland hosts Plant The Bomb")
	assert_eq(map.bomb_sites.size(), map.poles.size(), "a site per flag")
	for n in map.poles.size():
		assert_almost_eq(map.bomb_sites[n].x, map.poles[n].x, 0.01, "site %d x" % n)
		assert_almost_eq(map.bomb_sites[n].z, map.poles[n].z, 0.01, "site %d z" % n)


func test_the_area_at_each_pole_is_its_site() -> void:
	assert_almost_eq(map.poles[0].x, 42.2, 0.01, "flag A is in Fern hollow")
	assert_almost_eq(map.poles[1].z, 42.0, 0.01, "flag B is at the Log stacks")
	var names: Array[String] = ["A site", "B site"]
	for n in 2:
		assert_eq(MapAreas.area_at(map.areas, map.poles[n]), names[n], "pole %d" % n)
	# the old buildings keep their own names
	var named := PackedStringArray()
	for a in map.areas:
		named.append(a.name)
	assert_true(named.has("Fort"), "the Fort is still named")
	assert_true(named.has("Sawmill"), "the Sawmill is still named")


func test_every_lane_point_is_walkable_and_each_end_reaches_it() -> void:
	var cut := PackedStringArray()
	var route := PackedVector3Array()
	for l in map.lanes.size():
		for p in map.lanes[l]:
			if not nav.is_walkable_at(Vector3(p.x, p.y + 0.6, p.z)):
				cut.append("lane %d %s off the floor" % [l, p])
				continue
			for e in 2:
				route.clear()
				if not nav.find_route(map.ends[e].spawns[0].position, p, route, true):
					cut.append("lane %d end %d to %s" % [l, e, p])
	assert_eq(cut.size(), 0, "lane points: %s" % [cut.slice(0, 5)])


func test_neighbouring_lane_points_are_joined_by_a_short_walk() -> void:
	var bad := PackedStringArray()
	var route := PackedVector3Array()
	for l in map.lanes.size():
		var lane := map.lanes[l]
		for k in lane.size() - 1:
			route.clear()
			if not nav.find_route(lane[k], lane[k + 1], route, true):
				bad.append("lane %d: %d to %d no route" % [l, k, k + 1])
				continue
			var walk := 0.0
			for i in route.size() - 1:
				walk += route[i].distance_to(route[i + 1])
			var straight := lane[k].distance_to(lane[k + 1])
			if walk > straight * DETOUR + DETOUR_PLUS:
				bad.append("lane %d: %d to %d walks %.0f m for %.0f" % [l, k, k + 1, walk, straight])
	assert_eq(bad.size(), 0, "lane legs: %s" % [bad.slice(0, 5)])


func test_the_moved_lights_stand_at_the_poles_clear_of_blocks() -> void:
	for n in 2:
		var f := map.poles[n]
		var near := 0
		for l in map.lights:
			var d := Vector2(l.position.x - f.x, l.position.z - f.z).length()
			if d > 4.0:
				continue
			near += 1
			var y := nav.floor_at(Vector3(l.position.x, l.position.y + 1.0, l.position.z))
			var hit := _blocks_at(Vector2(l.position.x, l.position.z), y + 0.2, y + 1.0, 0.2)
			assert_eq(hit.size(), 0, "light %s at pole %d stands in %s" % [l.position, n, hit])
		assert_gte(near, 1, "pole %d has a light within 4 m" % n)


func test_a_seeded_match_in_each_flag_mode_holds_no_bot_up() -> void:
	for mode: RoundState.Mode in [RoundState.Mode.ATTACK_DEFEND, RoundState.Mode.PLANT_THE_BOMB]:
		var runner := MatchRunner.new(self, "woodland")
		runner.mode = mode
		var t := runner.play(3, 1800.0)
		runner.free_level()
		gut.p("mode %d: %d rounds, %d hits, held up %d, stayed home %d" % [mode, t.rounds.size(), t.hits,
				t.held_up, t.stayed_home])
		assert_true(t.finished, "mode %d: the match is won" % mode)
		assert_gt(t.hits, 0, "mode %d: BBs land" % mode)
		assert_eq(t.held_up, 0, "mode %d: no bot held up" % mode)
