extends GutTest
## The menus' side rail and backdrop (game/ui/nav_rail.gd, menu_backdrop.gd, menu_screen.gd), and the entry scene
## opening on them (UR1: no title screen).

const MAIN := preload("res://game/main.tscn")


func _texts(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for b in root.find_children("*", "Button", true, false):
		out.append((b as Button).text)
	return out


func test_the_game_opens_on_the_match_page_with_no_title_screen() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	var menus: MenuScreen = main._menus
	assert_true(menus.visible, "the game opens on the menus (UR1: no title screen)")
	assert_eq(menus.nav_rail().current(), NavRail.Tab.MATCH)
	assert_true(menus.match_page().visible)
	assert_eq(get_viewport().gui_get_focus_owner(), menus.match_page().play_button(), "Enter plays")
	assert_null(main.get("_title"), "no title node at all")


func test_the_rail_has_the_wordmark_and_quit_and_quit_asks() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	var bar: NavRail = main._menus.nav_rail()
	var mark := bar.find_child("Wordmark", true, false) as Label
	assert_not_null(mark, "the wordmark is words, not a button")
	assert_eq(mark.text, "AIRSOFT")
	assert_eq(bar.quit_button().text, "QUIT")
	bar.quit_button().pressed.emit()
	await wait_process_frames(1)
	assert_not_null(main._quit_prompt, "QUIT asks QUIT GAME?")
	main._quit_prompt.close()


func test_the_backdrop_shows_the_picked_field_blurred() -> void:
	var menus := MenuScreen.new()
	add_child_autofree(menus)
	var back := menus.backdrop()
	assert_eq(back.map_id(), menus.match_page().picks.map_id, "the field you picked")
	menus.match_page().map_picked.emit("woodland")
	assert_eq(back.map_id(), "woodland")
	if DisplayServer.get_name() != "headless":
		assert_not_null(back.picture().texture)


func test_the_rail_has_the_four_tabs_all_built() -> void:
	var bar := NavRail.new()
	add_child_autofree(bar)
	assert_eq(bar.tab_button(NavRail.Tab.MATCH).text, "MATCH")
	assert_eq(bar.tab_button(NavRail.Tab.LOADOUT).text, "LOADOUT")
	assert_eq(bar.tab_button(NavRail.Tab.ARMORY).text, "ARMORY")
	assert_eq(bar.tab_button(NavRail.Tab.SETTINGS).text, "SETTINGS")
	assert_false(bar.tab_button(NavRail.Tab.MATCH).disabled)
	assert_false(bar.tab_button(NavRail.Tab.SETTINGS).disabled)
	assert_false(bar.tab_button(NavRail.Tab.LOADOUT).disabled, "the Loadout tab is built (LO2)")
	assert_false(bar.tab_button(NavRail.Tab.ARMORY).disabled, "the Armory tab is built (AR1)")
	var later := 0
	for l in bar.find_children("*", "Label", true, false):
		if (l as Label).text == "LATER":
			later += 1
	assert_eq(later, 0, "no LATER tag: every tab is built")


func test_the_level_chip_reads_the_level_and_hides_with_levelling_off() -> void:
	var bar := NavRail.new()
	add_child_autofree(bar)
	bar.set_level(3)
	var chip := bar.find_child("Level", true, false) as Control
	assert_eq(bar.level_text(), "LV 3")
	bar.set_level(-1)
	assert_false(chip.visible, "no chip while levelling is off")
	assert_eq(bar.level_text(), "")


func test_the_current_tab_is_lit() -> void:
	var bar := NavRail.new()
	add_child_autofree(bar)
	assert_eq(bar.current(), NavRail.Tab.MATCH)
	bar.set_current(NavRail.Tab.SETTINGS)
	assert_eq(bar.current(), NavRail.Tab.SETTINGS)
	bar.set_current(NavRail.Tab.ARMORY)
	assert_eq(bar.current(), NavRail.Tab.ARMORY)
	var lit := bar.tab_button(NavRail.Tab.ARMORY).get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(lit.bg_color, GameTheme.CARD_HI, "the lit tab sits on a card")
	var dark := bar.tab_button(NavRail.Tab.MATCH).get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(dark.bg_color.a, 0.0, "the others are bare words")
	var rule := bar.tab_button(NavRail.Tab.ARMORY).get_child(0) as ColorRect
	assert_eq(rule.color, GameTheme.ACCENT)
	assert_true(rule.visible, "with the teal rule")
	assert_false((bar.tab_button(NavRail.Tab.MATCH).get_child(0) as ColorRect).visible)


func test_pressing_a_tab_sends_it() -> void:
	var bar := NavRail.new()
	add_child_autofree(bar)
	watch_signals(bar)
	bar.tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	assert_signal_emitted_with_parameters(bar, "tab_pressed", [NavRail.Tab.SETTINGS])


func test_the_menu_page_has_the_bar_and_a_play_button() -> void:
	var menus := MenuScreen.new()
	add_child_autofree(menus)
	assert_not_null(menus.nav_rail())
	assert_eq(menus.match_page().play_button().text, "PLAY")
	assert_eq(menus.match_page().play_button().theme_type_variation, GameTheme.MAIN_BUTTON)
	watch_signals(menus.match_page())
	menus.match_page().play_button().pressed.emit()
	assert_signal_emitted(menus.match_page(), "play_pressed")


func test_the_slanted_button_leans_right_inside_its_box() -> void:
	var p := SlantStyle.corners(Rect2(10.0, 20.0, 300.0, 80.0))
	assert_eq(p.size(), 4)
	assert_gt(p[0].x, p[3].x, "the top edge sits right of the bottom edge")
	assert_almost_eq(p[0].x - p[3].x, 80.0 * SlantStyle.SKEW, 1e-4)
	assert_eq(p[1].x, 310.0, "the top right corner is the box's")
	assert_eq(p[3].x, 10.0, "the bottom left corner is the box's")


func test_escape_on_the_menus_asks_to_quit() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	var menus: MenuScreen = main._menus
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	Input.parse_input_event(e)
	await wait_process_frames(2)
	assert_not_null(main._quit_prompt, "Esc on the menus asks QUIT GAME? (owner, 2026-10-29)")
	assert_true(menus.visible)
	main._quit_prompt.close()


func test_the_settings_tab_lights_while_the_settings_are_open() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	var bar: NavRail = main._menus.nav_rail()
	bar.tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	assert_eq(bar.current(), NavRail.Tab.SETTINGS)
	assert_eq(main._settings_screen.offset_left, float(NavRail.WIDTH), "beside the rail")
	bar.tab_button(NavRail.Tab.MATCH).pressed.emit()
	await wait_process_frames(2)
	assert_null(main._settings_screen, "the Match tab closes the settings")
	assert_eq(bar.current(), NavRail.Tab.MATCH)


func test_the_main_scene_resets_the_window_scale_when_freed() -> void:
	var main: Node = MAIN.instantiate()
	add_child(main)
	await wait_process_frames(2)
	var window := get_window()
	var cb := Callable(main, "_scale_menus")
	assert_true(window.size_changed.is_connected(cb))
	main.queue_free()
	await wait_process_frames(2)
	assert_false(window.size_changed.is_connected(cb))
	assert_almost_eq(window.content_scale_factor, 1.0, 1e-5)
