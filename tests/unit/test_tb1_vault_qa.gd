extends GutTest
## TB1 QA: the platform tunnels vaults leave no gap behind the drawn arc at any x, and the air under the crown stays open.


var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _held(m: MapData, p: Vector3) -> bool:
	for b in m.blocks:
		if b.kind != &"ramp" and AABB(b.center - b.size * 0.5, b.size).grow(0.001).has_point(p):
			return true
	return false


func _map() -> MapData:
	var m := MapData.load_map("subway", play.map_style, tuning.rounds.team_size)
	assert_true(m.ok(), "subway loads: %s" % [m.problems])
	return m


func test_no_gap_behind_the_arc_along_the_whole_tunnel() -> void:
	var m := _map()
	assert_eq(m.station.vaults.size(), 2, "both platform tunnels are vaulted")
	for v in m.station.vaults:
		var c := v.circle()
		var x := v.area.position.x + 0.05
		while x < v.area.end.x:
			for k in range(1, 20):
				var a := v.half_angle() * (-1.0 + 2.0 * float(k) / 20.0)
				var p := Vector3(x, c.y + (c.z + 0.02) * cos(a), c.x + (c.z + 0.02) * sin(a))
				if not _held(m, p):
					fail_test("gap behind the arc at %s" % p)
					return
			x += 3.7
	pass_test("no gap")


func test_the_air_under_the_crown_is_open() -> void:
	var m := _map()
	assert_eq(m.station.vaults.size(), 2, "both platform tunnels are vaulted")
	for v in m.station.vaults:
		var x := v.area.get_center().x
		# the middle of the tunnel under the arc, between the car roof and the crown, holds no collider
		for dz: float in [-0.5, 0.0, 0.5]:
			var p := Vector3(x, v.y + v.rise * 0.5, v.area.get_center().y + dz)
			assert_false(_held(m, p), "open air under the crown at %s" % p)
