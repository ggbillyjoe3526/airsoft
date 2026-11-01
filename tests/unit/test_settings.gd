extends GutTest
## The settings (game/save/settings.gd and settings_apply.gd): saved through SaveFile and read back, a missing file
## silent, a damaged one falling back to the defaults with a message, each bad value keeping its own default, and the
## values applied to the mouse, the camera, the audio buses and the window.

const ROOT := "user://test-settings"

var dir := ""
var path := ""
var _n := 0
var tuning: PlayTuning = null
var s: Settings = null


func before_each() -> void:
	_n += 1
	dir = "%s/%d" % [ROOT, _n]
	_wipe(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	path = dir.path_join("settings.save")
	tuning = PlayTuning.new()
	s = Settings.new(tuning)


func after_each() -> void:
	InputMap.load_from_project_settings()
	SettingsApply.apply_audio(Settings.new(tuning))


func after_all() -> void:
	_wipe(ROOT)


func _wipe(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p):
		return
	for d: String in DirAccess.get_directories_at(p):
		_wipe(p.path_join(d))
	for f: String in DirAccess.get_files_at(p):
		DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)


func _again() -> Settings:
	var t := Settings.new(PlayTuning.new())
	t.load_file(path)
	return t


func test_the_defaults_are_the_owners() -> void:
	assert_false(s.crouch_toggle, "crouch is held (owner, 2026-10-18)")
	assert_false(s.aim_toggle, "aim is held (owner, 2026-10-18)")
	assert_eq(s.volumes[&"Master"], 1.0)
	assert_eq(s.volumes[&"Effects"], 0.7)
	assert_eq(s.volumes[&"Power"], 1.0)
	assert_eq(s.volumes[&"Ambience"], 0.2, "ambience 20 % (owner, 2026-11-01; AU1)")
	assert_eq(s.volumes[&"Interface"], 0.4)
	assert_eq(s.fov, tuning.view.horizontal_fov_16x9, "the field of view starts where the camera config does")
	assert_eq(s.sensitivity, tuning.controls.sensitivity)
	assert_eq(s.aim_sensitivity, tuning.controls.aim_sensitivity)


func test_settings_round_trip_through_the_save_file() -> void:
	s.sensitivity = 1.7
	s.aim_sensitivity = 0.6
	s.invert_y = true
	s.crouch_toggle = true
	s.aim_toggle = true
	s.mouse_dpi = 1600
	s.volumes[&"Effects"] = 0.25
	s.volumes[&"Interface"] = 0.0
	s.window_mode = Settings.WindowMode.BORDERLESS
	s.vsync = false
	s.fov = 100.0
	s.show_fps = true
	s.bindings.rebind(&"reload", KEY_X)
	assert_true(s.save(path))
	var t := _again()
	assert_eq(t.load_message, "", "a good file says nothing")
	assert_almost_eq(t.sensitivity, 1.7, 1e-6)
	assert_almost_eq(t.aim_sensitivity, 0.6, 1e-6)
	assert_true(t.invert_y)
	assert_true(t.crouch_toggle)
	assert_true(t.aim_toggle)
	assert_eq(t.mouse_dpi, 1600)
	assert_almost_eq(t.volumes[&"Effects"], 0.25, 1e-6)
	assert_eq(t.volumes[&"Interface"], 0.0)
	assert_eq(t.volumes[&"Master"], 1.0)
	assert_eq(t.window_mode, Settings.WindowMode.BORDERLESS)
	assert_false(t.vsync)
	assert_almost_eq(t.fov, 100.0, 1e-6)
	assert_true(t.show_fps)
	assert_eq(Array(t.bindings.codes(&"reload")), [KEY_X])


func test_the_file_is_a_versioned_settings_save() -> void:
	s.save(path)
	var r := SaveFile.read(path, "settings")
	assert_true(r.ok)
	assert_eq(r.version, Settings.VERSION)
	assert_eq(SaveFile.read(path, "other").ok, false, "its kind is settings")


func test_the_first_start_is_exclusive_fullscreen_with_v_sync_off() -> void:
	assert_eq(s.window_mode, Settings.WindowMode.EXCLUSIVE, "owner, 2026-10-29")
	assert_false(s.vsync, "owner, 2026-10-29")
	s.load_file(path)
	assert_eq(s.window_mode, Settings.WindowMode.EXCLUSIVE, "no file: the same")
	assert_false(s.vsync)


func test_a_version_1_file_still_at_the_old_defaults_moves_to_the_new_ones() -> void:
	SaveFile.write(path, Settings.KIND, 1, {
		"window_mode": Settings.WindowMode.WINDOWED, "vsync": true,
		"volumes": {"Master": 1.0, "Effects": 0.8, "Power": 1.0, "Ambience": 0.6, "Interface": 0.5},
	})
	var t := _again()
	assert_eq(t.load_message, "")
	assert_eq(t.window_mode, Settings.WindowMode.EXCLUSIVE)
	assert_false(t.vsync)
	assert_eq(t.volumes[&"Effects"], 0.7)
	assert_eq(t.volumes[&"Ambience"], 0.2)
	assert_eq(t.volumes[&"Interface"], 0.4)
	assert_eq(t.volumes[&"Master"], 1.0)
	assert_eq(t.volumes[&"Power"], 1.0)
	assert_true(t.save(path), "saved again, now as version 2")
	assert_eq(SaveFile.read(path, Settings.KIND).version, Settings.VERSION)


func test_a_version_1_file_keeps_what_the_player_changed() -> void:
	SaveFile.write(path, Settings.KIND, 1, {
		"window_mode": Settings.WindowMode.BORDERLESS, "vsync": false,
		"volumes": {"Master": 0.9, "Effects": 0.8, "Power": 0.5, "Ambience": 0.6, "Interface": 0.2},
	})
	var t := _again()
	assert_eq(t.window_mode, Settings.WindowMode.BORDERLESS, "chosen, so kept")
	assert_false(t.vsync)
	assert_eq(t.volumes[&"Master"], 0.9)
	assert_eq(t.volumes[&"Power"], 0.5)
	assert_eq(t.volumes[&"Interface"], 0.2)
	assert_eq(t.volumes[&"Effects"], 0.7, "left at the old default: moved")
	SaveFile.write(path, Settings.KIND, 1, {"vsync": true, "volumes": {"Effects": 0.75}})
	t = _again()
	assert_false(t.vsync)
	assert_eq(t.volumes[&"Effects"], 0.75, "a value near the old default is still the player's")


func test_a_version_1_windowed_file_remembers_the_new_fullscreen_for_f11() -> void:
	SaveFile.write(path, Settings.KIND, 1, {"window_mode": 0, "last_fullscreen": 1})
	assert_eq(_again().last_fullscreen, Settings.WindowMode.EXCLUSIVE, "never left the old default")
	SaveFile.write(path, Settings.KIND, 1, {"window_mode": 1, "last_fullscreen": 1})
	var t := _again()
	assert_eq(t.window_mode, Settings.WindowMode.BORDERLESS)
	assert_eq(t.last_fullscreen, Settings.WindowMode.BORDERLESS, "a player in Borderless keeps it")
	SaveFile.write(path, Settings.KIND, 2, {"window_mode": 0, "last_fullscreen": 1})
	assert_eq(_again().last_fullscreen, Settings.WindowMode.BORDERLESS, "version 2: as saved")


func test_a_version_2_file_is_not_moved_again() -> void:
	SaveFile.write(path, Settings.KIND, 2, {
		"window_mode": Settings.WindowMode.WINDOWED, "vsync": true,
		"volumes": {"Master": 1.0, "Effects": 0.8, "Power": 1.0, "Ambience": 0.6, "Interface": 0.5},
	})
	var t := _again()
	assert_eq(t.window_mode, Settings.WindowMode.WINDOWED, "chosen after the move")
	assert_true(t.vsync)
	assert_eq(t.volumes[&"Effects"], 0.8)
	assert_eq(t.volumes[&"Ambience"], 0.6)


func test_a_fresh_start_shows_edge_smoothing_off_and_a_player_who_turns_it_on_keeps_it() -> void:
	for picked: StringName in GraphicsTable.PRESETS:
		assert_eq(s.graphics_in_force(picked).edge_smoothing, GraphicsQuality.EdgeSmoothing.OFF, String(picked))
	assert_true(s.change_graphics_row(GraphicsQuality.EDGE_SMOOTHING, "msaa_4x", &"medium"))
	s.save(path)
	var t := _again()
	assert_eq(t.graphics_in_force(&"medium").edge_smoothing, GraphicsQuality.EdgeSmoothing.MSAA_4X, "kept")


func test_reset_gives_the_new_defaults() -> void:
	s.window_mode = Settings.WindowMode.WINDOWED
	s.vsync = true
	s.volumes[&"Effects"] = 0.2
	s.reset_save(path)
	assert_eq(s.window_mode, Settings.WindowMode.EXCLUSIVE)
	assert_false(s.vsync)
	assert_eq(s.volumes[&"Effects"], 0.7)
	assert_eq(s.volumes[&"Power"], 1.0)
	assert_eq(s.volumes[&"Ambience"], 0.2)
	assert_eq(s.volumes[&"Interface"], 0.4)


func test_a_missing_file_is_silent_defaults() -> void:
	s.load_file(path)
	assert_eq(s.load_message, "")
	assert_eq(s.volumes[&"Effects"], 0.7)


func test_a_damaged_file_falls_back_with_a_message() -> void:
	s.sensitivity = 2.0
	s.save(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("ASAVE settings 1 deadbeef\n{\"sensitivity\": 3}")
	f.close()
	DirAccess.remove_absolute(path + SaveFile.BAK)
	DirAccess.remove_absolute(path + SaveFile.TMP)
	var t := _again()
	assert_ne(t.load_message, "")
	assert_ne(t.load_message, "SETTINGS_DAMAGED", "the message is translated")
	assert_eq(t.sensitivity, 1.0, "the defaults are in use")
	var kept := false
	for file: String in DirAccess.get_files_at(dir):
		kept = kept or file.contains("corrupt")
	assert_true(kept, "the damaged file is moved aside, not destroyed")


func test_a_file_that_is_not_a_save_falls_back_with_a_message() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("this is not a save file")
	f.close()
	assert_ne(_again().load_message, "")


func test_a_version_this_build_does_not_know_falls_back_with_a_message() -> void:
	assert_true(SaveFile.write(path, Settings.KIND, Settings.VERSION + 1, {"sensitivity": 3.0}))
	var t := _again()
	assert_ne(t.load_message, "")
	assert_eq(t.sensitivity, 1.0)


func test_each_bad_value_keeps_its_own_default() -> void:
	SaveFile.write(path, Settings.KIND, Settings.VERSION, {
		"sensitivity": 99.0, "aim_sensitivity": "fast", "invert_y": "yes", "crouch_toggle": true,
		"mouse_dpi": -5, "fov": 400.0, "window_mode": 7, "vsync": 1, "show_fps": true,
		"volumes": {"Master": 0.5, "Effects": 3.0, "Power": -1.0, "Ambience": null, "Interface": 0.0},
		"bindings": "nonsense",
	})
	var t := _again()
	assert_eq(t.load_message, "", "a good file with bad values is not a damaged file")
	assert_eq(t.sensitivity, 1.0, "out of range")
	assert_eq(t.aim_sensitivity, 1.0, "wrong type")
	assert_false(t.invert_y)
	assert_true(t.crouch_toggle, "a good value beside them is kept")
	assert_eq(t.mouse_dpi, Sensitivity.DPI_DEFAULT)
	assert_eq(t.fov, Settings.FOV_DEFAULT)
	assert_eq(t.window_mode, Settings.WindowMode.EXCLUSIVE, "a mode that is not one is the default")
	assert_false(t.vsync, "a number is not a flag: the default")
	assert_true(t.show_fps)
	assert_eq(t.volumes[&"Master"], 0.5)
	assert_eq(t.volumes[&"Effects"], 0.7)
	assert_eq(t.volumes[&"Power"], 1.0)
	assert_eq(t.volumes[&"Ambience"], 0.2)
	assert_eq(t.volumes[&"Interface"], 0.0)
	assert_eq(Array(t.bindings.codes(&"reload")), [KEY_R])


func test_save_if_dirty_writes_only_after_a_change() -> void:
	s.save_if_dirty(path)
	assert_false(FileAccess.file_exists(path), "nothing changed")
	s.mark_changed()
	s.save_if_dirty(path)
	assert_true(FileAccess.file_exists(path))
	assert_false(s.dirty)


func test_changed_is_sent_when_a_setting_changes() -> void:
	watch_signals(s)
	s.mark_changed()
	assert_signal_emitted(s, "changed")


func test_applying_controls_sets_the_mouse_and_the_camera() -> void:
	s.sensitivity = 2.2
	s.aim_sensitivity = 0.5
	s.invert_y = true
	s.crouch_toggle = true
	s.aim_toggle = true
	s.fov = 75.0
	SettingsApply.apply_controls(s)
	assert_eq(tuning.controls.sensitivity, 2.2)
	assert_eq(tuning.controls.aim_sensitivity, 0.5)
	assert_true(tuning.controls.invert_y)
	assert_true(tuning.controls.crouch_toggle)
	assert_true(tuning.controls.aim_toggle)
	assert_eq(tuning.view.horizontal_fov_16x9, 75.0)


func test_applying_volumes_sets_each_buss_db() -> void:
	s.volumes[&"Master"] = 0.5
	s.volumes[&"Effects"] = 0.25
	s.volumes[&"Power"] = 1.0
	s.volumes[&"Ambience"] = 0.0
	SettingsApply.apply_audio(s)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master")), linear_to_db(0.5), 1e-3)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Effects")), linear_to_db(0.25), 1e-3)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Power")), 0.0, 1e-3)
	var ambience := AudioServer.get_bus_index(&"Ambience")
	assert_true(AudioServer.is_bus_mute(ambience), "0 % is silence")
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Effects")))
	s.volumes[&"Ambience"] = 0.6
	SettingsApply.apply_audio(s)
	assert_false(AudioServer.is_bus_mute(ambience), "and coming back un-mutes")
	assert_almost_eq(AudioServer.get_bus_volume_db(ambience), linear_to_db(0.6), 1e-3)


func test_every_volume_has_a_bus_and_the_power_bus_feeds_effects() -> void:
	for bus: StringName in Settings.VOLUME_BUSES:
		assert_gte(AudioServer.get_bus_index(bus), 0, "bus %s" % bus)
	var power := AudioServer.get_bus_index(SimAudio.BUS_POWER)
	assert_eq(AudioServer.get_bus_send(power), SimAudio.BUS_EFFECTS)
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(SimAudio.BUS_FOOTSTEPS)), SimAudio.BUS_EFFECTS)


func test_applying_bindings_writes_the_input_map() -> void:
	s.bindings.rebind(&"jump", KEY_G)
	SettingsApply.apply_bindings(s)
	assert_eq((InputMap.action_get_events(&"jump")[0] as InputEventKey).physical_keycode, KEY_G as Key)


func test_the_shared_settings_use_the_play_tuning_a_match_loads() -> void:
	assert_eq(Settings.shared().tuning, PlayTuning.load_default())
	assert_same(Settings.shared(), Settings.shared())


func test_realistic_colours_is_off_by_default_and_kept() -> void:
	var s := Settings.new()
	assert_false(s.realistic_colours)
	s.realistic_colours = true
	var t := Settings.new()
	t.from_dict(s.to_dict())
	assert_true(t.realistic_colours)
	t.from_dict({"realistic_colours": "yes"})
	assert_false(t.realistic_colours, "a value that won't read keeps the default")


func test_the_graphics_and_window_fields_start_at_their_defaults() -> void:
	assert_eq(s.graphics_choice, Settings.GRAPHICS_AUTOMATIC, "the first start picks from the card")
	assert_eq(s.graphics_base, GraphicsTable.DEFAULT_PRESET)
	assert_eq(s.graphics_custom, {} as Dictionary[String, Variant])
	assert_eq(s.frame_limit, Settings.UNLIMITED)
	assert_eq(s.monitor, Settings.MONITOR_HERE)
	assert_eq(s.last_fullscreen, Settings.WINDOW_MODE_DEFAULT, "F11 goes back to the first start's mode")
	assert_eq(s.renderer, Settings.Renderer.AUTO)
	assert_false(s.first_start_seen)


func test_the_new_fields_round_trip_through_the_save_file() -> void:
	s.graphics_choice = GraphicsQuality.CUSTOM
	s.graphics_base = &"low"
	s.graphics_custom = {"wind_dust": 40, "edge_smoothing": "smaa"}
	s.frame_limit = 144
	s.monitor = 1
	s.last_fullscreen = Settings.WindowMode.EXCLUSIVE
	s.renderer = Settings.Renderer.COMPATIBILITY
	s.first_start_seen = true
	assert_true(s.save(path))
	var t := _again()
	assert_eq(t.load_message, "")
	assert_eq(t.graphics_choice, GraphicsQuality.CUSTOM)
	assert_eq(t.graphics_base, &"low")
	assert_eq(t.graphics_custom, {"wind_dust": 40, "edge_smoothing": "smaa"} as Dictionary[String, Variant])
	assert_eq(t.frame_limit, 144)
	assert_eq(t.monitor, 1)
	assert_eq(t.last_fullscreen, Settings.WindowMode.EXCLUSIVE)
	assert_eq(t.renderer, Settings.Renderer.COMPATIBILITY)
	assert_true(t.first_start_seen)


func test_the_automatic_pick_is_never_written() -> void:
	assert_false(s.to_dict().has("graphics_choice"), "automatic: no choice in the file")
	s.save(path)
	assert_eq(_again().graphics_choice, Settings.GRAPHICS_AUTOMATIC)
	s.graphics_choice = &"medium"
	assert_eq(s.to_dict().get("graphics_choice"), "medium", "a chosen preset is written")


func test_a_file_from_before_the_graphics_fields_loads_unchanged() -> void:
	SaveFile.write(path, Settings.KIND, Settings.VERSION, {
		"sensitivity": 1.5, "window_mode": Settings.WindowMode.BORDERLESS, "vsync": false, "fov": 95.0,
		"show_fps": true, "volumes": {"Master": 0.7},
	})
	var t := _again()
	assert_eq(Settings.VERSION, 3, "3 since AU1 moved the ambience's default; adding fields does not bump it")
	assert_eq(t.load_message, "", "an older file is not a damaged one")
	assert_almost_eq(t.sensitivity, 1.5, 1e-6)
	assert_eq(t.window_mode, Settings.WindowMode.BORDERLESS)
	assert_false(t.vsync)
	assert_almost_eq(t.fov, 95.0, 1e-6)
	assert_true(t.show_fps)
	assert_almost_eq(t.volumes[&"Master"], 0.7, 1e-6)
	assert_eq(t.graphics_choice, Settings.GRAPHICS_AUTOMATIC)
	assert_eq(t.frame_limit, Settings.UNLIMITED)
	assert_eq(t.monitor, Settings.MONITOR_HERE)
	assert_eq(t.last_fullscreen, Settings.WINDOW_MODE_DEFAULT)
	assert_eq(t.renderer, Settings.Renderer.AUTO)
	assert_false(t.first_start_seen)


func test_each_bad_graphics_or_window_value_keeps_its_own_default() -> void:
	SaveFile.write(path, Settings.KIND, Settings.VERSION, {
		"graphics_choice": "extreme", "graphics_base": "custom", "monitor": -3, "last_fullscreen": 0,
		"renderer": 5, "first_start_seen": 1, "frame_limit": -60, "fov": 100.0,
		"graphics_custom": {"sparkles": "on", "render_scale": 5000, "upscaler": 2, "edge_smoothing": "msaa_8x",
				"wind_dust": "lots", "shadow_detail": "2048", "shadow_range": 90.0},
	})
	var t := _again()
	assert_eq(t.load_message, "")
	assert_eq(t.graphics_choice, Settings.GRAPHICS_AUTOMATIC, "not a preset")
	assert_eq(t.graphics_base, GraphicsTable.DEFAULT_PRESET, "Custom can't be built on Custom")
	assert_eq(t.monitor, Settings.MONITOR_HERE)
	assert_eq(t.last_fullscreen, Settings.WINDOW_MODE_DEFAULT, "windowed isn't a fullscreen mode")
	assert_eq(t.renderer, Settings.Renderer.AUTO)
	assert_false(t.first_start_seen, "a number is not a flag")
	assert_eq(t.frame_limit, Settings.UNLIMITED, "a negative limit")
	assert_almost_eq(t.fov, 100.0, 1e-6, "a good value beside them is kept")
	assert_eq(t.graphics_custom, {"shadow_detail": "2048", "shadow_range": 90} as Dictionary[String, Variant],
			"each bad Custom row is dropped alone; an unknown row is kept out")
	SaveFile.write(path, Settings.KIND, Settings.VERSION, {"graphics_choice": 3, "graphics_custom": [1, 2]})
	t = _again()
	assert_eq(t.graphics_choice, Settings.GRAPHICS_AUTOMATIC)
	assert_eq(t.graphics_custom, {} as Dictionary[String, Variant])


func test_a_frame_limit_reads_as_the_nearest_the_higher_on_a_tie() -> void:
	var cases: Array[Vector2] = [Vector2(0, 0), Vector2(30, 30), Vector2(10, 30), Vector2(45, 60), Vector2(50, 60),
			Vector2(90, 120), Vector2(100, 120), Vector2(152, 144), Vector2(154.5, 165), Vector2(200, 165), Vector2(202.5, 240),
			Vector2(300, 360), Vector2(1000, 360), Vector2(-1, 0)]
	for c in cases:
		assert_eq(Settings.nearest_frame_limit(c.x), int(c.y), "%s, given %s" % [c.y, c.x])
	SaveFile.write(path, Settings.KIND, Settings.VERSION, {"frame_limit": 75})
	assert_eq(_again().frame_limit, 60, "a saved 75 (katanashotgun's) reads as 60")


func test_a_changed_row_makes_custom_from_the_preset_you_were_on() -> void:
	var table := GraphicsTable.read_file()
	assert_true(s.change_graphics_row(GraphicsQuality.EDGE_SMOOTHING, "smaa", &"medium", table),
			"automatic, the card's pick Medium")
	assert_eq(s.graphics_choice, GraphicsQuality.CUSTOM)
	assert_eq(s.graphics_base, &"medium")
	assert_eq(s.graphics_custom, {"edge_smoothing": "smaa"} as Dictionary[String, Variant])
	assert_true(s.change_graphics_row(GraphicsQuality.WIND_DUST, 20, &"high", table))
	assert_eq(s.graphics_base, &"medium", "already Custom: its base stays")
	assert_eq(s.graphics_custom, {"edge_smoothing": "smaa", "wind_dust": 20} as Dictionary[String, Variant])
	assert_true(s.change_graphics_row(GraphicsQuality.EDGE_SMOOTHING, "off", &"high", table))
	assert_eq(s.graphics_custom, {"wind_dust": 20} as Dictionary[String, Variant], "back to the base's value")
	var q := s.graphics_in_force(&"high", table)
	assert_eq(q.wind_dust, 20)
	assert_eq(q.shadow_detail, table.preset(&"medium").shadow_detail)
	assert_false(s.change_graphics_row(GraphicsQuality.WIND_DUST, 500, &"high", table), "not offered")
	assert_false(s.change_graphics_row(&"sparkles", "on", &"high", table), "not a row")
	assert_eq(s.graphics_custom, {"wind_dust": 20} as Dictionary[String, Variant], "nothing changed")
	var u := Settings.new(PlayTuning.new())
	u.graphics_choice = &"low"
	u.change_graphics_row(GraphicsQuality.SUN_SHADOWS, "on", &"high", table)
	assert_eq(u.graphics_base, &"low", "a chosen preset is the base, not the card's pick")
	assert_true(u.graphics_in_force(&"high", table).sun_shadows)


func test_choosing_custom_starts_from_the_preset_you_were_on() -> void:
	var table := GraphicsTable.read_file()
	s.graphics_choice = &"ultra"
	assert_true(s.choose_graphics(GraphicsQuality.CUSTOM, &"medium"))
	assert_eq(s.graphics_base, &"ultra")
	assert_eq(s.graphics_custom, {} as Dictionary[String, Variant])
	assert_true(s.graphics_in_force(&"medium", table).equals(table.preset(&"ultra")))
	s.change_graphics_row(GraphicsQuality.WIND_DUST, 10, &"medium", table)
	assert_true(s.choose_graphics(GraphicsQuality.CUSTOM, &"medium"), "Custom again keeps its rows")
	assert_eq(s.graphics_custom, {"wind_dust": 10} as Dictionary[String, Variant])
	assert_true(s.choose_graphics(Settings.GRAPHICS_AUTOMATIC, &"medium"))
	assert_true(s.graphics_in_force(&"medium", table).equals(table.preset(&"medium")), "automatic: the card's pick")
	assert_false(s.choose_graphics(&"extreme", &"medium"))
	assert_eq(s.graphics_choice, Settings.GRAPHICS_AUTOMATIC)


func test_the_graphics_flag_forces_its_preset_for_the_run_and_is_never_saved() -> void:
	var table := GraphicsTable.read_file()
	s.graphics_choice = &"low"
	s.graphics_forced = GraphicsPick.forced(PackedStringArray(["--graphics=ultra"]))
	assert_true(s.graphics_in_force(&"medium", table).equals(table.preset(&"ultra")))
	var saved := s.to_dict()
	assert_eq(saved.get("graphics_choice"), "low", "the player's own choice is what is saved")
	assert_false(saved.values().has("ultra"), "the forced preset is nowhere in the file")
	s.save(path)
	assert_eq(_again().graphics_forced, &"")


func test_picking_a_preset_drops_customs_rows() -> void:
	var s := Settings.new()
	assert_true(s.change_graphics_row(&"wind_dust", 10, &"high"))
	assert_false(s.graphics_custom.is_empty())
	assert_true(s.choose_graphics(&"low", &"high"))
	assert_true(s.graphics_custom.is_empty(), "no stale rows saved under a preset")


func test_the_accessibility_fields_start_at_their_defaults() -> void:
	assert_eq(s.team_colours, TeamColours.Set.STANDARD)
	assert_true(s.gauge_patterns, "patterns on")
	assert_false(s.sound_cues, "cues off: playing by ear stays the norm")
	assert_eq(s.sound_cue_size, 1.0)
	assert_eq(HudPrefs.COLOURS[s.sound_cue_colour], Color("ff3b30"), "red")
	assert_eq(s.reduced_motion, Settings.ReducedMotion.SYSTEM)
	assert_true(s.read_out)


func test_the_accessibility_fields_round_trip_through_the_save_file() -> void:
	s.team_colours = TeamColours.Set.HIGH_CONTRAST
	s.gauge_patterns = false
	s.sound_cues = true
	s.sound_cue_size = 1.7
	s.sound_cue_colour = 2
	s.reduced_motion = Settings.ReducedMotion.OFF
	s.read_out = false
	s.hud.hud_size = 0.85
	assert_true(s.save(path))
	var t := _again()
	assert_eq(t.team_colours, TeamColours.Set.HIGH_CONTRAST)
	assert_false(t.gauge_patterns)
	assert_true(t.sound_cues)
	assert_almost_eq(t.sound_cue_size, 1.7, 1e-6)
	assert_eq(t.sound_cue_colour, 2)
	assert_eq(t.reduced_motion, Settings.ReducedMotion.OFF)
	assert_false(t.read_out)
	assert_almost_eq(t.hud.hud_size, 0.85, 1e-6)
	s.reduced_motion = Settings.ReducedMotion.ON
	s.save(path)
	assert_eq(_again().reduced_motion, Settings.ReducedMotion.ON)


func test_following_the_system_is_never_written() -> void:
	assert_false(s.to_dict().has("reduced_motion"), "System: nothing in the file")
	s.reduced_motion = Settings.ReducedMotion.ON
	assert_eq(s.to_dict().get("reduced_motion"), true, "saved as on")
	s.reduced_motion = Settings.ReducedMotion.OFF
	assert_eq(s.to_dict().get("reduced_motion"), false, "saved as off")


func test_reduced_motion_follows_the_system_until_the_player_picks() -> void:
	assert_true(s.reduces_motion(1), "the system asks for it")
	assert_false(s.reduces_motion(0), "the system doesn't")
	assert_false(s.reduces_motion(-1), "the system can't say: full motion")
	s.reduced_motion = Settings.ReducedMotion.OFF
	assert_false(s.reduces_motion(1), "Off wins over the system")
	s.reduced_motion = Settings.ReducedMotion.ON
	assert_true(s.reduces_motion(0), "On wins over the system")
	assert_true(s.reduces_motion_now())
	s.reduced_motion = Settings.ReducedMotion.SYSTEM
	assert_false(s.reduces_motion_now(), "a headless display never asks")


func test_a_file_from_before_the_accessibility_fields_loads_unchanged() -> void:
	SaveFile.write(path, Settings.KIND, Settings.VERSION, {
		"sensitivity": 1.5, "fov": 95.0, "realistic_colours": true, "hud": {"colour": 2},
	})
	var t := _again()
	assert_eq(Settings.VERSION, 3, "3 since AU1 moved the ambience's default; adding fields does not bump it")
	assert_eq(t.load_message, "")
	assert_almost_eq(t.sensitivity, 1.5, 1e-6)
	assert_almost_eq(t.fov, 95.0, 1e-6)
	assert_true(t.realistic_colours)
	assert_eq(t.hud.colour, 2)
	var d := Settings.new(PlayTuning.new())
	assert_eq([t.team_colours, t.gauge_patterns, t.sound_cues, t.sound_cue_size, t.sound_cue_colour, t.reduced_motion,
			t.read_out, t.hud.hud_size], [d.team_colours, d.gauge_patterns, d.sound_cues, d.sound_cue_size,
			d.sound_cue_colour, d.reduced_motion, d.read_out, d.hud.hud_size])


func test_each_bad_accessibility_value_keeps_its_own_default() -> void:
	SaveFile.write(path, Settings.KIND, Settings.VERSION, {
		"team_colours": 2, "gauge_patterns": "no", "sound_cues": true, "sound_cue_size": 2.5, "sound_cue_colour": 6,
		"reduced_motion": "on", "read_out": 0, "hud": {"hud_size": 0.79},
	})
	var t := _again()
	assert_eq(t.load_message, "", "a good file with bad values is not a damaged file")
	assert_eq(t.team_colours, TeamColours.Set.STANDARD, "no third set")
	assert_true(t.gauge_patterns, "not a bool")
	assert_true(t.sound_cues, "a good value beside them is kept")
	assert_eq(t.sound_cue_size, 1.0, "over the slider's range")
	assert_eq(t.sound_cue_colour, AccessibilityConfig.CUE_COLOUR_DEFAULT, "no seventh colour")
	assert_eq(t.reduced_motion, Settings.ReducedMotion.SYSTEM, "a word is not on or off")
	assert_true(t.read_out, "a number is not a flag")
	assert_eq(t.hud.hud_size, 1.0, "under the slider's range")
	t.from_dict({"team_colours": -1, "sound_cue_size": 0.62, "sound_cue_colour": "red"})
	assert_eq(t.team_colours, TeamColours.Set.STANDARD)
	assert_almost_eq(t.sound_cue_size, 0.6, 1e-6, "between steps reads as the nearest")
	assert_eq(t.sound_cue_colour, AccessibilityConfig.CUE_COLOUR_DEFAULT)


## RB1: robots are the Dev tab's Easter egg. A save from before (the public Looks › Robots, `robots` at the top) loads
## cleanly with robots off, whatever it held, and is not written back.
func test_a_save_with_the_old_public_robots_loads_with_robots_off() -> void:
	assert_false(s.to_dict().has("robots"), "no public robots key is written")
	for old: Variant in [true, false, 1, "true", null, {}]:
		SaveFile.write(path, Settings.KIND, Settings.VERSION, {"robots": old, "fov": 95.0, "read_out": false,
				"dev_enabled": true})
		var t := _again()
		assert_eq(t.load_message, "", "an old file is not a damaged file (%s)" % str(old))
		assert_false(t.dev.robots, "the old public value is ignored, robots off in play (%s)" % str(old))
		assert_almost_eq(t.fov, 95.0, 1e-6, "the rest of the file is kept")
		assert_false(t.read_out)
		assert_false(t.to_dict().has("robots"), "dropped on the next save")
