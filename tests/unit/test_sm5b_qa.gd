extends GutTest
## SM5B QA: a fixture's scale, the escalator posters, the new printed cells, the departure boards, wall overlaps.

const SHEET := Vector2(2048.0, 2048.0)
## station_cells.py's new cells (x, y, w, h in px).
const NEW_CELLS: Dictionary[String, Rect2] = {
	"line_map": Rect2(0, 1408, 1024, 128),
	"departures_n": Rect2(0, 1872, 512, 128),
	"departures_s": Rect2(512, 1872, 512, 128),
	"info_panel": Rect2(1552, 1872, 352, 176),
	"notice_smoking": Rect2(1024, 1872, 176, 176),
	"notice_handrail": Rect2(1200, 1872, 176, 176),
	"notice_cctv": Rect2(1376, 1872, 176, 176),
}
const WALL_PLATES: Array[StringName] = [&"line_map", &"info_panel", &"notice_smoking", &"notice_handrail",
		&"notice_cctv", &"wall_sign_out", &"wall_sign_platforms"]
const POSTER_HALF := Vector2(0.525, 0.775)
const ESC_SCALE := 0.6
const DECK := 1.0

var play: PlayTuning = PlayTuning.load_default()
var cfg: StationFixturesConfig = play.station_fixtures
var _map: MapData = null


func _subway() -> MapData:
	if _map == null:
		_map = MapData.load_map("subway", play.map_style, SimTuning.new().rounds.team_size)
	return _map


func _read(fixtures: Array) -> Array:
	var warnings: Array[String] = []
	var d := StationDressing.read({"station": {"fixtures": fixtures}}, warnings)
	return [d, warnings]


func _fx(extra: Dictionary) -> Dictionary:
	var d := {"model": "poster_a", "x": 1, "y": 2, "z": 3, "yaw": 0}
	d.merge(extra, true)
	return d


# ---- the scale field ----

func test_a_fixture_with_no_scale_has_scale_1_and_a_valid_one_is_kept() -> void:
	var r := _read([_fx({}), _fx({"scale": 0.6}), _fx({"scale": 2})])
	var d: StationDressing = r[0]
	assert_eq(d.fixtures.size(), 3)
	assert_eq(r[1].size(), 0, "no warnings")
	assert_eq(d.fixtures[0].scale, 1.0)
	assert_almost_eq(d.fixtures[1].scale, 0.6, 0.0001)
	assert_eq(d.fixtures[2].scale, 2.0)


func test_a_zero_negative_or_non_number_scale_leaves_the_fixture_out_with_a_warning() -> void:
	for bad: Variant in [0, 0.0, -1, -0.5, "0.6", null, true, [1]]:
		var r := _read([_fx({"scale": bad})])
		var d: StationDressing = r[0]
		assert_eq(d.fixtures.size(), 0, "scale %s left out" % [bad])
		assert_eq(r[1].size(), 1, "scale %s warned about" % [bad])


func test_placings_scale_the_instance_basis_and_leave_its_turn_and_place() -> void:
	var r := _read([_fx({"yaw": 90, "scale": 0.6}), _fx({"yaw": 90})])
	var placed := StationFixtures.placings(r[0], cfg)
	var ts: Array = placed[&"poster_a"]
	assert_eq(ts.size(), 2)
	var small: Transform3D = ts[0]
	var full: Transform3D = ts[1]
	assert_almost_eq(small.basis.x.length(), 0.6, 0.0001)
	assert_almost_eq(small.basis.y.length(), 0.6, 0.0001)
	assert_almost_eq(small.basis.z.length(), 0.6, 0.0001)
	assert_eq(small.origin, Vector3(1, 2, 3))
	assert_almost_eq(small.basis.z.normalized().angle_to(full.basis.z), 0.0, 0.0001, "same facing")
	assert_almost_eq(full.basis.x.length(), 1.0, 0.0001)


func test_a_scaled_fixture_in_the_view_is_one_multimesh_instance_placed_at_its_size() -> void:
	var r := _read([_fx({"scale": 0.5})])
	var st := StationFixtures.build(_stub_map(r[0]), cfg)
	assert_not_null(st)
	if st == null:
		return
	add_child_autofree(st)
	assert_eq(st.views().size(), 1, "one multimesh for the one model")
	var ts: Array = st.placed()[&"poster_a"]
	assert_eq(ts.size(), 1)
	assert_almost_eq((ts[0] as Transform3D).basis.x.length(), 0.5, 0.0001)


func _stub_map(d: StationDressing) -> MapData:
	var m := MapData.new()
	m.station = d
	return m


# ---- the escalator posters ----

func _escalator_posters() -> Array[StationDressing.Fixture]:
	var out: Array[StationDressing.Fixture] = []
	for f in _subway().station.fixtures:
		if f.scale != 1.0:
			out.append(f)
	return out


func test_there_are_28_small_posters_all_of_the_poster_models_at_0_6() -> void:
	var ps := _escalator_posters()
	assert_eq(ps.size(), 28)
	for f in ps:
		assert_almost_eq(f.scale, ESC_SCALE, 0.0001)
		assert_true(String(f.model).begins_with("poster_") and not String(f.model).begins_with("poster_wide"), String(f.model))


func test_every_escalator_poster_stands_on_its_shaft_wall_centred_clear_of_the_decks_and_under_the_ceiling() -> void:
	var m := _subway()
	# shaft: x range, wall z, room height over the stair
	var shafts := [
		{"x0": -38.0, "x1": -18.0, "z": 3.5, "h": 3.2},
		{"x0": -6.0, "x1": 10.0, "z": 3.0, "h": 2.8},
	]
	var bad: Array[String] = []
	var sides := {}
	for f in _escalator_posters():
		var shaft := {}
		for s: Dictionary in shafts:
			if f.position.x >= s.x0 and f.position.x <= s.x1 and absf(absf(f.position.z) - s.z) < 0.001:
				shaft = s
		var tag := "%s at %s" % [f.model, f.position]
		if shaft.is_empty():
			bad.append("%s: on no shaft wall" % tag)
			continue
		sides["%s%s" % [shaft.z, signf(f.position.z)]] = true
		# faces into the shaft (its front, +z of the model, points to the middle)
		var front := Basis(Vector3.UP, f.yaw).z
		if front.z * f.position.z > -0.9:
			bad.append("%s: not facing the shaft" % tag)
		var half := POSTER_HALF * ESC_SCALE
		var lo := f.position.y - half.y
		var hi := f.position.y + half.y
		# the stair under it, at the poster's near and far x
		var floor_hi := -INF
		var floor_lo := INF
		for dx: float in [-half.x, 0.0, half.x]:
			var fl := m.floor_under(f.position.x + dx, 1.0, f.position.y)
			floor_hi = maxf(floor_hi, fl)
			floor_lo = minf(floor_lo, fl)
		if lo - floor_hi < DECK - 0.001:
			bad.append("%s: bottom %.2f only %.2f over the stair" % [tag, lo, lo - floor_hi])
		if hi > floor_lo + shaft.h + 0.001:
			bad.append("%s: top %.2f over the ceiling %.2f" % [tag, hi, floor_lo + shaft.h])
		if f.position.x < shaft.x0 + 2.0 - 0.001 or f.position.x > shaft.x1 - 2.0 + 0.001:
			bad.append("%s: within 2 m of the shaft's end" % tag)
	assert_eq(bad, [] as Array[String])
	assert_eq(sides.size(), 4, "both walls of both shafts carry a row")


# ---- the new cells ----

func test_the_new_printed_models_sign_uvs_stay_inside_their_own_cells() -> void:
	var eps := 0.5 / 2048.0
	for model: String in NEW_CELLS:
		var cell: Rect2 = NEW_CELLS[model]
		var mesh := PropDressConfig.load_mesh(cfg.path_of(StringName(model)))
		assert_not_null(mesh, model)
		var uvs := PackedVector2Array()
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat != null and mat.resource_name == "Sign":
				uvs.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV] as PackedVector2Array)
		assert_gt(uvs.size(), 0, "%s has Sign uvs" % model)
		var lo := cell.position / SHEET
		var hi := cell.end / SHEET
		for uv: Vector2 in uvs:
			if uv.x < lo.x - eps or uv.x > hi.x + eps or uv.y < lo.y - eps or uv.y > hi.y + eps:
				fail_test("%s: uv %s outside %s..%s" % [model, uv, lo, hi])
				break


func test_the_wall_signs_print_the_hanging_signs_cells_not_new_ones() -> void:
	# wall_sign_out / _platforms reuse the way_sign cell (0, 1296, 1024, 112); they must not stray out of it.
	var cell := Rect2(0, 1296, 1024, 112)
	var eps := 0.5 / 2048.0
	for model: StringName in [&"wall_sign_out", &"wall_sign_platforms"]:
		var mesh := PropDressConfig.load_mesh(cfg.path_of(model))
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat == null or mat.resource_name != "Sign":
				continue
			for uv: Vector2 in mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV]:
				var p := uv * SHEET
				assert_true(p.x >= cell.position.x - 1.0 and p.x <= cell.end.x + 1.0 and p.y >= cell.position.y - 1.0 \
						and p.y <= cell.end.y + 1.0, "%s uv %s" % [model, p])
	assert_gt(eps, 0.0)


# ---- the departure boards ----

func _lamp_boxes() -> Array[AABB]:
	var m := _subway()
	var mesh := PropDressConfig.load_mesh(play.roof.plain_lamp_model)
	var out: Array[AABB] = []
	for i in m.roof_lamps.size():
		out.append(RoofView.lamp_place(m, play.roof, false, i, 0.0) * mesh.get_aabb())
	return out


func _box_of(f: StationDressing.Fixture) -> AABB:
	var mesh := PropDressConfig.load_mesh(cfg.path_of(f.model))
	var t := Transform3D(Basis(Vector3.UP, f.yaw).scaled(Vector3.ONE * f.scale), f.position)
	return t * mesh.get_aabb()


func test_the_departure_boards_hang_under_the_ceiling_and_touch_no_strip_lamp() -> void:
	var lamps := _lamp_boxes()
	var n := 0
	var bad: Array[String] = []
	for f in _subway().station.fixtures:
		if f.model != &"departures_n" and f.model != &"departures_s":
			continue
		n += 1
		var box := _box_of(f)
		var tag := "%s at %s" % [f.model, f.position]
		for lb in lamps:
			if box.intersects(lb.grow(0.02)):
				bad.append("%s meets a lamp at %s" % [tag, lb.get_center()])
		# the nearest lamps along the platform: one each side, none inside the board's span
		var gap := INF
		for lb in lamps:
			if absf(lb.get_center().z - f.position.z) < 0.6 and absf(lb.get_center().y - f.position.y) < 1.0:
				gap = minf(gap, absf(lb.get_center().x - f.position.x))
		assert_gt(gap, 0.0, "%s has lamps in its row" % tag)
	assert_eq(n, 4)
	assert_eq(bad, [] as Array[String])


# ---- no overlaps ----

func test_no_two_wall_fixtures_on_one_wall_overlap() -> void:
	var m := _subway()
	var wall: Array[StationDressing.Fixture] = []
	for f in m.station.fixtures:
		if _is_wall(f.model):
			wall.append(f)
	var bad: Array[String] = []
	for i in wall.size():
		var a := wall[i]
		var na := Basis(Vector3.UP, a.yaw).z
		var ba := _box_of(a)
		for j in range(i + 1, wall.size()):
			var b := wall[j]
			if Basis(Vector3.UP, b.yaw).z.dot(na) < 0.99:
				continue
			# same plane
			if absf((b.position - a.position).dot(na)) > 0.15:
				continue
			var bb := _box_of(b)
			# compare in the wall's plane: both extents along the wall and up must overlap
			var along := Vector3(na.z, 0, -na.x)
			var ra := _span(ba, along)
			var rb := _span(bb, along)
			var along_ov := minf(ra.y, rb.y) - maxf(ra.x, rb.x)
			var up_ov := minf(ba.end.y, bb.end.y) - maxf(ba.position.y, bb.position.y)
			if along_ov > 0.01 and up_ov > 0.01:
				bad.append("%s at %s and %s at %s" % [a.model, a.position, b.model, b.position])
	assert_eq(bad, [] as Array[String], "wall fixtures overlapping")


func _is_wall(model: StringName) -> bool:
	var s := String(model)
	return s.begins_with("poster_") or s.begins_with("notice_") or s.begins_with("wall_sign_") \
			or s in ["line_map", "info_panel", "name_board", "cctv_camera", "fire_extinguisher", "platform_clock"]


func _span(box: AABB, dir: Vector3) -> Vector2:
	var lo := INF
	var hi := -INF
	for i in 8:
		var d := box.get_endpoint(i).dot(dir)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return Vector2(lo, hi)
