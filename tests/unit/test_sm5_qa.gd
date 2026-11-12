extends GutTest
## SM5 QA: the turn a roof lamp may name, Depot's lamps unchanged, the shared vertex shader's sheet only for printed
## materials, and a station with odd fixtures lists.

var play: PlayTuning = PlayTuning.load_default()


func _parse(roof_lamps: String) -> MapData:
	var text := '{"name":"t","size":{"x":10,"z":10},"roof":{"height":3,"plain":true,"lamps":%s}}' % roof_lamps
	return MapData.parse(text, play.map_style, 1)


func test_a_roof_lamp_s_turn_is_read_in_degrees_and_a_missing_or_bad_one_is_zero() -> void:
	var m := _parse('[{"x":1,"z":1,"turn":90},{"x":2,"z":2},{"x":3,"z":3,"turn":"left"}]')
	assert_eq(m.roof_lamp_turns.size(), m.roof_lamps.size(), "one turn per lamp")
	assert_almost_eq(m.roof_lamp_turns[0], PI / 2.0, 0.0001)
	assert_eq(m.roof_lamp_turns[1], 0.0)
	assert_eq(m.roof_lamp_turns[2], 0.0)


func test_a_lamp_left_out_keeps_the_turns_in_step_with_the_lamps() -> void:
	var m := _parse('[{"x":1,"turn":45},{"x":2,"z":2,"turn":30}]')
	assert_eq(m.roof_lamps.size(), 1)
	assert_eq(m.roof_lamp_turns.size(), 1)
	assert_almost_eq(m.roof_lamp_turns[0], deg_to_rad(30.0), 0.0001)


func test_depot_s_roof_lamps_hang_unturned_where_they_did() -> void:
	var m := MapData.load_map("depot", play.map_style, SimTuning.new().rounds.team_size)
	assert_gt(m.roof_lamps.size(), 0)
	for i in m.roof_lamps.size():
		assert_eq(m.roof_lamp_turns[i], 0.0, "depot lamp %d unturned" % i)
		var p := RoofView.lamp_place(m, play.roof, true, i, play.roof.lamp_drop)
		assert_eq(p.basis, Basis.IDENTITY, "depot lamp %d keeps an identity basis" % i)
		var at := RoofView.lamp_spot(m.roof_lamps[i], play.roof)
		assert_eq(p.origin, Vector3(at.x, m.roof_lamp_heights[i] - play.roof.lamp_drop, at.y))


func test_lamp_place_without_a_turn_entry_falls_back_to_unturned() -> void:
	var m := _parse('[{"x":1,"z":1,"turn":90}]')
	m.roof_lamp_turns = PackedFloat32Array()
	var p := RoofView.lamp_place(m, play.roof, false, 0, 0.08)
	assert_eq(p.basis, Basis.IDENTITY)


func test_only_the_printed_material_turns_the_sheet_on() -> void:
	var plain := LookMaterials.vertex_colour(0.7, 0.0)
	assert_ne(plain.get_shader_parameter(&"use_sheet"), true, "a vertex-colour material prints nothing")
	var sheet := PlaceholderTexture2D.new()
	var printed := LookMaterials.printed(sheet, 0.6, 0.5)
	assert_true(printed.get_shader_parameter(&"use_sheet") as bool)
	assert_eq(printed.shader, plain.shader, "one shared shader")


func test_a_fixtures_entry_that_is_not_a_list_gives_no_fixtures() -> void:
	for bad: Variant in ["x", 5, null, {"a": 1}]:
		var w: Array[String] = []
		var d := StationDressing.read({"station": {"fixtures": bad}}, w)
		assert_not_null(d)
		assert_eq(d.fixtures.size(), 0)
		var cfg := play.station_fixtures
		assert_eq(StationFixtures.placings(d, cfg).size(), 0)
	var empty := StationDressing.read({"station": {}}, [] as Array[String])
	assert_null(StationFixtures.build(MapData.new(), play.station_fixtures), "no station, no node")
	assert_eq(empty.fixtures.size(), 0)
