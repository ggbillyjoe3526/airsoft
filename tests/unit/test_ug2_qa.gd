extends GutTest
## UG2 QA: the sun and sky light under a roofed field's real lamps across preset switches, Custom combos, the night
## moon and repeats. Headless: properties only.

var table: GraphicsTable = null
var play: PlayTuning = PlayTuning.new()
var depot: MapData = null


func before_all() -> void:
	depot = MapData.load_map("depot", MapStyle.new(), 6)


func before_each() -> void:
	table = GraphicsTable.shared()


func _lamps() -> RoofLamps:
	var roof := RoofView.build(depot, play.roof)
	add_child_autofree(roof)
	return roof.lamp_lights()


func _lighting(night: bool = false) -> FieldLighting:
	var cfg := LightingConfig.new()
	cfg.night = night
	cfg.sun_energy = 0.4 if night else cfg.sun_energy
	cfg.ambient_energy = 0.3 if night else cfg.ambient_energy
	var lighting := FieldLighting.build(cfg)
	add_child_autofree(lighting)
	return lighting


func test_switching_presets_back_and_forth_restores_sun_and_sky_every_time() -> void:
	var lighting := _lighting()
	var sun := lighting.sun.light_energy
	var sky := lighting.environment.ambient_light_energy
	var lamps := _lamps()
	var rs := GraphicsApply.Server.new()
	for round_i in 3:
		for preset: StringName in [&"ultra", &"low", &"high", &"medium"]:
			GraphicsApply.apply_field(table.preset(preset), lighting, null, rs, null, null, null, lamps)
			var lamp_on := lamps.visible
			assert_eq(lighting.sun.visible, not lamp_on, "%s round %d: sun visible iff lamps off" % [preset, round_i])
			assert_almost_eq(lighting.sun.light_energy, 0.0 if lamp_on else sun, 0.001, preset)
			assert_almost_eq(lighting.environment.ambient_light_energy, sky * (0.6 if lamp_on else 1.0), 0.001, preset)


func test_custom_lamps_on_with_sun_shadows_off_still_puts_the_sun_out() -> void:
	var lighting := _lighting()
	var lamps := _lamps()
	var values := table.preset(&"high").copy()
	values.sun_shadows = false
	GraphicsApply.apply_field(values, lighting, null, GraphicsApply.Server.new(), null, null, null, lamps)
	assert_false(lighting.sun.visible)
	assert_true(lamps.visible)
	assert_true(GraphicsApply.any_shadows(values), "the lamps still cast, so the twins stay")


func test_custom_lamps_off_with_sun_shadows_off_keeps_the_sun_lit() -> void:
	var lighting := _lighting()
	var full := lighting.sun.light_energy
	var lamps := _lamps()
	var values := table.preset(&"ultra").copy()
	values.lamp_lights = GraphicsQuality.LampLights.OFF
	values.sun_shadows = false
	GraphicsApply.apply_field(values, lighting, null, GraphicsApply.Server.new(), null, null, null, lamps)
	assert_true(lighting.sun.visible)
	assert_almost_eq(lighting.sun.light_energy, full, 0.001)


func test_set_effects_after_the_lamps_do_not_bring_the_sun_back() -> void:
	var lighting := _lighting()
	var lamps := _lamps()
	var rs := GraphicsApply.Server.new()
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, rs, null, null, null, lamps)
	var sky := lighting.environment.ambient_light_energy
	var v := table.preset(&"ultra")
	lighting.set_effects(v.global_illumination, v.reflections, v.glow, v.volumetric_fog, true)
	assert_false(lighting.sun.visible)
	assert_almost_eq(lighting.sun.light_energy, 0.0, 0.001)
	assert_almost_eq(lighting.environment.ambient_light_energy, sky, 0.001)


func test_a_night_depot_scales_the_moons_own_energy_and_restores_it() -> void:
	var lighting := _lighting(true)
	var moon := lighting.sun.light_energy
	var sky := lighting.environment.ambient_light_energy
	assert_almost_eq(moon, 0.4, 0.001)
	var lamps := _lamps()
	var rs := GraphicsApply.Server.new()
	GraphicsApply.apply_field(table.preset(&"high"), lighting, null, rs, null, null, null, lamps)
	assert_false(lighting.sun.visible)
	assert_almost_eq(lighting.environment.ambient_light_energy, sky * 0.6, 0.001)
	GraphicsApply.apply_field(table.preset(&"low"), lighting, null, rs, null, null, null, lamps)
	assert_true(lighting.sun.visible)
	assert_almost_eq(lighting.sun.light_energy, moon, 0.001)
	assert_almost_eq(lighting.environment.ambient_light_energy, sky, 0.001)


func test_a_roof_without_lights_leaves_the_sun_whatever_the_preset() -> void:
	var lighting := _lighting()
	var full := lighting.sun.light_energy
	var lamps := RoofLamps.build([] as Array[Vector3], play.roof)
	add_child_autofree(lamps)
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, GraphicsApply.Server.new(), null, null, null, lamps)
	assert_true(lighting.sun.visible)
	assert_almost_eq(lighting.sun.light_energy, full, 0.001)
	assert_eq(lamps.ambient_share(GraphicsQuality.LampLights.FAR), 1.0)


func test_a_zero_ambient_share_or_sun_share_never_leaves_the_sun_hidden_at_full_share() -> void:
	var lighting := _lighting()
	lighting.set_key_share(0.0)
	lighting.set_ambient_share(0.0)
	assert_false(lighting.sun.visible)
	assert_almost_eq(lighting.environment.ambient_light_energy, 0.0, 0.0001)
	lighting.set_key_share(1.0)
	lighting.set_ambient_share(1.0)
	assert_true(lighting.sun.visible)
	assert_gt(lighting.sun.light_energy, 0.0)
	assert_gt(lighting.environment.ambient_light_energy, 0.0)
