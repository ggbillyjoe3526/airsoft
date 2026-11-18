extends GutTest
## BP10 part 3: a field's own wait for Plant The Bomb's defenders (data/maps.md Bomb defender respawn).


func test_a_field_s_bomb_defender_respawn_is_read_and_blank_or_bad_keeps_the_games() -> void:
	var head := "# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Bomb defender respawn (s) | Blurb |\n" \
			+ "|---|---|---|---|---|---|---|---|---|\n"
	var row := "| %s | %s | field | public | 5 | 6 | 8 | %s | A field. |\n"
	var m := MapCatalog.parse(head + row % ["near", "Near", ""] + row % ["far", "Far", "8"])
	assert_eq(m.problems, [] as Array[String])
	assert_eq(m.find("near").bomb_respawn, 0.0, "blank: the round tuning's")
	assert_eq(m.find("far").bomb_respawn, 8.0)
	for cell: String in ["1", "31", "soon"]:
		var bad := MapCatalog.parse(head + row % ["far", "Far", cell])
		assert_eq(bad.find("far").bomb_respawn, 0.0, "%s keeps the game's" % cell)
		assert_eq(bad.problems.size(), 1, "%s warns" % cell)


func test_every_field_plays_its_own_bomb_wait_in_skirmish_custom_and_the_measures() -> void:
	var base := SimTuning.load_default()
	var games := base.rounds.plant_defender_respawn_delay
	var own := 0
	for e in MapCatalog.shared().entries:
		if e.kind != &"field":
			continue
		var back := e.bomb_respawn if e.bomb_respawn > 0.0 else games
		own += 1 if e.bomb_respawn > 0.0 else 0
		assert_eq(MatchOptions.match_tuning(base, e, null).rounds.plant_defender_respawn_delay, back,
				"%s, Skirmish" % e.id)
		assert_eq(MatchOptions.match_tuning(base, e, CustomRules.new()).rounds.plant_defender_respawn_delay, back,
				"%s, Custom" % e.id)
		assert_eq(MatchRunner.sized_for(e.id).rounds.plant_defender_respawn_delay, back,
				"%s: the measures play it" % e.id)
		# The Attack / Defend wait is the other column's, untouched by this one.
		var ad := e.defender_respawn if e.defender_respawn > 0.0 else base.rounds.defender_respawn_delay
		assert_eq(MatchOptions.match_tuning(base, e, null).rounds.defender_respawn_delay, ad, "%s, A/D" % e.id)
	assert_gt(own, 0, "a field has its own, or this test proves nothing")
	assert_eq(base.rounds.plant_defender_respawn_delay, games, "the loaded tuning is never written")


func test_depot_s_bomb_wait_is_its_own_and_no_level_scales_it() -> void:
	var base := SimTuning.load_default()
	var depot := MapCatalog.shared().find("depot")
	assert_not_null(depot)
	var played := MatchOptions.match_tuning(base, depot, null)
	assert_gt(played.rounds.plant_defender_respawn_delay, base.rounds.plant_defender_respawn_delay,
			"Depot's defenders wait longer than the game's")
	for level: StringName in [&"easy", &"normal", &"hard"]:
		var t := MatchOptions.level_tuning(played, level)
		assert_eq(t.rounds.plant_defender_respawn_delay, played.rounds.plant_defender_respawn_delay,
				"%s keeps the field's bomb wait" % level)


func test_plant_the_bomb_s_defenders_come_back_after_the_field_s_wait() -> void:
	var played := MatchOptions.match_tuning(SimTuning.load_default(), MapCatalog.shared().find("depot"), null)
	var wait := played.rounds.plant_defender_respawn_delay
	var r := played.rounds
	# Respawns.delay is the one place a hit's wait is read (game/sim/respawns.gd).
	var rs := RoundState.new()
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	rs.attackers = 0
	assert_eq(Respawns.delay(rs, r, 1), wait, "the defenders wait the field's")
	assert_eq(Respawns.delay(rs, r, 0), r.respawn_delay, "the attackers wait theirs")
