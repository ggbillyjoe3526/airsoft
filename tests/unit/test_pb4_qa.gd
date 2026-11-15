extends GutTest
## PB4 QA: the fuse reaching the match through the paths the worker's file leaves open: map switches on the Match
## page, an unused page, Practice, a Custom size, the shared tuning never written, and a column in another place.

const HEAD := "# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Fuse (s) | Blurb |\n" \
		+ "|---|---|---|---|---|---|---|---|---|\n"


func _page(map_id: String, mode: String) -> MatchPage:
	var picks := MatchPicks.new()
	picks.map_id = map_id
	picks.mode = mode
	var page := MatchPage.new(picks, Settings.new())
	add_child_autofree(page)
	return page


func _says(map_id: String) -> String:
	var fuse := MatchOptions.fuse_time(MapCatalog.shared().find(map_id), SimTuning.load_default().plant.fuse_time)
	return "An armed bomb goes off after %s s on this field." % MatchOptions.seconds_text(fuse)


func test_switching_map_in_plant_the_bomb_rewrites_the_fuse_note() -> void:
	var page := _page("woodland", MatchOptions.MODE_PLANT_THE_BOMB)
	assert_eq(page.rules_box().flag_note_text(), _says("woodland"))
	page._pick_map("depot")
	assert_eq(page.rules_box().flag_note_text(), _says("depot"), "Depot's own fuse, not Woodland's")
	assert_ne(_says("depot"), _says("woodland"), "the fields differ, or this proves nothing")


func test_an_unused_page_hides_the_fuse_note_and_coming_back_restores_it() -> void:
	var page := _page("depot", MatchOptions.MODE_PLANT_THE_BOMB)
	page.rules_box().set_unused(true)
	assert_eq(page.rules_box().flag_note_text(), "", "Practice: nothing under the rules")
	page.rules_box().set_unused(false)
	assert_eq(page.rules_box().flag_note_text(), _says("depot"))


func test_no_other_mode_shows_a_fuse_note_on_any_field() -> void:
	for e in MapCatalog.shared().entries:
		if e.kind != &"field":
			continue
		for mode: String in [MatchOptions.MODE_ATTACK_DEFEND, "elimination"]:
			assert_eq(MatchOptions.field_fuse(mode, e, 30.0), 0.0, "%s %s" % [e.id, mode])


func test_the_page_built_tuning_for_each_field_in_plant_the_bomb_carries_its_fuse() -> void:
	var base := SimTuning.load_default()
	var before := base.plant.fuse_time
	for e in MapCatalog.shared().entries:
		if e.kind != &"field":
			continue
		var picks := MatchPicks.new()
		picks.map_id = e.id
		picks.mode = MatchOptions.MODE_PLANT_THE_BOMB
		var t := MatchOptions.match_tuning(base, e, null)
		assert_eq(t.plant.fuse_time, MatchOptions.fuse_time(e, before), e.id)
		assert_ne(t.plant, base.plant if e.fuse_time > 0.0 else null, "%s: a copy, not the shared config" % e.id)
	assert_eq(base.plant.fuse_time, before, "the shared tuning is never written")
	assert_eq(SimTuning.load_default().plant.fuse_time, before)


func test_a_fuse_of_the_range_ends_is_read_and_a_field_without_one_plays_the_games() -> void:
	var m := MapCatalog.parse(HEAD + "| lo | Lo | field | public | 5 | 6 | 8 | 15 | A. |\n"
			+ "| hi | Hi | field | public | 5 | 6 | 8 | 60 | A. |\n| none | No | field | public | 5 | 6 | 8 | | A. |\n")
	assert_eq(m.problems, [] as Array[String])
	assert_eq(m.find("lo").fuse_time, 15.0)
	assert_eq(m.find("hi").fuse_time, 60.0)
	var base := SimTuning.load_default()
	assert_eq(MatchOptions.match_tuning(base, m.find("none"), null).plant.fuse_time, base.plant.fuse_time)
	assert_same(MatchOptions.match_tuning(base, m.find("none"), null).plant, base.plant, "unchanged: shared, not copied")


func test_a_bomb_armed_by_the_sim_on_a_fields_tuning_counts_down_from_its_fuse() -> void:
	var base := SimTuning.load_default()
	var depot := MapCatalog.shared().find("depot")
	var t := MatchOptions.match_tuning(base, depot, null)
	assert_lt(t.plant.fuse_time, base.plant.fuse_time)
	# Round's overtime ceiling is built from the same tuning: it must follow the field's fuse, not the game's.
	assert_eq(t.plant.max_overtime + t.plant.fuse_time, t.plant.max_overtime + depot.fuse_time)


func test_practice_tuning_keeps_the_games_fuse_and_leaves_the_shared_one_alone() -> void:
	var base := SimTuning.load_default()
	var p := PlaySession.practice_tuning(base)
	assert_eq(p.plant.fuse_time, base.plant.fuse_time)
	assert_eq(base.plant.fuse_time, SimTuning.load_default().plant.fuse_time)
