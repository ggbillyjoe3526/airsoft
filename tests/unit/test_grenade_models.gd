extends GutTest
## The smoke and flash bombs' models (BL9): each file loads as one mesh with its long axis up through its middle, sized
## as GrenadeView lays it, inside the budget (docs/CC0_ASSETS.md › Grenade models), and its Kind material painted in
## the kind's own colour, so the stripe and band match the HUD.

const MAX_TRIANGLES := 5500
## Each kind's body (m): about this long, and this far from its axis.
const LENGTHS: Array[float] = [0.0, 0.140, 0.130]
const LENGTH_SLACK := 0.012
const KINDS: Array[int] = [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]

var cfg: GrenadeConfig = SimTuning.new().grenades


func _view() -> GrenadeView:
	var v := GrenadeView.new()
	add_child_autofree(v)
	v.setup(2, cfg, false)
	return v


func _triangles(mesh: Mesh) -> int:
	var count := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		count += (index.size() if not index.is_empty() else verts.size()) / 3
	return count


func test_each_model_loads_as_one_mesh() -> void:
	for kind: int in KINDS:
		var mesh := PropDressConfig.load_mesh(GrenadeView.MODELS[kind])
		assert_not_null(mesh, "%s loads" % GrenadeView.MODELS[kind])
		assert_true(mesh is ArrayMesh, "a modelled mesh, not the stand-in canister")


func test_each_model_stands_up_its_axis_through_its_middle_at_life_size() -> void:
	for kind: int in KINDS:
		var box := PropDressConfig.load_mesh(GrenadeView.MODELS[kind]).get_aabb()
		var body := GrenadeView.LIE_RADII[kind]
		assert_almost_eq(box.size.y, LENGTHS[kind], LENGTH_SLACK, "kind %d's length" % kind)
		assert_almost_eq(box.get_center().y, 0.0, LENGTH_SLACK, "its middle on the origin")
		assert_gt(box.size.y, box.size.x, "long axis up")
		assert_gt(box.size.x, body * 2.0 - 0.001, "its body as wide as it lies on")


func test_each_model_is_within_the_triangle_budget() -> void:
	for kind: int in KINDS:
		var tris := _triangles(PropDressConfig.load_mesh(GrenadeView.MODELS[kind]))
		assert_lt(tris, MAX_TRIANGLES, "kind %d: %d triangles" % [kind, tris])


func test_the_kind_material_takes_the_kinds_colour() -> void:
	var v := _view()
	for kind: int in KINDS:
		var mesh := v.mesh_of(kind)
		var painted := 0
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as StandardMaterial3D
			if m != null and m.albedo_color.is_equal_approx(GrenadeView.BODY_COLOURS[kind]):
				painted += 1
		assert_eq(painted, 1, "kind %d: one surface in its own colour" % kind)


func test_the_view_paints_its_own_copy_and_leaves_the_loaded_model_alone() -> void:
	var v := _view()
	var own := PropDressConfig.load_mesh(GrenadeView.MODELS[Grenade.Kind.FLASH])
	var drawn := v.mesh_of(Grenade.Kind.FLASH)
	assert_ne(own, drawn, "the view draws its own copy")
	for i in own.get_surface_count():
		if own.surface_get_material(i).resource_name == GrenadeView.KIND_MATERIAL:
			assert_ne(own.surface_get_material(i), drawn.surface_get_material(i), "the file's own Kind material kept")


func test_a_kind_with_no_model_draws_a_plain_canister() -> void:
	var v := _view()
	assert_true(v.mesh_of(Grenade.Kind.NONE) is CylinderMesh)


func test_the_view_prewarms_every_material_its_models_draw() -> void:
	var v := _view()
	var materials := v.materials()
	for kind: int in KINDS:
		var mesh := v.mesh_of(kind)
		for i in mesh.get_surface_count():
			assert_has(materials, mesh.surface_get_material(i))
