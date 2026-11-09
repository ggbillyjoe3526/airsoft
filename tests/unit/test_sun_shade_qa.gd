extends GutTest
## QA for UG2: Custom mixes of Lamp light Far, mode switching order, span edges.

var table: GraphicsTable = null
var play: PlayTuning = PlayTuning.new()
var depot: MapData = null


func before_all() -> void:
	depot = MapData.load_map("depot", MapStyle.new(), 6)


func _roof() -> RoofView:
	var roof := RoofView.build(depot, play.roof)
	add_child_autofree(roof)
	return roof


func test_far_with_sun_shadows_off_does_not_overbrighten() -> void:
	table = GraphicsTable.shared()
	var roof := _roof()
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	var full := lighting.sun.light_energy
	var values := table.preset(&"ultra").copy()
	values.sun_shadows = false
	GraphicsApply.apply_field(values, lighting, null, GraphicsApply.Server.new(), null, null, null, roof.lamp_lights())
	var shade_works := values.sun_shadows
	var sun_share := lighting.sun.light_energy / full
	var lamp := roof.lamp_lights().lights()[0].light_energy
	assert_false(shade_works)
	assert_true(sun_share <= play.roof.lamp_sun_share + 0.001 or lamp <= play.roof.lamp_light_energy + 0.001,
			"Far, sun shadows off: sun x%.2f and lamps %.0f though the shade casts nothing" % [sun_share, lamp])


func test_switching_far_near_far_off_far_restores_everything() -> void:
	var roof := _roof()
	var lamps := roof.lamp_lights()
	for m: int in [2, 1, 2, 0, 2, 1, 0]:
		lamps.set_mode(m as GraphicsQuality.LampLights, false, true)
		var far: bool = m == GraphicsQuality.LampLights.FAR
		assert_eq(roof.sun_shade().visible, far)
		assert_eq(roof.get_node("HallHaze").visible, far)
		if m != 0:
			var e := play.roof.lamp_shaded_energy if far else play.roof.lamp_light_energy
			assert_almost_eq(lamps.lights()[0].light_energy, e, 0.001)
	lamps.set_mode(GraphicsQuality.LampLights.FAR, true, true)
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false, true)
	assert_almost_eq(lamps.lights()[0].light_energy, play.roof.lamp_shaded_energy, 0.001)


func test_span_edges() -> void:
	var cfg := RoofConfig.new()
	for x0: float in [-8.0, 0.0, 4.0, 4.8, 3.2, 7.99, 12.0, -4.0]:
		for w: float in [0.1, 0.5, 1.6, 8.0, 40.0]:
			var spans := RoofView.shade_spans(Rect2(x0, 0, w, 3), cfg)
			var at: float = x0
			for s: Vector2 in spans:
				assert_gte(s.x, at - 0.0001)
				assert_gte(s.y, s.x, "non-empty %s %s" % [x0, w])
				assert_lte(s.y, x0 + w + 0.0001)
				at = s.y
	cfg.rooflight_half = 5.0
	assert_eq(RoofView.shade_spans(Rect2(0, 0, 40, 3), cfg).size(), 0, "rooflights wider than bays: no shade")


func _apply(values: GraphicsQuality, lighting: FieldLighting, roof: RoofView) -> void:
	GraphicsApply.apply_field(values, lighting, null, GraphicsApply.Server.new(), null, null, null, roof.lamp_lights())


func test_preset_round_trip_restores_shadow_distance_and_fades() -> void:
	table = GraphicsTable.shared()
	var roof := _roof()
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	var lamps := roof.lamp_lights()
	var hi := table.preset(&"high").copy()
	_apply(hi, lighting, roof)
	var d_high := lighting.sun.directional_shadow_max_distance
	var fade_high := lamps.lights()[0].distance_fade_begin
	var e_high := lamps.lights()[0].light_energy
	var sun_high := lighting.sun.light_energy
	var ultra := table.preset(&"ultra").copy()
	_apply(ultra, lighting, roof)
	assert_true(lamps.shaded())
	assert_gte(lighting.sun.directional_shadow_max_distance * lighting.sun.directional_shadow_fade_start, lamps.shade_reach() - 0.01)
	_apply(hi, lighting, roof)
	assert_false(lamps.shaded())
	assert_almost_eq(lighting.sun.directional_shadow_max_distance, d_high, 0.001)
	assert_almost_eq(lamps.lights()[0].distance_fade_begin, fade_high, 0.001)
	assert_almost_eq(lamps.lights()[0].light_energy, e_high, 0.001)
	assert_almost_eq(lighting.sun.light_energy, sun_high, 0.001)
	assert_false(roof.sun_shade().visible)


func test_custom_far_short_range_and_mid_match_sun_shadow_toggle() -> void:
	table = GraphicsTable.shared()
	var roof := _roof()
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	var lamps := roof.lamp_lights()
	var v := table.preset(&"ultra").copy()
	v.shadow_range = 10 if v.shadow_range > 10 else v.shadow_range
	var short := v.shadow_range
	_apply(v, lighting, roof)
	assert_gte(lighting.sun.directional_shadow_max_distance, float(short))
	assert_gte(lighting.sun.directional_shadow_max_distance * lighting.sun.directional_shadow_fade_start, lamps.shade_reach() - 0.01)
	var full := lighting.sun.light_energy
	v.sun_shadows = false
	_apply(v, lighting, roof)
	assert_false(lamps.shaded())
	assert_false(roof.sun_shade().visible)
	assert_almost_eq(lighting.sun.directional_shadow_max_distance, float(short), 0.001)
	assert_almost_eq(lamps.lights()[0].light_energy, play.roof.lamp_light_energy, 0.001)
	v.sun_shadows = true
	_apply(v, lighting, roof)
	assert_true(lamps.shaded())
	assert_almost_eq(lamps.lights()[0].light_energy, play.roof.lamp_shaded_energy, 0.001)
	assert_almost_eq(lighting.sun.light_energy, full, 0.001)


func test_null_lighting_and_lamps() -> void:
	var roof := _roof()
	var v := GraphicsTable.shared().preset(&"ultra").copy()
	GraphicsApply.apply_field(v, null, null, GraphicsApply.Server.new(), null, null, null, roof.lamp_lights())
	assert_true(roof.lamp_lights().shaded())
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	GraphicsApply.apply_field(v, lighting, null, GraphicsApply.Server.new(), null, null, null, null)
	assert_true(true)
