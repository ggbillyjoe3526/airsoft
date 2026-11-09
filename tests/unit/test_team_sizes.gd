extends GutTest
## WL2: team sizes per map (data/maps.md's Min, Standard and Max, the browser game's maps.ts teamSize), the Match page's
## Team size row offering only the picked map's (TS1: every field 5v5 to 8v8, 6v6 its standard), a 6v6 and an 8v8 on
## Woodland, the route searches' budget a tick
## (NavConfig.search_budget) and Woodland's nav grid built on a worker thread behind the loading screen.

const SAVE := "user://test_team_sizes_settings.save"
## Seconds a staged build may take (its nav grid builds on a worker thread, so frames are no measure).
const LOAD_LIMIT := 20.0
const HEAD := "## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Blurb |\n|---|---|---|---|---|---|---|---|\n"
## A walk-off that times out ends on its spot too (HitConfig.walk_off_time 20 s, then the fade): the hand-stepped
## match gets this long (s) for everyone to stand in the dead zone.
const WALK_LIMIT := 30.0


func after_each() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	get_tree().paused = false


func _sizes(e: MapCatalog.Entry) -> Array[int]:
	return [e.team_min, e.team_standard, e.team_max]


# --- the catalogue ---

func test_the_shipped_maps_offer_the_owner_s_sizes() -> void:
	var cat := MapCatalog.read_file()
	assert_eq(cat.problems, [] as Array[String])
	var want: Dictionary[String, Array] = {
		"depot": [5, 6, 8], "woodland": [5, 6, 8], "range": [1, 1, 1],
	}
	for id: String in want:
		var e := cat.find(id)
		assert_not_null(e, id)
		if e != null:
			assert_eq(_sizes(e), want[id] as Array[int], id)


func test_an_unreadable_size_keeps_its_built_in_value_and_warns() -> void:
	var cat := MapCatalog.parse(HEAD
			+ "| a | A | field | public | x | 2 | 2 | . |\n"
			+ "| b | B | field | public | 1 | 9 | 9 | . |\n"
			+ "| c | C | field | public | 2.5 | 4 | 0 | . |\n"
			+ "| d | D | field | public | 4 | 5 | 6 | . |\n"
			+ "| e | E | field | public | 6 | 5 | 6 | . |\n")
	assert_eq(cat.entries.size(), 5, "a team size never drops a map")
	assert_eq(_sizes(cat.find("a")), [1, 2, 2] as Array[int], "Min x keeps 1")
	assert_eq(_sizes(cat.find("b")), [1, 3, 3] as Array[int], "9 a side keeps 3: nothing offers 9v9")
	assert_eq(_sizes(cat.find("c")), [1, 3, 3] as Array[int], "2.5 and 0 kept theirs, then 1, 4, 3 is out of order")
	assert_eq(_sizes(cat.find("d")), [4, 5, 6] as Array[int])
	assert_eq(_sizes(cat.find("e")), [1, 3, 3] as Array[int], "a smallest over the standard: all three built in")
	assert_eq(cat.problems.size(), 7, "\n".join(cat.problems))
	assert_string_contains(cat.problems[0], "maps.md:5")
	assert_string_contains(cat.problems[0], "Min \"x\"")


func test_a_missing_size_column_is_reported_once() -> void:
	var cat := MapCatalog.parse("## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Blurb |\n|---|---|---|---|---|---|---|\n"
			+ "| a | A | field | public | 1 | 2 | . |\n| b | B | field | public | 1 | 1 | . |\n")
	assert_eq(cat.problems.size(), 1)
	assert_string_contains(cat.problems[0], "no \"Max\" column")
	assert_eq(_sizes(cat.find("a")), [1, 2, 3] as Array[int])


func test_nothing_offers_nine_a_side() -> void:
	assert_eq(CustomRules.TEAM_SIZES.max(), 8)
	for e in MapCatalog.shared().entries:
		assert_lte(e.team_max, 8, e.id)
	var c := CustomRules.new()
	c.from_dict({"team_size": 9})
	assert_eq(c.team_size, CustomRules.new().team_size)


func test_a_map_plays_a_picked_size_it_offers_else_its_standard() -> void:
	# a small field of 1v1 to 3v3 beside the shipped ones, as Depot was until DR1
	var cat := MapCatalog.parse(FileAccess.get_file_as_string(MapCatalog.PATH).replace("| range | Range |",
			"| small | Small | field | public | 1 | 3 | 3 | A small field. |\n| range | Range |"))
	var woodland := cat.find("woodland")
	var depot := cat.find("small")
	assert_eq(woodland.team_size_for(3), 6)
	assert_eq(woodland.team_size_for(5), 5)
	assert_eq(woodland.team_size_for(8), 8)
	assert_eq(depot.team_size_for(6), 3)
	assert_eq(depot.team_size_for(2), 2)
	assert_eq(MatchOptions.team_size(woodland, null), 6, "Skirmish plays the standard")
	assert_eq(MatchOptions.team_size(depot, null), 3)
	assert_eq(MatchOptions.team_size(cat.find("range"), null), 1)
	var custom := CustomRules.new()
	custom.team_size = 8
	assert_eq(MatchOptions.team_size(woodland, custom), 8)
	custom.team_size = 2
	assert_eq(MatchOptions.team_size(woodland, custom), 6, "2 is not one of Woodland's: its standard")
	assert_eq(MatchOptions.team_size(depot, custom), 2)
	var base := SimTuning.load_default()
	var played := MatchOptions.match_tuning(base, woodland, null)
	assert_eq(played.rounds.team_size, 6)
	assert_eq(base.rounds.team_size, 3, "the loaded tuning is never written")
	assert_same(MatchOptions.match_tuning(base, depot, null), base, "a 3v3 field plays the loaded tuning as it is")


func test_every_size_a_field_offers_has_a_spawn_and_a_dead_zone_spot_each() -> void:
	for e in MapCatalog.shared().fields(true):
		var m := MapData.load_map(e.id, PlayTuning.load_default().map_style, e.team_max)
		assert_true(m.ok(), "%s at %d: %s" % [e.id, e.team_max, "; ".join(m.problems)])
		for end in m.ends:
			assert_gte(end.dead_zone.size(), e.team_max, "%s's dead zone" % e.id)


# --- the Match page ---

func _page(rules: String, settings: Settings = null) -> MatchPage:
	var s := settings if settings != null else Settings.new()
	s.dev.dev_content = true
	var picks := MatchPicks.new()
	picks.rules = rules
	var page := MatchPage.new(picks, s)
	page.rules_box().save_path = SAVE
	add_child_autofree(page)
	return page


func _saved_size() -> int:
	var s := Settings.new()
	s.load_file(SAVE)
	return s.custom_rules.team_size


func _pick_size(page: MatchPage, n: int) -> void:
	page.rules_box().team_size_choice().button(CustomRules.TEAM_SIZES.find(n)).pressed.emit()


func test_the_team_size_row_offers_only_the_picked_map_s_sizes() -> void:
	var page := _page(MatchOptions.RULES_CUSTOM)
	var box := page.rules_box()
	assert_eq(box.offered_sizes(), [5, 6, 7, 8] as Array[int], "Depot")
	page.map_card("woodland").pressed.emit()
	assert_eq(box.offered_sizes(), [5, 6, 7, 8] as Array[int], "Woodland")
	for id in page.map_ids():
		page.map_card(id).pressed.emit()
		assert_false(box.offered_sizes().has(4), id)
		assert_true(box.offered_sizes().has(page.map_check_size()), "%s lights a size it offers" % id)


func test_picking_a_map_sets_its_standard_size() -> void:
	var page := _page(MatchOptions.RULES_SKIRMISH)
	assert_eq(page.chip_texts()[0], "6 v 6")
	page.map_card("woodland").pressed.emit()
	assert_eq(page.chip_texts()[0], "6 v 6")
	assert_eq(page.map_check_size(), 6)
	assert_string_contains(page.rules_box().blurb_text(), "6v6")
	page.map_card("depot").pressed.emit()
	assert_eq(page.chip_texts()[0], "6 v 6")


func test_a_saved_custom_size_is_kept_where_the_map_allows_it() -> void:
	var settings := Settings.new()
	var page := _page(MatchOptions.RULES_CUSTOM, settings)
	var box := page.rules_box()
	assert_eq(page.map_check_size(), 6, "the default 3 is not Depot's: its standard")
	assert_eq(settings.custom_rules.team_size, 3, "the saved size is kept")
	_pick_size(page, 5)
	assert_eq(_saved_size(), 5)
	page.map_card("woodland").pressed.emit()
	assert_eq(page.map_check_size(), 5, "Depot 5v5 to Woodland 5v5")
	assert_eq(box.team_size_choice().selected(), CustomRules.TEAM_SIZES.find(5))
	assert_true(page.summary_text().ends_with("Custom 5v5"), page.summary_text())
	assert_eq(_saved_size(), 5)
	page.map_card("woodland").pressed.emit()
	_pick_size(page, 8)
	assert_eq(_saved_size(), 8, "8v8 picked on Woodland is saved")
	page.map_card("depot").pressed.emit()
	assert_eq(page.map_check_size(), 8, "Depot plays the saved 8v8 too")
	assert_eq(box.team_size_choice().selected(), CustomRules.TEAM_SIZES.find(8))
	page.map_card("woodland").pressed.emit()
	assert_eq(page.map_check_size(), 8, "Woodland plays the saved 8v8 again")
	assert_eq(box.row_blurbs()[0], "You and seven bot teammates against eight bots.")


func test_an_old_save_loads_unchanged() -> void:
	var old := {"team_size": 2, "wins_needed": 7, "round_time": 180.0, "friendly_fire": false, "ricochets_count": true}
	assert_true(SaveFile.write(SAVE, Settings.KIND, Settings.VERSION, {"custom_rules": old}))
	var settings := Settings.new()
	settings.load_file(SAVE)
	assert_eq(settings.custom_rules.to_dict(), old)
	var page := _page(MatchOptions.RULES_CUSTOM, settings)
	assert_eq(page.map_check_size(), 6, "2 is not Depot's: its standard")
	assert_eq(settings.custom_rules.to_dict(), old, "opening the page writes nothing over it")


# --- 8v8 on Woodland (the largest, TS1) ---

func test_an_8v8_on_woodland_gives_everyone_a_spawn_and_a_dead_zone_spot_of_their_own() -> void:
	var settings := Settings.new(PlayTuning.new())
	settings.dev.bots_hold_fire = true
	var custom := CustomRules.new()
	custom.team_size = 8
	var session := PlaySession.new()
	session.settings = settings
	session.map_id = "woodland"
	session.custom_rules = custom
	add_child_autofree(session)
	var state := session.state
	assert_not_null(state, "Woodland 8v8 builds")
	if state == null:
		return
	assert_eq(state.characters.size(), 16, "sixteen players")
	var map := session._map
	var spawns := PackedVector3Array()
	for c in state.characters:
		assert_false(spawns.has(c.spawn_position), "%d has a spawn of its own" % c.id)
		spawns.append(c.spawn_position)
		var on_end := false
		for p in map.ends[c.end].spawns:
			on_end = on_end or Vector2(p.position.x - c.spawn_position.x, p.position.z - c.spawn_position.z).length() < 0.01
		assert_true(on_end, "%d starts on one of its end's spawns" % c.id)
		assert_false(c.armament.replicas.is_empty(), "%d carries a kit" % c.id)
	for b in session._bots.world.bots:
		assert_ne(b.bot_name, "", "bot %d has a name" % b.character.id)
	assert_eq(session._bots.world.bots.size(), 15)
	# Seven of each team hit at once (the eighth keeps the round live), each walks off to a spot of its own.
	var out: Array[Character] = []
	for team in 2:
		var hit := 0
		for c in state.characters:
			if c.team == team and hit < 7:
				Elimination.eliminate(c, -1, state.characters, map.ends)
				out.append(c)
				hit += 1
	session.set_physics_process(false)
	session.set_process(false)
	var ticks := 0
	while ticks < roundi(WALK_LIMIT / PlaySession.TICK) and out.any(func(c: Character) -> bool: return not Elimination.is_parked(c)):
		session._physics_process(PlaySession.TICK)
		ticks += 1
	var spots := PackedVector3Array()
	for c in out:
		assert_true(Elimination.is_parked(c), "%d stands in the dead zone" % c.id)
		assert_false(spots.has(c.dead_zone_target), "%d has a spot of its own" % c.id)
		spots.append(c.dead_zone_target)
		var flat := Vector2(c.position.x - c.dead_zone_target.x, c.position.z - c.dead_zone_target.z)
		assert_lt(flat.length(), session._tuning.hits.dead_zone_arrive * 2.0, "%d is on its spot" % c.id)
	for c in state.characters:
		if Elimination.is_in_play(c):
			Elimination.eliminate(c, -1, state.characters, map.ends)
			assert_false(spots.has(c.dead_zone_target), "the eighth's spot (%d) is its own too" % c.id)
			spots.append(c.dead_zone_target)
	assert_eq(spots.size(), 16)


func test_an_8v8_tab_board_fits_the_screen_at_the_largest_hud_size() -> void:
	var custom := CustomRules.new()
	custom.team_size = 8
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.settings.dev.bots_hold_fire = true
	session.map_id = "depot"
	session.custom_rules = custom
	add_child_autofree(session)
	assert_not_null(session.state, "Depot 8v8 builds")
	if session.state == null:
		return
	var window := get_tree().root
	var was := window.size
	window.size = Vector2i(1920, 1080) # a 1080p screen (headless starts square)
	var hud := session._hud
	hud.set_hud_size(AccessibilityConfig.HUD_SIZE_RANGE.y)
	session.set_physics_process(false)
	session.set_process(false)
	hud.show_board(true)
	hud.update(session.state, 1.0, PlaySession.TICK)
	var board := hud.board()
	assert_true(board.visible, "Tab shows the board")
	assert_eq(board.table().lines().size(), 16, "sixteen rows")
	var foot := Hud.BOARD_TOP + board.get_combined_minimum_size().y * board.scale.y
	assert_lte(foot, hud.size.y - Hud.SUMMARY_EDGE + 0.5, "the board ends on the screen (scale %.2f)" % board.scale.y)
	window.size = was


# --- the route search budget ---

## A world of `count` bots on the old yard (YardMap), each wanting a route across it.
func _world(count: int, budget: int) -> BotWorld:
	var tuning := SimTuning.load_default().duplicate() as SimTuning
	tuning.nav = tuning.nav.duplicate() as NavConfig
	tuning.nav.search_budget = budget
	var map := YardMap.load_map(PlayTuning.load_default().map_style, 3) # the old yard (DR1)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = BotConfig.load_default()
	w.nav = NavGrid.build(map, tuning.nav, tuning.body)
	for i in count:
		var end := map.ends[i % 2]
		var c := Character.new(i, i % 2, end.spawns[i / 2].position, 0.0, ReplicaStats.default_loadout())
		w.characters.append(c)
		var b := Bot.new(c, i, w.cfg.skill_for(&"easy"), count)
		BotRoutes.want(b, map.ends[1 - i % 2].spawns[0].position, w.cfg)
		w.bots.append(b)
	return w


func _wanted(w: BotWorld) -> int:
	var n := 0
	for b in w.bots:
		if b.route_state == Bot.RouteState.WANTED:
			n += 1
	return n


func test_route_searches_keep_to_the_budget_and_the_rest_wait_for_the_next_tick() -> void:
	var w := _world(4, 1)
	var cursor := BotRoutes.plan(w, w.characters, 0)
	assert_eq(_wanted(w), 3, "one search a tick")
	assert_eq(w.nav.searches, 1)
	assert_eq(w.bots[0].route_state, Bot.RouteState.OK)
	assert_eq(w.bots[1].route_asked_at, 0.0, "the others' wait is stamped")
	w.time += PlaySession.TICK
	cursor = BotRoutes.plan(w, w.characters, cursor)
	assert_eq(w.bots[1].route_state, Bot.RouteState.OK, "the next bot's turn")
	assert_eq(_wanted(w), 2)
	w = _world(4, 2)
	BotRoutes.plan(w, w.characters, 0)
	assert_eq(_wanted(w), 2, "a budget of two serves two")
	w = _world(4, 2)
	w.characters[0].walk_off_route_pending = true
	BotRoutes.plan(w, w.characters, 0)
	assert_eq(_wanted(w), 3, "a walk-off due takes the tick's first search")


func test_a_victim_still_vaulting_leaves_the_bots_their_search() -> void:
	var w := _world(2, 1)
	var victim := w.characters[1]
	victim.walk_off_route_pending = true
	victim.vault.active = true
	assert_false(Elimination.walk_off_due(victim, w.nav), "not planned until it lands")
	BotRoutes.plan(w, w.characters, 0)
	assert_eq(w.bots[0].route_state, Bot.RouteState.OK, "a bot gets the tick's search while the victim vaults")
	victim.vault.active = false
	assert_true(Elimination.walk_off_due(victim, w.nav))
	BotRoutes.want(w.bots[0], w.characters[1].position, w.cfg)
	w.bots[0].route_state = Bot.RouteState.WANTED
	BotRoutes.plan(w, w.characters, 0)
	assert_eq(w.bots[0].route_state, Bot.RouteState.WANTED, "once it has landed, its walk-off goes first")
	assert_false(Elimination.walk_off_due(victim, null), "no grid, no search to leave it")


func test_at_8v8_on_woodland_no_bot_waits_a_second_for_a_route() -> void:
	var tuning := SimTuning.load_default().duplicate() as SimTuning
	tuning.rounds = tuning.rounds.duplicate() as RoundConfig
	tuning.rounds.team_size = 8
	var runner := MatchRunner.new(self, "woodland", tuning)
	var t := runner.play(7, 60.0)
	runner.free_level()
	assert_gt(t.searches, 0)
	assert_lte(t.most_searches_a_tick, tuning.nav.search_budget, "never over the budget in a tick")
	assert_lt(t.longest_route_wait, 1.0, "no bot waits 1 s for its route")
	assert_lt(t.longest_walk_off_wait, tuning.hits.call_time, "a walk-off's route is in before the hit is called")
	gut.p("Woodland 8v8, 60 s: %d searches, at most %d a tick; longest wait %.3f s, walk-off %.3f s" % [t.searches,
			t.most_searches_a_tick, t.longest_route_wait, t.longest_walk_off_wait])


# --- the load ---

func test_woodland_s_nav_grid_builds_on_a_worker_thread_while_the_loading_screen_draws() -> void:
	var session := PlaySession.new()
	session.map_id = "woodland"
	session.autopilot = true
	session.staged = true
	var frames: Dictionary[int, int] = {}
	session.progressed.connect(func(done: int, _total: int, _key: String) -> void:
		frames[done] = Engine.get_process_frames())
	watch_signals(session)
	add_child_autofree(session)
	assert_true(await wait_until(func() -> bool: return session._nav_task >= 0, LOAD_LIMIT), "the grid builds on a task")
	var building_from := Engine.get_process_frames()
	assert_eq(frames.size(), 3, "in the teams step, its end not yet reported")
	assert_true(await wait_until(func() -> bool: return get_signal_emit_count(session, "started") > 0, LOAD_LIMIT))
	assert_gt(frames[3] - building_from, 2, "frames go on being drawn while the grid builds")
	assert_eq(session._nav_task, -1)
	assert_gt(session._sim.nav.node_count(), 200000, "Woodland's whole grid")
	assert_eq(session.state.characters.size(), 12, "6v6")


func test_a_session_freed_while_its_grid_builds_waits_for_the_task() -> void:
	var session := PlaySession.new()
	session.map_id = "woodland"
	session.staged = true
	add_child(session)
	assert_true(await wait_until(func() -> bool: return session._nav_task >= 0, LOAD_LIMIT), "the nav grid task starts within LOAD_LIMIT s")
	assert_gte(session._nav_task, 0)
	remove_child(session)
	assert_eq(session._nav_task, -1, "waited for as it left the tree")
	session.free()


func test_the_step_under_way_pulses_on_the_loading_bar() -> void:
	var screen := LoadingScreen.new()
	add_child_autofree(screen)
	screen.set_progress(2, 4, "Placing the teams")
	var first := screen.pulse()
	screen._process(LoadingScreen.PULSE_PERIOD * 0.25)
	var half := screen.pulse()
	assert_ne(first, half, "it moves")
	assert_between(half, LoadingScreen.PULSE_LOW, LoadingScreen.PULSE_HIGH)
	screen.set_progress(4, 4, "")
	assert_eq(screen.pulse(), 0.0, "nothing pulses once all are built")
