extends GutTest
## MB3 QA: the raise cell's edge cases and the shared tuning left alone across matches on different fields.

const HEAD := "# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Raise (s) | Blurb |\n" \
		+ "|---|---|---|---|---|---|---|---|---|\n"


func _row(id: String, raise: String) -> String:
	return "| %s | %s | field | public | 5 | 6 | 8 | %s | A field. |\n" % [id, id.capitalize(), raise]


func test_a_raise_cell_with_a_decimal_or_spaces_reads_and_the_edges_are_in() -> void:
	var m := MapCatalog.parse(HEAD + _row("a", "9.0") + _row("b", " 9 ") + _row("c", "3") + _row("d", "20"))
	assert_eq(m.problems, [] as Array[String])
	assert_eq(m.find("a").raise_time, 9.0)
	assert_eq(m.find("b").raise_time, 9.0)
	assert_eq(m.find("c").raise_time, 3.0)
	assert_eq(m.find("d").raise_time, 20.0)


func test_a_raise_of_zero_keeps_the_games_with_a_problem() -> void:
	var m := MapCatalog.parse(HEAD + _row("a", "0"))
	assert_eq(m.find("a").raise_time, 0.0)
	assert_eq(m.problems.size(), 1)


func test_a_row_shorter_than_the_header_keeps_the_games_raise() -> void:
	var m := MapCatalog.parse(HEAD + "| a | A | field | public | 5 | 6 | 8 |\n")
	assert_not_null(m.find("a"))
	assert_eq(m.find("a").raise_time, 0.0)


func test_the_range_has_no_raise_and_plays_the_games_flag() -> void:
	var base := SimTuning.load_default()
	var range_entry := MapCatalog.shared().find("range")
	assert_eq(range_entry.raise_time, 0.0)
	assert_eq(MatchOptions.match_tuning(base, range_entry, null).flag.raise_time, base.flag.raise_time)


func test_woodland_then_depot_leaves_the_shared_flag_tuning_and_each_match_its_own() -> void:
	var base := SimTuning.load_default()
	var flag_before := base.flag
	var games := base.flag.raise_time
	var woodland := MatchOptions.match_tuning(base, MapCatalog.shared().find("woodland"), null)
	var depot := MatchOptions.match_tuning(base, MapCatalog.shared().find("depot"), null)
	assert_ne(woodland.flag, base.flag, "Woodland's flag tuning is a copy")
	assert_same(base.flag, flag_before)
	assert_eq(base.flag.raise_time, games)
	assert_eq(depot.flag.raise_time, games, "Depot after Woodland plays the game's")
	assert_eq(woodland.flag.raise_time, 9.0, "and Woodland is still 9")
	var again := MatchOptions.match_tuning(SimTuning.load_default(), MapCatalog.shared().find("depot"), null)
	assert_eq(again.flag.raise_time, games, "a fresh load is untouched")


func test_a_custom_match_on_woodland_does_not_write_the_loaded_flag_tuning() -> void:
	var base := SimTuning.load_default()
	var games := base.flag.raise_time
	var custom := CustomRules.new()
	var played := MatchOptions.match_tuning(base, MapCatalog.shared().find("woodland"), custom)
	assert_eq(played.flag.raise_time, 9.0)
	assert_eq(base.flag.raise_time, games)
	assert_eq(SimTuning.load_default().flag.raise_time, games)
