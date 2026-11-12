extends GutTest
## MQ1 QA: the surface shader's edges: models with no vertex colours, materials the file keeps, repainting back and
## forth, the cache caps, depth-pressed copies and leaks.

const MODEL := "res://assets/models/replicas/%s.glb"

var _nodes: Array[Node] = []


func before_each() -> void:
	ReplicaPaint.clear()


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	ReplicaPaint.clear()


## A one-triangle mesh whose surface 0 wears `own` and carries no vertex colours (a parts file).
func _bare_mesh(own: Material) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, own)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	_nodes.append(mi)
	return mi


func _own(part: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = part
	return m


func test_a_model_with_no_vertex_colours_draws_as_its_part_default() -> void:
	var furniture := _bare_mesh(_own("Furniture"))
	var metal := _bare_mesh(_own("Metal"))
	ReplicaPaint.apply(furniture, &"cobalt", false)
	ReplicaPaint.apply(metal, &"cobalt", false)
	var f := furniture.get_surface_override_material(0) as ShaderMaterial
	var m := metal.get_surface_override_material(0) as ShaderMaterial
	assert_true(ReplicaPaint.is_surface(f))
	assert_true(ReplicaPaint.is_surface(m))
	assert_eq(int(f.get_shader_parameter(&"default_kind")), ReplicaSurfaces.index(&"polymer"))
	assert_eq(int(m.get_shader_parameter(&"default_kind")), ReplicaSurfaces.index(&"steel"))


func test_repainting_back_and_forth_gives_the_same_shared_materials() -> void:
	var mi := _bare_mesh(_own("Body"))
	ReplicaPaint.apply(mi, &"cobalt", false)
	var first := mi.get_surface_override_material(0)
	ReplicaPaint.apply(mi, &"tan", false)
	var second := mi.get_surface_override_material(0)
	assert_ne(first, second)
	ReplicaPaint.apply(mi, &"cobalt", false)
	assert_eq(mi.get_surface_override_material(0), first, "no new material per repaint")
	assert_eq(ReplicaPaint.surface_materials().size(), 2, "two paints, two materials kept")


func test_a_cap_overflow_keeps_every_drawn_material_working() -> void:
	var mi := _bare_mesh(_own("Body"))
	ReplicaPaint.apply(mi, &"cobalt", false)
	for n in ReplicaPaint.MAX_SURFACED + 5:
		var tex := PlaceholderTexture2D.new()
		ReplicaPaint._surface_of(ReplicaPaint.materials(&"tan", false)[0], tex, n % 8)
	assert_lte(ReplicaPaint.surface_materials().size(), ReplicaPaint.MAX_SURFACED, "capped")
	var held := mi.get_surface_override_material(0)
	assert_true(ReplicaPaint.is_surface(held), "a material already on a mesh stays a surface after the cache clears")
	assert_not_null(ReplicaPaint.plain_of(held))


func test_a_depth_pressed_copy_is_still_a_surface_with_its_plain_paint() -> void:
	var mi := _bare_mesh(_own("Body"))
	ReplicaPaint.apply(mi, &"cobalt", false)
	var drawn := mi.get_surface_override_material(0) as ShaderMaterial
	var copy := drawn.duplicate() as ShaderMaterial
	assert_true(ReplicaPaint.is_surface(copy))
	assert_eq(ReplicaPaint.plain_of(copy), ReplicaPaint.plain_of(drawn), "plain_of survives duplicate")
	assert_eq(ReplicaPaint.is_worn(copy), ReplicaPaint.is_worn(drawn))


func test_a_see_through_or_textured_own_colour_is_left_as_the_file_has_it() -> void:
	var glass := _own("CyberGlass")
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := _bare_mesh(glass)
	ReplicaPaint.apply(mi, ReplicaSchemes.OWN, false)
	assert_null(mi.get_surface_override_material(0), "alpha material untouched")
	var textured := _own("CyberTex")
	textured.albedo_texture = PlaceholderTexture2D.new()
	var mt := _bare_mesh(textured)
	ReplicaPaint.apply(mt, ReplicaSchemes.OWN, false)
	assert_null(mt.get_surface_override_material(0), "textured material untouched")


func test_painting_and_freeing_a_replica_leaves_no_orphans() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 3:
		var model := (load(MODEL % "aeg") as PackedScene).instantiate()
		ReplicaPaint.apply(model, &"cobalt", false)
		ReplicaPaint.apply(model, &"tan", true)
		model.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)
	var cached := ReplicaPaint.surface_materials().size()
	for i in 3:
		var model := (load(MODEL % "aeg") as PackedScene).instantiate()
		ReplicaPaint.apply(model, &"cobalt", false)
		model.free()
	assert_eq(ReplicaPaint.surface_materials().size(), cached, "more copies add no cached materials")


## Every vertex colour alpha in the replica and part files, as a kind slot (alpha * SLOTS): a whole number below the
## kinds' count, or 16 (no kind). A file still cut for 8 slots would read as a different kind.
func _glbs(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".glb"):
			out.append(dir.path_join(f))
	return out


func _slots_in(node: Node, bad: Array[String], path: String) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var colours: Variant = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
			if colours is PackedColorArray:
				for c in (colours as PackedColorArray):
					var slot := c.a * float(ReplicaSurfaces.SLOTS)
					if absf(slot - roundf(slot)) > 0.2 or int(roundf(slot)) > ReplicaSurfaces.SLOTS \
							or (int(roundf(slot)) >= ReplicaSurfaces.KINDS.size() and int(roundf(slot)) != ReplicaSurfaces.SLOTS):
						bad.append("%s %s %f" % [path, node.name, c.a])
						return
	for child in node.get_children():
		_slots_in(child, bad, path)


func test_every_replica_and_part_file_names_kinds_in_sixteenths_or_none() -> void:
	var bad: Array[String] = []
	var files: Array[String] = _glbs("res://assets/models/replicas") + _glbs("res://assets/models/replicaParts")
	assert_gt(files.size(), 5)
	for p in files:
		var scene := load(p) as PackedScene
		var root := scene.instantiate()
		_slots_in(root, bad, p)
		root.free()
	assert_eq(bad, [] as Array[String], "files still cut for another slot count")


func test_all_four_kind_tables_are_the_shaders_length() -> void:
	var m := ShaderMaterial.new()
	ReplicaSurfaces.dress(m)
	for t: StringName in [&"kind_finish", &"kind_grain", &"kind_tone", &"kind_shine"]:
		assert_eq((m.get_shader_parameter(t) as Array).size(), ReplicaSurfaces.SLOTS, str(t))
	var src := FileAccess.get_file_as_string("res://game/play/replica_surface.gdshaderinc")
	assert_true(src.contains("KINDS = %d;" % ReplicaSurfaces.SLOTS))
