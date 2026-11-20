extends GutTest
## UB3 QA: the Remove panel's lifecycle (menu and panel closing together, rebuilds while asking, the strip freed with
## the panel open), the haze switch's migration edges, and Spotted's longer reach staying inside what a ping reaches.


func _strip(count: int) -> LoadoutStrip:
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	while saved.slots.size() < count:
		saved.create()
	var strip := LoadoutStrip.new(saved)
	strip.position = Vector2(100.0, 100.0)
	add_child_autofree(strip)
	return strip


func _ask_remove(strip: LoadoutStrip, index: int) -> void:
	strip.open_menu(index, Vector2(20.0, 20.0))
	strip.menu().id_pressed.emit(LoadoutStrip.MenuItem.REMOVE)


func test_the_panel_is_connected_once_however_often_remove_is_asked() -> void:
	var strip := _strip(3)
	await wait_physics_frames(2)
	for i in 4:
		_ask_remove(strip, 1)
		strip.cancel()
	_ask_remove(strip, 1)
	var panel := strip.confirm_panel()
	assert_eq(panel.popup_hide.get_connections().size(), 1, "one popup_hide connection, not one per ask")
	assert_eq(panel.get_parent(), strip)
	var count := 0
	for child in strip.get_children(true):
		if child is PopupPanel:
			count += 1
	assert_eq(count, 1, "one panel, built once")


func test_a_rebuild_while_asking_keeps_the_panel_and_its_links_live() -> void:
	var strip := _strip(3)
	await wait_physics_frames(2)
	_ask_remove(strip, 1)
	# another slot appears while the question is up (a signature change rebuilds the strip)
	strip.saved.create()
	strip.refresh()
	await wait_physics_frames(2)
	assert_eq(strip.mode, LoadoutStrip.Mode.REMOVING)
	var yes := strip.action(&"remove_yes")
	assert_true(is_instance_valid(yes))
	assert_true(strip.confirm_panel().is_ancestor_of(yes))
	assert_eq(strip.confirm_panel().get_child(0).find_children("*", "Button", true, false).size(), 2,
			"the old links are gone, two stand")
	var before := strip.saved.slots.size()
	yes.pressed.emit()
	assert_eq(strip.saved.slots.size(), before - 1)
	assert_eq(strip.mode, LoadoutStrip.Mode.NORMAL)


func test_the_menu_shut_alone_while_asking_does_not_strand_the_question() -> void:
	var strip := _strip(2)
	await wait_physics_frames(2)
	_ask_remove(strip, 1)
	await wait_physics_frames(2)
	strip.menu().hide() # Esc on the menu's own focus, or a click off it
	await wait_physics_frames(2)
	# either the question went with it (mode back to normal) or it still stands with a live mode; never a shown
	# panel with the strip not asking, nor an asking strip with nothing on screen
	var panel_up := strip.confirm_panel().visible
	var asking := strip.mode == LoadoutStrip.Mode.REMOVING
	assert_eq(panel_up, asking, "panel up if and only if the strip is asking")


func test_esc_in_the_strip_while_asking_shuts_both_and_keeps_the_loadout() -> void:
	var strip := _strip(2)
	await wait_physics_frames(2)
	_ask_remove(strip, 1)
	assert_true(strip.cancel())
	assert_false(strip.confirm_panel().visible)
	assert_false(strip.menu().visible)
	assert_eq(strip.saved.slots.size(), 2)
	assert_false(strip.cancel(), "nothing more to leave")


func test_remove_asked_with_one_loadout_opens_nothing() -> void:
	var strip := _strip(1)
	await wait_physics_frames(2)
	strip.start_remove()
	assert_eq(strip.mode, LoadoutStrip.Mode.NORMAL)
	assert_true(strip.confirm_panel() == null or not strip.confirm_panel().visible)


func test_the_disabled_remove_row_opens_no_question() -> void:
	var strip := _strip(1)
	await wait_physics_frames(2)
	strip.open_menu(0, Vector2(20.0, 20.0))
	assert_true(strip.menu_disabled(LoadoutStrip.MenuItem.REMOVE))
	strip.menu().id_pressed.emit(LoadoutStrip.MenuItem.REMOVE)
	assert_false(strip.menu().visible, "a dead row shuts the menu as any other")
	assert_eq(strip.mode, LoadoutStrip.Mode.NORMAL)


func test_the_strip_freed_with_the_panel_open_leaves_no_nodes_behind() -> void:
	var before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	saved.create()
	var strip := LoadoutStrip.new(saved)
	add_child(strip)
	await wait_physics_frames(2)
	_ask_remove(strip, 1)
	await wait_physics_frames(2)
	strip.free()
	await wait_physics_frames(2)
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), before, "every node went with the strip")


func test_asking_again_after_a_remove_opens_a_fresh_question() -> void:
	var strip := _strip(3)
	await wait_physics_frames(2)
	_ask_remove(strip, 2)
	strip.action(&"remove_yes").pressed.emit()
	assert_eq(strip.saved.slots.size(), 2)
	_ask_remove(strip, 0)
	assert_true(strip.confirm_panel().visible)
	assert_string_contains(strip.prompt_text(), strip.saved.carried().name)


# --- the haze switch's migration ---

func test_a_version_six_file_moves_its_custom_haze_level_to_on_and_keeps_its_hud_choices() -> void:
	var data := {"graphics_custom": {"volumetric_fog": "medium"}, "gauge_pattern": "stripes", "hud_opacity": 0.9}
	var moved := Settings.migrate_defaults(data, 6)
	assert_eq(moved["graphics_custom"]["volumetric_fog"], "on")
	assert_eq(moved["hud_opacity"], 0.9, "a v6 player's own HUD choices are not reset again")
	assert_eq(moved["gauge_pattern"], "stripes")
	assert_eq(data["graphics_custom"]["volumetric_fog"], "medium", "the input is not changed")


func test_every_older_version_moves_each_level_and_leaves_off_and_on() -> void:
	for version: int in [1, 2, 3, 4, 5, 6]:
		for level: String in ["low", "medium", "high"]:
			var moved := Settings.migrate_defaults({"graphics_custom": {"volumetric_fog": level}}, version)
			assert_eq(moved["graphics_custom"]["volumetric_fog"], "on", "v%d %s" % [version, level])
		for kept: String in ["off", "on"]:
			var moved := Settings.migrate_defaults({"graphics_custom": {"volumetric_fog": kept}}, version)
			assert_eq(moved["graphics_custom"]["volumetric_fog"], kept, "v%d %s" % [version, kept])


func test_the_current_version_and_odd_custom_values_are_left_alone() -> void:
	var now := {"graphics_custom": {"volumetric_fog": "high"}}
	assert_eq(Settings.migrate_defaults(now, Settings.VERSION), now, "a v7 file is trusted as it is")
	for odd: Variant in [null, 5, "high", [], {"volumetric_fog": 2}, {"volumetric_fog": null}]:
		var moved := Settings.migrate_defaults({"graphics_custom": odd}, 6)
		assert_eq(moved["graphics_custom"], odd, "odd value kept: %s" % str(odd))
	assert_eq(Settings.migrate_defaults({}, 6), {}, "no custom table at all")


func test_the_haze_is_off_or_on_in_every_preset_and_the_choice_list() -> void:
	assert_eq(GraphicsQuality.CHOICES[GraphicsQuality.VOLUMETRIC_FOG], ["off", "on"])
	assert_eq(GraphicsQuality.VolumetricFog.size(), 2)


# --- Spotted's reach ---

func test_the_new_prompts_have_no_leftover_old_words() -> void:
	for key: String in ["HUD_DOOR_OPEN", "HUD_DOOR_SHUT", "HUD_LIFT_CALL", "HUD_LIFT_TO", "HUD_VAULT", "HUD_CLIMB",
			"HUD_RELOAD", "HUD_BOMB_PICK_UP", "HUD_BOMB_PLANT", "HUD_BOMB_DEFUSE"]:
		var words := HudStyle.prompt_words(StringName(key), ["X", "G"] if key == "HUD_LIFT_TO" else "G")
		assert_ne(words, key, "%s is translated" % key)
		assert_eq(words, words.to_upper(), "%s is in capitals" % key)
		assert_true(words.contains("[") and words.ends_with("]"), "%s ends with the key in brackets: %s" % [key, words])


func test_a_stop_name_with_a_percent_sign_does_not_break_the_lift_prompt() -> void:
	var words := HudStyle.prompt_words(&"HUD_LIFT_TO", ["50% off hall", "G"])
	assert_eq(words, "GO TO 50% OFF HALL [G]")
