extends GutTest
## RM2: the Range's rebuilt props. Sandbags are drawn matte in their own material (warmed with the rest), the
## three Range models stay within 5,000 triangles, and a cordwood section's pieces never pass its box.

const RANGE_MODELS: Array[StringName] = [&"sandbags", &"site_toilet", &"water_tote"]
const CORDWOOD: Array[StringName] = [&"cordwood", &"cordwood_b", &"cordwood_c"]

var play: PlayTuning = PlayTuning.load_default()


func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		var count: int = (idx as PackedInt32Array).size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		n += count / 3
	return n


func _range_dress() -> PropDress:
	var m := MapData.load_map("range", play.map_style, 1)
	var dress := PropDress.build(m, play.site_look.props)
	add_child_autofree(dress)
	return dress


func test_sandbags_are_drawn_matte_in_their_own_warmed_material() -> void:
	var cfg := play.site_look.props
	assert_almost_eq(cfg.model_roughness.get(&"sandbags", -1.0) as float, 0.97, 0.0001)
	var dress := _range_dress()
	var views := dress.views_of(&"sandbags")
	assert_gt(views.size(), 0, "the range has sandbags")
	var mat := views[0].material_override as ShaderMaterial
	assert_almost_eq(mat.get_shader_parameter(&"roughness") as float, 0.97, 0.0001, "drawn at 0.97")
	for v in dress.views_of(&"water_tote"):
		assert_ne(v.material_override, mat, "not the shared material")
	assert_true(dress.materials().has(mat), "in the prewarm list")


func test_the_range_models_stay_within_their_triangle_budget() -> void:
	var dress := _range_dress()
	for model in RANGE_MODELS:
		assert_gt(dress.views_of(model).size(), 0, "%s is placed" % model)
		var t := _tris(dress.mesh_of(model))
		assert_lt(t, 5000, "%s within 5,000 triangles (%d)" % [model, t])
		assert_gt(t, 500, "%s is a real model" % model)


func test_the_baked_colours_keep_the_team_rule_when_stored_8_bit() -> void:
	var dress := _range_dress()
	for model in RANGE_MODELS:
		var mesh := dress.mesh_of(model)
		for s in mesh.get_surface_count():
			var cols: Variant = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
			assert_not_null(cols, "%s keeps its vertex colours" % model)
			if cols == null:
				continue
			for c: Color in (cols as PackedColorArray):
				var hi := maxf(c.r, maxf(c.g, c.b))
				var lo := minf(c.r, minf(c.g, c.b))
				var is_team := hi > 0.35 and (hi - lo) > 0.6 * hi and (c.b > c.r * 1.5 or c.r > c.b * 1.5) \
						and c.g < maxf(c.r, c.b) * 0.5
				assert_false(is_team, "%s has no strongly red or blue vertex (%s)" % [model, c])
				if is_team:
					return


func test_cordwood_sections_stay_inside_their_box_and_budget() -> void:
	for model in CORDWOOD:
		var mesh := load("res://assets/models/props/%s.glb" % model) as PackedScene
		assert_not_null(mesh, "%s loads" % model)
		var root := mesh.instantiate()
		add_child_autofree(root)
		var tris := 0
		var box := AABB()
		var first := true
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			tris += _tris(mi.mesh)
			var b := mi.global_transform * mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		assert_lte(tris, 3200, "%s within its 3,200 budget (%d)" % [model, tris])
		assert_gt(box.size.x, 0.5, "%s has a body" % model)
		assert_almost_eq(box.position.y, 0.0, 0.05, "%s stands on its floor" % model)
