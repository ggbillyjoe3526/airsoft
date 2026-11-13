extends GutTest
## MB1: the three fields' lane and flag layouts as data. Every lane point and flag stands on walkable floor and is
## reached from both ends; each lane has a point either side of the field's middle, about equally deep for the two ends
## (the planner's _points_to_middle); the defender posts are on the site; Subway's flag B is on the north platform;
## from Woodland's Long road west of the Culvert nobody sees a chest at flag B's pole or at its defenders' posts.

const SIDE := 8
const MAPS: Array[String] = ["depot", "woodland", "subway"]
## The most the two ends' first points past the middle may differ in depth (m). Depot's middle lane is 0.8 m east of
## even on purpose (3.7 m and 5.3 m deep), Woodland's middle lane reads 1.2 m and 4.3 m.
const DEPTH_SLACK := 3.5
## The farthest a lane's last two points (the defender posts) may stand from the nearest flag (m).
const POST_REACH := 30.0
## Woodland's Long road from the west camp's gate to the Culvert (its centreline, tools/woodland/layout.py ROAD; the
## strip is walked 2 m either side of it), flag B's pole, the ring a body stands in to raise or hold it, its two
## defender posts, and the chest below the eye (m).
const ROAD_WEST: Array[Vector2] = [Vector2(-66, 27), Vector2(-48, 33), Vector2(-34, 42), Vector2(-26, 45.5),
		Vector2(-20.5, 52.3), Vector2(-16, 55.6), Vector2(-13, 55.6), Vector2(-10.3, 52), Vector2(-8.3, 46),
		Vector2(-6.3, 42.4), Vector2(-3.5, 42.4), Vector2(-0.8, 45), Vector2(3, 48.3), Vector2(8, 48.3)]
const ROAD_SIDE := 2.0
const POLE_B := Vector2(49.0, 38.5)
const POLE_RING := 1.5
const POSTS_B: Array[Vector2] = [Vector2(44.6, 29.8), Vector2(49.0, 37.0)]
const CHEST_BELOW_EYE := 0.3

var tuning: SimTuning = SimTuning.load_default()
var style: MapStyle = PlayTuning.load_default().map_style
var maps: Dictionary[String, MapData] = {}
var navs: Dictionary[String, NavGrid] = {}


func before_all() -> void:
	for id: String in MAPS:
		maps[id] = MapData.load_map(id, style, SIDE)
		navs[id] = NavGrid.build(maps[id], tuning.nav, tuning.body)


## The point's floor, found from just above the point's own height (Subway stacks three storeys).
func _floor(id: String, p: Vector3) -> float:
	return navs[id].floor_at(Vector3(p.x, p.y + 0.6, p.z))


func _flags(id: String) -> PackedVector3Array:
	return maps[id].poles


## Metres a point is past the middle, towards the enemy, for the given end (0 = the one that walks a lane first to last).
func _past_middle(id: String, p: Vector3, end: int) -> float:
	var m := maps[id]
	var home := _centre(m, 0)
	var enemy := _centre(m, 1)
	var way := Vector2(enemy.x - home.x, enemy.z - home.z)
	var half := way.length() * 0.5
	var along := Vector2(p.x - home.x, p.z - home.z).dot(way.normalized())
	return along - half if end == 0 else (half * 2.0 - along) - half


func _centre(m: MapData, e: int) -> Vector3:
	var c := Vector3.ZERO
	for s in m.ends[e].spawns:
		c += s.position
	return c / float(m.ends[e].spawns.size())


## How deep the first point past the middle is for end `e`, and its index (-1 and INF when none is).
func _first_past(id: String, lane: PackedVector3Array, e: int) -> Vector2:
	var n := lane.size()
	for k in n:
		var q := lane[k if e == 0 else n - 1 - k]
		var over := _past_middle(id, q, e)
		if over >= 0.0:
			return Vector2(k, over)
	return Vector2(-1.0, INF)


func test_every_lane_point_and_flag_stands_on_walkable_floor() -> void:
	for id: String in MAPS:
		var bad := PackedStringArray()
		for l in maps[id].lanes.size():
			for p in maps[id].lanes[l]:
				if not navs[id].is_walkable_at(Vector3(p.x, p.y + 0.6, p.z)):
					bad.append("lane %d %s" % [l + 1, p])
		for f in _flags(id):
			if not navs[id].is_walkable_at(Vector3(f.x, f.y + 0.6, f.z)):
				bad.append("flag %s" % f)
		assert_eq(bad.size(), 0, "%s: off the floor: %s" % [id, bad])


func test_both_ends_reach_every_lane_point_and_flag() -> void:
	var route := PackedVector3Array()
	for id: String in MAPS:
		var goals: Array[Vector3] = []
		for lane in maps[id].lanes:
			goals.append_array(lane)
		goals.append_array(_flags(id))
		var cut := PackedStringArray()
		for e in 2:
			var from := maps[id].ends[e].spawns[0].position
			for g in goals:
				route.clear()
				if not navs[id].find_route(from, g, route, true):
					cut.append("end %d to %s" % [e, g])
		assert_eq(cut.size(), 0, "%s: no route: %s" % [id, cut.slice(0, 5)])


func test_each_lane_has_a_point_either_side_of_the_middle_about_equally_deep_for_both_ends() -> void:
	for id: String in ["depot", "woodland"]:
		for l in maps[id].lanes.size():
			var lane := maps[id].lanes[l]
			var a := _first_past(id, lane, 0)
			var b := _first_past(id, lane, 1)
			assert_gt(a.x, 0.0, "%s lane %d: end 0 has a point short of the middle" % [id, l + 1])
			assert_gt(b.x, 0.0, "%s lane %d: end 1 has a point short of the middle" % [id, l + 1])
			assert_lt(absf(a.y - b.y), DEPTH_SLACK, "%s lane %d: first points past the middle %.1f and %.1f m deep"
					% [id, l + 1, a.y, b.y])
			assert_lt(maxf(a.y, b.y), 6.0, "%s lane %d: a squad goes no deeper than that" % [id, l + 1])


func test_subway_lanes_have_a_point_either_side_of_the_middle_about_equally_deep_for_both_ends() -> void:
	for l in maps["subway"].lanes.size():
		var lane := maps["subway"].lanes[l]
		var a := _first_past("subway", lane, 0)
		var b := _first_past("subway", lane, 1)
		assert_lt(absf(a.y - b.y), DEPTH_SLACK * 2.0, "lane %d: first points past the middle %.1f and %.1f m deep"
				% [l + 1, a.y, b.y])


func test_defender_posts_stand_on_the_site_within_reach_of_a_pole() -> void:
	for id: String in ["depot", "woodland"]:
		var at_a_site := 0
		for l in maps[id].lanes.size():
			var lane := maps[id].lanes[l]
			# Woodland's middle lane ends in the east camp's Back yard, at no pole: it defends nothing.
			if id == "woodland" and l == 1:
				continue
			at_a_site += 1
			for k: int in [lane.size() - 2, lane.size() - 1]:
				var q := lane[k]
				var nearest := INF
				for f in _flags(id):
					nearest = minf(nearest, Vector2(q.x - f.x, q.z - f.z).length())
				assert_lt(nearest, POST_REACH, "%s lane %d point %d is %.1f m from the nearest pole" % [id, l + 1, k + 1, nearest])
		assert_gte(at_a_site, 2, "%s: at least two lanes defend a site" % id)


func test_woodland_flag_b_forward_post_is_behind_the_crates() -> void:
	var lane := maps["woodland"].lanes[2]
	var post := lane[lane.size() - 2]
	assert_almost_eq(post.x, 44.6, 0.01, "flag B's forward defender post")
	assert_almost_eq(post.z, 29.8, 0.01, "flag B's forward defender post")
	var flag := maps["woodland"].poles[1]
	assert_lt(Vector2(post.x - flag.x, post.z - flag.z).length(), 12.0, "within reach of the pole")


func test_subway_flag_b_stands_on_the_north_platform_floor_clear_of_every_block() -> void:
	var m := maps["subway"]
	var f := m.poles[1]
	assert_almost_eq(f.x, 33.0, 0.01, "flag B x")
	assert_almost_eq(f.z, -7.8, 0.01, "flag B z")
	var nav := navs["subway"]
	assert_true(nav.is_walkable_at(Vector3(f.x, f.y + 0.6, f.z)), "a bot can stand at flag B")
	var floor_y := _floor("subway", f)
	assert_almost_eq(floor_y, 0.9, 0.2, "on the platform storey")
	var r := tuning.body.radius
	var feet := floor_y + 0.2
	var head := floor_y + tuning.body.stand_eye_height
	var hit := PackedStringArray()
	for b in m.blocks:
		if b.rise != MapData.Rise.NONE:
			continue
		var h := b.size * 0.5
		if absf(f.x - b.center.x) < h.x + r and absf(f.z - b.center.z) < h.z + r \
				and feet < b.center.y + h.y and head > b.center.y - h.y:
			hit.append("%s %s" % [b.kind, b.center])
	assert_eq(hit.size(), 0, "no block in a standing body at the flag: %s" % [hit])


## The Long road is clear of pieces (the owner, 2026-11-12, MB2): west of the Culvert it bends in an S between the two
## Road stands, and that S, not a piece on the road, keeps its strip off flag B's pole ring and posts.
func test_woodland_long_road_does_not_see_flag_b_pole_ring_or_posts() -> void:
	var m := maps["woodland"]
	var level := MapLevel.new()
	add_child(level)
	level.build(m, style, tuning.body)
	var q := level.query()
	var hit := RayHit.new()
	var nav := navs["woodland"]
	var eye := tuning.body.stand_eye_height
	var targets: Array[Vector3] = []
	for dx: float in [-POLE_RING, -POLE_RING * 0.5, 0.0, POLE_RING * 0.5, POLE_RING]:
		for dz: float in [-POLE_RING, -POLE_RING * 0.5, 0.0, POLE_RING * 0.5, POLE_RING]:
			targets.append(_chest(nav, POLE_B.x + dx, POLE_B.y + dz, eye))
	var ring_count := targets.size()
	for p: Vector2 in POSTS_B:
		targets.append(_chest(nav, p.x, p.y, eye))
	var ring_seen := 0
	var posts_seen := 0
	var from_count := 0
	for i in ROAD_WEST.size() - 1:
		var a := ROAD_WEST[i]
		var b := ROAD_WEST[i + 1]
		var side := (b - a).normalized().orthogonal() * ROAD_SIDE
		var steps := int(ceilf(a.distance_to(b)))
		for k in steps:
			var c := a.lerp(b, float(k) / float(steps))
			for p: Vector2 in [c - side, c, c + side]:
				var from := Vector3(p.x, nav.floor_at(Vector3(p.x, 50.0, p.y)) + eye, p.y)
				from_count += 1
				for t in targets.size():
					if not q.ray(from, targets[t], hit):
						if t < ring_count:
							ring_seen += 1
						else:
							posts_seen += 1
	level.free()
	assert_gt(from_count, 250, "the road's strip is sampled")
	assert_eq(ring_seen, 0, "the Long road west of the Culvert sees a chest in flag B's pole ring")
	assert_eq(posts_seen, 0, "the Long road west of the Culvert sees a chest at one of flag B's defender posts")


func _chest(nav: NavGrid, x: float, z: float, eye: float) -> Vector3:
	return Vector3(x, nav.floor_at(Vector3(x, 50.0, z)) + eye - CHEST_BELOW_EYE, z)


## A seeded bot match on each field: it finishes, BBs land, and no bot is held up.
func test_a_seeded_bot_match_finishes_on_each_field_with_no_bot_held_up() -> void:
	for id: String in MAPS:
		var runner := MatchRunner.new(self, id)
		var t := runner.play(11, 1800.0)
		runner.free_level()
		gut.p("%s: %d rounds, %d hits, held up %d, stayed home %d" % [id, t.rounds.size(), t.hits, t.held_up, t.stayed_home])
		assert_true(t.finished, "%s: the match is won" % id)
		assert_gt(t.hits, 0, "%s: BBs land" % id)
		assert_eq(t.held_up, 0, "%s: no bot held up" % id)
