extends GutTest
## QA for BP9 part 3 (light): edge cases of AreaProbes.capture_spot and the two shadow filter tables.

const BAND := Vector2(-1000.0, 1000.0)

var play: PlayTuning = PlayTuning.load_default()
var table: GraphicsTable = GraphicsTable.shared()


func _kiosk(c: Vector3, size: Vector3) -> Array[AABB]:
	var out: Array[AABB] = [AABB(c - size * 0.5, size)]
	return out


func test_a_box_smaller_than_the_clearance_falls_back_to_its_middle() -> void:
	var box := Rect2(0.0, 0.0, 0.3, 0.3)
	var solids := _kiosk(Vector3(0.15, 1.0, 0.15), Vector3(0.1, 2.0, 0.1))
	var eye := AreaProbes.capture_spot(box, BAND, play.look, null, 0.0, solids)
	assert_eq(Vector2(eye.x, eye.z), box.get_center(), "no spot in the box: the middle")
	assert_false(is_nan(eye.y), "a real height")


func test_a_zero_or_negative_clearance_keeps_the_middle_even_inside_a_prop() -> void:
	var box := Rect2(-5.0, -5.0, 10.0, 10.0)
	var solids := _kiosk(Vector3(0.0, 1.0, 0.0), Vector3(4.0, 4.0, 4.0))
	for room: float in [0.0, -1.0]:
		var look := LookConfig.new()
		look.probe_clearance = room
		var eye := AreaProbes.capture_spot(box, BAND, look, null, 0.0, solids)
		assert_eq(Vector2(eye.x, eye.z), Vector2.ZERO, "clearance %.1f: the middle" % room)


func test_a_spot_on_a_hill_stands_eye_high_over_the_ground_under_it() -> void:
	var slope := func(x: float, _z: float) -> float: return x * 0.2
	var terrain := TerrainGrid.create(-10.0, -10.0, 2.0, 10, 10, slope)
	var box := Rect2(-8.0, -8.0, 16.0, 16.0)
	var solids := _kiosk(Vector3(0.0, 1.0, 0.0), Vector3(4.0, 8.0, 4.0))
	var eye := AreaProbes.capture_spot(box, Vector2(-1.6, 6.0), play.look, terrain, 0.0, solids)
	assert_almost_eq(eye.y, eye.x * 0.2 + play.look.probe_eye, 0.01, "eye height over the slope at the spot")
	assert_false(solids[0].grow(play.look.probe_clearance - 0.01).has_point(eye), "clear of the prop")


func test_a_box_off_the_terrain_grid_does_not_give_a_nan_eye() -> void:
	var terrain := TerrainGrid.create(0.0, 0.0, 1.0, 2, 2, func(_x: float, _z: float) -> float: return 1.0)
	var box := Rect2(50.0, 50.0, 6.0, 6.0)
	var solids := _kiosk(Vector3(53.0, 1.0, 53.0), Vector3(2.0, 2.0, 2.0))
	var eye := AreaProbes.capture_spot(box, BAND, play.look, terrain, 0.0, solids)
	assert_false(is_nan(eye.x) or is_nan(eye.y) or is_nan(eye.z), "no NaN")
	assert_almost_eq(eye.y, play.look.probe_eye, 0.001, "off the grid counts as ground level 0")


func test_a_spot_whose_ground_is_below_the_probes_floor_is_not_taken() -> void:
	# A band floor at 3.0: a clear spot on ground at 0 would sit below the probe's box.
	var terrain := TerrainGrid.create(-10.0, -10.0, 2.0, 10, 10, func(_x: float, _z: float) -> float: return 0.0)
	var box := Rect2(-4.0, -4.0, 8.0, 8.0)
	var solids := _kiosk(Vector3(0.0, 1.0, 0.0), Vector3(2.0, 3.0, 2.0))
	var eye := AreaProbes.capture_spot(box, Vector2(3.0, 9.0), play.look, terrain, 0.0, solids)
	assert_eq(Vector2(eye.x, eye.z), Vector2.ZERO, "every candidate rejected: the middle")


func test_every_probe_on_every_map_keeps_its_eye_finite_and_inside_its_box() -> void:
	for id: String in ["depot", "woodland", "subway", "range"]:
		var map := MapData.load_map(id, play.map_style, SimTuning.new().rounds.team_size)
		var probes := AreaProbes.build(map, play.look)
		add_child_autofree(probes)
		for p: ReflectionProbe in probes.get_children():
			var eye := p.position + p.origin_offset
			assert_true(eye.is_finite(), "%s %s: finite eye" % [id, p.name])
			assert_true(AABB(p.position - p.size * 0.5, p.size).has_point(eye), "%s %s: eye in box" % [id, p.name])


func test_the_suns_filter_is_never_coarser_than_the_lamps_and_low_stays_hard() -> void:
	var rs := GraphicsApply.Server.new()
	var vp := SubViewport.new()
	add_child_autofree(vp)
	var sun: Array[int] = []
	for name: StringName in [&"low", &"medium", &"high", &"ultra"]:
		GraphicsApply.apply(table.preset(name), vp, rs)
		sun.append(rs.soft_shadows)
		assert_gte(rs.soft_shadows, rs.lamp_soft, "%s: the sun's filter at least the lamps'" % name)
	assert_eq(sun[0], RenderingServer.SHADOW_QUALITY_HARD, "Low is hard")
	assert_eq(sun[2], ProjectSettings.get_setting(GraphicsApply.Server.SOFT_SHADOWS), "High sends the project's own filter")
	for i in GraphicsQuality.ShadowSoftness.size():
		assert_lt(GraphicsApply.SOFTNESS[i], RenderingServer.SHADOW_QUALITY_MAX, "a valid filter")
		assert_lt(GraphicsApply.LAMP_SOFTNESS[i], RenderingServer.SHADOW_QUALITY_MAX, "a valid lamp filter")


func _spots(n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in n:
		out.append(Vector3(float(i) * 4.0, 5.0, 0.0))
	return out


func test_a_hall_set_first_with_the_bounce_on_shines_at_the_bounce_strength() -> void:
	var cfg := RoofConfig.new()
	var lamps := RoofLamps.build(_spots(2), cfg)
	add_child_autofree(lamps)
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false, true)
	for l in lamps.lights():
		assert_almost_eq(l.light_energy, cfg.lamp_bounce_energy, 0.0001, "first call, bounce on")


func test_a_flicker_step_while_the_lamps_are_off_is_kept_for_the_next_strength() -> void:
	var cfg := RoofConfig.new()
	var states := PackedByteArray([MapData.LAMP_FLICKER, MapData.LAMP_WORKING])
	var lamps := RoofLamps.build(_spots(2), cfg, 0.0, null, states)
	add_child_autofree(lamps)
	lamps.set_mode(GraphicsQuality.LampLights.OFF, false, false)
	lamps.set_flicker(0, cfg.lamp_flicker_low)
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false, true)
	assert_almost_eq(lamps.light_of(0).light_energy, cfg.lamp_bounce_energy * cfg.lamp_flicker_low, 0.0001)
	assert_almost_eq(lamps.light_of(1).light_energy, cfg.lamp_bounce_energy, 0.0001)


func test_a_plain_roofs_flicker_ignores_the_bounce_switch() -> void:
	var cfg := RoofConfig.new()
	var states := PackedByteArray([MapData.LAMP_FLICKER])
	var reaches := PackedFloat32Array([6.0])
	var lamps := RoofLamps.build(_spots(1), cfg, 0.0, null, states, reaches)
	add_child_autofree(lamps)
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false, true)
	lamps.set_flicker(0, 0.5)
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false, false)
	assert_almost_eq(lamps.light_of(0).light_energy, cfg.plain_lamp_energy * 0.5, 0.0001)


func test_an_all_dead_roof_takes_every_mode_and_flicker_without_error() -> void:
	var cfg := RoofConfig.new()
	var states := PackedByteArray([MapData.LAMP_DEAD, MapData.LAMP_DEAD])
	var lamps := RoofLamps.build(_spots(2), cfg, 0.0, null, states)
	add_child_autofree(lamps)
	lamps.set_mode(GraphicsQuality.LampLights.FAR, true, true)
	lamps.set_flicker(0, 0.3)
	lamps.set_mode(GraphicsQuality.LampLights.NEAR, false, false)
	assert_eq(lamps.light_count(), 0, "no lights")
	assert_eq(lamps.key_share(GraphicsQuality.LampLights.FAR), 1.0, "the sun stays with no lamp to stand for")


func _field(id: String) -> FieldLighting:
	var field := MapData.load_map(id, play.map_style, SimTuning.new().rounds.team_size)
	var lighting := FieldLighting.build(LightingConfig.for_map(play.lighting, play.night_lighting, field,
			LightingConfig.DAY), play.look)
	add_child_autofree(lighting)
	lighting.add_probes(field)
	return lighting


func _probe_modes(lighting: FieldLighting) -> Array[int]:
	var out: Array[int] = []
	for p in lighting.find_children("*", "ReflectionProbe", true, false):
		out.append((p as ReflectionProbe).ambient_mode)
	return out


func test_hidden_probes_still_follow_the_bounce_light_with_reflections_off() -> void:
	# Reflections Off hides the probes; Global illumination Scene still sets their ambient, so turning Reflections
	# back on shows them right, with no error either way.
	var lighting := _field("depot")
	var rs := GraphicsApply.Server.new()
	var values := table.preset(&"ultra").copy()
	values.reflections = GraphicsQuality.Reflections.OFF
	GraphicsApply.apply_field(values, lighting, null, rs)
	var probes := lighting.find_children("*", "ReflectionProbe", true, false)
	assert_gt(probes.size(), 1)
	assert_false((probes[0] as ReflectionProbe).is_visible_in_tree())
	for m in _probe_modes(lighting):
		assert_eq(m, ReflectionProbe.AMBIENT_ENVIRONMENT)
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, rs)
	for m in _probe_modes(lighting):
		assert_eq(m, ReflectionProbe.AMBIENT_ENVIRONMENT)


func test_set_effects_without_probes_takes_the_bounce_light_without_error() -> void:
	var field := MapData.load_map("depot", play.map_style, SimTuning.new().rounds.team_size)
	var lighting := FieldLighting.build(LightingConfig.for_map(play.lighting, play.night_lighting, field,
			LightingConfig.DAY), play.look)
	add_child_autofree(lighting)
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, GraphicsApply.Server.new())
	assert_eq(lighting.find_children("*", "ReflectionProbe", true, false).size(), 0)
	assert_true(lighting.environment.sdfgi_enabled)


func test_an_open_fields_probes_never_change_ambient_on_any_preset() -> void:
	var lighting := _field("woodland")
	var before := _probe_modes(lighting)
	assert_gt(before.size(), 0)
	var rs := GraphicsApply.Server.new()
	for preset: StringName in [&"low", &"ultra", &"medium", &"ultra"]:
		GraphicsApply.apply_field(table.preset(preset), lighting, null, rs)
		assert_eq(_probe_modes(lighting), before, str(preset))


func test_a_repeat_of_the_same_bounce_state_leaves_the_probes_alone() -> void:
	var probes := AreaProbes.new()
	add_child_autofree(probes)
	probes.set_bounce(false)
	probes.set_bounce(true)
	probes.set_bounce(true)
	probes.set_bounce(false)
	assert_eq(probes.get_child_count(), 0, "no probes: nothing to set, nothing breaks")


func test_the_probes_follow_the_lamps_flag_for_the_bounce_light() -> void:
	# The probes' flag (FieldLighting.set_effects: gi == SCENE) and the lamps' (apply_field: gi == SCENE) are the one
	# test on `values`: on every preset the interior probes keep their ambient exactly when the lamps take their
	# bounce strength.
	var lighting := _field("depot")
	var rs := GraphicsApply.Server.new()
	for preset: StringName in [&"low", &"medium", &"high", &"ultra"]:
		var values := table.preset(preset)
		GraphicsApply.apply_field(values, lighting, null, rs)
		var scene := values.global_illumination == GraphicsQuality.GlobalIllumination.SCENE
		for m in _probe_modes(lighting):
			assert_eq(m == ReflectionProbe.AMBIENT_ENVIRONMENT, scene, str(preset))


## The sun's blur and size on `preset` for `map` by `time`, as a match sets them.
func _sun_blur_and_size(preset: StringName, map: String, time: StringName) -> Vector2:
	var field := MapData.load_map(map, play.map_style, SimTuning.new().rounds.team_size)
	var lighting := FieldLighting.build(LightingConfig.for_map(play.lighting, play.night_lighting, field, time),
			play.look)
	add_child_autofree(lighting)
	GraphicsApply.apply_field(table.preset(preset), lighting, null, GraphicsApply.Server.new())
	return Vector2(lighting.sun.shadow_blur, lighting.sun.light_angular_distance)


func test_softest_sun_has_mains_blur_and_size_on_every_field_by_day_and_night() -> void:
	# On main the blur was 1.5 by day and 2 by night on every preset, the size the Look's on Softest.
	for map: String in ["woodland", "range", "depot", "subway"]:
		for c: Array in [[LightingConfig.DAY, 1.5], [LightingConfig.NIGHT, 2.0]]:
			var got := _sun_blur_and_size(&"ultra", map, c[0])
			assert_almost_eq(got.x, c[1], 0.0001, "%s by %s: Softest's blur" % [map, c[0]])
			assert_almost_eq(got.y, play.look.sun_size, 0.0001, "%s by %s: Softest's size" % [map, c[0]])


func test_the_softer_presets_keep_the_wider_blur_and_no_sun_size() -> void:
	for preset: StringName in [&"medium", &"high"]:
		for time: StringName in [LightingConfig.DAY, LightingConfig.NIGHT]:
			var got := _sun_blur_and_size(preset, "woodland", time)
			assert_almost_eq(got.x, 2.0, 0.0001, "%s by %s: the blur the fixed filters took" % [preset, time])
			assert_almost_eq(got.y, 0.0, 0.0001, "%s by %s: no size" % [preset, time])


func test_a_field_lighting_never_given_effects_keeps_the_shadow_blur() -> void:
	var cfg := LightingConfig.new()
	cfg.shadow_blur = 3.0
	cfg.soft_sun_blur = 0.7
	var lighting := FieldLighting.build(cfg)
	add_child_autofree(lighting)
	assert_almost_eq(lighting.sun.shadow_blur, 3.0, 0.0001, "built: shadow_blur")


func test_softest_with_the_sun_shut_out_takes_the_fixed_blur_and_comes_back() -> void:
	# Underground (Subway) the sun casts nothing on Softest: the blur is the fixed one; nothing is lost on a return.
	var field := MapData.load_map("subway", play.map_style, SimTuning.new().rounds.team_size)
	var cfg := LightingConfig.for_map(play.lighting, play.night_lighting, field, LightingConfig.DAY)
	var lighting := FieldLighting.build(cfg, play.look)
	add_child_autofree(lighting)
	lighting.set_underground(true)
	var rs := GraphicsApply.Server.new()
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, rs)
	assert_false(lighting.sun.shadow_enabled, "shut out")
	assert_almost_eq(lighting.sun.shadow_blur, cfg.shadow_blur, 0.0001, "the fixed blur, nothing reads it")
	assert_almost_eq(lighting.sun.light_angular_distance, 0.0, 0.0001, "no size")
	lighting.set_underground(false)
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, rs)
	assert_almost_eq(lighting.sun.shadow_blur, cfg.soft_sun_blur, 0.0001, "back on: Softest's blur")


func test_a_map_override_and_the_moon_keep_the_softest_blur() -> void:
	# for_map duplicates the preset: the copy carries soft_sun_blur, not the class default.
	var cfg := LightingConfig.new()
	cfg.id = &"x"
	cfg.soft_sun_blur = 0.9
	var copy := cfg.duplicate() as LightingConfig
	assert_almost_eq(copy.soft_sun_blur, 0.9, 0.0001)
