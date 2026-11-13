extends GutTest
## MB3: a field's own flag raise time (data/maps.md Raise, MapCatalog.Entry.raise_time). Woodland's is 9 s: its sites
## are 77 m apart. The catalog reads the column, a match there plays it under Skirmish and Custom, the loaded tuning is
## never written, and a flag on such a tuning takes that long to raise.

const DT := 1.0 / 60.0
const HEAD := "# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Raise (s) | Blurb |\n" \
		+ "|---|---|---|---|---|---|---|---|---|\n"
const WOODLAND_RAISE := 9.0


func _row(id: String, raise: String) -> String:
	return "| %s | %s | field | public | 5 | 6 | 8 | %s | A field. |\n" % [id, id.capitalize(), raise]


func test_the_catalog_reads_a_fields_raise_time_and_blank_keeps_the_games() -> void:
	var m := MapCatalog.parse(HEAD + _row("near", "") + _row("far", "9") + _row("half", "8.5"))
	assert_eq(m.problems, [] as Array[String])
	assert_eq(m.find("near").raise_time, 0.0, "blank: the flag tuning's")
	assert_eq(m.find("far").raise_time, 9.0)
	assert_eq(m.find("half").raise_time, 8.5)


func test_a_raise_time_out_of_range_or_not_a_number_keeps_the_games_with_a_problem() -> void:
	for bad: String in ["2", "21", "long", "-9"]:
		var m := MapCatalog.parse(HEAD + _row("far", bad))
		assert_eq(m.find("far").raise_time, 0.0, bad)
		assert_eq(m.problems.size(), 1, bad)


func test_a_table_without_the_column_reads_as_before_with_no_problem() -> void:
	var m := MapCatalog.parse("# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Blurb |\n"
			+ "|---|---|---|---|---|---|---|---|\n| far | Far | field | public | 5 | 6 | 8 | A field. |\n")
	assert_eq(m.problems, [] as Array[String])
	assert_eq(m.find("far").raise_time, 0.0)


func test_woodland_plays_its_own_raise_under_skirmish_and_custom_and_the_others_the_games() -> void:
	var base := SimTuning.load_default()
	var games := base.flag.raise_time
	var woodland := MapCatalog.shared().find("woodland")
	assert_eq(woodland.raise_time, WOODLAND_RAISE, "data/maps.md")
	var played := MatchOptions.match_tuning(base, woodland, null)
	assert_eq(played.flag.raise_time, WOODLAND_RAISE, "Skirmish")
	assert_eq(played.flag.hold_time, base.flag.hold_time, "the hold is the game's")
	var custom := CustomRules.new()
	custom.round_time = 120.0
	var customised := MatchOptions.match_tuning(base, woodland, custom)
	assert_eq(customised.flag.raise_time, WOODLAND_RAISE, "Custom has no switch for it")
	assert_eq(customised.rounds.round_time, 120.0, "and keeps its own round")
	assert_eq(base.flag.raise_time, games, "the loaded tuning is never written")
	assert_ne(games, WOODLAND_RAISE, "or this test proves nothing")
	for id: String in ["depot", "subway"]:
		var other := MatchOptions.match_tuning(base, MapCatalog.shared().find(id), null)
		assert_eq(other.flag.raise_time, games, id)
	assert_eq(MatchOptions.match_tuning(base, null, null).flag.raise_time, games, "no map")
	assert_eq(MatchRunner.sized_for("woodland").flag.raise_time, WOODLAND_RAISE, "the guards and measures play it too")
	assert_eq(MatchRunner.sized_for("depot").flag.raise_time, games)


func test_a_flag_on_woodlands_tuning_is_not_up_after_the_games_time_and_is_up_after_its_own() -> void:
	var base := SimTuning.load_default()
	var tuning := MatchOptions.match_tuning(base, MapCatalog.shared().find("woodland"), null)
	var flag := FlagState.new()
	var loadout: Array[ReplicaConfig] = []
	var raiser := Character.new(0, 0, flag.position, 0.0, loadout)
	var at_the_rope: Array[Character] = [raiser]
	var events := SimEvents.new()
	for i in roundi(base.flag.raise_time / DT):
		Flag.step(flag, at_the_rope, 0, tuning.flag, events, DT)
	assert_almost_eq(flag.progress, base.flag.raise_time / WOODLAND_RAISE, 0.01, "still climbing at the game's time")
	for i in roundi((WOODLAND_RAISE - base.flag.raise_time) / DT) + 1:
		Flag.step(flag, at_the_rope, 0, tuning.flag, events, DT)
	assert_almost_eq(flag.progress, 1.0, 0.001, "up after its own")


func test_the_match_tally_follows_every_poles_flag_and_names_the_pole() -> void:
	var a := FlagState.new()
	var b := FlagState.new()
	var flags: Array[FlagState] = [a, b]
	var r := MatchRunner.RoundTally.new()
	MatchRunner.watch_flags(flags, r)
	assert_eq(r.top_flag, 0.0)
	assert_eq(r.top_pole, -1, "no flag has left the ground")
	b.progress = 0.4
	MatchRunner.watch_flags(flags, r)
	assert_eq(r.top_flag, 0.4, "flag B's height counts (it read flag A alone)")
	assert_eq(r.top_pole, 1)
	b.progress = 0.1
	a.progress = 0.3
	MatchRunner.watch_flags(flags, r)
	assert_eq(r.top_flag, 0.4, "the highest it got, kept as it comes down")
	assert_eq(r.top_pole, 1)
	a.progress = 1.0
	MatchRunner.watch_flags(flags, r)
	assert_eq(r.top_flag, 1.0)
	assert_eq(r.top_pole, 0, "the pole of the highest flag")
