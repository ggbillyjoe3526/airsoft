extends GutTest
## BP4, the menus: the SWITCH REPLICA pop-up gives the keyboard back to the SWITCH REPLICA it was opened from when it
## closes (it was left on nothing), and while it is open the keyboard can't stray to the controls hidden behind it.

const LOADOUTS := "user://test_bp4_menus_loadouts.save"
const SETTINGS := "user://test_bp4_menus_settings.save"
const CYBER := "000019"


func after_all() -> void:
	for path: String in [LOADOUTS, SETTINGS]:
		SaveFile.remove(path)


func _page() -> LoadoutPage:
	SaveFile.remove(LOADOUTS)
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.gui_disable_input = false
	add_child_autofree(view)
	var page := LoadoutPage.new(SavedLoadouts.new(LoadoutRules.standard()), Settings.new())
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	view.add_child(page)
	return page


func test_closing_the_pop_up_puts_the_keyboard_back_on_switch_replica() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	var view := page.get_viewport()
	for slot: Loadout.Slot in LoadoutFacts.SLOTS:
		gear.open_switch(slot)
		assert_true(gear.switcher().is_ancestor_of(view.gui_get_focus_owner()), "slot %d: the keyboard is in it" % slot)
		gear.close_switch()
		assert_eq(view.gui_get_focus_owner(), gear.switch_button(slot), "slot %d: CLOSE gives it back" % slot)
	gear.open_switch(Loadout.Slot.SECONDARY)
	assert_true(page.back_out(), "Esc closes it")
	assert_eq(view.gui_get_focus_owner(), gear.switch_button(Loadout.Slot.SECONDARY), "Esc gives it back")


func test_a_pick_puts_the_keyboard_back_on_switch_replica() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	gear.open_switch(Loadout.Slot.SECONDARY)
	gear.replica_card(CYBER).pressed.emit()
	await wait_process_frames(1)
	assert_false(gear.switching())
	assert_eq(page.get_viewport().gui_get_focus_owner(), gear.switch_button(Loadout.Slot.SECONDARY))


func test_the_keyboard_can_t_leave_the_open_pop_up_for_the_page_behind() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	var view := page.get_viewport()
	gear.open_switch(Loadout.Slot.PRIMARY)
	var inside := view.gui_get_focus_owner()
	gear.customise_button().grab_focus() # where Tab or an arrow off the panel's edge would go
	await wait_process_frames(1)
	assert_eq(view.gui_get_focus_owner(), inside, "back on the card it left")
	gear.switcher().close_button().grab_focus()
	gear.switch_button(Loadout.Slot.SECONDARY).grab_focus()
	await wait_process_frames(1)
	assert_eq(view.gui_get_focus_owner(), gear.switcher().close_button(), "back on CLOSE")
	gear.close_switch()
	gear.customise_button().grab_focus()
	await wait_process_frames(1)
	assert_eq(view.gui_get_focus_owner(), gear.customise_button(), "closed, the page has the keyboard again")


func test_customise_from_the_open_pop_up_keeps_the_keyboard_in_customise() -> void:
	var page := _page()
	await wait_process_frames(2)
	page.gear().open_switch(Loadout.Slot.PRIMARY)
	page.show_customise()
	await wait_process_frames(1)
	assert_false(page.gear().switching())
	var owner := page.get_viewport().gui_get_focus_owner()
	assert_not_null(owner)
	assert_true(owner.is_visible_in_tree(), "the keyboard is on something shown")
