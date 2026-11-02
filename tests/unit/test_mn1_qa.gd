extends GutTest
## QA hunt for MN1: navigation, focus, repeated open/close, scale across window sizes, translation keys.

const MAIN := preload("res://game/main.tscn")


func _esc() -> void:
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	Input.parse_input_event(e)
	await wait_process_frames(2)


func _boot() -> Node:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	return main


func test_escape_in_settings_asks_to_quit_and_leaves_the_settings_and_menus_as_they_are() -> void:
	var main: Node = await _boot()
	main._menus.nav_rail().tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(1)
	await _esc()
	assert_not_null(main._quit_prompt, "Esc in the menus' settings asks QUIT GAME? (owner, 2026-10-29)")
	assert_not_null(main._settings_screen, "the settings stay open under it")
	assert_true(main._menus.visible)
	await _esc()
	assert_true(main._quit_prompt == null or main._quit_prompt.is_queued_for_deletion(), "Esc again closes it")
	assert_not_null(main._settings_screen)


func _open_about(main: Node) -> SettingsScreen:
	main._menus.nav_rail().tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(1)
	main._settings_screen.show_about()
	return main._settings_screen


func test_credits_open_from_about_and_escape_closes_them_back_to_about() -> void:
	var main: Node = await _boot()
	var screen: SettingsScreen = await _open_about(main)
	screen.about_credits_button().pressed.emit()
	assert_true(main._credits.visible)
	await _esc()
	assert_false(main._credits.visible)
	assert_not_null(main._settings_screen, "back on Settings › About")
	assert_true(main._menus.visible)


func test_after_the_credits_close_the_focus_is_back_on_licences() -> void:
	var main: Node = await _boot()
	var screen: SettingsScreen = await _open_about(main)
	screen.about_credits_button().pressed.emit()
	main._credits.close()
	await wait_process_frames(2)
	assert_eq(get_viewport().gui_get_focus_owner(), screen.about_credits_button(), "focus returns to Licences")


func test_after_settings_close_enter_still_reaches_play() -> void:
	var main: Node = await _boot()
	main._menus.nav_rail().tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(1)
	main._settings_screen._back.pressed.emit() # Esc now asks QUIT GAME? in the menus; Back closes the settings
	await wait_process_frames(2)
	assert_null(main._settings_screen)
	assert_eq(get_viewport().gui_get_focus_owner(), main._menus.match_page().play_button())


func test_the_game_opens_with_play_focused() -> void:
	var main: Node = await _boot()
	assert_eq(get_viewport().gui_get_focus_owner(), main._menus.match_page().play_button())


func test_opening_and_closing_settings_and_credits_repeatedly_leaks_no_nodes() -> void:
	var main: Node = await _boot()
	var bar: NavRail = main._menus.nav_rail()
	bar.tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(2)
	main._settings_screen.close()
	await wait_process_frames(2)
	var before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var conns := bar.tab_pressed.get_connections().size()
	for i in 5:
		bar.tab_button(NavRail.Tab.SETTINGS).pressed.emit()
		await wait_process_frames(2)
		main._settings_screen.close()
		await wait_process_frames(2)
		main._credits.open()
		main._credits.close()
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), before, "no nodes left behind")
	assert_eq(bar.tab_pressed.get_connections().size(), conns)
	assert_eq(main._menus.nav_rail().current(), NavRail.Tab.MATCH)


func test_settings_round_trips_keep_one_connection_per_signal() -> void:
	var main: Node = await _boot()
	var n_quit: int = main._menus.quit_requested.get_connections().size()
	for i in 4:
		main._menus.nav_rail().tab_button(NavRail.Tab.SETTINGS).pressed.emit()
		await wait_process_frames(1)
		main._settings_screen.close()
		await wait_process_frames(1)
	assert_eq(main._menus.quit_requested.get_connections().size(), n_quit)


func test_dev_content_toggle_adds_and_removes_the_dev_map_choice() -> void:
	var catalog := DevContent.use_map() # every shipped map is public: Woodland tagged dev for the test
	var main: Node = await _boot()
	var s := Settings.shared()
	var was := s.dev.dev_content
	s.dev.dev_content = false
	s.changed.emit()
	var page: MatchPage = main._menus.match_page()
	var base: int = page.map_ids().size()
	s.dev.dev_content = true
	s.changed.emit()
	assert_gt(page.map_ids().size(), base, "dev maps appear")
	s.dev.dev_content = false
	s.changed.emit()
	assert_eq(page.map_ids().size(), base)
	assert_true(page.map_ids().has(main._picks.map_id))
	s.dev.dev_content = was
	DevContent.restore_map(catalog)


func test_menu_scale_is_finite_positive_and_capped_across_window_sizes() -> void:
	for size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440), Vector2(3840, 2160),
			Vector2(3440, 1440), Vector2(5120, 1440), Vector2(320, 200), Vector2(1, 1), Vector2(0, 600),
			Vector2(-5, 5)]:
		var sc := MenuScale.scale_for(size)
		var f := MenuScale.content_factor(size)
		assert_true(sc > 0.0 and sc <= MenuScale.MAX_SCALE, "scale %s" % [size])
		assert_true(f > 0.0 and f <= 1.0 + 1e-6, "factor %s" % [size])
	assert_almost_eq(MenuScale.scale_for(Vector2(3840, 2160)), 2.0, 1e-5)
	assert_almost_eq(MenuScale.scale_for(Vector2(1280, 720)), 720.0 / 1080.0, 1e-5)


func test_content_scale_is_one_in_play_and_restored_on_return() -> void:
	var main: Node = await _boot()
	var w := get_window()
	var old := w.size
	w.size = Vector2i(2560, 1440)
	await wait_process_frames(3)
	var in_menu := w.content_scale_factor
	main._start_play()
	await wait_process_frames(2)
	assert_almost_eq(w.content_scale_factor, 1.0, 1e-5, "play draws at 1")
	main._end_play()
	await wait_process_frames(2)
	assert_almost_eq(w.content_scale_factor, MenuScale.content_factor(Vector2(w.size)), 1e-5)
	w.size = old
	assert_true(in_menu > 0.0)


func _count_menus(main: Node) -> int:
	var n := 0
	for c in main.get_children():
		if c is MenuScreen:
			n += 1
	return n


func test_a_match_frees_the_menus_and_leaving_rebuilds_them() -> void:
	var main: Node = await _boot()
	main._menus.nav_rail().tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(2)
	main._start_play()
	await wait_process_frames(3)
	assert_eq(_count_menus(main), 0, "no menu nodes in play (performance review)")
	assert_null(main._settings_screen, "the settings closed with the menus")
	main._end_play()
	await wait_process_frames(2)
	assert_eq(_count_menus(main), 1, "the menus back")
	# FB6 (owner, 2026-10-30): back on the Match page with Play focused
	assert_true(main._menus.visible)
	assert_eq(get_viewport().gui_get_focus_owner(), main._menus.match_page().play_button())
	assert_gt(main._menus.match_page().map_ids().size(), 0, "the Match page lists the maps again")


func test_every_translation_key_used_in_the_new_ui_exists_in_en_po() -> void:
	var po := FileAccess.get_file_as_string("res://game/ui/text/en.po")
	var re := RegEx.new()
	re.compile("tr\\(\"([A-Z0-9_]+)\"\\)")
	var missing := PackedStringArray()
	for f: String in ["nav_rail", "menu_backdrop", "menu_screen", "match_page", "credits", "settings_screen", "hazard_tape"]:
		var src := FileAccess.get_file_as_string("res://game/ui/%s.gd" % f)
		for m in re.search_all(src):
			if not po.contains("msgid \"%s\"" % m.get_string(1)):
				missing.append(m.get_string(1))
	var main_src := FileAccess.get_file_as_string("res://game/main.gd")
	for m in re.search_all(main_src):
		if not po.contains("msgid \"%s\"" % m.get_string(1)):
			missing.append(m.get_string(1))
	assert_eq(missing.size(), 0, "missing: %s" % ", ".join(missing))
