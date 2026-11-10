extends GutTest
## RF1 QA: the Retro filter's edges (clamping, resize, no lighting, haze coming off, toggled in one frame, a session
## freed while it is up, older saves, the Dev tab's sliders).


func _night() -> LightingConfig:
	var cfg := LightingConfig.new()
	cfg.fog = true
	cfg.fog_colour = Color(0.2, 0.4, 0.8)
	cfg.fog_from = 5.0
	cfg.fog_to = 33.0
	return cfg


func test_set_look_holds_lines_and_levels_to_their_ends_before_the_tree() -> void:
	var f := RetroFilter.new()
	f.set_look(-5, 0)
	f.set_look(100000, 100000)
	add_child_autofree(f)
	var mat := (f.get_child(0) as ColorRect).material as ShaderMaterial
	assert_eq(float(mat.get_shader_parameter(&"levels")), float(RetroFilter.LEVELS_MAX))
	f.set_look(-5, -5)
	assert_eq(float(mat.get_shader_parameter(&"levels")), float(RetroFilter.LEVELS_MIN))
	var h := f.get_viewport().get_visible_rect().size.y
	assert_eq(float(mat.get_shader_parameter(&"pixel_size")), float(RetroFilter.pixel_size(h, RetroFilter.LINES_MIN)))


func test_pixel_size_never_below_one_and_survives_zero_lines() -> void:
	assert_eq(RetroFilter.pixel_size(0.0, 240), 1)
	assert_eq(RetroFilter.pixel_size(1080.0, 0), 1080)
	assert_eq(RetroFilter.pixel_size(1080.0, -3), 1080)
	assert_eq(RetroFilter.pixel_size(100.0, 480), 1)


func test_resize_updates_pixel_size_and_snap_screen() -> void:
	var f := RetroFilter.new()
	add_child_autofree(f)
	var win := get_viewport() as Window
	var before := win.size
	var h := f.get_viewport().get_visible_rect().size
	var px := RetroFilter.pixel_size(h.y, RetroFilter.LINES)
	assert_almost_eq(f.snap().x, h.x / float(px), 0.001)
	assert_almost_eq(f.snap().y, h.y / float(px), 0.001)
	win.size = Vector2i(maxi(before.x, 64) + 64, maxi(before.y, 64) + 128)
	await wait_process_frames(2)
	var h2 := f.get_viewport().get_visible_rect().size
	var px2 := RetroFilter.pixel_size(h2.y, RetroFilter.LINES)
	assert_almost_eq(f.snap().y, h2.y / float(px2), 0.001, "follows the new size")
	win.size = before


func test_without_lighting_it_builds_and_frees_quietly() -> void:
	var f := RetroFilter.new()
	f.setup(null)
	add_child(f)
	await wait_process_frames(1)
	assert_gt(f.snap().x, 0.0)
	remove_child(f)
	assert_eq(f.snap(), Vector4.ZERO)
	f.free()


func test_leaving_the_tree_zeroes_the_snap_and_disconnects_resize() -> void:
	var f := RetroFilter.new()
	add_child(f)
	var vp := f.get_viewport()
	assert_true(vp.size_changed.is_connected(f._resize))
	remove_child(f)
	assert_false(vp.size_changed.is_connected(f._resize), "no stray connection")
	assert_eq(f.snap(), Vector4.ZERO)
	f.free()


func test_haze_comes_off_back_to_the_night_maps_own_fog() -> void:
	var cfg := _night()
	var light := FieldLighting.build(cfg)
	add_child_autofree(light)
	var env := light.environment
	var f := RetroFilter.new()
	f.setup(light)
	add_child(f)
	assert_eq(env.fog_depth_end, RetroFilter.HAZE_TO)
	assert_almost_eq(env.fog_density, RetroFilter.HAZE_MOST, 0.001)
	remove_child(f)
	f.free()
	assert_true(env.fog_enabled)
	assert_eq(env.fog_density, 1.0)
	assert_eq(env.fog_depth_begin, 5.0)
	assert_eq(env.fog_depth_end, 33.0)
	assert_eq(env.fog_light_color, cfg.fog_colour)


func test_haze_off_on_a_foggless_day_map_is_off_again() -> void:
	var cfg := LightingConfig.new()
	cfg.fog = false
	var light := FieldLighting.build(cfg)
	add_child_autofree(light)
	light.retro_haze(true, 12.0, 70.0, 0.85, 0.55)
	assert_true(light.environment.fog_enabled)
	light.retro_haze(false)
	assert_false(light.environment.fog_enabled)


func test_off_and_on_in_one_frame_leaves_one_filter_and_a_live_snap() -> void:
	var light := FieldLighting.build(_night())
	add_child_autofree(light)
	var a := RetroFilter.new()
	a.setup(light)
	add_child(a)
	remove_child(a)
	a.queue_free()
	var b := RetroFilter.new()
	b.setup(light)
	add_child(b)
	await wait_process_frames(2)
	assert_gt(b.snap().x, 0.0)
	assert_eq(light.environment.fog_depth_end, RetroFilter.HAZE_TO, "the new one's haze stands")
	remove_child(b)
	b.free()
	assert_eq(light.environment.fog_depth_end, 33.0)


func test_lighting_freed_before_the_filter_does_not_error() -> void:
	var light := FieldLighting.build(_night())
	add_child(light)
	var f := RetroFilter.new()
	f.setup(light)
	add_child(f)
	light.free()
	remove_child(f)
	f.free()
	assert_true(true, "no script error")


func test_session_freed_while_filter_up_clears_the_snap() -> void:
	var s := Settings.new(PlayTuning.new())
	s.dev.retro_filter = true
	var session := PlaySession.new()
	session.settings = s
	session.map_id = "depot"
	session.autopilot = true
	add_child(session)
	await wait_physics_frames(2)
	var filter := session._retro
	assert_not_null(filter)
	assert_gt(filter.snap().x, 0.0)
	session.free()
	assert_true(true, "freed with the filter up, no script error")


func test_toggling_the_session_filter_repeatedly_leaves_one_or_none() -> void:
	var s := Settings.new(PlayTuning.new())
	var session := PlaySession.new()
	session.settings = s
	session.map_id = "depot"
	session.autopilot = true
	add_child_autofree(session)
	await wait_physics_frames(2)
	for i in 4:
		s.dev.retro_filter = true
		s.mark_changed()
		s.dev.retro_filter = false
		s.mark_changed()
		s.dev.retro_filter = true
		s.mark_changed()
		assert_eq(session.find_children("*", "RetroFilter", true, false).size(), 1)
		s.dev.retro_filter = false
		s.mark_changed()
		assert_eq(session.find_children("*", "RetroFilter", true, false).size(), 0)
	await wait_process_frames(2)
	# Depot by day: the site sky's haze (SiteDress.dress_sky), exactly as before the filter (critic, RF1 attempt 1).
	var env := session._lighting.environment
	assert_true(env.fog_enabled, "the site sky's haze back")
	assert_eq(env.fog_depth_begin, session._play.site_look.haze_from)
	assert_eq(env.fog_light_color, session._play.site_look.haze_colour)


func test_old_save_with_retro_pixels_switch_turns_the_filter_on_with_new_defaults() -> void:
	var d := DevSettings.new()
	d.from_dict({"retro_pixels": true, "retro_pixel_size": 8, "retro_shades": 6})
	assert_true(d.retro_filter)
	assert_eq(d.retro_lines, RetroFilter.LINES)
	assert_eq(d.retro_levels, RetroFilter.LEVELS)


func test_new_switch_off_wins_over_nothing_and_roundtrips() -> void:
	var d := DevSettings.new()
	d.retro_filter = true
	d.retro_lines = 360
	d.retro_levels = 8
	var e := DevSettings.new()
	e.from_dict(d.to_dict())
	assert_true(e.retro_filter)
	assert_eq(e.retro_lines, 360)
	assert_eq(e.retro_levels, 8)


func test_corrupt_values_fall_back_to_defaults() -> void:
	var d := DevSettings.new()
	d.from_dict({"retro_filter": "yes", "retro_lines": "lots", "retro_levels": 9999})
	assert_false(d.retro_filter)
	assert_eq(d.retro_lines, RetroFilter.LINES)
	assert_eq(d.retro_levels, RetroFilter.LEVELS)
	d.from_dict({"retro_lines": 0, "retro_levels": -1})
	assert_eq(d.retro_lines, RetroFilter.LINES)
	assert_eq(d.retro_levels, RetroFilter.LEVELS)
	d.from_dict({})
	assert_false(d.retro_filter)


func test_lines_step_lands_on_the_slider_ends() -> void:
	assert_eq((RetroFilter.LINES_MAX - RetroFilter.LINES_MIN) % RetroFilter.LINES_STEP, 0)
	assert_eq((RetroFilter.LINES - RetroFilter.LINES_MIN) % RetroFilter.LINES_STEP, 0, "default on a step")


func test_haze_changed_after_build_is_what_comes_back() -> void:
	var light := FieldLighting.build(LightingConfig.new())
	add_child_autofree(light)
	var env := light.environment
	# a site-dressed map sets its sky haze after the build
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.3, 0.5, 0.7)
	env.fog_density = 0.013
	env.fog_sky_affect = 0.4
	light.retro_haze(true, 12.0, 70.0, 0.85, 0.55)
	light.retro_haze(true, 12.0, 70.0, 0.85, 0.55)
	light.retro_haze(false)
	assert_true(env.fog_enabled)
	assert_eq(env.fog_mode, Environment.FOG_MODE_EXPONENTIAL)
	assert_almost_eq(env.fog_density, 0.013, 0.0001)
	assert_almost_eq(env.fog_sky_affect, 0.4, 0.0001)
	assert_eq(env.fog_light_color, Color(0.3, 0.5, 0.7), "a second on did not hold the retro haze as the map's own")
	light.retro_haze(false)
	assert_almost_eq(env.fog_density, 0.013, 0.0001, "off twice is harmless")


func test_haze_off_without_on_changes_nothing() -> void:
	var light := FieldLighting.build(_night())
	add_child_autofree(light)
	light.retro_haze(false)
	assert_eq(light.environment.fog_depth_end, 33.0)


func test_process_without_a_camera_is_safe() -> void:
	var f := RetroFilter.new()
	add_child_autofree(f)
	await wait_process_frames(2)
	f._process(0.016)
	assert_true(true, "no script error")


func test_a_filter_outside_the_tree_does_not_process() -> void:
	var f := RetroFilter.new()
	assert_false(f.is_processing() and f.is_inside_tree())
	f.free()
