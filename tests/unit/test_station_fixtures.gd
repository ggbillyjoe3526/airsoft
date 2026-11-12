extends GutTest
## SM5: Subway's lamps and extras. Every model loads within its budget with its glowing glass or printed faces; the
## map names them (dressing.station.fixtures) and each stands in its room's air, a wall model's back on a wall, a
## hanging sign's top at its ceiling and well over the floor, a bin and an edge warning on the floor, none inside a
## block; StationFixtures draws one MultiMesh a model with no shadow, glowing lenses and the printed sheet, and nothing
## on the other maps; the ceilings' strip lamps are the model, turned along rooms running along z; no colour reads as
## a team; a malformed or unknown fixture is warned about and left out.

const BUDGETS: Dictionary[StringName, int] = {
	&"strip_lamp": 200, &"tunnel_lamp": 150, &"cctv_camera": 320, &"way_sign": 90, &"fire_extinguisher": 480,
	&"litter_bin": 320, &"edge_sign": 12, &"platform_clock": 300, &"poster_a": 40, &"poster_b": 40, &"poster_c": 40,
	&"poster_d": 40, &"poster_e": 40, &"poster_f": 40, &"poster_g": 40, &"poster_h": 40, &"poster_i": 40, &"poster_j": 40,
	&"poster_k": 40, &"poster_l": 40, &"poster_m": 40, &"poster_wide_a": 40, &"poster_wide_b": 40, &"poster_wide_c": 40,
	&"name_board": 40, &"line_map": 40, &"info_panel": 40, &"notice_smoking": 40, &"notice_handrail": 40,
	&"notice_cctv": 40, &"wall_sign_out": 40, &"wall_sign_platforms": 40, &"departures_n": 90, &"departures_s": 90,
}
const HUNG: Array[StringName] = [&"way_sign", &"departures_n", &"departures_s"]
const LENSED: Array[StringName] = [&"strip_lamp", &"tunnel_lamp"]
const PRINTED: Array[StringName] = [&"way_sign", &"edge_sign", &"platform_clock", &"poster_a", &"poster_b",
		&"poster_c", &"poster_d", &"poster_e", &"poster_f", &"poster_g", &"poster_h", &"poster_i", &"poster_j", &"poster_k",
		&"poster_l", &"poster_m", &"poster_wide_a", &"poster_wide_b", &"poster_wide_c", &"name_board", &"departures_n",
		&"departures_s", &"line_map", &"info_panel", &"notice_smoking", &"notice_handrail", &"notice_cctv", &"wall_sign_out",
		&"wall_sign_platforms"]
const WALL: Array[StringName] = [&"tunnel_lamp", &"cctv_camera", &"fire_extinguisher", &"platform_clock", &"poster_a",
		&"poster_b", &"poster_c", &"poster_d", &"poster_e", &"poster_f", &"poster_g", &"poster_h", &"poster_i", &"poster_j",
		&"poster_k", &"poster_l", &"poster_m", &"poster_wide_a", &"poster_wide_b", &"poster_wide_c", &"name_board",
		&"line_map", &"info_panel", &"notice_smoking", &"notice_handrail", &"notice_cctv", &"wall_sign_out",
		&"wall_sign_platforms"]
const FLOOR: Array[StringName] = [&"litter_bin", &"edge_sign"]
## How far (m) a model may sink into the wall or ceiling it is fixed to.
const TOUCH := 0.012

var play: PlayTuning = PlayTuning.load_default()
var cfg: StationFixturesConfig = null


func before_each() -> void:
	cfg = play.station_fixtures


func _map(id: String) -> MapData:
	var m := MapData.load_map(id, play.map_style, 1 if id == "range" else SimTuning.new().rounds.team_size)
	assert_true(m.ok(), "%s loads: %s" % [id, m.problems])
	return m


func _mesh(model: StringName) -> Mesh:
	return PropDressConfig.load_mesh(cfg.path_of(model))


func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		n += index.size() / 3 if not index.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _surfaces(mesh: Mesh) -> Array[StringName]:
	var out: Array[StringName] = []
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s)
		out.append(StringName(m.resource_name) if m != null else &"")
	return out


func _block_box(b: MapData.Block) -> AABB:
	return AABB(b.center - b.size * 0.5, b.size)


## `box` drawn in by up to `by` m a side, never past a quarter of its size (a poster is 2 cm deep).
func _shrunk(box: AABB, by: float) -> AABB:
	var d := Vector3(minf(by, box.size.x * 0.25), minf(by, box.size.y * 0.25), minf(by, box.size.z * 0.25))
	return AABB(box.position + d, box.size - d * 2.0)


func _in_block(m: MapData, p: Vector3) -> bool:
	for b in m.blocks:
		if _block_box(b).has_point(p):
			return true
	return false


func test_every_model_loads_within_its_budget_with_its_glass_or_print() -> void:
	for model: StringName in BUDGETS:
		var mesh := _mesh(model) if model != &"strip_lamp" else PropDressConfig.load_mesh(play.roof.plain_lamp_model)
		assert_not_null(mesh, "%s loads" % model)
		if mesh == null:
			continue
		assert_between(_tris(mesh), int(BUDGETS[model] * 0.8), BUDGETS[model], "%s uses its budget, within it" % model)
		var surfaces := _surfaces(mesh)
		assert_eq(surfaces.has(StationFixtures.LENS_SURFACE), LENSED.has(model), "%s's glass: %s" % [model, surfaces])
		assert_eq(surfaces.has(StationFixtures.SIGN_SURFACE), PRINTED.has(model), "%s's print: %s" % [model, surfaces])
	for model in cfg.models:
		assert_true(BUDGETS.has(StringName(model)), "%s has a budget here" % model)


func test_every_printed_face_keeps_its_cell_s_shape() -> void:
	# Each printed triangle's world edges over its edges on the 2048 px sheet: one ratio a triangle, so no face
	# stretches its cell's drawing (within 2%).
	for model: StringName in PRINTED:
		var mesh := _mesh(model)
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat == null or StringName(mat.resource_name) != StationFixtures.SIGN_SURFACE:
				continue
			var arrays := mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var worst := 0.0
			for t in index.size() / 3:
				var ratios: Array[float] = []
				for e in 3:
					var a := index[t * 3 + e]
					var b := index[t * 3 + (e + 1) % 3]
					var px := (uv[a] - uv[b]).length() * 2048.0
					if px > 4.0:
						ratios.append(pos[a].distance_to(pos[b]) / px)
				if ratios.size() >= 2:
					worst = maxf(worst, ratios.max() / ratios.min() - 1.0)
			assert_lt(worst, 0.02, "%s's print stretched %.1f%%" % [model, worst * 100.0])


func test_subway_names_every_model_and_the_tunnels_their_lamps() -> void:
	var m := _map("subway")
	var counts: Dictionary[StringName, int] = {}
	for f in m.station.fixtures:
		counts[f.model] = counts.get(f.model, 0) + 1
	for model in cfg.models:
		assert_gt(counts.get(StringName(model), 0), 0, "%s placed" % model)
	assert_between(counts.get(&"tunnel_lamp", 0), 10, 14, "about 12 tunnel lamps (the model list)")
	assert_gte(counts.get(&"name_board", 0), 8, "the station's name along both platforms")


func test_each_fixture_stands_in_its_room_on_its_wall_ceiling_or_floor_and_in_no_block() -> void:
	var m := _map("subway")
	var bad: Array[String] = []
	var boxes: Dictionary[StringName, AABB] = {}
	for model in cfg.models:
		boxes[StringName(model)] = _mesh(StringName(model)).get_aabb()
	for f in m.station.fixtures:
		var t := Transform3D(Basis(Vector3.UP, f.yaw).scaled(Vector3.ONE * f.scale), f.position)
		var box := t * boxes[f.model]
		var front := t.basis.z.normalized()
		var tag := "%s at %s" % [f.model, f.position]
		if m.station.zone_at(box.get_center()) == null:
			bad.append("%s: in no room" % tag)
		var inner := _shrunk(box, TOUCH)
		for b in m.blocks:
			if _block_box(b).intersects(inner):
				bad.append("%s: inside a %s block at %s" % [tag, b.kind, b.center])
				break
		if WALL.has(f.model):
			if not _in_block(m, f.position - front * 0.03):
				bad.append("%s: no wall behind it" % tag)
		elif HUNG.has(f.model):
			if not _in_block(m, f.position + Vector3.UP * 0.03) and not _on_rods(m, f.position):
				bad.append("%s: no ceiling over it" % tag)
			var floor_y := m.floor_under(f.position.x, f.position.z, box.position.y)
			if box.position.y - floor_y < 2.3:
				bad.append("%s: only %.2f m over the floor" % [tag, box.position.y - floor_y])
		elif FLOOR.has(f.model):
			# a warning lies on the coping, drawn StationLook.strip_lift over the floor
			var floor_y := m.floor_under(f.position.x, f.position.z, f.position.y + 0.1)
			var lift := play.station_look.strip_lift if f.model == &"edge_sign" else 0.0
			if absf(floor_y + lift - f.position.y) > 0.001:
				bad.append("%s: not on the floor (%.3f)" % [tag, floor_y])
	assert_eq(bad, [] as Array[String], "every fixture on its wall, ceiling or floor, in its room, in no block")


func test_the_view_draws_one_multimesh_a_model_glowing_and_printed_with_no_shadow() -> void:
	var m := _map("subway")
	var view := StationFixtures.build(m, cfg)
	assert_not_null(view, "Subway's fixtures drawn")
	if view == null:
		return
	add_child_autofree(view)
	var total := 0
	var glow := 0
	var printed := 0
	for v in view.views():
		total += v.multimesh.instance_count
		assert_eq(v.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % v.name)
		for s in v.multimesh.mesh.get_surface_count():
			var mat := v.multimesh.mesh.surface_get_material(s)
			if mat is ShaderMaterial and (mat as ShaderMaterial).get_shader_parameter(&"use_sheet") == true:
				printed += 1
				assert_not_null((mat as ShaderMaterial).get_shader_parameter(&"sheet"), "the sheet is printed")
			elif mat is ShaderMaterial and (mat as ShaderMaterial).get_shader_parameter(&"glow") != null:
				glow += 1
	assert_eq(view.views().size(), cfg.models.size(), "one MultiMesh a model")
	assert_eq(total, m.station.fixtures.size(), "every fixture drawn")
	assert_eq(glow, 1, "the tunnel lamp's glass glows")
	assert_eq(printed, PRINTED.size(), "every printed model prints the sheet")
	assert_eq(view.materials().size(), 3)


func test_each_tunnel_lamp_lights_its_running_tunnel_s_arch_from_its_glass() -> void:
	var m := _map("subway")
	var view := StationFixtures.build(m, cfg)
	add_child_autofree(view)
	var placed: Array = view.placed().get(&"tunnel_lamp", [])
	assert_gt(placed.size(), 8, "the running tunnels have their lamps")
	assert_eq(view.lamps().size(), placed.size(), "a light at each tunnel lamp, none elsewhere (TB2)")
	for i in view.lamps().size():
		var lamp: OmniLight3D = view.lamps()[i]
		var t: Transform3D = placed[i]
		assert_true(lamp.visible and lamp.is_inside_tree(), "lit on every preset")
		assert_false(lamp.shadow_enabled, "no shadow")
		assert_almost_eq(lamp.position.distance_to(t.origin), cfg.lamp_out, 0.001, "at its glass, out from the wall")
		assert_false(_in_block(m, lamp.position), "in the tunnel's air, not in its wall")
		# under the running arch, which it lights from below (the roof's lamps shine down from its crown)
		var v: StationDressing.TunnelVault = null
		for o in m.station.vaults:
			if o.open_west and o.area.has_point(Vector2(lamp.position.x, lamp.position.z)):
				v = o
		assert_not_null(v, "in a running tunnel: %s" % lamp.position)
		if v != null:
			assert_lt(lamp.position.y, v.y, "under the arch's springing")
			assert_gt(lamp.omni_range, v.y + v.rise - lamp.position.y, "reaching its crown")


func test_no_other_map_has_fixtures_and_freeing_leaves_no_orphans() -> void:
	for id: String in ["depot", "woodland", "range"]:
		assert_null(StationFixtures.build(_map(id), cfg), "%s has none" % id)
	assert_null(StationFixtures.build(null, cfg))
	var view := StationFixtures.build(_map("subway"), cfg)
	add_child(view)
	view.free()
	assert_no_new_orphans()


func test_subway_s_ceiling_lamps_are_the_strip_model_turned_along_their_rooms() -> void:
	var m := _map("subway")
	assert_eq(m.roof_lamp_turns.size(), m.roof_lamps.size(), "a turn for every lamp")
	var turned := 0
	for t in m.roof_lamp_turns:
		assert_true(is_equal_approx(t, 0.0) or is_equal_approx(t, PI / 2.0), "a lamp runs along x or z")
		turned += 1 if t > 0.0 else 0
	assert_between(turned, 1, m.roof_lamps.size() - 1, "some lamps run along z, most along x")
	var roof := RoofView.build(m, play.roof)
	add_child_autofree(roof)
	var lamps: MultiMeshInstance3D = roof.find_child("Lamps", false, false)
	assert_not_null(lamps)
	var mesh := lamps.multimesh.mesh
	assert_true(mesh.get_aabb().size.x > 1.4, "the strip lamp, 1.5 m long")
	assert_almost_eq(mesh.get_aabb().end.y, 0.0, 0.001, "its top at y 0")
	for i in m.roof_lamps.size():
		var t := RoofView.lamp_place(m, play.roof, false, i, 0.0)
		assert_almost_eq(t.origin.y, m.roof_lamp_heights[i], 0.001, "lamp %d hangs from its ceiling" % i)
		assert_almost_eq(t.basis.x.angle_to(Vector3.RIGHT), m.roof_lamp_turns[i], 0.001, "lamp %d turned" % i)


## Whether drop rods (look-only trims, TB1) rise from a hung model's top at `p` up into a vault's arc.
func _on_rods(m: MapData, p: Vector3) -> bool:
	var rods := 0
	for t in m.station.trims:
		var c := t.box.get_center()
		if absf(t.box.position.y - p.y) < 0.01 and Vector2(c.x - p.x, c.z - p.z).length() < 1.0:
			for v in m.station.vaults:
				if v.lid().has_point(Vector3(c.x, t.box.end.y - 0.01, c.z)) and t.box.end.y > v.y + 0.5:
					rods += 1
	return rods >= 2


## The trains' stripe, a worn burnt orange, and the station's name signs in it (owner, 2026-11-12): let off the
## team-hue rule at his word, as in test_trains.gd; within 0.03 of its hue and no more saturated (its blends with the
## signs' cream words are paler, never stronger; Beta's orange is).
func _stripe(c: Color) -> bool:
	var stripe := Color("#c0652f")
	var dh := absf(c.h - stripe.h)
	return minf(dh, 1.0 - dh) <= 0.03 and c.s <= stripe.s + 0.02


func test_no_colour_reads_as_a_team() -> void:
	var teams: Array[Color] = AccessibilityTable.read_file().colours
	teams.append_array(play.teams.colours)
	var near: Array[String] = []
	var models: Array[String] = ["strip_lamp"]
	for model in cfg.models:
		models.append(model)
	for model in models:
		var mesh := _mesh(StringName(model))
		var seen: Dictionary[Color, bool] = {}
		for s in mesh.get_surface_count():
			for linear in mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR] as PackedColorArray:
				var c := linear.linear_to_srgb()
				if not seen.has(c):
					seen[c] = true
					if FieldChecks.reads_as_team(c, teams):
						near.append("%s %s" % [model, c.to_html(false)])
	# the sign sheet: few of its pixels may read as a team (none of its paints do; only blends at their edges)
	var sheet := (load(cfg.sign_sheet) as Texture2D).get_image()
	if sheet.is_compressed():
		sheet.decompress()
	var hits := 0
	var tried := 0
	for y in range(0, sheet.get_height(), 8):
		for x in range(0, sheet.get_width(), 8):
			tried += 1
			var c := sheet.get_pixel(x, y)
			if FieldChecks.reads_as_team(c, teams) and not _stripe(c):
				hits += 1
	assert_eq(near, [] as Array[String], "no model paint within 20 degrees of a team's hue unless dull")
	assert_lt(float(hits) / tried, 0.01, "the sign sheet keeps off the teams' hues (%d of %d)" % [hits, tried])
	assert_false(_stripe(Color("#fa8c29")), "Beta's orange is never let off")


func test_a_malformed_or_unknown_fixture_is_warned_about_and_left_out() -> void:
	var warnings: Array[String] = []
	var d := StationDressing.read({"station": {"fixtures": [
		{"model": "poster_a", "x": 1, "y": 2, "z": 3, "yaw": 90},
		{"model": "poster_a", "x": 1, "y": 2, "z": 3},
		{"model": "", "x": 1, "y": 2, "z": 3, "yaw": 0},
		{"model": "no_such_model", "x": 0, "y": 0, "z": 0, "yaw": 0},
		7,
	]}}, warnings)
	assert_eq(d.fixtures.size(), 2, "the good ones kept")
	assert_eq(warnings.size(), 3, "each malformed one warned about")
	assert_almost_eq(d.fixtures[0].yaw, PI / 2.0, 0.0001, "yaw read in degrees")
	assert_eq(d.fixtures[0].position, Vector3(1, 2, 3))
	var placed := StationFixtures.placings(d, cfg)
	assert_eq(placed.keys(), [&"poster_a"], "an unknown model is left out")


func test_no_fixture_is_drawn_through_a_trim_or_the_vault_s_lid() -> void:
	# TB1 x SM5: the frieze, cables and linings lie on the same walls as the clocks, cameras and name boards.
	var m := _map("subway")
	var bad: Array[String] = []
	for f in m.station.fixtures:
		var t := Transform3D(Basis(Vector3.UP, f.yaw), f.position)
		var box := _shrunk(t * _mesh(f.model).get_aabb(), TOUCH)
		for tr in m.station.trims:
			if tr.box.intersects(box):
				bad.append("%s at %s through a %s trim" % [f.model, f.position, tr.finish])
		for v in m.station.vaults:
			if v.lid().intersects(box):
				bad.append("%s at %s in a vault's lid" % [f.model, f.position])
	assert_eq(bad, [] as Array[String], "fixtures clear every trim and vault")


func test_each_departure_board_has_a_rod_near_both_of_its_ends_and_reaching_the_arc() -> void:
	# QA: the rods sit at the board's own ends (along its yaw, not the world x), on its depth, from its top into a vault.
	var m := _map("subway")
	var n := 0
	for f in m.station.fixtures:
		if f.model != &"departures_n" and f.model != &"departures_s":
			continue
		n += 1
		var t := Transform3D(Basis(Vector3.UP, f.yaw).scaled(Vector3.ONE * f.scale), f.position)
		var box := _mesh(f.model).get_aabb()
		var ends := [0, 0]
		for tr in m.station.trims:
			var c := tr.box.get_center()
			if absf(tr.box.position.y - f.position.y) > 0.01 or Vector2(c.x - f.position.x, c.z - f.position.z).length() > 3.0:
				continue
			var local := t.affine_inverse() * Vector3(c.x, f.position.y, c.z)
			if local.x > box.position.x and local.x < box.end.x and absf(local.z - (box.position.z + box.end.z) * 0.5) < box.size.z:
				ends[0 if local.x < box.get_center().x else 1] += 1
				var hit := false
				for v in m.station.vaults:
					hit = hit or v.lid().has_point(Vector3(c.x, tr.box.end.y - 0.01, c.z))
				assert_true(hit, "%s's rod reaches a vault's arc" % f.model)
		assert_eq(ends, [1, 1], "%s at %s: one rod near each end" % [f.model, f.position])
	assert_eq(n, 4, "four departure boards")
