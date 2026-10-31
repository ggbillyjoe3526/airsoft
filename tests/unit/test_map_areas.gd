extends GutTest
## Named areas and storeys (MM1; the browser game's map/areas.test.ts and content/mapAreas.test.ts, CL1): area_at's
## rules, the shipped maps' areas read and named shortly, a malformed area warned of and left out, spots on Depot and on
## the test field TowerBlock by storey, area_at allocating nothing, and the minimap's numbers in play_tuning.tres. Every field's
## walkable cells in an area is the field rule field.areas (test_field_rules.gd).

var maps: Dictionary[String, MapData] = {}


func before_all() -> void:
	var tuning := SimTuning.load_default()
	for id: String in ["depot", "woodland", "range"]:
		maps[id] = MapData.load_map(id, MapStyle.new(), tuning.rounds.team_size if id != "range" else 1)
	maps["tower"] = TowerBlock.load_map(MapStyle.new(), tuning.rounds.team_size)


func after_all() -> void:
	maps.clear()


## Areas as the browser's test has them: Dock inside Yard, and a Roof with a floor band.
static func _sample() -> Array[MapAreas.Area]:
	var out: Array[MapAreas.Area] = []
	out.append(_area("Dock", 0, 10, 0, 10))
	out.append(_area("Yard", -20, 20, -20, 20))
	var roof := _area("Roof", 30, 40, 0, 10)
	roof.floor_from = 3.0
	roof.floor_to = 6.0
	out.append(roof)
	return out


static func _area(area_name: String, x0: float, x1: float, z0: float, z1: float) -> MapAreas.Area:
	var a := MapAreas.Area.new()
	a.name = area_name
	a.x0 = x0
	a.x1 = x1
	a.z0 = z0
	a.z1 = z1
	return a


func test_the_first_area_holding_the_point_wins_though_a_later_one_holds_it_too() -> void:
	var areas := _sample()
	assert_eq(MapAreas.area_at(areas, Vector3(5, 0, 5)), "Dock")
	var reversed := areas.duplicate()
	reversed.reverse()
	assert_eq(MapAreas.area_at(reversed, Vector3(5, 0, 5)), "Yard")
	assert_eq(MapAreas.area_at(areas, Vector3(15, 0, 5)), "Yard")


func test_a_box_holds_from_its_low_edge_to_just_short_of_its_high_edge_on_both_axes() -> void:
	var areas := _sample()
	assert_eq(MapAreas.area_at(areas, Vector3(0, 0, 0)), "Dock")
	assert_eq(MapAreas.area_at(areas, Vector3(10, 0, 5)), "Yard")
	assert_eq(MapAreas.area_at(areas, Vector3(5, 0, 10)), "Yard")


func test_a_floor_band_holds_from_its_low_end_to_just_short_of_its_high_end_and_no_band_any_height() -> void:
	var areas := _sample()
	assert_eq(MapAreas.area_at(areas, Vector3(35, 3, 5)), "Roof")
	assert_eq(MapAreas.area_at(areas, Vector3(35, 5.99, 5)), "Roof")
	assert_eq(MapAreas.area_at(areas, Vector3(35, 6, 5)), "")
	assert_eq(MapAreas.area_at(areas, Vector3(35, 2.99, 5)), "")
	assert_eq(MapAreas.area_at(areas, Vector3(5, 100, 5)), "Dock")


func test_is_empty_outside_every_area_and_with_none() -> void:
	assert_eq(MapAreas.area_at(_sample(), Vector3(50, 0, 50)), "")
	assert_eq(MapAreas.area_at([] as Array[MapAreas.Area], Vector3.ZERO), "")


func test_the_fields_load_their_areas_each_named_shortly_and_the_range_none() -> void:
	var counts: Dictionary[String, int] = {"depot": 37, "woodland": 244, "range": 0}
	for id: String in counts:
		var m := maps[id]
		assert_true(m.ok(), "%s: %s" % [id, m.problems])
		assert_eq(m.warnings, [] as Array[String], id)
		assert_eq(m.areas.size(), counts[id], id)
		for a in m.areas:
			assert_false(a.name.strip_edges().is_empty(), id)
			assert_lte(a.name.length(), MapAreas.NAME_MAX_LENGTH, a.name)


func test_a_field_in_storeys_has_them_and_the_shipped_maps_none() -> void:
	assert_eq(maps["tower"].storeys, PackedFloat64Array([0.0, 3.0, 6.0]))
	for id: String in ["depot", "woodland", "range"]:
		assert_true(maps[id].storeys.is_empty(), id)


func test_a_malformed_area_or_storey_is_warned_of_by_name_and_left_out_never_refusing_the_map() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MapData.DIR + "depot.json"))
	d["areas"] = [
		{"name": "Good", "box": [0, 1, 0, 1], "floor": [0, 2]},
		{"name": "  ", "box": [0, 1, 0, 1]},
		{"name": "x".repeat(MapAreas.NAME_MAX_LENGTH + 1), "box": [0, 1, 0, 1]},
		{"name": "x".repeat(MapAreas.NAME_MAX_LENGTH), "box": [0, 1, 0, 1]},
		{"name": "Backwards X", "box": [5, -5, 0, 1]},
		{"name": "Backwards Z", "box": [0, 1, 5, -5]},
		{"name": "Flat", "box": [0, 0, 0, 1]},
		{"name": "Upside down", "box": [0, 1, 0, 1], "floor": [4, 1]},
		{"name": "Short box", "box": [0, 1, 0]},
		{"name": "Word box", "box": [0, 1, "a", 2]},
		{"name": "Odd band", "box": [0, 1, 0, 1], "floor": 3},
		"Loose",
	]
	d["storeys"] = [0, "upstairs", 3, 2]
	var m := MapData.parse(JSON.stringify(d), MapStyle.new(), SimTuning.load_default().rounds.team_size)
	assert_true(m.ok(), str(m.problems))
	var kept: Array[String] = []
	for a in m.areas:
		kept.append(a.name)
	assert_eq(kept, ["Good", "x".repeat(MapAreas.NAME_MAX_LENGTH)] as Array[String])
	assert_eq(m.warnings.size(), 12, str(m.warnings))
	var named: Array[String] = ["area 1 (  )", "area 2 (%s)" % "x".repeat(MapAreas.NAME_MAX_LENGTH + 1),
			"Backwards X", "Backwards Z", "Flat", "Upside down", "Short box", "Word box", "Odd band", "area 11"]
	for i in named.size():
		if i < m.warnings.size():
			assert_string_contains(m.warnings[i], named[i])
	assert_eq(m.storeys, PackedFloat64Array([0.0, 3.0]))
	var not_list := MapData.parse(JSON.stringify({"areas": "everywhere", "storeys": 3}), MapStyle.new(), 1)
	assert_eq(not_list.warnings, ["areas is not a list", "storeys is not a list"] as Array[String])


func test_spots_on_depot_are_named_as_players_call_them() -> void:
	var m := maps["depot"]
	var spots: Dictionary[String, Vector2] = {
		"Chrono hall": Vector2(8, 0), "A site": Vector2(42, -30), "West tunnel": Vector2(-29.5, 5),
		"Box yard": Vector2(0, 16), "Lounge": Vector2(0, -25), "Loading bay": Vector2(49, 4),
		"Staging": Vector2(-49, -4), "B site": Vector2(44, 28),
	}
	for want: String in spots:
		var at := spots[want]
		var feet := Vector3(at.x, m.floor_top(at.x, at.y), at.y)
		assert_eq(MapAreas.area_at(m.areas, feet), want, str(feet))


func test_a_field_in_storeys_names_one_spot_by_its_storey() -> void:
	var m := maps["tower"]
	var names: Array[String] = ["Atrium", "Tower Level 1", "Tower Level 2"]
	for s in m.storeys.size():
		assert_eq(MapAreas.area_at(m.areas, Vector3(10, m.storeys[s], 0)), names[s], "storey %d" % s)
	assert_eq(MapAreas.area_at(m.areas, Vector3(0, m.storeys[2], 7)), "Sky Bridge")
	assert_eq(MapAreas.area_at(m.areas, Vector3(0, m.storeys[0], 7)), "Avenue")


func test_area_at_allocates_nothing() -> void:
	var m := maps["tower"]
	var p := Vector3(10, 3, 0)
	MapAreas.area_at(m.areas, p)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var found := 0
	for i in 10000:
		p.y = float(i % 9)
		if not MapAreas.area_at(m.areas, p).is_empty():
			found += 1
	var objects_after := Performance.get_monitor(Performance.OBJECT_COUNT)
	var memory_after := Performance.get_monitor(Performance.MEMORY_STATIC)
	assert_eq(found, 10000, "every height there is named")
	assert_eq(objects_after, objects, "objects")
	assert_eq(memory_after, memory, "memory")


func test_the_play_tuning_holds_the_minimap_numbers() -> void:
	var cfg := PlayTuning.load_default().minimap
	assert_not_null(cfg, "play_tuning.tres writes the minimap out")
	if cfg != null:
		assert_eq([cfg.size, cfg.view_radius, cfg.layer_scale], [200.0, 20.0, 10.0])
		assert_eq([cfg.step_reach, cfg.shot_reach, cfg.patch_life, cfg.patch_fade], [22.0, 60.0, 5.0, 2.0])
		assert_eq([cfg.storey_pick, cfg.storey_cut], [0.5, 1.8])
