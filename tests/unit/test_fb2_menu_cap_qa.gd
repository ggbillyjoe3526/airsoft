extends GutTest
## FB2 fix round 1, QA: the menus' refresh-rate cap through every way into and out of a match (start, quit from the
## pause menu, practice and its Loadout, a map that will not load), the background limit with it, a limit picked in
## Settings from the menus, focus lost and regained, F11 in the menus, and the first start's fullscreen for F11.

const LOAD_LIMIT := 30.0
const MAIN := preload("res://game/main.tscn")
const RATE := 144.0

var ds: FakeScreens = null
var shared_limit: int = 0


func before_each() -> void:
	ds = FakeScreens.new()
	ds.rates[0] = RATE
	SettingsApply.use_screens(ds)
	shared_limit = Settings.shared().frame_limit
	Settings.shared().frame_limit = Settings.UNLIMITED


func after_each() -> void:
	await wait_process_frames(2)
	Settings.shared().frame_limit = shared_limit
	SettingsApply.use_screens(null)
	Engine.max_fps = 0
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _main() -> Node:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	return main


func _watch_of(main: Node) -> WindowWatch:
	for c in main.get_children():
		if c is WindowWatch:
			return c as WindowWatch
	return null


func _load(main: Node) -> bool:
	return await wait_until(func() -> bool: return main._loading == null, LOAD_LIMIT)


func _rate() -> int:
	return roundi(RATE)


func test_the_title_starts_capped_and_a_match_goes_to_the_players_limit_and_back() -> void:
	var main := await _main()
	assert_true(ds.menus, "the title is a menu")
	assert_eq(Engine.max_fps, _rate(), "capped at the screen's rate from the first frame")
	main._picks.map_id = "range"
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._start_play()
	assert_true(ds.menus, "the loading screen is still capped")
	assert_eq(Engine.max_fps, _rate(), "and still capped while the match builds")
	assert_true(await _load(main), "the range loads")
	assert_false(ds.menus)
	assert_eq(Engine.max_fps, 0, "the range runs on the player's Unlimited")
	main._play._open_pause()
	assert_eq(Engine.max_fps, 0, "the pause menu of a match runs on the player's limit too")
	main._play._pause.left.emit()
	assert_null(main._play, "quit from pause frees the match")
	assert_true(ds.menus)
	assert_eq(Engine.max_fps, _rate(), "back at the title: capped again")


func test_a_bot_match_quit_from_pause_returns_to_the_capped_menus() -> void:
	var main := await _main()
	main._start_play()
	assert_true(await _load(main), "the match loads")
	assert_eq(Engine.max_fps, 0, "the match: the player's limit")
	main._play._open_pause()
	main._play._pause.left.emit()
	assert_true(ds.menus)
	assert_eq(Engine.max_fps, _rate())
	main._start_play()
	assert_eq(Engine.max_fps, _rate(), "a second match loads capped too")
	assert_true(await _load(main))
	assert_eq(Engine.max_fps, 0)
	main._end_play()
	assert_eq(Engine.max_fps, _rate())


func test_practice_loadout_is_capped_and_the_range_after_it_is_not() -> void:
	var main := await _main()
	main._picks.map_id = "range"
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._start_play()
	assert_true(await _load(main))
	main._play._unhandled_input(_action(&"loadout"))
	assert_null(main._play)
	assert_true(ds.menus, "the Loadout from practice is a menu")
	assert_eq(Engine.max_fps, _rate())
	await wait_process_frames(2)
	main._menus._unhandled_input(_action(&"loadout"))
	assert_eq(Engine.max_fps, _rate(), "the range building again is still capped")
	assert_true(await _load(main))
	assert_eq(Engine.max_fps, 0, "and runs on the player's limit once drawn")
	main._end_play()
	assert_true(ds.menus)
	assert_eq(Engine.max_fps, _rate(), "leaving practice lands on the Match page, capped")


func test_a_map_that_will_not_load_leaves_the_loading_screen_and_the_way_back_re_caps_the_menus() -> void:
	var main := await _main()
	main._picks.map_id = "no_such_map"
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._start_play()
	assert_true(await _load(main), "the loading screen goes even when the map did not load")
	assert_not_null(main._play, "the refusal is shown by the match scene")
	assert_eq(Engine.max_fps, 0, "the refusal screen runs on the player's limit (advisory: it is a menu in all but name)")
	main._play.left.emit()
	assert_null(main._play)
	assert_true(ds.menus)
	assert_eq(Engine.max_fps, _rate(), "Back from the refusal: capped again")
	assert_push_error("refused")


func test_the_background_limit_combines_with_the_menu_cap_through_a_match_and_back() -> void:
	var main := await _main()
	var watch := _watch_of(main)
	assert_not_null(watch)
	watch.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(Engine.max_fps, ds.config.background_fps, "menus unfocused: the lower, the background limit")
	main._picks.map_id = "range"
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._start_play()
	assert_true(await _load(main))
	assert_eq(Engine.max_fps, ds.config.background_fps, "a match unfocused: the background limit over Unlimited")
	main._end_play()
	assert_eq(Engine.max_fps, ds.config.background_fps, "back in the menus unfocused: still the background limit")
	watch.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_eq(Engine.max_fps, _rate(), "focus regained in the menus: the cap, not Unlimited and not the background")


func test_focus_regained_inside_a_match_gives_the_players_limit_not_the_menu_cap() -> void:
	var main := await _main()
	var watch := _watch_of(main)
	main._picks.map_id = "range"
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._start_play()
	assert_true(await _load(main))
	watch.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	watch.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_eq(Engine.max_fps, 0)
	main._end_play()


func test_a_limit_picked_in_settings_from_the_menus_is_held_to_the_rate_and_lower_ones_win() -> void:
	var main := await _main()
	main._open_settings()
	var page: SettingsDisplayPage = main._settings_screen._display_page
	if Settings.shared().frame_limit != Settings.UNLIMITED:
		page.limit_off().button(0).pressed.emit()
	Settings.shared().frame_limit_pick = 240
	assert_eq(Engine.max_fps, _rate(), "Unlimited picked in the menus: the cap")
	page.limit_off().button(0).pressed.emit()
	assert_eq(Settings.shared().frame_limit, 240, "Off pressed again: the slider's 240")
	assert_eq(Engine.max_fps, _rate(), "240 on a 144 screen: the rate in the menus")
	assert_eq(Settings.shared().frame_limit, 240, "but the setting itself stays 240 for the match")
	page.limit_slider().value = 30.0
	assert_eq(Engine.max_fps, 30, "30 is lower than the rate")
	page.limit_slider().value = 240.0
	main._settings_screen.close()
	main._picks.map_id = "range"
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._start_play()
	assert_true(await _load(main))
	assert_eq(Engine.max_fps, 240, "the match runs on the 240 chosen")
	main._end_play()


func test_f11_in_the_menus_keeps_the_cap_and_returns_to_the_first_starts_fullscreen() -> void:
	var main := await _main()
	var s := Settings.shared()
	var was_mode := s.window_mode
	var was_last := s.last_fullscreen
	s.window_mode = Settings.WindowMode.EXCLUSIVE
	s.last_fullscreen = Settings.WindowMode.EXCLUSIVE
	SettingsApply.toggle_fullscreen(s)
	assert_eq(s.window_mode, Settings.WindowMode.WINDOWED)
	assert_eq(Engine.max_fps, _rate(), "a window switch in the menus keeps the cap")
	SettingsApply.toggle_fullscreen(s)
	assert_eq(s.window_mode, Settings.WindowMode.EXCLUSIVE)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	assert_eq(Engine.max_fps, _rate())
	s.window_mode = was_mode
	s.last_fullscreen = was_last
	assert_not_null(main)


func test_a_monitor_with_another_rate_re_caps_when_the_window_moves_there_from_the_menus() -> void:
	var main := await _main()
	ds.sizes.append(Vector2i(1920, 1080))
	ds.rates.append(60.0)
	SettingsApply.pick_monitor(Settings.shared(), 1)
	assert_eq(Engine.max_fps, 60, "the menus follow the new screen's rate")
	assert_not_null(main)
	SettingsApply.pick_monitor(Settings.shared(), 0)


func test_a_screen_that_reports_a_huge_or_odd_rate_is_rounded_not_broken() -> void:
	var main := await _main()
	ds.rates[0] = 59.94
	SettingsApply.apply_frame_rate(Settings.shared())
	assert_eq(Engine.max_fps, 60, "59.94 Hz rounds to 60")
	ds.rates[0] = 0.4
	SettingsApply.apply_frame_rate(Settings.shared())
	assert_eq(Engine.max_fps, 0, "under half a hertz rounds to none (uncapped)")
	assert_not_null(main)


func test_a_v1_save_remembering_a_non_default_fullscreen_keeps_it_and_junk_falls_back() -> void:
	var data := Settings.migrate_defaults({"window_mode": 0, "last_fullscreen": 2}, 1)
	assert_eq(int(data["last_fullscreen"]), 2, "an Exclusive remembered stays Exclusive")
	data = Settings.migrate_defaults({"window_mode": 0, "last_fullscreen": 1.0}, 1)
	assert_eq(int(data["last_fullscreen"]), int(Settings.WINDOW_MODE_DEFAULT), "a float from JSON counts")
	data = Settings.migrate_defaults({"window_mode": 0, "last_fullscreen": "x"}, 1)
	assert_eq(data["last_fullscreen"], "x", "junk is left for the reader to refuse")
	var s := Settings.new(PlayTuning.new())
	s.from_dict(data)
	assert_eq(s.last_fullscreen, Settings.WINDOW_MODE_DEFAULT, "and it reads as the default")
	data = Settings.migrate_defaults({"window_mode": 1, "last_fullscreen": 1}, 1)
	assert_eq(int(data["last_fullscreen"]), 1, "Borderless chosen on purpose is left alone")


func _action(action: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e
