extends GutTest
## Graphics › Lamp light (RoofLamps, data/graphics.md): Depot's roof lamps as real shadow-casting spots, off on Low and
## Medium; on High and Ultra every lamp lights the whole hall, shadowed near on High and all the way on Ultra, with no
## sun and less sky light under the roof while they shine, both back when they stop;
## their shadows following the shadow rows (atlas, filter, contact hardening on Softest); the figures' shadow twins kept
## while only the lamps cast; a night pool's light unshadowed by its own lantern or campfire; and an open-air field
## untouched. Headless: properties and counts, never pixels.

var table: GraphicsTable = null
var play: PlayTuning = PlayTuning.new()
var depot: MapData = null
var _atlas: int = 0
var _slots: Array[int] = []


func before_all() -> void:
	depot = MapData.load_map("depot", MapStyle.new(), 6)


func before_each() -> void:
	table = GraphicsTable.shared()
	_atlas = get_tree().root.positional_shadow_atlas_size
	_slots.clear()
	for q in 4:
		_slots.append(get_tree().root.get_positional_shadow_atlas_quadrant_subdiv(q))


func after_each() -> void:
	get_tree().root.positional_shadow_atlas_size = _atlas
	for q in 4:
		get_tree().root.set_positional_shadow_atlas_quadrant_subdiv(q, _slots[q] as Viewport.PositionalShadowAtlasQuadrantSubdiv)


func _roof() -> RoofView:
	var roof := RoofView.build(depot, play.roof)
	add_child_autofree(roof)
	return roof


func test_the_presets_light_the_lamps_from_high_up() -> void:
	assert_eq(table.preset(&"low").lamp_lights, GraphicsQuality.LampLights.OFF)
	assert_eq(table.preset(&"medium").lamp_lights, GraphicsQuality.LampLights.OFF)
	assert_eq(table.preset(&"high").lamp_lights, GraphicsQuality.LampLights.NEAR)
	assert_eq(table.preset(&"ultra").lamp_lights, GraphicsQuality.LampLights.FAR)


func test_every_lamp_gets_a_downward_shadowed_spot_under_its_lens() -> void:
	var roof := _roof()
	var lamps := roof.lamp_lights()
	assert_not_null(lamps)
	assert_eq(lamps.light_count(), roof.lamp_count(), "one light a lamp")
	assert_false(lamps.visible, "off until the graphics say")
	for spot in lamps.lights():
		assert_true(spot.shadow_enabled, "%s casts a shadow, so it never shines through a room's roof" % spot.name)
		assert_true(spot.distance_fade_enabled)
		assert_lt(spot.global_position.y, depot.roof_height, "under the roof")
		assert_gt(spot.global_position.y, depot.roof_height - 2.0, "at the lamp, not down in the hall")
		assert_almost_eq((spot.global_basis * Vector3.FORWARD).y, -1.0, 0.001, "shining straight down")
		assert_eq(spot.light_bake_mode, Light3D.BAKE_STATIC, "baked into the bounce light, never updated per frame")


func test_near_and_far_light_the_whole_hall_and_shadow_near_or_all_of_it() -> void:
	var cfg := play.roof
	var lamps := _roof().lamp_lights()
	lamps.set_mode(GraphicsQuality.LampLights.NEAR, false)
	assert_true(lamps.visible)
	var spot := lamps.lights()[0]
	assert_gt(lamps.reach(), 130.0, "past Depot's roof diagonal, so every lamp lights the hall without a sun")
	assert_almost_eq(spot.distance_fade_begin + spot.distance_fade_length, lamps.reach(), 0.001)
	assert_almost_eq(spot.distance_fade_shadow, cfg.lamp_near, 0.001, "High shadows only the near lamps")
	assert_almost_eq(spot.light_size, 0.0, 0.001, "hard-edged off Softest")
	lamps.set_mode(GraphicsQuality.LampLights.FAR, true)
	assert_almost_eq(spot.distance_fade_begin + spot.distance_fade_length, lamps.reach(), 0.001)
	assert_almost_eq(spot.distance_fade_shadow, lamps.reach(), 0.001, "Ultra shadows every lamp it lights")
	assert_almost_eq(spot.light_size, cfg.lamp_lens_size, 0.001, "contact hardening on Softest")
	lamps.set_mode(GraphicsQuality.LampLights.OFF, true)
	assert_false(lamps.visible)


func test_the_sun_goes_out_indoors_while_the_lamps_shine_and_comes_back() -> void:
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	var full := lighting.sun.light_energy
	var sky := lighting.environment.ambient_light_energy
	var lamps := _roof().lamp_lights()
	var rs := GraphicsApply.Server.new()
	for preset: StringName in [&"ultra", &"high"]:
		GraphicsApply.apply_field(table.preset(preset), lighting, null, rs, null, null, null, lamps)
		assert_true(lamps.visible, preset)
		assert_almost_eq(lighting.sun.light_energy, 0.0, 0.001, "%s: no sun gets under the roof" % preset)
		assert_false(lighting.sun.visible, "%s: and its shadow passes go" % preset)
		assert_almost_eq(lighting.environment.ambient_light_energy, sky * play.roof.lamp_ambient_share, 0.001,
				"%s: less sky light, so the lamps' shadows stay deep" % preset)
	GraphicsApply.apply_field(table.preset(&"medium"), lighting, null, rs, null, null, null, lamps)
	assert_false(lamps.visible)
	assert_true(lighting.sun.visible)
	assert_almost_eq(lighting.sun.light_energy, full, 0.001, "the overhead light stands in for the lamps again")
	assert_almost_eq(lighting.environment.ambient_light_energy, sky, 0.001)


func test_the_ceiling_keeps_the_sky_out_of_the_bounce_light_while_the_lamps_shine() -> void:
	var roof := _roof()
	var ceiling := roof.get_node("Ceiling") as GeometryInstance3D
	assert_eq(ceiling.gi_mode, GeometryInstance3D.GI_MODE_DISABLED, "the sky lights the hall for the stand-in")
	roof.lamp_lights().set_mode(GraphicsQuality.LampLights.FAR, false)
	assert_eq(ceiling.gi_mode, GeometryInstance3D.GI_MODE_STATIC, "the roof blocks the sky in Ultra's bounce light")
	roof.lamp_lights().set_mode(GraphicsQuality.LampLights.NEAR, false)
	assert_eq(ceiling.gi_mode, GeometryInstance3D.GI_MODE_STATIC)
	roof.lamp_lights().set_mode(GraphicsQuality.LampLights.OFF, false)
	assert_eq(ceiling.gi_mode, GeometryInstance3D.GI_MODE_DISABLED)


func test_an_open_field_keeps_its_sun() -> void:
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	var full := lighting.sun.light_energy
	var sky := lighting.environment.ambient_light_energy
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, GraphicsApply.Server.new())
	assert_almost_eq(lighting.sun.light_energy, full, 0.001)
	assert_true(lighting.sun.visible)
	assert_almost_eq(lighting.environment.ambient_light_energy, sky, 0.001)


func test_their_shadows_follow_the_shadow_rows() -> void:
	var root := get_tree().root
	var rs := GraphicsApply.Server.new()
	var default_atlas := ProjectSettings.get_setting(GraphicsApply.LAMP_ATLAS_SIZE) as int
	GraphicsApply.apply(table.preset(&"medium"), root, rs)
	assert_eq(root.positional_shadow_atlas_size, default_atlas, "the torch's atlas as tuned, lamps off")
	GraphicsApply.apply(table.preset(&"ultra"), root, rs)
	assert_eq(root.positional_shadow_atlas_size, 8192, "Ultra's Shadow detail")
	var slots := 0
	for q in 4:
		slots += [0, 1, 4, 16, 64, 256, 1024][root.get_positional_shadow_atlas_quadrant_subdiv(q)] as int
	assert_gte(slots, 93 + 8 + 1, "a shadow for every lamp, the pools and the torch")
	assert_eq(rs.lamp_soft, RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "Softest's filter")
	assert_eq(GraphicsApply.glass_atlas(table.preset(&"ultra")), 4096, "the optic glass at half")
	assert_eq(GraphicsApply.glass_atlas(table.preset(&"medium")), 0, "and none with the lamps off, as before")


func test_the_figures_keep_their_shadows_while_only_the_lamps_cast() -> void:
	var q := table.preset(&"ultra")
	q.sun_shadows = false
	assert_true(GraphicsApply.any_shadows(q))
	q.lamp_lights = GraphicsQuality.LampLights.OFF
	assert_false(GraphicsApply.any_shadows(q))


func test_a_repeat_changes_nothing() -> void:
	var lamps := _roof().lamp_lights()
	lamps.set_mode(GraphicsQuality.LampLights.FAR, true)
	var spot := lamps.lights()[0]
	spot.light_size = 9.0
	lamps.set_mode(GraphicsQuality.LampLights.FAR, true)
	assert_almost_eq(spot.light_size, 9.0, 0.001, "nothing set again when nothing changed")


func test_a_pool_light_is_not_shadowed_by_the_lantern_or_campfire_it_sits_in() -> void:
	var map := MapData.load_map("woodland", play.map_style, 6)
	var night := LightingConfig.new()
	night.night = true
	var pools := LightPools.build(map, night)
	var fixtures := LightFixtures.build(map, play.light_fixtures,
			LightingConfig.for_map(play.lighting, play.night_lighting, map, LightingConfig.NIGHT))
	assert_not_null(pools)
	assert_not_null(fixtures)
	add_child_autofree(pools)
	add_child_autofree(fixtures)
	pools.set_real_count(2)
	pools.set_shadows(true)
	for light in pools.real_lights():
		assert_eq(light.shadow_caster_mask & LightFixtures.LAYER, 0, "the fixtures' layer is left out")
		assert_ne(light.shadow_caster_mask & 1, 0, "the field, its props and the players still cast")
	for view in fixtures.find_children("*", "MultiMeshInstance3D", false, false):
		assert_ne((view as VisualInstance3D).layers & LightFixtures.LAYER, 0, "%s on the fixtures' layer" % view.name)
		assert_ne((view as VisualInstance3D).layers & 1, 0, "and still drawn with the field")
