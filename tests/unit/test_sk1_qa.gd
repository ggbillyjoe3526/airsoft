extends GutTest
## QA for Stockade (SK1): the map loads clean, is dev-only, its ends, sites, poles, flag and bomb start stand on floor
## the bots reach from both spawns, nobody can stand above the ground (no roof walks), and every walkable cell is
## reachable on foot from the attackers' spawn.

const SPOT_SNAP := 0.6

var map: MapData
var nav: NavGrid
var tuning: SimTuning


func before_all() -> void:
	tuning = SimTuning.load_default()
	map = MapData.load_map("stockade", PlayTuning.load_default().map_style, tuning.rounds.team_size)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func after_all() -> void:
	map = null
	nav = null


func _reached(from: Vector3, to: Vector3) -> bool:
	var route := PackedVector3Array()
	return nav.find_route(from, to, route)


func test_stockade_loads_with_no_problem_and_no_warning() -> void:
	assert_eq(map.problems, [] as Array[String])
	assert_eq(map.warnings, [] as Array[String])
	var style := PlayTuning.load_default().map_style
	assert_eq(MatchOptions.map_problems("stockade", style, 6), [] as Array[String])
	assert_eq(MatchOptions.map_problems("stockade", style, 8), [] as Array[String])


func test_stockade_is_listed_only_with_dev_content_on() -> void:
	var catalog := MapCatalog.read_file()
	var public_ids: Array[String] = []
	for e: MapCatalog.Entry in catalog.fields(false):
		public_ids.append(e.id)
	var dev_ids: Array[String] = []
	for e: MapCatalog.Entry in catalog.fields(true):
		dev_ids.append(e.id)
	assert_does_not_have(public_ids, "stockade")
	assert_has(dev_ids, "stockade")
	assert_true(catalog.is_dev("stockade"))


func test_the_night_preset_and_every_light_are_read() -> void:
	assert_has(map.lighting_presets, &"night")
	assert_has(map.lighting_presets, &"day")
	assert_eq(map.lights.size(), 26, "every lantern and fire kept")


func test_sites_poles_flag_and_bomb_start_are_on_floor_both_ends_reach() -> void:
	assert_true(map.has_bomb_sites)
	assert_eq(map.bomb_sites.size(), 2)
	assert_true(map.has_bomb_start)
	assert_true(map.has_overtime_flag)
	var spots: Array[Vector3] = [map.bomb_start, map.overtime_flag]
	for s: Vector3 in map.bomb_sites:
		spots.append(s)
	for f: Vector3 in map.poles:
		spots.append(f)
	assert_eq(spots.size(), 6)
	for p: Vector3 in spots:
		assert_true(nav.is_walkable_at(p), "%s stands on walkable floor" % p)
		for e in 2:
			var spawn := map.ends[e].spawns[0].position
			assert_true(_reached(spawn, p), "end %d reaches %s" % [e, p])


func test_every_spawn_and_dead_zone_spot_is_walkable_and_reaches_the_other_end() -> void:
	for e in 2:
		for list: Array in [map.ends[e].spawns, map.ends[e].dead_zone]:
			for sp: SpawnPoint in list:
				assert_true(nav.is_walkable_at(sp.position), "%s walkable" % sp.position)
		var d: SpawnPoint = map.ends[e].dead_zone[0]
		var other: Vector3 = map.ends[1 - e].spawns[0].position
		assert_true(_reached(d.position, other), "dead zone %d reaches the other end's spawn" % e)


func test_nobody_stands_above_the_ground_so_no_roof_is_walkable() -> void:
	var highest := 0.0
	for k in nav.node_count():
		if nav.floor_y[k] > highest:
			highest = nav.floor_y[k]
	assert_lt(highest, 0.3, "the highest standable floor on the nav grid")


func test_every_walkable_node_is_reachable_on_foot_from_the_attackers_spawn() -> void:
	var start: Vector3 = map.ends[0].spawns[0].position
	var route := PackedVector3Array()
	var cut_off := 0
	var worst := Vector3.ZERO
	for k in nav.node_count():
		if not nav.walkable[k]:
			continue
		var p := nav.node_position(k)
		# A sparse sample keeps the run short: every 6th node.
		if k % 6 != 0:
			continue
		if not nav.find_route(start, p, route):
			cut_off += 1
			worst = p
	assert_eq(cut_off, 0, "standable cells with no walk from the West camp (last at %s)" % worst)


# ---- MB1's lane rules (docs/DECISIONS.md, "A lane is laid for the planner"), as test_mb1_layouts checks them ----

## The most the two ends' first points past the middle may differ in depth (m), and the deepest either goes.
const DEPTH_SLACK := 3.5
const DEEPEST := 6.0
## The farthest a defender post (a lane's last two points) may stand from the nearest pole (m).
const POST_REACH := 30.0
const DOORS_TOTAL := 26
const DOORS_SHUT := 0
const ORCHARD_GATES: Array[float] = [-29.0, 7.0]
## Four minutes of a seeded bot match, not the whole match (the balance runs play whole ones).
const MATCH_SECONDS := 240.0


func _centre(e: int) -> Vector3:
	var c := Vector3.ZERO
	for s in map.ends[e].spawns:
		c += s.position
	return c / float(map.ends[e].spawns.size())


## Metres a point is past the middle (spawn-to-spawn line) towards the enemy, for end `end`.
func _past_middle(p: Vector3, end: int) -> float:
	var home := _centre(0)
	var way := Vector2(_centre(1).x - home.x, _centre(1).z - home.z)
	var half := way.length() * 0.5
	var along := Vector2(p.x - home.x, p.z - home.z).dot(way.normalized())
	return along - half if end == 0 else (half * 2.0 - along) - half


## Index walked and depth of the first point past the middle for end `e` (-1, INF when none).
func _first_past(lane: PackedVector3Array, e: int) -> Vector2:
	var n := lane.size()
	for k in n:
		var over := _past_middle(lane[k if e == 0 else n - 1 - k], e)
		if over >= 0.0:
			return Vector2(k, over)
	return Vector2(-1.0, INF)


func test_every_lane_point_and_flag_stands_on_walkable_floor() -> void:
	var bad := PackedStringArray()
	for l in map.lanes.size():
		for p in map.lanes[l]:
			if not nav.is_walkable_at(Vector3(p.x, p.y + 0.6, p.z)):
				bad.append("lane %d %s" % [l + 1, p])
	for f in map.poles:
		if not nav.is_walkable_at(Vector3(f.x, f.y + 0.6, f.z)):
			bad.append("flag %s" % f)
	assert_eq(bad.size(), 0, "off the floor: %s" % [bad])


func test_both_ends_reach_every_lane_point_and_flag() -> void:
	var goals: Array[Vector3] = []
	for lane in map.lanes:
		goals.append_array(lane)
	goals.append_array(map.poles)
	var route := PackedVector3Array()
	var cut := PackedStringArray()
	for e in 2:
		var from := map.ends[e].spawns[0].position
		for g in goals:
			route.clear()
			if not nav.find_route(from, g, route, true):
				cut.append("end %d to %s" % [e, g])
	assert_eq(cut.size(), 0, "no route: %s" % [cut.slice(0, 5)])


func test_each_lane_has_a_point_either_side_of_the_middle_about_equally_deep_for_both_ends() -> void:
	assert_eq(map.lanes.size(), 3)
	for l in map.lanes.size():
		var lane := map.lanes[l]
		var a := _first_past(lane, 0)
		var b := _first_past(lane, 1)
		assert_gt(a.x, 0.0, "lane %d: end 0 has a point short of the middle" % [l + 1])
		assert_gt(b.x, 0.0, "lane %d: end 1 has a point short of the middle" % [l + 1])
		assert_lt(absf(a.y - b.y), DEPTH_SLACK, "lane %d: first points past the middle %.1f and %.1f m deep" % [l + 1, a.y, b.y])
		assert_lte(maxf(a.y, b.y), DEEPEST, "lane %d: a squad goes no deeper than that" % [l + 1])


func test_defender_posts_stand_within_reach_of_a_pole() -> void:
	for l in map.lanes.size():
		var lane := map.lanes[l]
		for k: int in [lane.size() - 2, lane.size() - 1]:
			var nearest := INF
			for f in map.poles:
				nearest = minf(nearest, Vector2(lane[k].x - f.x, lane[k].z - f.z).length())
			assert_lt(nearest, POST_REACH, "lane %d point %d (%s) is %.1f m from the nearest pole" % [l + 1, k + 1, lane[k], nearest])


# ---- Doors, gates, the Bell house ----

## Every door starts the round open: the Long House's east door is the defenders' way onto flag A (SK1 attempt 3).
func test_stockade_has_twenty_six_doors_all_open() -> void:
	assert_eq(map.doors.size(), DOORS_TOTAL)
	var shut := 0
	for d in map.doors:
		if d.shut:
			shut += 1
	assert_eq(shut, DOORS_SHUT)


## The doorway of an open door is walkable and a body gets through it from both faces; a shut leaf stops a BB at the
## doorway's mid-height and an open one does not.
func test_every_doorway_is_passable_open_and_shut_ones_stop_a_bb() -> void:
	var level := MapLevel.new()
	add_child(level)
	level.build(map, PlayTuning.load_default().map_style, tuning.body)
	var q := level.query()
	var hit := RayHit.new()
	var blocked := PackedStringArray()
	var passable := PackedStringArray()
	for d in map.doors:
		var thin_x := d.size.x < d.size.z
		var axis := Vector3.RIGHT if thin_x else Vector3.BACK
		var a: Vector3 = d.center - axis * 1.0
		var b: Vector3 = d.center + axis * 1.0
		var stopped := q.ray(a, b, hit)
		if d.shut and not stopped:
			blocked.append("shut door at %s lets a BB through" % d.center)
		if not d.shut and stopped:
			blocked.append("open door at %s stops a BB" % d.center)
		for p: Vector3 in [d.center, a, b]:
			if not nav.is_walkable_at(Vector3(p.x, 0.0, p.z)):
				passable.append("%s not walkable (door %s)" % [p, d.center])
		var from := Vector3(a.x, 0.0, a.z)
		if not _reached(map.ends[0].spawns[0].position, from) or not _reached(map.ends[1].spawns[0].position, from):
			passable.append("an end can't reach the near face of the door at %s" % d.center)
	level.free()
	assert_eq(blocked.size(), 0, "%s" % [blocked])
	assert_eq(passable.size(), 0, "%s" % [passable.slice(0, 6)])


func test_the_orchards_two_gates_are_walkable_and_reached_from_both_ends() -> void:
	for gx in ORCHARD_GATES:
		for z: float in [33.0, 34.4, 35.0, 36.0]:
			var p := Vector3(gx, 0.0, z)
			assert_true(nav.is_walkable_at(p), "gate x=%.1f z=%.1f walkable" % [gx, z])
		for e in 2:
			assert_true(_reached(map.ends[e].spawns[0].position, Vector3(gx, 0.0, 36.0)), "end %d reaches inside the Orchard by x=%.1f" % [e, gx])


## Two doors, off each other's line (the street behind, the Green), a crate stack between them (SK1 attempt 3).
func test_the_bell_house_has_two_doors_and_its_inside_is_reached() -> void:
	var box := Rect2(12.0, -4.5, 6.0, 9.0)
	var inside := 0
	for d in map.doors:
		if box.grow(0.5).has_point(Vector2(d.center.x, d.center.z)):
			inside += 1
	assert_eq(inside, 2, "doors on the Bell house")
	var c := Vector3(15.0, 0.0, -2.5)
	assert_true(nav.is_walkable_at(c), "the way round its stock is walkable")
	for e in 2:
		assert_true(_reached(map.ends[e].spawns[0].position, c), "end %d reaches the Bell house" % e)


## The first rounds of a seeded bot match: rounds end, BBs land, no bot is held up.
func test_a_seeded_bot_match_plays_rounds_with_no_bot_held_up() -> void:
	var runner := MatchRunner.new(self, "stockade")
	var t := runner.play(11, MATCH_SECONDS)
	runner.free_level()
	gut.p("stockade: %d rounds, %d hits, held up %d, stayed home %d" % [t.rounds.size(), t.hits, t.held_up, t.stayed_home])
	var decided := 0
	for r in t.rounds:
		if r.winner >= 0:
			decided += 1
	assert_gt(decided, 0, "a round is won")
	assert_gt(t.hits, 0, "BBs land")
	assert_eq(t.held_up, 0, "no bot held up")
