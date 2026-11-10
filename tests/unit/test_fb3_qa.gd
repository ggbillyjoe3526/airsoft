extends GutTest
## FB3 (the Dev tab always there, its switches off and applying whenever set): QA's checks of what the worker's tests
## leave open. Every switch that changes play keeps a match off the records; an old save with the Dev settings box
## ticked, unticked, missing, mistyped or naming a switch that is gone; a match built from such a save; the Dev tab's
## switches by keyboard; the bug report's Dev line with a cheat on; Dev-only content still behind its own switch.

const ROOT := "user://test-fb3-qa"

var dir := ""
var path := ""
var _n := 0


func before_each() -> void:
	_n += 1
	dir = "%s/%d" % [ROOT, _n]
	DirAccess.make_dir_recursive_absolute(dir)
	path = dir.path_join("settings.save")


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


## A settings file as an older build wrote it: the box key `box` (left out when null) over the Dev switches `dev`.
func _old_file(box: Variant, dev: Variant) -> Settings:
	var d := Settings.new(PlayTuning.new()).to_dict()
	d["dev"] = dev
	if box != null:
		d["dev_enabled"] = box
	assert_true(SaveFile.write(path, Settings.KIND, Settings.VERSION, d))
	var s := Settings.new(PlayTuning.new())
	s.load_file(path)
	assert_eq(s.load_message, "", "an old file is not a damaged one")
	return s


func test_every_switch_that_changes_play_keeps_a_match_off_the_record_and_the_looks_do_not() -> void:
	var cheat: Array[Callable] = [
		func(d: DevSettings) -> void: d.game_speed = 0.5,
		func(d: DevSettings) -> void: d.bottomless = true,
		func(d: DevSettings) -> void: d.ghost = true,
		func(d: DevSettings) -> void: d.bots_hold_fire = true,
		func(d: DevSettings) -> void: d.bots_run_low = true,
		func(d: DevSettings) -> void: d.spectate_bots = true,
		func(d: DevSettings) -> void: d.bot_intent = true,
		func(d: DevSettings) -> void: d.disable_levelling = true,
		func(d: DevSettings) -> void: d.time_of_day = LightingConfig.NIGHT,
	]
	for set_it in cheat:
		var d := DevSettings.new()
		set_it.call(d)
		assert_true(d.cheats().any(), "a cheat: %s" % str(d.to_dict()))
	var look: Array[Callable] = [
		func(d: DevSettings) -> void: d.retro_filter = true,
		func(d: DevSettings) -> void: d.robots = true,
		func(d: DevSettings) -> void: d.pretend_slow_frames = true,
		func(d: DevSettings) -> void: d.dev_content = true,
	]
	for set_it in look:
		var d := DevSettings.new()
		set_it.call(d)
		assert_false(d.cheats().any(), "no cheat: %s" % str(d.to_dict()))


func test_a_save_with_no_box_key_reads_its_switches_as_written() -> void:
	var stale := DevSettings.new()
	stale.ghost = true
	stale.game_speed = 2.0
	var s := _old_file(null, stale.to_dict())
	assert_eq(s.dev.to_dict(), stale.to_dict(), "every save from now on has no box key")


func test_a_box_key_of_the_wrong_type_is_not_read_as_unticked() -> void:
	var stale := DevSettings.new()
	stale.ghost = true
	for odd: Variant in ["false", 0, 0.0, [], {}]:
		var s := _old_file(odd, stale.to_dict())
		assert_true(s.dev.ghost, "a box key of %s is ignored" % str(odd))


func test_a_save_naming_a_switch_that_is_gone_loads_clean_with_the_box_ticked_or_not() -> void:
	var named := DevSettings.new().to_dict()
	named["rigged_figures"] = true
	named["a_switch_never_made"] = 3
	named["ghost"] = true
	for box: Variant in [true, false, null]:
		var s := _old_file(box, named)
		assert_false(s.dev.robots, "no stray switch")
		assert_eq(s.dev.ghost, box != false, "the box %s: the known switch is kept only unless it was unticked" % str(box))
		var kept := s.to_dict()["dev"] as Dictionary
		assert_false(kept.has("rigged_figures") or kept.has("a_switch_never_made"), "dropped when saved again")
		assert_false(s.to_dict().has("dev_enabled"))


func test_an_unticked_save_with_a_damaged_dev_block_still_loads() -> void:
	for dev: Variant in [null, "ghost", 4, [true], {}]:
		var s := _old_file(false, dev)
		assert_eq(s.dev.to_dict(), DevSettings.new().to_dict(), "defaults for %s" % str(dev))


func test_the_reset_covers_every_switch_an_unticked_save_held() -> void:
	var all := DevSettings.new()
	all.dev_content = true
	all.disable_levelling = true
	all.game_speed = 2.0
	all.bottomless = true
	all.ghost = true
	all.bots_hold_fire = true
	all.bots_run_low = true
	all.spectate_bots = true
	all.bot_intent = true
	all.retro_filter = true
	all.robots = true
	all.pretend_slow_frames = true
	all.time_of_day = LightingConfig.DAY
	assert_ne(all.to_dict(), DevSettings.new().to_dict())
	assert_eq(_old_file(false, all.to_dict()).dev.to_dict(), DevSettings.new().to_dict())
	assert_eq(_old_file(true, all.to_dict()).dev.to_dict(), all.to_dict(), "ticked: every switch carries on")


func test_a_match_from_a_ticked_old_save_is_off_the_record_and_from_an_unticked_one_is_on_it() -> void:
	var ghost := DevSettings.new()
	ghost.ghost = true
	for box: bool in [true, false]:
		var session := PlaySession.new()
		session.settings = _old_file(box, ghost.to_dict())
		session.map_id = "depot"
		session.autopilot = true
		add_child_autofree(session)
		await wait_physics_frames(2)
		assert_eq(session.state.off_record, box, "box %s" % str(box))
		assert_eq(session.state.cheats.ghost, box)


func test_a_switch_set_while_playing_with_no_box_takes_the_match_off_the_record() -> void:
	var s := Settings.new(PlayTuning.new())
	var session := PlaySession.new()
	session.settings = s
	session.map_id = "depot"
	session.autopilot = true
	add_child_autofree(session)
	await wait_physics_frames(2)
	assert_false(session.state.off_record)
	s.dev.bots_run_low = true
	s.mark_changed()
	await wait_physics_frames(2)
	assert_true(session.state.off_record, "no box to tick first")
	assert_true(session.state.cheats.bots_run_low)


func test_a_new_player_plays_with_no_dev_only_feature_reachable() -> void:
	var s := Settings.new(PlayTuning.new())
	var session := PlaySession.new()
	session.settings = s
	session.map_id = "depot"
	session.autopilot = true
	add_child_autofree(session)
	await wait_physics_frames(2)
	for kind in session.figure_kinds:
		assert_eq(kind, 0, "everyone human: Robots is its own switch")
	assert_false(session.state.cheats.bots_run_low, "Bots run low on BBs is its own switch")
	assert_false(session.state.dev_content)
	for e in MapCatalog.shared().listed(s.dev.dev_content):
		assert_false(MapCatalog.shared().is_dev(e.id), "%s is a dev map" % e.id)
	assert_false(session.find_children("*", "BotIntentView", true, false).size() > 0)


func test_every_dev_switch_is_a_focusable_row_that_keyboard_accept_flips() -> void:
	var s := Settings.new(PlayTuning.new())
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = path
	add_child_autofree(screen)
	screen.open()
	screen._tabs.current_tab = screen._dev_page.get_parent().get_index()
	await wait_process_frames(2)
	var ok := screen._dev_checks[&"retro_filter"]
	for field: StringName in SettingsScreen.DEV_SWITCHES:
		assert_ne(screen._dev_checks[field].focus_mode, Control.FOCUS_NONE, "%s takes focus" % field)
	ok.grab_focus()
	var press := InputEventKey.new()
	press.keycode = KEY_ENTER
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	get_viewport().push_input(press)
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	get_viewport().push_input(release)
	await wait_process_frames(2)
	assert_true(s.dev.retro_filter, "Enter on the focused switch turned it on")
	assert_true(s.dirty or FileAccess.file_exists(path), "and it was saved")


func test_the_bug_report_names_the_switches_turned_on() -> void:
	var s := Settings.new(PlayTuning.new())
	s.dev.ghost = true
	s.dev.time_of_day = LightingConfig.NIGHT
	var line := ReportFacts.dev_text(s.dev.to_dict(), DevSettings.new().to_dict())
	assert_string_contains(line, "ghost on")
	assert_string_contains(line, "time_of_day")
	assert_eq(ReportFacts.dev_text(DevSettings.new().to_dict(), DevSettings.new().to_dict()), BugReport.NONE)
	var info := BugReport.ReportInfo.new()
	info.dev_settings = line
	assert_string_contains(BugReport.write(info), "\nDev settings: %s\n" % line)
