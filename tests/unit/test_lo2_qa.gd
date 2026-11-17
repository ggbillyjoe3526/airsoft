extends GutTest
## QA probes for the Loadout and Customise screens (LO2): what a player can do to the strip, the page and the menus
## around it that the worker's own tests do not reach.

const LOADOUTS := "user://test_lo2_qa_loadouts.save"
const SETTINGS := "user://test_lo2_qa_settings.save"
const AEG := "000002"
const LIPO := "000015"

var saved: SavedLoadouts
var settings: Settings


func before_each() -> void:
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)
	saved = SavedLoadouts.new(LoadoutRules.standard())
	settings = Settings.new()


func after_each() -> void:
	await wait_process_frames(2)
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)


func _page() -> LoadoutPage:
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	return page


func _key(code: Key, ctrl: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.ctrl_pressed = ctrl
	return e


func test_looking_at_the_pages_changes_and_saves_nothing() -> void:
	var page := _page()
	page.show_customise(0)
	for t: CustomiseView.Tab in [CustomiseView.Tab.BBS, CustomiseView.Tab.POWER, CustomiseView.Tab.COLOUR]:
		page.customise().show_tab(t)
	page.show_gear()
	page.gear().carried_card(Loadout.Slot.SECONDARY).pressed.emit()
	page.show_customise()
	page.customise().show_tab(CustomiseView.Tab.BBS)
	assert_false(saved.dirty, "only looking: nothing edited, nothing to write")
	assert_eq(saved.carried().tunes.size(), 0, "no tune was written by the sliders being set to show the value")


func test_a_huge_or_negative_slider_value_is_snapped_into_range() -> void:
	var page := _page()
	page.show_customise(0)
	page.customise().show_tab(CustomiseView.Tab.BBS)
	page._set_weight(99.0)
	page._set_hop_up(-5.0)
	var t := saved.rules.tune_of(saved.carried(), AEG)
	assert_eq(t.bb_weight, saved.rules.snap_bb_weight(99.0))
	assert_between(t.bb_weight, 0.01, 1.0)
	assert_between(t.hop_up, 0.0, 1.0)


func test_leaving_the_page_mid_rename_keeps_the_name_typed() -> void:
	var menus := MenuScreen.new(null, settings)
	add_child_autofree(menus)
	menus.show_loadout()
	var page := menus.loadout_page()
	page.save_path = LOADOUTS
	var shared := page.saved
	var before := shared.carried().name
	page.strip().start_rename()
	page.strip().edit().text = "Mid Rename"
	menus.show_match()
	await wait_process_frames(2)
	assert_null(menus.loadout_page())
	assert_eq(shared.carried().name, "Mid Rename", "a name typed and left by changing tab is kept, as a click elsewhere keeps it")
	shared.rename(shared.current, before)
	shared.dirty = false


func test_escape_in_rename_drops_the_typed_name_and_a_blank_one_keeps_the_old() -> void:
	var page := _page()
	var strip := page.strip()
	strip.start_rename()
	strip.edit().text = "Typed"
	assert_true(page.back_out())
	await wait_process_frames(2)
	assert_eq(saved.carried().name, "Loadout 1", "Esc cancels the rename")
	strip.start_rename()
	strip.edit().text = "   "
	strip.edit().text_submitted.emit("   ")
	assert_eq(saved.carried().name, "Loadout 1", "an empty name is refused")
	assert_eq(strip.mode, LoadoutStrip.Mode.NORMAL)


func test_a_long_name_is_cut_and_five_loadouts_close_the_new_card() -> void:
	var page := _page()
	for i in 4:
		page.strip().new_card().pressed.emit()
	assert_eq(saved.slots.size(), 5)
	assert_null(page.strip().new_card(), "no sixth loadout is offered")
	page.strip().open_menu(saved.current)
	assert_true(page.strip().menu_disabled(LoadoutStrip.MenuItem.DUPLICATE))
	page.strip().pick(LoadoutStrip.MenuItem.DUPLICATE)
	assert_eq(saved.slots.size(), 5, "a greyed item does nothing")
	page.strip().menu().hide()
	page.strip().start_rename()
	var long := "A".repeat(60)
	page.strip().edit().text_submitted.emit(long)
	assert_eq(saved.carried().name.length(), SavedLoadouts.NAME_MAX)
	assert_eq(saved.create(), -1)


func test_removing_the_last_loadout_is_never_possible_and_removal_needs_the_confirm() -> void:
	var page := _page()
	page.strip().start_remove()
	assert_eq(page.strip().mode, LoadoutStrip.Mode.NORMAL, "the only loadout cannot be removed")
	page.strip().open_menu(0)
	assert_true(page.strip().menu_disabled(LoadoutStrip.MenuItem.REMOVE))
	saved.create()
	page.strip().open_menu(saved.current)
	page.strip().pick(LoadoutStrip.MenuItem.REMOVE)
	assert_eq(saved.slots.size(), 2, "asking is not removing")
	assert_true(page.back_out(), "Esc backs out of the question")
	assert_eq(saved.slots.size(), 2)
	page.strip().open_menu(saved.current)
	page.strip().pick(LoadoutStrip.MenuItem.REMOVE)
	page.strip().action(&"remove_yes").pressed.emit()
	assert_eq(saved.slots.size(), 1)
	assert_eq(saved.current, 0)
	page.strip().open_menu(0)
	assert_true(page.strip().menu_disabled(LoadoutStrip.MenuItem.REMOVE))
	page.strip().menu().hide()


func test_keys_do_nothing_with_a_modifier_or_while_asking() -> void:
	saved.create()
	var page := _page()
	page.strip().start_remove()
	page._unhandled_input(_key(KEY_1))
	assert_eq(saved.current, 1, "no switching while a question is open")
	page.strip().cancel()
	page._unhandled_input(_key(KEY_1, true))
	assert_eq(saved.current, 1, "Ctrl+1 is not the 1 key")


func test_opening_and_leaving_the_page_again_and_again_leaks_no_nodes() -> void:
	var menus := MenuScreen.new(null, settings)
	add_child_autofree(menus)
	menus.show_loadout()
	menus.loadout_page().show_customise(0)
	menus.show_match()
	await wait_process_frames(3)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 3:
		menus.show_loadout()
		menus.loadout_page().show_customise(0)
		await wait_process_frames(2)
		menus.show_match()
		await wait_process_frames(3)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no nodes are left over: the kept page lets its Customise viewports go")
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans)
	assert_null(menus.loadout_page())


func test_the_pictures_paint_again_after_a_match_cleared_the_shared_paints() -> void:
	var page := _page()
	var key := StringName(page.facts().item(Loadout.Slot.PRIMARY).key)
	assert_not_null(page.pictures().texture(key, &"signal", false))
	ReplicaPaint.clear()
	var again := LoadoutPage.new(saved, settings)
	again.save_path = LOADOUTS
	add_child_autofree(again)
	again.show_customise(0)
	await wait_process_frames(2)
	assert_gt(again.pictures().count(), 0)
	assert_not_null(again.pictures().texture(key, &"signal", false))


func test_a_capped_sheet_shows_the_limit_and_the_carried_weights_energy_may_sit_a_little_above_it() -> void:
	saved.rules.stats.site_limits[&"rifle"] = 0.5
	var page := _page()
	saved.rules.set_bb_weight(saved.carried(), AEG, 0.4)
	saved.mark_changed()
	var sheet := page.facts().sheet(Loadout.Slot.PRIMARY)
	assert_true(sheet.capped)
	assert_eq(sheet.limit, 0.5, "the limit is shown")
	# the limit caps the rated energy on the replica's own BBs (docs/records/LO1.md); a heavier BB carries a little more
	var energy := float(sheet.row(&"energy").text)
	assert_gte(energy, sheet.limit - 0.005)
	assert_lt(energy, sheet.limit * 1.1, "only a little above it")
	assert_true(page.gear().sheet().capped_line().contains("own BBs"), "and the words say so")
