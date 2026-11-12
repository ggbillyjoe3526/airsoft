extends GutTest
## UL1: an underground field (Subway) has no sky in its light and no sun shadow, so Medium's stand-in sun lights its
## floors below the storeys instead of leaving them in one flat shade; its feet kick up grey dust, not white.

var table: GraphicsTable = GraphicsTable.shared()


func _roofed(extra: String) -> MapData:
	return MapData.parse('{"blocks": [], "spawns": [[], []], "deadZones": [[], []], "roof": {"height": 4.0%s, '
			% extra + '"lamps": []}}', MapStyle.new(), 1)


func _lit(underground: bool) -> FieldLighting:
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	lighting.set_underground(underground)
	return lighting


func test_the_flag_reads_true_and_defaults_false_with_a_warning_for_a_non_bool() -> void:
	assert_true(_roofed(', "underground": true').roof_underground)
	assert_false(_roofed("").roof_underground)
	var odd := _roofed(', "underground": "yes"')
	assert_false(odd.roof_underground)
	assert_eq(odd.warnings.size(), 1, "a non-bool is warned about")


func test_subway_is_underground_and_depot_and_woodland_are_not() -> void:
	var subway := MapData.load_map("subway", MapStyle.new(), 6)
	assert_true(subway.roof_underground)
	assert_eq(subway.warnings, [] as Array[String])
	assert_ne(subway.kicked_dust_tint, Color.WHITE, "grey dust, not the white default")
	for id: String in ["depot", "woodland"]:
		assert_false(MapData.load_map(id, MapStyle.new(), 6).roof_underground, id)


func test_underground_light_takes_no_sky_and_reflects_none() -> void:
	var cfg := LightingConfig.new()
	var lighting := _lit(true)
	assert_eq(lighting.environment.ambient_light_sky_contribution, 0.0)
	assert_eq(lighting.environment.reflected_light_source, Environment.REFLECTION_SOURCE_DISABLED)
	assert_true(lighting.underground())
	lighting.set_underground(false)
	assert_almost_eq(lighting.environment.ambient_light_sky_contribution, cfg.sky_contribution, 0.0001, "put back")
	assert_eq(lighting.environment.reflected_light_source, Environment.REFLECTION_SOURCE_SKY)


func test_above_ground_keeps_the_sky() -> void:
	var lighting := _lit(false)
	assert_almost_eq(lighting.environment.ambient_light_sky_contribution, LightingConfig.new().sky_contribution,
			0.0001)
	assert_false(lighting.underground())


func test_no_sun_shadow_underground_on_any_preset() -> void:
	var under := _lit(true)
	var open := _lit(false)
	var rs := GraphicsApply.Server.new()
	for p: StringName in [&"low", &"medium", &"high", &"ultra"]:
		var values := table.preset(p)
		assert_false(GraphicsApply.sun_shadows(values, under), p)
		assert_eq(GraphicsApply.sun_shadows(values, open), values.sun_shadows, p)
		assert_eq(GraphicsApply.sun_shadows(values), values.sun_shadows, "%s: no field, the preset's" % p)
		GraphicsApply.apply_field(values, under, null, rs)
		assert_false(under.sun.shadow_enabled, p)
		GraphicsApply.apply_field(values, open, null, rs)
		assert_eq(open.sun.shadow_enabled, values.sun_shadows, p)


func test_medium_underground_keeps_the_contact_shadows_and_drops_the_twins() -> void:
	var medium := table.preset(&"medium")
	var under := _lit(true)
	assert_true(GraphicsApply.contact_shadows(medium, under), "no sun shadow, so the contact shadow shows")
	assert_false(GraphicsApply.any_shadows(medium, under), "nothing casts on Medium underground: no twins")
	assert_false(GraphicsApply.contact_shadows(medium, _lit(false)), "above ground the sun casts")
	var high := table.preset(&"high")
	assert_true(GraphicsApply.any_shadows(high, under), "High's lamps still cast underground")
