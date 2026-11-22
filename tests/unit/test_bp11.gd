extends GutTest
## BP11, the second pass before 0.1 Beta 2: the edge cases it fixed that have no older test file of their own. The
## Match page keeps the field's mode across menus built again, maps.md reads a typed minus sign, levels.md refuses a
## percent multiplier, a bot under Regroup or Follow Me asks for a route again after one failed, and a field sets its
## own Attack / Defend wait against Hard bots (Subway's, data/maps.md Defender respawn at Hard).


# --- the Match page ---

func test_the_field_mode_comes_back_after_the_range_through_menus_built_again() -> void:
	# Pick Depot with Elimination, then the Range: practice's Leave (or a colour change) builds a new page, and picking
	# Depot then gave Attack / Defend, the default, not Elimination.
	var picks := MatchPicks.new()
	var settings := Settings.new()
	var page := MatchPage.new(picks, settings)
	add_child_autofree(page)
	page.map_card("depot").pressed.emit()
	page.mode_card(MatchOptions.MODE_ELIMINATION).pressed.emit()
	assert_eq(picks.mode, MatchOptions.MODE_ELIMINATION)
	page.map_card("range").pressed.emit()
	assert_eq(picks.mode, MatchOptions.MODE_PRACTICE)
	remove_child(page)
	page.free()
	var again := MatchPage.new(picks, settings)
	add_child_autofree(again)
	assert_eq(picks.mode, MatchOptions.MODE_PRACTICE, "still on the Range")
	again.map_card("depot").pressed.emit()
	assert_eq(picks.mode, MatchOptions.MODE_ELIMINATION, "the field's mode given back")


# --- the data tables ---

func test_a_typed_minus_sign_reads_as_a_cold_field_s_air() -> void:
	var text := FileAccess.get_file_as_string(MapCatalog.PATH)
	var row := "| depot | Depot | field | public | 5 | 6 | 8 |  |  | 24 | 15 |  |  | 8 | burst | 0 | 20 |"
	assert_string_contains(text, row, "the test's row is the shipped one")
	var cold := MapCatalog.parse(text.replace(row, row.replace("| 0 | 20 |", "| 0 | −5 |")))
	assert_eq(cold.find("depot").air, -5.0, "−5 as the other tables read it")
	assert_true(cold.problems.is_empty(), "\n".join(cold.problems))
	var bad := MapCatalog.parse(text.replace(row, row.replace("| 0 | 20 |", "| 0 | 20 % |")))
	assert_true(is_nan(bad.find("depot").air), "a percent keeps the built-in: the replicas' rated air")
	assert_false(bad.problems.is_empty())


func test_a_percent_multiplier_is_refused_not_read_as_its_number() -> void:
	var text := FileAccess.get_file_as_string(LevelTable.PATH)
	assert_string_contains(text, "| Easy | 0.5 |")
	var t := LevelTable.parse(text.replace("| Easy | 0.5 |", "| Easy | 50 % |"), Pool.shared())
	assert_eq(t.multiplier(&"easy"), LevelTable.DEFAULT_MULTIPLIERS[&"easy"], "the built-in, not 50 times the XP")
	assert_string_contains("\n".join(t.problems), "Multiplier must be a number")


# --- Regroup and Follow Me ---

func test_a_failed_route_to_a_giver_standing_still_is_asked_for_again() -> void:
	var w := BotWorld.new()
	w.cfg = BotConfig.load_default()
	w.tuning = SimTuning.new()
	w.nav = NavGrid.new()
	var giver := Character.new(0, 0, Vector3(20.0, 0.0, 0.0), 0.0, [] as Array[ReplicaConfig])
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [] as Array[ReplicaConfig])
	var b := Bot.new(c, 3, w.cfg.skill, 2)
	w.characters = [giver, c]
	w.bots = [b]
	b.order = SquadOrder.Kind.REGROUP
	b.order_giver = giver
	b.route_goal = giver.position
	b.route_state = Bot.RouteState.FAILED
	w.time = 10.0
	b.route_retry_at = 12.0
	var cmd := PlayerCommand.new()
	SquadOrders.move(b, w, cmd, 1.0 / 60.0)
	assert_eq(b.route_state, Bot.RouteState.FAILED, "not before route_retry_delay")
	w.time = 12.0
	SquadOrders.move(b, w, cmd, 1.0 / 60.0)
	assert_eq(b.route_state, Bot.RouteState.WANTED, "asked for again, the giver still within replan_distance")


# --- a standing Follow me through a hit ---

func test_a_follower_back_from_a_hit_follows_again_while_the_order_stands() -> void:
	# KNOWN_ISSUES (BP10): with respawns a bot dropped Follow me when hit and never took it again, so the order thinned.
	var w := BotWorld.new()
	w.cfg = BotConfig.load_default()
	w.tuning = SimTuning.new()
	var none: Array[ReplicaConfig] = []
	var you := Character.new(0, 0, Vector3.ZERO, 0.0, none)
	w.characters = [you]
	for id: int in [1, 2]:
		var c := Character.new(id, 0, Vector3(2.0 * id, 0.0, 0.0), 0.0, none)
		w.characters.append(c)
		w.bots.append(Bot.new(c, id + 3, w.cfg.skill, 3))
	w.characters.append(Character.new(3, 1, Vector3(30.0, 0.0, 0.0), 0.0, none))
	var book := SquadOrderBook.new(w)
	assert_eq(book.give_order(you, SquadOrder.Kind.FOLLOW), SquadOrder.Kind.FOLLOW)
	var hit := w.bots[0]
	var slot := hit.order_slot
	hit.character.status = Character.Status.OUT
	book.update()
	assert_eq(hit.order, SquadOrder.Kind.NONE, "out: its order ends")
	assert_eq(book.order_of(you.id), SquadOrder.Kind.FOLLOW, "the other still carries it")
	hit.character.status = Character.Status.ALIVE
	book.rejoin(hit)
	assert_eq(hit.order, SquadOrder.Kind.FOLLOW, "back in: following again")
	assert_eq(hit.order_giver, you)
	assert_eq(hit.order_slot, slot, "its own slot behind you, the other's kept")
	# With nobody carrying it the order lapses (the giver is told), and a bot back later plays the team plan.
	book.give_order(you, SquadOrder.Kind.TEAM_PLAN)
	book.rejoin(hit)
	assert_eq(hit.order, SquadOrder.Kind.NONE)


# --- Attack / Defend's wait at Hard ---

func test_a_field_s_hard_wait_is_read_and_blank_or_bad_keeps_the_scale() -> void:
	var head := "# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Defender respawn at Hard (s) " \
			+ "| Blurb |\n|---|---|---|---|---|---|---|---|---|\n"
	var row := "| %s | %s | field | public | 5 | 6 | 8 | %s | A field. |\n"
	var m := MapCatalog.parse(head + row % ["near", "Near", ""] + row % ["far", "Far", "15.2"])
	assert_eq(m.problems, [] as Array[String])
	assert_eq(m.find("near").defender_respawn_hard, 0.0, "blank: the field's times the Hard scale")
	assert_eq(m.find("far").defender_respawn_hard, 15.2)
	for cell: String in ["1", "31", "soon", "15 %"]:
		var bad := MapCatalog.parse(head + row % ["far", "Far", cell])
		assert_eq(bad.find("far").defender_respawn_hard, 0.0, "%s keeps the scale" % cell)
		assert_eq(bad.problems.size(), 1, "%s warns" % cell)


func test_subway_s_defenders_wait_their_own_time_only_against_hard_bots() -> void:
	var base := SimTuning.load_default()
	var subway := MapCatalog.shared().find("subway")
	assert_gt(subway.defender_respawn_hard, 0.0, "Subway sets its own Hard wait")
	var played: Array[SimTuning] = [MatchOptions.match_tuning(base, subway, null),
			MatchOptions.match_tuning(base, subway, CustomRules.new()), MatchRunner.sized_for("subway")]
	for t in played:
		assert_eq(t.rounds.defender_respawn_hard, subway.defender_respawn_hard)
		assert_eq(MatchOptions.level_tuning(t, &"hard").rounds.defender_respawn_delay, subway.defender_respawn_hard)
		assert_eq(MatchOptions.level_tuning(t, &"normal").rounds.defender_respawn_delay, subway.defender_respawn)
		var easy: float = subway.defender_respawn * base.rounds.defender_respawn_scale[&"easy"]
		assert_almost_eq(MatchOptions.level_tuning(t, &"easy").rounds.defender_respawn_delay, easy, 0.001)
		# Plant The Bomb keeps its own column.
		assert_eq(MatchOptions.level_tuning(t, &"hard").rounds.plant_defender_respawn_delay,
				base.rounds.plant_defender_respawn_delay)
	assert_eq(base.rounds.defender_respawn_hard, 0.0, "the loaded tuning is never written")


func test_a_field_without_a_hard_wait_plays_its_own_times_the_hard_scale() -> void:
	var base := SimTuning.load_default()
	for e in MapCatalog.shared().entries:
		if e.kind != &"field" or e.defender_respawn_hard > 0.0:
			continue
		var t := MatchOptions.match_tuning(base, e, null)
		var want := minf(t.rounds.defender_respawn_delay * base.rounds.defender_respawn_scale[&"hard"],
				maxf(t.rounds.defender_respawn_delay, base.rounds.defender_respawn_most))
		assert_eq(MatchOptions.level_tuning(t, &"hard").rounds.defender_respawn_delay, want, e.id)
