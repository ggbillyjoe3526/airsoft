extends GutTest
## BL8 QA: the attachment models in the real parts files keep the part contract (docs/CC0_ASSETS.md > Replica models):
## names, figures, sight lines, muzzle and beam points, budgets, materials, and the optics' glass discs matching their
## windows (ViewModelConfig).

const DIR := "res://assets/models/replicaParts/"
const FILES: Array[String] = ["aeg", "pistol", "cyber", "sniper"]
const PART_TRIS := 10000
const FILE_BYTES := 2 * 1024 * 1024
const SIGHT_REDDOT_AEG := Vector3(0.0, 0.104, -0.025)
## The glass disc's lift off the window (OpticGlass.DISC_LIFT), and the slack allowed on a surface test.
const LIFT := 0.0005
const SLACK := 0.0002
const OPTICS: Array[StringName] = [&"redDot", &"scope2x", &"scopeVar"]

var cfg := ViewModelConfig.new()


func _load(file: String) -> Node3D:
	var n := (load(DIR + file + ".glb") as PackedScene).instantiate() as Node3D
	add_child_autofree(n)
	return n


func _parts(root: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c: Node in root.get_children():
		var m := c as MeshInstance3D
		if m != null and not m.name.ends_with("_Figure"):
			out.append(m)
	return out


func _tris(m: MeshInstance3D) -> int:
	return m.mesh.get_faces().size() / 3


func _kind(m: MeshInstance3D) -> String:
	return String(m.name).split("_")[0]


func _part(root: Node3D, part_name: String) -> MeshInstance3D:
	return root.get_node_or_null(part_name) as MeshInstance3D


func _surface_box(m: MeshInstance3D, material: String) -> AABB:
	for i in m.mesh.get_surface_count():
		var mat := m.mesh.surface_get_material(i)
		if mat != null and mat.resource_name == material:
			var verts := m.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var box := AABB(verts[0], Vector3.ZERO)
			for v in verts:
				box = box.expand(v)
			return box
	return AABB()


func test_every_part_is_within_its_triangle_budget_and_every_file_within_two_megabytes() -> void:
	for file: String in FILES:
		assert_lte(FileAccess.get_file_as_bytes(DIR + file + ".glb").size(), FILE_BYTES, "%s.glb size" % file)
		var root := _load(file)
		for m: MeshInstance3D in _parts(root):
			assert_lt(_tris(m), PART_TRIS, "%s/%s triangles" % [file, m.name])
			var fig := m.get_node_or_null(NodePath(String(m.name) + "_Figure"))
			if fig == null:
				fig = root.get_node_or_null(NodePath(String(m.name) + "_Figure"))
			assert_not_null(fig, "%s/%s has a _Figure" % [file, m.name])
			if fig is MeshInstance3D:
				assert_lt(_tris(fig as MeshInstance3D), _tris(m), "%s/%s figure is cut down" % [file, m.name])


func test_each_part_kind_carries_its_marker_empties() -> void:
	for file: String in FILES:
		var root := _load(file)
		for m: MeshInstance3D in _parts(root):
			var n := String(m.name)
			match _kind(m):
				"optic":
					assert_not_null(m.get_node_or_null(n + "_SightLine"), "%s: %s sight line" % [file, n])
				"muzzle":
					assert_not_null(m.get_node_or_null(n + "_Muzzle"), "%s: %s muzzle" % [file, n])
				"laser":
					assert_not_null(m.get_node_or_null(n + "_Beam"), "%s: %s beam" % [file, n])
				"light":
					assert_not_null(m.get_node_or_null(n + "_Beam"), "%s: %s beam" % [file, n])
					var under := m.get_node_or_null(n + "_UnderLaser")
					if file == "pistol" or file == "cyber":
						assert_not_null(under, "%s: torch has an UnderLaser" % file)
					else:
						assert_null(under, "%s: a rifle's torch has no UnderLaser" % file)


func test_the_red_dots_sight_line_is_unchanged_in_the_rifles_space() -> void:
	var dot := _part(_load("aeg"), "optic_redDot")
	var line := dot.get_node("optic_redDot_SightLine") as Node3D
	assert_almost_eq(dot.transform * line.position, SIGHT_REDDOT_AEG, Vector3.ONE * 0.0002, "aeg: red dot sight line")
	# The Sniper Rifle has its own mounts (BL5): the sight stands as high over its mount as on the AEG.
	var s_dot := _part(_load("sniper"), "optic_redDot")
	var s_line := s_dot.get_node("optic_redDot_SightLine") as Node3D
	assert_almost_eq(s_line.position, line.position, Vector3.ONE * 0.0002, "sniper: red dot sight line over its mount")


func test_sight_lines_sit_on_their_lens_and_each_optic_is_centred_on_the_bore() -> void:
	for file: String in ["aeg", "sniper"]:
		var root := _load(file)
		for pair: Array in [["optic_redDot", "LensDot"], ["optic_scope2x", "Lens"], ["optic_scopeVar", "Lens"]]:
			var m := _part(root, pair[0])
			var line := m.get_node(String(pair[0]) + "_SightLine") as Node3D
			var lens := _surface_box(m, pair[1])
			assert_gt(lens.size.x, 0.0, "%s %s has a %s surface" % [file, pair[0], pair[1]])
			var c := lens.get_center()
			assert_almost_eq(line.position.x, c.x, 0.001, "%s %s sight line x on its lens" % [file, pair[0]])
			assert_almost_eq(line.position.y, c.y, 0.001, "%s %s sight line y on its lens" % [file, pair[0]])
			assert_almost_eq(m.position.x, 0.0, 0.0001, "%s %s on the bore's plane" % [file, pair[0]])


func test_glass_discs_sit_just_over_each_optics_window_inside_it() -> void:
	for file: String in ["aeg", "sniper"]:
		var root := _load(file)
		for key: StringName in OPTICS:
			var m := _part(root, "optic_%s" % key)
			var line := (m.get_node("optic_%s_SightLine" % key) as Node3D).position
			var disc_z := float(cfg.optic_glass_z[key]) + LIFT
			var radius := float(cfg.optic_glass_radius[key])
			var tm := m.mesh.generate_triangle_mesh()
			for k in 12:
				var a := TAU * k / 12.0
				for r: float in [0.0, 0.9]:
					# The red dot's base hides the lower part of its disc from the eye (advisory in the QA report):
					# only the middle and the upper half are held for it.
					if key == &"redDot" and sin(a) < -0.1 and r > 0.0:
						continue
					var from := Vector3(line.x + cos(a) * radius * r, line.y + sin(a) * radius * r, 0.5)
					var hit := tm.intersect_ray(from, Vector3(0, 0, -1))
					assert_false(hit.is_empty(), "%s %s: the window at %.0f deg r%.1f is solid" % [file, key, rad_to_deg(a), r])
					if hit.is_empty():
						continue
					var z := (hit["position"] as Vector3).z
					# Nothing of the optic stands between the eye and the disc inside the window.
					assert_lte(z, disc_z + SLACK, "%s %s: housing in front of the disc (z %.4f, disc %.4f)" % [file, key, z, disc_z])
					# And the disc is just over the glass, not floating off it.
					assert_gt(z, disc_z - 0.002, "%s %s: the disc floats off the glass (z %.4f, disc %.4f)" % [file, key, z, disc_z])


func test_glass_radius_fits_inside_the_lens_and_the_config_names_all_three_optics() -> void:
	var root := _load("aeg")
	for key: StringName in OPTICS:
		assert_true(cfg.optic_glass_z.has(key) and cfg.optic_glass_radius.has(key) and cfg.optic_eye_back.has(key), "%s configured" % key)
		var m := _part(root, "optic_%s" % key)
		var lens := _surface_box(m, "LensDot" if key == &"redDot" else "Lens")
		var half := minf(lens.size.x, lens.size.y) * 0.5
		assert_lte(float(cfg.optic_glass_radius[key]), half, "%s glass radius inside its lens" % key)
		assert_gt(float(cfg.optic_glass_radius[key]), half * 0.4, "%s glass is not tiny against its lens" % key)
		assert_gt(float(cfg.optic_eye_back[key]), 0.0)
		assert_between(float(cfg.optic_glass_z[key]), m.get_aabb().position.z, m.get_aabb().end.z, "%s glass_z inside the optic" % key)


func test_every_torchs_beam_is_at_its_lens_on_every_replica() -> void:
	for file: String in FILES:
		var m := _part(_load(file), "light_weaponTorch")
		assert_not_null(m, "%s has the torch" % file)
		var beam := m.get_node("light_weaponTorch_Beam") as Node3D
		var lens := _surface_box(m, "TorchLens")
		assert_gt(lens.size.x, 0.0, "%s: TorchLens surface" % file)
		assert_almost_eq(beam.position.x, lens.get_center().x, 0.001, "%s beam x on the lens" % file)
		assert_almost_eq(beam.position.y, lens.get_center().y, 0.001, "%s beam y on the lens" % file)
		assert_lte(beam.position.z, lens.position.z + SLACK, "%s beam at or ahead of the lens face" % file)
		assert_gt(beam.position.z, lens.position.z - 0.005, "%s beam within 5 mm of the lens" % file)


func test_the_rifles_torch_is_turned_to_the_right_side_rail() -> void:
	for file: String in ["aeg", "sniper"]:
		var m := _part(_load(file), "light_weaponTorch")
		var beam := m.transform * (m.get_node("light_weaponTorch_Beam") as Node3D).position
		assert_gt(beam.x, 0.03, "%s: the lens is out on the right" % file)
		assert_lt(beam.z, m.position.z, "%s: it still points forward (-z)" % file)
		assert_gt(m.position.x + m.get_aabb().position.x, -0.02, "%s: clear of the left" % file)


func test_the_lasers_beam_is_at_its_emitter() -> void:
	var m := _part(_load("pistol"), "laser_redLaser")
	var beam := m.get_node("laser_redLaser_Beam") as Node3D
	var lens := _surface_box(m, "LaserLens")
	assert_gt(lens.size.y, 0.0, "LaserLens surface")
	assert_almost_eq(beam.position.x, lens.get_center().x, 0.001)
	assert_almost_eq(beam.position.y, lens.get_center().y, 0.001)
	assert_almost_eq(beam.position.z, lens.get_center().z, 0.002)


## Every vertex of a part, in its own space (x right, y up from the rail, -z forward).
func _verts(m: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in m.mesh.get_surface_count():
		out.append_array(m.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	return out


func test_the_laser_sits_flush_in_its_housing_with_nothing_standing_out_in_front() -> void:
	# The owner (2026-11-05): no cylinder standing out of the laser; the emitter flush in the attachment.
	var m := _part(_load("pistol"), "laser_redLaser")
	var verts := _verts(m)
	var front := INF
	for v in verts:
		front = minf(front, v.z)
	var lo := INF
	var hi := -INF
	for v in verts:
		if v.z < front + 0.004:
			lo = minf(lo, v.x)
			hi = maxf(hi, v.x)
	assert_gt(hi - lo, 0.024, "the front 4 mm is the housing's full width, not a tube")
	var beam := m.get_node("laser_redLaser_Beam") as Node3D
	assert_between(beam.position.z - front, 0.0, 0.002, "the emitter is just inside the front face")


func test_the_2x_scope_stands_low() -> void:
	# The owner (2026-11-05): less tall, then "as much as possible": the axis 26 mm over the rail (the first build's was
	# 46), as low as the AEG's receiver leaves the glass in clear view. The rifles' iron sights fold away and hide
	# under any optic (SightFold), so nothing meets the lowered belly.
	var m := _part(_load("aeg"), "optic_scope2x")
	var top := -INF
	for v in _verts(m):
		top = maxf(top, v.y)
	assert_lt(top, 0.056, "at least 19 mm lower than the first build")
	var line := m.get_node("optic_scope2x_SightLine") as Node3D
	assert_almost_eq(line.position.y, 0.026, 0.0005, "its sight line on the lowered axis")


func test_the_variable_scope_is_a_little_smaller() -> void:
	# The owner (2026-11-05): "a little smaller" than the first build's 146 mm.
	var m := _part(_load("aeg"), "optic_scopeVar")
	assert_between(m.get_aabb().size.z, 0.12, 0.135)
	# Shrunk towards the rail's face, so it sits as low on its neck as on the photo.
	var line := m.get_node("optic_scopeVar_SightLine") as Node3D
	assert_lt(line.position.y, 0.0300, "its sight line low over the clamp")


func test_the_sniper_carries_the_aegs_attachments_and_a_muzzle_at_its_own_barrel() -> void:
	var aeg := _load("aeg")
	var sniper := _load("sniper")
	for part_name: String in ["optic_redDot", "optic_scope2x", "optic_scopeVar", "grip_angled", "grip_vertical", "light_weaponTorch", "muzzle_silencer"]:
		var a := _part(aeg, part_name)
		var s := _part(sniper, part_name)
		assert_not_null(s, "sniper has %s" % part_name)
		if s != null:
			assert_eq(_tris(s), _tris(a), "%s is the AEG's model" % part_name)
	var end_a := _part(aeg, "muzzle_silencer").position
	var end_s := _part(sniper, "muzzle_silencer").position
	assert_lt(end_s.z, end_a.z - 0.1, "the sniper's silencer sits further out its longer barrel")
	assert_almost_eq(end_s.x, 0.0, 0.0001, "the sniper's silencer on the bore's plane")


func test_materials_are_named_and_replica_paint_leaves_the_glass_and_fibre_alone() -> void:
	var known: Array[String] = ["Detail", "Metal", "Rubber", "Accent", "Body", "Furniture", "Lens", "LensDot", "Fibre", "TorchLens", "Led", "LaserLens"]
	var untouched: Array[String] = ["Lens", "LensDot", "Fibre", "TorchLens", "Led", "LaserLens", "Rubber"]
	for file: String in FILES:
		var root := _load(file)
		for m: MeshInstance3D in _parts(root):
			if _kind(m) in ["barrel", "magazine"]:
				continue
			for i in m.mesh.get_surface_count():
				var nm := m.mesh.surface_get_material(i).resource_name
				assert_true(nm in known, "%s/%s surface %d: material '%s' is a known name" % [file, m.name, i, nm])
		for scheme: StringName in [&"cobalt", &"onyx"]:
			ReplicaPaint.apply(root, scheme, false)
			for node: Node in root.find_children("*", "MeshInstance3D", true, false):
				var mi := node as MeshInstance3D
				for i in mi.mesh.get_surface_count():
					if mi.mesh.surface_get_material(i).resource_name in untouched:
						assert_null(mi.get_surface_override_material(i), "%s/%s surface %d stays as modelled" % [file, mi.name, i])
