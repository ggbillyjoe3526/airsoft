extends GutTest
## The Match page, the loading screen and the seed on the pause menu (MN2): the rules as chips read from the round
## tuning, the modes a map hosts, the team you really play, every shipped map listed and a dev one tagged, a map
## that can't load greyed, a pick of a map no longer listed (or gone, as Neon Heights) falling back, the staged build
## behind the loading screen, and the picks kept across the menus being freed for a match.

const MAIN := preload("res://game/main.tscn")
## Seconds a staged build may take (its nav grid builds on a worker thread, so frames are no measure).
const LOAD_LIMIT := 20.0


func _page(dev_content: bool) -> MatchPage:
	var settings := Settings.new()
	settings.dev.dev_content = dev_content
	var page := MatchPage.new(MatchPicks.new(), settings)
	add_child_autofree(page)
	return page


func _labels(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for l in root.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


# --- the rules ---

func test_the_chips_read_the_round_tuning() -> void:
	var texts := PackedStringArray()
	for chip in MatchOptions.rule_chips(RoundConfig.new(), HitConfig.new()):
		texts.append(MatchOptions.chip_text(chip))
	assert_eq(texts, PackedStringArray(["3 v 3", "First to 5", "Rounds 2:30", "Ends swap after 4",
			"Ricochets Don't count", "Friendly fire On"]))


func test_the_chips_follow_a_changed_tuning() -> void:
	var rounds := RoundConfig.new()
	rounds.team_size = 5
	rounds.wins_needed = 7
	rounds.round_time = 95.0
	rounds.half_time_after = 6
	var hits := HitConfig.new()
	hits.ricochets_count = true
	var texts := PackedStringArray()
	for chip in MatchOptions.rule_chips(rounds, hits):
		texts.append(MatchOptions.chip_text(chip))
	assert_eq(texts, PackedStringArray(["5 v 5", "First to 7", "Rounds 1:35", "Ends swap after 6", "Ricochets Count",
			"Friendly fire On"]))


func test_the_page_shows_the_chips_the_summary_and_play() -> void:
	var page := _page(false)
	assert_eq(page.chip_texts(), PackedStringArray(["5 v 5", "First to 5", "Rounds 2:30", "Ends swap after 4",
			"Ricochets Don't count", "Friendly fire On"]))
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Normal bots")
	assert_eq(page.play_button().text, "PLAY")
	var words := _labels(page)
	for expected: String in ["MAP", "MODE", "YOUR TEAM", "BOTS", "RULES", "DEPOT"]:
		assert_true(words.has(expected), expected)
	# the map's line is its card's tooltip (UI1)
	assert_eq(page.map_card("depot").tooltip_text, "An indoor airsoft hall: three lanes, two dark tunnels.")


# --- modes ---

func test_a_map_offers_only_its_own_modes() -> void:
	var catalog := MapCatalog.shared()
	var field := PackedStringArray(["elimination", "attack_defend", "practice"])
	assert_eq(MatchOptions.modes_offered(catalog.find("depot")), field)
	assert_eq(MatchOptions.modes_offered(catalog.find("woodland")), field)
	assert_eq(MatchOptions.modes_offered(catalog.find("range")), PackedStringArray(["practice"]))
	assert_eq(MatchOptions.modes_offered(null), PackedStringArray())
	assert_true(MatchOptions.mode_pickable("elimination", catalog.find("depot"), true))
	assert_true(MatchOptions.mode_pickable("attack_defend", catalog.find("depot"), true))
	assert_false(MatchOptions.mode_pickable("attack_defend", catalog.find("depot"), false), "no pole on the map")
	assert_true(MatchOptions.mode_pickable("elimination", catalog.find("depot"), false), "Elimination needs no pole")
	assert_true(MatchOptions.mode_pickable("practice", catalog.find("depot"), true), "every field hosts Practice (WL9)")
	assert_false(MatchOptions.mode_pickable("elimination", catalog.find("range"), false), "not hosted by the range")


func test_the_kinds_modes_are_plain_arrays_read_by_a_variable_key() -> void:
	# Godot 4.7.2 can crash reading a const Dictionary[K, PackedStringArray] by a variable key (GraphicsTable's note).
	assert_eq(MatchOptions.KIND_MODES.get_typed_value_builtin(), TYPE_ARRAY)
	for kind: StringName in MatchOptions.KIND_MODES:
		var modes: Array = MatchOptions.KIND_MODES[kind]
		assert_true(modes.has("practice"), String(kind))


func test_a_pole_mode_on_a_map_without_a_pole_says_so_rather_than_later() -> void:
	var depot := MapCatalog.shared().find("depot")
	assert_true(MatchOptions.needs_pole("attack_defend", depot, false))
	assert_false(MatchOptions.needs_pole("attack_defend", depot, true))
	assert_false(MatchOptions.needs_pole("elimination", depot, false))
	assert_false(MatchOptions.needs_pole("practice", depot, false), "not built: it says later instead")


func test_every_mode_can_be_picked_on_a_field_and_none_says_range_only() -> void:
	var page := _page(false)
	assert_true(page.mode_card("elimination").is_picked())
	for mode: String in ["elimination", "attack_defend"]:
		assert_false(page.mode_card(mode).disabled, mode)
		assert_false(_labels(page.mode_card(mode)).has("LATER"), mode)
		assert_false(page.says_needs_pole(mode), "Depot has a pole")
	assert_false(page.mode_card("practice").disabled, "every field hosts Practice (WL9)")
	assert_false(_labels(page.mode_card("practice")).has("RANGE ONLY"))
	assert_false(_labels(page.mode_card("practice")).has("LATER"))
	for level: String in MatchOptions.BOT_LEVELS:
		assert_false(page.bot_button(level).disabled, level)
		assert_true(page.bot_button(level).visible, level)
	assert_true(page.bot_button("normal").is_picked())


func test_picking_attack_defend_names_who_attacks_first() -> void:
	var page := _page(false)
	assert_eq(page.attack_line(), "", "Elimination has no attackers")
	page.mode_card("attack_defend").pressed.emit()
	assert_eq(page.picks.mode, "attack_defend")
	assert_true(page.mode_card("attack_defend").is_picked())
	assert_eq(page.attack_line(), "Alpha attacks first, sides swap at half time")
	assert_string_contains(page.summary_text(), "attacks first")
	page.team_card(1).pressed.emit()
	assert_string_contains(page.attack_line(), "Beta attacks first", "the team you pick attacks first")


func test_hard_is_offered_without_dev_content_and_named_in_the_summary() -> void:
	var page := _page(false)
	var hard := page.bot_button("hard")
	assert_false(_labels(hard).has("DEV"), "a public level, no DEV tag")
	hard.pressed.emit()
	assert_eq(page.picks.bots, "hard")
	assert_true(hard.is_picked())
	assert_string_ends_with(page.summary_text(), "Hard bots")


func test_there_are_three_levels_and_a_new_player_starts_on_normal() -> void:
	var page := _page(false)
	assert_eq(MatchOptions.BOT_LEVELS, PackedStringArray(["easy", "normal", "hard"]))
	assert_null(page.bots_box().find_child("*_pro", true, false), "no Pro button (TL1)")
	assert_eq(MatchPicks.new().bots, "normal")
	assert_true(page.bot_button("normal").is_picked())


# --- maps ---

func test_every_shipped_map_is_public_and_a_dev_one_is_tagged() -> void:
	var page := _page(false)
	assert_eq(page.map_ids(), PackedStringArray(["depot", "woodland", "street", "range"]), "listed with Dev content off")
	for id: String in page.map_ids():
		assert_false(_labels(page.map_card(id)).has("DEV"), id)
		assert_false(page.is_unloadable(id), id)
	var was := DevContent.use_map()
	var dev := _page(true)
	DevContent.restore_map(was)
	assert_true(_labels(dev.map_card("woodland")).has("DEV"), "a dev map is tagged")
	assert_false(_labels(dev.map_card("woodland")).has("LATER"))
	assert_false(_labels(dev.map_card("depot")).has("DEV"))
	for id: String in ["depot", "woodland"]:
		assert_true(MatchOptions.map_problems(id, PlayTuning.load_default().map_style, 3).is_empty(), id)
	page.map_card("woodland").pressed.emit()
	assert_eq(page.picks.map_id, "woodland")
	assert_true(page.summary_text().begins_with("Woodland · "))


func test_a_map_that_cant_load_is_greyed_with_later_and_listed_last() -> void:
	var page := _page(true)
	# A catalogue naming a field with no file yet, so MapData refuses it, picked.
	page._catalog = MapCatalog.parse(FileAccess.get_file_as_string(MapCatalog.PATH).replace(
			"| range | Range |", "| ghost | Ghost | field | public | 5 | 5 | 6 | No file yet. |\n| range | Range |"))
	assert_not_null(page._catalog.find("ghost"))
	page.picks.map_id = "ghost"
	page._offered = PackedStringArray()
	page._list_maps()
	assert_eq(page.map_ids(), PackedStringArray(["depot", "woodland", "street", "range", "ghost"]))
	var ghost := page.map_card("ghost")
	assert_true(page.is_unloadable("ghost"))
	assert_true(ghost.disabled)
	assert_lt(ghost.modulate.a, 1.0)
	assert_true(_labels(ghost).has("LATER"))
	assert_false(MatchOptions.map_problems("ghost", PlayTuning.load_default().map_style, 5).is_empty())
	assert_ne(page.picks.map_id, "ghost", "the pick moves to a map that can play")


func test_no_dev_maps_listed_with_dev_content_off() -> void:
	var was := DevContent.use_map()
	var page := _page(false)
	DevContent.restore_map(was)
	assert_eq(page.map_ids(), PackedStringArray(["depot", "street", "range"]))
	assert_true(page.map_card("depot").is_picked())


func test_picking_a_map_lights_its_card_and_the_summary() -> void:
	var page := _page(true)
	page.map_card("woodland").pressed.emit()
	assert_eq(page.picks.map_id, "woodland")
	assert_true(page.map_card("woodland").is_picked())
	assert_false(page.map_card("depot").is_picked())
	assert_true(page.summary_text().begins_with("Woodland · "))


func test_a_picked_map_that_is_no_longer_listed_falls_back_to_a_playable_one() -> void:
	var was := DevContent.use_map()
	var picks := MatchPicks.new()
	picks.map_id = "woodland" # a dev map, dev content off: not listed
	var page := MatchPage.new(picks, Settings.new())
	add_child_autofree(page)
	DevContent.restore_map(was)
	assert_eq(picks.map_id, "depot")
	var gone := MatchPicks.new()
	gone.map_id = "neonHeights" # a map taken out of the game (2026-10-29)
	add_child_autofree(MatchPage.new(gone, Settings.new()))
	assert_eq(gone.map_id, "depot", "a map no longer in the game falls back to Depot")


# --- your team and the picks ---

func test_your_team_is_alpha_or_beta_and_the_cards_say_nothing_else() -> void:
	var page := _page(false)
	assert_eq(page.team_card(0).text, "ALPHA", "a text card: the team's name and nothing else")
	assert_eq(page.team_card(1).text, "BETA")
	assert_eq(_labels(page.team_card(0)), PackedStringArray())
	assert_true(page.team_card(0).is_picked())
	page.team_card(1).pressed.emit()
	assert_eq(page.picks.team, PlaySession.TEAM_BETA)
	assert_true(page.team_card(1).is_picked())
	assert_false(page.team_card(0).is_picked())
	assert_eq(page.summary_text(), "Depot · Elimination · Beta · Normal bots")


func test_the_picks_survive_the_page_being_built_again() -> void:
	var picks := MatchPicks.new()
	var settings := Settings.new()
	var first := MatchPage.new(picks, settings)
	add_child(first)
	first.team_card(1).pressed.emit()
	first.free()
	var second := MatchPage.new(picks, settings)
	add_child_autofree(second)
	assert_true(second.team_card(1).is_picked())
	assert_false(second.team_card(0).is_picked())


func test_the_page_lets_go_of_the_settings_when_freed() -> void:
	var settings := Settings.new()
	var page := MatchPage.new(MatchPicks.new(), settings)
	add_child(page)
	assert_eq(settings.changed.get_connections().size(), 1)
	page.free()
	assert_eq(settings.changed.get_connections().size(), 0)


# --- the team actually played ---

func test_beta_picked_means_character_zero_is_on_team_one() -> void:
	var session := PlaySession.new()
	session.autopilot = true
	session.player_team = PlaySession.TEAM_BETA
	add_child_autofree(session)
	await wait_physics_frames(2)
	var size := session._tuning.rounds.team_size # the map's standard size
	assert_eq(session.state.characters[0].team, 1)
	assert_eq(session.player.team, 1)
	assert_eq(session.opponent_team(), 0)
	var per_team := PackedInt32Array([0, 0])
	for c in session.state.characters:
		per_team[c.team] += 1
	assert_eq(per_team, PackedInt32Array([size, size]))
	var mates := 0
	for c in session.state.characters:
		if c.team == 1 and c.id != 0:
			mates += 1
	assert_eq(mates, size - 1, "your teammates are on Beta with you")
	assert_eq(session.player.end, Round.team_end(1, 1, SimTuning.new().rounds), "you start at Beta's end")


func test_out_on_beta_you_watch_a_beta_teammate() -> void:
	var session := PlaySession.new()
	session.autopilot = false
	session.bots_active = false
	session.player_team = PlaySession.TEAM_BETA
	add_child_autofree(session)
	await wait_physics_frames(2)
	session.player.status = Character.Status.OUT
	assert_eq(session.spectated().team, 1)
	assert_ne(session.spectated(), session.player)


func test_alpha_is_still_the_default_team() -> void:
	var session := PlaySession.new()
	session.autopilot = true
	add_child_autofree(session)
	await wait_physics_frames(2)
	assert_eq(session.player.team, 0)


# --- the pause menu's words ---

func test_the_pause_menu_names_the_match_and_shows_its_seed() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	menu.set_match("Depot", "Elimination", 3, 48213)
	assert_eq(menu.subtitle_text(), "Depot · Elimination · Round 3")
	assert_eq(menu.seed_text(), "48213")
	var words := _labels(menu)
	assert_true(words.has("PAUSED"))
	assert_true(words.has("Match seed"))


func test_pausing_a_match_shows_its_own_seed_map_and_round() -> void:
	var session := PlaySession.new()
	session.autopilot = true
	session.match_seed = 777
	add_child_autofree(session)
	await wait_physics_frames(2)
	session._open_pause()
	var menu := session.find_child("PauseMenu", true, false) as PauseMenu
	assert_eq(menu.seed_text(), str(session.state.match_seed))
	assert_eq(menu.seed_text(), "777")
	assert_eq(menu.subtitle_text(), "Depot · Elimination · Round 1")
	session._resume()


# --- the loading screen ---

func test_the_loading_screen_shows_the_matchs_words_and_a_bar() -> void:
	var screen := LoadingScreen.new()
	add_child_autofree(screen)
	screen.setup("depot", "Depot", "An abandoned warehouse yard.", MatchOptions.kicker("elimination", 3, 0))
	assert_eq(screen.kicker_text(), "ELIMINATION · 3 V 3 · YOU'RE ALPHA")
	assert_eq(screen.title_text(), "DEPOT")
	assert_eq(screen.blurb_text(), "An abandoned warehouse yard.")
	assert_eq(MatchOptions.kicker("elimination", 3, 1), "ELIMINATION · 3 V 3 · YOU'RE BETA")
	screen.set_progress_step(2, 4, "LOAD_TEAMS")
	assert_almost_eq(screen.progress(), 0.5, 1e-6)
	assert_eq(screen.percent_text(), "50 %")
	assert_eq(screen.step_text(), "Placing the teams")
	screen.set_progress_step(4, 4, "")
	assert_almost_eq(screen.progress(), 1.0, 1e-6)
	assert_eq(screen.percent_text(), "100 %")


func test_a_staged_build_reports_every_step_then_starts_once_drawn() -> void:
	var session := PlaySession.new()
	session.autopilot = true
	session.staged = true
	var reports: Array = []
	session.progressed.connect(func(done: int, total: int, key: String) -> void:
		reports.append([done, total, key, Engine.get_process_frames()]))
	watch_signals(session)
	add_child_autofree(session)
	assert_eq(reports.size(), 1)
	assert_eq(reports[0].slice(0, 3), [0, 4, "LOAD_MAP"])
	assert_null(session.state, "nothing built before the first frame")
	assert_true(await wait_until(func() -> bool: return get_signal_emit_count(session, "started") > 0, LOAD_LIMIT))
	assert_signal_emit_count(session, "started", 1)
	assert_eq(reports.size(), 5, "0 to 4 of 4")
	var keys: Array = []
	for r: Array in reports:
		keys.append(r.slice(0, 3))
	assert_eq(keys, [[0, 4, "LOAD_MAP"], [1, 4, "LOAD_LEVEL"], [2, 4, "LOAD_TEAMS"], [3, 4, "LOAD_VIEWS"], [4, 4, ""]])
	for i in range(2, reports.size()):
		assert_gt(reports[i][3], reports[i - 1][3], "a step a frame, not all at once")
	assert_not_null(session.state)
	await wait_physics_frames(3)
	assert_gt(session.ticks(), 0, "the match runs once built")


func test_woodland_builds_staged_at_its_standard_size_and_runs() -> void:
	var session := PlaySession.new()
	session.map_id = "woodland"
	session.autopilot = true
	session.staged = true
	watch_signals(session)
	add_child_autofree(session)
	assert_true(await wait_until(func() -> bool: return get_signal_emit_count(session, "started") > 0, LOAD_LIMIT), "the build starts the match within LOAD_LIMIT s")
	assert_signal_emit_count(session, "started", 1)
	assert_not_null(session.state, "Woodland loads and builds")
	if session.state == null:
		return
	assert_eq(session.state.characters.size(), MapCatalog.shared().find("woodland").team_standard * 2, "5v5")
	await wait_physics_frames(30)
	assert_gt(session.ticks(), 0, "the match runs")
	for c in session.state.characters:
		assert_true(c.grounded, "%d stands on the ground" % c.id)


func test_a_staged_refused_map_still_starts_so_the_loading_screen_goes() -> void:
	var session := PlaySession.new()
	session.map_id = "nowhere" # no such file: refused
	session.staged = true
	watch_signals(session)
	add_child_autofree(session)
	var frames := 0
	while get_signal_emit_count(session, "started") == 0 and frames < 30:
		await wait_process_frames(1)
		frames += 1
	assert_push_error("refused")
	assert_signal_emit_count(session, "started", 1)
	assert_null(session.state)


# --- the entry scene ---

func test_play_frees_the_menus_shows_loading_and_frees_it_once_the_match_runs() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._picks.team = PlaySession.TEAM_BETA
	main._start_play()
	assert_not_null(main._loading)
	assert_eq(main._loading.kicker_text(), "ELIMINATION · 5 V 5 · YOU'RE BETA")
	assert_eq(main._loading.title_text(), "DEPOT")
	assert_null(main._title, "no title node lives during a match")
	assert_null(main._menus, "no menu nodes live during a match")
	assert_true(await wait_until(func() -> bool: return main._loading == null, LOAD_LIMIT))
	assert_null(main._loading, "freed once the match has drawn")
	var play: PlaySession = main._play
	assert_eq(play.player_team, PlaySession.TEAM_BETA)
	await wait_process_frames(2)
	assert_eq(main.find_children("*", "LoadingScreen", true, false).size(), 0)
	main._end_play()
	await wait_process_frames(2)
	assert_not_null(main._title)
	assert_not_null(main._menus)
	assert_true(main._menus.match_page().team_card(1).is_picked(), "the pick is still there")
