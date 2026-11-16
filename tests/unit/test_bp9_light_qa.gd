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
