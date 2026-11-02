extends GutTest
## Locked items on the Loadout and Customise (LV1; concept step11-armory `locked.png`): an item not unlocked yet is
## greyed with the level that unlocks it, and picking it changes nothing.

const LOADOUTS := "user://test_lv1_loadouts.save"
const SETTINGS := "user://test_lv1_settings.save"
const AEG := "000002"
const PISTOL := "000001"
const LIPO := "000015"
const STANDARD := "000003"
const RED_DOT := "000007"
const SCOPE := "000010"

var saved: SavedLoadouts
var settings: Settings
var progress: Progress


func before_each() -> void:
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)
	saved = SavedLoadouts.new(LoadoutRules.standard())
	settings = Settings.new()
	progress = Progress.new(LevelTable.read_file(Pool.read_file()))
	progress.add_xp(150)
	saved.rules.follow_progress(progress, false)


func after_each() -> void:
	await wait_process_frames(2)
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)


func _page(slot: int = 0) -> LoadoutPage:
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	page.show_customise(slot)
	return page


func _tags(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for t in node.find_children("Tag", "MenuTag", true, false):
		if (t as MenuTag).is_visible_in_tree():
			out.append((t as MenuTag).text())
	return out


func test_a_locked_optic_is_greyed_with_its_level_and_cannot_be_picked() -> void:
	var page := _page()
	var optics := page.customise().part_page(CustomiseView.Tab.OPTIC)
	page.customise().show_tab(CustomiseView.Tab.OPTIC)
	# None, Red Dot (level 1: unlocked at 150 XP), 2x Scope (level 7).
	assert_eq(optics.card_count(), 3)
	assert_false(optics.card(1).disabled)
	assert_eq(_tags(optics.card(1)), PackedStringArray())
	assert_true(optics.card(2).disabled)
	assert_eq(_tags(optics.card(2)), PackedStringArray(["LEVEL 7"]))
	optics.card(2).pressed.emit()
	assert_false(saved.rules.tune_of(saved.carried(), AEG).parts.has(&"optic"), "nothing picked")
	optics.card(1).pressed.emit()
	assert_eq(saved.rules.tune_of(saved.carried(), AEG).parts[&"optic"], RED_DOT)


func test_a_locked_power_source_is_greyed_with_its_level() -> void:
	var page := _page()
	page.customise().show_tab(CustomiseView.Tab.POWER)
	var lipo := page.customise().power_card(LIPO)
	assert_true(lipo.disabled)
	assert_eq(_tags(lipo), PackedStringArray(["LEVEL 8"]))
	assert_false(page.customise().power_card(STANDARD).disabled)


func test_a_locked_replica_is_greyed_with_its_level_in_the_list() -> void:
	var table := LevelTable.parse("""## Levels
| Level | XP | Unlocks |
|---|---|---|
| 0 | | AEG Rifle, Standard Battery, Green Gas |
| 1 | 100 | GBB Pistol |
""", saved.rules.pool)
	var fresh := Progress.new(table)
	saved.rules.follow_progress(fresh, false)
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	var card := page.gear().replica_card(PISTOL)
	assert_true(card.disabled)
	assert_eq(_tags(card), PackedStringArray(["LEVEL 1"]))
	assert_false(page.gear().replica_card(AEG).disabled)


func test_disable_levelling_unlocks_everything_on_the_page() -> void:
	saved.rules.follow_progress(progress, true)
	var page := _page()
	var optics := page.customise().part_page(CustomiseView.Tab.OPTIC)
	page.customise().show_tab(CustomiseView.Tab.OPTIC)
	assert_false(optics.card(2).disabled)
	assert_eq(_tags(optics.card(2)), PackedStringArray())


func test_an_open_loadout_page_is_built_again_when_levelling_changes_under_the_settings() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), settings)
	add_child_autofree(menus)
	menus.show_loadout()
	var page := menus.loadout_page()
	menus.show_level()
	assert_eq(menus.loadout_page(), page, "nothing changed: the same page")
	settings.dev.disable_levelling = true
	menus.show_level()
	assert_ne(menus.loadout_page(), page, "built again with everything unlocked")
	assert_eq(menus.nav_rail().level_text(), "", "no level chip while levelling is off")
	assert_false(menus.loadout_page().gear().replica_ids().is_empty())
	menus.leave_loadout()
