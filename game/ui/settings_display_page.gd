class_name SettingsDisplayPage
extends HBoxContainer
## The settings' Display tab (concept `settings-display.png`): the window (Window mode as Windowed, Borderless or
## Fullscreen, the F11 and Alt+Enter keys in its tooltip; Monitor, shown only with two screens or more, each as its
## number, size and rate) and the frame rate (V-Sync, and the frame-rate limit: a slider from 30 to 360 with Off beside
## it, owner 2026-11-17) and the view (field of view, Show FPS) and the interface (its colour, UA2: a swatch per
## UiColours colour, its name in its tooltip; and Tooltips, on or off, owner 2026-11-17), in one column. The longer
## explanations are the rows' tooltips (UI1: help only where a player would be stuck). Each choice is applied at once
## through SettingsApply and `changed` asks the screen to save it. F11 pressed while the tab shows moves Window mode
## with it (`Settings.changed`).

## A choice landed: saved now (`immediate`, a click) or a moment after a slider stops.
signal changed(immediate: bool)
## The interface's colour changed (after `changed`): the screens built in the old one are built again.
signal restyled

## The column's width and the labels' width (px).
const LEFT_WIDTH := 1100.0
const COLUMN_GAP := 48
const LEFT_LABEL := SettingsScreen.ROW_LABEL_WIDTH
const FOV_STEP := 1.0
## The frame-rate limit's slider moves a frame a second at a time.
const LIMIT_STEP := 1.0
## The window modes in Settings.WindowMode's order, as the buttons name them (short: the long names are the notices').
const WINDOW_KEYS: Array[String] = ["SETTINGS_WINDOWED", "SETTINGS_MODE_BORDERLESS", "SETTINGS_MODE_FULLSCREEN"]
## The limit's slider and figure while it is Off.
const OFF_ALPHA := 0.45
## A screen whose refresh rate the system doesn't give reports this or less.
const NO_RATE := 0.0

var _screen: SettingsScreen = null
var _window: MenuChoice = null
var _monitor_row: HBoxContainer = null
var _monitor: MenuChoice = null
var _vsync: CheckButton = null
var _limit: HSlider = null
var _limit_off: MenuChoice = null
var _fov: HSlider = null
var _fps: CheckButton = null
var _ui_colour: MenuSwatches = null
var _tooltips: CheckButton = null


func _init() -> void:
	name = "SettingsDisplayPage"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", COLUMN_GAP)


## Builds the tab with `screen`'s rows (SettingsScreen.add_row and the rest), editing its settings.
func build(screen: SettingsScreen) -> void:
	_screen = screen
	# one column: the choices are one width each now (the frame rate's eight are as wide as UNLIMITED), and a second
	# column beside them no longer fits
	var left := _column(LEFT_WIDTH)
	_build_window(left)
	_build_frame_rate(left)
	_build_view(left)
	_build_interface(left)
	_watch(is_inside_tree())


## Shows the settings as they are now, and the screens there are now. Allocates (the monitors' buttons): on opening only.
func refresh() -> void:
	var s := _screen.settings
	_show_window()
	_show_monitors()
	_screen.set_check(_vsync, s.vsync)
	_show_vsync_note()
	_show_limit()
	_screen.set_slider(_fov, s.fov)
	_ui_colour.put(s.ui_colour)
	_screen.set_check(_tooltips, s.tooltips)
	_screen.set_check(_fps, s.show_fps)


func window_choice() -> MenuChoice:
	return _window


## The Monitor row's choices, or null with fewer than two screens.
func monitor_choice() -> MenuChoice:
	return _monitor


func monitor_row() -> Control:
	return _monitor_row


func vsync() -> CheckButton:
	return _vsync


## V-Sync's explanation (its tooltip).
func vsync_note() -> String:
	return _vsync.tooltip_text


## The frame-rate limit's slider (30 to 360) and its Off button beside it (one choice, lit while there is no limit).
func limit_slider() -> HSlider:
	return _limit


func limit_off() -> MenuChoice:
	return _limit_off


## Settings › Display › Interface › Tooltips.
func tooltips() -> CheckButton:
	return _tooltips


func fov() -> HSlider:
	return _fov


## The interface colour's swatches (tests; Main.restyle puts the keyboard back on the picked one).
func ui_colour() -> MenuSwatches:
	return _ui_colour


func show_fps() -> CheckButton:
	return _fps


func _enter_tree() -> void:
	_watch(true)


func _exit_tree() -> void:
	_watch(false)


## Follows the settings' changes (F11 from anywhere) while in the tree, so nothing is left connected after.
func _watch(on: bool) -> void:
	if _screen == null or _screen.settings == null:
		return
	var s := _screen.settings
	if on and not s.changed.is_connected(_show_window):
		s.changed.connect(_show_window)
	elif not on and s.changed.is_connected(_show_window):
		s.changed.disconnect(_show_window)


func _column(width: float) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.custom_minimum_size.x = width
	c.add_theme_constant_override("separation", SettingsScreen.ROW_GAP)
	add_child(c)
	return c


## Window: the mode (its keys in its tooltip), and Monitor (filled in on refresh).
func _build_window(column: VBoxContainer) -> void:
	_screen.add_section(column, tr("SETTINGS_WINDOW"))
	var row := _screen.add_row(column, "SETTINGS_WINDOW_MODE", LEFT_LABEL)
	var words := PackedStringArray()
	for key in WINDOW_KEYS:
		words.append(tr(key))
	_window = MenuChoice.new(words)
	_window.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_window.picked.connect(func(i: int) -> void:
		SettingsApply.pick_window_mode(_screen.settings, i as Settings.WindowMode)
		changed.emit(true))
	row.add_child(_window)
	_screen.explain(row, keys_tip())
	_monitor_row = _screen.add_row(column, "SETTINGS_MONITOR", LEFT_LABEL)
	_monitor_row.tooltip_text = tr("SETTINGS_MONITOR_HELP")
	_monitor_row.visible = false


## "F11 or Alt+Enter switches at any time.", the window mode row's tooltip (UI1: no hint line beside it); the keys
## named in the player's layout.
func keys_tip() -> String:
	var config := SettingsApply.screens().config
	return "%s %s %s+%s %s." % [KeyNames.name_of(config.toggle_key), tr("SETTINGS_KEYS_OR"), KeyNames.name_of(KEY_ALT),
			KeyNames.name_of(config.alt_toggle_keys[0]), tr("SETTINGS_KEYS_LINE")]


## Frame rate: V-Sync and the limit's choices, each explained in its tooltip.
func _build_frame_rate(column: VBoxContainer) -> void:
	_screen.add_section(column, tr("SETTINGS_FRAME_RATE"))
	_vsync = _screen.add_check_row(column, "SETTINGS_VSYNC", "SETTINGS_ON", "SETTINGS_OFF", LEFT_LABEL)
	_vsync.toggled.connect(func(on: bool) -> void:
		_screen.settings.vsync = on
		SettingsApply.apply_display(_screen.settings)
		changed.emit(true))
	var limits := Settings.FRAME_LIMIT_RANGE
	_limit = _screen.add_slider_row(column, "SETTINGS_FRAME_LIMIT", limits.x, limits.y, LIMIT_STEP, "%d", LEFT_LABEL)
	var row := _limit.get_parent() as HBoxContainer
	_limit.value_changed.connect(func(v: float) -> void:
		# moving the slider sets a limit, Off or not
		_screen.settings.frame_limit_pick = roundi(v)
		_screen.settings.frame_limit = roundi(v)
		_limit_off.put(-1)
		_show_limit_lit()
		SettingsApply.apply_frame_rate(_screen.settings)
		changed.emit(false))
	_limit_off = MenuChoice.new(PackedStringArray([tr("SETTINGS_NO_LIMIT")]))
	_limit_off.name = "LimitOff"
	_limit_off.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_limit_off.picked.connect(func(_i: int) -> void:
		# Off pressed again puts the slider's limit back
		var s := _screen.settings
		s.frame_limit = s.frame_limit_pick if s.frame_limit == Settings.UNLIMITED else Settings.UNLIMITED
		_show_limit()
		SettingsApply.apply_frame_rate(s)
		changed.emit(true))
	row.add_child(_limit_off)
	var help := tr("SETTINGS_FRAME_LIMIT_HELP") % [Engine.physics_ticks_per_second,
			SettingsApply.screens().config.background_fps]
	_screen.explain(row, help)


## The limit's slider on its number (the one kept while Off) and Off lit while there is no limit.
func _show_limit() -> void:
	var s := _screen.settings
	_screen.set_slider(_limit, s.frame_limit_pick if s.frame_limit == Settings.UNLIMITED else s.frame_limit)
	_limit_off.put(0 if s.frame_limit == Settings.UNLIMITED else -1)
	_show_limit_lit()


## The slider and its figure dim while the limit is Off: the number is what turning it on gives.
func _show_limit_lit() -> void:
	var off := _screen.settings.frame_limit == Settings.UNLIMITED
	var shade := Color(1.0, 1.0, 1.0, OFF_ALPHA if off else 1.0)
	_limit.modulate = shade
	(_limit.get_meta(&"readout") as Control).modulate = shade


## View: the field of view and Show FPS.
func _build_view(column: VBoxContainer) -> void:
	_screen.add_section(column, tr("SETTINGS_VIEW"))
	_fov = _screen.add_slider_row(column, "SETTINGS_FOV", Settings.FOV_MIN, Settings.FOV_MAX, FOV_STEP, "%d°",
			LEFT_LABEL)
	_fov.value_changed.connect(func(v: float) -> void:
		_screen.settings.fov = v
		SettingsApply.apply_controls(_screen.settings)
		changed.emit(false))
	_fps = _screen.add_check_row(column, "SETTINGS_SHOW_FPS", "SETTINGS_ON", "SETTINGS_OFF", LEFT_LABEL)
	_fps.tooltip_text = tr("SETTINGS_SHOW_FPS_HELP")
	_fps.toggled.connect(func(on: bool) -> void:
		_screen.settings.show_fps = on
		changed.emit(true))


## Interface: the colour of the main buttons and the selection (UiColours), applied at once, and Tooltips.
func _build_interface(column: VBoxContainer) -> void:
	_screen.add_section(column, tr("SETTINGS_INTERFACE"))
	var row := _screen.add_row(column, "SETTINGS_UI_COLOUR", LEFT_LABEL)
	_ui_colour = MenuSwatches.new(UiColours.ACCENTS)
	_ui_colour.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in UiColours.NAME_KEYS.size():
		_ui_colour.button(i).tooltip_text = tr(UiColours.NAME_KEYS[i])
	_ui_colour.picked.connect(func(i: int) -> void:
		_screen.settings.ui_colour = i as UiColours.Pick
		var restyle := SettingsApply.apply_ui_colour(_screen.settings)
		changed.emit(true)
		if restyle:
			restyled.emit())
	row.add_child(_ui_colour)
	_screen.explain(row, tr("SETTINGS_UI_COLOUR_HELP"))
	_tooltips = _screen.add_check_row(column, "SETTINGS_TOOLTIPS", "SETTINGS_ON", "SETTINGS_OFF", LEFT_LABEL)
	_tooltips.tooltip_text = tr("SETTINGS_TOOLTIPS_HELP")
	_tooltips.toggled.connect(func(on: bool) -> void:
		_screen.settings.tooltips = on
		SettingsApply.apply_tooltips(_screen.settings)
		changed.emit(true))


func _show_window() -> void:
	_window.put(_screen.settings.window_mode)


## The Monitor row's buttons for the screens there are now (number, size, rate), the window's own lit; hidden with one.
func _show_monitors() -> void:
	var ds := SettingsApply.screens()
	var count := ds.count()
	if _monitor != null:
		# freed now, not queued: refresh runs on opening, never from the row's own press
		_monitor.free()
		_monitor = null
	_monitor_row.visible = count >= 2
	if not _monitor_row.visible:
		return
	var words := PackedStringArray()
	for i in count:
		var size := ds.size(i)
		var rate := ds.rate(i)
		if rate > NO_RATE:
			words.append(tr("SETTINGS_MONITOR_LINE") % [i + 1, size.x, size.y, roundi(rate)])
		else:
			words.append(tr("SETTINGS_MONITOR_LINE_NO_RATE") % [i + 1, size.x, size.y])
	_monitor = MenuChoice.new(words)
	_monitor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_monitor.picked.connect(func(i: int) -> void:
		SettingsApply.pick_monitor(_screen.settings, i)
		_show_vsync_note()
		changed.emit(true))
	_monitor_row.add_child(_monitor)
	# on its buttons too: they stop the mouse, so the row's own tooltip never showed over them
	_screen.explain(_monitor_row, tr("SETTINGS_MONITOR_HELP"))
	# the screen the window is on now (dragged since the start, it may not be the saved one)
	var on := ds.current()
	_monitor.put(on if on >= 0 else SettingsApply.monitor_now(_screen.settings, ds))


## V-Sync's note names the rate of the screen the window is on, when the system gives it.
func _show_vsync_note() -> void:
	var ds := SettingsApply.screens()
	var at := ds.current()
	var rate := ds.rate(at) if at >= 0 and at < ds.count() else NO_RATE
	if rate > NO_RATE:
		_vsync.tooltip_text = tr("SETTINGS_VSYNC_HELP") % roundi(rate)
	else:
		_vsync.tooltip_text = tr("SETTINGS_VSYNC_HELP_NO_RATE")
