extends GutTest
## UB3 (William's Beta 2 playtest, 2026-11-20): every prompt is the action, then the key in brackets, in capitals
## ("OPEN DOOR [G]"); Remove's question opens in a panel beside the loadout card's menu, not at the strip's far right.

func _hud() -> Hud:
	var you := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.size = Vector2(1920.0, 1080.0)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	return hud


func test_the_door_and_lift_prompts_read_action_then_key() -> void:
	var hud := _hud()
	var key := KeyNames.of_action(&"use_door").to_upper()
	hud.set_door_prompt(Hud.DoorPrompt.OPEN)
	assert_eq(hud.door_prompt_text(), "OPEN DOOR [%s]" % key)
	hud.set_door_prompt(Hud.DoorPrompt.SHUT)
	assert_eq(hud.door_prompt_text(), "CLOSE DOOR [%s]" % key)
	hud.set_door_prompt(Hud.DoorPrompt.LIFT_CALL)
	assert_eq(hud.door_prompt_text(), "CALL LIFT [%s]" % key)
	hud.set_door_prompt(Hud.DoorPrompt.LIFT_TO, "Ticket hall")
	assert_eq(hud.door_prompt_text(), "GO TO TICKET HALL [%s]" % key)


func test_the_vault_climb_and_reload_prompts_read_action_then_key() -> void:
	var jump := KeyNames.of_action(&"jump").to_upper()
	assert_eq(Hud.vault_words(), "VAULT [%s]" % jump)
	assert_eq(Hud.vault_words(true), "CLIMB [%s]" % jump)
	var reload := HudReloadPrompt.new()
	add_child_autofree(reload)
	assert_eq(reload.text(), "RELOAD [%s]" % KeyNames.of_action(PlayerInput.RELOAD).to_upper())
	assert_eq(reload.key_text(), KeyNames.of_action(PlayerInput.RELOAD))


# --- Remove beside the menu ---

func _strip(count: int) -> LoadoutStrip:
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	while saved.slots.size() < count:
		saved.create()
	var strip := LoadoutStrip.new(saved)
	strip.position = Vector2(100.0, 100.0)
	add_child_autofree(strip)
	return strip


func test_remove_asks_in_a_panel_beside_the_open_menu() -> void:
	var strip := _strip(2)
	await wait_physics_frames(2)
	strip.open_menu(1, Vector2(20.0, 20.0))
	await wait_physics_frames(2)
	var menu := strip.menu()
	assert_true(menu.visible)
	menu.id_pressed.emit(LoadoutStrip.MenuItem.REMOVE)
	await wait_physics_frames(2)
	var panel := strip.confirm_panel()
	assert_not_null(panel)
	assert_true(panel.visible, "the question is up")
	assert_true(menu.visible, "the menu stays up beside it")
	assert_eq(strip.mode, LoadoutStrip.Mode.REMOVING)
	assert_string_contains(strip.prompt_text(), strip.saved.carried().name)
	assert_eq(panel.position.x, menu.position.x + menu.size.x + LoadoutStrip.CONFIRM_GAP, "right beside the menu")
	assert_eq(panel.position.y + panel.size.y, menu.position.y + menu.size.y, "its foot level with the menu's")
	assert_true(panel.is_ancestor_of(strip.action(&"remove_yes")), "Remove is in the panel")
	assert_true(panel.is_ancestor_of(strip.action(&"keep")), "Keep is in the panel")


func test_keep_it_or_a_click_off_shuts_the_panel_and_the_menu_and_keeps_the_loadout() -> void:
	var strip := _strip(2)
	await wait_physics_frames(2)
	strip.open_menu(1, Vector2(20.0, 20.0))
	strip.menu().id_pressed.emit(LoadoutStrip.MenuItem.REMOVE)
	strip.action(&"keep").pressed.emit()
	assert_eq(strip.mode, LoadoutStrip.Mode.NORMAL)
	assert_false(strip.confirm_panel().visible)
	assert_false(strip.menu().visible)
	assert_eq(strip.saved.slots.size(), 2)
	strip.open_menu(1, Vector2(20.0, 20.0))
	strip.menu().id_pressed.emit(LoadoutStrip.MenuItem.REMOVE)
	strip.confirm_panel().hide() # a click off it, or Esc
	assert_eq(strip.mode, LoadoutStrip.Mode.NORMAL, "kept")
	assert_false(strip.menu().visible)
	assert_eq(strip.saved.slots.size(), 2)


func test_remove_it_removes_and_shuts_both() -> void:
	var strip := _strip(3)
	await wait_physics_frames(2)
	strip.open_menu(2, Vector2(20.0, 20.0))
	strip.menu().id_pressed.emit(LoadoutStrip.MenuItem.REMOVE)
	strip.action(&"remove_yes").pressed.emit()
	assert_eq(strip.saved.slots.size(), 2)
	assert_false(strip.confirm_panel().visible)
	assert_false(strip.menu().visible)


func test_another_row_shuts_the_menu_as_before() -> void:
	var strip := _strip(2)
	await wait_physics_frames(2)
	strip.open_menu(0, Vector2(20.0, 20.0))
	strip.menu().id_pressed.emit(LoadoutStrip.MenuItem.DUPLICATE)
	assert_false(strip.menu().visible)
	assert_eq(strip.saved.slots.size(), 3)


func test_remove_asked_with_no_menu_up_opens_under_the_carried_card() -> void:
	var strip := _strip(2)
	await wait_physics_frames(2)
	strip.start_remove()
	await wait_physics_frames(1)
	assert_true(strip.confirm_panel().visible)
	var c := strip.card(strip.saved.current)
	assert_almost_eq(float(strip.confirm_panel().position.y), c.get_screen_position().y + c.size.y, 1.0)
	strip.cancel()
	assert_false(strip.confirm_panel().visible)


# --- focus rings clear of the words (owner, 2026-11-20) ---

func test_the_clear_focus_ring_stands_outside_and_the_links_and_switch_use_it() -> void:
	var ring := GameTheme.focus_clear()
	var border := float(ring.border_width_left)
	assert_gt(ring.expand_margin_left, border, "the ring's inside edge is outside the words")
	assert_gt(ring.expand_margin_top, border)
	assert_eq(ring.expand_margin_left, ring.expand_margin_right)
	assert_eq(ring.expand_margin_top, ring.expand_margin_bottom)
	var link := GameTheme.get_theme().get_stylebox(&"focus", GameTheme.LINK_BUTTON) as StyleBoxFlat
	assert_eq(link.expand_margin_left, ring.expand_margin_left, "the quiet links' ring")
	var toggle := MenuToggle.new("WORDS", "")
	add_child_autofree(toggle)
	var own := toggle.get_theme_stylebox(&"focus") as StyleBoxFlat
	assert_eq(own.expand_margin_left, ring.expand_margin_left, "the switch with its words")


func test_the_remove_panels_links_have_room_for_the_ring_between_them() -> void:
	assert_gt(LoadoutStrip.ACTION_GAP, GameTheme.FOCUS_CLEAR_PAD.x * 2, "two rings never meet")
	assert_gt(LoadoutStrip.CONFIRM_PAD, GameTheme.FOCUS_CLEAR_PAD.x, "the ring stays inside the panel")
