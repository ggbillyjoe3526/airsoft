extends GutTest
## SD2: a station's small fittings (StationDetail): built on Subway, none on a field without a station, clear of the
## signs' band and the lamps, off the teams' hues, and look only.

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _subway() -> MapData:
	var m := MapData.load_map("subway", play.map_style, tuning.rounds.team_size)
	assert_true(m.ok(), "Subway loads: %s" % [m.problems])
	return m


func _triangles(mesh: ArrayMesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		out.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	return out


func test_subway_is_fitted_out_and_depot_is_not() -> void:
	var d := StationDetail.build(_subway(), play.station_detail)
	assert_not_null(d, "Subway's rooms are fitted")
	add_child_autofree(d)
	var tris := _triangles(d.mesh()).size() / 3
	assert_between(tris, 2000, 80000, "a few thousand boxes, one mesh (%d triangles)" % tris)
	assert_eq(d.get_child_count(), 1, "one draw")
	assert_false(d.find_children("*", "CollisionObject3D", true, false).size() > 0, "look only: no collider")
	var depot := MapData.load_map("depot", play.map_style, tuning.rounds.team_size)
	assert_null(StationDetail.build(depot, play.station_detail), "a field without a station has none")


func test_each_plant_room_has_a_service_door() -> void:
	var m := _subway()
	var d := StationDetail.build(m, play.station_detail)
	add_child_autofree(d)
	var plant := 0
	for z in m.station.zones:
		if play.station_detail.door_rooms.has(z.style) \
				and minf(z.box.size.x, z.box.size.z) >= play.station_detail.door_room_min:
			plant += 1
	assert_gt(d.doors().size(), 0, "service doors laid")
	assert_true(d.doors().size() <= plant, "at most one a plant room")
	for p in d.doors():
		var z := m.station.zone_at(p + Vector3(0.0, 1.0, 0.0))
		assert_not_null(z, "a door stands on a room's wall")


func test_nothing_in_the_signs_band_of_a_hall_or_passage() -> void:
	# SM5's posters and signs hang 0.85 to 2.35 m over the floor: no fitting but a plant room's door stands there.
	var m := _subway()
	var cfg := play.station_detail
	var d := StationDetail.build(m, cfg)
	add_child_autofree(d)
	var v := _triangles(d.mesh())
	var bad := 0
	for i in range(0, v.size(), 3):
		var c := (v[i] + v[i + 1] + v[i + 2]) / 3.0
		var z := m.station.zone_at(c)
		if z == null or not (z.style == &"hall" or z.style == &"passage"):
			continue
		var over := c.y - (z.box.position.y + cfg.zone_under)
		var hi := maxf(v[i].y, maxf(v[i + 1].y, v[i + 2].y)) - (z.box.position.y + cfg.zone_under)
		var lo := minf(v[i].y, minf(v[i + 1].y, v[i + 2].y)) - (z.box.position.y + cfg.zone_under)
		if lo > 0.85 and hi < 2.35 and over > 0.85:
			bad += 1
	assert_eq(bad, 0, "the signs' band is clear in the halls and passages")


func test_no_hatch_under_a_lamp() -> void:
	var m := _subway()
	var cfg := play.station_detail
	var d := StationDetail.build(m, cfg)
	add_child_autofree(d)
	var v := _triangles(d.mesh())
	var near := 0
	for i in range(0, v.size(), 3):
		var c := (v[i] + v[i + 1] + v[i + 2]) / 3.0
		for k in m.roof_lamps.size():
			if absf(m.roof_lamp_heights[k] - c.y) < 0.03 and m.roof_lamps[k].distance_to(Vector2(c.x, c.z)) \
					< cfg.lamp_clear - cfg.hatch:
				near += 1
	assert_eq(near, 0, "the lamps' spots on the ceilings stay clear")


func test_no_fitting_reads_as_a_team() -> void:
	var teams: Array[Color] = AccessibilityTable.read_file().colours
	teams.append_array(play.teams.colours)
	var cfg := play.station_detail
	var colours: Array[Color] = [cfg.skirting_colour, cfg.band_colour, cfg.conduit_colour, cfg.clip_colour,
			cfg.bracket_colour, cfg.vent_colour, cfg.louvre_colour, cfg.hatch_colour, cfg.seam_colour,
			cfg.drain_colour, cfg.door_colour, cfg.frame_colour, cfg.handle_colour, cfg.plate_colour]
	colours.append_array(cfg.pipe_colours)
	for c in colours:
		assert_false(FieldChecks.reads_as_team(c, teams), "#%s is off the teams' hues" % c.to_html(false))


func test_doors_keep_clear_of_the_fixtures() -> void:
	# SM5's signs, posters and clocks hang on the same walls: a service door never stands over one.
	var m := _subway()
	var cfg := play.station_detail
	var d := StationDetail.build(m, cfg)
	add_child_autofree(d)
	for p in d.doors():
		for f in m.station.fixtures:
			var flat := Vector2(f.position.x - p.x, f.position.z - p.z).length()
			var over := f.position.y - p.y
			assert_false(flat < cfg.door.x * 0.5 + cfg.fixture_clear * 0.5 and over > -0.1 and over < cfg.door.y,
					"door at %s clear of %s" % [p, f.model])
