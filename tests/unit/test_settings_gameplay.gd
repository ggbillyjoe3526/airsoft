extends GutTest
## BP7 (row 61, owner 2026-11-07): Settings has a Gameplay tab after Controls, holding how crouch, aim and reload work
## (from Controls) and What got you (from HUD). The settings are the fields they always were, so a file saved before
## loads into the new tab with nothing lost; each choice is named for a screen reader and takes keyboard focus.

const ROOT := "user://test-bp7-gameplay"

var screen: SettingsScreen = null
var s: Settings = null


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	s = Settings.new(PlayTuning.new())
	screen = _screen(s)


func after_each() -> void:
	SettingsApply.use_screens(null)
	InputMap.load_from_project_settings()
	for f: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(f))


func after_all() -> void:
	DirAccess.remove_absolute(ROOT)


func _screen(settings: Settings) -> SettingsScreen:
	var out := SettingsScreen.new()
	out.settings = settings
	out.save_path = ROOT.path_join("settings.save")
	add_child_autofree(out)
	out.open()
	return out


func _tab_of(c: Control) -> int:
	for t in screen._tabs.get_tab_count():
		if screen._tabs.get_tab_control(t).is_ancestor_of(c):
			return t
	return -1


func _gameplay() -> int:
	var names := PackedStringArray()
	for i in screen._tabs.get_tab_count():
		names.append(screen._tabs.get_tab_title(i))
	return names.find(tr("SETTINGS_GAMEPLAY").to_upper())


func test_gameplay_is_the_tab_after_controls() -> void:
	var at := _gameplay()
	assert_eq(at, 1, "second")
	assert_eq(screen._tabs.get_tab_title(at - 1), tr("SETTINGS_CONTROLS").to_upper())
	assert_eq(screen._tabs.get_tab_title(at + 1), tr("SETTINGS_AUDIO").to_upper())


func test_it_holds_crouch_aim_reload_and_what_got_you_and_controls_and_hud_do_not() -> void:
	var at := _gameplay()
	for choice: MenuChoice in [screen._crouch, screen._aim, screen._auto_reload, screen._what_got_you]:
		assert_eq(_tab_of(choice), at, "%s on Gameplay" % choice.accessibility_name)
	assert_eq(_tab_of(screen._wheel_pick), 0, "the order wheel stays on Controls")
	assert_eq(_tab_of(screen._sensitivity), 0, "the mouse stays on Controls")
	assert_false("_what_got_you" in screen._hud_page, "no What got you left on HUD")
	var moved := [tr("SETTINGS_CROUCH"), tr("SETTINGS_AIM"), tr("SETTINGS_RELOAD"), tr("SETTINGS_WHAT_GOT_YOU")]
	for t: int in [0, screen._hud_page.get_parent().get_parent().get_index()]:
		for choice: MenuChoice in screen._tabs.get_tab_control(t).find_children("*", "MenuChoice", true, false):
			assert_false(moved.has(choice.accessibility_name), "%s left on %s" % [choice.accessibility_name,
					screen._tabs.get_tab_title(t)])
	for label: Label in screen._tabs.get_tab_control(0).find_children("*", "Label", true, false):
		assert_ne(label.text, tr("SETTINGS_STANCE"), "no stance heading on Controls")


func test_a_saved_file_loads_into_the_gameplay_tab_with_nothing_lost() -> void:
	var saved := Settings.new(PlayTuning.new())
	saved.crouch_toggle = true
	saved.aim_toggle = true
	saved.auto_reload = true
	saved.what_got_you = Settings.WhatGotYou.OFF
	saved.sensitivity = 1.7
	saved.hud.minimap_zoom = 1.5
	var path := ROOT.path_join("before.save")
	assert_true(saved.save(path))
	var back := Settings.new(PlayTuning.new())
	back.load_file(path)
	var shown := _screen(back)
	assert_eq(shown._crouch.selected(), 1, "crouch: toggle")
	assert_eq(shown._aim.selected(), 1, "aim: toggle")
	assert_eq(shown._auto_reload.selected(), 1, "reload: automatic")
	assert_eq(shown._what_got_you.selected(), Settings.WhatGotYou.OFF)
	assert_eq(back.to_dict(), saved.to_dict(), "every setting as saved")
	# and a change on the new tab is saved where the old one was
	shown._what_got_you.button(Settings.WhatGotYou.ON).pressed.emit()
	shown._crouch.button(0).pressed.emit()
	var again := Settings.new(PlayTuning.new())
	again.load_file(shown.save_path)
	assert_eq(again.what_got_you, Settings.WhatGotYou.ON)
	assert_false(again.crouch_toggle)
	assert_true(again.aim_toggle and again.auto_reload, "the rest kept")


func test_each_choice_is_named_and_takes_focus_in_order() -> void:
	var names := {screen._crouch: "SETTINGS_CROUCH", screen._aim: "SETTINGS_AIM", screen._auto_reload: "SETTINGS_RELOAD",
			screen._what_got_you: "SETTINGS_WHAT_GOT_YOU", screen._simulate_skips: "SETTINGS_SIMULATE_SKIPS"}
	for choice: MenuChoice in names:
		assert_eq(choice.accessibility_name, tr(names[choice]), "a screen reader names it by its row")
		for b in choice.get_children():
			assert_ne((b as Button).focus_mode, Control.FOCUS_NONE)
	screen._tabs.current_tab = _gameplay()
	await wait_process_frames(2)
	var first := screen._crouch.get_child(0) as Button
	first.grab_focus()
	await wait_process_frames(1)
	# Tab walks the rows top to bottom: crouch's choices, then aim's, reload's, What got you's and Simulate's (BP8)
	var order: Array[MenuChoice] = [screen._crouch, screen._aim, screen._auto_reload, screen._what_got_you,
			screen._simulate_skips]
	var reached: Array[MenuChoice] = []
	var at: Control = first
	for i in 14:
		var parent := at.get_parent() as MenuChoice
		if parent != null and (reached.is_empty() or reached.back() != parent):
			reached.append(parent)
		var next := at.find_next_valid_focus()
		if next == null or next == first:
			break
		at = next
	assert_eq(reached, order, "every choice reached, in order")


func test_picking_what_got_you_saves_at_once() -> void:
	screen._what_got_you.button(Settings.WhatGotYou.OFF).pressed.emit()
	assert_eq(s.what_got_you, Settings.WhatGotYou.OFF)
	assert_false(s.dirty, "saved at once")
