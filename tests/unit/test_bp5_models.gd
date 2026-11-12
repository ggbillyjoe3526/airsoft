extends GutTest
## BP5, the second bug and performance pass: the bots' held replicas in fewer draws (HeldMerge). Each figure's replica
## is one mesh of one surface a material, its magazine in its well kept apart for the reloads, shared by every figure
## holding the same; beyond the far line a far version of one or two surfaces stands in for it, magazine and all. The
## moving models import with no part in baked light (GI static would let Ultra's scene GI voxelise them as level).

var figures: FigureConfig = PlayTuning.load_default().figures
var hits: HitConfig = HitConfig.new()


func after_each() -> void:
	HeldMerge.clear()


func _view(id: int = 1) -> FigureView:
	var c := Character.new(id, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.BLUE, hits, GameTheme.font(800), false, [], 0.0, figures)
	return v


func _materials(m: MeshInstance3D) -> int:
	var seen: Array[Material] = []
	for s in m.mesh.get_surface_count():
		var mat := m.mesh.surface_get_material(s)
		if not seen.has(mat):
			seen.append(mat)
	return seen.size()


func _shown_meshes(held: MeshInstance3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in held.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m.visible and m.name != "Far" and m.mesh != null:
			out.append(m)
	return out


func test_each_held_replica_is_one_surface_a_material_with_only_its_magazine_apart() -> void:
	var v := _view()
	var replicas: Array[MeshInstance3D] = v.get("_replicas")
	var wells: Array[MeshInstance3D] = v.get("_wells")
	assert_eq(replicas.size(), 2, "the rifle and the pistol")
	for i in replicas.size():
		var held := replicas[i]
		assert_not_null(held)
		assert_eq(held.mesh.get_surface_count(), _materials(held), "%s: a surface a material" % held.name)
		var shown := _shown_meshes(held)
		assert_eq(shown.size(), 1, "%s: only its magazine still drawn apart" % held.name)
		assert_eq(shown[0], wells[i], "and that is the magazine in its well")


func test_figures_holding_the_same_share_one_merged_mesh() -> void:
	var a: Array[MeshInstance3D] = _view(1).get("_replicas")
	var b: Array[MeshInstance3D] = _view(2).get("_replicas")
	assert_same(a[0].mesh, b[0].mesh, "the rifle's")
	assert_same(a[1].mesh, b[1].mesh, "the pistol's")
	assert_eq(HeldMerge.made_count(), 2, "made once each")


func test_the_far_version_takes_over_past_the_far_line_and_the_magazine_stays_its_own() -> void:
	var v := _view()
	var models := FigureModels.new(figures)
	models.load_kinds()
	v.set_body(models, 0, figures.lod_high)
	var replicas: Array[MeshInstance3D] = v.get("_replicas")
	var fars: Array[MeshInstance3D] = v.get("_fars")
	var wells: Array[MeshInstance3D] = v.get("_wells")
	for i in replicas.size():
		var far := fars[i]
		assert_not_null(far, "slot %d has a far version" % i)
		assert_true(far.visible)
		assert_lte(far.mesh.get_surface_count(), 3, "two or three draws out there")
		assert_eq(far.visibility_range_begin, figures.lod_high.y, "from the far line")
		assert_eq(replicas[i].visibility_range_end, figures.lod_high.y, "the whole replica up to it")
		assert_eq(wells[i].visibility_range_end, 0.0, "its magazine at every distance: a reload far off empties the well")
		assert_eq(_tris(far), _tris(replicas[i]), "the same triangles, the magazine not baked in")
	v.set_lod_lines(figures.lod_low)
	assert_eq(fars[0].visibility_range_begin, figures.lod_low.y, "a new preset's line")
	assert_eq(replicas[0].visibility_range_end, figures.lod_low.y)


func _tris(m: MeshInstance3D) -> int:
	var n := 0
	for s in m.mesh.get_surface_count():
		n += (m.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
	return n


func test_with_no_body_yet_the_far_version_stays_hidden() -> void:
	var fars: Array[MeshInstance3D] = _view().get("_fars")
	for far in fars:
		assert_false(far.visible, "no far line yet: only the whole replica draws")


func test_the_far_version_keeps_each_paint_s_colour() -> void:
	var v := _view()
	var replicas: Array[MeshInstance3D] = v.get("_replicas")
	var fars: Array[MeshInstance3D] = v.get("_fars")
	var albedos: Array[Color] = []
	for s in replicas[0].mesh.get_surface_count():
		var mat := replicas[0].mesh.surface_get_material(s) as BaseMaterial3D
		if HeldMerge._plain(mat):
			albedos.append(mat.albedo_color)
	var painted: PackedColorArray = PackedColorArray()
	for s in fars[0].mesh.get_surface_count():
		var arrays := fars[0].mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_COLOR] != null:
			painted.append_array(arrays[Mesh.ARRAY_COLOR])
	assert_gt(painted.size(), 0, "a surface of vertex colours")
	for albedo in albedos:
		var found := false
		for c in painted:
			if absf(c.r - albedo.r) < 0.01 and absf(c.g - albedo.g) < 0.01 and absf(c.b - albedo.b) < 0.01:
				found = true
				break
		assert_true(found, "%s is in it" % albedo)


func test_moving_models_take_no_part_in_baked_light() -> void:
	for path: String in ["res://assets/models/characters/human.glb", "res://assets/models/characters/robot.glb",
			"res://assets/models/replicas/aeg.glb", "res://assets/models/replicas/pistol.glb",
			"res://assets/models/replicas/sniper.glb", "res://assets/models/replicas/cyber.glb",
			"res://assets/models/replicaParts/aeg.glb", "res://assets/models/grenades/smoke.glb",
			"res://assets/models/grenades/flash.glb", "res://assets/models/effects/bb.glb"]:
		var scene := (load(path) as PackedScene).instantiate()
		for n: Node in scene.find_children("*", "GeometryInstance3D", true, false):
			assert_eq((n as GeometryInstance3D).gi_mode, GeometryInstance3D.GI_MODE_DISABLED, "%s %s" % [path, n.name])
		scene.free()


func test_a_paint_made_again_makes_the_merged_mesh_again() -> void:
	var a: Array[MeshInstance3D] = _view(1).get("_replicas")
	ReplicaPaint.clear()
	var b: Array[MeshInstance3D] = _view(2).get("_replicas")
	assert_ne(a[0].mesh, b[0].mesh, "not the one made with the old paints (ReplicaPaint let them go)")
	var c: Array[MeshInstance3D] = _view(3).get("_replicas")
	assert_same(b[0].mesh, c[0].mesh, "and the new one shared again")
	assert_eq(HeldMerge.made_count(), 4, "two each time")


func test_the_far_version_keeps_each_paint_s_finish_and_the_session_prewarms_its_paints() -> void:
	var replicas: Array[MeshInstance3D] = _view().get("_replicas")
	var fars: Array[MeshInstance3D] = _view(2).get("_fars")
	var warm := HeldMerge.far_materials()
	var far_paints: Array[BaseMaterial3D] = []
	for s in fars[0].mesh.get_surface_count():
		var m := fars[0].mesh.surface_get_material(s) as BaseMaterial3D
		# a far paint, not a model's own material that happens to multiply by vertex colours (MQ1: the importer sets
		# that on any material a mesh with surface kinds shares)
		if m != null and m.vertex_color_use_as_albedo and m.resource_name.begins_with(HeldMerge.FAR_PAINT_PREFIX):
			far_paints.append(m)
			assert_true(warm.has(m), "%s handed to ShaderPrewarm" % m.resource_name)
	assert_gt(far_paints.size(), 1, "more than one finish on the rifle")
	for s in replicas[0].mesh.get_surface_count():
		var near := replicas[0].mesh.surface_get_material(s) as BaseMaterial3D
		if not HeldMerge._plain(near):
			continue
		var kept := false
		for m in far_paints:
			kept = kept or (is_equal_approx(m.roughness, near.roughness) and is_equal_approx(m.metallic, near.metallic)
					and m.cull_mode == near.cull_mode)
		assert_true(kept, "%s's roughness %.2f, metallic %.2f and sides %d kept" % [near.resource_name,
				near.roughness, near.metallic, near.cull_mode])


func test_an_open_shell_drawn_from_both_sides_stays_so_far_off() -> void:
	var held := MeshInstance3D.new()
	add_child_autofree(held)
	var both := StandardMaterial3D.new()
	both.cull_mode = BaseMaterial3D.CULL_DISABLED
	var one := StandardMaterial3D.new()
	var mesh := ArrayMesh.new()
	for m: StandardMaterial3D in [both, one]:
		var t := SurfaceTool.new()
		t.begin(Mesh.PRIMITIVE_TRIANGLES)
		t.add_vertex(Vector3.ZERO)
		t.add_vertex(Vector3.RIGHT)
		t.add_vertex(Vector3.UP)
		t.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	held.mesh = mesh
	var far := HeldMerge.far_version(held, "test/open-shell")
	assert_eq(far.get_surface_count(), 2, "the two sides' paints apart")
	var culls: Array[int] = []
	for s in far.get_surface_count():
		culls.append((far.surface_get_material(s) as BaseMaterial3D).cull_mode)
	assert_true(culls.has(BaseMaterial3D.CULL_DISABLED), "the open shell still drawn from both sides")
	assert_true(culls.has(BaseMaterial3D.CULL_BACK))
