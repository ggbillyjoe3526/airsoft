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


func test_the_sun_filter_is_never_softer_than_the_lamp_filter_and_hard_stays_hard() -> void:
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
