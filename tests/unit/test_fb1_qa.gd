extends GutTest
## FB1 QA: what the menu fixes must keep true under a keyboard and a pointer, beyond test_fb1_menus.gd: the focus comes
## back where it was when QUIT GAME? closes, a button that is not showing sets no group's width, Esc has its owner in
## each menu state, and the prompt, the screens and the tabs leave nothing behind when they open and close again.

const MAIN := preload("res://game/main.tscn")


func after_each() -> void:
	SettingsApply.use_screens(null)
	Engine.max_fps = 0
	InputMap.load_from_project_settings()
	get_tree().paused = false


func _esc() -> void:
	await _action(&"ui_cancel")


func _action(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await wait_process_frames(2)


## A real key press and release, as the keyboard sends it.
func _key(code: Key, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.shift_pressed = shift
		e.pressed = down
		Input.parse_input_event(e)
		await wait_process_frames(2)


func _boot() -> Node:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(3)
	return main


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


## The control a click at `at` reaches under `node`, as Godot picks it (a headless run has no pointer to ask).
func _hit(node: Node, at: Vector2) -> Control:
	for i in range(node.get_child_count() - 1, -1, -1):
		var found := _hit(node.get_child(i), at)
		if found != null:
			return found
	var c := node as Control
	if c != null and c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE \
			and c.get_global_rect().has_point(at):
		return c
	return null


## The Settings screen of `main` on its last-but-one tab (Save file), with the screen's tab box.
func _settings_on_save_tab(main: Node) -> SettingsScreen:
	main._menus.nav_rail().tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(3)
	var screen: SettingsScreen = main._settings_screen
	var tabs: TabContainer = screen.find_children("*", "TabContainer", true, false)[0]
	for t in tabs.get_tab_count():
		if tabs.get_tab_title(t).to_lower().contains("save"):
			tabs.current_tab = t
	await wait_process_frames(3)
	return screen


# --- The focus comes back --------------------------------------------------------------------------------------------

func test_the_focus_is_back_where_it_was_when_cancel_closes_the_prompt_in_the_menus_and_the_settings() -> void:
	var main: Node = await _boot()
	await wait_process_frames(2)
	var before := _focus()
	assert_not_null(before, "the Match page has the keyboard on PLAY")
	main.ask_quit()
	await wait_process_frames(2)
	main._quit_prompt.cancel_button().pressed.emit()
	await wait_process_frames(2)
	assert_eq(_focus(), before, "CANCEL gives the keyboard back to PLAY")
	main._menus.nav_rail().tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(3)
	var in_settings := _focus()
	assert_not_null(in_settings)
	await _esc()
	await _esc()
	assert_eq(_focus(), in_settings, "and in the settings, to the control that had it")


# --- A button that isn't showing sets no width -------------------------------------------------------------------------

func test_a_hidden_button_does_not_widen_its_group() -> void:
	var box := VBoxContainer.new()
	add_child_autofree(box)
	var ok := Button.new()
	ok.text = "OK"
	var quit := Button.new()
	quit.text = "QUIT MATCH"
	var hidden := Button.new()
	hidden.text = "A HIDDEN BUTTON WITH A VERY LONG LABEL INDEED"
	hidden.visible = false
	for b: Button in [ok, quit, hidden]:
		box.add_child(b)
	ButtonWidth.group([ok, quit, hidden])
	await wait_process_frames(3)
	assert_almost_eq(ok.size.x, quit.get_minimum_size().x, 0.5, "the group is as wide as the widest button that shows")


func test_a_button_shown_later_joins_the_group_width() -> void:
	var box := VBoxContainer.new()
	add_child_autofree(box)
	var ok := Button.new()
	ok.text = "OK"
	var late := Button.new()
	late.text = "A BUTTON SHOWN LATER, LONGER THAN OK"
	late.visible = false
	box.add_child(ok)
	box.add_child(late)
	ButtonWidth.group([ok, late])
	await wait_process_frames(3)
	late.visible = true
	await wait_process_frames(3)
	assert_almost_eq(ok.size.x, late.size.x, 0.5, "one width once the long one shows")
	assert_almost_eq(late.size.x, late.get_minimum_size().x, 0.5, "and the long one is not clipped")


func test_the_pause_menu_in_a_match_is_as_wide_as_its_widest_showing_button() -> void:
	var pause := PauseMenu.new()
	add_child_autofree(pause)
	pause.open()
	await wait_process_frames(3)
	var widest := 0.0
	var shown: Array[Button] = []
	for node: Node in pause.find_children("*", "Button", true, false):
		var b := node as Button
		if b.is_visible_in_tree() and b.has_meta(ButtonWidth.META):
			shown.append(b)
			widest = maxf(widest, b.get_minimum_size().x)
	assert_gt(shown.size(), 2)
	for b in shown:
		assert_almost_eq(b.size.x, widest, 1.0, "%s: no wider than the widest showing button needs (the practice-only rows are hidden)" % b.text)


# --- Esc in each menu state --------------------------------------------------------------------------------------------

func test_escape_in_the_practice_loadout_goes_back_to_the_range_and_asks_nothing() -> void:
	var main: Node = await _boot()
	main._menus.open_practice_loadout(Loadout.Slot.PRIMARY)
	await wait_process_frames(3)
	watch_signals(main._menus)
	await _esc()
	assert_signal_emit_count(main._menus, "practice_requested", 1)
	assert_null(main._quit_prompt, "practice has its own way back")
	assert_false(main._menus.nav_rail().quit_button().visible, "and no QUIT in practice")
	main._menus.leave_loadout()
	await wait_process_frames(2)


func test_escape_with_a_settings_question_open_closes_only_the_question() -> void:
	var main: Node = await _boot()
	var screen := await _settings_on_save_tab(main)
	var confirm: SettingsSaveConfirm = screen.save_page().confirm()
	confirm.ask(SettingsSaveConfirm.Ask.new())
	await wait_process_frames(2)
	assert_true(confirm.visible)
	await _esc()
	assert_false(confirm.visible, "Esc answered the question")
	assert_null(main._quit_prompt, "and asked nothing more")
	assert_not_null(main._settings_screen, "the settings stay")


func test_the_match_tab_with_a_settings_question_open_frees_the_settings_and_shows_the_match_page() -> void:
	var main: Node = await _boot()
	var screen := await _settings_on_save_tab(main)
	screen.save_page().confirm().ask(SettingsSaveConfirm.Ask.new())
	await wait_process_frames(2)
	main._menus.nav_rail().tab_button(NavRail.Tab.MATCH).pressed.emit()
	await wait_process_frames(3)
	assert_null(main._settings_screen, "the settings were freed")
	assert_true(main._menus.match_page().visible)


func test_escape_ends_a_rebind_then_the_next_asks_quit_game() -> void:
	var main: Node = await _boot()
	main._menus.nav_rail().tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(3)
	var keys: KeyBindingList = main._settings_screen._keys
	keys.begin(&"move_forward", 0)
	await _key(KEY_ESCAPE)
	assert_false(keys.capturing())
	assert_null(main._quit_prompt, "the first Esc only cancelled the rebind")
	await _key(KEY_ESCAPE)
	assert_not_null(main._quit_prompt, "the next Esc asks")
	await _key(KEY_ESCAPE)
	assert_null(main._quit_prompt)


# --- The prompt itself -------------------------------------------------------------------------------------------------

func test_enter_on_cancel_closes_the_prompt_and_on_quit_sends_confirmed() -> void:
	var prompt := QuitPrompt.new()
	add_child_autofree(prompt)
	await wait_process_frames(2)
	# counted by hand: the prompt frees itself on closing, and a signal watcher must not be asked about a freed object
	var confirmed: Array[int] = [0]
	var closed: Array[int] = [0]
	prompt.confirmed.connect(func() -> void: confirmed[0] += 1)
	prompt.closed.connect(func() -> void: closed[0] += 1)
	assert_eq(_focus(), prompt.cancel_button(), "the focus starts on CANCEL")
	prompt.quit_button().grab_focus()
	await _key(KEY_ENTER)
	assert_eq(confirmed[0], 1, "Enter on QUIT quits")
	assert_eq(closed[0], 0)
	prompt.cancel_button().grab_focus()
	await _key(KEY_SPACE)
	assert_eq(confirmed[0], 1, "Space on CANCEL does not")
	assert_eq(closed[0], 1, "it closes")
	assert_false(is_instance_valid(prompt), "and the prompt is freed")


func test_tab_and_the_arrows_stay_in_the_prompt_and_never_reach_the_menu_under_it() -> void:
	var main: Node = await _boot()
	await wait_process_frames(3)
	main.ask_quit()
	await wait_process_frames(2)
	var prompt: QuitPrompt = main._quit_prompt
	var seen: Array[Control] = []
	for code: Key in [KEY_TAB, KEY_TAB, KEY_TAB, KEY_RIGHT, KEY_LEFT, KEY_DOWN, KEY_UP, KEY_PAGEDOWN]:
		await _key(code)
		var f := _focus()
		seen.append(f)
		assert_true(f == prompt.quit_button() or f == prompt.cancel_button(), "key %d keeps the focus in the prompt" % code)
	assert_ne(seen[0], seen[1], "Tab goes from one button to the other")
	prompt.close()


func test_the_prompt_covers_the_menus_so_a_click_never_reaches_them() -> void:
	var main: Node = await _boot()
	await wait_process_frames(3)
	var mark: Button = main._menus.nav_rail().quit_button()
	main.ask_quit()
	await wait_process_frames(2)
	var hit := _hit(main, mark.get_global_rect().get_center())
	assert_not_null(hit)
	assert_true(main._quit_prompt.is_ancestor_of(hit), "the click lands on the prompt's shade, not QUIT")
	main._quit_prompt.close()


func test_two_escapes_in_one_frame_leave_no_prompt_and_asking_again_works() -> void:
	var main: Node = await _boot()
	for i in 2:
		var e := InputEventAction.new()
		e.action = &"ui_cancel"
		e.pressed = true
		Input.parse_input_event(e)
	await wait_process_frames(3)
	assert_null(main._quit_prompt, "the second Esc of the frame closed what the first opened")
	await _esc()
	assert_not_null(main._quit_prompt, "and the next one asks again")
	await _esc()


func test_opening_and_closing_quit_game_the_settings_and_the_tabs_again_leaves_no_nodes() -> void:
	var main: Node = await _boot()
	var bar: NavRail = main._menus.nav_rail()
	bar.tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(3)
	main._settings_screen.close()
	await wait_process_frames(3)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 6:
		main.ask_quit()
		await wait_process_frames(2)
		main._quit_prompt.cancel_button().pressed.emit()
		await wait_process_frames(2)
		bar.tab_button(NavRail.Tab.SETTINGS).pressed.emit()
		await wait_process_frames(2)
		main._settings_screen.close()
		await wait_process_frames(2)
		bar.tab_button(NavRail.Tab.ARMORY).pressed.emit()
		await wait_process_frames(2)
		bar.tab_button(NavRail.Tab.MATCH).pressed.emit()
		await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node left over")
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans)
	assert_eq(bar.quit_button().pressed.get_connections().size(), 1, "one listener on QUIT")
	assert_eq(main._menus.quit_requested.get_connections().size(), 1)


# --- Fix round 1: what the fixes must not break ----------------------------------------------------------------------

func test_the_focus_falls_back_to_the_screens_own_control_when_the_remembered_one_is_gone() -> void:
	var main: Node = await _boot()
	await wait_process_frames(2)
	main.ask_quit()
	await wait_process_frames(2)
	main._quit_prompt._before = null
	main._quit_prompt.close()
	await wait_process_frames(2)
	assert_not_null(_focus(), "the Match page gives the keyboard to a control of its own (no script error)")


func test_a_group_whose_members_are_all_hidden_or_toggle_every_frame_stays_sane() -> void:
	var box := VBoxContainer.new()
	add_child_autofree(box)
	var a := Button.new()
	a.text = "ONE"
	var b := Button.new()
	b.text = "A MUCH LONGER TWO"
	box.add_child(a)
	box.add_child(b)
	var group := ButtonWidth.group([a, b])
	var listeners := b.visibility_changed.get_connections().size()
	a.visible = false
	b.visible = false
	await wait_process_frames(2)
	assert_eq(group.width(), 0.0, "nothing showing, no width to keep")
	for i in 20:
		b.visible = not b.visible
		a.visible = not b.visible
		await wait_process_frames(1)
	b.visible = true
	a.visible = true
	await wait_process_frames(3)
	assert_almost_eq(a.size.x, b.size.x, 0.5)
	assert_almost_eq(b.size.x, b.get_minimum_size().x, 0.5, "the long one is whole again")
	assert_eq(b.visibility_changed.get_connections().size(), listeners, "no listener added by toggling")


func test_escape_in_the_name_field_cancels_the_rename_and_the_next_escape_asks_quit_game() -> void:
	var main: Node = await _boot()
	main._menus.nav_rail().tab_button(NavRail.Tab.LOADOUT).pressed.emit()
	await wait_process_frames(3)
	var page: LoadoutPage = main._menus.loadout_page()
	page.strip().start_rename()
	await wait_process_frames(2)
	await _key(KEY_ESCAPE)
	assert_eq(page.strip().mode, LoadoutStrip.Mode.NORMAL, "one Esc cancels the rename")
	assert_null(main._quit_prompt, "and asks nothing")
	await _key(KEY_ESCAPE)
	assert_not_null(main._quit_prompt, "the next one asks")
	main._quit_prompt.close()
	await wait_process_frames(2)
	main._menus.leave_loadout()
	await wait_process_frames(2)
