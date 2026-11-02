extends GutTest
## UR6: Settings as concept B v2 (`settings.png`): the SETTINGS title over pill tabs, the open one white with dark
## words, and each row of choices a segmented control on a dark track with the picked one white.

const MAIN := preload("res://game/main.tscn")


func _main() -> Node:
	var main: Node = MAIN.instantiate()
	# the test's own files, never the player's saves
	var graphics: GraphicsStartUp = main.graphics
	graphics.guard_path = "user://test-ur6-guard.json"
	graphics.renderer_path = "user://test-ur6-renderer.json"
	graphics.settings_path = "user://test-ur6-settings.json"
	main.run_path = "user://test-ur6-run.json"
	add_child_autofree(main)
	return main


func test_the_menus_settings_have_the_settings_title() -> void:
	var main := _main()
	await wait_process_frames(3)
	main._on_tab(NavRail.Tab.SETTINGS)
	await wait_process_frames(2)
	var s: SettingsScreen = main._settings_screen
	var row := s.find_child("TitleRow", true, false) as HBoxContainer
	assert_not_null(row, "Settings opens on its page title")
	var title := row.find_child("Title", true, false) as Label
	assert_eq(title.text, "SETTINGS")
	assert_eq(row.get_child_count(), 1, "no empty line beside it")


func test_the_open_tab_is_a_white_pill_with_dark_words() -> void:
	var t := GameTheme.get_theme()
	var open := t.get_stylebox("tab_selected", "TabContainer") as StyleBoxFlat
	assert_eq(open.bg_color, GameTheme.TEXT)
	assert_eq(t.get_color("font_selected_color", "TabContainer"), GameTheme.BG)
	var shut := t.get_stylebox("tab_unselected", "TabContainer") as StyleBoxFlat
	assert_eq(shut.bg_color, GameTheme.CARD)
	assert_true(t.get_stylebox("tabbar_background", "TabContainer") is StyleBoxEmpty, "no bar behind the pills")


func test_the_tabs_start_under_the_title() -> void:
	var main := _main()
	await wait_process_frames(3)
	main._on_tab(NavRail.Tab.SETTINGS)
	await wait_process_frames(3)
	var s: SettingsScreen = main._settings_screen
	var title := s.find_child("TitleRow", true, false) as Control
	var first := s._tabs.get_tab_bar().get_tab_rect(0)
	var x := s._tabs.get_tab_bar().global_position.x + first.position.x
	assert_almost_eq(x, title.global_position.x, 1.0, "the first pill lines up with the title")


func test_a_choice_row_is_a_track_with_the_pick_white() -> void:
	var c := MenuChoice.new(PackedStringArray(["low", "high"]))
	add_child_autofree(c)
	await wait_process_frames(2)
	assert_not_null(c._track, "the buttons sit on a track")
	c.put(1)
	var lit := c.button(1).get_theme_stylebox("pressed") as StyleBoxFlat
	assert_eq(lit.bg_color, GameTheme.TEXT)
	assert_eq(c.button(1).get_theme_color("font_pressed_color"), GameTheme.BG)
	var plain := c.button(0).get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(plain.bg_color.a, 0.0, "an unpicked choice is clear on the track")


func test_swatches_have_no_track() -> void:
	var colours: Array[Color] = [Color.RED, Color.GREEN]
	var w := MenuSwatches.new(colours)
	add_child_autofree(w)
	await wait_process_frames(2)
	assert_null(w._track)
