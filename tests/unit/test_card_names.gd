extends GutTest
## AC6 (BP7 row 62): a screen reader hears a name for every card on the Match page (maps, modes, teams, bots, rules)
## and the Loadout (loadouts, replicas, parts) and for the menus' choices outside Settings. A card is named by its own
## words (MenuCard.spoken_words) as the reader asks, unless its builder named it (Customise's paint tiles); a choice by
## its row.

const LOADOUTS := "user://test-bp7-card-names-loadouts.save"
const SETTINGS := "user://test-bp7-card-names-settings.save"


func after_each() -> void:
	await wait_process_frames(2)
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)


## Every MenuCard and MenuChoice under `root` that shows: those with no spoken name, as "path: what".
func _unnamed(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for card: MenuCard in root.find_children("*", "MenuCard", true, false):
		if not card.is_visible_in_tree():
			continue
		card.name_by_words()
		if card.accessibility_name.strip_edges() == "":
			out.append("%s: card" % root.get_path_to(card))
	for choice: MenuChoice in root.find_children("*", "MenuChoice", true, false):
		if choice.is_visible_in_tree() and choice.accessibility_name.strip_edges() == "":
			out.append("%s: choice" % root.get_path_to(choice))
	# any other button the keyboard reaches says something: its words or a name
	for b: BaseButton in root.find_children("*", "BaseButton", true, false):
		if b is MenuCard or not b.is_visible_in_tree() or b.focus_mode == Control.FOCUS_NONE:
			continue
		var words := (b as Button).text if b is Button else ""
		if words.strip_edges() == "" and b.accessibility_name.strip_edges() == "":
			out.append("%s: button" % root.get_path_to(b))
	return out


func test_a_card_is_named_by_its_words_and_keeps_a_name_its_builder_gave() -> void:
	var card := MenuCard.new()
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "DEPOT"
	var line := Label.new()
	line.text = "Elimination · 5v5"
	var hidden := Label.new()
	hidden.text = "LOCKED"
	hidden.visible = false
	box.add_child(title)
	box.add_child(line)
	box.add_child(hidden)
	card.add_content(box)
	add_child_autofree(card)
	assert_eq(card.accessibility_name, "DEPOT, Elimination · 5v5", "named as it enters the tree; hidden words left out")
	title.text = "WOODLAND"
	assert_true(card.name_by_words(), "words changed: so does the name")
	assert_eq(card.accessibility_name, "WOODLAND, Elimination · 5v5")
	var named := MenuCard.new()
	named.accessibility_name = "Safety yellow"
	named.add_content(box.duplicate())
	add_child_autofree(named)
	assert_false(named.name_by_words())
	assert_eq(named.accessibility_name, "Safety yellow", "a builder's name stays")
	var words := MenuCard.new()
	words.text = "ALPHA"
	add_child_autofree(words)
	assert_eq(words.accessibility_name, "ALPHA", "a card of words alone")


func test_every_card_and_choice_on_the_match_page_has_a_name() -> void:
	var page := MatchPage.new(MatchPicks.new(), Settings.new())
	add_child_autofree(page)
	await wait_process_frames(2)
	assert_gt(page.find_children("*", "MenuCard", true, false).size(), 5, "a real page")
	assert_eq(_unnamed(page), PackedStringArray())
	var depot := page.map_card("depot")
	depot.name_by_words()
	assert_string_contains(depot.accessibility_name.to_lower(), "depot", "a map card says its map")


func test_every_card_and_choice_on_the_loadout_and_in_customise_has_a_name() -> void:
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	saved.create()
	var page := LoadoutPage.new(saved, Settings.new())
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	await wait_process_frames(2)
	assert_eq(_unnamed(page), PackedStringArray(), "the Loadout")
	page.show_customise(0)
	await wait_process_frames(2)
	var view := page.customise()
	for t in CustomiseView.Tab.size():
		if t > 1 and not view.part_available(t as CustomiseView.Tab):
			continue
		view.show_tab(t as CustomiseView.Tab)
		await wait_process_frames(1)
		assert_eq(_unnamed(page), PackedStringArray(), "Customise tab %d" % t)


func test_the_menus_rail_armory_and_pause_menu_have_no_unnamed_button() -> void:
	var host := Control.new()
	host.size = Vector2(1920.0, 1080.0)
	add_child_autofree(host)
	var menus := MenuScreen.new()
	host.add_child(menus)
	await wait_process_frames(2)
	assert_eq(_unnamed(menus), PackedStringArray(), "the Match page and the rail")
	menus.show_armory()
	await wait_process_frames(2)
	assert_eq(_unnamed(menus), PackedStringArray(), "the Armory")
	var pause := PauseMenu.new()
	add_child_autofree(pause)
	await wait_process_frames(1)
	if pause.has_method("open"):
		pause.call("open")
	await wait_process_frames(1)
	assert_eq(_unnamed(pause), PackedStringArray(), "the pause menu")
