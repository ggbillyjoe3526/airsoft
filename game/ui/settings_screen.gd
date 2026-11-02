class_name SettingsScreen
extends Control
## The settings, in seven tabs: Controls (the mouse, sensitivity as cm/360, the crouch and aim toggles, rebinding),
## Audio (a volume for each bus), Display (SettingsDisplayPage: the window, the frame rate, the view), Graphics
## (SettingsGraphicsPage), HUD (SettingsHudPage), Accessibility (SettingsAccessPage) and Save file (SettingsSavePage:
## restore points, Undo and delete, which restart the game, so only from the title's settings); and an eighth, Dev,
## always there, each of its switches off until you turn it on (owner, 2026-10-29; docs/DECISIONS.md › Content
## tags and dev content). Opened from the title screen and the pause menu; works while the tree is paused. Every change
## is applied at once through SettingsApply and saved: a slider a moment after it stops moving, anything else straight
## away, and the last change always on close. Back closes it, and Esc does too when `esc_closes` (the pause menu's: in a
## match Esc stays the pause menu's; in the menus Esc asks QUIT GAME?, owner 2026-10-29). While it is open, keys the
## controls don't use stop here, so none reaches play.

## The screen closed.
signal closed
## About's Licences, Report a Bug and Quit were pressed (the menus' settings only: `in_menus`).
signal credits_requested
signal report_requested
signal quit_requested

const MARGIN_X := 56.0
const MARGIN_Y := 28.0
const SAVE_DELAY := 0.5
## The rows' one design (UI1): a name LABEL_WIDTH wide, ROW_SEPARATION, then the control, every row at least
## GameTheme.CONTROL_HEIGHT tall and ROW_GAP apart; a section's heading SECTION_GAP under the row before it.
const ROW_LABEL_WIDTH := 280.0
const ROW_SEPARATION := 16
const SLIDER_WIDTH := 280.0
const READOUT_WIDTH := 72.0
const BOX_WIDTH := 120.0
const ROW_GAP := 8
const SECTION_GAP := 18
## The Controls tab's two columns: the left's width and the gap (px).
const CONTROLS_LEFT := 760.0
const COLUMN_GAP := 48
## The page heading's size (px at 1080p).
const HEADING_SIZE := 34
## cm/360 boxes: the widest range a typed figure may be in before it is held to the sensitivity's range.
const CM_MIN := 0.1
const CM_MAX := 1000.0
const CM_STEP := 0.01
const DPI_STEP := 50.0
const PERCENT_STEP := 1.0
## The Dev tab's switches, each a DevSettings field with a label DEV_<FIELD> and a help line DEV_<FIELD>_HELP.
## Dev › Time of day's choices in order: the map's own (&""), then LightingConfig's presets.
const DEV_TIMES: Array[StringName] = [&"", LightingConfig.DAY, LightingConfig.NIGHT]
const DEV_SWITCHES: Array[StringName] = [&"dev_content", &"disable_levelling", &"bottomless", &"ghost",
		&"bots_hold_fire", &"bots_run_low", &"spectate_bots", &"bot_intent", &"retro_pixels", &"robots", &"pretend_slow_frames"]
## Dev › Actions' error and crash, in the log (English: the log is read by the developer).
const DEV_TEST_ERROR := "Dev: a test error (Settings › Dev › Log a test error)"
const DEV_CRASH := "Dev: Settings › Dev › Crash the game now"
## What the screen edits; the game's own by default.
var settings: Settings = null
## Where it saves (a test points this at a temporary file).
var save_path: String = Settings.PATH
## Whether Esc closes the screen (the pause menu's settings); off in the menus, where Esc asks QUIT GAME? instead.
var esc_closes: bool = false
## Whether the SETTINGS heading shows: not beside the menus' rail, whose lit SETTINGS tab already says it.
var show_heading: bool = true
## Opened from the menus (beside the rail, over the field's picture): no plate of its own, and About has Report a Bug,
## Licences and Quit; off from the pause menu, which has its own.
var in_menus: bool = false
## The match's End the round now, set when opened from the pause menu (returns false when no round is live); empty
## from the title screen.
var end_round: Callable = Callable()
## Whose level the Dev tab's Reset level resets: the game's own when unset (a test gives its own).
var progress: Progress = null
## Starts the game again (main's), after the Save file tab replaces the save; empty from the pause menu, where the save
## can't be replaced.
var restart: Callable = Callable()
## The Save file tab's restore points and Undo: the real save's when unset (a test gives its own).
var save_keeper: SaveKeeper = null
## Dev › Crash the game now (OS.crash) and Log a test error (push_error) when unset; tests give their own, so no test
## crashes the test run.
var crash_now: Callable = Callable()
var log_test_error: Callable = Callable()

var _back: Button = null
var _heading: Label = null
var _tabs: TabContainer = null
var _load_message: Label = null
var _note: Label = null
var _timer: Timer = null
var _keys: KeyBindingList = null
var _sensitivity: HSlider = null
var _aim_sensitivity: HSlider = null
var _cm: SpinBox = null
var _dpi: SpinBox = null
var _invert: CheckButton = null
## Hold or Toggle (0, 1), the order wheel's Hover or Click (0, 1) and Reload's Manual or Automatic (0, 1): two words
## each, so a choice, not a switch.
var _crouch: MenuChoice = null
var _aim: MenuChoice = null
var _wheel_pick: MenuChoice = null
var _auto_reload: MenuChoice = null
var _volume: Dictionary[StringName, HSlider] = {}
var _display_page: SettingsDisplayPage = null
var _graphics_page: SettingsGraphicsPage = null
var _hud_page: SettingsHudPage = null
var _access_page: SettingsAccessPage = null
## Save file's tab page, and the tab built in it the first time it shows (it reads the save; most visits never do).
var _save_tab: VBoxContainer = null
var _save_page: SettingsSavePage = null
var _dev_page: Control = null
var _dev_checks: Dictionary[StringName, CheckButton] = {}
## Dev › Time of day: the map's own, then each preset (DEV_TIMES).
var _time_of_day: MenuChoice = null
var _speed: HSlider = null
var _end_round: Button = null
var _confirm_level: ConfirmationDialog = null
var _confirm_crash: ConfirmationDialog = null
var _about_page: SettingsAboutPage = null


func _ready() -> void:
	name = "SettingsScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	if settings == null:
		settings = Settings.shared()
	theme = GameTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plate := ColorRect.new()
	plate.color = GameTheme.BG
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# in the menus the field's blurred picture shows through
	plate.visible = not in_menus
	add_child(plate)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = MARGIN_X
	box.offset_right = -MARGIN_X
	box.offset_top = MARGIN_Y
	box.offset_bottom = -MARGIN_Y
	box.add_theme_constant_override("separation", ROW_GAP)
	add_child(box)
	_heading = Label.new()
	_heading.text = tr("SETTINGS_TITLE").to_upper()
	_heading.add_theme_font_override("font", GameTheme.heading_font(700, GameTheme.SPACING_TAB, HEADING_SIZE))
	_heading.add_theme_font_size_override("font_size", HEADING_SIZE)
	_heading.visible = show_heading
	box.add_child(_heading)
	_load_message = Label.new()
	_load_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_load_message.add_theme_color_override("font_color", GameTheme.WARN)
	box.add_child(_load_message)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_tabs)
	_build_controls()
	_build_audio()
	_build_display()
	_build_graphics()
	_build_hud()
	_build_access()
	_build_save()
	_build_about()
	_build_dev()
	# the foot: BACK, a small button at the bottom left as wide as its words (owner, 2026-10-29), and the note of the last
	# action beside it in a line of its own width, so a note never moves the tabs
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", ROW_SEPARATION)
	box.add_child(foot)
	_back = Button.new()
	_back.name = "Back"
	_back.text = tr("SETTINGS_BACK").to_upper()
	GameTheme.small_button(_back, GameTheme.ACCENT)
	_back.pressed.connect(close)
	ButtonWidth.group([_back])
	foot.add_child(_back)
	_note = Label.new()
	GameTheme.note_label(_note)
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foot.add_child(_note)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = SAVE_DELAY
	_timer.timeout.connect(_save)
	add_child(_timer)
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if settings != null:
			settings.save_if_dirty(save_path)


## Shows the settings as they are now.
func open() -> void:
	_refresh()
	_keys.cancel()
	_note.text = ""
	visible = true
	# take focus, so Tab and Enter can't reach the screen underneath
	_back.grab_focus()


## Shows the Graphics tab (the first start's notice's Graphics settings).
func show_graphics() -> void:
	# the page sits in its tab's scroll box
	_tabs.current_tab = _graphics_page.get_parent().get_parent().get_index()


## Shows the About tab.
func show_about() -> void:
	_tabs.current_tab = _about_page.get_parent().get_parent().get_index()


## About's Report a Bug, Licences and Quit buttons (null from the pause menu).
func about_report_button() -> Button:
	return _about_page.report_button()


func about_credits_button() -> Button:
	return _about_page.credits_button()


func about_quit_button() -> Button:
	return _about_page.quit_button()


## The tab showing (tests).
func current_tab() -> int:
	return _tabs.current_tab


## Hides the screen, saving any change not yet saved.
func close() -> void:
	if not visible:
		return
	_keys.cancel()
	_graphics_page.let_go()
	visible = false
	_timer.stop()
	settings.save_if_dirty(save_path)
	closed.emit()


func _input(event: InputEvent) -> void:
	if esc_closes and is_visible_in_tree() and not _keys.capturing() and event.is_action_pressed(&"ui_cancel") \
			and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()


## Keys that reach here weren't used by the focused control (which has had its turn): they stop here, before any
## _unhandled_input in play, except the debug keys and the like, which the game keeps for itself.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and is_visible_in_tree() and not KeyBindings.UNBINDABLE.has(int(key.physical_keycode)):
		get_viewport().set_input_as_handled()


func _save() -> void:
	settings.save_if_dirty(save_path)


## A setting changed: it is saved a moment from now, or at once for a click.
func _changed(immediate: bool = false) -> void:
	settings.mark_changed()
	if immediate:
		_timer.stop()
		settings.save_if_dirty(save_path)
	else:
		_timer.start()


# --- Controls ---

func _build_controls() -> void:
	var tab := _page(tr("SETTINGS_CONTROLS"))
	# two columns: the mouse, stance and order wheel on the left, the keys on the right
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", COLUMN_GAP)
	tab.add_child(columns)
	var page := VBoxContainer.new()
	page.custom_minimum_size.x = CONTROLS_LEFT
	page.add_theme_constant_override("separation", ROW_GAP)
	columns.add_child(page)
	var keys := VBoxContainer.new()
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys.add_theme_constant_override("separation", ROW_GAP)
	columns.add_child(keys)
	add_section(page, tr("SETTINGS_MOUSE"))
	_sensitivity = add_slider_row(page, "SETTINGS_SENSITIVITY", Sensitivity.MIN, Sensitivity.MAX, Sensitivity.STEP, "%.2f")
	_sensitivity.value_changed.connect(_on_sensitivity)
	_aim_sensitivity = add_slider_row(page, "SETTINGS_AIM_SENSITIVITY", Sensitivity.AIM_MIN, Sensitivity.AIM_MAX,
			Sensitivity.AIM_STEP, "%.2f")
	_aim_sensitivity.value_changed.connect(_on_aim_sensitivity)
	_dpi = _spin_row(page, "SETTINGS_DPI", Sensitivity.DPI_MIN, Sensitivity.DPI_MAX, DPI_STEP)
	_dpi.value_changed.connect(_on_dpi)
	_cm = _spin_row(page, "SETTINGS_CM360", CM_MIN, CM_MAX, CM_STEP)
	_cm.value_changed.connect(_on_cm)
	_invert = add_check_row(page, "SETTINGS_INVERT", "SETTINGS_ON", "SETTINGS_OFF")
	_invert.toggled.connect(func(on: bool) -> void:
		settings.invert_y = on
		_applied(SettingsApply.apply_controls, true))
	add_section(page, tr("SETTINGS_STANCE"))
	var hold_toggle: Array[String] = ["SETTINGS_HOLD", "SETTINGS_TOGGLE"]
	_crouch = add_choice_row(page, "SETTINGS_CROUCH", hold_toggle)
	_crouch.picked.connect(func(i: int) -> void:
		settings.crouch_toggle = i == 1
		_applied(SettingsApply.apply_controls, true))
	_aim = add_choice_row(page, "SETTINGS_AIM", hold_toggle)
	_aim.picked.connect(func(i: int) -> void:
		settings.aim_toggle = i == 1
		_applied(SettingsApply.apply_controls, true))
	# Manual or Automatic (RL2), a choice like Crouch and Aim (UI1)
	_auto_reload = add_choice_row(page, "SETTINGS_RELOAD", ["SETTINGS_RELOAD_MANUAL", "SETTINGS_RELOAD_AUTO"])
	_auto_reload.picked.connect(func(i: int) -> void:
		settings.auto_reload = i == 1
		_applied(SettingsApply.apply_controls, true))
	add_section(page, tr("SETTINGS_ORDERS"))
	_wheel_pick = add_choice_row(page, "SETTINGS_ORDER_WHEEL", ["SETTINGS_WHEEL_HOVER", "SETTINGS_WHEEL_CLICK"])
	_wheel_pick.picked.connect(func(i: int) -> void:
		settings.wheel_pick = ControlsConfig.WheelPick.CLICK if i == 1 else ControlsConfig.WheelPick.HOVER
		_applied(SettingsApply.apply_controls, true))
	# how Hover and Click work: the choice's tooltip, no paragraph under it (UI1 round 3)
	explain(_wheel_pick.get_parent() as Control, tr("SETTINGS_ORDERS_HELP"))
	add_section(keys, tr("SETTINGS_KEYS"))
	add_help(keys, "SETTINGS_KEYS_HINT")
	_keys = KeyBindingList.new(settings)
	_keys.rebound.connect(func() -> void: _changed(true))
	_keys.note.connect(func(text: String) -> void: _note.text = text)
	keys.add_child(_keys)
	var reset := Button.new()
	reset.text = tr("SETTINGS_KEYS_RESET").to_upper()
	GameTheme.small_button(reset)
	reset.pressed.connect(_keys.reset_all)
	ButtonWidth.group([reset])
	keys.add_child(reset)


func _on_sensitivity(v: float) -> void:
	settings.sensitivity = v
	_applied(SettingsApply.apply_controls)
	_show_cm()


func _on_aim_sensitivity(v: float) -> void:
	settings.aim_sensitivity = v
	_applied(SettingsApply.apply_controls)


func _on_dpi(v: float) -> void:
	settings.mouse_dpi = roundi(v)
	_changed()
	_show_cm()


## A typed cm/360 sets the sensitivity; the box then shows what that is (it may have been held to the range).
func _on_cm(v: float) -> void:
	var s := Sensitivity.from_typed_cm(settings.tuning.controls.radians_per_count, v, settings.mouse_dpi)
	if is_nan(s):
		_show_cm()
		return
	settings.sensitivity = s
	set_slider(_sensitivity, s)
	_applied(SettingsApply.apply_controls)
	_show_cm()


func _show_cm() -> void:
	_cm.set_value_no_signal(Sensitivity.cm_per_360(settings.tuning.controls.radians_per_count, settings.sensitivity,
			settings.mouse_dpi))


# --- Audio ---

func _build_audio() -> void:
	var page := _page(tr("SETTINGS_AUDIO"))
	add_section(page, tr("SETTINGS_VOLUME"))
	for bus: StringName in Settings.VOLUME_BUSES:
		var slider := add_slider_row(page, "SETTINGS_VOL_" + String(bus).to_upper(), 0.0, 100.0, PERCENT_STEP, "%d %%")
		slider.value_changed.connect(_on_volume.bind(bus))
		_volume[bus] = slider


func _on_volume(v: float, bus: StringName) -> void:
	settings.volumes[bus] = v / 100.0
	_applied(SettingsApply.apply_audio)


# --- Display ---

func _build_display() -> void:
	var page := _page(tr("SETTINGS_DISPLAY"))
	_display_page = SettingsDisplayPage.new()
	page.add_child(_display_page)
	_display_page.build(self)
	_display_page.changed.connect(_changed)


# --- Graphics ---

func _build_graphics() -> void:
	var page := _page(tr("SETTINGS_GRAPHICS"))
	_graphics_page = SettingsGraphicsPage.new()
	page.add_child(_graphics_page)
	_graphics_page.build(self)
	_graphics_page.changed.connect(_changed)


# --- HUD ---

func _build_hud() -> void:
	var page := _page(tr("SETTINGS_HUD"))
	_hud_page = SettingsHudPage.new()
	page.add_child(_hud_page)
	_hud_page.build(self)
	_hud_page.changed.connect(_changed)


# --- Accessibility ---

func _build_access() -> void:
	var page := _page(tr("SETTINGS_ACCESSIBILITY"))
	_access_page = SettingsAccessPage.new()
	page.add_child(_access_page)
	_access_page.build(self)
	_access_page.changed.connect(_changed)


# --- Save file ---

func _build_save() -> void:
	_save_tab = _page(tr("SETTINGS_SAVE_FILE"))
	_tabs.tab_changed.connect(_on_tab_changed)


## The Save file tab's page, built on its first show.
func _on_tab_changed(tab: int) -> void:
	if tab != _save_tab.get_parent().get_index() or _save_page != null:
		return
	_save_page = SettingsSavePage.new()
	if save_keeper != null:
		_save_page.keeper = save_keeper
	_save_tab.add_child(_save_page)
	_save_page.build(self)
	if _save_page.is_visible_in_tree():
		_save_page.refresh()


## Save file's page, or null until its tab first shows.
func save_page() -> SettingsSavePage:
	return _save_page


## The focus on Back (a question closed and the button that asked it is greyed now).
func focus_back() -> void:
	_back.grab_focus()


## Whether the save may be replaced from here: the title's settings (which can restart the game), not a match's.
func can_replace() -> bool:
	return restart.is_valid() and not end_round.is_valid()


# --- Dev ---

func _build_dev() -> void:
	_dev_page = _page(tr("SETTINGS_DEV"))
	var page := _dev_page as VBoxContainer
	# one line, the records warning; which settings it means is its tooltip, and each row's note the row's (UI1 round 3)
	var intro := add_help(page, "DEV_RECORDS_LINE")
	intro.tooltip_text = tr("DEV_INTRO")
	intro.mouse_filter = Control.MOUSE_FILTER_PASS
	add_section(page, tr("DEV_SWITCHES"))
	_speed = add_slider_row(page, "DEV_GAME_SPEED", DevCheats.SPEED_MIN * 100.0, DevCheats.SPEED_MAX * 100.0,
			DevSettings.SPEED_STEP * 100.0, "%d %%")
	_speed.value_changed.connect(func(v: float) -> void:
		settings.dev.game_speed = v / 100.0
		_changed())
	explain(_speed.get_parent() as Control, tr("DEV_GAME_SPEED_HELP"))
	for field: StringName in DEV_SWITCHES:
		var key := "DEV_" + String(field).to_upper()
		var check := add_check_row(page, key, "SETTINGS_ON", "SETTINGS_OFF")
		check.toggled.connect(_on_dev_switch.bind(field))
		_dev_checks[field] = check
		explain(check.get_parent() as Control, tr(key + "_HELP"))
	_build_time_of_day(page)
	add_section(page, tr("DEV_ACTIONS"))
	var end_row := add_row(page, "DEV_END_ROUND")
	_end_round = Button.new()
	_end_round.text = tr("DEV_END_ROUND_BUTTON").to_upper()
	GameTheme.small_button(_end_round)
	_end_round.pressed.connect(_on_end_round)
	end_row.add_child(_end_round)
	explain(end_row, tr("DEV_END_ROUND_HELP"))
	var level_row := add_row(page, "DEV_RESET_LEVEL")
	var reset_level := Button.new()
	reset_level.text = tr("DEV_RESET_LEVEL_BUTTON").to_upper()
	GameTheme.small_button(reset_level)
	level_row.add_child(reset_level)
	explain(level_row, tr("DEV_RESET_LEVEL_HELP"))
	_confirm_level = ConfirmationDialog.new()
	_confirm_level.title = tr("DEV_RESET_LEVEL_TITLE")
	_confirm_level.dialog_text = tr("DEV_RESET_LEVEL_QUESTION")
	_confirm_level.ok_button_text = tr("DEV_RESET_LEVEL_BUTTON")
	_confirm_level.confirmed.connect(_on_reset_level)
	add_child(_confirm_level)
	reset_level.pressed.connect(_confirm_level.popup_centered)
	# the Actions' buttons are one group
	var actions: Array[Button] = [_end_round, reset_level]
	actions.append_array(_build_dev_checks(page))
	ButtonWidth.group(actions)


## Dev › Time of day (WL3): the map's own light, or Day or Night on any map, from the next match.
func _build_time_of_day(page: VBoxContainer) -> void:
	var row := add_row(page, "DEV_TIME_OF_DAY")
	_time_of_day = MenuChoice.new(PackedStringArray([tr("DEV_TIME_MAP"), tr("DEV_TIME_DAY"), tr("DEV_TIME_NIGHT")]))
	_time_of_day.name = "TimeOfDay"
	row.add_child(_time_of_day)
	_time_of_day.picked.connect(func(i: int) -> void:
		settings.dev.time_of_day = DEV_TIMES[i]
		_changed(true))
	explain(row, tr("DEV_TIME_OF_DAY_HELP"))


## Dev › Time of day's choice.
func time_of_day_choice() -> MenuChoice:
	return _time_of_day


## Dev › Actions' checks of the crash screen and the pause menu's error line (SV6); the two buttons.
func _build_dev_checks(page: VBoxContainer) -> Array[Button]:
	var error_row := add_row(page, "DEV_TEST_ERROR")
	var error := Button.new()
	error.name = "LogTestError"
	error.text = tr("DEV_TEST_ERROR_BUTTON").to_upper()
	GameTheme.small_button(error)
	error.pressed.connect(_on_test_error)
	error_row.add_child(error)
	explain(error_row, tr("DEV_TEST_ERROR_HELP"))
	var crash_row := add_row(page, "DEV_CRASH")
	var crash := Button.new()
	crash.name = "CrashNow"
	crash.text = tr("DEV_CRASH_BUTTON").to_upper()
	GameTheme.small_button(crash)
	crash_row.add_child(crash)
	explain(crash_row, tr("DEV_CRASH_HELP"))
	_confirm_crash = ConfirmationDialog.new()
	_confirm_crash.title = tr("DEV_CRASH_TITLE")
	_confirm_crash.dialog_text = tr("DEV_CRASH_QUESTION")
	_confirm_crash.ok_button_text = tr("DEV_CRASH_BUTTON")
	_confirm_crash.confirmed.connect(_on_crash)
	add_child(_confirm_crash)
	crash.pressed.connect(_ask_crash)
	return [error, crash]


func _on_dev_switch(on: bool, field: StringName) -> void:
	settings.dev.set(field, on)
	_changed(true)


func _on_end_round() -> void:
	var ended: bool = end_round.is_valid() and bool(end_round.call())
	_note.text = tr("DEV_DONE") if ended else tr("DEV_NO_ROUND")


## Back to level 0 with the starting kit alone (the game's own progress, or `progress` a test gives).
func _on_reset_level() -> void:
	var p := progress if progress != null else Progress.shared()
	p.reset()
	p.save_if_dirty()
	_note.text = tr("DEV_DONE")


func _on_test_error() -> void:
	if log_test_error.is_valid():
		log_test_error.call()
	else:
		push_error(DEV_TEST_ERROR)
	_note.text = tr("DEV_DONE")


## The crash's confirm, Cancel focused: Enter or a stray press keeps the game running.
func _ask_crash() -> void:
	_confirm_crash.popup_centered()
	_confirm_crash.get_cancel_button().grab_focus.call_deferred()


## The run ends here as a crash: the next start shows the crash screen.
func _on_crash() -> void:
	if crash_now.is_valid():
		crash_now.call()
	else:
		OS.crash(DEV_CRASH)


## Runs `apply` on the settings, then saves (at once if `immediate`).
func _applied(apply: Callable, immediate: bool = false) -> void:
	apply.call(settings)
	_changed(immediate)


# --- Showing the settings ---

func _refresh() -> void:
	_load_message.text = settings.load_message
	_load_message.visible = not settings.load_message.is_empty()
	set_slider(_sensitivity, settings.sensitivity)
	set_slider(_aim_sensitivity, settings.aim_sensitivity)
	_dpi.set_value_no_signal(settings.mouse_dpi)
	_show_cm()
	set_check(_invert, settings.invert_y)
	_crouch.put(int(settings.crouch_toggle))
	_aim.put(int(settings.aim_toggle))
	_auto_reload.put(int(settings.auto_reload))
	_wheel_pick.put(int(settings.wheel_pick == ControlsConfig.WheelPick.CLICK))
	_keys.refresh()
	for bus: StringName in Settings.VOLUME_BUSES:
		set_slider(_volume[bus], settings.volumes[bus] * 100.0)
	_display_page.refresh()
	_graphics_page.refresh()
	_hud_page.refresh()
	_access_page.refresh()
	set_slider(_speed, settings.dev.game_speed * 100.0)
	for field: StringName in DEV_SWITCHES:
		set_check(_dev_checks[field], settings.dev.get(field) as bool)
	_time_of_day.put(maxi(0, DEV_TIMES.find(settings.dev.time_of_day)))
	_end_round.disabled = not end_round.is_valid()


# --- About ---

## About (no title screen: owner, 2026-11-02): SettingsAboutPage on its tab.
func _build_about() -> void:
	var tab := _page(tr("SETTINGS_ABOUT"))
	_about_page = SettingsAboutPage.new()
	tab.add_child(_about_page)
	_about_page.build(self, in_menus)
	_about_page.report_pressed.connect(func() -> void: report_requested.emit())
	_about_page.credits_pressed.connect(func() -> void: credits_requested.emit())
	_about_page.quit_pressed.connect(func() -> void: quit_requested.emit())


# --- Building blocks ---

## A scrolling tab page titled `title` (a tab takes its page's name), returned as the column to fill. It scrolls to the
## control the keyboard or a pad moves focus to.
func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title.to_upper()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_tabs.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", ROW_GAP)
	scroll.add_child(page)
	return page


func add_section(page: Control, text: String) -> void:
	if page.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0.0, SECTION_GAP)
		page.add_child(gap)
	page.add_child(section_label(text))


## A section's heading: `text` in spaced capitals, muted.
static func section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_override("font", GameTheme.heading_font(600, GameTheme.SPACING_HEADING_CAPS,
			GameTheme.SECTION_SIZE))
	label.add_theme_font_size_override("font_size", GameTheme.SECTION_SIZE)
	label.add_theme_color_override("font_color", GameTheme.MUTED)
	return label


## A row under `page`: its name (`label_key` translated, in capitals, `width` px wide), then what the caller adds; at
## least one control tall.
func add_row(page: Control, label_key: String, width: float = ROW_LABEL_WIDTH) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	row.custom_minimum_size.y = GameTheme.CONTROL_HEIGHT
	var label := Label.new()
	label.text = tr(label_key)
	GameTheme.row_label(label)
	label.custom_minimum_size = Vector2(width, 0.0)
	row.add_child(label)
	page.add_child(row)
	return row


## A label and a row of choices (`keys` translated), none picked yet.
func add_choice_row(page: Control, label_key: String, keys: Array[String],
		width: float = ROW_LABEL_WIDTH) -> MenuChoice:
	var row := add_row(page, label_key, width)
	var words := PackedStringArray()
	for key in keys:
		words.append(tr(key))
	var choice := MenuChoice.new(words)
	choice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(choice)
	return choice


## A label, a slider and its figure; `fmt` shows the value.
func add_slider_row(page: Control, label_key: String, lo: float, hi: float, step: float, fmt: String,
		width: float = ROW_LABEL_WIDTH) -> HSlider:
	var row := add_row(page, label_key, width)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 0.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size = Vector2(READOUT_WIDTH, 0.0)
	readout.add_theme_font_override("font", GameTheme.font(700))
	readout.add_theme_font_size_override("font_size", GameTheme.LABEL_SIZE)
	readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	readout.size_flags_vertical = Control.SIZE_FILL
	row.add_child(readout)
	slider.set_meta(&"readout", readout)
	slider.set_meta(&"format", fmt)
	slider.value_changed.connect(_show_readout.bind(slider))
	return slider


func _show_readout(v: float, slider: HSlider) -> void:
	(slider.get_meta(&"readout") as Label).text = (slider.get_meta(&"format") as String) % v


## Moves a slider without sending a change, and its figure with it.
func set_slider(slider: HSlider, v: float) -> void:
	slider.set_value_no_signal(v)
	_show_readout(slider.value, slider)


func _spin_row(page: Control, label_key: String, lo: float, hi: float, step: float) -> SpinBox:
	var row := add_row(page, label_key)
	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.step = step
	spin.custom_minimum_size = Vector2(BOX_WIDTH, GameTheme.CONTROL_HEIGHT)
	spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spin.get_line_edit().add_theme_font_size_override("font_size", GameTheme.LABEL_SIZE)
	spin.get_line_edit().add_theme_stylebox_override("normal", GameTheme.box(GameTheme.CARD, GameTheme.LINE,
			GameTheme.CONTROL_PAD_X, 0))
	spin.get_line_edit().add_theme_stylebox_override("focus", GameTheme.box(GameTheme.CARD, GameTheme.ACCENT,
			GameTheme.CONTROL_PAD_X, 0))
	row.add_child(spin)
	return spin


## A help line under a row, wrapped and quiet, `indent` px in (under the controls, past the rows' names).
func add_help(page: Control, key: String, indent: float = 0.0) -> Label:
	var help := Label.new()
	help.text = tr(key)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameTheme.note_label(help)
	if indent > 0.0:
		var margin := StyleBoxEmpty.new()
		margin.content_margin_left = indent
		help.add_theme_stylebox_override("normal", margin)
	page.add_child(help)
	return help


## A quiet note after a row's control (`text` as given), on the row's line.
func add_note(row: Control, text: String) -> Label:
	var note := Label.new()
	note.text = text
	GameTheme.note_label(note)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(note)
	return note


## Puts `text` as the tooltip of `row` and of every button and slider in it, so the explanation of a row is under the
## pointer wherever it rests on the row (UI1: help that would only clutter the page).
func explain(row: Control, text: String) -> void:
	row.tooltip_text = text
	if row.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		row.mouse_filter = Control.MOUSE_FILTER_PASS
	for c: Node in row.find_children("*", "", true, false):
		if (c is BaseButton or c is Range) and (c as Control).tooltip_text == "":
			(c as Control).tooltip_text = text


## A label and an On/Off switch (MenuSwitch: a pill of one size, so pressing it moves nothing beside it); `on_key`
## and `off_key` name its states in words.
func add_check_row(page: Control, label_key: String, on_key: String, off_key: String,
		width: float = ROW_LABEL_WIDTH) -> CheckButton:
	var row := add_row(page, label_key, width)
	var check := MenuSwitch.new(tr(on_key), tr(off_key))
	row.add_child(check)
	return check


## Moves a switch without sending a change.
func set_check(check: CheckButton, on: bool) -> void:
	var switch := check as MenuSwitch
	if switch != null:
		switch.put(on)
	else:
		check.set_pressed_no_signal(on)
