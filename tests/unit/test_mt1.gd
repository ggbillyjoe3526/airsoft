extends GutTest
## MT1: Kingsmere's low poles keep their letters under the ceiling over them (critic, attempt 1).


## The underside of the lowest block over (x, z) above `over` (m), INF with none.
func _ceiling(map: MapData, x: float, z: float, over: float) -> float:
	var low := INF
	for b in map.blocks:
		var lo := b.center - b.size * 0.5
		var hi := b.center + b.size * 0.5
		if x >= lo.x and x <= hi.x and z >= lo.z and z <= hi.z and lo.y > over:
			low = minf(low, lo.y)
	return low


func test_every_kingsmere_letter_stands_under_the_ceiling_over_its_pole() -> void:
	var map := MapData.load_map("kingsmere", MapStyle.new(), 6)
	assert_eq(map.poles.size(), 2, "A and B")
	var cfg := FlagViewConfig.new()
	for i in map.poles.size():
		var foot: Vector3 = map.poles[i]
		var v := FlagView.new()
		add_child_autofree(v)
		v.setup(cfg, TeamConfig.new(), foot, 1.6, "AB"[i], map.pole_height)
		var top := foot.y + v.letter_height() + v.letter_size() * 0.5
		var ceiling := _ceiling(map, foot.x, foot.z, foot.y + 1.0)
		assert_lt(top, ceiling, "%s's letter top %.2f m under the ceiling at %.2f m" % ["AB"[i], top, ceiling])
		assert_gt(v.letter_height(), map.pole_height * 0.9, "%s's letter still at its pole's top" % "AB"[i])


func test_a_full_height_pole_keeps_its_letter_over_the_top() -> void:
	var cfg := FlagViewConfig.new()
	var v := FlagView.new()
	add_child_autofree(v)
	v.setup(cfg, TeamConfig.new(), Vector3.ZERO, 1.6, "A")
	assert_almost_eq(v.letter_height(), cfg.pole_height + cfg.letter_rise, 0.0001, "Depot and Woodland as before")
	assert_almost_eq(v.letter_size(), cfg.letter_size * cfg.letter_pixel, 0.0001)
