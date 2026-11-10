extends GutTest
## UG4 QA: the Server's tracking of ambient occlusion across switches, renderer gating, and no leftovers.

var table: GraphicsTable = null
var look: LookConfig = LookConfig.new()


func before_each() -> void:
	table = GraphicsTable.shared()


func _lighting() -> FieldLighting:
	var lighting := FieldLighting.build(LightingConfig.new(), look)
	add_child_autofree(lighting)
	return lighting


func test_ultra_high_ultra_resends_full_each_way() -> void:
	var rs := GraphicsApply.Server.new()
	var lighting := _lighting()
	for i in 2:
		GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, rs)
		assert_eq(rs.ssao_quality, RenderingServer.ENV_SSAO_QUALITY_ULTRA, "ultra pass %d" % i)
		assert_false(rs.ssao_half)
		GraphicsApply.apply_field(table.preset(&"high"), lighting, null, rs)
		assert_eq(rs.ssao_quality, GraphicsApply.SSAO_QUALITY_OF[GraphicsQuality.AmbientOcclusion.HALF])
		assert_true(rs.ssao_half)


func test_ao_off_keeps_the_server_in_step_with_what_was_last_sent() -> void:
	var rs := GraphicsApply.Server.new()
	var lighting := _lighting()
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, rs)
	var off: GraphicsQuality = table.preset(&"ultra")
	off.ambient_occlusion = GraphicsQuality.AmbientOcclusion.OFF
	GraphicsApply.apply_field(off, lighting, null, rs)
	assert_false(lighting.environment.ssao_enabled)
	assert_false(rs.ssao_half, "nothing sent while off, so the record still says full")
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, rs)
	assert_true(lighting.environment.ssao_enabled or not lighting.ssao_allowed())
	assert_eq(rs.ssao_quality, RenderingServer.ENV_SSAO_QUALITY_ULTRA)


func test_set_ao_full_then_half_records_each() -> void:
	var rs := GraphicsApply.Server.new()
	rs.set_ao(GraphicsQuality.AmbientOcclusion.FULL, look)
	assert_false(rs.ssao_half)
	assert_eq(rs.ssao_quality, RenderingServer.ENV_SSAO_QUALITY_ULTRA)
	rs.set_ao(GraphicsQuality.AmbientOcclusion.HALF, look)
	assert_true(rs.ssao_half)
	assert_eq(rs.ssao_quality, RenderingServer.ENV_SSAO_QUALITY_MEDIUM)


func test_custom_mix_full_ao_with_screen_gi_and_half_ao_with_scene_gi() -> void:
	var rs := GraphicsApply.Server.new()
	var lighting := _lighting()
	var mix: GraphicsQuality = table.preset(&"high")
	mix.ambient_occlusion = GraphicsQuality.AmbientOcclusion.FULL
	GraphicsApply.apply_field(mix, lighting, null, rs)
	assert_eq(rs.gi_quality, GraphicsQuality.GlobalIllumination.SCREEN)
	assert_false(rs.ssao_half)
	mix.ambient_occlusion = GraphicsQuality.AmbientOcclusion.HALF
	mix.global_illumination = GraphicsQuality.GlobalIllumination.SCENE
	GraphicsApply.apply_field(mix, lighting, null, rs)
	assert_eq(rs.gi_quality, GraphicsQuality.GlobalIllumination.SCENE)
	assert_true(rs.ssao_half)
	assert_eq(rs.ssao_quality, RenderingServer.ENV_SSAO_QUALITY_MEDIUM)


func test_ultra_and_the_ao_row_need_forward_plus() -> void:
	for method: String in ["gl_compatibility", "mobile"]:
		assert_false(table.can_draw(&"ambient_occlusion", GraphicsQuality.AmbientOcclusion.FULL, method), method)
		assert_false(table.can_draw(&"global_illumination", GraphicsQuality.GlobalIllumination.SCENE, "gl_compatibility"))
	assert_true(table.can_draw(&"ambient_occlusion", GraphicsQuality.AmbientOcclusion.FULL, "forward_plus"))


func test_removed_set_ssao_half_has_no_callers() -> void:
	assert_false(GraphicsApply.Server.new().has_method("set_ssao_half"))
	for root: String in ["res://game", "res://tools", "res://tests"]:
		for path in _scripts(root):
			if path.ends_with("test_ug4_qa.gd"):
				continue
			var text := FileAccess.get_file_as_string(path)
			assert_false(text.contains("set_ssao_half"), path)


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out


func test_switching_presets_leaves_no_orphans() -> void:
	var rs := GraphicsApply.Server.new()
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var lighting := FieldLighting.build(LightingConfig.new(), look)
	add_child(lighting)
	for n: StringName in [&"ultra", &"high", &"ultra"]:
		GraphicsApply.apply_field(table.preset(n), lighting, null, rs)
	remove_child(lighting)
	lighting.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)
