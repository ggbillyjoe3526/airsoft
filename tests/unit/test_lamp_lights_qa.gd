extends GutTest
## QA for Graphics › Lamp light: state a settings change leaves behind (atlas, slots, pool shadows, optic glass), and a
## custom mix (sun shadows off, lamps on) that must not hide the figures' shadow twins.

var table: GraphicsTable = null
var _atlas: int = 0
var _slots: Array[int] = []


func before_each() -> void:
	table = GraphicsTable.shared()
	var root := get_tree().root
	_atlas = root.positional_shadow_atlas_size
	_slots.clear()
	for q in 4:
		_slots.append(root.get_positional_shadow_atlas_quadrant_subdiv(q))


func after_each() -> void:
	var root := get_tree().root
	root.positional_shadow_atlas_size = _atlas
	for q in 4:
		root.set_positional_shadow_atlas_quadrant_subdiv(q, _slots[q] as Viewport.PositionalShadowAtlasQuadrantSubdiv)


func test_turning_the_lamps_off_again_restores_the_atlas_and_its_slots() -> void:
	var root := get_tree().root
	var rs := GraphicsApply.Server.new()
	GraphicsApply.apply(table.preset(&"medium"), root, rs)
	var atlas := root.positional_shadow_atlas_size
	var slots: Array[int] = []
	for q in 4:
		slots.append(root.get_positional_shadow_atlas_quadrant_subdiv(q))
	GraphicsApply.apply(table.preset(&"ultra"), root, rs)
	assert_ne(root.positional_shadow_atlas_size, atlas, "Ultra resizes the atlas")
	GraphicsApply.apply(table.preset(&"medium"), root, rs)
	assert_eq(root.positional_shadow_atlas_size, atlas)
	for q in 4:
		assert_eq(root.get_positional_shadow_atlas_quadrant_subdiv(q), slots[q], "slot %d back" % q)


func test_a_custom_mix_of_lamps_without_sun_shadows_still_casts_for_the_figures() -> void:
	var q := table.preset(&"high")
	q.sun_shadows = false
	assert_true(GraphicsApply.any_shadows(q), "lamps cast")
	assert_true(GraphicsApply.contact_shadows(q), "and the contact shadow stays for where the sun casts none")
	q.lamp_lights = GraphicsQuality.LampLights.OFF
	assert_false(GraphicsApply.any_shadows(q))


func test_pool_shadows_reach_lights_made_after_and_before_the_switch() -> void:
	var night := LightingConfig.new()
	night.night = true
	var pools := LightPools.build(MapData.load_map("woodland", MapStyle.new(), 6), night)
	assert_not_null(pools)
	add_child_autofree(pools)
	pools.set_real_count(2)
	pools.set_shadows(true)
	for light in pools.real_lights():
		assert_true(light.shadow_enabled, "existing light follows")
	pools.set_real_count(4)
	assert_eq(pools.real_lights().size(), 4)
	for light in pools.real_lights():
		assert_true(light.shadow_enabled, "a light made later follows too")
	pools.set_shadows(false)
	for light in pools.real_lights():
		assert_false(light.shadow_enabled)


func test_far_gives_more_real_lights_than_mesh_detail_and_never_fewer() -> void:
	var cfg := LightingConfig.new()
	var q := table.preset(&"medium")
	q.lamp_lights = GraphicsQuality.LampLights.FAR
	assert_eq(GraphicsApply.pool_lights(q, cfg, false), cfg.real_lights_far)
	assert_eq(GraphicsApply.pool_lights(q, cfg, true), cfg.real_lights_far - 1, "the torch still takes one")
	q.lamp_lights = GraphicsQuality.LampLights.NEAR
	assert_eq(GraphicsApply.pool_lights(q, cfg, false), cfg.real_lights_for(q.mesh_detail))
	q.mesh_detail = GraphicsQuality.MeshDetail.ULTRA
	q.lamp_lights = GraphicsQuality.LampLights.FAR
	assert_gte(GraphicsApply.pool_lights(q, cfg, false), cfg.real_lights_for(q.mesh_detail))


func test_switching_between_near_and_far_and_off_leaves_one_consistent_state() -> void:
	var roof := RoofView.build(MapData.load_map("depot", MapStyle.new(), 6), RoofConfig.new())
	add_child_autofree(roof)
	var lamps := roof.lamp_lights()
	var cfg := RoofConfig.new()
	for step: Array in [[GraphicsQuality.LampLights.FAR, true], [GraphicsQuality.LampLights.OFF, true],
			[GraphicsQuality.LampLights.NEAR, false], [GraphicsQuality.LampLights.NEAR, true],
			[GraphicsQuality.LampLights.FAR, false]]:
		lamps.set_mode(step[0], step[1])
		var spot := lamps.lights()[0]
		if step[0] == GraphicsQuality.LampLights.OFF:
			assert_false(lamps.visible)
			continue
		var reach := cfg.lamp_near if step[0] == GraphicsQuality.LampLights.NEAR else lamps.reach()
		assert_true(lamps.visible)
		assert_almost_eq(spot.distance_fade_shadow, reach, 0.001)
		assert_almost_eq(spot.light_size, cfg.lamp_lens_size if step[1] else 0.0, 0.001)
