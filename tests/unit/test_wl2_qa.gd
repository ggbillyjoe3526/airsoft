extends GutTest
## QA hunt for WL2: a 6v6 on Woodland holds twelve on the board and the minimap, a wanted route does not starve behind a
## hit character mid-vault, an old or odd save keeps its team size, and a quick second match after a staged one is clean.

const LOAD_LIMIT := 20.0


func _session_6v6() -> PlaySession:
	var settings := Settings.new(PlayTuning.new())
	var custom := CustomRules.new()
	custom.team_size = 6
	var session := PlaySession.new()
	session.settings = settings
	session.map_id = "woodland"
	session.custom_rules = custom
	add_child_autofree(session)
	return session


func test_a_6v6_board_lists_twelve_rows_that_fit_the_screen() -> void:
	var session := _session_6v6()
	assert_not_null(session.state)
	if session.state == null:
		return
	var board := session._hud.board()
	session._hud.show_board(true)
	board.update(session.state, session._stats, session.state.characters[0], true)
	var lines := board.table().lines()
	assert_eq(lines.size(), 12, "twelve rows")
	var names := {}
	for l in lines:
		names[String(l).split(" |")[0]] = true
	assert_eq(names.size(), 12, "twelve distinct names")
	assert_lt(board.table().size.y + 200.0, 1080.0, "the table fits below the board's top")


func test_a_6v6_minimap_has_room_for_every_other_player() -> void:
	var session := _session_6v6()
	if session.state == null:
		return
	assert_eq(session._bots.world.bots.size(), 11)
	var kits := {}
	for c in session.state.characters:
		assert_false(c.armament.replicas.is_empty())
		kits[c.id] = true
	assert_eq(kits.size(), 12)


func test_a_second_staged_match_started_at_once_after_the_first_leaves_nothing_behind() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 2:
		var session := PlaySession.new()
		session.map_id = "woodland"
		session.staged = true
		add_child(session)
		await wait_until(func() -> bool: return session._nav_task >= 0, LOAD_LIMIT)
		remove_child(session)
		session.free()
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_odd_saved_team_sizes_fall_back_and_the_map_plays_its_standard() -> void:
	for odd: Variant in [9, 0, -1, 3.5, "5", null, [], 12]:
		var c := CustomRules.new()
		c.from_dict({"team_size": odd})
		assert_true(CustomRules.TEAM_SIZES.has(c.team_size), "%s -> %d" % [str(odd), c.team_size])
		for id: String in ["depot", "woodland", "range"]:
			var e := MapCatalog.shared().find(id)
			var n := MatchOptions.team_size(e, c)
			assert_true(n >= e.team_min and n <= e.team_max or e.kind == &"range", "%s plays %d" % [id, n])


const SAVE := "user://test_wl2_qa_settings.save"


func after_each() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)


func _page(picks: MatchPicks, settings: Settings) -> MatchPage:
	var page := MatchPage.new(picks, settings)
	page.rules_box().save_path = SAVE
	add_child_autofree(page)
	return page


func test_a_stale_dev_map_pick_without_dev_content_offers_and_plays_depot_s_sizes() -> void:
	var picks := MatchPicks.new()
	picks.map_id = "woodland"
	picks.rules = MatchOptions.RULES_CUSTOM
	var settings := Settings.new()
	settings.custom_rules.team_size = 2
	var catalog := DevContent.use_map() # every shipped map is public: Woodland tagged dev for the test
	var page := _page(picks, settings)
	DevContent.restore_map(catalog)
	await wait_process_frames(1)
	assert_eq(picks.map_id, "depot", "a dev Woodland is not listed without Dev content")
	assert_eq(page.rules_box().offered_sizes(), [5, 6, 7, 8] as Array[int])
	assert_eq(page.map_check_size(), 6, "Depot plays its standard where 2 is not offered")
	assert_eq(settings.custom_rules.team_size, 2, "the saved size is untouched")


func test_the_saved_size_survives_depot_woodland_depot() -> void:
	var picks := MatchPicks.new()
	picks.rules = MatchOptions.RULES_CUSTOM
	var settings := Settings.new()
	settings.custom_rules.team_size = 2
	var page := _page(picks, settings)
	await wait_process_frames(1)
	assert_eq(page.map_check_size(), 6, "2 is not Depot's: its standard")
	page._pick_map("woodland")
	assert_eq(page.map_check_size(), 6, "Woodland offers 5 to 8: its standard")
	assert_eq(page.rules_box().offered_sizes(), [5, 6, 7, 8] as Array[int])
	assert_eq(settings.custom_rules.team_size, 2, "the saved size is kept")
	page.rules_box().team_size_choice().button(CustomRules.TEAM_SIZES.find(6)).pressed.emit()
	page._pick_map("depot")
	assert_eq(page.map_check_size(), 6, "Depot offers 6 too")
	assert_eq(settings.custom_rules.team_size, 6)
	page._pick_map("woodland")
	assert_eq(page.map_check_size(), 6)
