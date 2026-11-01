extends GutTest
## BP2 (the 0.1 Dev 2 bug pass), performance: shaders written as code are made once for the whole run.


func test_two_matches_night_skies_share_one_shader_so_it_compiles_once() -> void:
	var cfg := LightingConfig.new()
	var first := FieldLighting.night_sky_material(cfg)
	var second := FieldLighting.night_sky_material(cfg)
	assert_ne(first, second, "each match its own material")
	assert_same(first.shader, second.shader, "one shader for both")
	assert_eq(first.shader.code, FieldLighting.NIGHT_SKY)


func test_a_shader_is_made_per_code_not_one_for_all() -> void:
	assert_same(CodeShaders.of(FieldLighting.NIGHT_SKY), CodeShaders.of(FieldLighting.NIGHT_SKY))
	assert_ne(CodeShaders.of(FieldLighting.NIGHT_SKY), CodeShaders.of(LightPools.POOL_SHADER))
