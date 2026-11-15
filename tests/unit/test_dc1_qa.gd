extends GutTest
## QA for DC1 (Depot's compact hall, the owner's concept B): nothing the old west end left behind outside the new hall,
## the flags and bomb sites on walkable floor in their own areas, the overtime flag fair, the defender posts walkable,
## the Staging mouth open and the doors still set in walls.

const SIDE := 6
const HALL_X0 := -44.0
const HALL_X1 := 54.0
const HALL_Z0 := -36.0
const HALL_Z1 := 36.0

var tuning: SimTuning = SimTuning.new()
var style: MapStyle = MapStyle.new()
var map: MapData = null
var nav: NavGrid = null


func before_all() -> void:
	map = MapData.load_map("depot", style, SIDE)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func _in_hall(x: float, z: float, slack: float = 0.0) -> bool:
	return x >= HALL_X0 - slack and x <= HALL_X1 + slack and z >= HALL_Z0 - slack and z <= HALL_Z1 + slack


func test_no_block_lamp_mark_stencil_door_or_area_lies_outside_the_hall() -> void:
	var out := PackedStringArray()
	for b in map.blocks:
		if b.kind == &"wall" and (absf(b.center.x - HALL_X0) < 1.0 or absf(b.center.x - HALL_X1) < 1.0
				or absf(b.center.z) > 35.0):
			continue # the outer walls themselves, 0.5 m thick on the edge
		if b.center.x - b.size.x * 0.5 < HALL_X0 - 1e-3 or b.center.x + b.size.x * 0.5 > HALL_X1 + 1e-3 \
				or b.center.z - b.size.z * 0.5 < HALL_Z0 - 1e-3 or b.center.z + b.size.z * 0.5 > HALL_Z1 + 1e-3:
			out.append("block %s at %s" % [b.kind, b.center])
	for l in map.roof_lamps:
		if not _in_hall(l.x, l.y):
			out.append("lamp %s" % l)
	for m in map.marks:
		if not _in_hall(m.at.x, m.at.y):
			out.append("mark %s" % m.at)
	if map.site != null:
		for s in map.site.stencils:
			if not _in_hall(s.at.x, s.at.z):
				out.append("stencil %s" % s.area)
	for d in map.doors:
		if not _in_hall(d.center.x, d.center.z):
			out.append("door %s" % d.center)
	for a in map.areas:
		if a.x0 < HALL_X0 - 1e-3 or a.x1 > HALL_X1 + 1e-3 or a.z0 < HALL_Z0 - 1e-3 or a.z1 > HALL_Z1 + 1e-3:
			out.append("area %s" % a.name)
	assert_eq(out.size(), 0, "outside the hall: %s" % [out.slice(0, 6)])


func test_the_hall_footprint_is_the_compact_one_and_holds_every_start_flag_and_site() -> void:
	var f := map.footprint()
	assert_almost_eq(f.position.x, HALL_X0 - 0.5, 0.01, "west wall's outer face")
	assert_almost_eq(f.end.x, HALL_X1 + 0.5, 0.01, "east wall's outer face")
	var spots: Array[Vector3] = [map.overtime_flag]
	spots.append_array(map.poles)
	spots.append_array(map.bomb_sites)
	for e in 2:
		for s in map.ends[e].spawns:
			spots.append(s.position)
		for d in map.ends[e].dead_zone:
			spots.append(d.position)
	for p in spots:
		assert_true(f.has_point(Vector2(p.x, p.z)), "%s inside the footprint" % p)


func test_every_flag_and_bomb_site_is_walkable_and_in_its_own_site_area() -> void:
	assert_eq(map.poles.size(), 2)
	assert_eq(map.bomb_sites.size(), 2)
	var names: Array[String] = ["A site", "B site"]
	for i in 2:
		assert_true(nav.is_walkable_at(map.poles[i]), "flag %d walkable" % i)
		assert_true(nav.is_walkable_at(map.bomb_sites[i]), "site %d walkable" % i)
		assert_eq(MapAreas.area_at(map.areas, map.poles[i]), names[i], "flag %d's area" % i)
		assert_eq(MapAreas.area_at(map.areas, map.bomb_sites[i]), names[i], "site %d's area" % i)
		assert_lt(Vector2(map.poles[i].x - map.bomb_sites[i].x, map.poles[i].z - map.bomb_sites[i].z).length(),
				map.bomb_site_radii[i] + 3.0, "flag %d stands near its site" % i)


func test_the_overtime_flag_is_walkable_in_the_hall_and_both_ends_are_about_as_far_from_it() -> void:
	assert_true(nav.is_walkable_at(map.overtime_flag))
	assert_ne(MapAreas.area_at(map.areas, map.overtime_flag), "Staging", "not in a spawn room")
	var lens: Array[float] = []
	var route := PackedVector3Array()
	for e in 2:
		route.clear()
		assert_true(nav.find_route(map.ends[e].spawns[0].position, map.overtime_flag, route, false), "end %d reaches it" % e)
		var length := 0.0
		var at := map.ends[e].spawns[0].position
		for p in route:
			length += Vector2(p.x - at.x, p.z - at.z).length()
			at = p
		lens.append(length)
	var ratio := minf(lens[0], lens[1]) / maxf(lens[0], lens[1])
	gut.p("overtime flag walks: %.1f m west, %.1f m east (ratio %.2f)" % [lens[0], lens[1], ratio])
	assert_gt(ratio, 0.75, "the flag is fair: %s" % [lens])


func test_every_lane_point_is_inside_the_hall_and_not_in_a_spawn_room() -> void:
	assert_eq(map.lanes.size(), 5, "five lanes")
	for lane in map.lanes:
		assert_gte(lane.size(), 4)
		for p in lane:
			assert_true(_in_hall(p.x, p.z), "lane point %s" % p)
			assert_ne(MapAreas.area_at(map.areas, p), "Staging", "lane point %s in Staging" % p)
			assert_ne(MapAreas.area_at(map.areas, p), "Loading bay", "lane point %s in the Loading bay" % p)


func test_both_ends_reach_the_defender_posts_on_the_lower_mid_and_containers_crates() -> void:
	var route := PackedVector3Array()
	for post: Vector3 in [Vector3(29.0, 0.0, -2.2), Vector3(26.5, 0.0, 24.5)]:
		assert_true(nav.is_walkable_at(post), "post %s walkable" % post)
		for e in 2:
			route.clear()
			assert_true(nav.find_route(map.ends[e].spawns[0].position, post, route, false), "end %d reaches %s" % [e, post])
		# Behind a low crate: a block under a metre stands within 1.5 m of the post.
		var crate := false
		for b in map.blocks:
			if b.size.y <= 1.3 and b.center.y + b.size.y * 0.5 <= 1.3 and b.size.y > 0.3 \
					and absf(b.center.x - post.x) < b.size.x * 0.5 + 1.5 and absf(b.center.z - post.z) < b.size.z * 0.5 + 1.5:
				crate = true
		assert_true(crate, "a low block beside post %s" % post)


func test_staging_opens_to_upper_mid_by_a_mouth_about_eight_metres_wide() -> void:
	# The plywood wall at x -34 closes the room's east side from z -13 to -6; the rest of the side is the mouth.
	var best := 0.0
	var run := 0.0
	var z := -13.0
	while z <= 4.5:
		if nav.is_walkable_at(Vector3(-34.0, 0.0, z)):
			run += 0.25
			best = maxf(best, run)
		else:
			run = 0.0
		z += 0.25
	gut.p("Staging's east mouth: %.2f m of walkable floor in a run" % best)
	assert_gte(best, 6.0, "a mouth a squad can come through")
	assert_false(nav.is_walkable_at(Vector3(-34.0, 0.0, -9.5)), "the plywood wall stands")
	var route := PackedVector3Array()
	assert_true(nav.find_route(Vector3(-40.0, 0.0, -4.75), Vector3(-28.0, 0.0, -2.0), route, false), "out to Upper mid")


func test_every_door_is_set_in_a_block_of_the_hall() -> void:
	var loose := PackedStringArray()
	for d in map.doors:
		var held := false
		for b in map.blocks:
			if absf(d.center.x - b.center.x) <= b.size.x * 0.5 + 0.3 and absf(d.center.z - b.center.z) <= b.size.z * 0.5 + 0.3 \
					and d.center.y - d.size.y * 0.5 >= b.center.y - b.size.y * 0.5 - 0.3:
				held = true
				break
		if not held:
			loose.append(str(d.center))
	assert_eq(loose.size(), 0, "doors hanging in the open: %s" % [loose])


func test_no_walkable_cell_lies_beyond_the_west_wall() -> void:
	var beyond := PackedStringArray()
	for x in range(-60, -45):
		for z in range(-40, 41, 2):
			if nav.is_walkable_at(Vector3(x, 0.0, z)):
				beyond.append("%d,%d" % [x, z])
	assert_eq(beyond.size(), 0, "floor outside the west wall: %s" % [beyond.slice(0, 5)])
