extends GutTest
## SettingsApply's window and frame rate (Settings › Display), against FakeScreens: the window onto the saved monitor or
## the primary, the modes and F11's way back, leaving fullscreen maximised on the same monitor, V-Sync, Engine.max_fps
## and the background limit; WindowWatch's keys and focus; and the simulation's 60 ticks a second at a 30 limit.

const ROOT := "user://test-settings-apply"
## How long the tick count runs (s), by the clock, and how far from 60 a second it may be (the headless runner's own
## jitter).
const TICK_RUN := 2.0
const TICK_SLACK := 0.1

var ds: FakeScreens = null
var s: Settings = null
var path := ""


func before_each() -> void:
	ds = FakeScreens.new()
	SettingsApply.use_screens(ds)
	s = Settings.new(PlayTuning.new())
	# these walk the window modes from a window with V-Sync on; the first-start defaults are pinned in test_settings.gd
	s.window_mode = Settings.WindowMode.WINDOWED
	s.vsync = true
	s.last_fullscreen = Settings.WindowMode.BORDERLESS
	DirAccess.make_dir_recursive_absolute(ROOT)
	path = ROOT.path_join("settings.save")
	SaveFile.remove(path)


func after_each() -> void:
	SettingsApply.use_screens(null)
	Engine.max_fps = 0


func after_all() -> void:
	SaveFile.remove(path)
	DirAccess.remove_absolute(ROOT)


func _key(code: Key, alt: bool = false, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	e.alt_pressed = alt
	e.echo = echo
	return e


func _watch() -> WindowWatch:
	var w := WindowWatch.new()
	w.settings = s
	w.save_path = path
	add_child_autofree(w)
	return w


# --- the frame rate ---

func test_the_limit_is_engine_max_fps_and_unlimited_is_none() -> void:
	for limit: int in [Settings.FRAME_LIMIT_RANGE.x, 75, 144, 239, Settings.FRAME_LIMIT_RANGE.y]:
		s.frame_limit = limit
		SettingsApply.apply_display(s)
		assert_eq(Engine.max_fps, limit)
	s.frame_limit = Settings.UNLIMITED
	SettingsApply.apply_display(s)
	assert_eq(Engine.max_fps, 0, "Unlimited")


func test_the_menus_draw_at_most_the_refresh_rate_and_a_match_the_players_limit() -> void:
	s.frame_limit = Settings.UNLIMITED
	SettingsApply.set_menus(s, true)
	assert_eq(Engine.max_fps, 144, "Unlimited in the menus: the screen's rate (V-Sync is off by default)")
	s.frame_limit = 60
	SettingsApply.apply_frame_rate(s)
	assert_eq(Engine.max_fps, 60, "a lower limit of the player's wins")
	s.frame_limit = 240
	SettingsApply.apply_frame_rate(s)
	assert_eq(Engine.max_fps, 144, "a higher one is held to the rate in the menus")
	s.frame_limit = Settings.UNLIMITED
	SettingsApply.set_menus(s, false)
	assert_eq(Engine.max_fps, 0, "a match: the player's Unlimited")
	s.frame_limit = 240
	SettingsApply.apply_frame_rate(s)
	assert_eq(Engine.max_fps, 240)


func test_the_menu_cap_falls_back_when_the_display_says_no_rate_and_is_off_without_a_screen() -> void:
	s.frame_limit = Settings.UNLIMITED
	ds.rates[0] = -1.0
	SettingsApply.set_menus(s, true)
	assert_eq(Engine.max_fps, ds.config.menu_fallback_fps, "no rate given")
	assert_eq(ds.config.menu_fallback_fps, 60)
	ds.rates[0] = 0.0
	SettingsApply.apply_frame_rate(s)
	assert_eq(Engine.max_fps, 60, "a rate of 0 is no rate")
	ds.sizes.clear()
	SettingsApply.apply_frame_rate(s)
	assert_eq(Engine.max_fps, 0, "no screens (headless): no cap")
	ds.sizes.append(Vector2i(2560, 1440))
	ds.config.menu_cap_to_refresh = false
	SettingsApply.apply_frame_rate(s)
	assert_eq(Engine.max_fps, 0, "the cap switched off in the config")


func test_the_menu_cap_and_the_background_rate_both_apply() -> void:
	s.frame_limit = Settings.UNLIMITED
	SettingsApply.set_menus(s, true)
	SettingsApply.set_focused(s, false)
	assert_eq(Engine.max_fps, ds.config.background_fps, "the lower of the two")
	SettingsApply.set_focused(s, true)
	assert_eq(Engine.max_fps, 144)


func test_f11_from_a_window_goes_back_to_the_first_starts_fullscreen() -> void:
	s = Settings.new(PlayTuning.new())
	assert_eq(s.window_mode, Settings.WindowMode.EXCLUSIVE)
	SettingsApply.pick_window_mode(s, Settings.WindowMode.WINDOWED)
	SettingsApply.toggle_fullscreen(s)
	assert_eq(s.window_mode, Settings.WindowMode.EXCLUSIVE, "not Borderless")
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func test_in_the_background_it_draws_the_background_rate_and_back_on_focus() -> void:
	var background := ds.config.background_fps
	assert_eq(background, 30, "the plan's default")
	s.frame_limit = Settings.UNLIMITED
	SettingsApply.set_focused(s, false)
	assert_eq(Engine.max_fps, background, "Unlimited draws 30 behind")
	s.frame_limit = 144
	SettingsApply.apply_display(s)
	assert_eq(Engine.max_fps, background, "a change made behind keeps the background rate")
	SettingsApply.set_focused(s, true)
	assert_eq(Engine.max_fps, 144, "the limit again in front")
	s.frame_limit = 30
	SettingsApply.set_focused(s, false)
	assert_eq(Engine.max_fps, 30, "a limit lower than the background one wins")


func test_the_watch_follows_focus_out_and_in() -> void:
	var w := _watch()
	s.frame_limit = 120
	SettingsApply.apply_display(s)
	w.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(Engine.max_fps, ds.config.background_fps, "unfocused or minimised")
	w.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_eq(Engine.max_fps, 120)
	w.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_eq(Engine.max_fps, ds.config.background_fps, "the window's own focus too")
	w.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	assert_eq(Engine.max_fps, 120)


func test_the_simulation_ticks_60_a_second_at_a_30_limit() -> void:
	var ticks := TickCounter.new()
	add_child_autofree(ticks)
	s.frame_limit = 30
	SettingsApply.apply_display(s)
	assert_eq(Engine.max_fps, 30)
	await wait_physics_frames(2)
	ticks.reset()
	# timed by the clock, not by frames
	while ticks.elapsed() < TICK_RUN:
		await get_tree().process_frame
	var fps := ticks.frames / ticks.elapsed()
	# A slow runner only lowers the frames and raises the ticks a frame, so neither bound can flake that way (critic).
	var per_frame := float(Engine.physics_ticks_per_second) / 30.0
	assert_gte(float(ticks.ticks) / maxf(1.0, float(ticks.frames)), per_frame * (1.0 - TICK_SLACK),
			"%d ticks in %d frames: the 60 a second kept" % [ticks.ticks, ticks.frames])
	assert_lt(fps, 30.0 * (1.0 + TICK_SLACK), "%d frames: the limit held" % ticks.frames)


# --- the window ---

func test_window_modes_and_v_sync_go_to_the_display_server() -> void:
	SettingsApply.pick_window_mode(s, Settings.WindowMode.BORDERLESS)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_eq(s.last_fullscreen, Settings.WindowMode.BORDERLESS)
	SettingsApply.pick_window_mode(s, Settings.WindowMode.EXCLUSIVE)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	assert_eq(s.last_fullscreen, Settings.WindowMode.EXCLUSIVE, "F11 goes back to Exclusive now")
	SettingsApply.pick_window_mode(s, Settings.WindowMode.WINDOWED)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_MAXIMIZED, "the maximised window the game starts in")
	assert_eq(s.last_fullscreen, Settings.WindowMode.EXCLUSIVE)
	s.vsync = false
	SettingsApply.apply_display(s)
	assert_eq(ds.vsync_mode, DisplayServer.VSYNC_DISABLED)
	ds.calls.clear()
	SettingsApply.apply_display(s)
	assert_eq(ds.calls.size(), 0, "nothing sent when nothing changed")


func test_windowed_leaves_a_window_the_player_sized_alone() -> void:
	ds.window_mode = DisplayServer.WINDOW_MODE_WINDOWED
	SettingsApply.apply_display(s)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_WINDOWED)
	assert_eq(ds.calls.size(), 0)


func test_the_toggle_goes_between_a_window_and_the_last_fullscreen() -> void:
	SettingsApply.toggle_fullscreen(s)
	assert_eq(s.window_mode, Settings.WindowMode.BORDERLESS, "Borderless by default")
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_FULLSCREEN)
	SettingsApply.toggle_fullscreen(s)
	assert_eq(s.window_mode, Settings.WindowMode.WINDOWED)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_MAXIMIZED)
	s.window_mode = Settings.WindowMode.EXCLUSIVE # an older save: Exclusive with Borderless remembered
	SettingsApply.apply_display(s)
	SettingsApply.toggle_fullscreen(s)
	SettingsApply.toggle_fullscreen(s)
	assert_eq(s.window_mode, Settings.WindowMode.EXCLUSIVE, "back to the fullscreen it left")


func test_leaving_fullscreen_stays_on_the_same_monitor() -> void:
	_two_screens()
	ds.on = 1
	ds.window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	ds.leave_to = 0 # the system puts the window back where it was before fullscreen
	s.window_mode = Settings.WindowMode.BORDERLESS
	SettingsApply.toggle_fullscreen(s)
	assert_eq(ds.on, 1, "on the monitor it was fullscreen on")
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_MAXIMIZED, "and maximised there")


func test_the_window_opens_on_the_saved_monitor() -> void:
	_two_screens()
	s.monitor = 1
	SettingsApply.apply_display(s, true) # at start
	assert_eq(ds.on, 1)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_MAXIMIZED, "maximised on it")
	assert_eq(Array(ds.calls), ["mode %d" % DisplayServer.WINDOW_MODE_WINDOWED, "screen 1",
			"mode %d" % DisplayServer.WINDOW_MODE_MAXIMIZED], "let down, moved, maximised again")
	ds.calls.clear()
	SettingsApply.apply_display(s, true)
	assert_eq(ds.calls.size(), 0, "already there")


func test_a_fullscreen_window_moves_straight_to_the_picked_monitor() -> void:
	_two_screens()
	SettingsApply.pick_window_mode(s, Settings.WindowMode.EXCLUSIVE)
	ds.calls.clear()
	SettingsApply.pick_monitor(s, 1)
	assert_eq(s.monitor, 1)
	assert_eq(Array(ds.calls), ["screen 1"])
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func test_a_saved_monitor_that_is_gone_falls_back_to_the_primary() -> void:
	_two_screens()
	ds.primary_screen = 1
	s.monitor = 4
	SettingsApply.apply_display(s, true)
	assert_eq(ds.on, 1, "the primary, never off-screen")
	assert_eq(s.monitor, 4, "kept, for when it is plugged in again")


func test_no_monitor_saved_or_no_screens_leaves_the_window_where_it_is() -> void:
	_two_screens()
	ds.on = 1
	SettingsApply.apply_display(s)
	assert_eq(ds.on, 1, "MONITOR_HERE")
	ds.sizes.clear()
	ds.rates.clear()
	s.monitor = 0
	SettingsApply.apply_display(s)
	assert_eq(ds.on, 1, "headless: no screens to ask")
	assert_eq(SettingsApply.monitor_now(s, ds), -1)


# --- the keys ---

func test_f11_and_alt_enter_switch_and_save() -> void:
	_watch()
	get_viewport().push_input(_key(KEY_F11))
	assert_eq(s.window_mode, Settings.WindowMode.BORDERLESS)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_FULLSCREEN)
	var saved := Settings.new(PlayTuning.new())
	saved.load_file(path)
	assert_eq(saved.window_mode, Settings.WindowMode.BORDERLESS, "saved at once")
	get_viewport().push_input(_key(KEY_ENTER, true))
	assert_eq(s.window_mode, Settings.WindowMode.WINDOWED, "Alt+Enter")
	saved.load_file(path)
	assert_eq(saved.window_mode, Settings.WindowMode.WINDOWED)
	get_viewport().push_input(_key(KEY_KP_ENTER, true))
	assert_eq(s.window_mode, Settings.WindowMode.BORDERLESS, "the keypad's Enter too")


func test_other_presses_do_not_switch() -> void:
	_watch()
	get_viewport().push_input(_key(KEY_ENTER))
	get_viewport().push_input(_key(KEY_F11, false, true))
	get_viewport().push_input(_key(KEY_F11, true))
	var ctrl := _key(KEY_F11)
	ctrl.ctrl_pressed = true
	get_viewport().push_input(ctrl)
	var up := _key(KEY_F11)
	up.pressed = false
	get_viewport().push_input(up)
	assert_eq(s.window_mode, Settings.WindowMode.WINDOWED, "Enter alone, a held F11's repeat, Alt+F11, Ctrl+F11, F11 up")
	assert_false(FileAccess.file_exists(path))


func test_the_keys_work_while_the_game_is_paused() -> void:
	_watch()
	get_tree().paused = true
	get_viewport().push_input(_key(KEY_F11))
	get_tree().paused = false
	assert_eq(s.window_mode, Settings.WindowMode.BORDERLESS, "from the pause menu")


func _two_screens() -> void:
	ds.sizes = [Vector2i(2560, 1440), Vector2i(1920, 1080)]
	ds.rates = [144.0, 60.0]


## Counts physics ticks and drawn frames from `reset`; the tick rate between the first tick and the last, so a
## frame's ticks at either end don't count against it.
class TickCounter:
	extends Node
	var ticks: int = 0
	var frames: int = 0
	var _from: int = 0
	var _first_tick: int = 0
	var _last_tick: int = 0

	func reset() -> void:
		ticks = 0
		frames = 0
		_from = Time.get_ticks_usec()

	func elapsed() -> float:
		return (Time.get_ticks_usec() - _from) / 1e6

	func tick_rate() -> float:
		return (ticks - 1) / ((_last_tick - _first_tick) / 1e6)

	func _physics_process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		if ticks == 0:
			_first_tick = now
		_last_tick = now
		ticks += 1

	func _process(_delta: float) -> void:
		frames += 1
