extends GutTest
## BG1: a field's own wait for Plant The Bomb's defenders at every level (data/maps.md Bomb defender respawn), which
## Hard plays too unless the field sets its Hard one.


func test_a_field_s_bomb_wait_is_read_and_blank_or_bad_keeps_the_games() -> void:
	var head := "# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Bomb defender respawn (s) " \
			+ "| Blurb |\n|---|---|---|---|---|---|---|---|---|\n"
	var row := "| %s | %s | field | public | 5 | 6 | 8 | %s | A field. |\n"
	var m := MapCatalog.parse(head + row % ["near", "Near", ""] + row % ["far", "Far", "3.5"])
	assert_eq(m.problems, [] as Array[String])
	assert_eq(m.find("near").bomb_respawn, 0.0, "blank: the round tuning's")
	assert_eq(m.find("far").bomb_respawn, 3.5)
	for cell: String in ["1", "31", "soon"]:
		var bad := MapCatalog.parse(head + row % ["far", "Far", cell])
		assert_eq(bad.find("far").bomb_respawn, 0.0, "%s keeps the game's" % cell)
		assert_eq(bad.problems.size(), 1, "%s warns" % cell)


func test_subway_s_bomb_defenders_wait_less_except_at_hard() -> void:
	var base := SimTuning.load_default()
	var subway := MapCatalog.shared().find("subway")
	assert_not_null(subway)
	var games := base.rounds.plant_defender_respawn_delay
	assert_gt(subway.bomb_respawn, 0.0, "Subway sets its own")
	assert_lt(subway.bomb_respawn, games, "its defenders come back sooner than the game's")
	var played: Array[SimTuning] = [MatchOptions.match_tuning(base, subway, null),
			MatchOptions.match_tuning(base, subway, CustomRules.new()), MatchRunner.sized_for("subway")]
	for t in played:
		for level: StringName in [&"easy", &"normal"]:
			assert_eq(MatchOptions.level_tuning(t, level).rounds.plant_defender_respawn_delay, subway.bomb_respawn,
					"%s waits Subway's" % level)
		assert_eq(MatchOptions.level_tuning(t, &"hard").rounds.plant_defender_respawn_delay, games,
				"Hard keeps the game's wait (Subway's Hard column)")
	assert_eq(base.rounds.plant_defender_respawn_delay, games, "the loaded tuning is never written")


func test_subway_s_bomb_wait_is_only_plant_the_bomb_s() -> void:
	var subway := MapCatalog.shared().find("subway")
	var r := MatchOptions.level_tuning(MatchOptions.match_tuning(SimTuning.load_default(), subway, null), &"normal").rounds
	var rs := RoundState.new()
	rs.attackers = 0
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	assert_eq(Respawns.delay(rs, r, 1), subway.bomb_respawn, "the defenders wait Subway's")
	assert_eq(Respawns.delay(rs, r, 0), r.respawn_delay, "the attackers wait theirs")
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	assert_eq(Respawns.delay(rs, r, 1), subway.defender_respawn, "Attack / Defend keeps Subway's own")
