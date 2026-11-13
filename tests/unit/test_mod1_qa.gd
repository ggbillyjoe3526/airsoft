extends GutTest
## MOD1: the Match page lists Attack / Defend, Elimination, Practice (top to bottom); a field without a pole falls back
## to Elimination, the Range to Practice.


func _page() -> MatchPage:
	var page := MatchPage.new(MatchPicks.new(), Settings.new())
	add_child_autofree(page)
	return page


func test_the_mode_cards_list_attack_defend_elimination_plant_the_bomb_then_practice() -> void:
	var page := _page()
	var box: Node = page.mode_card("elimination").get_parent()
	var names := PackedStringArray()
	for card in box.get_children():
		names.append(card.name)
	assert_eq(names, PackedStringArray(["Mode_attack_defend", "Mode_elimination", "Mode_plant_the_bomb",
			"Mode_practice"]))


func test_a_field_without_a_pole_falls_back_to_elimination() -> void:
	var page := _page()
	page._poles["depot"] = false
	page._pick_map("depot")
	assert_eq(page.picks.mode, MatchOptions.MODE_ELIMINATION)


func test_the_range_offers_and_picks_practice() -> void:
	var page := _page()
	page._pick_map("range")
	assert_eq(page.picks.mode, MatchOptions.MODE_PRACTICE)
	assert_eq(MatchOptions.modes_offered(MapCatalog.shared().find("range")), PackedStringArray(["practice"]))
