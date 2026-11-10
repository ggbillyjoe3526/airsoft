extends GutTest
## UG4: Ultra's finer light (data/graphics.md › Ultra). Full ambient occlusion and Scene's screen bounce at the engine's
## Ultra quality at full size, High's left as the project's; SDFGI in 10 cm cells near the eye, reaching as far as
## before, with the most rays; screen-space reflections at full size. Headless: what is sent and set, never pixels.

## SDFGI's cascades are 128 cells a side, each twice the last.
const CASCADE_CELLS := 128.0

var table: GraphicsTable = null
var look: LookConfig = LookConfig.new()


func before_each() -> void:
	table = GraphicsTable.shared()


func _lighting() -> FieldLighting:
	var lighting := FieldLighting.build(LightingConfig.new(), look)
	add_child_autofree(lighting)
	return lighting


func test_ultra_draws_its_ambient_occlusion_at_ultra_quality_and_full_size() -> void:
	var rs := GraphicsApply.Server.new()
	var lighting := _lighting()
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, rs)
	assert_eq(rs.ssao_quality, RenderingServer.ENV_SSAO_QUALITY_ULTRA)
	assert_false(rs.ssao_half)
	GraphicsApply.apply_field(table.preset(&"high"), lighting, null, rs)
	assert_eq(rs.ssao_quality, ProjectSettings.get_setting(GraphicsApply.SSAO_QUALITY) as int,
			"High back on the project's quality")
	assert_true(rs.ssao_half)


func test_high_sends_no_new_ambient_occlusion() -> void:
	var rs := GraphicsApply.Server.new()
	assert_eq(rs.ssao_quality, GraphicsApply.SSAO_QUALITY_OF[GraphicsQuality.AmbientOcclusion.HALF],
			"the project's quality is High's")
	assert_eq(rs.ssao_half, true, "and so is its half size")


func test_scene_bounces_the_screen_at_ultra_quality_and_screen_stays_medium() -> void:
	assert_eq(GraphicsApply.SSIL_QUALITY[GraphicsQuality.GlobalIllumination.SCENE],
			RenderingServer.ENV_SSIL_QUALITY_ULTRA)
	assert_false(GraphicsApply.SSIL_HALF[GraphicsQuality.GlobalIllumination.SCENE])
	assert_eq(GraphicsApply.SSIL_QUALITY[GraphicsQuality.GlobalIllumination.SCREEN],
			RenderingServer.ENV_SSIL_QUALITY_MEDIUM)
	assert_true(GraphicsApply.SSIL_HALF[GraphicsQuality.GlobalIllumination.SCREEN])
	assert_between(look.fine_adaptive, 0.0, 1.0)


func test_sdfgi_cells_are_finer_and_reach_as_far() -> void:
	assert_lte(look.sdfgi_min_cell, 0.1 + 1e-5, "10 cm near the eye")
	var reach := look.sdfgi_min_cell * CASCADE_CELLS * pow(2.0, look.sdfgi_cascades - 1)
	assert_gte(reach, 400.0, "the farthest cascade still covers a field and its skyline")
	assert_between(look.sdfgi_cascades, 1, 8, "the engine's most")
	assert_eq(look.sdfgi_rays, RenderingServer.ENV_SDFGI_RAY_COUNT_128)


func test_the_field_draws_the_finer_sdfgi() -> void:
	var lighting := _lighting()
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, GraphicsApply.Server.new())
	var env := lighting.environment
	assert_true(env.sdfgi_enabled)
	assert_eq(env.sdfgi_cascades, look.sdfgi_cascades)
	assert_almost_eq(env.sdfgi_min_cell_size, look.sdfgi_min_cell, 1e-5)


func test_screen_reflections_draw_at_full_size() -> void:
	assert_false(ProjectSettings.get_setting("rendering/environment/screen_space_reflection/half_size") as bool,
			"only Screen (Ultra) draws them, so no other preset pays")
