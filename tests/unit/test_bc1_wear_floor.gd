extends GutTest
## BC1: a worn model's floor (look_wear.gdshaderinc's wear_floor, SL2) goes on each instance on Forward+ and Mobile,
## and on a copy of its material on Compatibility, whose instance uniforms run out at 256 drawn instances (Woodland
## draws about 300 worn models: the simpler renderer logged about 90 errors loading it).

const WEAR_INCLUDE := "res://game/play/look/look_wear.gdshaderinc"


func _view() -> MultiMeshInstance3D:
	var v := MultiMeshInstance3D.new()
	autofree(v)
	return v


func test_with_instance_uniforms_the_floor_goes_on_the_view_and_the_material_is_shared() -> void:
	var mat := LookMaterials.vertex_colour(0.8, 0.0)
	var copies := {}
	var a := _view()
	var b := _view()
	LookMaterials.draw_worn(a, mat, -0.5, false, copies)
	LookMaterials.draw_worn(b, mat, 0.25, false, copies)
	assert_eq(a.material_override, mat)
	assert_eq(b.material_override, mat)
	assert_almost_eq(float(a.get_instance_shader_parameter(&"wear_floor")), -0.5, 1e-6)
	assert_almost_eq(float(b.get_instance_shader_parameter(&"wear_floor")), 0.25, 1e-6)
	assert_true(copies.is_empty(), "no copies where instances carry the floor")


func test_on_compatibility_each_floor_gets_one_copy_of_the_material_and_the_original_is_untouched() -> void:
	var mat := LookMaterials.vertex_colour(0.8, 0.0, Color.WHITE, false, 0.5)
	var copies := {}
	var a := _view()
	var b := _view()
	var c := _view()
	LookMaterials.draw_worn(a, mat, -0.5, true, copies)
	LookMaterials.draw_worn(b, mat, -0.5, true, copies)
	LookMaterials.draw_worn(c, mat, 2.25, true, copies)
	assert_ne(a.material_override, mat, "a floor off the origin draws in a copy")
	assert_eq(a.material_override, b.material_override, "one copy a material and floor")
	assert_ne(a.material_override, c.material_override, "another floor, another copy")
	var copy := a.material_override as ShaderMaterial
	assert_almost_eq(float(copy.get_shader_parameter(&"wear_floor")), -0.5, 1e-6)
	assert_almost_eq(float((c.material_override as ShaderMaterial).get_shader_parameter(&"wear_floor")), 2.25, 1e-6)
	assert_eq(copy.shader, mat.shader)
	assert_almost_eq(float(copy.get_shader_parameter(&"wear")), 0.5, 1e-6, "the copy keeps the material's wear")
	assert_null(mat.get_shader_parameter(&"wear_floor"), "the shared material keeps no floor")
	assert_null(a.get_instance_shader_parameter(&"wear_floor"), "nothing is set on the instance")
	assert_eq(copies.size(), 1)
	assert_eq((copies[mat] as Dictionary).size(), 2)


func test_on_compatibility_a_floor_at_the_origin_draws_in_the_material_itself() -> void:
	var mat := LookMaterials.vertex_colour(0.8, 0.0)
	var copies := {}
	var a := _view()
	LookMaterials.draw_worn(a, mat, 0.0, true, copies)
	assert_eq(a.material_override, mat)
	assert_true(copies.is_empty())


func test_the_include_declares_the_floor_per_material_on_compatibility_and_per_instance_elsewhere() -> void:
	var text := FileAccess.get_file_as_string(WEAR_INCLUDE)
	var at_if := text.find("#if CURRENT_RENDERER == RENDERER_COMPATIBILITY")
	var at_else := text.find("#else", at_if)
	var at_end := text.find("#endif", at_else)
	assert_gt(at_if, -1, "the include switches on the renderer")
	assert_true(at_if < at_else and at_else < at_end)
	var compat := text.substr(at_if, at_else - at_if)
	var others := text.substr(at_else, at_end - at_else)
	assert_true(compat.contains("\nuniform float wear_floor"), "Compatibility: a material uniform")
	assert_false(compat.contains("instance uniform"), "Compatibility: no instance uniform")
	assert_true(others.contains("instance uniform float wear_floor"), "Forward+ and Mobile: an instance uniform")
	assert_eq(text.count("\ninstance uniform"), 1, "no other instance uniform in the wear")


func test_floors_by_material_follows_the_renderer_running() -> void:
	assert_eq(LookMaterials.floors_by_material(),
			RenderingServer.get_current_rendering_method() == GraphicsPick.COMPATIBILITY)
