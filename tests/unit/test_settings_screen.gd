extends GutTest
## The settings screen (game/ui/settings_screen.gd) and the pause menu's way to it: a change applies at once and is
## saved by the time the screen closes, rebinding refuses or swaps a clash, and no key or click used in the menus
## reaches PlayerInput.

const ROOT := "user://test-settings-screen"

var dir := ""
var _n := 0
var tuning: PlayTuning = null
var s: Settings = null
var screen: SettingsScreen = null


func before_each() -> void:
	_n += 1
	dir = "%s/%d" % [ROOT, _n]
	_wipe(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	tuning = PlayTuning.new()
	s = Settings.new(tuning)
	screen = SettingsScreen.new()
	screen.settings = s
	screen.save_path = dir.path_join("settings.save")
	add_child_autofree(screen)
	screen.open()


func after_each() -> void:
	SettingsApply.use_screens(null)
	Engine.max_fps = 0
	InputMap.load_from_project_settings()
	Input.action_release(&"aim")
	get_tree().paused = false


func after_all() -> void:
	_wipe(ROOT)


func _wipe(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p):
		return
	for d: String in DirAccess.get_directories_at(p):
		_wipe(p.path_join(d))
	for f: String in DirAccess.get_files_at(p):
		DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	return e


func test_it_starts_hidden_in_a_scene_and_opens_with_the_settings() -> void:
	var fresh := SettingsScreen.new()
	fresh.settings = s
	add_child_autofree(fresh)
	assert_false(fresh.visible)
	fresh.open()
	assert_true(fresh.visible)


func test_a_slider_applies_at_once_and_is_saved_on_close() -> void:
	screen._sensitivity.value = 2.5
	assert_eq(tuning.controls.sensitivity, 2.5, "applied at once")
	screen._volume[&"Effects"].value = 40.0
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Effects")), linear_to_db(0.4), 1e-3)
	screen._display_page.fov().value = 100.0
	assert_eq(tuning.view.horizontal_fov_16x9, 100.0)
	assert_false(FileAccess.file_exists(screen.save_path), "a slider is saved a moment later")
	screen.close()
	assert_true(FileAccess.file_exists(screen.save_path), "the last value is never lost on close")
	var t := Settings.new(PlayTuning.new())
	t.load_file(screen.save_path)
	assert_almost_eq(t.sensitivity, 2.5, 1e-6)
	assert_almost_eq(t.volumes[&"Effects"], 0.4, 1e-6)
	assert_almost_eq(t.fov, 100.0, 1e-6)
	SettingsApply.apply_audio(Settings.new(tuning))


func test_a_click_setting_is_saved_straight_away() -> void:
	screen._invert.button_pressed = true
	assert_true(tuning.controls.invert_y)
	assert_true(FileAccess.file_exists(screen.save_path))
	screen._crouch.button(1).pressed.emit()
	screen._aim.button(1).pressed.emit()
	assert_true(tuning.controls.crouch_toggle and tuning.controls.aim_toggle)


func test_the_reload_row_starts_on_manual_and_switches_to_automatic() -> void:
	# a choice of two words, MANUAL then AUTOMATIC, like Crouch and Aim (UI1)
	assert_eq(screen._auto_reload.selected(), 0, "Manual by default (RL2)")
	assert_eq(screen._auto_reload.button(0).text, "MANUAL")
	screen._auto_reload.button(1).pressed.emit()
	assert_eq(screen._auto_reload.selected(), 1)
	assert_true(s.auto_reload)
	assert_true(tuning.controls.auto_reload)
	var back := Settings.new()
	back.load_file(screen.save_path)
	assert_true(back.auto_reload, "saved straight away")


func test_a_typed_cm_per_360_sets_the_sensitivity() -> void:
	screen._dpi.value = 800.0
	screen._cm.value = 40.0
	var rpc := tuning.controls.radians_per_count
	assert_almost_eq(Sensitivity.cm_per_360(rpc, s.sensitivity, 800.0), 40.0, 0.01)
	assert_eq(tuning.controls.sensitivity, s.sensitivity, "and it applies")
	screen._dpi.value = 1600.0
	assert_almost_eq(screen._cm.value, 20.0, 0.01, "twice the DPI is half the travel")
	screen._cm.value = 0.5
	assert_eq(s.sensitivity, Sensitivity.MAX, "held to the range")


func test_the_window_vsync_and_fps_rows_change_the_settings() -> void:
	var ds := _fake_screens()
	var page := screen._display_page
	page.window_choice().button(Settings.WindowMode.EXCLUSIVE).pressed.emit()
	assert_eq(s.window_mode, Settings.WindowMode.EXCLUSIVE)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, "applied at once")
	assert_true(FileAccess.file_exists(screen.save_path), "and saved")
	page.window_choice().button(Settings.WindowMode.WINDOWED).pressed.emit()
	page.vsync().button_pressed = false
	assert_false(s.vsync)
	assert_eq(ds.vsync_mode, DisplayServer.VSYNC_DISABLED)
	page.show_fps().button_pressed = true
	assert_true(s.show_fps)


func test_a_load_message_shows_on_the_screen() -> void:
	s.load_message = "Your saved settings could not be read"
	screen.open()
	assert_true(screen._load_message.visible)
	assert_eq(screen._load_message.text, s.load_message)


func test_esc_closes_it_and_back_closes_it() -> void:
	screen.esc_closes = true # as the pause menu opens it; in the menus Esc asks to quit instead
	watch_signals(screen)
	get_viewport().push_input(_key(KEY_ESCAPE))
	assert_false(screen.visible, "Esc closes")
	assert_signal_emitted(screen, "closed")
	screen.open()
	screen._back.pressed.emit()
	assert_false(screen.visible, "Back closes")


func test_rebinding_swaps_a_clash_and_applies_at_once() -> void:
	screen._keys.begin(&"reload", 0)
	assert_true(screen._keys.capturing())
	get_viewport().push_input(_key(KEY_C))
	assert_false(screen._keys.capturing())
	assert_eq(Array(s.bindings.codes(&"reload")), [KEY_C])
	assert_eq(Array(s.bindings.codes(&"crouch")), [KEY_R, KEY_CTRL], "the two swapped")
	assert_eq((InputMap.action_get_events(&"reload")[0] as InputEventKey).physical_keycode, KEY_C as Key)
	assert_true(FileAccess.file_exists(screen.save_path), "saved")
	assert_ne(screen._note.text, "", "and the screen says what happened")


func test_rebinding_refuses_a_key_that_cannot_be_bound_and_keeps_waiting() -> void:
	screen._keys.begin(&"reload", 0)
	get_viewport().push_input(_key(KEY_F3))
	assert_true(screen._keys.capturing(), "the player can try another key")
	assert_eq(Array(s.bindings.codes(&"reload")), [KEY_R])
	get_viewport().push_input(_key(KEY_ESCAPE))
	assert_false(screen._keys.capturing(), "Esc cancels the wait")
	assert_true(screen.visible, "and doesn't close the screen")
	assert_eq(Array(s.bindings.codes(&"reload")), [KEY_R])


func test_rebinding_refuses_stranding_fire_and_backspace_clears() -> void:
	s.bindings.unbind(&"move_forward", 1)
	screen._keys.begin(&"jump", 1)
	get_viewport().push_input(_key(KEY_W))
	assert_eq(Array(s.bindings.codes(&"move_forward")), [KEY_W], "Move forward keeps its only key")
	assert_true(screen._keys.capturing())
	get_viewport().push_input(_key(KEY_BACKSPACE))
	assert_eq(Array(s.bindings.codes(&"jump")), [KEY_SPACE], "an empty slot has nothing to clear")
	screen._keys.begin(&"jump", 0)
	get_viewport().push_input(_key(KEY_BACKSPACE))
	assert_eq(Array(s.bindings.codes(&"jump")), [], "Backspace clears a key")


func test_a_mouse_button_can_be_bound() -> void:
	screen._keys.begin(&"reload", 1)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_XBUTTON1
	e.pressed = true
	get_viewport().push_input(e)
	assert_eq(Array(s.bindings.codes(&"reload")), [KEY_R, -MOUSE_BUTTON_XBUTTON1])


func test_reset_keys_restores_the_defaults() -> void:
	s.bindings.rebind(&"reload", KEY_X)
	screen._keys.reset_all()
	assert_eq(Array(s.bindings.codes(&"reload")), [KEY_R])


# --- nothing reaches play ---

func _input_node() -> PlayerInput:
	var input := PlayerInput.new()
	input.setup(ControlsConfig.new(), 1.5)
	add_child_autofree(input)
	input.active = true
	return input


func test_a_key_taken_while_rebinding_does_not_reach_the_player_input() -> void:
	var input := _input_node()
	screen._keys.begin(&"reload", 0)
	get_viewport().push_input(_key(KEY_T))
	assert_eq(Array(s.bindings.codes(&"reload")), [KEY_T], "T is reload now")
	var cmd := PlayerCommand.new()
	input.fill(cmd)
	assert_false(cmd.reload, "the press that bound it is not a reload")
	# the key is the action from now on, once the menu is closed and play reads it
	screen.close()
	get_viewport().push_input(_key(KEY_T))
	input.fill(cmd)
	assert_true(cmd.reload, "a rebound key works in play at once")


func test_keys_the_screen_does_not_use_do_not_reach_the_player_input() -> void:
	var input := _input_node()
	var cmd := PlayerCommand.new()
	for code: Key in [KEY_R, KEY_B, KEY_SPACE, KEY_3, KEY_C]:
		get_viewport().push_input(_key(code))
	input.fill(cmd)
	assert_false(cmd.reload or cmd.cycle_fire_mode or cmd.holster, "menu keys are not play keys")
	assert_eq(cmd.jump, false)
	# with the screen gone the same key is a reload
	screen.close()
	get_viewport().push_input(_key(KEY_R))
	input.fill(cmd)
	assert_true(cmd.reload)


func test_a_click_on_the_screen_does_not_reach_the_player_input() -> void:
	var input := _input_node()
	await wait_process_frames(2)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(20, 20)
	click.global_position = click.position
	get_viewport().push_input(click)
	var cmd := PlayerCommand.new()
	input.fill(cmd)
	assert_false(cmd.fire, "a click on the menu doesn't fire")


func test_the_debug_keys_still_pass_while_the_screen_is_open() -> void:
	get_viewport().push_input(_key(KEY_Q))
	assert_true(get_viewport().is_input_handled(), "an ordinary key stops at the screen")
	get_viewport().push_input(_key(KEY_F3))
	assert_false(get_viewport().is_input_handled(), "F3 is left for the overlay")


# --- the aimed sensitivity ---

func test_aiming_scales_the_turn_by_the_aimed_sensitivity() -> void:
	var controls := ControlsConfig.new()
	controls.aim_sensitivity = 0.5
	var input := PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true
	var move := InputEventMouseMotion.new()
	move.screen_relative = Vector2(100.0, 0.0)
	move.relative = move.screen_relative
	input._unhandled_input(move)
	var hip := input.view_yaw
	input.view_yaw = 0.0
	Input.action_press(&"aim")
	input._unhandled_input(move)
	Input.action_release(&"aim")
	assert_almost_eq(input.view_yaw, hip * 0.5, 1e-6)


# --- the pause menu ---

func test_the_pause_menu_has_resume_settings_and_leave() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	var texts: Array[String] = []
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).visible:
			texts.append((b as Button).text)
	assert_eq(texts, ["RESUME", "SETTINGS", "QUIT MATCH", "REPORT A BUG"],
			"Skip to next round only while you are out (WG1); Report a Bug at the foot (SV5)")
	assert_ne(tr("PAUSE_SETTINGS"), "PAUSE_SETTINGS")


func test_the_pause_menu_opens_the_settings_while_paused_and_esc_closes_only_them() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	var resumed := [0]
	menu.resumed.connect(func() -> void: resumed[0] += 1)
	menu.open()
	get_tree().paused = true
	menu.open_settings()
	assert_true(menu.settings_open())
	get_viewport().push_input(_key(KEY_ESCAPE))
	assert_false(menu.settings_open(), "Esc closes the settings, working while paused")
	assert_true(menu.visible, "and the pause menu stays")
	assert_eq(resumed[0], 0, "the same Esc doesn't also resume")


# --- the FPS readout and the title screen ---

func test_the_fps_readout_follows_the_setting() -> void:
	var fps := FpsReadout.new(s)
	add_child_autofree(fps)
	assert_false(fps.shown(), "off by default")
	s.show_fps = true
	s.mark_changed()
	assert_true(fps.shown())
	await wait_process_frames(2)
	var label: Label = fps.get_child(0)
	assert_true(label.text.begins_with("FPS "), "it reads a frame rate: %s" % label.text)
	s.show_fps = false
	s.mark_changed()
	assert_false(fps.shown())


func test_the_fps_readout_leaves_no_connection_behind() -> void:
	var before := s.changed.get_connections().size()
	var fps := FpsReadout.new(s)
	add_child(fps)
	assert_eq(s.changed.get_connections().size(), before + 1)
	fps.free()
	assert_eq(s.changed.get_connections().size(), before)


func test_the_menus_have_a_settings_tab_that_opens_the_screen() -> void:
	var main: Node = add_child_autofree(load("res://game/main.tscn").instantiate())
	await wait_process_frames(2)
	var button: Button = null
	for b in main.find_children("*", "Button", true, false):
		if (b as Button).text == tr("MENU_TAB_SETTINGS"):
			button = b
	assert_not_null(button, "a Settings button")
	assert_null(_settings_child(main._menus), "not built until asked for")
	button.pressed.emit()
	var opened := _settings_child(main._menus)
	assert_not_null(opened)
	assert_true(opened.visible)
	opened.close()
	await wait_process_frames(1)
	assert_null(_settings_child(main._menus), "freed once closed")


func _settings_child(parent: Node) -> SettingsScreen:
	for c in parent.get_children():
		if c is SettingsScreen and not c.is_queued_for_deletion():
			return c
	return null


# --- Graphics (GR2) ---

func _graphics() -> SettingsGraphicsPage:
	return screen._graphics_page


func _probe(preset: StringName, method: String = "forward_plus") -> GraphicsPick.Probe:
	var p := GraphicsPick.Probe.new()
	p.preset = preset
	p.rendering_method = method
	p.driver = "vulkan"
	p.adapter_name = "Test Card"
	p.adapter_type = RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
	return p


## A second Graphics page on the screen's settings, for a machine `p`.
func _page_with(p: GraphicsPick.Probe) -> SettingsGraphicsPage:
	var page := SettingsGraphicsPage.new()
	page.probe = p
	screen.add_child(page)
	page.build(screen)
	page.refresh()
	return page


func _saved() -> Settings:
	var t := Settings.new(PlayTuning.new())
	t.load_file(screen.save_path)
	return t


## The button for `choice_name` on row `id`'s line.
func _choice_button(page: SettingsGraphicsPage, id: StringName, choice_name: String) -> Button:
	var line := page.line(id)
	return line.choice.button(line.levels.find(GraphicsQuality.CHOICES[id].find(choice_name)))


func test_the_graphics_tab_sits_between_display_and_hud() -> void:
	var names := PackedStringArray()
	for i in screen._tabs.get_tab_count():
		names.append(screen._tabs.get_tab_title(i))
	var at := names.find(tr("SETTINGS_GRAPHICS").to_upper())
	assert_gt(at, 0)
	assert_eq(names[at - 1], tr("SETTINGS_DISPLAY").to_upper())
	assert_eq(names[at + 1], tr("SETTINGS_HUD").to_upper())


func test_while_automatic_the_tab_says_so_and_tags_the_card_s_pick() -> void:
	var page := _graphics()
	var pick := GraphicsTable.PRESETS.find(page.probe.preset)
	assert_eq(s.graphics_choice, Settings.GRAPHICS_AUTOMATIC)
	assert_string_starts_with(page.blurb(), "Automatic")
	assert_eq(page.preset_choice().selected(), pick, "the pick is lit")
	assert_eq(page.tagged(), page.preset_choice().button(pick), "For your card on the pick")
	for id in GraphicsQuality.ROWS:
		assert_false(page.line(id).marked(), "%s unmarked" % id)


func test_choosing_a_preset_draws_it_at_once_and_saves_the_choice() -> void:
	var page := _graphics()
	page.preset_choice().button(GraphicsTable.PRESETS.find(&"ultra")).pressed.emit()
	assert_eq(s.graphics_choice, &"ultra")
	assert_true(GraphicsApply.server().drawn.equals(GraphicsTable.shared().preset(&"ultra")), "drawn at once")
	assert_eq(get_tree().root.msaa_3d, Viewport.MSAA_DISABLED, "edge smoothing is off on every preset")
	assert_eq(_saved().graphics_choice, &"ultra", "saved at once")
	assert_string_starts_with(page.blurb(), "Ultra:")


func test_changing_a_row_makes_custom_on_the_preset_you_were_on_and_marks_it() -> void:
	var page := _graphics()
	page.preset_choice().button(GraphicsTable.PRESETS.find(&"high")).pressed.emit()
	_choice_button(page, GraphicsQuality.AMBIENT_OCCLUSION, "full").pressed.emit()
	assert_eq(s.graphics_choice, GraphicsQuality.CUSTOM)
	assert_eq(s.graphics_base, &"high")
	assert_eq(page.preset_choice().selected(), GraphicsTable.PRESETS.size(), "Custom lit")
	for id in GraphicsQuality.ROWS:
		assert_eq(page.line(id).marked(), id == GraphicsQuality.AMBIENT_OCCLUSION, "%s marked only if changed" % id)
	assert_string_contains(page.blurb(), "Custom: High with 1 change")
	assert_eq(GraphicsApply.server().drawn.ambient_occlusion, GraphicsQuality.AmbientOcclusion.FULL, "drawn at once")
	var saved := _saved()
	assert_eq(saved.graphics_choice, GraphicsQuality.CUSTOM)
	assert_eq(saved.graphics_custom, {"ambient_occlusion": "full"} as Dictionary[String, Variant])


func test_reset_goes_back_to_the_card_s_pick() -> void:
	var page := _graphics()
	_choice_button(page, GraphicsQuality.MESH_DETAIL, "ultra").pressed.emit()
	assert_eq(s.graphics_choice, GraphicsQuality.CUSTOM)
	assert_string_contains(page.reset_button().text, tr("GRAPHICS_PRESET_" + String(page.probe.preset).to_upper())
			.to_upper())
	page.reset_button().pressed.emit()
	assert_eq(s.graphics_choice, Settings.GRAPHICS_AUTOMATIC)
	assert_true(s.graphics_custom.is_empty())
	assert_false(page.line(GraphicsQuality.MESH_DETAIL).marked())
	assert_eq(_saved().graphics_choice, Settings.GRAPHICS_AUTOMATIC)
	assert_true(GraphicsApply.server().drawn.equals(GraphicsApply.values_for(s, page.probe)))


func test_every_row_shows_its_cost_from_the_table() -> void:
	var page := _graphics()
	for id in GraphicsQuality.ROWS:
		var squares := page.line(id).row.get_child(-1) as SettingsGraphicsPage.CostSquares
		assert_not_null(squares, "%s has squares" % id)
		assert_eq(squares.cost(), GraphicsTable.shared().row(id).cost, "%s's cost" % id)


func test_a_slider_applies_when_it_is_let_go() -> void:
	var page := _graphics()
	page.preset_choice().button(GraphicsTable.PRESETS.find(&"high")).pressed.emit()
	assert_true(page.line(GraphicsQuality.UPSCALER).dimmed(), "the upscaler is greyed at 100 %")
	var slider := page.line(GraphicsQuality.RENDER_SCALE).slider
	slider.drag_started.emit()
	slider.value = 70.0
	assert_eq(s.graphics_choice, &"high", "nothing applied while held")
	slider.drag_ended.emit(true)
	assert_eq(s.graphics_choice, GraphicsQuality.CUSTOM)
	assert_eq(s.graphics_in_force(page.probe.preset).render_scale, 70)
	assert_almost_eq(get_tree().root.scaling_3d_scale, 0.7, 0.001, "drawn on release")
	assert_false(page.line(GraphicsQuality.UPSCALER).dimmed(), "the upscaler works below 100 %")
	page.preset_choice().button(GraphicsTable.PRESETS.find(&"high")).pressed.emit()


func test_the_simpler_renderer_greys_what_it_can_t_draw() -> void:
	var page := _page_with(_probe(&"low", "gl_compatibility"))
	assert_false(_choice_button(page, GraphicsQuality.UPSCALER, "bilinear").disabled)
	assert_true(_choice_button(page, GraphicsQuality.UPSCALER, "fsr1").disabled, "no FSR 1")
	assert_true(_choice_button(page, GraphicsQuality.UPSCALER, "fsr2").disabled, "no FSR 2")
	assert_true(_choice_button(page, GraphicsQuality.EDGE_SMOOTHING, "smaa").disabled, "no SMAA")
	assert_false(_choice_button(page, GraphicsQuality.EDGE_SMOOTHING, "msaa_4x").disabled)
	assert_true(page.line(GraphicsQuality.TEMPORAL_SMOOTHING).check.disabled, "no TAA")
	assert_true(page.line(GraphicsQuality.TEMPORAL_SMOOTHING).dimmed())
	assert_true(page.line(GraphicsQuality.AMBIENT_OCCLUSION).dimmed(), "no SSAO")
	assert_false(page.line(GraphicsQuality.SUN_SHADOWS).dimmed())
	var forward := _page_with(_probe(&"high"))
	assert_false(_choice_button(forward, GraphicsQuality.UPSCALER, "fsr2").disabled, "Forward+ draws them all")


func test_your_system_names_the_card_the_renderer_and_the_screen() -> void:
	var lines := _page_with(_probe(&"high")).system_lines()
	assert_eq(lines[0], "Test Card · dedicated")
	assert_eq(lines[1], "Forward+ · Vulkan")
	assert_string_contains(lines[2], "monitor")
	var unknown := _probe(&"medium", "gl_compatibility")
	unknown.adapter_name = ""
	unknown.adapter_type = RenderingDevice.DEVICE_TYPE_OTHER
	unknown.driver = "opengl3"
	var other := _page_with(unknown).system_lines()
	assert_eq(other[0], "%s · %s" % [tr("GRAPHICS_UNKNOWN_CARD"), tr("GRAPHICS_TYPE_OTHER")])
	assert_eq(other[1], "Compatibility · OpenGL 3")


func test_the_launch_option_shows_on_the_tab() -> void:
	s.graphics_forced = &"low"
	screen.open()
	var page := _graphics()
	assert_string_starts_with(page.blurb(), "--graphics=low:")
	assert_eq(page.preset_choice().selected(), 0, "Low lit")
	s.graphics_forced = &""


# --- Display ---

## A stand-in for the window's calls with one screen (two with `two`), the screen opened again to show it.
func _fake_screens(two: bool = false) -> FakeScreens:
	var ds := FakeScreens.new()
	if two:
		ds.sizes = [Vector2i(2560, 1440), Vector2i(1920, 1080)]
		ds.rates = [144.0, 60.0]
	SettingsApply.use_screens(ds)
	screen.open()
	return ds


func _texts(choice: MenuChoice) -> PackedStringArray:
	var out := PackedStringArray()
	for b: Node in choice.get_children():
		out.append((b as Button).text)
	return out


func _labels(node: Node, into: PackedStringArray) -> PackedStringArray:
	if node is Label:
		into.append((node as Label).text)
	for c: Node in node.get_children():
		_labels(c, into)
	return into


func test_the_display_tab_has_the_concept_s_rows() -> void:
	_fake_screens()
	var page := screen._display_page
	assert_eq(_texts(page.window_choice()), PackedStringArray(["WINDOWED", "BORDERLESS", "FULLSCREEN"]),
			"short words on the buttons (UI1)")
	assert_eq(page.window_choice().selected(), Settings.WindowMode.EXCLUSIVE, "exclusive fullscreen by default")
	var words := " ".join(_labels(page, PackedStringArray()))
	for want: String in ["FRAME RATE", "V-SYNC",
			"FRAME-RATE LIMIT", "FIELD OF VIEW", "SHOW FPS"]:
		assert_string_contains(words, want)
	# the longer explanations are tooltips now (UI1), the keys too (UI1 round 1)
	for want: String in ["F11", "Alt", "Enter", "switches at any time"]:
		assert_string_contains(page.window_choice().button(0).tooltip_text, want)
	assert_string_contains(page.limit_choice().button(0).tooltip_text, "still plays at 60 ticks a second")
	assert_string_contains(page.limit_choice().button(0).tooltip_text, "In the background it draws 30")
	assert_eq(page.show_fps().tooltip_text, "Frames a second, bottom right.")
	assert_eq(_texts(page.limit_choice()), PackedStringArray(["30", "60", "120", "144", "165", "240", "360",
			"OFF"]))
	assert_eq(page.limit_choice().selected(), Settings.FRAME_LIMITS.size(), "Unlimited by default")
	assert_false(page.vsync().button_pressed, "V-Sync off by default (owner, 2026-10-29)")
	assert_eq(page.vsync_note(), "No tearing, at most the screen’s 144 a second. Off: a little less input delay.")
	assert_false(page.monitor_row().visible, "no Monitor row with one screen")
	assert_null(page.monitor_choice())


func test_the_monitor_row_shows_with_two_screens_and_moves_the_window() -> void:
	var ds := _fake_screens(true)
	var page := screen._display_page
	assert_true(page.monitor_row().visible)
	assert_eq(_texts(page.monitor_choice()), PackedStringArray(["1 · 2560 × 1440 · 144 HZ", "2 · 1920 × 1080 · 60 HZ"]))
	assert_eq(page.monitor_choice().selected(), 0, "the window's own screen lit")
	page.monitor_choice().button(1).pressed.emit()
	assert_eq(s.monitor, 1)
	assert_eq(ds.on, 1, "moved at once")
	assert_eq(_saved().monitor, 1, "and saved")
	assert_string_contains(page.vsync_note(), " 60 a second", "V-Sync's note names the new screen's rate")
	screen.open()
	assert_eq(page.monitor_choice().selected(), 1)
	ds.sizes.resize(1)
	ds.rates.resize(1)
	ds.on = 0
	screen.open()
	assert_false(page.monitor_row().visible, "a screen unplugged: the row goes")


func test_a_screen_with_no_rate_shows_its_size_only() -> void:
	var ds := FakeScreens.new()
	ds.sizes = [Vector2i(1920, 1080), Vector2i(1280, 1024)]
	ds.rates = [-1.0, 75.0]
	SettingsApply.use_screens(ds)
	screen.open()
	var page := screen._display_page
	assert_eq(_texts(page.monitor_choice()), PackedStringArray(["1 · 1920 × 1080", "2 · 1280 × 1024 · 75 HZ"]))
	assert_eq(page.vsync_note(), "No tearing, at most the screen’s rate. Off: a little less input delay.")


func test_a_frame_rate_limit_applies_at_once_and_is_saved() -> void:
	_fake_screens()
	var page := screen._display_page
	page.limit_choice().button(0).pressed.emit()
	assert_eq(s.frame_limit, 30)
	assert_eq(Engine.max_fps, 30)
	assert_eq(_saved().frame_limit, 30)
	page.limit_choice().button(Settings.FRAME_LIMITS.size()).pressed.emit()
	assert_eq(s.frame_limit, Settings.UNLIMITED)
	assert_eq(Engine.max_fps, 0)
	s.frame_limit = 165
	screen.open()
	assert_eq(page.limit_choice().selected(), Settings.FRAME_LIMITS.find(165))


func test_f11_switches_and_the_tab_follows_but_not_while_a_key_is_being_rebound() -> void:
	var ds := _fake_screens()
	s.last_fullscreen = Settings.WindowMode.BORDERLESS
	s.window_mode = Settings.WindowMode.WINDOWED # F11 from a window; the first start's mode is pinned elsewhere
	screen.open()
	var watch := WindowWatch.new()
	watch.settings = s
	watch.save_path = screen.save_path
	add_child_autofree(watch)
	move_child(watch, 0) # before the screen, as in the main scene
	screen._keys.begin(&"reload", 0)
	get_viewport().push_input(_key(KEY_F11))
	assert_eq(s.window_mode, Settings.WindowMode.WINDOWED, "the key list has it")
	assert_true(screen._keys.capturing(), "and refuses it: F11 can't be bound")
	var alt_enter := _key(KEY_ENTER)
	alt_enter.alt_pressed = true
	get_viewport().push_input(alt_enter)
	assert_eq(s.window_mode, Settings.WindowMode.WINDOWED)
	screen._keys.cancel()
	get_viewport().push_input(_key(KEY_F11))
	assert_eq(s.window_mode, Settings.WindowMode.BORDERLESS)
	assert_eq(ds.window_mode, DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_eq(screen._display_page.window_choice().selected(), Settings.WindowMode.BORDERLESS, "the tab follows")
	assert_eq(_saved().window_mode, Settings.WindowMode.BORDERLESS, "saved")
	get_viewport().push_input(alt_enter)
	assert_eq(screen._display_page.window_choice().selected(), Settings.WindowMode.WINDOWED)
	assert_true(screen.visible, "Enter didn't press anything on the screen")


func test_the_display_tab_leaves_no_connection_behind() -> void:
	var before := s.changed.get_connections().size()
	screen.get_parent().remove_child(screen)
	assert_lt(s.changed.get_connections().size(), before, "out of the tree: let go")
	add_child(screen)
	assert_eq(s.changed.get_connections().size(), before, "back: once again")


func test_the_menus_have_no_fullscreen_button() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	var words := " ".join(_labels(menus, PackedStringArray())).to_lower()
	for b: Node in menus.find_children("*", "Button", true, false):
		words += " " + (b as Button).text.to_lower()
	assert_false(words.contains("fullscreen"), words)


# --- Accessibility (AC2) ---

func _access() -> SettingsAccessPage:
	return screen._access_page


## Every label's and rich label's words under `node`, rich text without its tags.
## Every word `node` shows: its labels and, as help moved to them (UI1), its tooltips.
func _words(node: Node) -> String:
	var out := PackedStringArray()
	for n: Node in node.find_children("*", "", true, false):
		if n is Label:
			out.append((n as Label).text)
		elif n is RichTextLabel:
			out.append((n as RichTextLabel).get_parsed_text())
		if n is Control and (n as Control).tooltip_text != "":
			out.append((n as Control).tooltip_text)
	return " ".join(out)


func test_the_accessibility_tab_comes_after_hud() -> void:
	var names := PackedStringArray()
	for i in screen._tabs.get_tab_count():
		names.append(screen._tabs.get_tab_title(i))
	var at := names.find(tr("SETTINGS_ACCESSIBILITY").to_upper())
	assert_gt(at, 0)
	assert_eq(names[at - 1], tr("SETTINGS_HUD").to_upper())


func test_the_save_file_tab_comes_after_accessibility_then_about_then_dev() -> void:
	var names := PackedStringArray()
	for i in screen._tabs.get_tab_count():
		names.append(screen._tabs.get_tab_title(i))
	var at := names.find(tr("SETTINGS_SAVE_FILE").to_upper())
	assert_gt(at, 0)
	assert_eq(names[at - 1], tr("SETTINGS_ACCESSIBILITY").to_upper())
	assert_eq(names[at + 1], tr("SETTINGS_ABOUT").to_upper())
	assert_eq(names[at + 2], tr("SETTINGS_DEV").to_upper())


func test_about_shows_the_version_and_in_the_menus_the_title_screen_s_buttons() -> void:
	screen.show_about()
	assert_eq(screen._tabs.get_tab_title(screen.current_tab()), tr("SETTINGS_ABOUT").to_upper())
	var version := screen._about_page.find_child("Version", true, false) as Label
	assert_eq(version.text, Version.current())
	assert_null(screen.about_report_button(), "from the pause menu: no Report, Licences or Quit of About's own")
	var menus := SettingsScreen.new()
	menus.settings = s
	menus.save_path = screen.save_path
	menus.in_menus = true
	add_child_autofree(menus)
	watch_signals(menus)
	menus.about_report_button().pressed.emit()
	menus.about_credits_button().pressed.emit()
	menus.about_quit_button().pressed.emit()
	assert_signal_emit_count(menus, "report_requested", 1)
	assert_signal_emit_count(menus, "credits_requested", 1)
	assert_signal_emit_count(menus, "quit_requested", 1)


## From the menus (main gives the restart) the save may be replaced; from a match (End the round) or with no restart,
## not.
func test_the_save_may_be_replaced_only_from_the_menus() -> void:
	assert_false(screen.can_replace(), "no restart given")
	screen.restart = func() -> void: pass
	assert_true(screen.can_replace())
	screen.end_round = func() -> bool: return false
	assert_false(screen.can_replace(), "in a match")


func test_the_accessibility_tab_has_the_concept_s_rows() -> void:
	var page := _access()
	var words := _words(page)
	for want: String in ["TEAM COLOURS", "STANDARD", "HIGH CONTRAST", "IN USE", "#8ccfff", "#b8460c",
			"Blue and orange: they stay apart", "Light blue and dark orange, apart in lightness too",
			"From the next match.", "the figures when the next match starts", "GAUGE PATTERNS",
			"Stripes as well as colour", "SCREEN READER MESSAGES", "Reads hit calls, your hit and round results",
			"SOUND CUES", "Red is the default.", "Two dots a step (up to 22 m)",
			"Arrowhead a shot (up to 60 m)", "HIT tag a hit call (up to 60 m)", "Shown through walls", "REDUCED MOTION",
			"Follow system uses your computer's", "Off: the replica sways", "On: no weapon sway or drifting dust",
			"The recoil climb stays", "Your system asks for reduced motion: It doesn't say"]:
		assert_string_contains(words, want)
	# the switches' row labels, in capitals as every row label is (UI1)
	for want: String in ["PATTERNS", "READ OUT", "SHOW CUES"]:
		assert_string_contains(words, want)
	assert_eq(_texts(page.motion()), PackedStringArray(["FOLLOW SYSTEM", "OFF", "ON"]))
	assert_eq(page.cue_colour().selected(), AccessibilityConfig.CUE_COLOUR_DEFAULT, "red by default")
	assert_true(page.set_card(TeamColours.Set.STANDARD).is_picked(), "Standard by default")
	assert_false(page.set_card(TeamColours.Set.HIGH_CONTRAST).is_picked())
	page._show_system(1)
	assert_string_contains(_words(page), "reduced motion: Yes")
	page._show_system(0)
	assert_string_contains(_words(page), "reduced motion: No")


func test_the_rows_of_later_tasks_are_greyed_with_later() -> void:
	var page := _access()
	assert_false(page.greyed(SettingsAccessPage.Section.TEAM_COLOURS), "the team colours are live")
	for section: SettingsAccessPage.Section in SettingsAccessPage.Section.values():
		assert_eq(page.greyed(section), SettingsAccessPage.LATER.has(section), str(section))
	assert_eq(page.read_out().mouse_filter, Control.MOUSE_FILTER_STOP, "screen reader messages are live (AC6)")
	assert_eq(page.patterns().mouse_filter, Control.MOUSE_FILTER_STOP, "gauge patterns are live (AC3)")
	assert_eq(page.set_card(TeamColours.Set.HIGH_CONTRAST).mouse_filter, Control.MOUSE_FILTER_STOP)


func test_the_tab_s_rows_map_to_the_settings_fields_and_save_at_once() -> void:
	var page := _access()
	page.set_card(TeamColours.Set.HIGH_CONTRAST).pressed.emit()
	assert_eq(s.team_colours, TeamColours.Set.HIGH_CONTRAST)
	assert_false(s.dirty, "a click saves at once")
	assert_eq(_saved().team_colours, TeamColours.Set.HIGH_CONTRAST)
	assert_true(page.set_card(TeamColours.Set.HIGH_CONTRAST).is_picked())
	assert_false(page.set_card(TeamColours.Set.STANDARD).is_picked())
	page.patterns().toggled.emit(false)
	assert_false(s.gauge_patterns)
	page.read_out().toggled.emit(false)
	assert_false(s.read_out)
	page.cues().toggled.emit(true)
	assert_true(s.sound_cues)
	page.cue_colour().button(2).pressed.emit()
	assert_eq(s.sound_cue_colour, 2)
	page.motion().button(Settings.ReducedMotion.ON).pressed.emit()
	assert_eq(s.reduced_motion, Settings.ReducedMotion.ON)
	assert_false(s.dirty)
	page.cue_size().value = 150.0
	assert_almost_eq(s.sound_cue_size, 1.5, 0.001)
	screen.close()
	var saved := _saved()
	assert_false(saved.gauge_patterns)
	assert_false(saved.read_out)
	assert_true(saved.sound_cues)
	assert_eq(saved.sound_cue_colour, 2)
	assert_almost_eq(saved.sound_cue_size, 1.5, 0.001)
	assert_eq(saved.reduced_motion, Settings.ReducedMotion.ON)


func test_the_tab_shows_the_saved_choices_on_opening() -> void:
	s.team_colours = TeamColours.Set.HIGH_CONTRAST
	s.sound_cues = true
	s.sound_cue_size = 0.6
	s.reduced_motion = Settings.ReducedMotion.OFF
	screen.open()
	var page := _access()
	assert_true(page.set_card(TeamColours.Set.HIGH_CONTRAST).is_picked())
	assert_true(page.cues().button_pressed)
	assert_almost_eq(page.cue_size().value, 60.0, 0.001)
	assert_eq(page.motion().selected(), Settings.ReducedMotion.OFF)


func test_the_hud_tab_s_preview_and_samples_follow_the_set_picked() -> void:
	var hud_tab := screen._hud_page.get_parent().get_parent().get_index()
	screen._tabs.current_tab = hud_tab
	await wait_process_frames(1)
	var page := screen._hud_page
	var today := PlayTuning.new().teams.colours
	assert_almost_eq(page.preview().feed_row()._bar.b, today[0].b, 1.0 / 255.0, "Standard's blue")
	assert_true(page._thumbs[0].built())
	screen._tabs.current_tab = _access().get_parent().get_parent().get_index()
	_access().set_card(TeamColours.Set.HIGH_CONTRAST).pressed.emit()
	screen._tabs.current_tab = hud_tab
	await wait_process_frames(1)
	var hc := TeamColours.resolve(TeamColours.Set.HIGH_CONTRAST, false).hud
	assert_eq(page.preview().feed_row()._bar, hc.colours[0], "the feed line in High contrast")
	for thumb in page._thumbs:
		assert_eq(thumb._view._team, hc.colours[0], "the minimap sample's team")
		assert_eq(thumb._view._enemy, hc.colours[1])
