extends GutTest
## DW1 QA: edges of the worn roof lamps (short or long state lists, all dead, flicker with the lamps off, frees).

var cfg: RoofConfig = RoofConfig.new()


func _depot() -> MapData:
	return MapData.load_map("depot", MapStyle.new(), 6)


func _roof(map: MapData) -> RoofView:
	var roof := RoofView.build(map, cfg)
	add_child_autofree(roof)
	return roof


func test_states_shorter_than_lamps_leave_the_rest_working() -> void:
	var map := _depot()
	map.roof_lamp_states = map.roof_lamp_states.slice(0, 3)
	var roof := _roof(map)
	assert_eq(roof.lamp_lights().light_count(), map.roof_lamps.size() - map.roof_lamp_states.count(MapData.LAMP_DEAD))
	assert_not_null(roof.lamp_lights().light_of(map.roof_lamps.size() - 1))


func test_no_states_at_all_is_every_lamp_working_and_not_processing() -> void:
	var map := _depot()
	map.roof_lamp_states = PackedByteArray()
	var roof := _roof(map)
	assert_eq(roof.lamp_lights().light_count(), map.roof_lamps.size())
	assert_false(roof.is_processing())


func test_light_of_out_of_range_is_null() -> void:
	var lamps := _roof(_depot()).lamp_lights()
	assert_null(lamps.light_of(-1))
	assert_null(lamps.light_of(100000))
	lamps.set_flicker(100000, 0.5)


func test_an_all_dead_roof_has_no_lights_and_keeps_the_sun() -> void:
	var map := _depot()
	map.roof_lamp_states.fill(MapData.LAMP_DEAD)
	var roof := _roof(map)
	var lamps := roof.lamp_lights()
	assert_eq(lamps.light_count(), 0)
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false)
	assert_eq(lamps.key_share(GraphicsQuality.LampLights.FAR), 1.0, "the sun stands in with no lamp lit")
	assert_false(roof.is_processing())


func test_flicker_set_while_off_survives_switching_on() -> void:
	var roof := _roof(_depot())
	var lamps := roof.lamp_lights()
	var lamp := Array(_depot().roof_lamp_states).find(MapData.LAMP_FLICKER)
	lamps.set_mode(GraphicsQuality.LampLights.OFF, false)
	lamps.set_flicker(lamp, cfg.lamp_flicker_low)
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false)
	assert_almost_eq(lamps.light_of(lamp).light_energy, cfg.lamp_light_energy * cfg.lamp_flicker_low, 0.001)
	var dim := lamps.light_of(Array(_depot().roof_lamp_states).find(MapData.LAMP_DIM))
	assert_almost_eq(dim.light_energy, cfg.lamp_light_energy * cfg.lamp_dim_share, 0.001, "set_mode keeps dim")


func test_flicker_level_is_valid_for_odd_times_and_lamps() -> void:
	for lamp: int in [0, 1, 16, 999999]:
		for t: float in [0.0, 0.001, 123456.7, 1.0e7]:
			var level := RoofView.flicker_level(t, lamp, cfg)
			assert_true(level >= 0.0 and level <= 1.0)


func test_freeing_the_roof_leaves_no_orphans() -> void:
	await wait_physics_frames(2)  # the earlier tests' freed nodes go first, so they are not counted as this one's
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var roof := RoofView.build(_depot(), cfg)
	add_child(roof)
	await wait_physics_frames(3)
	remove_child(roof)
	roof.free()
	await wait_physics_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)
