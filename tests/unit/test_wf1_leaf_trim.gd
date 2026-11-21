extends GutTest
## WF1: Woodland's tree crowns' leaf cards trimmed to the leaves they draw (LeafTrim, LeafTrimSheet,
## tools/textures/leaf_trim.py). The sheet's rectangles hold every texel the foliage shader can draw up to their mip,
## a trimmed crown keeps its triangles, box, levels of detail and material, each trimmed corner opens back out to the
## card's original corner exactly (CUSTOM0, CUSTOM1), the leaves stay on their cards' planes and inside their cells'
## rectangles, the solid faces come first, and the dress lays every model as before.

const SHEET := "res://assets/textures/woodland/leaves.png"
## The finest mip level read from the sheet here (the full sheet is 2048 square: four million texels a level 0 pass).
const FINEST := 2
## How far a stored UV may lie from its exact place: the importer packs a surface's UVs to 16 bits over its largest
## (the crowns' tiled bark runs to about 8, a step of about 2.5e-4), and a trimmed surface is packed again.
const UV_STEP := 5e-4

var cfg: PropDressConfig = null
var trim: LeafTrimSheet = null


func before_all() -> void:
	cfg = PlayTuning.load_default().site_look.props
	trim = cfg.leaf_trim()


func _crowns() -> Array[StringName]:
	var out: Array[StringName] = []
	for model: StringName in cfg.model_barks:
		if String(model).ends_with("_crown"):
			out.append(model)
	return out


func test_the_sheet_trim_loads_with_a_rectangle_for_every_cell() -> void:
	assert_not_null(trim, "the leaf sheet's trim loads")
	if trim == null:
		return
	assert_eq(trim.rects.size(), trim.grid * trim.grid, "a rectangle a cell")
	for row in trim.grid:
		for col in trim.grid:
			var r := trim.rect_of(Vector2i(col, row))
			if row == trim.grid - 1:
				assert_false(r.has_area(), "the masses' and twigs' row is drawn whole (cell %d,%d)" % [col, row])
				continue
			assert_true(r.has_area(), "card cell %d,%d has a rectangle" % [col, row])
			assert_true(Rect2(0, 0, 1, 1).encloses(r), "cell %d,%d's rectangle lies in its cell" % [col, row])
	assert_eq(trim.rect_of(Vector2i(-1, 0)), Rect2(), "outside the sheet: none")
	assert_eq(trim.rect_of(Vector2i(0, trim.grid)), Rect2(), "outside the sheet: none")


## Every texel a card can draw at the rectangles' mip or finer (its alpha grown as look_foliage.gdshader grows it, a
## level more than its own, so a read between two levels counts) lies inside its cell's rectangle.
func test_the_rectangles_hold_every_texel_the_shader_draws() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	assert_not_null(image, "the leaf sheet's source loads")
	if image == null or trim == null:
		return
	image.convert(Image.FORMAT_RGBA8)
	image.generate_mipmaps()
	var cover := PropDress.MIP_COVER
	var cut := 0.5
	var outside := 0
	for level in range(FINEST, int(trim.max_mip) + 1):
		var size := image.get_width() >> level
		var data := image.get_data().slice(image.get_mipmap_offset(level), image.get_mipmap_offset(level)
				+ size * size * 4)
		var cell_size := size / trim.grid
		for y in size:
			for x in size:
				var a := data[(y * size + x) * 4 + 3] / 255.0
				if a * (1.0 + (level + 1) * cover) < cut:
					continue
				var cell := Vector2i(x / cell_size, y / cell_size)
				var r := trim.rect_of(cell)
				if not r.has_area():
					continue
				var at := (Vector2(x + 0.5, y + 0.5) / float(cell_size)) - Vector2(cell)
				if not r.grow(0.5 / float(cell_size)).has_point(at):
					outside += 1
	assert_eq(outside, 0, "no drawn texel lies outside its cell's rectangle")


func test_a_trimmed_crown_keeps_its_triangles_box_and_levels() -> void:
	for model in _crowns():
		var mesh := cfg.mesh_of(model)
		var drawn := cfg.drawn_mesh_of(model)
		assert_ne(drawn, mesh, "%s is trimmed" % model)
		assert_eq(drawn.get_surface_count(), mesh.get_surface_count(), "%s keeps its surfaces" % model)
		var before := RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
		var after := RenderingServer.mesh_get_surface(drawn.get_rid(), 0)
		assert_eq(after["index_count"], before["index_count"], "%s keeps its triangles" % model)
		assert_eq((after["lods"] as Array).size(), (before["lods"] as Array).size(), "%s keeps its levels" % model)
		assert_true(drawn.get_aabb().is_equal_approx(mesh.get_aabb()), "%s keeps its box" % model)
		assert_eq(drawn.surface_get_material(0), mesh.surface_get_material(0), "%s keeps its material" % model)
		assert_eq(cfg.drawn_mesh_of(model), drawn, "%s is trimmed once" % model)


func test_every_trimmed_corner_opens_back_to_its_original_corner() -> void:
	for model in _crowns():
		var a := cfg.mesh_of(model).surface_get_arrays(0)
		var b := cfg.drawn_mesh_of(model).surface_get_arrays(0)
		var at0: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uv0: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var at1: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
		var uv1: PackedVector2Array = b[Mesh.ARRAY_TEX_UV]
		var grow: PackedFloat32Array = b[Mesh.ARRAY_CUSTOM0]
		var grow_uv: PackedFloat32Array = b[Mesh.ARRAY_CUSTOM1]
		var moved := 0
		var wrong := 0
		var inside := 0
		for i in at0.size():
			var d := Vector3(grow[i * 4], grow[i * 4 + 1], grow[i * 4 + 2])
			var e := Vector2(grow_uv[i * 4], grow_uv[i * 4 + 1])
			if not d.is_zero_approx() or not e.is_zero_approx():
				moved += 1
				var cell := Vector2i(floori(uv1[i].x * trim.grid), floori(uv1[i].y * trim.grid))
				var r := trim.rect_of(cell)
				var local := uv1[i] * float(trim.grid) - Vector2(cell)
				inside += 1 if r.grow(UV_STEP * trim.grid).has_point(local) else 0
			# the corner as drawn, opened all the way out, is the corner the model was built with
			if (at1[i] + d).distance_to(at0[i]) > 1e-3 or (uv1[i] + e).distance_to(uv0[i]) > UV_STEP:
				wrong += 1
		assert_gt(moved, 0, "%s has trimmed corners" % model)
		assert_eq(wrong, 0, "%s: every corner opens back to where it was" % model)
		assert_eq(inside, moved, "%s: every trimmed corner lies in its cell's rectangle" % model)


func test_a_trimmed_card_stays_on_its_own_plane() -> void:
	var model := &"oak_crown"
	var b := cfg.drawn_mesh_of(model).surface_get_arrays(0)
	var at: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
	var grow: PackedFloat32Array = b[Mesh.ARRAY_CUSTOM0]
	var idx: PackedInt32Array = b[Mesh.ARRAY_INDEX]
	var off := 0
	for t in idx.size() / 3:
		var i := idx[t * 3]
		if is_zero_approx(grow[i * 4]) and is_zero_approx(grow[i * 4 + 1]) and is_zero_approx(grow[i * 4 + 2]):
			continue
		# each trimmed triangle's corners, opened out, lie on the plane of its corners as drawn
		var p: Array[Vector3] = [at[idx[t * 3]], at[idx[t * 3 + 1]], at[idx[t * 3 + 2]]]
		var n := (p[1] - p[0]).cross(p[2] - p[0])
		if n.length_squared() <= 0.0:
			continue
		n = n.normalized()
		for k in 3:
			var j := idx[t * 3 + k]
			var opened := at[j] + Vector3(grow[j * 4], grow[j * 4 + 1], grow[j * 4 + 2])
			if absf(n.dot(opened - p[0])) > 2e-3:
				off += 1
	assert_eq(off, 0, "an oak crown's trimmed cards open along their own planes")


func test_the_solid_faces_come_before_the_cards() -> void:
	for model in _crowns() + ([&"spruce"] as Array[StringName]):
		var b := cfg.drawn_mesh_of(model).surface_get_arrays(0)
		var uv: PackedVector2Array = b[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = b[Mesh.ARRAY_INDEX]
		var card_seen := false
		var late := 0
		for t in idx.size() / 3:
			var mid := (uv[idx[t * 3]] + uv[idx[t * 3 + 1]] + uv[idx[t * 3 + 2]]) / 3.0
			var bark := mid.x < LeafTrim.BARK_BELOW
			var whole := not bark and not trim.rect_of(Vector2i(floori(mid.x * trim.grid),
					floori(mid.y * trim.grid))).has_area()
			if bark or whole:
				late += 1 if card_seen else 0
			else:
				card_seen = true
		assert_eq(late, 0, "%s draws its bark and cores before its cards" % model)


func test_a_model_without_cards_is_left_as_it_is() -> void:
	for model: StringName in [&"oak", &"pine_old", &"birch"]:
		assert_eq(cfg.drawn_mesh_of(model), cfg.mesh_of(model), "%s (bark only) is drawn as loaded" % model)
	assert_eq(cfg.drawn_mesh_of(&"crate"), cfg.mesh_of(&"crate"), "a crate (no leaves) is drawn as loaded")
	assert_eq(LeafTrim.trimmed(cfg.mesh_of(&"oak_crown"), null), cfg.mesh_of(&"oak_crown"), "no sheet: as loaded")


func test_no_trim_named_draws_the_cards_whole() -> void:
	var plain := cfg.duplicate() as PropDressConfig
	plain.foliage_trim = ""
	assert_null(plain.leaf_trim(), "no trim named, none loads")
	assert_eq(plain.drawn_mesh_of(&"oak_crown"), plain.mesh_of(&"oak_crown"), "cards drawn whole")


func test_the_dress_draws_the_trimmed_crowns_and_lays_them_as_before() -> void:
	var play := PlayTuning.load_default()
	var map := MapData.load_map("woodland", play.map_style, SimTuning.load_default().rounds.team_size)
	var dress := PropDress.build(map, cfg, play.site_look.prop_paint)
	add_child_autofree(dress)
	var plain := cfg.duplicate() as PropDressConfig
	plain.foliage_trim = ""
	var whole := PropDress.build(map, plain, play.site_look.prop_paint)
	add_child_autofree(whole)
	for model in _crowns():
		assert_eq(dress.mesh_of(model), cfg.drawn_mesh_of(model), "%s drawn trimmed" % model)
		assert_eq(dress.placed()[model].transforms, whole.placed()[model].transforms, "%s laid as before" % model)
		var m := dress._material_of(model)
		var lod: float = cfg.model_alpha_lod.get(model, PropDress.ALPHA_LOD)
		if lod + 1.0 <= trim.max_mip:
			assert_eq(m.get_shader_parameter(&"trim_mip"), PropDress.TRIM_NEVER_OPENS,
					"%s (cut-out read no coarser than mip %d) stays trimmed far off" % [model, lod])
		else:
			assert_eq(m.get_shader_parameter(&"trim_mip"), trim.max_mip, "%s opens out before the trim's mip" % model)
		for view in dress.views_of(model):
			assert_eq(view.multimesh.mesh, cfg.drawn_mesh_of(model), "%s's every chunk draws it" % model)


func test_the_levels_of_detail_draw_their_solid_faces_first_too() -> void:
	for model in _crowns():
		var drawn := cfg.drawn_mesh_of(model)
		var uv: PackedVector2Array = drawn.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		var lods: Array = RenderingServer.mesh_get_surface(drawn.get_rid(), 0)["lods"]
		assert_gt(lods.size(), 0, "%s has levels of detail" % model)
		for lod: Dictionary in lods:
			var bytes: PackedByteArray = lod["index_data"]
			var card_seen := false
			var late := 0
			for t in bytes.size() / 6:
				var mid := Vector2.ZERO
				for k in 3:
					mid += uv[bytes.decode_u16((t * 3 + k) * 2)] / 3.0
				var solid := mid.x < LeafTrim.BARK_BELOW or not trim.rect_of(Vector2i(floori(mid.x * trim.grid),
						floori(mid.y * trim.grid))).has_area()
				if solid:
					late += 1 if card_seen else 0
				else:
					card_seen = true
			assert_eq(late, 0, "%s's level at %.2f draws its bark and cores first" % [model, lod["edge_length"]])


func test_a_card_sharing_a_corner_with_another_face_is_kept_whole() -> void:
	var c := 1.0 / float(trim.grid)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0),
			Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(-1, -1, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK,
			Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, c), Vector2(c, c), Vector2(c, 0), Vector2(0, 0),
			Vector2(-3, 0), Vector2(-3, 1)])
	# the card (cell 0,0) and a bark face that shares its first corner
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 0, 4, 5])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var out := LeafTrim.trimmed(mesh, trim)
	var b := out.surface_get_arrays(0)
	assert_null(b[Mesh.ARRAY_CUSTOM0], "the card isn't trimmed")
	assert_eq(b[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_VERTEX], "no corner moves")
	assert_eq((b[Mesh.ARRAY_INDEX] as PackedInt32Array).slice(0, 3), PackedInt32Array([0, 4, 5]), "the bark face first")
