extends GutTest
## TB1 QA: the platform tunnels vaults leave no gap behind the drawn arc at any x, and the air under the crown stays open.


var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _held(m: MapData, p: Vector3) -> bool:
	for b in m.blocks:
		if b.kind != &"ramp" and AABB(b.center - b.size * 0.5, b.size).grow(0.001).has_point(p):
			return true
	return false


## Whether a collider that is not a train's own shell holds `p`.
func _held_by_scenery(m: MapData, p: Vector3) -> bool:
	for b in m.blocks:
		if b.kind != &"ramp" and m.station.owner_of(b) != &"train" \
				and AABB(b.center - b.size * 0.5, b.size).grow(0.001).has_point(p):
			return true
	return false


func _map() -> MapData:
	var m := MapData.load_map("subway", play.map_style, tuning.rounds.team_size)
	assert_true(m.ok(), "subway loads: %s" % [m.problems])
	return m


func test_no_gap_behind_the_arc_along_the_whole_tunnel() -> void:
	var m := _map()
	assert_eq(m.station.vaults.size(), 4, "both platform tunnels and both running tunnels are vaulted")
	for v in m.station.vaults:
		var c := v.circle()
		var x := v.area.position.x + 0.05
		while x < v.area.end.x:
			for k in range(1, 20):
				var a := v.half_angle() * (-1.0 + 2.0 * float(k) / 20.0)
				var p := Vector3(x, c.y + (c.z + 0.02) * cos(a), c.x + (c.z + 0.02) * sin(a))
				# a car standing in a running tunnel: its own shell holds its corners, under the arch (TB2)
				if not _held(m, p) and m.station.style_at(p) != &"train":
					fail_test("gap behind the arc at %s" % p)
					return
			x += 3.7
	pass_test("no gap")


func test_the_air_under_the_crown_is_open() -> void:
	var m := _map()
	assert_eq(m.station.vaults.size(), 4, "both platform tunnels and both running tunnels are vaulted")
	for v in m.station.vaults:
		var x := v.area.get_center().x
		# the middle of the tunnel under the arc, between the car roof and the crown, holds no collider
		for dz: float in [-0.5, 0.0, 0.5]:
			var p := Vector3(x, v.y + v.rise * 0.5, v.area.get_center().y + dz)
			assert_false(_held(m, p), "open air under the crown at %s" % p)


## TB2 QA: the running tunnels' arches (x 50 to 82) and their mouths onto the platform tunnels.
func _running(m: MapData) -> Array[StationDressing.TunnelVault]:
	var out: Array[StationDressing.TunnelVault] = []
	for v in m.station.vaults:
		if v.open_west:
			out.append(v)
	return out


func test_no_collider_stands_more_than_8_cm_proud_of_a_running_arch_at_any_x() -> void:
	var m := _map()
	var runs := _running(m)
	assert_eq(runs.size(), 2, "both running tunnels open west")
	for v in runs:
		var c := v.circle()
		var lid := v.lid()
		for b in m.blocks:
			var box := AABB(b.center - b.size * 0.5, b.size)
			if b.kind == &"ramp" or not lid.encloses(box) or box.size.x < 0.5 or box.end.x < v.area.position.x or box.position.x > v.area.end.x:
				continue
			var near := Vector2(clampf(c.x, box.position.z, box.end.z), clampf(c.y, box.position.y, box.end.y))
			assert_gt(near.distance_to(Vector2(c.x, c.y)), c.z - 0.09, "arch collider within 8 cm of the arc: %s" % box)


func test_the_running_arch_air_is_open_along_its_whole_length() -> void:
	var m := _map()
	for v in _running(m):
		var c := v.circle()
		var x := v.area.position.x + 0.05
		while x < v.area.end.x:
			for k in range(-8, 9):
				var a := v.half_angle() * float(k) / 9.0
				var p := Vector3(x, c.y + (c.z - 0.1) * cos(a), c.x + (c.z - 0.1) * sin(a))
				assert_false(_held(m, p) and m.station.style_at(p) != &"train", "air 10 cm under the arc at %s" % p)
			x += 1.9


func test_the_junction_at_x_50_has_no_hole_and_no_block_in_the_air() -> void:
	var m := _map()
	for v in _running(m):
		var c := v.circle()
		for dx: float in [-0.3, -0.05, 0.05, 0.3]:
			# air in the middle of the opening is open on both sides of the seam
			var q := Vector3(50.0 + dx, v.y + v.rise * 0.8, c.x)
			assert_false(_held_by_scenery(m, q), "open air across the seam, dx %.2f" % dx)
		# the arc itself is sealed on the running side, right at the seam
		for k in range(1, 12):
			var a := v.half_angle() * (-1.0 + 2.0 * float(k) / 12.0)
			var p := Vector3(50.03, c.y + (c.z + 0.02) * cos(a), c.x + (c.z + 0.02) * sin(a))
			assert_true(_held(m, p) or m.station.style_at(p) == &"train", "no BB slips past the arc at the seam %s" % p)


func test_running_arch_has_no_end_cap_at_its_open_west_and_one_at_the_east() -> void:
	var m := _map()
	for v in _running(m):
		var z := v.area.get_center().y
		var y := v.y + v.rise * 0.9
		assert_false(_held(m, Vector3(49.99, y, z)), "mouth open at x 50")
		assert_true(_held(m, Vector3(82.02, y + 0.05, z + 0.0)) or _held(m, Vector3(82.02, y, z)), "closed at the east end")


func test_xpass_mouth_into_each_running_tunnel_stays_walkable() -> void:
	var m := _map()
	# the cross passage (x 74-77, 2.6 m high) meets each running tunnel at z = +-9: floor and head room both there
	for sz: float in [-1.0, 1.0]:
		for z: float in [8.0, 8.9, 9.1, 10.0]:
			var zz := z * sz
			assert_false(_held(m, Vector3(75.5, -18.9 + 1.0, zz)), "a body walks through z %.1f" % zz)
			assert_false(_held(m, Vector3(75.5, -18.9 + 2.3, zz)), "head clear at z %.1f" % zz)
