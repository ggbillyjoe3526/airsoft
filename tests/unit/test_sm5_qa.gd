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


# ---- the sign sheet at 2048 x 2048, the 13 posters and the 3 wide ones ----

const SHEET := Vector2(2048.0, 2048.0)
const POSTER_CELL := Vector2(336.0, 504.0)
const WIDE_CELL := Vector2(672.0, 336.0)
const POSTER_KEYS := "abcdefghijklm"
const WIDE_KEYS := "abc"
const EDGE_IN := 0.7

var cfg: StationFixturesConfig = play.station_fixtures


## station_cells.py's CELLS, by model name (x, y, w, h in px). way_sign prints two cells side by side.
func _cell(model: String) -> Rect2:
	if model.begins_with("poster_wide_"):
		return Rect2(Vector2(WIDE_KEYS.find(model.right(1)) * WIDE_CELL.x, 1536.0), WIDE_CELL)
	if model.begins_with("poster_"):
		var i := POSTER_KEYS.find(model.right(1))
		if i == 12:
			return Rect2(Vector2(1536.0, 1008.0), POSTER_CELL)
		return Rect2(Vector2((i % 6) * POSTER_CELL.x, (i / 6) * POSTER_CELL.y), POSTER_CELL)
	match model:
		"name_board": return Rect2(0, 1008, 1024, 160)
		"edge_sign": return Rect2(0, 1168, 1024, 128)
		"platform_clock": return Rect2(1024, 1008, 512, 512)
		"way_sign": return Rect2(0, 1296, 1024, 112)
	return Rect2()


func _sign_uvs(mesh: Mesh) -> PackedVector2Array:
	var out := PackedVector2Array()
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s)
		if m == null or m.resource_name != "Sign":
			continue
		out.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV] as PackedVector2Array)
	return out


func _poster_models() -> Array[String]:
	var out: Array[String] = []
	for k in POSTER_KEYS:
		out.append("poster_" + k)
	for k in WIDE_KEYS:
		out.append("poster_wide_" + k)
	return out


func test_every_poster_and_wide_poster_loads_within_40_triangles_with_a_sign_surface() -> void:
	assert_eq(_poster_models().size(), 16)
	for model in _poster_models():
		assert_true(cfg.models.has(model), "%s listed" % model)
		var mesh := PropDressConfig.load_mesh(cfg.path_of(StringName(model)))
		assert_not_null(mesh, "%s loads" % model)
		if mesh == null:
			continue
		var tris := 0
		var has_sign := false
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3 if not idx.is_empty() else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			has_sign = has_sign or mesh.surface_get_material(s).resource_name == "Sign"
		assert_lte(tris, 40, "%s within budget" % model)
		assert_true(has_sign, "%s has a Sign surface" % model)


func test_every_printed_model_s_uvs_stay_inside_its_own_cell_of_the_sheet() -> void:
	var eps := 0.5 / 2048.0
	for model in cfg.models:
		var cell := _cell(model)
		if cell.size == Vector2.ZERO:
			continue
		var mesh := PropDressConfig.load_mesh(cfg.path_of(StringName(model)))
		var uvs := _sign_uvs(mesh)
		assert_gt(uvs.size(), 0, "%s has Sign uvs" % model)
		var lo := cell.position / SHEET
		var hi := cell.end / SHEET
		for uv: Vector2 in uvs:
			if uv.x < lo.x - eps or uv.x > hi.x + eps or uv.y < lo.y - eps or uv.y > hi.y + eps:
				fail_test("%s: uv %s outside its cell %s..%s" % [model, uv, lo, hi])
				break


func test_the_sign_sheet_is_2048_square_and_has_an_import() -> void:
	assert_true(FileAccess.file_exists(cfg.sign_sheet + ".import"), "signs.png.import")
	var tex := load(cfg.sign_sheet) as Texture2D
	assert_not_null(tex)
	assert_eq(tex.get_size(), SHEET)


func test_every_listed_model_is_on_disk_with_an_import_and_subway_names_only_listed_ones() -> void:
	for model in cfg.models:
		var p := cfg.path_of(StringName(model))
		assert_true(FileAccess.file_exists(p), "%s on disk" % p)
		assert_true(FileAccess.file_exists(p + ".import"), "%s.import committed" % p)
	var m := MapData.load_map("subway", play.map_style, SimTuning.new().rounds.team_size)
	var named := {}
	for f in m.station.fixtures:
		named[String(f.model)] = true
		assert_true(cfg.models.has(String(f.model)), "%s named but unlisted" % f.model)
	for model in cfg.models:
		assert_true(named.has(model), "%s listed but unused" % model)


func test_wide_posters_hang_on_the_trackside_walls_at_2_3_m_clear_of_the_name_boards() -> void:
	var m := MapData.load_map("subway", play.map_style, SimTuning.new().rounds.team_size)
	var wides: Array[StationDressing.Fixture] = []
	var boards: Array[StationDressing.Fixture] = []
	for f in m.station.fixtures:
		if String(f.model).begins_with("poster_wide_"):
			wides.append(f)
		elif f.model == &"name_board":
			boards.append(f)
	assert_eq(wides.size(), 7)
	for w: StationDressing.Fixture in wides:
		assert_almost_eq(absf(w.position.z), 12.5, 0.001, "trackside wall")
		assert_almost_eq(w.position.y, 2.3, 0.001, "centred at 2.3")
		for b: StationDressing.Fixture in boards:
			if absf(b.position.z - w.position.z) < 0.5:
				assert_gt(absf(b.position.x - w.position.x), 1.5 + 1.46, "wide at %s overlaps a board at %s" % [w.position, b.position])
	for i in wides.size():
		for j in range(i + 1, wides.size()):
			if absf(wides[i].position.z - wides[j].position.z) < 0.5:
				assert_gt(absf(wides[i].position.x - wides[j].position.x), 3.0, "wide posters overlap")


func test_no_two_neighbouring_posters_on_one_wall_share_a_design() -> void:
	var m := MapData.load_map("subway", play.map_style, SimTuning.new().rounds.team_size)
	var posters: Array[StationDressing.Fixture] = []
	for f in m.station.fixtures:
		if String(f.model).begins_with("poster_"):
			posters.append(f)
	var bad: Array[String] = []
	for a: StationDressing.Fixture in posters:
		for b: StationDressing.Fixture in posters:
			if a == b or a.model != b.model:
				continue
			# same wall: same facing and the same plane
			if absf(a.yaw - b.yaw) > 1.0:
				continue
			var plane := absf(a.position.z - b.position.z) if absf(sin(deg_to_rad(a.yaw))) < 0.5 else absf(a.position.x - b.position.x)
			var along := absf(a.position.x - b.position.x) if absf(sin(deg_to_rad(a.yaw))) < 0.5 else absf(a.position.z - b.position.z)
			if plane < 0.1 and along < 8.0 and along > 0.01:
				bad.append("%s at %s and %s" % [a.model, a.position, b.position])
	assert_eq(bad, [] as Array[String], "same design close together on one wall")


func test_edge_warnings_sit_0_7_m_in_from_their_platform_edge() -> void:
	var m := MapData.load_map("subway", play.map_style, SimTuning.new().rounds.team_size)
	# the track zones' near edges are the platform edges (z -9 and 9)
	var edges: Array[float] = []
	for z: StationDressing.Zone in m.station.zones:
		if z.style == &"train":
			var b: AABB = z.box
			edges.append(b.end.z if b.position.z < 0.0 else b.position.z)
	assert_gt(edges.size(), 0)
	var n := 0
	for f in m.station.fixtures:
		if f.model != &"edge_sign":
			continue
		n += 1
		var best := 1e9
		for e: float in edges:
			best = minf(best, absf(absf(f.position.z) - absf(e) ))
		assert_almost_eq(best, EDGE_IN, 0.01, "edge warning at %s" % f.position)
	assert_gt(n, 0)
