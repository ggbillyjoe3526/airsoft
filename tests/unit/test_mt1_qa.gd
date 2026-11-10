extends GutTest
## MT1 QA: Subway loads clean and stays Dev-only; per-lamp heights, plain roofs and their light reach, floor_under on
## ramps and terrain, a scaled flag pole, and the area probes of a storeyed map against Depot's.

var play: PlayTuning = PlayTuning.load_default()
var cfg: RoofConfig = RoofConfig.new()


func _parse(text: String) -> MapData:
	return MapData.parse(text, MapStyle.new(), 1)


func _roofed(lamp: String, extra: String = "") -> MapData:
	return _parse('{"blocks": [], "spawns": [[], []], "deadZones": [[], []], "roof": {"height": 4.0%s, "lamps": [%s]}}'
			% [extra, lamp])


func test_subway_loads_without_problems_or_warnings() -> void:
	var m := MapData.load_map("subway", MapStyle.new(), 6)
	assert_eq(m.problems, [] as Array[String])
	assert_eq(m.warnings, [] as Array[String])
	assert_true(m.roof_plain, "a plain roof")
	assert_gt(m.pole_height, 0.0)
	assert_eq(m.roof_lamp_heights.size(), m.roof_lamps.size(), "a height per lamp")
	assert_gt(m.storeys.size(), 1)


func test_subway_is_dev_only() -> void:
	var cat := MapCatalog.shared()
	assert_true(cat.is_dev("subway"))
	var public_ids: Array[String] = []
	for e in cat.fields(false):
		public_ids.append(e.id)
	assert_false("subway" in public_ids)
	var dev_ids: Array[String] = []
	for e in cat.fields(true):
		dev_ids.append(e.id)
	assert_true("subway" in dev_ids)


func test_lamp_y_is_read_per_lamp() -> void:
	var m := _roofed('{"x": 0, "z": 0, "y": 2.5}, {"x": 1, "z": 1}')
	assert_eq(m.warnings, [] as Array[String])
	assert_eq(m.roof_lamp_heights, PackedFloat32Array([2.5, 4.0]))


func test_lamp_y_above_roof_warns_and_hangs_from_roof() -> void:
	var m := _roofed('{"x": 0, "z": 0, "y": 9.0}')
	assert_eq(m.roof_lamp_heights, PackedFloat32Array([4.0]))
	assert_eq(m.warnings.size(), 1)


func test_lamp_y_zero_or_negative_warns_and_hangs_from_roof() -> void:
	var m := _roofed('{"x": 0, "z": 0, "y": 0}, {"x": 1, "z": 0, "y": -3}')
	assert_eq(m.roof_lamp_heights, PackedFloat32Array([4.0, 4.0]))
	assert_eq(m.warnings.size(), 2)


func test_lamp_left_out_has_no_height_entry() -> void:
	var m := _roofed('{"x": 0}, {"x": 1, "z": 1, "y": 3}')
	assert_eq(m.roof_lamps.size(), 1)
	assert_eq(m.roof_lamp_heights, PackedFloat32Array([3.0]), "heights stay in step with lamps")


func test_plain_flag_defaults_false_and_non_bool_is_false() -> void:
	assert_false(_roofed("").roof_plain)
	assert_false(_roofed("", ', "plain": "yes"').roof_plain)
	assert_true(_roofed("", ', "plain": true').roof_plain)


func test_pole_height_negative_or_missing_is_zero() -> void:
	assert_eq(_parse('{"poleHeight": -2, "blocks": [], "spawns": [[], []], "deadZones": [[], []]}').pole_height, 0.0)
	assert_eq(_parse('{"blocks": [], "spawns": [[], []], "deadZones": [[], []]}').pole_height, 0.0)


func test_plain_reaches_is_empty_on_a_non_plain_roof() -> void:
	var m := MapData.load_map("depot", MapStyle.new(), 6)
	assert_false(m.roof_plain)
	var spots: Array[Vector3] = [Vector3(0, 5, 0)]
	assert_true(RoofView.plain_reaches(m, spots, cfg).is_empty())


func test_plain_reaches_stops_just_under_the_floor_below_the_lamp() -> void:
	var m := MapData.load_map("subway", MapStyle.new(), 6)
	var spots: Array[Vector3] = []
	for i in m.roof_lamps.size():
		spots.append(Vector3(m.roof_lamps[i].x, m.roof_lamp_heights[i] - cfg.plain_lamp_drop, m.roof_lamps[i].y))
	var reaches := RoofView.plain_reaches(m, spots, cfg)
	assert_eq(reaches.size(), spots.size())
	for i in spots.size():
		var under := m.floor_under(spots[i].x, spots[i].z, spots[i].y)
		if is_finite(under):
			assert_almost_eq(reaches[i], spots[i].y - under + cfg.plain_lamp_reach, 0.001)
		assert_gt(reaches[i], cfg.plain_lamp_reach - 0.001)


func test_plain_reaches_without_a_floor_falls_back_to_ground() -> void:
	var m := _roofed('{"x": 0, "z": 0}', ', "plain": true')
	var spots: Array[Vector3] = [Vector3(0, 3.0, 0)]
	var r := RoofView.plain_reaches(m, spots, cfg)
	assert_almost_eq(r[0], 3.0 + cfg.plain_lamp_reach, 0.001)


func test_plain_roof_lights_use_plain_energy_and_per_light_range() -> void:
	var m := _roofed('{"x": 0, "z": 0}, {"x": 3, "z": 0, "y": 2}', ', "plain": true')
	m.blocks.clear()
	var roof := RoofView.build(m, cfg)
	add_child_autofree(roof)
	var lights := roof.lamp_lights()
	assert_eq(lights.light_count(), 2)
	for s in lights.lights():
		assert_almost_eq(s.light_energy, cfg.plain_lamp_energy, 0.001)
	assert_lt(lights.light_of(1).spot_range, lights.light_of(0).spot_range, "the low lamp reaches less far")
	lights.set_flicker(0, 0.5)
	assert_almost_eq(lights.light_of(0).light_energy, cfg.plain_lamp_energy * 0.5, 0.001)


func test_non_plain_roof_lights_keep_the_hall_energy_and_range() -> void:
	var m := MapData.load_map("depot", MapStyle.new(), 6)
	var roof := RoofView.build(m, cfg)
	add_child_autofree(roof)
	var lights := roof.lamp_lights()
	for i in lights.lights().size():
		assert_eq(lights.lights()[i].spot_range, cfg.lamp_range)
	lights.set_flicker(lights.lights().size() - 1, 1.0)


func test_floor_under_picks_the_highest_surface_not_above_top() -> void:
	var m := MapData.load_map("subway", MapStyle.new(), 6)
	for x_z: Vector2 in [Vector2(-40, 0), Vector2(0, 0), Vector2(30, 3)]:
		var all := m.floor_top(x_z.x, x_z.y)
		assert_eq(m.floor_under(x_z.x, x_z.y, INF), all, "INF top is floor_top")
		var below := m.floor_under(x_z.x, x_z.y, all - 0.01)
		assert_true(below < all or all == -INF, "a lower top finds a lower floor or none")
	assert_eq(m.floor_under(0, 0, -INF), -INF, "nothing under -INF")


func test_floor_under_on_a_ramp_uses_the_ramp_height_at_the_point() -> void:
	var m := MapData.load_map("subway", MapStyle.new(), 6)
	var found := false
	for b in m.blocks:
		if b.kind == &"ramp" and b.rise != MapData.Rise.NONE:
			var x := b.center.x
			var z := b.center.z
			var y := m.ramp_top(b, x, z)
			assert_true(m.floor_under(x, z, y) >= y - 0.0001, "a ramp at its own height counts")
			found = true
			break
	if not found:
		pending("no ramp in Subway")


func test_floor_under_respects_terrain() -> void:
	var m := MapData.load_map("woodland", MapStyle.new(), 6)
	assert_not_null(m.terrain)
	var g := m.terrain.height_at(0.0, 0.0)
	assert_gte(m.floor_under(0.0, 0.0, g + 1.0), g)
	assert_lt(m.floor_under(0.0, 0.0, g - 5.0), g, "ground above top is not under it")
	assert_eq(m.floor_top(0.0, 0.0), m.floor_under(0.0, 0.0, INF))


func _flag(height: float, letter: String = "") -> FlagView:
	var v := FlagView.new()
	add_child_autofree(v)
	v.setup(FlagViewConfig.new(), TeamConfig.new(), Vector3.ZERO, 1.6, letter, height)
	return v


func test_flag_with_height_under_pole_scales_standing_and_the_letter() -> void:
	var full := FlagViewConfig.new().pole_height
	var v := _flag(full * 0.5, "A")
	assert_almost_eq((v.get_node("Standing") as Node3D).scale.y, 0.5, 0.0001)


func test_flag_height_zero_negative_or_too_tall_leaves_full_size() -> void:
	var full := FlagViewConfig.new().pole_height
	for h: float in [0.0, -1.0, full, full * 3.0]:
		var v := _flag(h)
		assert_eq((v.get_node("Standing") as Node3D).scale, Vector3.ONE, "height %s" % h)


func test_scaled_flag_letter_rides_lower() -> void:
	var full := FlagViewConfig.new().pole_height
	var small := _flag(full * 0.5, "A")
	var big := _flag(0.0, "A")
	var ls: Label3D = null
	var lb: Label3D = null
	for c in small.get_children():
		if c is Label3D:
			ls = c
	for c in big.get_children():
		if c is Label3D:
			lb = c
	assert_lt(ls.position.y, lb.position.y)


func test_depot_probe_count_is_whole_field_plus_its_areas() -> void:
	var depot := MapData.load_map("depot", MapStyle.new(), 6)
	assert_true(depot.storeys.is_empty())
	var probes := AreaProbes.build(depot, play.look)
	assert_eq(probes.get_child_count(),
			mini(1 + AreaProbes.boxes(depot, play.look).size(), play.look.probe_most))
	assert_eq(probes.get_child(0).name, &"Field0")
	probes.free()


func test_storeyed_map_has_no_field_probe_and_each_area_probe_spans_its_band() -> void:
	var m := MapData.load_map("subway", MapStyle.new(), 6)
	var probes := AreaProbes.build(m, play.look)
	var areas := AreaProbes.probed_areas(m, play.look)
	assert_gt(areas.size(), 0)
	assert_eq(probes.get_child_count(), mini(areas.size(), play.look.probe_most))
	for c in probes.get_children():
		assert_false(String(c.name).begins_with("Field"))
	for i in probes.get_child_count():
		var p := probes.get_child(i) as ReflectionProbe
		var a := areas[i]
		assert_true(p.interior)
		if is_finite(a.floor_from):
			assert_almost_eq(p.position.y - p.size.y * 0.5, a.floor_from, 0.01, "starts at the band's floor")
	probes.free()


func test_probed_areas_match_boxes_in_order() -> void:
	var m := MapData.load_map("subway", MapStyle.new(), 6)
	var boxes := AreaProbes.boxes(m, play.look)
	var areas := AreaProbes.probed_areas(m, play.look)
	assert_eq(boxes.size(), areas.size())


func test_storeyed_map_with_no_large_area_builds_an_empty_probe_set() -> void:
	var m := MapData.load_map("subway", MapStyle.new(), 6)
	m.areas.clear()
	var probes := AreaProbes.build(m, play.look)
	assert_eq(probes.get_child_count(), 0)
	probes.free()
