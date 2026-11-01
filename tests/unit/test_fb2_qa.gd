extends GutTest
## QA for FB2 (the first-start defaults): the version 1 to 2 migration at its edges (each field alone, wrong types,
## a missing field, a file that is not changed twice or is newer), imported bundles, the bug report's settings line,
## Custom edge smoothing kept across a restart, the first start's pick, and the window going in and out of Exclusive
## fullscreen against FakeScreens (and never changing in the headless runner).

const ROOT := "user://test-fb2-qa"
## The volumes a version 1 file started with.
const OLD_VOLUMES := {"Master": 1.0, "Effects": 0.8, "Power": 1.0, "Ambience": 0.6, "Interface": 0.5}

var dir := ""
var path := ""
var _n := 0


func before_each() -> void:
	_n += 1
	dir = "%s/%d" % [ROOT, _n]
	_wipe(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	path = dir.path_join("settings.save")


func after_each() -> void:
	SettingsApply.use_screens(null)


func after_all() -> void:
	_wipe(ROOT)


func _wipe(at: String) -> void:
	if not DirAccess.dir_exists_absolute(at):
		return
	for d: String in DirAccess.get_directories_at(at):
		_wipe(at.path_join(d))
	for f: String in DirAccess.get_files_at(at):
		DirAccess.remove_absolute(at.path_join(f))
	DirAccess.remove_absolute(at)


func _load(version: int, data: Dictionary) -> Settings:
	SaveFile.write(path, Settings.KIND, version, data)
	var t := Settings.new(PlayTuning.new())
	t.load_file(path)
	return t


# --- the migration, one field at a time ---

func test_each_volume_alone_at_its_old_default_moves_and_the_others_stay() -> void:
	for bus: StringName in Settings.VOLUME_BUSES:
		var vol := {}
		for other: StringName in Settings.VOLUME_BUSES:
			vol[String(other)] = 0.123 # a value nobody's default was
		vol[String(bus)] = OLD_VOLUMES[String(bus)]
		var t := _load(1, {"volumes": vol})
		for other: StringName in Settings.VOLUME_BUSES:
			var want: float = Settings.VOLUME_DEFAULTS[other] if other == bus else 0.123
			assert_almost_eq(t.volumes[other], want, 1e-6, "%s alone at its old default (%s)" % [bus, other])


func test_a_volume_saved_as_a_whole_number_is_read_like_a_float() -> void:
	var t := _load(1, {"volumes": {"Master": 1, "Power": 1, "Effects": 0}})
	assert_eq(t.volumes[&"Master"], 1.0)
	assert_eq(t.volumes[&"Power"], 1.0)
	assert_eq(t.volumes[&"Effects"], 0.0, "muted is the player's own")


func test_window_mode_and_vsync_each_move_on_their_own() -> void:
	var t := _load(1, {"window_mode": 0, "vsync": false})
	assert_eq(t.window_mode, Settings.WindowMode.EXCLUSIVE, "Windowed moved")
	assert_false(t.vsync)
	t = _load(1, {"window_mode": 0.0, "vsync": true, "volumes": {"Master": 0.4}})
	assert_eq(t.window_mode, Settings.WindowMode.EXCLUSIVE, "a mode saved as a float moved too")
	assert_false(t.vsync)
	assert_eq(t.volumes[&"Master"], 0.4)
	t = _load(1, {"window_mode": 1, "vsync": true})
	assert_eq(t.window_mode, Settings.WindowMode.BORDERLESS, "chosen Borderless kept")
	t = _load(1, {"window_mode": 2, "vsync": false})
	assert_eq(t.window_mode, Settings.WindowMode.EXCLUSIVE, "chosen Exclusive kept")


func test_fields_that_are_missing_take_the_new_defaults() -> void:
	var t := _load(1, {"sensitivity": 1.5})
	assert_eq(t.window_mode, Settings.WindowMode.EXCLUSIVE)
	assert_false(t.vsync)
	for bus: StringName in Settings.VOLUME_BUSES:
		assert_eq(t.volumes[bus], Settings.VOLUME_DEFAULTS[bus], String(bus))
	assert_almost_eq(t.sensitivity, 1.5, 1e-6, "the rest of the file is read")
	assert_eq(t.load_message, "")


func test_fields_of_the_wrong_type_neither_crash_nor_leave_the_old_default() -> void:
	for bad: Variant in ["0.8", [0.8], null, true, {"a": 1}]:
		var t := _load(1, {"volumes": {"Effects": bad, "Ambience": bad}, "window_mode": bad, "vsync": bad})
		assert_eq(t.volumes[&"Effects"], Settings.VOLUME_DEFAULTS[&"Effects"], "Effects as %s" % [bad])
		assert_eq(t.volumes[&"Ambience"], Settings.VOLUME_DEFAULTS[&"Ambience"], "Ambience as %s" % [bad])
		assert_eq(t.window_mode, Settings.WindowMode.EXCLUSIVE, "window_mode as %s" % [bad])
		assert_eq(t.vsync, Settings.VSYNC_DEFAULT, "vsync as %s" % [bad])
	for bad_volumes: Variant in ["loud", [1, 2], null, 7]:
		var t := _load(1, {"volumes": bad_volumes})
		assert_eq(t.volumes[&"Interface"], Settings.VOLUME_DEFAULTS[&"Interface"], "volumes as %s" % [bad_volumes])


func test_a_number_for_vsync_is_not_a_flag_and_is_not_moved() -> void:
	var t := _load(1, {"vsync": 1})
	assert_false(t.vsync, "not a bool: the default, off")


func test_migrating_does_not_change_the_dictionary_it_was_given() -> void:
	var data := {"vsync": true, "window_mode": 0, "volumes": {"Effects": 0.8}}
	var before := data.duplicate(true)
	var moved := Settings.migrate_defaults(data, 1)
	assert_eq(data, before, "the argument is untouched")
	assert_ne(moved, before)
	assert_eq((moved["volumes"] as Dictionary)["Effects"], 0.7)


func test_the_current_version_and_later_pass_through_unchanged() -> void:
	var data := {"vsync": true, "window_mode": 0, "volumes": {"Effects": 0.8, "Ambience": 0.3}}
	assert_eq(Settings.migrate_defaults(data, Settings.VERSION), data)
	assert_eq(Settings.migrate_defaults(data, Settings.VERSION + 1), data)


func test_a_version_2_file_moves_only_an_untouched_ambience() -> void:
	var data := {"vsync": true, "window_mode": 0, "volumes": {"Effects": 0.8, "Ambience": 0.3, "Interface": 0.4}}
	var moved := Settings.migrate_defaults(data, 2)
	var vol: Dictionary = moved["volumes"]
	assert_eq(vol["Ambience"], Settings.VOLUME_DEFAULTS[&"Ambience"], "the old 30 % default moves to 20 %")
	assert_eq(vol["Effects"], 0.8, "a volume the player changed is kept")
	assert_eq(vol["Interface"], 0.4, "a default that did not move stays")
	assert_eq(moved["vsync"], true, "version 2's window and V-Sync are not version 1's: left alone")
	assert_eq(moved["window_mode"], 0)
	var kept := Settings.migrate_defaults({"volumes": {"Ambience": 0.5}}, 2)
	assert_eq((kept["volumes"] as Dictionary)["Ambience"], 0.5, "an ambience the player set is kept")


# --- the version a file holds ---

func test_a_newer_file_is_the_defaults_with_a_message_and_not_half_applied() -> void:
	var t := _load(Settings.VERSION + 1, {"vsync": true, "window_mode": 0, "fov": 100.0,
			"volumes": {"Effects": 0.8}})
	assert_ne(t.load_message, "", "a file from a newer build says so")
	assert_false(t.vsync)
	assert_eq(t.window_mode, Settings.WindowMode.EXCLUSIVE)
	assert_eq(t.volumes[&"Effects"], Settings.VOLUME_DEFAULTS[&"Effects"])
	assert_eq(t.fov, Settings.FOV_DEFAULT)


func test_a_version_0_file_is_refused_not_migrated() -> void:
	var t := _load(0, {"fov": 100.0})
	assert_ne(t.load_message, "")
	assert_eq(t.fov, Settings.FOV_DEFAULT)


func test_a_value_chosen_after_the_move_is_kept_on_every_later_start() -> void:
	var t := _load(1, {"volumes": {"Effects": 0.8}})
	assert_eq(t.volumes[&"Effects"], 0.7)
	t.volumes[&"Effects"] = 0.8 # the player picks the old default on purpose
	t.window_mode = Settings.WindowMode.WINDOWED
	t.vsync = true
	assert_true(t.save(path))
	for i in 3:
		var again := Settings.new(PlayTuning.new())
		again.load_file(path)
		assert_eq(again.volumes[&"Effects"], 0.8, "start %d" % i)
		assert_eq(again.window_mode, Settings.WindowMode.WINDOWED)
		assert_true(again.vsync)
		assert_true(again.save(path))


func test_a_migrated_file_with_graphics_rows_keeps_them() -> void:
	var t := _load(1, {"graphics_choice": "custom", "graphics_base": "medium",
			"graphics_custom": {"edge_smoothing": "msaa_2x", "wind_dust": 20}})
	var q := t.graphics_in_force(&"high")
	assert_eq(q.edge_smoothing, GraphicsQuality.EdgeSmoothing.MSAA_2X, "a Custom row the player set is kept")
	assert_eq(q.wind_dust, 20)


func test_an_old_save_on_a_preset_shows_off_now() -> void:
	for p: String in ["low", "medium", "high", "ultra"]:
		var t := _load(1, {"graphics_choice": p})
		assert_eq(t.graphics_in_force(&"high").edge_smoothing, GraphicsQuality.EdgeSmoothing.OFF, p)


# --- bundles ---

func test_a_bundle_holding_version_1_settings_is_restorable_and_migrates_on_load() -> void:
	var data := {"vsync": true, "window_mode": 0, "volumes": OLD_VOLUMES}
	var bundle := SaveBundle.from_dict({"saved_at": 1, "version": Version.current(),
			"stores": {"settings": {"version": 1, "data": data}}})
	assert_eq(bundle.refusal(), "", "an older settings store is fine")
	var paths: Array[String] = []
	for p: String in SaveBundle.PATHS:
		paths.append(dir.path_join(p.get_file()))
	assert_true(bundle.write(paths))
	var t := Settings.new(PlayTuning.new())
	t.load_file(paths[SaveBundle.KINDS.find(Settings.KIND)])
	assert_eq(t.window_mode, Settings.WindowMode.EXCLUSIVE)
	assert_false(t.vsync)
	assert_eq(t.volumes[&"Ambience"], Settings.VOLUME_DEFAULTS[&"Ambience"])


func test_a_bundle_with_newer_settings_is_refused() -> void:
	var bundle := SaveBundle.from_dict({"saved_at": 1, "version": Version.current(),
			"stores": {"settings": {"version": Settings.VERSION + 1, "data": {}}}})
	assert_ne(bundle.refusal(), "")


# --- the bug report's settings line ---

func test_a_new_player_s_report_names_no_settings_and_a_changed_default_names_it() -> void:
	var fresh := Settings.new(PlayTuning.new())
	assert_eq(ReportFacts.settings_text(fresh.to_dict(), fresh.to_dict()), BugReport.NONE)
	var moved := _load(1, {"window_mode": 0, "vsync": true, "volumes": OLD_VOLUMES})
	assert_eq(ReportFacts.settings_text(moved.to_dict(), fresh.to_dict()), BugReport.NONE,
			"a migrated untouched save reads as a new player's")
	moved.window_mode = Settings.WindowMode.WINDOWED
	moved.vsync = true
	assert_eq(ReportFacts.settings_text(moved.to_dict(), fresh.to_dict()), "vsync on, window_mode windowed")


# --- graphics ---

func test_turning_edge_smoothing_on_from_any_preset_is_custom_and_kept_across_a_restart() -> void:
	for p: StringName in GraphicsTable.PRESETS:
		var s := Settings.new(PlayTuning.new())
		assert_true(s.choose_graphics(p, &"high"))
		assert_true(s.change_graphics_row(GraphicsQuality.EDGE_SMOOTHING, "smaa", &"high"))
		assert_eq(s.graphics_choice, GraphicsQuality.CUSTOM, String(p))
		assert_eq(s.graphics_base, p)
		assert_true(s.save(path))
		var t := Settings.new(PlayTuning.new())
		t.load_file(path)
		var q := t.graphics_in_force(&"medium")
		assert_eq(q.edge_smoothing, GraphicsQuality.EdgeSmoothing.SMAA, "kept after a restart on %s" % p)
		var base := GraphicsTable.shared().preset(p)
		q.edge_smoothing = GraphicsQuality.EdgeSmoothing.OFF
		assert_true(q.equals(base), "nothing but edge smoothing differs from %s" % p)
		assert_true(t.choose_graphics(p, &"medium"))
		assert_eq(t.graphics_in_force(&"medium").edge_smoothing, GraphicsQuality.EdgeSmoothing.OFF,
				"picking the preset again is Off")


func test_the_first_start_pick_lands_on_off_whatever_the_card() -> void:
	var s := Settings.new(PlayTuning.new())
	assert_eq(s.graphics_choice, Settings.GRAPHICS_AUTOMATIC)
	for picked: StringName in [&"medium", &"high", &"low"]:
		assert_eq(s.graphics_in_force(picked).edge_smoothing, GraphicsQuality.EdgeSmoothing.OFF, String(picked))


func test_no_preset_blurb_names_an_edge_smoothing_mode() -> void:
	for p: String in ["LOW", "MEDIUM", "HIGH", "ULTRA"]:
		var words := TranslationServer.translate("GRAPHICS_BLURB_" + p)
		assert_ne(words, "GRAPHICS_BLURB_" + p, "%s has a blurb" % p)
		for mode: String in ["MSAA", "FXAA", "SMAA"]:
			assert_false(words.contains(mode), "%s says %s though every preset is Off" % [p, mode])


# --- the window ---

func test_a_first_start_goes_exclusive_with_v_sync_off_once() -> void:
	var ds := FakeScreens.new()
	SettingsApply.use_screens(ds)
	var s := Settings.new(PlayTuning.new())
	SettingsApply.apply_display(s, true)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	assert_eq(ds.vsync_mode, DisplayServer.VSYNC_DISABLED)
	var calls := ds.calls.size()
	SettingsApply.apply_display(s)
	assert_eq(ds.calls.size(), calls, "applying again changes nothing")


func test_f11_leaves_exclusive_and_comes_back_to_it() -> void:
	var ds := FakeScreens.new()
	SettingsApply.use_screens(ds)
	var s := Settings.new(PlayTuning.new())
	SettingsApply.apply_display(s, true)
	SettingsApply.toggle_fullscreen(s)
	assert_eq(s.window_mode, Settings.WindowMode.WINDOWED)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_MAXIMIZED, "the window the project starts in")
	SettingsApply.toggle_fullscreen(s)
	assert_eq(s.window_mode, Settings.WindowMode.EXCLUSIVE, "F11 back to Exclusive, not Borderless")
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func test_settings_display_leaves_exclusive_for_a_window_and_back() -> void:
	var ds := FakeScreens.new()
	SettingsApply.use_screens(ds)
	var s := Settings.new(PlayTuning.new())
	SettingsApply.apply_display(s, true)
	SettingsApply.pick_window_mode(s, Settings.WindowMode.WINDOWED)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_MAXIMIZED)
	SettingsApply.pick_window_mode(s, Settings.WindowMode.EXCLUSIVE)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	SettingsApply.pick_window_mode(s, Settings.WindowMode.WINDOWED)
	SettingsApply.toggle_fullscreen(s)
	assert_eq(s.window_mode, Settings.WindowMode.EXCLUSIVE, "F11 returns to the mode the player last had")


func test_the_headless_runner_never_changes_the_window_mode() -> void:
	SettingsApply.use_screens(null)
	var mode := DisplayServer.window_get_mode()
	var vsync := DisplayServer.window_get_vsync_mode()
	var s := Settings.new(PlayTuning.new())
	SettingsApply.apply_display(s, true)
	SettingsApply.toggle_fullscreen(s)
	SettingsApply.toggle_fullscreen(s)
	if DisplayServer.get_name() == "headless":
		assert_eq(DisplayServer.window_get_mode(), mode, "headless and the smoke test stay as they are")
		assert_eq(DisplayServer.window_get_vsync_mode(), vsync)
	else:
		pending("needs the headless display server")


func test_the_first_start_card_names_every_window_mode() -> void:
	for mode: Settings.WindowMode in [Settings.WindowMode.WINDOWED, Settings.WindowMode.BORDERLESS,
			Settings.WindowMode.EXCLUSIVE]:
		var words := GraphicsNotice.screen_words(Vector2i(2560, 1440), 144.0, mode)
		assert_true(words.contains("2560"), words)
		assert_false(words.contains("NOTICE_"), "translated: %s" % words)
		assert_false(GraphicsNotice.screen_words(Vector2i(1920, 1080), -1.0, mode).contains("NOTICE_"))
