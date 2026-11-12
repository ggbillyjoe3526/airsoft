extends GutTest
## SD2 QA: StationDetail edge cases: no station, walls, doorways, fixtures, teardown and the tuning round-trip.

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _subway() -> MapData:
	return MapData.load_map("subway", play.map_style, tuning.rounds.team_size)


func _verts(mesh: ArrayMesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		out.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	return out


func _solids(m: MapData) -> Array[AABB]:
	var out: Array[AABB] = []
	for b in m.blocks:
		if play.station_detail.solid_kinds.has(b.kind) and b.dress == &"":
			out.append(AABB(b.center - b.size * 0.5, b.size))
	return out


func test_null_inputs_and_a_map_without_a_station_build_nothing() -> void:
	assert_null(StationDetail.build(null, play.station_detail), "null map")
	assert_null(StationDetail.build(_subway(), null), "null config")
	var m := _subway()
	m.station = null
	assert_null(StationDetail.build(m, play.station_detail), "no station")


func test_a_config_that_fits_no_room_builds_nothing() -> void:
	var cfg := StationDetailConfig.new()
	cfg.rooms = [] as Array[StringName]
	assert_null(StationDetail.build(_subway(), cfg), "no styles fitted")
	var big := StationDetailConfig.new()
	big.min_room = 1000.0
	assert_null(StationDetail.build(_subway(), big), "every room too small")


func test_degenerate_settings_do_not_hang_or_error() -> void:
	var cfg := StationDetailConfig.new()
	cfg.step = 0.05
	cfg.hatch_pitch = 0.5
	var d := StationDetail.build(_subway(), cfg)
	if d != null:
		add_child_autofree(d)
		assert_gt(_verts(d.mesh()).size(), 0)
	pass_test("built without error")


func test_vertices_in_halls_and_passages_never_enter_the_signs_band() -> void:
	# Stricter than the 'centroid' check: no vertex strictly inside the band, so a pipe or conduit cannot clip it.
	var m := _subway()
	var cfg := play.station_detail
	var d := StationDetail.build(m, cfg)
	add_child_autofree(d)
	var bad := 0
	for v: Vector3 in _verts(d.mesh()):
		for z in m.station.zones:
			if (z.style == &"hall" or z.style == &"passage") and z.box.grow(-0.001).has_point(v):
				var over := v.y - (z.box.position.y + cfg.zone_under)
				if over > 0.86 and over < 2.34:
					bad += 1
					break
	assert_eq(bad, 0, "vertices inside the 0.85..2.35 band of a hall or passage")


func test_fittings_do_not_sink_into_walls_or_stand_in_a_walkway() -> void:
	# Every vertex is in a room's air or within a hair of a solid's face: none deep inside a solid.
	var m := _subway()
	var d := StationDetail.build(m, play.station_detail)
	add_child_autofree(d)
	var solids := _solids(m)
	var deep := 0
	var samples: Array[Vector3] = []
	for v: Vector3 in _verts(d.mesh()):
		for s in solids:
			var k := minf(0.06, minf(s.size.x, minf(s.size.y, s.size.z)) * 0.4)
			if s.grow(-k).has_point(v):
				deep += 1
				if samples.size() < 6:
					samples.append(v)
				break
	assert_eq(deep, 0, "vertices buried more than 6 cm in a wall, pillar or floor block, e.g. %s" % [samples])


func test_every_door_stands_against_a_wall_across_its_whole_leaf() -> void:
	# A door in a doorway would hang over air: wall just behind the leaf at low, mid and high points.
	var m := _subway()
	var cfg := play.station_detail
	var d := StationDetail.build(m, cfg)
	add_child_autofree(d)
	var solids := _solids(m)
	for p in d.doors():
		var walled := 0
		var dirs: Array[Vector3] = [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
		for dir: Vector3 in dirs:
			var along: Vector3 = dir.cross(Vector3.UP)
			var all := true
			for u: float in [-0.45, -0.2, 0.0, 0.2, 0.45]:
				for h: float in [0.3, 1.0, 2.0]:
					var q: Vector3 = p + along * u + Vector3.UP * h + dir * 0.06
					var hit := false
					for s in solids:
						if s.has_point(q):
							hit = true
							break
					all = all and hit
			if all:
				walled += 1
		assert_gt(walled, 0, "door at %s has wall behind its whole leaf" % [p])


func test_vents_keep_clear_of_fixtures() -> void:
	var m := _subway()
	var cfg := play.station_detail
	var d := StationDetail.build(m, cfg)
	add_child_autofree(d)
	var arr := d.mesh().surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var bad := 0
	for i in vs.size():
		if cs[i].is_equal_approx(cfg.vent_colour):
			for f in m.station.fixtures:
				if vs[i].distance_to(f.position) < cfg.fixture_clear * 0.5:
					bad += 1
	assert_eq(bad, 0, "vent frame vertices within half the clearance of a fixture")


func test_build_is_deterministic() -> void:
	var a := StationDetail.build(_subway(), play.station_detail)
	var b := StationDetail.build(_subway(), play.station_detail)
	add_child_autofree(a)
	add_child_autofree(b)
	assert_eq(_verts(a.mesh()).size(), _verts(b.mesh()).size())
	assert_eq(a.doors(), b.doors())


func test_freeing_the_fittings_releases_mesh_and_material() -> void:
	var d := StationDetail.build(_subway(), play.station_detail)
	add_child(d)
	var mesh: WeakRef = weakref(d.mesh())
	var mat: WeakRef = weakref(d.materials()[0])
	assert_not_null(mesh.get_ref())
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	remove_child(d)
	d.free()
	await wait_physics_frames(2)
	assert_null(mesh.get_ref(), "mesh freed")
	assert_null(mat.get_ref(), "material freed")
	assert_lt(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "nodes released")


func test_repeated_builds_leave_no_orphans() -> void:
	var m := _subway()
	var base := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 3:
		var d := StationDetail.build(m, play.station_detail)
		d.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), base, "no orphan nodes")


func test_station_detail_survives_a_tres_round_trip() -> void:
	assert_not_null(play.station_detail, "play_tuning.tres carries it")
	var fresh := StationDetailConfig.new()
	assert_eq(play.station_detail.door, fresh.door)
	assert_eq(play.station_detail.rooms, fresh.rooms)
	var path := "user://qa_sd2_tuning.tres"
	assert_eq(ResourceSaver.save(play.station_detail, path), OK)
	var back := load(path) as StationDetailConfig
	assert_not_null(back)
	assert_eq(back.pipe_colours, fresh.pipe_colours)
	assert_eq(back.plant_pipes, fresh.plant_pipes)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
