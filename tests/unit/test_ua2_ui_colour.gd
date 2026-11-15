extends GutTest
## UA2: Settings › Display › Interface › Colour picks the UI's accent; the pick is saved, applied in place and
## rebuilds the screens that were built in the old colour.

const ROOT := "user://test-ua2"
const MIN_INK_CONTRAST := 4.5
const MIN_TEAM_DISTANCE := 0.2

var _n := 0


func after_each() -> void:
	GameTheme.use_colour(UiColours.DEFAULT)
	SettingsApply.use_screens(null)
	get_tree().paused = false


func after_all() -> void:
	var d := DirAccess.open("user://")
	if d != null and d.dir_exists("test-ua2"):
		for f in DirAccess.get_files_at(ROOT):
			DirAccess.remove_absolute(ROOT.path_join(f))
		DirAccess.remove_absolute(ROOT)


func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)


func _luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _click(c: Control) -> void:
	var at := c.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	c.get_viewport().push_input(move)
	await wait_process_frames(1)
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		c.get_viewport().push_input(e)
		await wait_process_frames(1)
	await wait_process_frames(1)


func _screen() -> SettingsScreen:
	_n += 1
	DirAccess.make_dir_recursive_absolute(ROOT)
	var screen := SettingsScreen.new()
	screen.settings = Settings.new(PlayTuning.new())
	screen.save_path = "%s/%d.save" % [ROOT, _n]
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	add_child_autofree(view)
	view.add_child(screen)
	screen.open()
	return screen


func test_the_default_colour_is_blue() -> void:
	assert_eq(UiColours.DEFAULT, UiColours.Pick.BLUE)
	assert_eq(GameTheme.accent, UiColours.ACCENTS[UiColours.Pick.BLUE])
	assert_eq(Settings.new(PlayTuning.new()).ui_colour, UiColours.Pick.BLUE)


func test_every_colour_has_a_name_an_ink_and_a_readable_one() -> void:
	var count := UiColours.Pick.size()
	assert_eq(UiColours.ACCENTS.size(), count)
	assert_eq(UiColours.INKS.size(), count)
	assert_eq(UiColours.NAME_KEYS.size(), count)
	for i in count:
		assert_gte(_contrast(UiColours.INKS[i], UiColours.ACCENTS[i]), MIN_INK_CONTRAST, "ink on colour %d" % i)


func test_every_colour_stays_apart_from_the_standard_team_colours() -> void:
	var hud := TeamColours.resolve(TeamColours.Set.STANDARD, false).hud
	for i in UiColours.ACCENTS.size():
		for team in hud.colours.size():
			assert_gte(_distance(UiColours.ACCENTS[i], hud.colours[team]), MIN_TEAM_DISTANCE,
				"colour %d vs team %d" % [i, team])


func test_the_pick_round_trips_through_the_save() -> void:
	var a := Settings.new(PlayTuning.new())
	a.ui_colour = UiColours.Pick.VIOLET
	var b := Settings.new(PlayTuning.new())
	b.from_dict(a.to_dict())
	assert_eq(b.ui_colour, UiColours.Pick.VIOLET)


func test_a_bad_saved_colour_is_clamped_or_defaulted() -> void:
	var s := Settings.new(PlayTuning.new())
	for bad: Variant in [99, -4, "x", null]:
		s.from_dict({"ui_colour": bad})
		assert_between(int(s.ui_colour), 0, UiColours.Pick.size() - 1, "clamped for %s" % str(bad))
	s.from_dict({})
	assert_eq(s.ui_colour, UiColours.DEFAULT, "an older file without it falls back")


func test_use_colour_restyles_the_shared_theme_in_place() -> void:
	var theme := GameTheme.get_theme()
	var before := theme.get_stylebox("normal", GameTheme.MAIN_BUTTON)
	assert_eq((before as StyleBoxFlat).bg_color, UiColours.ACCENTS[UiColours.Pick.BLUE])
	assert_true(GameTheme.use_colour(UiColours.Pick.GREEN), "a change reports true")
	assert_same(GameTheme.get_theme(), theme, "the same Theme object")
	var after := theme.get_stylebox("normal", GameTheme.MAIN_BUTTON) as StyleBoxFlat
	assert_eq(after.bg_color, UiColours.ACCENTS[UiColours.Pick.GREEN])
	assert_eq(theme.get_color("font_color", GameTheme.MAIN_BUTTON), UiColours.INKS[UiColours.Pick.GREEN])
	assert_false(GameTheme.use_colour(UiColours.Pick.GREEN), "the same pick reports false")


func test_use_colour_clamps_an_out_of_range_pick() -> void:
	GameTheme.use_colour(99 as UiColours.Pick)
	assert_eq(GameTheme.accent, UiColours.ACCENTS[UiColours.Pick.size() - 1])
	GameTheme.use_colour(-3 as UiColours.Pick)
	assert_eq(GameTheme.accent, UiColours.ACCENTS[0])


func test_clicking_a_swatch_sets_the_setting_applies_it_and_asks_for_a_restyle() -> void:
	var screen := _screen()
	await wait_process_frames(2)
	screen.show_display_colour()
	await wait_process_frames(2)
	watch_signals(screen)
	var swatches := screen._display_page.ui_colour()
	await _click(swatches.button(UiColours.Pick.RED))
	assert_eq(screen.settings.ui_colour, UiColours.Pick.RED)
	assert_eq(GameTheme.accent, UiColours.ACCENTS[UiColours.Pick.RED])
	assert_signal_emitted(screen, "restyled")
	assert_signal_emit_count(screen, "restyled", 1)


func test_picking_the_colour_already_in_use_does_not_restyle() -> void:
	var screen := _screen()
	await wait_process_frames(2)
	screen.show_display_colour()
	await wait_process_frames(2)
	watch_signals(screen)
	screen._display_page.ui_colour().button(UiColours.Pick.BLUE).pressed.emit()
	assert_signal_not_emitted(screen, "restyled")


func test_the_pause_menus_restyle_dresses_resume_in_the_new_colour_and_rebuilds_its_settings() -> void:
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child_autofree(host)
	var menu := PauseMenu.new()
	host.add_child(menu)
	menu.open()
	menu.open_settings()
	await wait_process_frames(2)
	var old_screen := menu._screen
	GameTheme.use_colour(UiColours.Pick.PINK)
	menu.restyle()
	var plate := menu._resume.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(plate.bg_color, UiColours.ACCENTS[UiColours.Pick.PINK], "Resume re-dressed at once")
	assert_eq(menu._resume.get_theme_color("font_color"), UiColours.INKS[UiColours.Pick.PINK])
	await wait_process_frames(3)
	assert_not_null(menu._screen, "settings are open again")
	assert_ne(menu._screen, old_screen, "a new screen")
	assert_true(not is_instance_valid(old_screen) or old_screen.is_queued_for_deletion(), "the old one goes")
	assert_eq(menu._resume.focus_mode, Control.FOCUS_NONE, "Resume stays out of the focus ring under the settings")
	menu._screen.close()
	await wait_process_frames(2)
	assert_null(menu._screen)


func test_repeated_pause_restyles_leave_no_extra_settings_screens() -> void:
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child_autofree(host)
	var menu := PauseMenu.new()
	host.add_child(menu)
	menu.open()
	menu.open_settings()
	await wait_process_frames(2)
	for pick: UiColours.Pick in [UiColours.Pick.RED, UiColours.Pick.GREEN, UiColours.Pick.BLUE]:
		GameTheme.use_colour(pick)
		menu.restyle()
		await wait_process_frames(3)
	var screens := 0
	for c in menu.get_children():
		if c is SettingsScreen and not c.is_queued_for_deletion():
			screens += 1
	assert_eq(screens, 1, "one live settings screen")
	assert_eq(menu._screen.restyled.get_connections().size(), 1, "restyled connected once")


func test_main_rebuilds_the_menus_once_per_restyle_without_leaking_nodes() -> void:
	var main: Node = add_child_autofree(load("res://game/main.tscn").instantiate())
	await wait_process_frames(3)
	main._open_settings()
	await wait_process_frames(3)
	var screen: SettingsScreen = main._settings_screen
	screen.show_display_colour()
	await wait_process_frames(2)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for pick: UiColours.Pick in [UiColours.Pick.RED, UiColours.Pick.GREEN, UiColours.Pick.BLUE]:
		main._settings_screen._display_page.ui_colour().button(pick).pressed.emit()
		await wait_process_frames(4)
		assert_eq(GameTheme.accent, UiColours.ACCENTS[pick])
		assert_not_null(main._settings_screen)
		assert_eq(main._settings_screen.restyled.get_connections().size(), 1, "one connection")
	await wait_process_frames(3)
	assert_almost_eq(float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), float(nodes), 40.0,
		"the old menus are freed, not kept beside the new")
	var owner_focus := get_viewport().gui_get_focus_owner()
	assert_not_null(owner_focus, "the keyboard is somewhere")
	if owner_focus != null:
		assert_true(main._settings_screen.is_ancestor_of(owner_focus), "on the new settings screen")
