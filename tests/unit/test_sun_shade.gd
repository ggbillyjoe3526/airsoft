extends GutTest
## Lamp light Far's sun shade (UG2, RoofView.sun_shade): on Ultra an indoor field's roof shades the sun but at its
## rooflights, halfway between the trusses where the bay model's rooflight strips lie, with a thicker haze under it so
## the sun shows in shafts; the lamps shine brighter and the sun keeps its share for it; Near and Off show neither. A
## roof without the bay model has no shade. Headless: geometry and properties, never pixels.

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
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false)
	assert_true(shade.visible)
	assert_true(haze.visible, "the shafts show in a thicker haze")
	assert_almost_eq(lamps.lights()[0].light_energy, cfg.lamp_shaded_energy, 0.001)
	assert_almost_eq(lamps.key_share(GraphicsQuality.LampLights.FAR), cfg.shade_sun_share, 0.001)
	lamps.set_mode(GraphicsQuality.LampLights.NEAR, false)
	assert_false(shade.visible, "Near lights only the lamps near you, so the sun keeps lighting the rest")
	assert_false(haze.visible)
	assert_almost_eq(lamps.lights()[0].light_energy, cfg.lamp_light_energy, 0.001)
	assert_almost_eq(lamps.key_share(GraphicsQuality.LampLights.NEAR), cfg.lamp_sun_share, 0.001)
	lamps.set_mode(GraphicsQuality.LampLights.OFF, false)
	assert_false(shade.visible)
	assert_almost_eq(lamps.key_share(GraphicsQuality.LampLights.OFF), 1.0, 0.001)


func test_a_roof_without_the_bay_model_has_no_shade() -> void:
	var cfg := play.roof.duplicate() as RoofConfig
	cfg.bay_model = ""
	var roof := _roof(cfg)
	assert_null(roof.sun_shade())
	var lamps := roof.lamp_lights()
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false)
	assert_almost_eq(lamps.key_share(GraphicsQuality.LampLights.FAR), cfg.lamp_sun_share, 0.001, "the sun dims instead")
	assert_almost_eq(lamps.lights()[0].light_energy, cfg.lamp_light_energy, 0.001)
