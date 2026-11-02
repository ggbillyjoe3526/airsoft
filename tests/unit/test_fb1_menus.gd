extends GutTest
## FB1, the menus after William's 0.1 Dev 1 playtest: a Settings switch keeps its size and nothing moves when it is
## pressed, the For your card tag isn't under its neighbours, Customise's LOADOUT button works, buttons are as wide as
## their words and one width in a group, the rail's QUIT asks QUIT GAME? (UR1: the wordmark's title is gone), Esc asks QUIT GAME?, and Settings' BACK is
## small and at the bottom left.

const MAIN := preload("res://game/main.tscn")
const ROOT := "user://test-fb1-menus"

var _n := 0
var s: Settings = null
var screen: SettingsScreen = null


func before_each() -> void:
	_n += 1
	DirAccess.make_dir_recursive_absolute(ROOT)
	s = Settings.new(PlayTuning.new())
	screen = SettingsScreen.new()
	screen.settings = s
	screen.save_path = "%s/settings-%d.save" % [ROOT, _n]
	add_child_autofree(screen)
	screen.open()


func after_each() -> void:
	SettingsApply.use_screens(null)
	Engine.max_fps = 0
	InputMap.load_from_project_settings()
	get_tree().paused = false


func after_all() -> void:
	for f: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(f))
	DirAccess.remove_absolute(ROOT)


func _esc() -> void:
	var e := InputEventAction.new()
	e.action = &"ui_cancel"
	e.pressed = true
	Input.parse_input_event(e)
	await wait_process_frames(2)


func _boot() -> Node:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	return main


func _rects(n: Node, skip: Node, into: Dictionary) -> void:
	if n == skip:
		return
	var c := n as Control
	if c != null and c.is_visible_in_tree():
		into[c.get_path()] = c.get_global_rect()
	for child in n.get_children():
		_rects(child, skip, into)


func _switches(n: Node, into: Array[CheckButton]) -> void:
	var check := n as CheckButton
	if check != null and check.is_visible_in_tree() and check is MenuSwitch:
		into.append(check)
	for child in n.get_children():
		_switches(child, into)


## The control a click at `at` reaches under `root`, as Godot picks it: the last drawn visible control whose rectangle
## holds the point and whose mouse filter isn't Ignore (a headless run has no pointer to ask).
func _hit(root: Node, at: Vector2) -> Control:
	for i in range(root.get_child_count() - 1, -1, -1):
		var found := _hit(root.get_child(i), at)
		if found != null:
			return found
	var c := root as Control
	if c != null and c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE \
			and c.get_global_rect().has_point(at):
		return c
	return null


# --- 1: the switches -----------------------------------------------------------------------------------------------

func test_pressing_a_switch_on_any_settings_page_moves_and_resizes_nothing_else() -> void:
	var tabs := screen.find_children("*", "TabContainer", true, false)[0] as TabContainer
	var pressed := 0
	for t in tabs.get_tab_count():
		tabs.current_tab = t
		await wait_process_frames(3)
		var switches: Array[CheckButton] = []
		_switches(tabs.get_current_tab_control(), switches)
		for check in switches:
			var preview := tabs.find_child("HudPreview", true, false)
			var before := {}
			_rects(screen, preview, before)
			check.button_pressed = not check.button_pressed
			await wait_process_frames(3)
			var after := {}
			_rects(screen, preview, after)
			for path: NodePath in before:
				if after.has(path):
					assert_eq(after[path], before[path], "%s moved or resized when %s was pressed" % [path, check.get_path()])
			check.button_pressed = not check.button_pressed
			await wait_process_frames(2)
			pressed += 1
	assert_gt(pressed, 12, "the pages' switches were pressed")


func test_a_switch_is_one_size_on_or_off_and_one_line_high_beside_a_long_note() -> void:
	var row := screen.add_row(screen.find_children("*", "VBoxContainer", true, false)[0] as Control, "SETTINGS_INVERT")
	var check := MenuSwitch.new("On", "Off")
	row.add_child(check)
	var note := Label.new()
	note.text = "A long note that wraps over a good many lines beside the switch so the row is tall. ".repeat(6)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)
	await wait_process_frames(3)
	var off_size := check.size
	check.put(true)
	await wait_process_frames(2)
	assert_eq(check.words(), "On")
	assert_eq(check.text, "", "a pill with no words (UI1)")
	assert_eq(check.size, off_size, "the same size on as off")
	assert_lt(check.size.y, note.size.y * 0.8, "not stretched to the note's height")


func test_the_preset_has_no_line_of_prose_its_story_is_the_tooltip_and_custom_moves_nothing() -> void:
	screen.show_graphics()
	await wait_process_frames(3)
	var page: SettingsGraphicsPage = screen.find_children("*", "HBoxContainer", true, false) \
			.filter(func(n: Node) -> bool: return n is SettingsGraphicsPage)[0]
	assert_eq(page.find_children("*", "RichTextLabel", true, false).size(), 0, "no line under Preset (UI1 round 1)")
	var heights := {}
	for choice: StringName in [Settings.GRAPHICS_AUTOMATIC, &"low", &"medium", &"high", &"ultra", GraphicsQuality.CUSTOM]:
		s.graphics_choice = choice
		page.refresh()
		await wait_process_frames(3)
		heights[choice] = page.size.y
		for i in GraphicsTable.PRESETS.size() + 1:
			assert_string_starts_with(page.preset_choice().button(i).tooltip_text, page.blurb(),
					"%s: the story is every preset button's tooltip" % choice)
	for choice: StringName in heights:
		assert_eq(heights[choice], heights[Settings.GRAPHICS_AUTOMATIC], "%s: the same height" % choice)


# --- 2: the For your card tag --------------------------------------------------------------------------------------

func test_the_for_your_card_tag_draws_above_the_buttons_after_it() -> void:
	screen.show_graphics()
	await wait_process_frames(3)
	var page: SettingsGraphicsPage = screen.find_children("*", "HBoxContainer", true, false) \
			.filter(func(n: Node) -> bool: return n is SettingsGraphicsPage)[0]
	var tag: Control = page._tag
	var button := page.tagged()
	assert_false(button.is_ancestor_of(tag), "in its own room above the buttons, not over one (UI1)")
	assert_lte(tag.size.x, button.size.x + 8.0, "no wider than its button, give or take a few px")


# --- 14: Customise's LOADOUT button ---------------------------------------------------------------------------------

func test_a_click_on_the_loadout_button_in_customise_goes_back_to_the_loadout() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	await wait_process_frames(2)
	menus.show_loadout()
	var page := menus.loadout_page()
	page.show_customise()
	await wait_process_frames(3)
	assert_true(page.customising())
	var back := page.find_child("Back", true, false) as Button
	assert_not_null(back)
	assert_eq(_hit(page, back.get_global_rect().get_center()), back,
			"the pointer on the button reaches it: no box of the view lies over it")
	back.pressed.emit()
	assert_false(page.customising(), "the button at the top left of Customise leads back")
	menus.leave_loadout()


func test_the_loadout_tab_in_the_bar_also_leaves_customise() -> void:
	var main: Node = await _boot()
	main._menus.nav_rail().tab_button(NavRail.Tab.LOADOUT).pressed.emit()
	var page: LoadoutPage = main._menus.loadout_page()
	page.show_customise()
	assert_true(page.customising())
	main._menus.nav_rail().tab_button(NavRail.Tab.LOADOUT).pressed.emit()
	assert_false(page.customising(), "the tab for the page you are on goes back to its first screen")
	main._menus.leave_loadout()


# --- 18: button widths ----------------------------------------------------------------------------------------------

func test_a_group_is_as_wide_as_its_widest_button_and_hugs_its_container() -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 900.0
	add_child_autofree(box)
	var buttons: Array[Button] = []
	for words: String in ["OK", "A MUCH LONGER BUTTON", "MIDDLE"]:
		var b := Button.new()
		b.text = words
		box.add_child(b)
		buttons.append(b)
	var group := ButtonWidth.group(buttons)
	await wait_process_frames(2)
	var widest := 0.0
	for b in buttons:
		widest = maxf(widest, b.get_minimum_size().x)
	assert_almost_eq(group.width(), widest, 0.01)
	for b in buttons:
		assert_almost_eq(b.size.x, widest, 0.5, "%s is the widest one's width, not the box's 900" % b.text)
	buttons[0].text = "A STILL MUCH LONGER BUTTON THAN ALL THE REST"
	await wait_process_frames(3)
	for b in buttons:
		assert_almost_eq(b.size.x, buttons[0].get_minimum_size().x, 0.5, "measured again when a button's words change")


func test_choice_rows_are_one_width_and_no_wider_than_their_widest_words() -> void:
	var choice := MenuChoice.new(PackedStringArray(["LOW", "MEDIUM", "HIGH", "ULTRA", "CUSTOM"]))
	add_child_autofree(choice)
	await wait_process_frames(3)
	var natural := 0.0
	for i in 5:
		natural = maxf(natural, choice.button(i).get_minimum_size().x)
	for i in 5:
		assert_almost_eq(choice.button(i).size.x, natural, 0.5)
	var compact := MenuChoice.new(PackedStringArray(["Skirmish", "Custom"]), true)
	add_child_autofree(compact)
	compact.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	await wait_process_frames(3)
	assert_almost_eq(compact.button(0).size.x, compact.button(1).size.x, 0.5)
	assert_lt(compact.button(0).size.x, 300.0, "a compact row no longer fills the width it is in")


func test_swatches_keep_their_squares() -> void:
	var swatches := MenuSwatches.new(HudPrefs.COLOURS)
	add_child_autofree(swatches)
	await wait_process_frames(2)
	assert_eq(swatches.button(0).size, Vector2(MenuSwatches.SIDE, MenuSwatches.SIDE))


func test_the_bar_tabs_are_one_width() -> void:
	var bar := NavRail.new()
	add_child_autofree(bar)
	await wait_process_frames(3)
	var w := bar.tab_button(NavRail.Tab.MATCH).size.x
	for tab: NavRail.Tab in NavRail.TAB_KEYS:
		assert_almost_eq(bar.tab_button(tab).size.x, w, 0.5)


func test_the_pause_menus_buttons_are_one_width_and_the_panel_fits_them() -> void:
	var pause := PauseMenu.new()
	add_child_autofree(pause)
	pause.set_practice("Range", false, 0)
	pause.open()
	await wait_process_frames(3)
	var panel: Control = pause.find_child("Panel", false, false)
	var resume := pause.find_children("*", "Button", true, false)[0] as Button
	var settings_button := pause.find_children("*", "Button", true, false).filter(
			func(b: Node) -> bool: return (b as Button).text == "SETTINGS")[0] as Button
	assert_almost_eq(resume.size.x, settings_button.size.x, 0.5)
	assert_lt(panel.size.x, 560.0, "the panel is no wider than its words and buttons need")
	assert_lt(resume.size.x, panel.size.x, "the buttons hug the left, a button no wider than the widest")


# --- 21: Settings' BACK -----------------------------------------------------------------------------------------------

func test_settings_back_is_a_small_button_at_the_bottom_left() -> void:
	await wait_process_frames(3)
	var back := screen.find_child("Back", true, false) as Button
	assert_not_null(back)
	assert_lt(back.size.x, 220.0, "as wide as its word, not the screen")
	assert_almost_eq(back.get_global_rect().position.x, MenuParts.PAGE_MARGIN.x, 1.0, "at the left margin")
	var screen_rect := screen.get_global_rect()
	assert_gt(back.get_global_rect().position.y, screen_rect.position.y + screen_rect.size.y * 0.8, "at the bottom")


# --- 19: QUIT and Esc -------------------------------------------------------------------------------------------------

func test_quit_in_the_rail_is_hidden_in_practice() -> void:
	var bar := NavRail.new()
	add_child_autofree(bar)
	watch_signals(bar)
	bar.quit_button().pressed.emit()
	assert_signal_emit_count(bar, "quit_pressed", 1)
	bar.set_practice(true)
	assert_false(bar.quit_button().visible, "from practice the way out is BACK TO PRACTICE")
	bar.set_practice(false)
	assert_true(bar.quit_button().visible)


func test_quit_in_the_rail_asks_quit_game_with_the_focus_on_cancel_and_escape_closes_it() -> void:
	var main: Node = await _boot()
	main._menus.nav_rail().quit_button().pressed.emit()
	await wait_process_frames(2)
	var prompt: QuitPrompt = main._quit_prompt
	assert_not_null(prompt, "QUIT asks")
	assert_true(main._menus.visible, "and stays on the menus")
	assert_eq(prompt.get_viewport().gui_get_focus_owner(), prompt.cancel_button(), "CANCEL has the focus")
	assert_eq(prompt.quit_button().size.x, prompt.cancel_button().size.x, "QUIT and CANCEL are one width")
	await _esc()
	assert_null(main._quit_prompt, "Esc closes it")


func test_escape_in_the_menus_and_in_the_settings_asks_quit_game_and_changes_nothing_else() -> void:
	var main: Node = await _boot()
	await _esc()
	assert_not_null(main._quit_prompt)
	assert_true(main._menus.visible, "the menus stay")
	main._quit_prompt.cancel_button().pressed.emit()
	await wait_process_frames(2)
	assert_null(main._quit_prompt, "CANCEL closes it")
	main._menus.nav_rail().tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(2)
	await _esc()
	assert_not_null(main._quit_prompt, "Esc in the settings asks too")
	assert_not_null(main._settings_screen, "the settings stay open under it")
	await _esc()
	assert_null(main._quit_prompt)


func test_quit_sends_confirmed_and_cancel_closes_without_it() -> void:
	var prompt := QuitPrompt.new()
	add_child_autofree(prompt)
	watch_signals(prompt)
	prompt.quit_button().pressed.emit()
	assert_signal_emit_count(prompt, "confirmed", 1)
	prompt.cancel_button().pressed.emit()
	assert_signal_emit_count(prompt, "closed", 1)
	assert_signal_emit_count(prompt, "confirmed", 1)


func test_a_dialog_or_the_credits_take_escape_before_the_quit_prompt() -> void:
	var main: Node = await _boot()
	main._credits.open()
	await _esc()
	assert_false(main._credits.visible, "Esc closed the credits")
	assert_null(main._quit_prompt, "and asked nothing")


func test_escape_while_a_key_waits_to_be_rebound_cancels_it_and_asks_nothing() -> void:
	var main: Node = await _boot()
	main._menus.nav_rail().tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(2)
	var keys: KeyBindingList = main._settings_screen._keys
	keys.begin(&"move_forward", 0)
	assert_true(keys.capturing())
	var e := InputEventKey.new()
	e.physical_keycode = KEY_ESCAPE
	e.keycode = KEY_ESCAPE
	e.pressed = true
	Input.parse_input_event(e)
	await wait_process_frames(2)
	assert_false(keys.capturing(), "Esc cancelled the rebind")
	assert_null(main._quit_prompt)


func test_the_pause_menus_settings_still_close_on_escape() -> void:
	var pause := PauseMenu.new()
	add_child_autofree(pause)
	pause.open()
	pause.open_settings()
	await wait_process_frames(2)
	assert_true(pause.settings_open())
	await _esc()
	assert_false(pause.settings_open(), "in a match Esc closes the settings and leaves the pause menu")


func test_one_escape_in_the_rename_field_cancels_the_rename() -> void:
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	var page := LoadoutPage.new(saved, s)
	page.save_path = "%s/loadouts-%d.save" % [ROOT, _n]
	page.settings_path = "%s/settings-page-%d.save" % [ROOT, _n]
	add_child_autofree(page)
	await wait_process_frames(2)
	var strip := page.strip()
	var before := saved.carried().name
	strip.start_rename()
	await wait_process_frames(2)
	strip.edit().text = "Typed"
	assert_eq(get_viewport().gui_get_focus_owner(), strip.edit(), "the name field has the keyboard")
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	Input.parse_input_event(e)
	await wait_process_frames(2)
	assert_eq(strip.mode, LoadoutStrip.Mode.NORMAL, "the first Esc ends the rename (it took two)")
	assert_eq(saved.carried().name, before, "and drops what was typed")
