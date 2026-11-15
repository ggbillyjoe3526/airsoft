extends GutTest
## PB4: a field's own Plant The Bomb fuse (data/maps.md Fuse, MapCatalog.Entry.fuse_time). The bots' attackers took
## about 38 % of rounds on three fields with the game's 30 s: a defuse came 13 to 21 s after the plant, so the fight
## after it was settled long before the fuse mattered. The catalog reads the column, a match there plays it under
## Skirmish and Custom, the loaded tuning is never written, and every field's fuse still leaves a defending player time.

const DT := 1.0 / 60.0
const HEAD := "# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Fuse (s) | Blurb |\n" \
		+ "|---|---|---|---|---|---|---|---|---|\n"
## Seconds a defending player within BotConfig.plant_player_claim m of the armed bomb needs, past the sprint there, to
## see it is armed and turn: their reaction.
const PLAYER_REACTION := 1.5


func _row(id: String, fuse: String) -> String:
	return "| %s | %s | field | public | 5 | 6 | 8 | %s | A field. |\n" % [id, id.capitalize(), fuse]


func test_the_catalog_reads_a_fields_fuse_and_blank_keeps_the_games() -> void:
	var m := MapCatalog.parse(HEAD + _row("near", "") + _row("far", "23") + _row("half", "17.5"))
	assert_eq(m.problems, [] as Array[String])
	assert_eq(m.find("near").fuse_time, 0.0, "blank: the bomb tuning's")
	assert_eq(m.find("far").fuse_time, 23.0)
	assert_eq(m.find("half").fuse_time, 17.5)


func test_a_fuse_out_of_range_or_not_a_number_keeps_the_games_with_a_problem() -> void:
	for bad: String in ["14", "61", "short", "-20"]:
		var m := MapCatalog.parse(HEAD + _row("far", bad))
		assert_eq(m.find("far").fuse_time, 0.0, bad)
		assert_eq(m.problems.size(), 1, bad)


func test_a_table_without_the_column_reads_as_before_with_no_problem() -> void:
	var m := MapCatalog.parse("# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Blurb |\n"
			+ "|---|---|---|---|---|---|---|---|\n| far | Far | field | public | 5 | 6 | 8 | A field. |\n")
	assert_eq(m.problems, [] as Array[String])
	assert_eq(m.find("far").fuse_time, 0.0)


func test_each_field_plays_its_own_fuse_under_skirmish_custom_and_the_measures() -> void:
	var base := SimTuning.load_default()
	var games := base.plant.fuse_time
	var own := 0
	for e in MapCatalog.shared().entries:
		if e.kind != &"field":
			continue
		var fuse := e.fuse_time if e.fuse_time > 0.0 else games
		own += 1 if e.fuse_time > 0.0 else 0
		assert_eq(MatchOptions.match_tuning(base, e, null).plant.fuse_time, fuse, "%s, Skirmish" % e.id)
		var custom := CustomRules.new()
		custom.round_time = 120.0
		var customised := MatchOptions.match_tuning(base, e, custom)
		assert_eq(customised.plant.fuse_time, fuse, "%s: Custom has no switch for it" % e.id)
		assert_eq(customised.rounds.round_time, 120.0, "%s: and keeps its own round" % e.id)
		assert_eq(MatchRunner.sized_for(e.id).plant.fuse_time, fuse, "%s: the guards and measures play it" % e.id)
		var played := MatchOptions.match_tuning(base, e, null)
		assert_eq(played.plant.defuse_time, base.plant.defuse_time, "%s: the defuse is the game's" % e.id)
		assert_eq(played.plant.plant_time, base.plant.plant_time, "%s: and the plant" % e.id)
	assert_gt(own, 0, "a field has a fuse of its own, or this test proves nothing")
	assert_eq(base.plant.fuse_time, games, "the loaded tuning is never written")
	assert_eq(MatchOptions.match_tuning(base, null, null).plant.fuse_time, games, "no map")


func test_every_fuse_leaves_a_defending_player_time_before_a_bot_takes_over() -> void:
	# A bot leaves the defuse to the player within plant_player_claim m of the bomb until the fuse leaves its defuse
	# plus plant_takeover_margin s (BotPlant.may_defuse): the player has the fuse less that to sprint there and start.
	var base := SimTuning.load_default()
	var bots := BotConfig.new()
	var run := bots.plant_player_claim / base.movement.sprint_speed + PLAYER_REACTION
	for e in MapCatalog.shared().entries:
		if e.kind != &"field":
			continue
		var fuse := MatchOptions.fuse_time(e, base.plant.fuse_time)
		assert_gte(fuse - base.plant.defuse_time - bots.plant_takeover_margin, run, e.id)


func test_a_bomb_on_a_fields_tuning_goes_off_at_its_own_fuse() -> void:
	var base := SimTuning.load_default()
	var shortest: MapCatalog.Entry = null
	for e in MapCatalog.shared().entries:
		if e.fuse_time > 0.0 and (shortest == null or e.fuse_time < shortest.fuse_time):
			shortest = e
	var tuning := MatchOptions.match_tuning(base, shortest, null)
	assert_lt(tuning.plant.fuse_time, base.plant.fuse_time, "shorter than the game's")
	var ps := PlantState.new()
	ps.set_sites(PackedVector3Array([Vector3.ZERO]), PackedFloat32Array([0.0]), tuning.plant.site_radius)
	# Armed as Plant arms it (_step_carried): the fuse set from the tuning the match plays.
	ps.status = PlantState.Status.PLANTED
	ps.site = 0
	ps.fuse_left = tuning.plant.fuse_time
	var events := SimEvents.new()
	var nobody: Array[Character] = []
	for i in roundi((tuning.plant.fuse_time - 0.5) / DT):
		Plant.step(ps, nobody, 0, tuning.plant, events, DT)
	assert_eq(ps.status, PlantState.Status.PLANTED, "still ticking just before its own fuse")
	for i in roundi(1.0 / DT):
		Plant.step(ps, nobody, 0, tuning.plant, events, DT)
	assert_eq(ps.status, PlantState.Status.GONE_OFF, "gone off at its own fuse, long before the game's")


func test_the_match_page_says_the_fields_fuse_in_plant_the_bomb_only() -> void:
	var woodland := MapCatalog.shared().find("woodland")
	assert_eq(MatchOptions.field_fuse(MatchOptions.MODE_PLANT_THE_BOMB, woodland, 30.0),
			MatchOptions.fuse_time(woodland, 30.0))
	assert_eq(MatchOptions.field_fuse(MatchOptions.MODE_ATTACK_DEFEND, woodland, 30.0), 0.0, "no bomb")
	assert_eq(MatchOptions.field_fuse(MatchOptions.MODE_PLANT_THE_BOMB, null, 30.0), 0.0, "no map")
	var picks := MatchPicks.new()
	picks.map_id = "woodland"
	picks.mode = MatchOptions.MODE_PLANT_THE_BOMB
	var page := MatchPage.new(picks, Settings.new())
	add_child_autofree(page)
	var said := MatchOptions.seconds_text(MatchOptions.fuse_time(woodland, SimTuning.load_default().plant.fuse_time))
	assert_eq(page.rules_box().flag_note_text(), "An armed bomb goes off after %s s on this field." % said)
	page._pick_mode("elimination")
	assert_eq(page.rules_box().flag_note_text(), "", "a mode with no bomb")
	page._pick_mode(MatchOptions.MODE_ATTACK_DEFEND)
	assert_eq(page.rules_box().flag_note_text(), "The flag takes 9 s to raise on this field (7 s on the others).",
			"Attack / Defend still says the raise")
