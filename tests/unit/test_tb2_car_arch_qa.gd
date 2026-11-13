extends GutTest
## TB2 QA: a car standing under a running arch keeps standing room, stays walkable for bots, and leaves no overlap.

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _map() -> MapData:
	var m := MapData.load_map("subway", play.map_style, tuning.rounds.team_size)
	assert_true(m.ok(), "subway loads: %s" % [m.problems])
	return m


func _box(b: MapData.Block) -> AABB:
	return AABB(b.center - b.size * 0.5, b.size)


## The lowest solid ceiling over (x, z) above `y0`, or INF.
func _ceiling(m: MapData, x: float, z: float, y0: float) -> float:
	var best := INF
	for b in m.blocks:
		if b.kind == &"ramp":
			continue
		var a := _box(b)
		if x >= a.position.x and x <= a.end.x and z >= a.position.z and z <= a.end.z and a.end.y > y0 and a.position.y >= y0 - 0.001:
			best = minf(best, a.position.y)
	return best


## The top of the highest solid below `y_max` over (x, z): what a body stands on.
func _floor(m: MapData, x: float, z: float, y_max: float) -> float:
	var best := -INF
	for b in m.blocks:
		if b.kind == &"ramp":
			continue
		var a := _box(b)
		if x >= a.position.x and x <= a.end.x and z >= a.position.z and z <= a.end.z and a.end.y <= y_max + 0.001:
			best = maxf(best, a.end.y)
	return best


## Whether a solid block (not a ramp) holds `p`.
func _solid_at(m: MapData, p: Vector3) -> bool:
	for b in m.blocks:
		if b.kind != &"ramp" and _box(b).has_point(p):
			return true
	return false


func test_a_player_can_stand_in_a_car_under_the_arch_but_near_its_sides_only_crouched() -> void:
	var body := BodyConfig.new()
	var m := _map()
	var checked := 0
	var crouch_only := 0
	for x: float in [32.0, 40.0, 52.0, 55.0, 59.0]:
		for zi in 60:
			var z := 8.5 + zi * 0.1
			if m.station.style_at(Vector3(x, 1.5, z)) != &"train":
				continue
			var f := _floor(m, x, z, 1.2)
			if _solid_at(m, Vector3(x, f + 1.0, z)):
				continue   # inside the car's side (a window's glass, SM1): nobody stands there
			var head := _ceiling(m, x, z, f + 0.05) - f
			checked += 1
			assert_gte(head, body.crouch_height, "a crouched body fits in the car at x %.1f z %.1f (%.2f m)" % [x, z, head])
			if head < body.height:
				crouch_only += 1
	assert_gt(checked, 50, "the car has an inside")
	assert_lt(crouch_only, checked / 4, "most of the car's width is standing room")


func test_the_cars_roof_steps_leave_no_hole_for_a_bb_from_inside_to_the_tunnel() -> void:
	var m := _map()
	var holes := 0
	for x: float in [30.5, 36.0, 44.0, 49.9, 50.1, 54.0, 60.0, 66.0, 71.0, 81.5]:
		for zi in 60:
			var z := 8.5 + zi * 0.1
			if m.station.style_at(Vector3(x, 1.5, z)) != &"train":
				continue
			if is_inf(_ceiling(m, x, z, 1.0)):
				holes += 1
	assert_eq(holes, 0, "every column of the car's inside has a roof")


func test_no_two_solid_blocks_overlap_inside_the_south_car_s_tunnel() -> void:
	var m := _map()
	var solids: Array[AABB] = []
	for b in m.blocks:
		if b.kind != &"ramp":
			var a := _box(b)
			if a.end.x > 30.0 and a.position.x < 82.0 and a.position.z > 8.0 and a.end.z < 14.5 and a.position.y > 0.0:
				solids.append(a)
	var bad := 0
	for i in solids.size():
		for j in range(i + 1, solids.size()):
			var o := solids[i].intersection(solids[j])
			if o.size.x > 0.02 and o.size.y > 0.02 and o.size.z > 0.02:
				bad += 1
	assert_eq(bad, 0, "blocks that overlap by more than 2 cm each way (z-fighting colliders)")


func test_a_bot_walks_from_one_end_of_the_south_car_to_the_other_and_round_the_cab_steps() -> void:
	var m := _map()
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	var floor_y := _floor(m, 40.0, 11.0, 1.2)
	var path := PackedVector3Array()
	var ok := nav.find_route(Vector3(32.0, floor_y, 11.0), Vector3(58.0, floor_y, 11.0), path)
	assert_true(ok, "the car is walkable end to end")
	assert_true(nav.is_walkable_at(Vector3(34.0, floor_y, 11.0)) and nav.is_walkable_at(Vector3(58.0, floor_y, 11.0)), "both ends of the car")
	for r: Array in [["cab_steps", Vector3(61.0, 0.0, 10.8)]]:
		var q := Vector3(r[1])
		var c := nav.find_route(Vector3(40.0, floor_y, 11.0), q, path)
		assert_true(c or nav.nearest_walkable(q, 1.5) >= 0, "the cab steps room is reachable or snaps to walkable")
