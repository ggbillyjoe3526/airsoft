extends GutTest
## TQ2 QA: edge cases of the lamp `floor`, the entrance's clearance and TrainView's cleanup.

var play: PlayTuning = PlayTuning.load_default()
var cfg: RoofConfig = RoofConfig.new()


func _parse(lamps: String) -> MapData:
	return MapData.parse('{"blocks": [], "spawns": [[], []], "deadZones": [[], []], "roof": {"height": 4.0, '
			+ '"plain": true, "lamps": %s}}' % lamps, MapStyle.new(), 1)


func test_a_non_number_floor_reads_as_none() -> void:
	var m := _parse('[{"x": 0, "z": 0, "floor": "low"}, {"x": 1, "z": 1, "floor": null}]')
	assert_eq(m.roof_lamp_floors.size(), 2)
	assert_true(is_nan(m.roof_lamp_floors[0]))
	assert_true(is_nan(m.roof_lamp_floors[1]))


func test_a_skipped_lamp_keeps_floors_in_step_with_lamps() -> void:
	var m := _parse('[{"x": 0, "z": 0, "floor": 1.0}, {"z": 5, "floor": 9.0}, {"x": 2, "z": 2, "floor": 2.0}]')
	assert_eq(m.roof_lamps.size(), 2)
	assert_eq(m.roof_lamp_floors.size(), 2, "the lamp left out leaves no floor behind")
	assert_almost_eq(m.roof_lamp_floors[1], 2.0, 0.001)


func test_a_floor_above_its_lamp_never_gives_a_negative_reach() -> void:
	var m := _parse('[{"x": 0, "z": 0, "y": 3.0, "floor": 3.5}]')
	var spots: Array[Vector3] = [Vector3(0, 3.0, 0)]
	var r := RoofView.plain_reaches(m, spots, cfg)
	assert_gt(r[0], 0.0, "a light's range is never negative")


func test_the_entrance_block_covers_no_spawn_flag_or_site() -> void:
	var m := MapData.load_map("subway", MapStyle.new(), 6)
	var box := AABB()
	for b in m.blocks:
		if b.dress == &"station_entrance":
			box = AABB(b.center - b.size / 2.0, b.size)
	assert_gt(box.size.x, 0.0)
	for end: MapEnd in m.ends:
		for s: SpawnPoint in end.spawns + end.dead_zone:
			assert_false(box.grow(0.5).has_point(s.position), "spawn %s" % [s.position])
	for p: Vector3 in m.poles + m.bomb_sites:
		assert_false(box.has_point(p), "flag or site %s" % [p])


func test_a_trainview_leaves_no_orphans_when_freed() -> void:
	var m := MapData.load_map("subway", play.map_style, 6)
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var view := TrainView.build(m, play.station_look.trains)
	add_child(view)
	view.free()
	await wait_physics_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)
