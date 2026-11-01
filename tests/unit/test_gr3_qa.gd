extends GutTest
## QA's hunt for GR3 (window modes, F11 and Alt+Enter, the monitor, the frame-rate limit): the keys against a focused
## button and the real input order, a window the player moved, a saved monitor that is gone, the background rate with a
## limit changed behind, the Display tab's rows saving, connections and nodes left behind, and the physics steps a frame
## limit leaves room for.

const ROOT := "user://test-gr3-qa"

var ds: FakeScreens = null
var s: Settings = null
var path := ""
var _pressed := 0


func before_each() -> void:
	ds = FakeScreens.new()
	ds.sizes = [Vector2i(2560, 1440), Vector2i(1920, 1080)]
	ds.rates = [144.0, 60.0]
	SettingsApply.use_screens(ds)
	s = Settings.new(PlayTuning.new())
	s.window_mode = Settings.WindowMode.WINDOWED # F11 from a window; the first-start default is pinned in test_settings.gd
	s.vsync = true
	s.last_fullscreen = Settings.WindowMode.BORDERLESS
	DirAccess.make_dir_recursive_absolute(ROOT)
	path = ROOT.path_join("settings.save")
	SaveFile.remove(path)
	_pressed = 0


func after_each() -> void:
	SettingsApply.use_screens(null)
	Engine.max_fps = 0
	get_tree().paused = false


func after_all() -> void:
	SaveFile.remove(path)
	DirAccess.remove_absolute(ROOT)


func _key(code: Key, alt: bool = false, echo: bool = false, ctrl: bool = false, shift: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	e.alt_pressed = alt
	e.echo = echo
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	return e


func _watch() -> WindowWatch:
	var w := WindowWatch.new()
	w.settings = s
	w.save_path = path
	add_child_autofree(w)
	return w


func _screen() -> SettingsScreen:
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = path
	add_child_autofree(screen)
	screen.open()
	return screen


func _saved() -> Settings:
	var t := Settings.new(PlayTuning.new())
	t.load_file(path)
	return t


# --- the keys ---

func test_alt_enter_does_not_press_the_focused_button() -> void:
	_watch()
	var b := Button.new()
	b.pressed.connect(func() -> void: _pressed += 1)
	add_child_autofree(b)
	b.grab_focus()
	get_viewport().push_input(_key(KEY_ENTER, true))
	assert_eq(s.window_mode, Settings.WindowMode.BORDERLESS, "the watch took it")
	assert_eq(_pressed, 0, "and the focused button never saw Enter")
	get_viewport().push_input(_key(KEY_ENTER))
	assert_eq(s.window_mode, Settings.WindowMode.BORDERLESS, "a plain Enter is not a fullscreen key")


func test_modified_or_repeated_presses_never_switch_the_window() -> void:
	_watch()
	var presses: Array[InputEventKey] = [
		_key(KEY_F11, false, false, true), _key(KEY_F11, false, false, false, true), _key(KEY_F11, true),
		_key(KEY_F11, false, true), _key(KEY_ENTER, true, true), _key(KEY_ENTER, true, false, true),
		_key(KEY_ENTER, true, false, false, true)]
	for e in presses:
		get_viewport().push_input(e)
	assert_eq(s.window_mode, Settings.WindowMode.WINDOWED)
	assert_eq(ds.calls.size(), 0, "nothing was sent to the window")
	get_viewport().push_input(_key(KEY_F11))
	assert_eq(s.window_mode, Settings.WindowMode.BORDERLESS, "a clean press does")


func test_a_held_f11_switches_once_and_a_release_does_nothing() -> void:
	_watch()
	get_viewport().push_input(_key(KEY_F11))
	for i in 5:
		get_viewport().push_input(_key(KEY_F11, false, true))
	var up := _key(KEY_F11)
	up.pressed = false
	get_viewport().push_input(up)
	assert_eq(s.window_mode, Settings.WindowMode.BORDERLESS)


func test_f11_works_paused_and_unpaused_and_the_mouse_mode_is_left_alone() -> void:
	_watch()
	var was := Input.mouse_mode
	get_viewport().push_input(_key(KEY_F11))
	assert_eq(s.window_mode, Settings.WindowMode.BORDERLESS, "unpaused")
	assert_eq(Input.mouse_mode, was, "the watch doesn't change the mouse mode (the real capture is the owner's check)")
	get_tree().paused = true
	get_viewport().push_input(_key(KEY_F11))
	assert_eq(s.window_mode, Settings.WindowMode.WINDOWED, "paused")
	get_viewport().push_input(_key(KEY_ENTER, true))
	assert_eq(s.window_mode, Settings.WindowMode.BORDERLESS, "Alt+Enter paused")


# --- the monitor ---

func test_f11_goes_fullscreen_on_the_screen_the_window_is_on_now() -> void:
	s.monitor = 1
	SettingsApply.apply_display(s, true) # opened on the saved monitor
	ds.on = 0 # the player dragged the window to the other screen
	SettingsApply.toggle_fullscreen(s)
	assert_eq(ds.on, 0, "fullscreen where the window is, not thrown back to the saved monitor")
	SettingsApply.toggle_fullscreen(s)
	assert_eq(ds.on, 0, "and back to a window there")


func test_v_sync_does_not_throw_a_dragged_window_back_to_the_saved_monitor() -> void:
	s.monitor = 1
	SettingsApply.apply_display(s)
	ds.on = 0
	ds.calls.clear()
	s.vsync = false
	SettingsApply.apply_display(s)
	assert_eq(ds.on, 0, "a V-Sync change moves no window")


func test_a_monitor_beyond_the_screens_falls_back_and_is_kept_through_a_save() -> void:
	s.monitor = 7
	s.mark_changed()
	s.save(path)
	var t := _saved()
	assert_eq(t.monitor, 7)
	ds.primary_screen = 1
	SettingsApply.apply_display(t, true) # at start
	assert_eq(ds.on, 1, "the primary")
	assert_eq(SettingsApply.monitor_now(t), 1)
	assert_eq(t.monitor, 7, "kept")


func test_a_monitor_saved_out_of_range_reads_as_a_valid_index() -> void:
	for raw: Variant in [-9, 9999, 1.0e30, "two", null]:
		SaveFile.write(path, "settings", 1, {"monitor": raw})
		var t := _saved()
		assert_true(t.monitor >= Settings.MONITOR_HERE and t.monitor <= Settings.MONITOR_MOST, "monitor %s" % [raw])


func test_no_screens_at_all_changes_nothing() -> void:
	ds.sizes.clear()
	ds.rates.clear()
	s.monitor = 3
	ds.calls.clear()
	SettingsApply.apply_display(s)
	assert_eq(ds.calls.size(), 0)
	assert_eq(SettingsApply.monitor_now(s), -1)


func test_the_monitor_row_comes_and_goes_with_the_screens_and_leaves_no_buttons() -> void:
	var screen := _screen()
	var page := screen._display_page
	var row_children := page.monitor_row().get_child_count()
	for i in 4:
		ds.sizes.resize(1)
		ds.rates.resize(1)
		screen.open()
		assert_false(page.monitor_row().visible)
		ds.sizes = [Vector2i(2560, 1440), Vector2i(1920, 1080)]
		ds.rates = [144.0, 60.0]
		screen.open()
		assert_true(page.monitor_row().visible)
	assert_eq(page.monitor_row().get_child_count(), row_children, "one choice and no strays")


# --- the window mode and the rows saving ---

func test_the_mode_the_player_left_is_the_mode_the_next_start_opens_in() -> void:
	SettingsApply.pick_window_mode(s, Settings.WindowMode.EXCLUSIVE)
	s.mark_changed()
	s.save(path)
	ds.window_mode = DisplayServer.WINDOW_MODE_MAXIMIZED
	var t := _saved()
	SettingsApply.apply_all(t)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	SettingsApply.toggle_fullscreen(t)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_MAXIMIZED)
	SettingsApply.toggle_fullscreen(t)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, "F11 goes back to Exclusive")


func test_a_saved_window_last_fullscreen_still_lets_f11_go_fullscreen() -> void:
	SaveFile.write(path, "settings", 2, {"window_mode": 0, "last_fullscreen": 0})
	var t := _saved()
	SettingsApply.toggle_fullscreen(t)
	assert_ne(t.window_mode, Settings.WindowMode.WINDOWED, "a corrupt memory of 'windowed' doesn't dead-end F11")


func test_every_display_row_is_applied_and_saved() -> void:
	var screen := _screen()
	var page := screen._display_page
	page.window_choice().button(2).pressed.emit()
	assert_eq(_saved().window_mode, Settings.WindowMode.EXCLUSIVE)
	assert_eq(_saved().last_fullscreen, Settings.WindowMode.EXCLUSIVE)
	page.monitor_choice().button(1).pressed.emit()
	assert_eq(_saved().monitor, 1)
	page.vsync().button_pressed = false
	assert_false(_saved().vsync)
	assert_eq(ds.vsync_mode, DisplayServer.VSYNC_DISABLED)
	page.limit_choice().button(3).pressed.emit()
	assert_eq(_saved().frame_limit, 144)
	page.show_fps().button_pressed = true
	assert_true(_saved().show_fps)
	page.fov().value = 95.0
	screen._timer.stop()
	screen.close()
	assert_eq(_saved().fov, 95.0, "the moved Field of view row still saves")


# --- the frame-rate limit ---

func test_a_limit_changed_behind_applies_on_focus_and_a_lower_one_wins_behind() -> void:
	var w := _watch()
	s.frame_limit = 144
	SettingsApply.apply_display(s)
	w.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	s.frame_limit = Settings.UNLIMITED
	SettingsApply.apply_frame_rate(s)
	assert_eq(Engine.max_fps, 30, "unlimited behind is the background rate")
	s.frame_limit = 60
	SettingsApply.apply_frame_rate(s)
	assert_eq(Engine.max_fps, 30)
	w.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_eq(Engine.max_fps, 60, "the limit set behind, on focus")
	s.frame_limit = Settings.UNLIMITED
	SettingsApply.apply_frame_rate(s)
	assert_eq(Engine.max_fps, 0)


func test_minimise_then_restore_with_the_window_events_alone() -> void:
	var w := _watch()
	s.frame_limit = Settings.UNLIMITED
	w.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	w.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_eq(Engine.max_fps, 30)
	w.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	assert_eq(Engine.max_fps, 0, "twice out, once in: back in front")


func test_every_limit_leaves_the_physics_steps_to_catch_up_to_60_a_second() -> void:
	var worst := ds.config.background_fps
	for l in Settings.FRAME_LIMITS:
		worst = mini(worst, l)
	var per_frame := ceili(float(Engine.physics_ticks_per_second) / float(worst))
	assert_eq(Engine.physics_ticks_per_second, 60)
	assert_lte(per_frame, Engine.max_physics_steps_per_frame, "a frame at the slowest limit runs the ticks it owes")


# --- what is left behind ---

func test_the_settings_screen_opened_and_freed_again_leaves_no_connection_or_node() -> void:
	var before := s.changed.get_connections().size()
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 6:
		var screen := SettingsScreen.new()
		screen.settings = s
		screen.save_path = path
		add_child(screen)
		screen.open()
		screen.close()
		screen.open()
		remove_child(screen)
		add_child(screen)
		screen.free()
	assert_eq(s.changed.get_connections().size(), before)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)


func test_a_freed_watch_stops_listening() -> void:
	var w := WindowWatch.new()
	w.settings = s
	w.save_path = path
	add_child(w)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	w.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes - 1)
	get_viewport().push_input(_key(KEY_F11))
	assert_eq(s.window_mode, Settings.WindowMode.WINDOWED)


func test_the_display_words_exist_in_the_catalogue() -> void:
	for k: String in ["SETTINGS_WINDOW", "SETTINGS_WINDOW_MODE", "SETTINGS_WINDOWED", "SETTINGS_BORDERLESS",
			"SETTINGS_EXCLUSIVE", "SETTINGS_KEYS_OR", "SETTINGS_KEYS_LINE", "SETTINGS_MONITOR",
			"SETTINGS_MONITOR_HELP", "SETTINGS_MONITOR_LINE", "SETTINGS_MONITOR_LINE_NO_RATE", "SETTINGS_FRAME_RATE",
			"SETTINGS_VSYNC", "SETTINGS_VSYNC_HELP", "SETTINGS_VSYNC_HELP_NO_RATE", "SETTINGS_FRAME_LIMIT",
			"SETTINGS_FRAME_LIMIT_HELP", "SETTINGS_VIEW", "SETTINGS_FOV", "SETTINGS_SHOW_FPS",
			"SETTINGS_SHOW_FPS_HELP"]:
		assert_ne(tr(k), k, k)
