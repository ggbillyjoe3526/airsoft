extends GutTest
## WL3 QA: the light pools hand a pool back whole, the night systems follow the one flag across matches and a
## changed preset, and a stale bake still warns at night.

var play: PlayTuning = PlayTuning.load_default()
var woodland: MapData = null


func before_all() -> void:
	woodland = MapData.load_map("woodland", play.map_style, 5)


func _pools() -> LightPools:
	var pools := LightPools.build(woodland, play.night_lighting)
	add_child_autofree(pools)
	return pools


func test_a_pool_a_real_light_hands_back_is_drawn_whole_again() -> void:
	var pools := _pools()
	pools.set_real_count(1)
	var camp := Vector3(-50.0, 2.0, -10.0)
	for i in 40:
		pools.update(camp, 1.0 / 60.0)
	var first := pools.served()[0]
	assert_gte(first, 0, "a light serves the nearest pool")
	assert_eq(pools.drawn_share(first), 0.0, "under a real light, its disc is gone")
	# walk to the far side of the field: the light moves on, fading out first
	var far := Vector3(60.0, 2.0, 10.0)
	for i in 120:
		pools.update(far, 1.0 / 60.0)
	assert_ne(pools.served()[0], first, "the light moved to another pool")
	assert_eq(pools.drawn_share(first), 1.0, "the pool it left is drawn whole again")


func test_a_long_frame_does_not_leave_a_pool_dark() -> void:
	var pools := _pools()
	pools.set_real_count(1)
	var camp := Vector3(-50.0, 2.0, -10.0)
	for i in 40:
		pools.update(camp, 1.0 / 60.0)
	var first := pools.served()[0]
	var far := Vector3(60.0, 2.0, 10.0)
	pools.update(far, 0.5)
	for i in 120:
		pools.update(far, 1.0 / 60.0)
	assert_eq(pools.drawn_share(first), 1.0, "a hitch of half a second still hands the pool back")


func _session(map_id: String, settings: Settings, pick: StringName = &"") -> PlaySession:
	var session := PlaySession.new()
	session.map_id = map_id
	session.settings = settings
	session.lighting_pick = pick
	session.bots_active = false
	add_child_autofree(session)
	return session


## The night's real lights under `node`: the bombs' flash light (SF1), hidden until a bang, is not one.
func _lights_in(node: Node) -> int:
	var n := 0
	for light in node.find_children("*", "OmniLight3D", true, false):
		if not light.get_parent() is GrenadeView:
			n += 1
	return n


func test_a_stale_bake_still_warns_at_night() -> void:
	var m := MapData.load_map("depot", play.map_style, 1)
	var cfg := play.baked_light.duplicate() as BakeConfig
	cfg.cell = 0.25
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, BodyConfig.new(), cfg, play.lighting, true)
	level.set_baked_light(true)
	assert_false(level.baked_light_drawn(), "a bake of other settings is not drawn at night either")
	assert_push_warning("baked from other blocks or settings")


func test_changing_the_graphics_mid_match_changes_the_real_lights_and_frees_them() -> void:
	var s := Settings.new()
	var session := _session("woodland", s, LightingConfig.NIGHT)
	var pools := session.light_pools()
	assert_not_null(pools, "Woodland at night has its pools")
	for preset: StringName in [&"low", &"medium", &"high", &"ultra", &"low", &"high"]:
		var quality := GraphicsTable.shared().preset(preset)
		session._apply_graphics(quality)
		# No weapon light in this kit: the pools keep every real light (WL7; test_torch.gd has one fitted).
		assert_null(session._eyes.torch(), "no torch's spot: %s" % preset)
		assert_eq(pools.real_lights().size(), session.lighting().real_lights_for(quality.mesh_detail), String(preset))
	for i in 30:
		pools.update(Vector3(-50.0, 2.0, -10.0), 0.05)
	session._apply_graphics(GraphicsTable.shared().preset(&"low"))
	await get_tree().process_frame
	assert_eq(_lights_in(session), 0, "Low: no real light left, queued ones freed")
	for k in woodland.lights.size():
		assert_eq(pools.drawn_share(k), 1.0, "pool %d drawn on Low" % k)


func test_leaving_a_night_match_frees_its_pools_and_the_next_match_is_lit_by_its_own_map() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var s := Settings.new()
	var night := _session("woodland", s, LightingConfig.NIGHT)
	night._apply_graphics(GraphicsTable.shared().preset(&"high"))
	assert_gt(_lights_in(night), 0)
	night.free()
	var day := _session("depot", s)
	assert_false(day.lighting().night, "Depot is day again")
	assert_null(day.light_pools())
	assert_false(day.lighting().fog)
	assert_false(day._audio.night)
	assert_eq(_lights_in(day.get_parent()) - _lights_in(day), 0, "no night light outside this session")
	assert_gt(day.lighting().sun_energy, 0.5, "the day sun, not the moon's strength")
	day.free()
	await get_tree().process_frame
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "nothing left over")


func test_dev_time_of_day_is_dropped_from_a_save_with_the_old_box_unticked_and_old_saves_load_without_it() -> void:
	var s := Settings.new()
	s.from_dict({"dev_enabled": false, "dev": {"time_of_day": String(LightingConfig.NIGHT)}})
	var session := _session("depot", s)
	assert_false(session.lighting().night, "the old box was off: the map's own")
	var d := DevSettings.new()
	d.from_dict({"bottomless": true})
	assert_eq(d.time_of_day, &"")
	var again := Settings.new()
	again.dev.time_of_day = LightingConfig.DAY
	var back := Settings.new()
	back.from_dict(again.to_dict())
	assert_eq(back.dev.time_of_day, LightingConfig.DAY, "saved through the settings file")


func test_a_practice_range_by_dev_night_plays_without_pools_and_stays_off_the_record() -> void:
	var s := Settings.new()
	s.dev.time_of_day = LightingConfig.NIGHT
	var session := PlaySession.new()
	session.map_id = "range"
	session.practice = true
	session.settings = s
	add_child_autofree(session)
	assert_true(session.lighting().night)
	assert_null(session.light_pools())
	assert_true(session.state.off_record, "a forced preset keeps it off the record")


func test_a_map_offering_one_preset_ignores_the_match_pick() -> void:
	var s := Settings.new()
	var day := _session("depot", s, LightingConfig.NIGHT)
	assert_false(day.lighting().night, "Depot offers day alone")
	var wood := TowerBlock.load_map(play.map_style, 4)
	wood.lighting_presets = [LightingConfig.NIGHT] as Array[StringName]
	assert_eq(wood.preset_played(LightingConfig.DAY), LightingConfig.NIGHT, "a field offering night alone")
	var both := _session("woodland", s, LightingConfig.NIGHT)
	assert_true(both.lighting().night, "Woodland offers both: the Match page's Night (WR1)")


func test_dev_time_of_day_row_picks_saves_and_shows_the_saved_choice() -> void:
	var path := "user://test_night_light_qa/settings.save"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var s := Settings.new(PlayTuning.new())
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = path
	add_child_autofree(screen)
	screen.open()
	var row := screen.time_of_day_choice()
	assert_eq(row.selected(), 0, "the map's own by default")
	row.button(2).pressed.emit()
	assert_eq(s.dev.time_of_day, LightingConfig.NIGHT)
	assert_true(s.dev.cheats().watching, "Night counts as watching")
	var back := Settings.new(PlayTuning.new())
	back.load_file(path)
	assert_eq(back.dev.time_of_day, LightingConfig.NIGHT, "saved at once")
	var again := SettingsScreen.new()
	again.settings = back
	again.save_path = path
	add_child_autofree(again)
	again.open()
	assert_eq(again.time_of_day_choice().selected(), 2, "a new screen shows Night")
	again.time_of_day_choice().button(0).pressed.emit()
	assert_eq(back.dev.time_of_day, &"", "back to the map's own")
	DirAccess.remove_absolute(path)


func test_pools_stay_whole_after_many_handovers_and_long_frames() -> void:
	var pools := _pools()
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	for count: int in [1, 2, 4]:
		pools.set_real_count(count)
		for step in 600:
			var eye := Vector3(rng.randf_range(-70.0, 70.0), 2.0, rng.randf_range(-30.0, 30.0))
			var dt := rng.randf_range(0.0, 1.0) if step % 7 == 0 else 1.0 / 60.0
			pools.update(eye, dt)
			for k in woodland.lights.size():
				var share := pools.drawn_share(k)
				assert_between(share, 0.0, 1.0, "pool %d stays in range" % k)
		# settle: every unserved pool is whole, a served one is under its light
		for i in 120:
			pools.update(Vector3(-50.0, 2.0, -10.0), 1.0 / 60.0)
		var served := pools.served()
		for k in woodland.lights.size():
			if served.has(k):
				assert_eq(pools.drawn_share(k), 0.0, "%d real: pool %d served" % [count, k])
			else:
				assert_eq(pools.drawn_share(k), 1.0, "%d real: pool %d whole" % [count, k])
