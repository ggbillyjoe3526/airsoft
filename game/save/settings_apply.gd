class_name SettingsApply
## Puts Settings into the game, each group on its own so a slider only does its own work: the mouse and the camera (the
## PlayTuning that PlayerInput and the view read live), the audio buses' volumes, the window (its monitor and mode),
## V-Sync and the frame-rate limit, the graphics (GraphicsApply, on the root viewport), the key bindings (the
## InputMap) and the interface's colour (GameTheme). Nothing is cached, so the change shows at once. The window goes through `screens()`, which a test swaps
## for a stand-in: the headless display server has no screens and never changes mode.

## Silence: the bus is muted at a volume of 0 rather than set to minus infinity.
const MUTE_DB := -80.0

static var _screens: Screens = null


static func apply_all(s: Settings) -> void:
	apply_controls(s)
	apply_audio(s)
	apply_display(s, true)
	apply_graphics(s)
	apply_bindings(s)
	apply_ui_colour(s)
	apply_tooltips(s)
	s.changed.emit()


## The mouse (hip and aimed sensitivity, invert, the crouch and aim toggles, the order wheel's Hover or Click) and the
## field of view.
static func apply_controls(s: Settings) -> void:
	var c := s.tuning.controls
	c.sensitivity = s.sensitivity
	c.aim_sensitivity = s.aim_sensitivity
	c.invert_y = s.invert_y
	c.crouch_toggle = s.crouch_toggle
	c.aim_toggle = s.aim_toggle
	c.auto_reload = s.auto_reload
	c.wheel_pick = s.wheel_pick
	s.tuning.view.horizontal_fov_16x9 = s.fov


## Whether tooltips show (Settings › Display › Interface; TooltipWrap).
static func apply_tooltips(s: Settings) -> void:
	TooltipWrap.enabled = s.tooltips


## The interface's colour (UA2): GameTheme's accent and the shared Theme. Whether it changed (the menus are then built
## again, Main.restyle, as a page keeps the colours it was built with).
static func apply_ui_colour(s: Settings) -> bool:
	return GameTheme.use_colour(s.ui_colour)


## Each bus's volume from its share, times its gain (Settings.VOLUME_GAINS).
static func apply_audio(s: Settings) -> void:
	for bus: StringName in Settings.VOLUME_BUSES:
		var i := AudioServer.get_bus_index(bus)
		if i < 0:
			push_warning("settings: no audio bus %s" % bus)
			continue
		var v: float = s.volumes[bus]
		var gain: float = Settings.VOLUME_GAINS.get(bus, 1.0)
		AudioServer.set_bus_mute(i, v <= 0.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(v * gain) if v > 0.0 else MUTE_DB)


## The window and the frame rate: with `place` (at start, and on picking a Monitor) the window onto the saved monitor
## (the primary when that one is gone, so never off-screen); then its mode, V-Sync and Engine.max_fps. Without it the
## window stays on the screen it was dragged to (QA). Windowed leaves a windowed (or maximised) window alone, and
## leaving fullscreen gives the maximised window the game starts in, on the monitor it was on.
static func apply_display(s: Settings, place: bool = false) -> void:
	var ds := screens()
	if place:
		_place(s, ds)
	var now := ds.mode()
	match s.window_mode:
		Settings.WindowMode.BORDERLESS:
			if now != DisplayServer.WINDOW_MODE_FULLSCREEN:
				ds.set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		Settings.WindowMode.EXCLUSIVE:
			if now != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				ds.set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			if now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				var at := ds.current()
				ds.set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
				if at >= 0 and ds.current() != at:
					_move(ds, at)
	var want := DisplayServer.VSYNC_ENABLED if s.vsync else DisplayServer.VSYNC_DISABLED
	if ds.vsync() != want:
		ds.set_vsync(want)
	apply_frame_rate(s)


## Engine.max_fps: the frame-rate limit (or the menus' refresh-rate cap, `menu_cap`, when lower), or DisplayConfig.background_fps (the lower of the two) while the game is in the
## background. The simulation's 60 ticks a second don't depend on it: a slower frame runs more ticks.
static func apply_frame_rate(s: Settings) -> void:
	var ds := screens()
	var limit := s.frame_limit
	var cap := menu_cap(ds)
	if cap > 0:
		limit = cap if limit == Settings.UNLIMITED else mini(limit, cap)
	if not ds.focused:
		var background := ds.config.background_fps
		limit = background if limit == Settings.UNLIMITED else mini(limit, background)
	if Engine.max_fps != limit:
		Engine.max_fps = limit


## The most frames a second the title, the menus and the loading screen draw (`ds.menus`): the display's refresh rate
## (DisplayConfig.menu_fallback_fps when it doesn't say), so a light scene never runs uncapped with V-Sync off; 0 for
## none: in a match, with no screen (headless) or with the cap off.
static func menu_cap(ds: Screens) -> int:
	if not ds.menus or not ds.config.menu_cap_to_refresh or ds.count() <= 0:
		return 0
	var hz := ds.rate(ds.current())
	return roundi(hz) if hz > 0.0 else ds.config.menu_fallback_fps


## The title and the menus are showing (`menus`, main.gd) or a match is loaded: the frame rate follows.
static func set_menus(s: Settings, menus: bool) -> void:
	screens().menus = menus
	apply_frame_rate(s)


## The game came to the front (`focused`) or went to the background (unfocused or minimised): WindowWatch.
static func set_focused(s: Settings, focused: bool) -> void:
	screens().focused = focused
	apply_frame_rate(s)


## Settings › Display's Window mode: `mode`, remembered as the one F11 goes back to when it is a fullscreen one.
static func pick_window_mode(s: Settings, mode: Settings.WindowMode) -> void:
	s.window_mode = mode
	if mode != Settings.WindowMode.WINDOWED:
		s.last_fullscreen = mode
	apply_display(s)


## F11 or Alt+Enter: a window from fullscreen, or the last fullscreen mode from a window.
static func toggle_fullscreen(s: Settings) -> void:
	if s.window_mode == Settings.WindowMode.WINDOWED:
		pick_window_mode(s, s.last_fullscreen)
		return
	s.last_fullscreen = s.window_mode
	pick_window_mode(s, Settings.WindowMode.WINDOWED)


## Settings › Display's Monitor: the window moves to screen `screen` and opens there from now on.
static func pick_monitor(s: Settings, screen: int) -> void:
	s.monitor = screen
	apply_display(s, true)


## The screen the saved monitor names now: itself, the primary when it is gone, or -1 to leave the window where it is
## (no monitor saved, or no screens to ask, as headless).
static func monitor_now(s: Settings, ds: Screens = null) -> int:
	if ds == null:
		ds = screens()
	var count := ds.count()
	if s.monitor == Settings.MONITOR_HERE or count <= 0:
		return -1
	return s.monitor if s.monitor < count else ds.primary()


## The game's window calls, or the stand-in a test gave.
static func screens() -> Screens:
	if _screens == null:
		_screens = Screens.new()
	return _screens


## A test's stand-in for the window calls; null goes back to the real ones.
static func use_screens(stand_in: Screens) -> void:
	_screens = stand_in


static func _place(s: Settings, ds: Screens) -> void:
	var target := monitor_now(s, ds)
	if target >= 0 and ds.current() != target:
		_move(ds, target)


## Onto screen `target`: a maximised window is let down, moved and maximised again, so it fills the new screen.
static func _move(ds: Screens, target: int) -> void:
	if ds.mode() != DisplayServer.WINDOW_MODE_MAXIMIZED:
		ds.set_current(target)
		return
	ds.set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	ds.set_current(target)
	ds.set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


## The graphics values in force onto the root viewport and, through GraphicsApply's `applied`, the match: only when
## they differ from those drawn.
static func apply_graphics(s: Settings) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		GraphicsApply.apply_settings(s, tree.root)


## The key bindings into the InputMap.
static func apply_bindings(s: Settings) -> void:
	s.bindings.apply()


## The window's DisplayServer calls, one each, so a test can stand in for them; whether the game is in front
## (`set_focused`); and the display config.
class Screens:
	extends RefCounted
	## False while the window is unfocused or minimised.
	var focused: bool = true
	## True while the title, the menus or the loading screen show (main.gd sets it): they draw at most the refresh rate.
	var menus: bool = false
	var config: DisplayConfig = DisplayConfig.new()

	func mode() -> DisplayServer.WindowMode:
		return DisplayServer.window_get_mode()

	func set_mode(m: DisplayServer.WindowMode) -> void:
		DisplayServer.window_set_mode(m)

	func vsync() -> DisplayServer.VSyncMode:
		return DisplayServer.window_get_vsync_mode()

	func set_vsync(m: DisplayServer.VSyncMode) -> void:
		DisplayServer.window_set_vsync_mode(m)

	## The smallest the window can be dragged (BP13).
	func set_min_size(size: Vector2i) -> void:
		DisplayServer.window_set_min_size(size)

	## The number of screens (none headless).
	func count() -> int:
		return DisplayServer.get_screen_count()

	func primary() -> int:
		return DisplayServer.get_primary_screen()

	## The screen the window is on, or -1.
	func current() -> int:
		return DisplayServer.window_get_current_screen()

	func set_current(screen: int) -> void:
		DisplayServer.window_set_current_screen(screen)

	func size(screen: int) -> Vector2i:
		return DisplayServer.screen_get_size(screen)

	## Refresh rate (Hz), or less than 0 when the system doesn't say.
	func rate(screen: int) -> float:
		return DisplayServer.screen_get_refresh_rate(screen)
