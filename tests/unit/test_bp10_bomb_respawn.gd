extends GutTest
## BP10 part 3: a field's own wait for Plant The Bomb's defenders against Hard bots (data/maps.md Bomb defender respawn
## at Hard).


func test_a_field_s_hard_bomb_wait_is_read_and_blank_or_bad_keeps_the_games() -> void:
	var head := "# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Bomb defender respawn at Hard (s) " \
			+ "| Blurb |\n|---|---|---|---|---|---|---|---|---|\n"
	var row := "| %s | %s | field | public | 5 | 6 | 8 | %s | A field. |\n"
	var m := MapCatalog.parse(head + row % ["near", "Near", ""] + row % ["far", "Far", "8"])
	assert_eq(m.problems, [] as Array[String])
	assert_eq(m.find("near").bomb_respawn_hard, 0.0, "blank: the round tuning's")
	assert_eq(m.find("far").bomb_respawn_hard, 8.0)
	for cell: String in ["1", "31", "soon"]:
		var bad := MapCatalog.parse(head + row % ["far", "Far", cell])
		assert_eq(bad.find("far").bomb_respawn_hard, 0.0, "%s keeps the game's" % cell)
		assert_eq(bad.problems.size(), 1, "%s warns" % cell)


func test_every_field_carries_its_hard_bomb_wait_in_skirmish_custom_and_the_measures() -> void:
	var base := SimTuning.load_default()
	var own := 0
	for e in MapCatalog.shared().entries:
		if e.kind != &"field":
			continue
		var hard := e.bomb_respawn_hard if e.bomb_respawn_hard > 0.0 else base.rounds.plant_defender_respawn_hard
		own += 1 if e.bomb_respawn_hard > 0.0 else 0
		var played: Array[SimTuning] = [MatchOptions.match_tuning(base, e, null),
				MatchOptions.match_tuning(base, e, CustomRules.new()), MatchRunner.sized_for(e.id)]
		for t in played:
			assert_eq(t.rounds.plant_defender_respawn_hard, hard, "%s carries its Hard wait" % e.id)
			# Before the level is applied every field plays the game's wait, and Attack / Defend's is the other column's.
			assert_eq(t.rounds.plant_defender_respawn_delay, base.rounds.plant_defender_respawn_delay, e.id)
			var ad := e.defender_respawn if e.defender_respawn > 0.0 else base.rounds.defender_respawn_delay
			assert_eq(t.rounds.defender_respawn_delay, ad, "%s, Attack / Defend" % e.id)
	assert_gt(own, 0, "a field has its own, or this test proves nothing")
	assert_eq(base.rounds.plant_defender_respawn_hard, 0.0, "the loaded tuning is never written")


func test_depot_s_defenders_wait_longer_only_against_hard_bots() -> void:
	var base := SimTuning.load_default()
	var depot := MapCatalog.shared().find("depot")
	assert_not_null(depot)
	var played := MatchOptions.match_tuning(base, depot, null)
	var games := base.rounds.plant_defender_respawn_delay
	assert_gt(depot.bomb_respawn_hard, games, "Depot's Hard defenders wait longer than the game's")
	assert_eq(MatchOptions.level_tuning(played, &"hard").rounds.plant_defender_respawn_delay, depot.bomb_respawn_hard)
	for level: StringName in [&"easy", &"normal"]:
		assert_eq(MatchOptions.level_tuning(played, level).rounds.plant_defender_respawn_delay, games,
				"%s waits the game's" % level)
	assert_eq(played.rounds.plant_defender_respawn_delay, games, "level_tuning never writes its input")


func test_a_field_without_one_waits_the_game_s_at_hard_too() -> void:
	var base := SimTuning.load_default()
	var checked := 0
	for e in MapCatalog.shared().entries:
		if e.kind != &"field" or e.bomb_respawn_hard > 0.0:
			continue
		checked += 1
		var hard := MatchOptions.level_tuning(MatchOptions.match_tuning(base, e, null), &"hard")
		assert_eq(hard.rounds.plant_defender_respawn_delay, base.rounds.plant_defender_respawn_delay, e.id)
	assert_gt(checked, 0, "a field without one, or this test proves nothing")


func test_hard_defenders_on_depot_come_back_after_its_wait_and_attackers_after_theirs() -> void:
	var depot := MapCatalog.shared().find("depot")
	var r := MatchOptions.level_tuning(MatchOptions.match_tuning(SimTuning.load_default(), depot, null), &"hard").rounds
	var rs := RoundState.new()
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	rs.attackers = 0
	assert_eq(Respawns.delay(rs, r, 1), depot.bomb_respawn_hard, "the defenders wait Depot's Hard time")
	assert_eq(Respawns.delay(rs, r, 0), r.respawn_delay, "the attackers wait theirs")
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	assert_eq(Respawns.delay(rs, r, 1), r.defender_respawn_delay, "Attack / Defend keeps its own")
