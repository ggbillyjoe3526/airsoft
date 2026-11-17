extends GutTest
## The nav grid (game/nav/), ported from the browser game's nav/navGrid.test.ts: walls and their clearance, a door's
## lane, snapping, routes round cover in straight legs, raised floors and ramps (the clearance from a drop, no walking
## off an edge), floors over floors, and Depot: the dock's lip (G11), every spawn to every dead-zone spot, and legs that
## keep a body's radius from every block (audit AI-12). The terrain cases wait for a map with terrain.

const YARD_HALF := 15.0
const WALL := 0.4

var cfg: NavConfig = NavConfig.new()
var body: BodyConfig = BodyConfig.new()
var yard: NavGrid = null
var depot_map: MapData = null
var depot: NavGrid = null


func before_all() -> void:
	yard = NavGrid.build(_yard([]), cfg, body)
	depot_map = YardMap.load_map(MapStyle.new(), 3) # the old Depot, whose docks and ramps these tests walk (DR1)
	depot = NavGrid.build(depot_map, cfg, body)


static func _block(kind: StringName, center: Vector3, size: Vector3, rise: MapData.Rise = MapData.Rise.NONE) \
		-> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	b.rise = rise
	return b


static func _map(blocks: Array[MapData.Block]) -> MapData:
	var m := MapData.new()
	m.id = "test"
	m.blocks = blocks
	return m


## The browser's Test Yard: a walled 30 m square with a 1.2 m crate at (0, -6), and `extra`.
static func _yard(extra: Array[MapData.Block]) -> MapData:
	var side := YARD_HALF * 2.0 + WALL * 2.0
	var blocks: Array[MapData.Block] = [
		_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(side, 0.5, side)),
		_block(&"wall", Vector3(0.0, 1.5, -YARD_HALF - WALL / 2.0), Vector3(side, 3.0, WALL)),
		_block(&"wall", Vector3(0.0, 1.5, YARD_HALF + WALL / 2.0), Vector3(side, 3.0, WALL)),
		_block(&"wall", Vector3(-YARD_HALF - WALL / 2.0, 1.5, 0.0), Vector3(WALL, 3.0, YARD_HALF * 2.0)),
		_block(&"wall", Vector3(YARD_HALF + WALL / 2.0, 1.5, 0.0), Vector3(WALL, 3.0, YARD_HALF * 2.0)),
		_block(&"crate", Vector3(0.0, 0.6, -6.0), Vector3(1.2, 1.2, 1.2)),
	]
	blocks.append_array(extra)
	return _map(blocks)


## A 1 m platform (x 2..8, z -4..4) on a 20 m yard, with a 2 m wide ramp up to it from the west (1:2) if `ramp`.
static func _platform_yard(ramp: bool, extra: Array[MapData.Block] = []) -> MapData:
	var blocks: Array[MapData.Block] = [
		_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(20.0, 0.5, 20.0)),
		_block(&"floor", Vector3(5.0, 0.5, 0.0), Vector3(6.0, 1.0, 8.0)),
	]
	if ramp:
		blocks.append(_block(&"ramp", Vector3(1.0, 0.5, 0.0), Vector3(2.0, 1.0, 2.0), MapData.Rise.POS_X))
	blocks.append_array(extra)
	return _map(blocks)


## Two storeys: a 40 x 16 m yard, an upper floor 3 m up over x -6..6 (a hall under it), and a 2 m stair up to it from
## the west (x -12..-6, z 5..7). The upper floor's other edges are open drops.
static func _two_storeys() -> MapData:
	var blocks: Array[MapData.Block] = [
		_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(40.0, 0.5, 16.0)),
		_block(&"floor", Vector3(0.0, 2.85, 0.0), Vector3(12.0, 0.3, 16.0)),
		_block(&"ramp", Vector3(-9.0, 1.5, 6.0), Vector3(6.0, 3.0, 2.0), MapData.Rise.POS_X),
		_block(&"crate", Vector3(0.0, 0.6, 0.0), Vector3(1.2, 1.2, 1.2)),
	]
	return _map(blocks)


## Every leg of `path` from `from` is walkable in a straight line on its floor and steps off no edge, and it ends at `to`.
func _check_route(g: NavGrid, from: Vector3, to: Vector3, path: PackedVector3Array) -> void:
	var p := from
	for q in path:
		assert_true(g.clear_line(p, q), "leg %s -> %s walkable" % [p, q])
		assert_false(g.drop_on_line(p, q), "leg %s -> %s steps off no edge" % [p, q])
		p = q
	assert_lt(Vector2(p.x - to.x, p.z - to.z).length(), cfg.cell, "ends at %s" % to)


func _route_length(from: Vector3, path: PackedVector3Array) -> float:
	var length := 0.0
	var p := from
	for q in path:
		length += Vector2(q.x - p.x, q.z - p.z).length()
		p = q
	return length


func test_blocks_the_crate_plus_clearance_and_the_perimeter_and_leaves_open_ground_walkable() -> void:
	var r := cfg.clearance(body)
	assert_true(yard.is_walkable_at(Vector3(0.0, 0.0, 0.0)))
	assert_false(yard.is_walkable_at(Vector3(0.0, 0.0, -6.0)), "the crate")
	assert_false(yard.is_walkable_at(Vector3(0.6 + r - 0.05, 0.0, -6.0)), "within the clearance of its side")
	assert_true(yard.is_walkable_at(Vector3(0.6 + r + 0.15, 0.0, -6.0)))
	assert_false(yard.is_walkable_at(Vector3(14.9, 0.0, 0.0)), "against the wall")
	assert_true(is_nan(yard.floor_at(Vector3(40.0, 0.0, 0.0))), "off the grid")
	assert_eq(yard.node_at(Vector3(40.0, 0.0, 0.0)), -1)


func test_walks_straight_across_open_ground_in_one_leg_ending_on_the_goal() -> void:
	var path := PackedVector3Array()
	var from := Vector3(-5.0, 0.0, 5.0)
	var to := Vector3(5.0, 0.0, 5.0)
	assert_true(yard.find_route(from, to, path))
	assert_eq(path.size(), 1)
	assert_eq(path[0], to, "exactly on the goal")
	_check_route(yard, from, to, path)


func test_routes_round_the_crate_in_straight_walkable_legs() -> void:
	var path := PackedVector3Array()
	var from := Vector3(0.0, 0.0, -2.0)
	var to := Vector3(0.0, 0.0, -10.0)
	assert_false(yard.clear_line(from, to))
	assert_true(yard.find_route(from, to, path))
	assert_gt(path.size(), 1)
	_check_route(yard, from, to, path)
	assert_lt(_route_length(from, path), 8.0 + 2.5, "a short detour, not a lap of the yard")


func test_snaps_ends_inside_the_clearance_to_the_nearest_walkable_cell() -> void:
	assert_gte(yard.nearest_walkable(Vector3(0.0, 0.0, -6.0), cfg.snap), 0)
	assert_eq(yard.nearest_walkable(Vector3(0.0, 0.0, -6.0), 0.1), -1)
	var path := PackedVector3Array()
	assert_true(yard.find_route(Vector3(0.0, 0.0, -6.0), Vector3(5.0, 0.0, 5.0), path), "from inside the crate")


func test_a_one_metre_door_keeps_a_lane_down_its_middle() -> void:
	# A wall across the yard at z = 0 with a 1 m gap at x -0.5..0.5.
	var half := (YARD_HALF - 0.5) / 2.0
	var g := NavGrid.build(_yard([
		_block(&"wall", Vector3(-0.5 - half, 1.5, 0.0), Vector3(half * 2.0, 3.0, WALL)),
		_block(&"wall", Vector3(0.5 + half, 1.5, 0.0), Vector3(half * 2.0, 3.0, WALL)),
	]), cfg, body)
	assert_true(g.is_walkable_at(Vector3(0.0, 0.0, 0.0)), "the door's middle")
	assert_false(g.is_walkable_at(Vector3(0.4, 0.0, 0.0)), "its sides keep the clearance")
	var path := PackedVector3Array()
	var from := Vector3(6.0, 0.0, -5.0)
	var to := Vector3(-6.0, 0.0, 5.0)
	assert_true(g.find_route(from, to, path))
	_check_route(g, from, to, path)
	var p := from
	for q in path:
		if p.z * q.z < 0.0:
			assert_lt(absf(p.x + (0.0 - p.z) / (q.z - p.z) * (q.x - p.x)), 0.5, "crosses the wall in the door")
		p = q


func test_reports_no_route_into_a_sealed_room_and_empties_the_route() -> void:
	var g := NavGrid.build(_yard([
		_block(&"wall", Vector3(7.0, 1.5, 3.2), Vector3(8.0, 3.0, 0.4)),
		_block(&"wall", Vector3(7.0, 1.5, 10.8), Vector3(8.0, 3.0, 0.4)),
		_block(&"wall", Vector3(3.2, 1.5, 7.0), Vector3(0.4, 3.0, 8.0)),
		_block(&"wall", Vector3(10.8, 1.5, 7.0), Vector3(0.4, 3.0, 8.0)),
	]), cfg, body)
	var inside := Vector3(7.0, 0.0, 7.0)
	assert_true(g.is_walkable_at(inside))
	var path := PackedVector3Array([Vector3.ONE])
	assert_false(g.find_route(Vector3(-5.0, 0.0, -2.0), inside, path))
	assert_eq(path.size(), 0)


func test_gives_each_cell_the_height_of_the_surface_under_it() -> void:
	var g := NavGrid.build(_platform_yard(true), cfg, body)
	assert_eq(g.floor_at(Vector3(-4.0, 0.0, 0.0)), 0.0)
	assert_eq(g.floor_at(Vector3(6.0, 0.0, 0.0)), 1.0)
	assert_almost_eq(g.floor_at(Vector3(1.1, 0.0, 0.0)), 0.55, 1e-5, "the ramp at that cell's centre")


func test_routes_up_a_ramp_onto_the_platform_with_every_waypoint_on_its_floor() -> void:
	var g := NavGrid.build(_platform_yard(true), cfg, body)
	var path := PackedVector3Array()
	var below := Vector3(-4.0, 0.0, 0.0)
	var above := Vector3(6.0, 1.0, 0.0)
	assert_true(g.find_route(below, above, path))
	_check_route(g, below, above, path)
	for p in path:
		assert_eq(p.y, g.floor_at(p), "%s on its floor" % p)
	assert_eq(path[path.size() - 1].y, 1.0)
	# Up the ramp, not up the platform's side: the route crosses x = 2 between the ramp's sides.
	var a := below
	for b in path:
		if (a.x - 2.0) * (b.x - 2.0) < 0.0:
			assert_lt(absf(a.z + (2.0 - a.x) / (b.x - a.x) * (b.z - a.z)), 1.0)
		a = b


func test_has_no_route_onto_a_one_metre_platform_without_a_ramp() -> void:
	var g := NavGrid.build(_platform_yard(false), cfg, body)
	assert_true(g.is_walkable_at(Vector3(-4.0, 0.0, 0.0)))
	assert_true(g.is_walkable_at(Vector3(6.0, 0.0, 0.0)))
	var path := PackedVector3Array()
	assert_false(g.find_route(Vector3(-4.0, 0.0, 0.0), Vector3(6.0, 1.0, 0.0), path))
	assert_false(g.clear_line(Vector3(-4.0, 0.0, 0.0), Vector3(6.0, 0.0, 0.0)), "no straight line up its side")


func test_finds_drops_on_a_line_but_not_walls_or_the_ramp_itself() -> void:
	var g := NavGrid.build(_platform_yard(true, [_block(&"wall", Vector3(-4.0, 1.5, 3.0), Vector3(4.0, 3.0, 0.4))]),
			cfg, body)
	assert_false(g.drop_on_line(Vector3(6.0, 0.0, 2.0), Vector3(7.0, 0.0, 2.0)), "across the platform")
	assert_true(g.drop_on_line(Vector3(2.4, 0.0, 2.0), Vector3(1.6, 0.0, 2.0)), "off its west edge")
	assert_true(g.drop_on_line(Vector3(1.6, 0.0, 2.0), Vector3(2.4, 0.0, 2.0)), "and up it")
	assert_false(g.drop_on_line(Vector3(-1.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0)), "up the ramp")
	assert_true(g.drop_on_line(Vector3(1.0, 0.0, 0.5), Vector3(1.0, 0.0, 1.5)), "off the ramp's side")
	assert_false(g.drop_on_line(Vector3(-4.0, 0.0, 2.0), Vector3(-4.0, 0.0, 4.0)), "through a wall: not a drop")
	assert_true(g.drop_on_line(Vector3(9.5, 0.0, 0.0), Vector3(10.5, 0.0, 0.0)), "past the floor's edge")
	assert_false(g.drop_on_line(Vector3(1.6, 0.0, 2.0), Vector3(2.4, 0.0, 2.0), 0.5), "a wall too high to ride onto")


func test_keeps_the_clearance_from_a_drop_on_both_sides_of_it() -> void:
	var g := NavGrid.build(_platform_yard(false), cfg, body)
	var r := cfg.clearance(body)
	# The platform's west side is at x = 2.
	assert_false(g.is_walkable_at(Vector3(2.0 - r + 0.1, 0.0, 2.0)))
	assert_true(g.is_walkable_at(Vector3(2.0 - r - 0.15, 0.0, 2.0)))
	assert_false(g.is_walkable_at(Vector3(2.0 + r - 0.1, 0.0, 2.0)))
	assert_true(g.is_walkable_at(Vector3(2.0 + r + 0.15, 0.0, 2.0)))


func test_judges_blocks_against_the_floor_they_stand_over() -> void:
	# On the platform: a crate (blocks) and a 0.1 m mat (walked onto). Across the yard and the platform, a beam 2 m
	# above the yard floor: it passes overhead in the yard but is only 1 m above the platform.
	var g := NavGrid.build(_platform_yard(true, [
		_block(&"crate", Vector3(4.0, 1.6, 2.0), Vector3(1.2, 1.2, 1.2)),
		_block(&"barrier", Vector3(6.5, 1.05, 1.0), Vector3(1.0, 0.1, 1.0)),
		_block(&"barrier", Vector3(0.0, 2.1, -2.5), Vector3(20.0, 0.2, 0.4)),
	]), cfg, body)
	assert_false(g.is_walkable_at(Vector3(4.0, 0.0, 2.0)))
	assert_true(g.is_walkable_at(Vector3(6.5, 0.0, 1.0)))
	assert_true(g.is_walkable_at(Vector3(-4.0, 0.0, -2.5)))
	assert_false(g.is_walkable_at(Vector3(6.5, 0.0, -2.5)))


func test_keeps_a_floor_under_the_upper_floor_and_none_inside_a_stair() -> void:
	var g := NavGrid.build(_two_storeys(), cfg, body)
	assert_eq(g.layers, 2)
	var c := g.cell_index(-4.5, 2.0)
	assert_eq(g.floor_y.slice(g.cell_start[c], g.cell_start[c + 1]), PackedFloat32Array([0.0, 3.0]), "hall and floor")
	c = g.cell_index(-15.0, 0.0)
	assert_eq(g.cell_start[c + 1] - g.cell_start[c], 1, "the yard")
	c = g.cell_index(-9.1, 6.1)
	assert_eq(g.cell_start[c + 1] - g.cell_start[c], 1, "the stair's solid wedge: its top only")
	assert_almost_eq(g.floor_at(Vector3(-9.1, 0.0, 6.1)), 1.45, 1e-4)


func test_answers_each_query_for_the_floor_at_the_height_asked_about() -> void:
	var g := NavGrid.build(_two_storeys(), cfg, body)
	assert_eq(g.floor_at(Vector3(-4.5, 0.0, 2.0)), 0.0)
	assert_eq(g.floor_at(Vector3(-4.5, 1.4, 2.0)), 0.0, "mid-jump: still over the hall floor")
	assert_eq(g.floor_at(Vector3(-4.5, 3.0, 2.0)), 3.0)
	assert_eq(g.floor_at(Vector3(-4.5, -5.0, 2.0)), 0.0, "below every floor: the lowest")
	# Under the upper floor's open edge: the hall floor is walkable, the edge above it is not.
	assert_true(g.is_walkable_at(Vector3(-5.9, 0.0, 2.0)))
	assert_false(g.is_walkable_at(Vector3(-5.9, 3.0, 2.0)))
	var k := g.nearest_walkable(Vector3(-5.9, 3.0, 2.0), cfg.snap)
	assert_gte(k, 0)
	assert_eq(g.floor_y[k], 3.0, "snaps to the upper floor, not the hall under it")
	assert_true(g.drop_on_line(Vector3(-5.0, 3.0, 2.5), Vector3(-7.0, 3.0, 2.5)), "off the edge")
	assert_false(g.drop_on_line(Vector3(-5.0, 0.0, 2.5), Vector3(-7.0, 0.0, 2.5)), "out from under it")
	assert_false(g.drop_on_line(Vector3(-11.0, 0.5, 6.0), Vector3(-5.0, 3.0, 6.0)), "up the stair")
	assert_false(g.clear_line(Vector3(-3.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0)), "the hall's crate")
	assert_true(g.clear_line(Vector3(-3.0, 3.0, 0.0), Vector3(3.0, 3.0, 0.0)), "over it, upstairs")


func test_routes_up_the_stair_to_the_upper_floor_and_through_the_hall_on_the_ground() -> void:
	var g := NavGrid.build(_two_storeys(), cfg, body)
	var path := PackedVector3Array()
	var yard_point := Vector3(-17.0, 0.0, 0.0)
	var upper := Vector3(-4.0, 3.0, 4.0)
	assert_true(g.find_route(yard_point, upper, path))
	_check_route(g, yard_point, upper, path)
	for p in path:
		assert_eq(p.y, g.floor_at(p), "%s on its floor" % p)
	assert_eq(path[path.size() - 1], upper)
	var hall := Vector3(3.0, 0.0, -2.0)
	assert_true(g.find_route(yard_point, hall, path))
	_check_route(g, yard_point, hall, path)
	for p in path:
		assert_eq(p.y, 0.0, "on the ground all the way")
	# From the upper floor to the far yard: back down the stair, not off an edge.
	var far := Vector3(17.0, 0.0, 0.0)
	assert_true(g.find_route(upper, far, path))
	_check_route(g, upper, far, path)
	assert_gt(_route_length(upper, path), 21.0 + 10.0, "round by the stair")


func test_snaps_a_body_on_the_depot_docks_lip_to_the_dock_not_the_road_below() -> void:
	# Its middle just past the open edge (z -13.2; browser G11, Depot seed 11): the road's walkable cells are nearer.
	var k := depot.nearest_walkable(Vector3(4.5, 1.2, -13.05), cfg.snap)
	assert_gte(k, 0)
	assert_almost_eq(depot.floor_y[k], 1.2, 1e-5)
	# Nothing at the dock's height in reach: the nearest floor below still counts.
	assert_eq(depot.floor_y[depot.nearest_walkable(Vector3(4.5, 1.2, -10.6), cfg.snap)], 0.0)


func test_walks_off_the_depot_dock_by_a_ramp_never_its_lip() -> void:
	var path := PackedVector3Array()
	var dock := Vector3(4.5, 1.2, -14.6)
	var road := Vector3(4.5, 0.0, -11.5)
	assert_true(depot.drop_on_line(dock, road), "straight off the lip is a drop")
	assert_true(depot.find_route(dock, road, path))
	_check_route(depot, dock, road, path)
	assert_gt(_route_length(dock, path), 9.0, "round by a ramp")


func test_depot_has_one_floor_a_cell_and_its_walkable_area_on_whole_cells() -> void:
	assert_eq(depot.layers, 1)
	assert_eq(depot.node_count(), 42075, "255 x 165 cells, one floor each")
	var walk := 0
	for k in depot.node_count():
		walk += depot.walkable[k]
	# The browser's grid had 27,380; the map's numbers are single precision here, which moves a few edge cells. DP1 adds
	# the Box's inside and the port walls, thinner than the gabions and walls they replaced: 27,363 became 27,593. SW2's
	# grid origin on whole cells moved this old Depot's cells half a cell (its corner is at -25.5 m), so the cells
	# beside its walls line up with them differently: 25,935, no longer the browser's figure (its cells started at the
	# corner). The shipped fields' corners are on whole cells, so their grids did not move.
	assert_almost_eq(walk, 25935, 50)


func test_the_grids_origin_sits_on_whole_cells_so_a_floor_moved_at_one_edge_never_shifts_the_rest() -> void:
	# SW2: Subway's wider running tunnels moved its outermost floor and every cell with it, which shut the way past
	# the works wagons at the other end of the field. A step 0.3 m out past the yard's north edge (to z -15.7).
	var step := _block(&"floor", Vector3(0.0, -0.25, -YARD_HALF - WALL - 0.15), Vector3(4.0, 0.5, 0.3))
	var g := NavGrid.build(_yard([step]), cfg, body)
	assert_almost_eq(yard.min_z, -YARD_HALF - WALL, 1e-6, "a corner on a whole cell is the origin")
	assert_almost_eq(g.min_z, -15.8, 1e-6, "the next whole cell below the step's edge, not the edge")
	assert_almost_eq(g.floor_min_z, -YARD_HALF - WALL - 0.3, 1e-6, "the floor's own corner kept")
	assert_eq(g.min_x, yard.min_x)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 300:
		var p := Vector3(rng.randf_range(-YARD_HALF, YARD_HALF), 0.0, rng.randf_range(-YARD_HALF + 1.0, YARD_HALF))
		assert_eq(g.is_walkable_at(p), yard.is_walkable_at(p), "the same cells at %s" % p)


func test_a_corner_a_hair_off_a_whole_cell_keeps_its_own_value_as_the_origin() -> void:
	var on := -66.4
	var noisy := -66.400002 # the Range's corner as the map's single-precision numbers give it
	assert_eq(NavGridBuilder._on_cells(noisy, 0.2), noisy, "single-precision noise: still on its cell")
	assert_eq(NavGridBuilder._on_cells(on, 0.2), on)
	assert_eq(NavGridBuilder._on_cells(-44.0, 0.2), -44.0)
	assert_almost_eq(NavGridBuilder._on_cells(-25.5, 0.2), -25.6, 1e-9, "off the lattice: the next whole cell below")
	assert_almost_eq(NavGridBuilder._on_cells(3.05, 0.2), 3.0, 1e-9, "a positive corner snaps down too")


func test_every_depot_spawn_reaches_every_dead_zone_spot_and_the_other_ends_spawns() -> void:
	var path := PackedVector3Array()
	for e in 2:
		var other := depot_map.ends[1 - e]
		var targets: Array[SpawnPoint] = []
		targets.append_array(depot_map.ends[0].dead_zone)
		targets.append_array(depot_map.ends[1].dead_zone)
		targets.append_array(other.spawns)
		for s in depot_map.ends[e].spawns:
			assert_true(depot.is_walkable_at(s.position), "spawn %s walkable" % s.position)
			for t in targets:
				assert_true(depot.find_route(s.position, t.position, path), "%s -> %s" % [s.position, t.position])
				_check_route(depot, s.position, t.position, path)


func test_route_legs_keep_a_body_radius_from_depot_blocks() -> void:
	var path := PackedVector3Array()
	# Two routes whose plain string-pulled legs passed a few millimetres inside the body in the browser, then a sweep.
	var pairs: Array[PackedFloat64Array] = [
		PackedFloat64Array([3.819315647622254, 9.523805991990404, -1.5377613993071748, 9.129878249079866]),
		PackedFloat64Array([-3.036300269438094, -4.436642778775022, 2.3016265818391126, -1.9000533627812057]),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	while pairs.size() < 150:
		var ax := rng.randf_range(-24.0, 24.0)
		var az := rng.randf_range(-15.0, 15.0)
		pairs.append(PackedFloat64Array([ax, az, ax + rng.randf_range(-6.0, 6.0), az + rng.randf_range(-6.0, 6.0)]))
	var r := cfg.clearance(body)
	var checked := 0
	for pair in pairs:
		var a := Vector3(pair[0], 0.0, pair[1])
		var b := Vector3(pair[2], 0.0, pair[3])
		if not depot.is_walkable_at(a) or not depot.is_walkable_at(b) or depot.floor_at(a) != 0.0 \
				or depot.floor_at(b) != 0.0:
			continue
		if not depot.find_route(a, b, path):
			continue
		var ground := true
		for p in path:
			ground = ground and p.y == 0.0
		# Ground routes with ends well clear of blocks, so any leg that comes close does so on the search's account.
		if not ground or _to_blocks(a.x, a.z) < r or _to_blocks(b.x, b.z) < r:
			continue
		var legs := PackedVector3Array([a])
		legs.append_array(path)
		assert_gte(_closest_approach(legs), body.radius, "%s -> %s" % [a, b])
		checked += 1
	assert_gt(checked, 40)


func test_random_walkable_near_draws_walkable_points_in_reach_from_its_stream() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var centre := Vector3(0.0, 0.0, -6.0)
	for i in 50:
		var p := yard.random_walkable_near(centre, 3.0, rng)
		assert_true(yard.is_walkable_at(p), "%s walkable" % p)
		assert_lte(Vector2(p.x - centre.x, p.z - centre.z).length(), 3.0 + 1e-4)
		assert_eq(p.y, 0.0, "on the floor")
	var one := RandomNumberGenerator.new()
	one.seed = 9
	var two := RandomNumberGenerator.new()
	two.seed = 9
	assert_eq(yard.random_walkable_near(centre, 5.0, one), yard.random_walkable_near(centre, 5.0, two), "seeded")
	var far := Vector3(100.0, 0.0, 100.0)
	assert_eq(yard.random_walkable_near(far, 1.0, rng), far, "nothing walkable in reach: the point itself")


## Distance on the ground from (x, z) to the nearest Depot block standing in a walker's way on the ground.
func _to_blocks(x: float, z: float) -> float:
	var m := INF
	for b in depot_map.blocks:
		if NavGridBuilder.is_surface(b):
			continue
		if b.center.y - b.size.y * 0.5 >= body.height * 0.5 or b.center.y + b.size.y * 0.5 <= body.max_step:
			continue
		var dx := maxf(absf(x - b.center.x) - b.size.x * 0.5, 0.0)
		var dz := maxf(absf(z - b.center.z) - b.size.z * 0.5, 0.0)
		m = minf(m, sqrt(dx * dx + dz * dz))
	return m


## The closest any leg of the polyline comes to a block.
func _closest_approach(points: PackedVector3Array) -> float:
	var m := INF
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		for s in 65:
			var t := s / 64.0
			m = minf(m, _to_blocks(a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t))
	return m
