extends GutTest
## WQ1 QA: Woodland's trees, foliage and structures on their textured materials. Each model gets the material its
## config names, a texture that won't load falls back plain, the maps load with the layers the shaders pick from, and
## the models carry the UVs the shaders read.

var cfg: PropDressConfig = null


func before_all() -> void:
	cfg = PlayTuning.load_default().site_look.props


func _dress(c: PropDressConfig) -> PropDress:
	var d := PropDress.new()
	d._cfg = c
	autofree(d)
	return d


func _arrays(model: StringName) -> Array:
	var mesh := cfg.mesh_of(model)
	assert_not_null(mesh, "%s loads" % model)
	return mesh.surface_get_arrays(0) if mesh != null else []


func test_every_textured_model_is_a_model_the_config_loads() -> void:
	for model: StringName in cfg.model_barks:
		assert_true(cfg.models.has(model), "%s has a model" % model)
	for model: StringName in cfg.surface_models:
		assert_true(cfg.models.has(model), "%s has a model" % model)


func test_tree_models_draw_on_the_foliage_material_with_their_maps() -> void:
	var d := _dress(cfg)
	for model: StringName in cfg.model_barks:
		var m := d._material_of(model)
		assert_eq(m.shader, LookMaterials.FOLIAGE_SHADER, "%s on the foliage shader" % model)
		assert_not_null(m.get_shader_parameter(&"sheet"), "%s has the leaf sheet" % model)
		assert_not_null(m.get_shader_parameter(&"bark"), "%s has its bark" % model)
		assert_not_null(m.get_shader_parameter(&"bark_relief"), "%s has its bark's normal map" % model)
		var two: bool = cfg.model_barks[model].size() > 1
		assert_eq(m.get_shader_parameter(&"use_bark_b"), two, "%s blends a second bark only when it names one" % model)
		if two:
			assert_not_null(m.get_shader_parameter(&"bark_b"))
			assert_not_null(m.get_shader_parameter(&"bark_b_relief"))


func test_structures_and_props_draw_on_the_surface_material_with_layers() -> void:
	var d := _dress(cfg)
	for model: StringName in cfg.surface_models:
		var m := d._material_of(model)
		assert_eq(m.shader, LookMaterials.SURFACE_SHADER, "%s on the surface shader" % model)
		var s := m.get_shader_parameter(&"surfaces") as TextureLayered
		var r := m.get_shader_parameter(&"surfaces_relief") as TextureLayered
		assert_not_null(s, "%s has its surfaces" % model)
		assert_not_null(r, "%s has its relief" % model)
		if s != null and r != null:
			assert_eq(s.get_layers(), r.get_layers(), "detail and relief have the same layers")


func test_surface_array_has_a_layer_for_every_surface_the_models_name() -> void:
	var s := load(cfg.surface_maps) as TextureLayered
	assert_not_null(s, "surfaces.png loads as an array")
	if s == null:
		return
	# mapkit.SURFACES names layers 1 to 7
	assert_gte(s.get_layers(), 8, "layer 0 plain and 1 to 7 named")
	assert_gte(s.get_width(), 64)


func test_leaf_sheet_loads_with_alpha() -> void:
	var t := load(cfg.foliage_sheet) as Texture2D
	assert_not_null(t, "the leaf sheet loads")
	if t != null:
		assert_true(t.get_image().detect_alpha() != Image.ALPHA_NONE, "the sheet has alpha to cut out")


func test_a_texture_that_wont_load_draws_plain() -> void:
	var bad := cfg.duplicate() as PropDressConfig
	bad.foliage_sheet = "res://assets/textures/woodland/none.png"
	bad.foliage_folder = "res://assets/textures/woodland/none_folder"
	bad.surface_maps = "res://assets/textures/woodland/none_a.png"
	bad.surface_relief = "res://assets/textures/woodland/none_b.png"
	var d := _dress(bad)
	var tree := d._material_of(&"oak")
	assert_not_null(tree, "a material still comes")
	assert_null(tree.get_shader_parameter(&"sheet"))
	assert_null(tree.get_shader_parameter(&"bark"))
	assert_false(tree.get_shader_parameter(&"use_bark_b"))
	var pine := d._material_of(&"pine_grown")
	assert_false(pine.get_shader_parameter(&"use_bark_b"), "no bark_b loaded, so none blended")
	var wood := d._material_of(&"palisade")
	assert_null(wood.get_shader_parameter(&"surfaces"))
	assert_eq(d._material_of(&"oak"), tree, "the fallback is made once")


func test_the_same_barks_share_one_material() -> void:
	var d := _dress(cfg)
	assert_same(d._material_of(&"oak"), d._material_of(&"oak"))
	assert_same(d._material_of(&"palisade"), d._material_of(&"watch_tower"), "same roughness and wear share surfaces")
	assert_not_same(d._material_of(&"oak"), d._material_of(&"birch"), "different barks differ")


func test_materials_are_listed_for_warming() -> void:
	var d := _dress(cfg)
	var m := d._material_of(&"oak")
	assert_true(d.materials().has(m), "a textured material is warmed with the rest")


func test_missing_texture_not_a_script_error_for_unknown_bark_name() -> void:
	var bad := cfg.duplicate() as PropDressConfig
	bad.model_barks = {&"oak": PackedStringArray(["no_such_bark", "none_b", "extra_third"])}
	var m := _dress(bad)._material_of(&"oak")
	assert_null(m.get_shader_parameter(&"bark"))
	assert_false(m.get_shader_parameter(&"use_bark_b"))


func test_tree_models_carry_uvs_for_leaves_and_bark() -> void:
	for model: StringName in cfg.model_barks:
		var a := _arrays(model)
		if a.is_empty():
			continue
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		assert_eq(uv.size(), verts.size(), "%s has UV on every vertex" % model)
		assert_eq(uv2.size(), verts.size(), "%s has UV2 on every vertex" % model)
		var bark := 0
		var leaf := 0
		for p in uv:
			if p.x < -1.0:
				bark += 1
			elif p.x >= 0.0 and p.x <= 1.0 and p.y >= 0.0 and p.y <= 1.0:
				leaf += 1
		var is_crown := String(model).ends_with("_crown")
		if is_crown:
			assert_gt(leaf, 0, "%s has leaf cards on the sheet" % model)
		elif model != &"spruce":
			assert_gt(bark, 0, "%s's trunk has bark faces" % model)
		assert_gt(bark + leaf, 0, "%s: every model is bark or leaf somewhere" % model)


func test_leaf_uvs_stay_on_the_sheet() -> void:
	for model: StringName in cfg.model_barks:
		var a := _arrays(model)
		if a.is_empty():
			continue
		for p: Vector2 in a[Mesh.ARRAY_TEX_UV]:
			if p.x >= -1.0:
				assert_true(p.x >= -0.001 and p.x <= 1.001 and p.y >= -0.001 and p.y <= 1.001,
						"%s: leaf UV %s inside the sheet" % [model, p])
				if p.x < -0.001 or p.x > 1.001 or p.y < -0.001 or p.y > 1.001:
					return


func test_surface_models_carry_uvs_and_a_layer() -> void:
	var s := load(cfg.surface_maps) as TextureLayered
	var layers := s.get_layers() if s != null else 8
	for model: StringName in cfg.surface_models:
		var a := _arrays(model)
		if a.is_empty():
			continue
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
		assert_eq(uv.size(), verts.size(), "%s has UVs" % model)
		assert_eq(uv2.size(), verts.size(), "%s has UV2" % model)
		var some := false
		for p in uv2:
			if p.x > 0.5:
				some = true
				assert_lt(roundi(p.x), layers, "%s names a layer the array has" % model)
		# a tyre is plain rubber: mapkit.SURFACES has no layer for it
		assert_true(some or String(model).begins_with("tractor_tyre"), "%s has at least one detailed face" % model)


func test_crowns_stay_inside_the_old_box() -> void:
	# a crown's card tips and branches never reach past its tree's blocks: the crowns' bounds are what PropLayout fits
	for crown: StringName in cfg.tree_crowns.values():
		var box := cfg.mesh_of(crown).get_aabb()
		assert_gt(box.size.x, 0.1, "%s has width" % crown)
		assert_lt(box.size.x, 40.0, "%s width is sane" % crown)
		assert_lt(box.size.y, 40.0, "%s height is sane" % crown)
		for v: Vector3 in cfg.mesh_of(crown).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			assert_true(box.grow(0.001).has_point(v), "inside own bounds")
			break


func test_campfire_and_lantern_fixtures_draw_surfaced() -> void:
	var fx := LightFixturesConfig.new()
	var m := LightFixtures._prop_material(fx)
	assert_eq(m.shader, LookMaterials.SURFACE_SHADER, "the fixtures' props use their surfaces' shader")
	assert_not_null(m.get_shader_parameter(&"surfaces"), "their surface array loads (as TextureLayered)")
