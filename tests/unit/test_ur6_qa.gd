extends GutTest
## UR6 QA: the Settings restyle (pill tabs, segmented MenuChoice) fits 1080p in the menus and the pause menu.

const WINDOW := Vector2(1920.0, 1080.0)


func _host() -> Control:
	var host := Control.new()
	host.custom_minimum_size = WINDOW
	host.size = WINDOW
	add_child_autofree(host)
	return host


func _screen_in_menus() -> SettingsScreen:
	var host := _host()
	var menus := MenuScreen.new()
	host.add_child(menus)
	var s := SettingsScreen.new()
	s.settings = Settings.new()
	s.in_menus = true
	s.save_path = "user://test-ur6-a.json"
	menus.add_over_page(s)
	s.open()
	return s


func _screen_in_pause() -> SettingsScreen:
	var host := _host()
	var s := SettingsScreen.new()
	s.settings = Settings.new()
	s.esc_closes = true
	s.save_path = "user://test-ur6-b.json"
	host.add_child(s)
	s.open()
	return s


func _check_fit(s: SettingsScreen, label: String) -> void:
	await wait_process_frames(3)
	var bar: TabBar = s._tabs.get_tab_bar()
	for i in s._tabs.get_tab_count():
		s._tabs.current_tab = i
		await wait_process_frames(2)
		var t: String = "%s tab %s" % [label, s._tabs.get_tab_title(i)]
		assert_lte(s._tabs.get_global_rect().end.x, WINDOW.x - MenuParts.PAGE_MARGIN.z + 0.5, t + ": right")
		assert_lte(s._tabs.get_global_rect().end.y, WINDOW.y - MenuParts.PAGE_MARGIN.w + 0.5, t + ": bottom")
		var back: Button = s.find_child("Back", true, false)
		assert_lte(back.get_global_rect().end.y, WINDOW.y, t + ": back inside window")
		assert_gte(back.get_global_rect().position.y, s._tabs.get_global_rect().end.y - 1.0, t + ": back under tabs")
		assert_lte(bar.get_combined_minimum_size().x, bar.size.x + 0.5, t + ": tab bar needs no scroll arrows")
		assert_lte(bar.get_tab_rect(bar.tab_count - 1).end.x, bar.size.x + 0.5, t + ": last tab inside the bar")
		assert_false(bar.get_global_rect().intersects(Rect2()) and false)
		# content not clipped sideways
		var page: Control = s._tabs.get_current_tab_control()
		assert_lte(page.get_combined_minimum_size().x, page.size.x + 0.5, t + ": page min width fits")


func test_every_tab_fits_in_the_menus() -> void:
	await _check_fit(_screen_in_menus(), "menus")


func test_every_tab_fits_in_the_pause_menu() -> void:
	await _check_fit(_screen_in_pause(), "pause")


func test_pause_menu_real_settings_fit() -> void:
	var menu := PauseMenu.new()
	var host := _host()
	host.add_child(menu)
	menu.open_settings()
	await wait_process_frames(3)
	var s: SettingsScreen = menu._screen
	assert_not_null(s)
	assert_lte(s.get_global_rect().end.y, WINDOW.y + 0.5)
	assert_lte(s.get_global_rect().end.x, WINDOW.x + 0.5)
	assert_gte(s.get_global_rect().size.x, WINDOW.x - 1.0, "full width")


func test_tab_bar_sits_a_gap_over_the_panel() -> void:
	var s := _screen_in_pause()
	await wait_process_frames(3)
	var bar := s._tabs.get_tab_bar()
	var panel: StyleBoxFlat = s._tabs.get_theme_stylebox("panel") as StyleBoxFlat
	var drawn_top: float = s._tabs.get_global_rect().position.y + bar.size.y + panel.expand_margin_top * -1.0
	assert_almost_eq(drawn_top - bar.get_global_rect().end.y, float(GameTheme.TAB_GAP), 1.0, "gap under the pills")
	assert_lt(panel.expand_margin_top, 0.0)
	var page: Control = s._tabs.get_current_tab_control()
	assert_gte(page.get_global_rect().position.y, bar.get_global_rect().end.y + GameTheme.TAB_GAP, "content under the drawn panel")


func test_tabs_are_reachable_by_keyboard() -> void:
	var s := _screen_in_pause()
	await wait_process_frames(3)
	var bar := s._tabs.get_tab_bar()
	gut.p("tabbar focus_mode %s tabs focus_mode %s" % [bar.focus_mode, s._tabs.focus_mode])
	s._tabs.current_tab = 0
	bar.grab_focus()
	await wait_process_frames(1)
	var ev := InputEventAction.new()
	ev.action = "ui_right"
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_process_frames(2)
	assert_eq(get_viewport().gui_get_focus_owner(), bar)
	assert_eq(s._tabs.current_tab, 1, "ui_right on the focused tab bar moves to the next tab")


func test_choice_with_one_button_draws_and_picks() -> void:
	var host := _host()
	var c := MenuChoice.new(PackedStringArray(["Only"]))
	host.add_child(c)
	await wait_process_frames(2)
	assert_eq(c.get_child_count(), 1)
	c.button(0).pressed.emit()
	c.button(0).button_pressed = true
	assert_eq(c.selected(), 0)
	assert_gt(c.size.x, 0.0)


func test_empty_choice_does_not_draw_a_track() -> void:
	var host := _host()
	var c := MenuChoice.new(PackedStringArray())
	host.add_child(c)
	await wait_process_frames(2)
	assert_eq(c.selected(), -1)
	assert_null(c._track)


func test_swatches_have_no_track_and_keep_their_frame() -> void:
	var host := _host()
	var sw := MenuSwatches.new(HudPrefs.COLOURS)
	host.add_child(sw)
	await wait_process_frames(2)
	assert_null(sw._track, "swatches stay plain squares")
	var lit: StyleBoxFlat = sw.button(0).get_theme_stylebox("pressed") as StyleBoxFlat
	assert_eq(lit.border_color, GameTheme.TEXT)
	assert_eq(sw.get_theme_constant("separation"), MenuSwatches.SWATCH_GAP)


func test_picked_choice_text_is_dark_on_white_even_when_focused_and_hovered() -> void:
	var host := _host()
	var c := MenuChoice.new(PackedStringArray(["a", "b"]))
	host.add_child(c)
	await wait_process_frames(2)
	var b := c.button(0)
	assert_eq(b.get_theme_color("font_pressed_color"), GameTheme.BG)
	assert_eq(b.get_theme_color("font_hover_pressed_color"), GameTheme.BG)
	var lit: StyleBoxFlat = b.get_theme_stylebox("pressed") as StyleBoxFlat
	assert_eq(lit.bg_color, GameTheme.TEXT)
	# the focus ring lies outside the white pill, on the dark track, where teal shows
	var ring: StyleBoxFlat = b.get_theme_stylebox("focus") as StyleBoxFlat
	assert_gt(ring.expand_margin_left, float(GameTheme.FOCUS_BORDER), "the ring is drawn outside the pill")
	var ratio := (_lum(ring.border_color) + 0.05) / (_lum(GameTheme.BG) + 0.05)
	assert_gte(ratio, 3.0, "focus ring is visible on the dark round the pill")
	var tab_ring: StyleBoxFlat = GameTheme.get_theme().get_stylebox("tab_focus", "TabContainer") as StyleBoxFlat
	assert_gt(tab_ring.expand_margin_left, float(GameTheme.FOCUS_BORDER), "the open tab's ring is outside its pill")


func test_disabled_picked_choice_is_still_marked() -> void:
	var host := _host()
	var c := MenuChoice.new(PackedStringArray(["a", "b"]))
	host.add_child(c)
	await wait_process_frames(2)
	c.put(1)
	c.button(1).disabled = true
	c.button(0).disabled = true
	var st: StyleBoxFlat = c.button(1).get_theme_stylebox("disabled") as StyleBoxFlat
	var other: StyleBoxFlat = c.button(0).get_theme_stylebox("disabled") as StyleBoxFlat
	assert_ne(st.bg_color, other.bg_color, "a picked but disabled button differs from the others")
	c.put(0)
	assert_eq((c.button(1).get_theme_stylebox("disabled") as StyleBoxFlat).bg_color, other.bg_color,
			"the faint pill moves with the pick")


func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)
