extends GutTest
## GraphicsApply (game/save/graphics_apply.gd): the root viewport's knobs and the RenderingServer's shadow map and filter
## from a preset, the choices the simpler renderer can't draw moved to ones it can, the match's sun, ambient occlusion
## and wind dust switched in place, the optic glass following, and fifty rounds of the four presets in a match leaving
## nothing behind. Headless: properties and counts, never pixels.

const FORWARD := "forward_plus"
const COMPATIBILITY := "gl_compatibility"
const SWITCHES := 50

var table: GraphicsTable = null
var _saved: Dictionary[StringName, Variant] = {}
## The root viewport's knobs, put back after each test.
var _knobs: Array[StringName] = [&"scaling_3d_scale", &"scaling_3d_mode", &"msaa_3d", &"screen_space_aa", &"use_taa",
		&"anisotropic_filtering_level", &"mesh_lod_threshold", &"use_occlusion_culling", &"positional_shadow_atlas_size"]


func before_each() -> void:
	table = GraphicsTable.shared()
	_saved.clear()
	for k in _knobs:
		_saved[k] = get_tree().root.get(k)


func after_each() -> void:
	for k in _knobs:
		get_tree().root.set(k, _saved[k])
	get_tree().paused = false


func _probe(preset: StringName, method: String = FORWARD) -> GraphicsPick.Probe:
	var p := GraphicsPick.Probe.new()
	p.preset = preset
	p.rendering_method = method
	p.driver = "vulkan"
	return p


func _settings(choice: StringName) -> Settings:
	var s := Settings.new(PlayTuning.new())
	s.choose_graphics(choice, GraphicsTable.DEFAULT_PRESET)
	return s


func test_high_sets_the_root_viewport_and_the_shadow_map() -> void:
	var rs := GraphicsApply.Server.new()
	var root := get_tree().root
	GraphicsApply.apply(table.preset(&"high"), root, rs)
	assert_almost_eq(root.scaling_3d_scale, 1.0, 0.001)
	assert_eq(root.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR, "FSR 1 (it does nothing at 100 %)")
	assert_eq(root.msaa_3d, Viewport.MSAA_DISABLED, "edge smoothing is off on every preset (owner, 2026-10-29)")
	assert_eq(root.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_false(root.use_taa)
	assert_eq(root.anisotropic_filtering_level, Viewport.ANISOTROPY_16X)
	assert_almost_eq(root.mesh_lod_threshold, 1.0, 0.001, "the engine's default")
	assert_eq(rs.shadow_size, 4096)
	assert_eq(rs.soft_shadows, RenderingServer.SHADOW_QUALITY_SOFT_LOW, "Softer is the engine's default")


func test_low_sets_the_cheap_knobs() -> void:
	var rs := GraphicsApply.Server.new()
	var root := get_tree().root
	GraphicsApply.apply(table.preset(&"low"), root, rs)
	assert_almost_eq(root.scaling_3d_scale, 0.8, 0.001)
	assert_eq(root.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR)
	assert_eq(root.msaa_3d, Viewport.MSAA_DISABLED)
	assert_eq(root.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_eq(root.anisotropic_filtering_level, Viewport.ANISOTROPY_2X)
	var smoothed := table.preset(&"low")
	smoothed.edge_smoothing = GraphicsQuality.EdgeSmoothing.FXAA
	GraphicsApply.apply(smoothed, root, rs)
	assert_eq(root.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA, "a player who turns it on gets it")
	assert_gt(root.mesh_lod_threshold, 1.0, "coarser meshes")
	assert_eq(rs.shadow_size, 1024)
	assert_eq(rs.soft_shadows, RenderingServer.SHADOW_QUALITY_HARD)


func test_ultra_sets_the_dear_knobs() -> void:
	var rs := GraphicsApply.Server.new()
	var root := get_tree().root
	GraphicsApply.apply(table.preset(&"ultra"), root, rs)
	assert_eq(rs.shadow_size, 8192)
	assert_eq(rs.soft_shadows, RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	assert_lt(root.mesh_lod_threshold, 1.0, "finer meshes")


func test_a_new_server_starts_at_the_project_s_values_so_high_sends_nothing_new() -> void:
	var rs := GraphicsApply.Server.new()
	assert_eq(rs.shadow_size, ProjectSettings.get_setting(GraphicsApply.Server.SHADOW_SIZE) as int)
	assert_eq(rs.soft_shadows, ProjectSettings.get_setting(GraphicsApply.Server.SOFT_SHADOWS) as int)
	assert_eq(rs.shadow_size, table.preset(&"high").shadow_detail, "High's shadow map is the project's")
	assert_eq(rs.soft_shadows, GraphicsApply.SOFTNESS[table.preset(&"high").shadow_softness])


func test_every_edge_smoothing_maps_to_one_filter_at_most() -> void:
	for e in GraphicsQuality.CHOICES[GraphicsQuality.EDGE_SMOOTHING].size():
		var msaa := GraphicsApply.EDGE_MSAA[e] != Viewport.MSAA_DISABLED
		var screen := GraphicsApply.EDGE_SCREEN_AA[e] != Viewport.SCREEN_SPACE_AA_DISABLED
		assert_false(msaa and screen, "edge smoothing %d is one filter" % e)
	assert_eq(GraphicsApply.UPSCALE_MODES.size(), GraphicsQuality.CHOICES[GraphicsQuality.UPSCALER].size())
	assert_eq(GraphicsApply.ANISOTROPY.size(), GraphicsQuality.CHOICES[GraphicsQuality.TEXTURE_FILTERING].size())
	assert_eq(GraphicsApply.MESH_LOD.size(), GraphicsQuality.CHOICES[GraphicsQuality.MESH_DETAIL].size())
	assert_eq(GraphicsApply.SOFTNESS.size(), GraphicsQuality.CHOICES[GraphicsQuality.SHADOW_SOFTNESS].size())


func test_the_simpler_renderer_draws_bilinear_msaa_and_no_ssao_or_taa() -> void:
	var low := GraphicsApply.drawable(table.preset(&"low"), COMPATIBILITY, table)
	assert_eq(low.upscaler, GraphicsQuality.Upscaler.BILINEAR, "Low's FSR 1 falls back to bilinear")
	assert_eq(low.edge_smoothing, GraphicsQuality.EdgeSmoothing.OFF, "Low's edge smoothing is off")
	var custom := table.preset(&"high")
	custom.edge_smoothing = GraphicsQuality.EdgeSmoothing.SMAA
	custom.temporal_smoothing = true
	custom.upscaler = GraphicsQuality.Upscaler.FSR2
	var drawn := GraphicsApply.drawable(custom, COMPATIBILITY, table)
	assert_eq(drawn.edge_smoothing, GraphicsQuality.EdgeSmoothing.MSAA_2X, "SMAA's cheaper neighbour FXAA is refused too")
	assert_false(drawn.temporal_smoothing, "TAA is Forward+ only")
	assert_eq(drawn.ambient_occlusion, GraphicsQuality.AmbientOcclusion.OFF, "SSAO is Forward+ only")
	assert_eq(drawn.upscaler, GraphicsQuality.Upscaler.BILINEAR)
	assert_eq(custom.edge_smoothing, GraphicsQuality.EdgeSmoothing.SMAA, "a copy: the values given are untouched")
	assert_true(GraphicsApply.drawable(custom, FORWARD, table).equals(custom), "Forward+ draws everything")


func test_values_for_takes_the_pick_while_automatic_and_the_flag_over_all() -> void:
	var s := Settings.new(PlayTuning.new())
	assert_true(GraphicsApply.values_for(s, _probe(&"medium")).equals(table.preset(&"medium")))
	s.choose_graphics(&"ultra", &"medium")
	assert_true(GraphicsApply.values_for(s, _probe(&"medium")).equals(table.preset(&"ultra")))
	s.graphics_forced = &"low"
	assert_true(GraphicsApply.values_for(s, _probe(&"medium")).equals(table.preset(&"low")))
	var compat := GraphicsApply.values_for(s, _probe(&"low", COMPATIBILITY))
	assert_eq(compat.upscaler, GraphicsQuality.Upscaler.BILINEAR)


func test_apply_settings_draws_only_a_change_and_says_so_once() -> void:
	var rs := GraphicsApply.Server.new()
	var heard: Array[GraphicsQuality] = []
	rs.applied.connect(func(v: GraphicsQuality) -> void: heard.append(v))
	var view := SubViewport.new()
	add_child_autofree(view)
	var s := _settings(&"low")
	assert_true(GraphicsApply.apply_settings(s, view, rs, _probe(&"high")))
	assert_false(GraphicsApply.apply_settings(s, view, rs, _probe(&"high")), "the same values: nothing drawn")
	assert_eq(heard.size(), 1)
	assert_true(rs.drawn.equals(table.preset(&"low")))
	s.change_graphics_row(GraphicsQuality.WIND_DUST, 30, &"high", table)
	assert_true(GraphicsApply.apply_settings(s, view, rs, _probe(&"high")))
	assert_eq(heard.size(), 2)
	assert_eq(heard[1].wind_dust, 30)
	assert_almost_eq(view.scaling_3d_scale, 0.8, 0.001, "on the viewport given")


func test_high_draws_the_field_as_before_the_presets() -> void:
	var cfg := LightingConfig.new()
	var lighting := FieldLighting.build(cfg)
	add_child_autofree(lighting)
	var before_shadows := lighting.sun.shadow_enabled
	var before_range := lighting.sun.directional_shadow_max_distance
	var dust := _dust()
	var rs := GraphicsApply.Server.new()
	GraphicsApply.apply_field(table.preset(&"high"), lighting, dust, rs)
	assert_eq(lighting.sun.shadow_enabled, before_shadows)
	assert_true(lighting.sun.shadow_enabled, "sun shadows")
	assert_almost_eq(lighting.sun.directional_shadow_max_distance, before_range, 0.001)
	assert_almost_eq(lighting.sun.directional_shadow_max_distance, 70.0, 0.001, "70 m")
	assert_true(lighting.environment.ssao_enabled, "SSAO")
	assert_true(rs.ssao_half, "at half size")
	assert_true(dust.visible)
	assert_eq(dust.amount, EffectsConfig.new().dust_count, "all the dust")


func test_low_draws_no_sun_shadows_no_ssao_and_no_dust() -> void:
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	var dust := _dust()
	GraphicsApply.apply_field(table.preset(&"low"), lighting, dust, GraphicsApply.Server.new())
	assert_false(lighting.sun.shadow_enabled)
	assert_false(lighting.environment.ssao_enabled)
	assert_false(dust.visible)
	assert_false(dust.emitting)
	var at := dust.global_position
	dust.update(Vector3(5.0, 1.0, 5.0), Vector3.ONE, 1.0)
	assert_eq(dust.global_position, at, "hidden dust does no work")


func test_medium_draws_half_the_dust_and_ultra_full_ssao() -> void:
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	var dust := _dust()
	var rs := GraphicsApply.Server.new()
	GraphicsApply.apply_field(table.preset(&"low"), lighting, dust, rs)
	GraphicsApply.apply_field(table.preset(&"medium"), lighting, dust, rs)
	assert_true(dust.visible, "shown again")
	assert_eq(dust.amount, roundi(EffectsConfig.new().dust_count * 0.5))
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, dust, rs)
	assert_true(lighting.environment.ssao_enabled)
	assert_false(rs.ssao_half, "full size")
	assert_almost_eq(lighting.sun.directional_shadow_max_distance, 100.0, 0.001)


func test_a_field_without_ssao_never_gets_it() -> void:
	var cfg := LightingConfig.new()
	cfg.ssao = false
	var lighting := FieldLighting.build(cfg)
	add_child_autofree(lighting)
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, GraphicsApply.Server.new())
	assert_false(lighting.environment.ssao_enabled)


func test_the_optic_glass_follows_scale_and_edge_smoothing() -> void:
	var eyes := Camera3D.new()
	add_child_autofree(eyes)
	var glass := OpticGlass.new()
	glass.setup(ViewModelConfig.new(), ViewConfig.new(), eyes)
	add_child_autofree(glass)
	var port := glass.get_child(0) as SubViewport
	var low := table.preset(&"low")
	low.edge_smoothing = GraphicsQuality.EdgeSmoothing.FXAA
	GraphicsApply.server().applied.emit(low)
	assert_almost_eq(port.scaling_3d_scale, 0.8, 0.001)
	assert_eq(port.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA)
	assert_eq(port.msaa_3d, Viewport.MSAA_DISABLED)
	var high := table.preset(&"high")
	GraphicsApply.server().applied.emit(high)
	assert_eq(port.msaa_3d, Viewport.MSAA_DISABLED, "off by default")
	high.edge_smoothing = GraphicsQuality.EdgeSmoothing.MSAA_4X
	GraphicsApply.server().applied.emit(high)
	assert_almost_eq(port.scaling_3d_scale, 1.0, 0.001)
	assert_eq(port.msaa_3d, Viewport.MSAA_4X)
	glass.get_parent().remove_child(glass)
	assert_false(GraphicsApply.server().applied.is_connected(glass._follow), "let go when it leaves")
	add_child_autofree(glass)


func test_four_presets_fifty_times_in_a_match_leave_nothing_behind() -> void:
	var s := Settings.new(PlayTuning.new())
	var play := PlaySession.new()
	play.settings = s
	play.match_seed = 77
	add_child_autofree(play)
	await wait_physics_frames(3)
	SettingsApply.apply_graphics(s)
	# As from the pause menu: the match stands still while the settings change.
	get_tree().paused = true
	await wait_process_frames(2)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var resources := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var start := s.graphics_choice
	for i in SWITCHES:
		for p in GraphicsTable.PRESETS:
			s.choose_graphics(p, GraphicsTable.DEFAULT_PRESET)
			SettingsApply.apply_graphics(s)
	s.choose_graphics(&"low", GraphicsTable.DEFAULT_PRESET)
	SettingsApply.apply_graphics(s)
	assert_false(play._lighting.sun.shadow_enabled, "Low reached the match's sun")
	assert_false(play._lighting.environment.ssao_enabled)
	assert_false(play._dust.visible)
	s.choose_graphics(start, GraphicsTable.DEFAULT_PRESET)
	SettingsApply.apply_graphics(s)
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans, "no orphan nodes")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no nodes added")
	# No growth: the count can fall while an earlier test's resources are freed (CI, 2026-10-23).
	assert_lte(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), resources, "no resources leaked")
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	await wait_process_frames(10)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects, "a frame allocates nothing")
	get_tree().paused = false


func test_a_match_starts_with_the_graphics_drawn_and_lets_go_when_it_ends() -> void:
	var s := _settings(&"low")
	SettingsApply.apply_graphics(s)
	var play := PlaySession.new()
	play.settings = s
	play.match_seed = 78
	add_child(play)
	await wait_physics_frames(3)
	assert_false(play._lighting.sun.shadow_enabled, "the drawn preset, at the start")
	assert_false(play._dust.visible)
	assert_true(GraphicsApply.server().applied.is_connected(play._apply_graphics))
	play.queue_free()
	await wait_process_frames(2)
	assert_eq(GraphicsApply.server().applied.get_connections().size(), 0, "nothing left listening")
	s.choose_graphics(&"high", GraphicsTable.DEFAULT_PRESET)
	SettingsApply.apply_graphics(s)


func _dust() -> WindDust:
	var dust := WindDust.new()
	dust.setup(EffectsConfig.new())
	add_child_autofree(dust)
	return dust
