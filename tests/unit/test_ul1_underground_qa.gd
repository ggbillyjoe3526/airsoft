extends GutTest
## UL1 QA: the underground look survives graphics being re-applied, preset switches and a repeated set, and the
## open-air maps (Range included) keep the sky.

var table: GraphicsTable = GraphicsTable.shared()


func _lit(underground: bool) -> FieldLighting:
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	lighting.set_underground(underground)
	return lighting


func test_reapplying_graphics_and_switching_presets_keeps_the_sun_shadow_off_underground() -> void:
	var under := _lit(true)
	var rs := GraphicsApply.Server.new()
	for p: StringName in [&"ultra", &"low", &"high", &"medium", &"ultra", &"ultra"]:
		GraphicsApply.apply_field(table.preset(p), under, null, rs)
		assert_false(under.sun.shadow_enabled, p)
		assert_eq(under.sun.light_angular_distance, 0.0, "%s: no soft sun without a shadow" % p)
		assert_eq(under.environment.ambient_light_sky_contribution, 0.0, p)
		assert_eq(under.environment.reflected_light_source, Environment.REFLECTION_SOURCE_DISABLED, p)


func test_a_sun_shadow_toggle_underground_changes_nothing() -> void:
	var under := _lit(true)
	var values := table.preset(&"ultra")
	var rs := GraphicsApply.Server.new()
	for on: bool in [true, false, true]:
		values.sun_shadows = on
		GraphicsApply.apply_field(values, under, null, rs)
		assert_false(under.sun.shadow_enabled)
		assert_true(GraphicsApply.contact_shadows(values, under))


func test_setting_underground_twice_still_restores_the_preset_sky_share() -> void:
	var lighting := _lit(true)
	lighting.set_underground(true)
	lighting.set_underground(false)
	lighting.set_underground(false)
	assert_almost_eq(lighting.environment.ambient_light_sky_contribution, LightingConfig.new().sky_contribution,
			0.0001)
	assert_false(lighting.underground())


func test_underground_leaves_eye_adaptation_and_ambient_energy_alone() -> void:
	var under := _lit(true)
	var open := _lit(false)
	assert_eq(under.environment.ambient_light_energy, open.environment.ambient_light_energy)
	under.set_ambient_share(0.5)
	assert_eq(under.environment.ambient_light_sky_contribution, 0.0, "a lamp-share change keeps the sky out")
	under.set_eye_adaptation(true)
	under.set_eye_adaptation(false)
	assert_eq(under.environment.ambient_light_sky_contribution, 0.0)


func test_every_other_map_is_above_ground() -> void:
	for id: String in ["depot", "woodland", "range"]:
		var m := MapData.load_map(id, MapStyle.new(), 6)
		if m == null:
			continue
		assert_false(m.roof_underground, id)
