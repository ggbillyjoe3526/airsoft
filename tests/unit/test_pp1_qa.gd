extends GutTest
## PP1 part 1, QA: the optic glass's picture takes the lamp shadow slots as the main view does, and the fixtures'
## shaders are the shared ones (no fresh Shader per match).


func test_the_optic_glass_takes_the_lamp_slots_when_the_lamps_are_lights() -> void:
	var eyes := Camera3D.new()
	add_child_autofree(eyes)
	var glass := OpticGlass.new()
	glass.setup(ViewModelConfig.new(), ViewConfig.new(), eyes)
	add_child_autofree(glass)
	var port := glass.get_child(0) as SubViewport
	var values := GraphicsTable.shared().preset(&"high")
	values.lamp_lights = GraphicsQuality.LampLights.FAR
	GraphicsApply.server().applied.emit(values)
	for q in GraphicsApply.LAMP_SLOTS.size():
		assert_eq(port.get_positional_shadow_atlas_quadrant_subdiv(q), GraphicsApply.LAMP_SLOTS[q], "quadrant %d" % q)
	values.lamp_lights = GraphicsQuality.LampLights.OFF
	GraphicsApply.server().applied.emit(values)
	for q in GraphicsApply.PROJECT_SLOTS.size():
		assert_eq(port.get_positional_shadow_atlas_quadrant_subdiv(q), GraphicsApply.PROJECT_SLOTS[q], "off: quadrant %d" % q)


func test_a_code_shader_is_made_once() -> void:
	var a := CodeShaders.of("shader_type spatial; void fragment() { ALBEDO = vec3(0.1234); }")
	var b := CodeShaders.of("shader_type spatial; void fragment() { ALBEDO = vec3(0.1234); }")
	assert_same(a, b)
