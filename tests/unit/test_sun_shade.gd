extends GutTest
## Lamp light Far's sun shade (UG2, RoofView.sun_shade): on Ultra an indoor field's roof shades the sun but at its
## rooflights, halfway between the trusses where the bay model's rooflight strips lie, with a thicker haze under it so
## the sun shows in shafts; the lamps shine brighter and the sun keeps its share for it; Near and Off show neither, nor
## does Far with Sun shadows off; shaded, every lamp and the sun's shadows reach the roof's far corner. A roof without
## the bay model has no shade. Headless: geometry and properties, never pixels.

var play: PlayTuning = PlayTuning.new()
var depot: MapData = null


func before_all() -> void:
	depot = MapData.load_map("depot", MapStyle.new(), 6)


func _roof(cfg: RoofConfig = play.roof) -> RoofView:
	var roof := RoofView.build(depot, cfg)
	add_child_autofree(roof)
	return roof


func test_the_shade_leaves_a_rooflight_halfway_between_each_pair_of_trusses() -> void:
	var cfg := RoofConfig.new()
	cfg.truss_step = 8.0
	cfg.rooflight_half = 0.8
	var spans := RoofView.shade_spans(Rect2(-1.0, 0.0, 10.0, 5.0), cfg)
	assert_eq(spans.size(), 2, "one rooflight inside (at 4 m), the next (12 m) past the end")
	assert_almost_eq(spans[0].x, -1.0, 0.001, "from the roof's edge")
	assert_almost_eq(spans[0].y, 3.2, 0.001)
	assert_almost_eq(spans[1].x, 4.8, 0.001)
	assert_almost_eq(spans[1].y, 9.0, 0.001, "to the roof's edge")
	var lead := RoofView.shade_spans(Rect2(3.5, 0.0, 9.0, 5.0), cfg)
	assert_almost_eq(lead[0].x, 4.8, 0.001, "a roof starting in a rooflight starts shaded past it")


func test_every_gap_lies_on_a_rooflight_and_the_rest_is_shaded() -> void:
	var cfg := play.roof
	var area := depot.footprint().grow(cfg.ceiling_overhang)
	var spans := RoofView.shade_spans(area, cfg)
	var shaded := 0.0
	var at := area.position.x
	for span in spans:
		assert_gte(span.x, at, "in order, never overlapping")
		if span.x > at + 0.001:
			var gap_mid := (at + span.x) * 0.5
			var off_line := fposmod(gap_mid, cfg.truss_step) - cfg.truss_step * 0.5
			assert_almost_eq(off_line, 0.0, cfg.rooflight_half + 0.001, "a gap halfway between two trusses")
		shaded += span.y - span.x
		at = span.y
	var share := shaded / area.size.x
	var open := 2.0 * cfg.rooflight_half / cfg.truss_step
	assert_almost_eq(share, 1.0 - open, 0.03, "a fifth of the roof lets the sun in, as the bay model draws it")


func test_far_shows_the_shade_and_haze_and_brightens_the_lamps() -> void:
	var cfg := play.roof
	var roof := _roof()
	var shade := roof.sun_shade()
	assert_not_null(shade)
	assert_eq(shade.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "a shadow, never drawn")
	assert_false(shade.visible, "hidden until Far")
	assert_gt(shade.mesh.get_aabb().position.y, depot.roof_height, "over the roof, so it never shades the sheet")
	var haze := roof.get_node("HallHaze") as FogVolume
	assert_false(haze.visible)
	var lamps := roof.lamp_lights()
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false, true)
	assert_true(shade.visible)
	assert_true(haze.visible, "the shafts show in a thicker haze")
	assert_almost_eq(lamps.lights()[0].light_energy, cfg.lamp_shaded_energy, 0.001)
	assert_almost_eq(lamps.key_share(GraphicsQuality.LampLights.FAR), cfg.shade_sun_share, 0.001)
	lamps.set_mode(GraphicsQuality.LampLights.NEAR, false, true)
	assert_false(shade.visible, "Near lights only the lamps near you, so the sun keeps lighting the rest")
	assert_false(haze.visible)
	assert_almost_eq(lamps.lights()[0].light_energy, cfg.lamp_light_energy, 0.001)
	assert_almost_eq(lamps.key_share(GraphicsQuality.LampLights.NEAR), cfg.lamp_sun_share, 0.001)
	lamps.set_mode(GraphicsQuality.LampLights.OFF, false, true)
	assert_false(shade.visible)
	assert_almost_eq(lamps.key_share(GraphicsQuality.LampLights.OFF), 1.0, 0.001)


func test_no_shade_while_the_sun_casts_no_shadow() -> void:
	var cfg := play.roof
	var roof := _roof()
	var lamps := roof.lamp_lights()
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	var full := lighting.sun.light_energy
	var q := GraphicsTable.shared().preset(&"ultra").copy()
	q.sun_shadows = false
	GraphicsApply.apply_field(q, lighting, null, GraphicsApply.Server.new(), null, null, null, lamps)
	assert_false(roof.sun_shade().visible, "Custom Ultra with Sun shadows off: a shadow-only shade blocks nothing")
	assert_false(lamps.shaded())
	assert_almost_eq(lighting.sun.light_energy, full * cfg.lamp_sun_share, 0.001, "Near's mix instead")
	assert_almost_eq(lamps.lights()[0].light_energy, cfg.lamp_light_energy, 0.001)
	assert_almost_eq(lamps.lights()[0].distance_fade_shadow, cfg.lamp_far, 0.001)
	q.sun_shadows = true
	GraphicsApply.apply_field(q, lighting, null, GraphicsApply.Server.new(), null, null, null, lamps)
	assert_true(roof.sun_shade().visible, "shaded again with the sun's shadows back")
	assert_almost_eq(lighting.sun.light_energy, full * cfg.shade_sun_share, 0.001)


func test_shaded_the_lamps_and_the_suns_shadows_cover_the_whole_roof() -> void:
	var cfg := play.roof
	var roof := _roof()
	var lamps := roof.lamp_lights()
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	var area := depot.footprint().grow(cfg.ceiling_overhang)
	var corner_to_corner := Vector3(area.size.x, depot.roof_height, area.size.y).length()
	assert_gt(corner_to_corner, cfg.lamp_far, "Depot's hall is longer than Far's usual reach")
	var q := GraphicsTable.shared().preset(&"ultra").copy()
	GraphicsApply.apply_field(q, lighting, null, GraphicsApply.Server.new(), null, null, null, lamps)
	assert_true(lamps.shaded())
	for spot in lamps.lights():
		assert_gte(spot.distance_fade_begin, corner_to_corner - 0.01, "%s lit from the roof's far corner" % spot.name)
	var sun := lighting.sun
	assert_gte(sun.directional_shadow_max_distance * sun.directional_shadow_fade_start, corner_to_corner - 0.01,
			"the sun's shadows (so the shade) reach the far corner before they fade")
	q.lamp_lights = GraphicsQuality.LampLights.NEAR
	GraphicsApply.apply_field(q, lighting, null, GraphicsApply.Server.new(), null, null, null, lamps)
	assert_almost_eq(sun.directional_shadow_max_distance, float(q.shadow_range), 0.001, "the row's range again")
	assert_almost_eq(lamps.lights()[0].distance_fade_shadow, cfg.lamp_near, 0.001)


func test_a_roof_without_the_bay_model_has_no_shade() -> void:
	var cfg := play.roof.duplicate() as RoofConfig
	cfg.bay_model = ""
	var roof := _roof(cfg)
	assert_null(roof.sun_shade())
	var lamps := roof.lamp_lights()
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false, true)
	assert_almost_eq(lamps.key_share(GraphicsQuality.LampLights.FAR), cfg.lamp_sun_share, 0.001, "the sun dims instead")
	assert_almost_eq(lamps.lights()[0].light_energy, cfg.lamp_light_energy, 0.001)
