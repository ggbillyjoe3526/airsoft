extends GutTest
## WA1 QA: the shared light's two flags and the clear material, the greybox's sloping-ground tiles and the woods in the
## shared light on a built Woodland level, every bake fresh against the repainted kinds, the grid gone, and a Woodland
## level's build and free leaving no nodes behind.

var play: PlayTuning = PlayTuning.load_default()


func test_props_stay_linear_and_code_built_meshes_are_srgb() -> void:
	var prop := LookMaterials.vertex_colour(0.8, 0.0)
	assert_false(prop.get_shader_parameter(&"srgb_colours") as bool, "a glTF's colours are read as stored")
	var built := LookMaterials.vertex_colour(0.8, 0.0, Color.WHITE, true)
	assert_true(built.get_shader_parameter(&"srgb_colours") as bool, "a mesh built in code is sRGB")


func test_the_clear_material_carries_its_roughness_priority_and_alpha() -> void:
	var m := LookMaterials.clear_colour(0.25)
	assert_eq(m.shader, LookMaterials.CLEAR_SHADER)
	assert_almost_eq(m.get_shader_parameter(&"roughness") as float, 0.25, 1e-6)
	assert_eq(m.render_priority, Material.RENDER_PRIORITY_MIN)
	assert_true(m.shader.code.contains("ALPHA = COLOR.a"))


func test_the_map_style_has_no_grid_left() -> void:
	assert_false("grid_size" in play.map_style, "no grid size")
	assert_false("grid_shade" in play.map_style, "no grid shade")


func test_woodlands_sloping_ground_and_blocks_draw_in_the_shared_light() -> void:
	var m := MapData.load_map("woodland", play.map_style, 5)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, BodyConfig.new())
	var tiles := 0
	for n in level.find_children("*", "MeshInstance3D", true, false):
		var mat := (n as MeshInstance3D).material_override as ShaderMaterial
		assert_not_null(mat, "%s has a shader material" % n.name)
		if mat == null:
			continue
		tiles += 1
		assert_eq(mat.shader, LookMaterials.VERTEX_SHADER, "%s in the shared light" % n.name)
		assert_true(mat.get_shader_parameter(&"srgb_colours") as bool, "%s sRGB" % n.name)
	assert_gt(tiles, 1, "the greybox and ground tiles")


func test_every_bake_matches_the_repainted_kinds() -> void:
	var seen := 0
	for file in DirAccess.get_files_at(BakeConfig.DIR):
		if file.get_extension() != "res":
			continue
		seen += 1
		var found := false
		for mapfile in DirAccess.get_files_at(MapData.DIR):
			if mapfile.get_extension() != "json":
				continue
			var m := MapData.load_map(mapfile.get_basename(), play.map_style, 1)
			if m.baked_light_file.get_file().get_basename() != file.get_basename():
				continue
			found = true
			var bake := BakedLight.load_for(m)
			var sun := LightingConfig.for_map(play.lighting, null, m, LightingConfig.DAY)
			assert_eq(bake.source_hash, BakedLight.hash_of(m, play.map_style, sun, play.baked_light), "%s fresh" % m.id)
		assert_true(found, "%s belongs to a map" % file)
	assert_gte(seen, 2, "Depot's and the Range's")


func test_building_and_freeing_woodland_leaves_no_nodes() -> void:
	var m := MapData.load_map("woodland", play.map_style, 5)
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 3:
		var level := MapLevel.new()
		add_child(level)
		level.build(m, play.map_style, BodyConfig.new())
		var woods := WoodsView.build(m, play.woods, play.skyline, play.lighting, play.map_style)
		add_child(woods)
		var bushes := BushView.build(m, play.woods)
		if bushes != null:
			add_child(bushes)
			bushes.free()
		woods.free()
		level.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "no node left over")
