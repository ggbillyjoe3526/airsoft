extends GutTest
## The bug pass's menu fixes (BP3, second part): the pause menu's buttons out of reach under its settings, the QUIT
## GAME? prompt holding the Loadout page's number keys, and the crosshair sized on the view's own zoom.

const WINDOW := Vector2(1920.0, 1080.0)


func _host() -> Control:
	var host := Control.new()
	host.custom_minimum_size = WINDOW
	host.size = WINDOW
	add_child_autofree(host)
	return host


func test_under_its_settings_the_pause_menus_buttons_take_no_focus() -> void:
	var menu := PauseMenu.new()
	_host().add_child(menu)
	menu.open()
	menu.open_settings()
	await wait_process_frames(2)
	for b: Button in [menu._resume, menu._leave, menu._report_button, menu._settings_button]:
		assert_eq(b.focus_mode, Control.FOCUS_NONE, "%s: Tab can't reach it unseen" % b.text)
	menu._screen.close()
	await wait_process_frames(2)
	assert_eq(menu._resume.focus_mode, Control.FOCUS_ALL, "back once the settings close")
	assert_true(menu._settings_button.has_focus())


func test_the_quit_prompt_is_found_by_its_group_while_it_is_up() -> void:
	var prompt := QuitPrompt.new()
	_host().add_child(prompt)
	assert_eq(get_tree().get_node_count_in_group(QuitPrompt.GROUP), 1)
	prompt.close()
	await wait_process_frames(2)
	assert_eq(get_tree().get_node_count_in_group(QuitPrompt.GROUP), 0)


func test_from_settings_to_the_armory_by_the_rail_the_keyboard_has_somewhere_to_be() -> void:
	var main: Node = add_child_autofree(load("res://game/main.tscn").instantiate())
	await wait_process_frames(2)
	main._on_tab(NavRail.Tab.SETTINGS)
	await wait_process_frames(2)
	main._on_tab(NavRail.Tab.ARMORY)
	await wait_process_frames(2)
	var owner := get_viewport().gui_get_focus_owner()
	assert_not_null(owner, "something has the focus")
	if owner != null:
		assert_true(owner.is_visible_in_tree(), "and it shows")


func test_through_a_scope_the_crosshair_s_zoom_is_the_view_s_not_the_glass_s() -> void:
	var tuning := SimTuning.load_default()
	var rules := LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true
	var eyes := FirstPersonView.new()
	add_child_autofree(eyes)
	eyes.setup(ViewConfig.new(), tuning.body, tuning.hits)
	var input := PlayerInput.new()
	add_child_autofree(input)
	var l := rules.default_loadout("L")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, "000021"), "the Sniper Rifle, its 2x Scope as it comes")
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, rules.carried(l).replicas)
	c.aim_raise = 0.4
	eyes.update(c, input, 1.0, 1.0 / 60.0, c.aim_raise)
	assert_gt(input.zoom, eyes.view_zoom, "the turn follows the 2x glass")
	assert_lt(eyes.view_zoom, 1.5, "the crosshair, still drawn below half raised, keeps the view's own")
