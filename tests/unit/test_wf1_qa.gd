extends GutTest
## WF1 QA: LeafTrim on small hand-built meshes (shared corners, several surfaces, missing arrays, odd cards) and the
## config's trim loading.

const CELL := 0.25


func _sheet() -> LeafTrimSheet:
	var s := LeafTrimSheet.new()
	s.grid = 4
	var r: Array[Rect2] = []
	for i in 16:
		r.append(Rect2(0.25, 0.25, 0.5, 0.5) if i == 0 else Rect2())
	s.rects = r
	return s


## A card filling cell 0 (vertices 0..3, indices 0..5), a unit square at z 0.
func _card_arrays() -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)])
	a[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(CELL, 0), Vector2(0, CELL), Vector2(CELL, CELL)])
	a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
	return a


func _mesh(arrays: Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _append_tri(a: Array, p: Array[Vector3], uv: Array[Vector2], shared: int) -> void:
	# one more triangle: vertex `shared` of the card plus two new vertices
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var u: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var base := v.size()
	for k in 2:
		v.append(p[k])
		n.append(Vector3.BACK)
		u.append(uv[k])
	idx.append_array(PackedInt32Array([shared, base, base + 1]))
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = n
	a[Mesh.ARRAY_TEX_UV] = u
	a[Mesh.ARRAY_INDEX] = idx


func test_a_plain_card_is_trimmed_to_its_cells_rectangle() -> void:
	var out := LeafTrim.trimmed(_mesh(_card_arrays()), _sheet())
	var b := out.surface_get_arrays(0)
	var uv: PackedVector2Array = b[Mesh.ARRAY_TEX_UV]
	var box := Rect2(uv[0], Vector2.ZERO)
	for i in 4:
		box = box.expand(uv[i])
	assert_almost_eq(box.size.x, CELL * 0.5, 2e-3, "the card is half a cell wide now")
	assert_not_null(b[Mesh.ARRAY_CUSTOM0], "its way back out is stored")


func _uses(idx: PackedInt32Array, t: int, v: int) -> bool:
	return idx[t * 3] == v or idx[t * 3 + 1] == v or idx[t * 3 + 2] == v


func test_a_surface_without_uv_is_returned_as_it_is() -> void:
	var a := _card_arrays()
	a[Mesh.ARRAY_TEX_UV] = null
	var m := _mesh(a)
	assert_eq(LeafTrim.trimmed(m, _sheet()), m)


func test_a_surface_without_normals_is_returned_as_it_is() -> void:
	var a := _card_arrays()
	a[Mesh.ARRAY_NORMAL] = null
	var m := _mesh(a)
	assert_eq(LeafTrim.trimmed(m, _sheet()), m)


func test_colours_and_tangents_stay_the_size_of_the_vertices() -> void:
	var a := _card_arrays()
	a[Mesh.ARRAY_COLOR] = PackedColorArray([Color.RED, Color.GREEN, Color.BLUE, Color.WHITE])
	var t := PackedFloat32Array()
	for i in 4:
		t.append_array(PackedFloat32Array([1, 0, 0, 1]))
	a[Mesh.ARRAY_TANGENT] = t
	var out := LeafTrim.trimmed(_mesh(a), _sheet())
	var b := out.surface_get_arrays(0)
	var n := (b[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	assert_eq((b[Mesh.ARRAY_COLOR] as PackedColorArray).size(), n)
	assert_eq((b[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size(), n * 4)
	assert_eq((b[Mesh.ARRAY_NORMAL] as PackedVector3Array).size(), n)
	assert_eq((b[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size(), n)
	assert_eq((b[Mesh.ARRAY_CUSTOM0] as PackedFloat32Array).size(), n * 4)


func test_each_surface_keeps_its_material_and_untrimmed_ones_stay_whole() -> void:
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _card_arrays())
	var plain := _card_arrays()
	plain[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(-3, 0), Vector2(-2, 0), Vector2(-3, 1), Vector2(-2, 1)])
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plain)
	var mat_a := StandardMaterial3D.new()
	var mat_b := StandardMaterial3D.new()
	m.surface_set_material(0, mat_a)
	m.surface_set_material(1, mat_b)
	var out := LeafTrim.trimmed(m, _sheet())
	assert_eq(out.get_surface_count(), 2)
	assert_eq(out.surface_get_material(0), mat_a)
	assert_eq(out.surface_get_material(1), mat_b)
	assert_null(out.surface_get_arrays(1)[Mesh.ARRAY_CUSTOM0], "a bark-only surface carries no custom data")
	assert_eq(out.surface_get_arrays(1)[Mesh.ARRAY_VERTEX], plain[Mesh.ARRAY_VERTEX], "and is not moved")


func test_a_degenerate_card_is_kept_whole() -> void:
	var a := _card_arrays()
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.1, 0.1), Vector2(0.1, 0.1), Vector2(0.1, 0.1), Vector2(0.1, 0.1)])
	var m := _mesh(a)
	assert_eq(LeafTrim.trimmed(m, _sheet()), m)
	var b := _card_arrays()
	b[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	var m2 := _mesh(b)
	assert_eq(LeafTrim.trimmed(m2, _sheet()), m2, "a card of no area in space")


func test_a_rotated_card_on_the_sheet_is_kept_whole() -> void:
	var a := _card_arrays()
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.125, 0), Vector2(0.25, 0.125), Vector2(0, 0.125),
			Vector2(0.125, 0.25)])
	var m := _mesh(a)
	assert_eq(LeafTrim.trimmed(m, _sheet()), m)


func test_a_card_straddling_two_cells_is_not_cut_to_one_cells_rectangle() -> void:
	var a := _card_arrays()
	# spans cells 0 and 1 (x 0 to 0.5), its centre on the border
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(0.5, 0), Vector2(0, CELL), Vector2(0.5, CELL)])
	var m := _mesh(a)
	var out := LeafTrim.trimmed(m, _sheet())
	if out == m:
		assert_true(true)
		return
	var uv: PackedVector2Array = out.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var lo := minf(minf(uv[0].x, uv[1].x), minf(uv[2].x, uv[3].x))
	assert_almost_eq(lo, 0.0, 1e-3, "cell 0's leaves left of the cut are still drawn")


func test_an_empty_or_missing_trim_draws_the_cards_whole() -> void:
	var m := _mesh(_card_arrays())
	assert_eq(LeafTrim.trimmed(m, LeafTrimSheet.new()), m, "a sheet with no rectangles")
	assert_eq(LeafTrim.trimmed(null, _sheet()), null)
	var cfg := PlayTuning.load_default().site_look.props.duplicate() as PropDressConfig
	cfg.foliage_trim = "res://assets/textures/woodland/none.tres"
	assert_null(cfg.leaf_trim())
	assert_eq(cfg.drawn_mesh_of(&"oak_crown"), cfg.mesh_of(&"oak_crown"), "no trim loads: drawn as loaded")


func test_a_duplicated_config_trims_for_itself_and_caches() -> void:
	var base := PlayTuning.load_default().site_look.props
	var copy := base.duplicate() as PropDressConfig
	var a := copy.drawn_mesh_of(&"oak_crown")
	assert_eq(copy.drawn_mesh_of(&"oak_crown"), a, "cut once a config")
	assert_ne(a, copy.mesh_of(&"oak_crown"))
	assert_eq(copy.drawn_mesh_of(&"oak_crown").get_aabb(), copy.mesh_of(&"oak_crown").get_aabb(), "same box")


func test_trimming_leaves_no_orphans_behind() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 5:
		LeafTrim.trimmed(_mesh(_card_arrays()), _sheet())
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


## A trimmed corner belongs to its card alone: no other face of a real crown uses it (it would be pulled in too).
func test_no_real_crowns_trimmed_corner_is_used_by_a_face_that_is_not_its_card() -> void:
	var cfg := PlayTuning.load_default().site_look.props
	var shared := 0
	for model: StringName in cfg.model_barks:
		if not String(model).ends_with("_crown"):
			continue
		var b := cfg.drawn_mesh_of(model).surface_get_arrays(0)
		var g1: Variant = b[Mesh.ARRAY_CUSTOM1]
		if g1 == null:
			continue
		var grow: PackedFloat32Array = g1
		var idx: PackedInt32Array = b[Mesh.ARRAY_INDEX]
		var uses := {}
		for i in idx.size():
			uses[idx[i]] = int(uses.get(idx[i], 0)) + 1
		for v: int in uses:
			if (grow[v * 4] != 0.0 or grow[v * 4 + 1] != 0.0) and int(uses[v]) > 2:
				shared += 1 # a card's corner is in 1 or 2 index entries; 3 or more means another face
	assert_eq(shared, 0, "trimmed corners used by faces beyond their own card")
