extends GutTest
## UR1 QA: the entry scene on the menus with no title screen, the rail, the backdrop, the settings' About tab, and the
## state opening and closing them leaves behind.

const MAIN := preload("res://game/main.tscn")


func _main() -> Node:
	var main: Node = MAIN.instantiate()
	# the test's own files, never the player's saves
	var graphics: GraphicsStartUp = main.graphics
	graphics.guard_path = "user://test-ur1-guard.json"
	graphics.renderer_path = "user://test-ur1-renderer.json"
	graphics.settings_path = "user://test-ur1-settings.json"
	main.run_path = "user://test-ur1-run.json"
	add_child_autofree(main)
	return main


func _esc() -> void:
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	Input.parse_input_event(e)


## `node` under a host of `size` px, as a window of that size would hold it.
func _host(node: Control, size: Vector2 = Vector2(1920.0, 1080.0)) -> void:
	var host := Control.new()
	host.custom_minimum_size = size
	host.size = size
	add_child_autofree(host)
	host.add_child(node)


# --- The backdrop ---

func test_the_backdrop_copes_with_a_missing_or_wrong_kind_of_picture() -> void:
	assert_null(MenuBackdrop.blurred("res://assets/maps/nope-not-here.jpg"), "no file")
	assert_null(MenuBackdrop.blurred("res://data/maps/depot.json"), "not a texture")
	assert_null(MenuBackdrop.blurred(""), "empty path")
	var back := MenuBackdrop.new()
	add_child_autofree(back)
	back.show_map("ghost")
	assert_eq(back.map_id(), "ghost")
	assert_null(back.picture().texture, "a field with no picture leaves the plain night")
	back.show_map("depot")
	back.show_map("ghost")
	assert_null(back.picture().texture, "going to a field with no picture drops the last picture")


func test_the_backdrop_blurs_every_listed_fields_picture() -> void:
	for id: String in ["depot", "woodland", "street", "range"]:
		var tex := MenuBackdrop.blurred(MenuBackdrop.PICTURE_DIR + id + ".jpg")
		assert_not_null(tex, id)
		if tex != null:
			assert_eq(tex.get_size(), Vector2(MenuBackdrop.SOFT), id)


func test_the_backdrop_picks_nothing_up_from_the_mouse() -> void:
	var back := MenuBackdrop.new()
	add_child_autofree(back)
	for c: Node in back.find_children("*", "Control", true, false):
		assert_eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, c.name)


func test_building_the_menus_again_and_again_leaves_no_orphans() -> void:
	var before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for i in 5:
		var menus := MenuScreen.new()
		add_child(menus)
		menus.match_page().map_picked.emit("woodland")
		menus.show_loadout()
		menus.show_armory()
		menus.show_match()
		menus.free()
	await wait_process_frames(2)
	assert_lte(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), before)


# --- Boot, settings, About ---

func test_the_settings_open_over_the_page_under_the_rail_and_a_notice() -> void:
	var main := _main()
	await wait_process_frames(2)
	var menus: MenuScreen = main._menus
	var notice := GraphicsNotice.safe_start("High", "Safe")
	menus.show_notice(notice)
	main._on_tab(NavRail.Tab.SETTINGS)
	var s: SettingsScreen = main._settings_screen
	assert_true(s.visible)
	assert_false(menus.match_page().visible, "the page steps aside")
	assert_lt(s.get_index(), menus.nav_rail().get_index(), "under the rail")
	assert_lt(s.get_index(), notice.get_index(), "under the notice")
	assert_gt(menus.nav_rail().get_index(), menus.backdrop().get_index())
	assert_eq(s.offset_left, float(NavRail.WIDTH))
	# a notice shown after the settings is still above them
	var later := GraphicsNotice.safe_start("High", "Safe")
	menus.show_notice(later)
	assert_lt(s.get_index(), later.get_index())
	assert_false(is_instance_valid(notice) and notice.is_inside_tree() and not notice.is_queued_for_deletion())


func test_opening_and_closing_the_settings_about_credits_and_report_leaves_nothing_behind() -> void:
	var main := _main()
	await wait_process_frames(3)
	var base_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var base_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for i in 4:
		main._on_tab(NavRail.Tab.SETTINGS)
		var s: SettingsScreen = main._settings_screen
		s.show_about()
		s.about_credits_button().pressed.emit()
		await wait_process_frames(1)
		main._credits.close()
		s.about_report_button().pressed.emit()
		await wait_process_frames(1)
		assert_not_null(main._report_panel)
		main._report_panel.close()
		await wait_process_frames(1)
		assert_null(main._report_panel)
		s.close()
		await wait_process_frames(2)
		assert_null(main._settings_screen)
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), base_nodes, "no node left over")
	assert_lte(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), base_orphans)
	assert_true(main._menus.match_page().visible, "the page is back")
	assert_eq(main._menus.nav_rail().current(), NavRail.Tab.MATCH)


func test_credits_and_report_close_back_to_their_about_buttons() -> void:
	var main := _main()
	await wait_process_frames(2)
	main._on_tab(NavRail.Tab.SETTINGS)
	var s: SettingsScreen = main._settings_screen
	s.show_about()
	s.about_credits_button().pressed.emit()
	await wait_process_frames(1)
	main._credits.close()
	await wait_process_frames(1)
	assert_eq(get_viewport().gui_get_focus_owner(), s.about_credits_button(), "Licences takes the keyboard back")
	s.about_report_button().pressed.emit()
	await wait_process_frames(1)
	main._report_panel.close()
	await wait_process_frames(1)
	assert_eq(get_viewport().gui_get_focus_owner(), s.about_report_button())


func test_esc_on_about_asks_to_quit_and_cancel_returns_the_keyboard_to_the_settings() -> void:
	var main := _main()
	await wait_process_frames(2)
	main._on_tab(NavRail.Tab.SETTINGS)
	var s: SettingsScreen = main._settings_screen
	s.show_about()
	s.about_quit_button().grab_focus()
	_esc()
	await wait_process_frames(2)
	assert_not_null(main._quit_prompt, "Esc asks QUIT GAME?")
	assert_true(s.visible, "the settings stay")
	main._quit_prompt.close()
	await wait_process_frames(2)
	assert_null(main._quit_prompt)
	assert_not_null(get_viewport().gui_get_focus_owner(), "the keyboard is somewhere")
	assert_true(s.is_ancestor_of(get_viewport().gui_get_focus_owner()), "back in the settings")


func test_esc_in_the_credits_from_about_closes_only_the_credits() -> void:
	var main := _main()
	await wait_process_frames(2)
	main._on_tab(NavRail.Tab.SETTINGS)
	var s: SettingsScreen = main._settings_screen
	s.show_about()
	s.about_credits_button().pressed.emit()
	await wait_process_frames(1)
	assert_true(main._credits.visible)
	_esc()
	await wait_process_frames(2)
	assert_false(main._credits.visible, "Esc closes the credits")
	assert_null(main._quit_prompt, "and does not also ask to quit")
	assert_true(s.visible)


func test_esc_in_the_report_from_about_closes_only_the_report() -> void:
	var main := _main()
	await wait_process_frames(2)
	main._on_tab(NavRail.Tab.SETTINGS)
	var s: SettingsScreen = main._settings_screen
	s.show_about()
	s.about_report_button().pressed.emit()
	await wait_process_frames(1)
	_esc()
	await wait_process_frames(2)
	assert_null(main._report_panel, "Esc closes the report")
	assert_null(main._quit_prompt, "and does not also ask to quit")


func test_pause_menu_settings_have_an_about_tab_with_no_menu_buttons() -> void:
	var s := SettingsScreen.new()
	s.settings = Settings.new()
	s.save_path = "user://test-ur1-pause-settings.json"
	add_child_autofree(s)
	s.show_about()
	s.open()
	assert_null(s.about_report_button())
	assert_null(s.about_credits_button())
	assert_null(s.about_quit_button())
	assert_not_null(s.find_child("Version", true, false))
	var plate := s.get_child(0) as ColorRect
	assert_true(plate.visible, "outside the menus the settings have their own plate")


func test_settings_tab_pressed_twice_does_not_stack_screens() -> void:
	var main := _main()
	await wait_process_frames(2)
	main._on_tab(NavRail.Tab.SETTINGS)
	main._on_tab(NavRail.Tab.SETTINGS)
	var n := 0
	for c: Node in main._menus.get_children():
		if c is SettingsScreen:
			n += 1
	assert_eq(n, 1)


func test_closing_the_settings_from_the_loadout_tab_puts_the_loadout_back() -> void:
	var main := _main()
	await wait_process_frames(2)
	main._on_tab(NavRail.Tab.LOADOUT)
	var menus: MenuScreen = main._menus
	assert_not_null(menus.loadout_page())
	main._on_tab(NavRail.Tab.SETTINGS)
	assert_false(menus.loadout_page().visible, "the Loadout steps aside under the settings")
	main._settings_screen.close()
	await wait_process_frames(2)
	assert_true(menus.loadout_page().visible)
	assert_false(menus.match_page().visible, "the Match page stays hidden behind the Loadout")
	assert_eq(menus.nav_rail().current(), NavRail.Tab.LOADOUT)


func test_closing_the_settings_from_the_armory_tab_puts_the_armory_back_and_focuses_its_tab() -> void:
	var main := _main()
	await wait_process_frames(2)
	main._on_tab(NavRail.Tab.ARMORY)
	var menus: MenuScreen = main._menus
	main._on_tab(NavRail.Tab.SETTINGS)
	main._settings_screen.close()
	await wait_process_frames(2)
	assert_true(menus.armory_page().visible)
	assert_false(menus.match_page().visible)
	assert_eq(get_viewport().gui_get_focus_owner(), menus.nav_rail().tab_button(NavRail.Tab.ARMORY))


func test_a_tab_pressed_with_the_settings_open_shows_that_page() -> void:
	var main := _main()
	await wait_process_frames(2)
	main._on_tab(NavRail.Tab.SETTINGS)
	main._on_tab(NavRail.Tab.LOADOUT)
	await wait_process_frames(2)
	var menus: MenuScreen = main._menus
	assert_null(main._settings_screen)
	assert_not_null(menus.loadout_page())
	assert_true(menus.loadout_page().visible)
	assert_true(menus.loadout_page().get_index() > menus.backdrop().get_index())
	assert_lt(menus.loadout_page().get_index(), menus.nav_rail().get_index(), "the page is under the rail")


# --- Practice ---

func test_the_practice_rail_has_only_loadout_and_back_and_esc_goes_back() -> void:
	var menus := MenuScreen.new()
	add_child_autofree(menus)
	watch_signals(menus)
	menus.open_practice_loadout(Loadout.Slot.PRIMARY)
	var rail := menus.nav_rail()
	assert_true(rail.is_practice())
	assert_false(rail.tab_button(NavRail.Tab.MATCH).visible)
	assert_false(rail.tab_button(NavRail.Tab.ARMORY).visible)
	assert_false(rail.tab_button(NavRail.Tab.SETTINGS).visible)
	assert_true(rail.tab_button(NavRail.Tab.LOADOUT).visible)
	assert_true(rail.back_button().visible)
	assert_false(rail.quit_button().visible)
	assert_false(menus.match_page().visible)
	rail.back_button().pressed.emit()
	assert_signal_emit_count(menus, "practice_requested", 1)
	_esc()
	await wait_process_frames(2)
	assert_signal_emit_count(menus, "practice_requested", 2)


func test_the_practice_rail_keeps_its_height_under_a_720_window() -> void:
	var menus := MenuScreen.new()
	add_child_autofree(menus)
	menus.open_practice_loadout(Loadout.Slot.PRIMARY)
	assert_lte(menus.nav_rail().get_combined_minimum_size().y, 1080.0, "fits the 1080-high design space")


# --- Layout ---

func test_the_rail_fits_the_design_height() -> void:
	var rail := NavRail.new()
	add_child_autofree(rail)
	rail.set_level(12, 0.5)
	assert_lte(rail.get_combined_minimum_size().y, 1080.0)
	assert_lte(rail.get_combined_minimum_size().x, float(NavRail.WIDTH) + 1.0, "no tab or word is wider than the rail")


func test_the_rail_words_do_not_overflow_the_rail() -> void:
	var rail := NavRail.new()
	add_child_autofree(rail)
	rail.set_practice(true)
	await wait_process_frames(2)
	for b: Node in rail.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.visible:
			assert_lte(btn.get_combined_minimum_size().x, float(NavRail.WIDTH), btn.text)
	for l: Node in rail.find_children("*", "Label", true, false):
		var lab := l as Label
		if lab.is_visible_in_tree():
			assert_lte(lab.get_combined_minimum_size().x, float(NavRail.WIDTH), lab.text)


func test_the_pages_beside_the_rail_fit_the_remaining_width() -> void:
	var menus := MenuScreen.new()
	_host(menus)
	await wait_process_frames(2)
	var room := 1920.0 - float(NavRail.WIDTH)
	assert_lte(menus.match_page().get_combined_minimum_size().x, room, "Match page")
	menus.show_loadout()
	await wait_process_frames(2)
	assert_lte(menus.loadout_page().get_combined_minimum_size().x, room, "Loadout page")
	menus.show_armory()
	await wait_process_frames(2)
	assert_lte(menus.armory_page().get_combined_minimum_size().x, room, "Armory page")


func test_nothing_on_the_match_page_is_cut_off_at_the_right_at_1080p() -> void:
	var menus := MenuScreen.new()
	_host(menus)
	await wait_process_frames(3)
	var page := menus.match_page()
	var limit := page.get_global_rect().end.x + 0.5
	var checked := 0
	for c: Node in page.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl.is_visible_in_tree() and ctl.size.x > 0.0 and not (ctl.get_parent() is ScrollContainer):
			checked += 1
			if ctl.get_global_rect().end.x > limit and ctl.clip_contents == false:
				assert_true(false, "%s ends at %.0f past %.0f" % [ctl.get_path(), ctl.get_global_rect().end.x, limit])
				break
	assert_gt(checked, 10, "the page was laid out")


func test_the_about_buttons_fit_the_settings_column() -> void:
	var s := SettingsScreen.new()
	s.settings = Settings.new()
	s.in_menus = true
	s.save_path = "user://test-ur1-about.json"
	_host(s, Vector2(1920.0 - NavRail.WIDTH, 1080.0))
	s.open()
	s.show_about()
	await wait_process_frames(2)
	for b: Button in [s.about_report_button(), s.about_credits_button(), s.about_quit_button()]:
		assert_gt(b.size.x, 40.0, b.text)
		assert_true(s.get_global_rect().encloses(b.get_global_rect()), b.text)


# --- Boot after things ---

func test_after_the_crash_screen_continue_the_keyboard_is_on_play() -> void:
	var r := RunRecord.new()
	r.start("0.1 Dev 3", 1700000000, 1700000100)
	r.play(48213, "depot", "elimination", {}, 0, "normal", "normal", [3, 3] as Array[int])
	r.save("user://test-ur1-run.json")
	var main: Node = MAIN.instantiate()
	main.run_path = "user://test-ur1-run.json"
	main.run_process_running = func(_id: int) -> bool: return false
	main.crash_open = func(_url: String) -> int: return OK
	main.crash_copy = func(_text: String) -> void: pass
	main.crash_log_dir = "user://test-ur1-logs"
	var graphics: GraphicsStartUp = main.graphics
	graphics.guard_path = "user://test-ur1-guard.json"
	graphics.renderer_path = "user://test-ur1-renderer.json"
	graphics.settings_path = "user://test-ur1-settings.json"
	add_child_autofree(main)
	await wait_process_frames(2)
	assert_not_null(main.crash_screen, "the record kept a previous run")
	assert_false(main._menus.visible)
	assert_null(get_viewport().gui_get_focus_owner() if main._menus.is_ancestor_of(
			get_viewport().gui_get_focus_owner() if get_viewport().gui_get_focus_owner() != null else main) else null,
			"no menu control holds the keyboard under the crash screen")
	main.crash_screen.continue_button().pressed.emit()
	await wait_process_frames(2)
	assert_eq(get_viewport().gui_get_focus_owner(), main._menus.match_page().play_button())


## BLOCKING: the settings tabs are laid out for 1920 px; the rail takes 136 of them. HUD (1800 px of tabs), Accessibility
## (1749) and Graphics (1673) are wider than the 1664 px the settings have left, so the screen grows past the window's
## right edge and cuts them off.
func test_every_settings_tab_fits_beside_the_rail_at_1080p() -> void:
	var host := Control.new()
	host.size = Vector2(1920.0, 1080.0)
	add_child_autofree(host)
	var menus := MenuScreen.new()
	host.add_child(menus)
	var s := SettingsScreen.new()
	s.settings = Settings.new()
	s.in_menus = true
	s.save_path = "user://test-ur1-fit.json"
	menus.add_over_page(s)
	s.open()
	await wait_process_frames(3)
	for i in s._tabs.get_tab_count():
		s._tabs.current_tab = i
		await wait_process_frames(2)
		assert_lte(s.get_global_rect().end.x, 1920.5, "tab %s: the screen ends inside the window" % s._tabs.get_tab_title(i))
		assert_lte(s._tabs.get_global_rect().end.x, 1920.0 - SettingsScreen.MARGIN_X + 0.5,
				"tab %s: its content ends inside the margin" % s._tabs.get_tab_title(i))
