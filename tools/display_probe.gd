extends SceneTree
## What of the display-dependent code runs for real under Xvfb (AUD2, KNOWN_ISSUES 89), against the real X11 display
## server rather than the tests' stand-in: window modes, F11 and Alt+Enter through the real WindowWatch and input
## events, V-Sync, the background frame rate (the focus notifications are synthetic: Xvfb has no window manager to
## take focus), and key names in a layout the X server holds (the layout is set by the caller, `setxkbmap fr`). Prints
## `[probe] <what>: <result>` lines. Needs a display and OpenGL; under xvfb:
##   XDG_DATA_HOME=/tmp/x XDG_CONFIG_HOME=/tmp/xc xvfb-run -a -s "-screen 0 1920x1080x24" bash -c \
##       'setxkbmap fr; godot --path . --rendering-driver opengl3 -s res://tools/display_probe.gd'
## Dev only: tools/ never ships.

const SECOND := 1.0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _say(what: String, result: String) -> void:
	print("[probe] ", what, ": ", result)


func _mode_name(m: int) -> String:
	return ["windowed", "minimized", "maximized", "fullscreen", "exclusive fullscreen"][m]


## The frames a second drawn over `seconds` of real time.
func _measure(seconds: float) -> float:
	var start := Time.get_ticks_msec()
	var n := 0
	while float(Time.get_ticks_msec() - start) < seconds * 1000.0:
		await process_frame
		n += 1
	return float(n) / (float(Time.get_ticks_msec() - start) / 1000.0)


func _key(code: Key, alt: bool = false) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		e.alt_pressed = alt
		Input.parse_input_event(e)
		await _frames(3)


func _run() -> void:
	_say("display server", "%s, screens %d, size %s, refresh %.1f Hz" % [DisplayServer.get_name(),
			DisplayServer.get_screen_count(), DisplayServer.screen_get_size(), DisplayServer.screen_get_refresh_rate()])
	await _frames(10)
	var s := Settings.new()
	s.window_mode = Settings.WindowMode.WINDOWED
	# window modes through the real DisplayServer
	_say("start mode", _mode_name(DisplayServer.window_get_mode()))
	for pick: Settings.WindowMode in [Settings.WindowMode.BORDERLESS, Settings.WindowMode.EXCLUSIVE,
			Settings.WindowMode.WINDOWED]:
		SettingsApply.pick_window_mode(s, pick)
		await _frames(20)
		_say("window mode %s" % Settings.WindowMode.keys()[pick], "the display server reports %s, size %s" % [
				_mode_name(DisplayServer.window_get_mode()), DisplayServer.window_get_size()])
	# V-Sync read back
	for on: bool in [false, true]:
		s.vsync = on
		SettingsApply.apply_display(s)
		await _frames(5)
		_say("V-Sync %s" % on, "reads back %s" % DisplayServer.window_get_vsync_mode())
	# F11 and Alt+Enter through the real WindowWatch
	var watch := WindowWatch.new()
	watch.settings = s
	watch.save_path = "user://display-probe.save"
	root.add_child(watch)
	s.window_mode = Settings.WindowMode.WINDOWED
	s.last_fullscreen = Settings.WindowMode.BORDERLESS
	await _key(KEY_F11)
	_say("F11 from a window", "settings %s, display %s" % [Settings.WindowMode.keys()[s.window_mode],
			_mode_name(DisplayServer.window_get_mode())])
	await _key(KEY_F11)
	_say("F11 again", "settings %s, display %s" % [Settings.WindowMode.keys()[s.window_mode],
			_mode_name(DisplayServer.window_get_mode())])
	await _key(KEY_ENTER, true)
	_say("Alt+Enter from a window", "settings %s, display %s" % [Settings.WindowMode.keys()[s.window_mode],
			_mode_name(DisplayServer.window_get_mode())])
	await _key(KEY_ENTER, true)
	_say("Alt+Enter again", "settings %s, display %s" % [Settings.WindowMode.keys()[s.window_mode],
			_mode_name(DisplayServer.window_get_mode())])
	DirAccess.remove_absolute("user://display-probe.save")
	# the frame rate, in front and in the background
	s.vsync = false
	s.frame_limit = Settings.UNLIMITED
	SettingsApply.set_menus(s, false)
	SettingsApply.set_focused(s, true)
	var front := await _measure(SECOND)
	_say("frame rate in front, no limit", "%.0f fps, Engine.max_fps %d" % [front, Engine.max_fps])
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	# the watch's own notification is only sent to it: send it there as the window would
	watch.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var back := await _measure(SECOND)
	_say("frame rate in the background", "%.0f fps, Engine.max_fps %d (wanted DisplayConfig.background_fps %d)" % [
			back, Engine.max_fps, SettingsApply.screens().config.background_fps])
	watch.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var again := await _measure(SECOND)
	_say("frame rate back in front", "%.0f fps, Engine.max_fps %d" % [again, Engine.max_fps])
	s.frame_limit = 60
	SettingsApply.apply_frame_rate(s)
	_say("frame limit 60", "%.0f fps, Engine.max_fps %d" % [await _measure(SECOND), Engine.max_fps])
	# key names in the layout the X server holds
	var q := KeyNames.name_of(KEY_Q)
	var a := KeyNames.name_of(KEY_A)
	var w := KeyNames.name_of(KEY_W)
	var m := KeyNames.name_of(KEY_SEMICOLON)
	_say("key names", "physical Q prints %s, A prints %s, W prints %s, the key right of L prints %s (DisplayServer says Q->%s)" % [
			q, a, w, m, OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(KEY_Q))])
	_say("keyboard layout", "%s (%s)" % [DisplayServer.keyboard_get_layout_name(
			DisplayServer.keyboard_get_current_layout()), DisplayServer.keyboard_get_layout_count()])
	watch.queue_free()
	await _frames(2)
	quit()
