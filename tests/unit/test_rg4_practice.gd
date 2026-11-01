extends GutTest
## Practice on the Match screen, its HUD and pause menu (RG4): the Range card and what Practice leaves unused, the
## practice summary and loading kicker, the pause menu's practice form and its saved challenge switch, the readout's
## three outcomes and the challenge's banners and result.

const SETTINGS_PATH := "user://test_rg4_settings.json"

## One practice session serves every test that needs one (building it is the slow part), so those tests run in file
## order: the readout and the challenge display first, the pause menu's switch last.
var session: PlaySession = null


func before_all() -> void:
	session = PlaySession.new()
	session.practice = true
	session.map_id = "range"
	session.settings = Settings.new()
	session.settings_path = SETTINGS_PATH
	add_child(session)
	await wait_physics_frames(2)


func after_all() -> void:
	session.free()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


func _page() -> MatchPage:
	var settings := Settings.new()
	var page := MatchPage.new(MatchPicks.new(), settings)
	add_child_autofree(page)
	return page


func _event(kind: GameEvent.Kind) -> GameEvent:
	var e := session.state.events.add(kind)
	e.actor = PlaySession.PLAYER_ID
	return e


func _tick() -> void:
	session.hud().on_tick(session.state)
	session.state.events.clear()


func _target(label: String, distance: float) -> int:
	for t in session.state.targets:
		if t.label == label and is_equal_approx(t.distance, distance):
			return t.id
	return -1


# --- the Match page ---

func test_the_range_is_listed_beside_the_fields_and_hosts_only_practice() -> void:
	var catalog := MapCatalog.shared()
	var ids := PackedStringArray()
	for e in catalog.listed(false):
		ids.append(e.id)
	assert_eq(ids, PackedStringArray(["depot", "woodland", "street", "range"]), "every map is public")
	var range_entry := catalog.find("range")
	assert_eq(MatchOptions.modes_offered(range_entry), PackedStringArray(["practice"]))
	assert_eq(MatchOptions.only_tag_key("elimination", range_entry), MatchOptions.FIELDS_ONLY_KEY)
	assert_eq(MatchOptions.only_tag_key("practice", range_entry), "")
	assert_eq(MatchOptions.only_tag_key("practice", catalog.find("depot")), "", "every field hosts Practice (WL9)")
	assert_eq(MatchOptions.check_size(range_entry, 3), 1, "you alone on the range")
	assert_eq(MatchOptions.check_size(catalog.find("depot"), 3), 3)


func test_picking_the_range_picks_practice_and_greys_team_bots_and_rules() -> void:
	var page := _page()
	assert_eq(page.play_button().text, "PLAY")
	page.map_card("range").pressed.emit()
	assert_eq(page.picks.mode, MatchOptions.MODE_PRACTICE)
	assert_true(page.mode_card("practice").is_picked())
	assert_true(page.mode_card("elimination").disabled)
	assert_eq(page.play_button().text, "PRACTICE")
	assert_true(page.rules_box().is_unused())
	assert_true(page.bots_box().is_unused())
	# the level row sits in its gap's margin since UI1: that is the faded part
	assert_lt(page.bot_button("hard").get_parent().get_parent().modulate.a, 1.0)
	assert_eq(page.bot_button("hard").mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_string_contains(page.summary_text(), "No bots, no score")
	assert_false(page.is_unloadable("range"), "checked as a team of one")
	page.map_card("depot").pressed.emit()
	assert_eq(page.picks.mode, "elimination")
	assert_eq(page.play_button().text, "PLAY")
	assert_false(page.rules_box().is_unused())
	assert_false(page.bots_box().is_unused())
	assert_eq(page.bot_button("hard").mouse_filter, Control.MOUSE_FILTER_STOP)


func test_the_practice_kicker_and_summary_say_no_bots_no_score() -> void:
	assert_eq(MatchOptions.kicker("practice", 3, 0), "PRACTICE · NO BOTS, NO SCORE")
	var rest := MatchOptions.summary_rest("practice", 0, "normal")
	assert_false(rest.contains("bots") and not rest.contains("No bots"))


# --- the setting ---

func test_the_challenge_switch_is_a_setting_that_older_files_lack() -> void:
	var s := Settings.new()
	assert_false(s.practice_challenge)
	s.practice_challenge = true
	var back := Settings.new()
	back.from_dict(s.to_dict())
	assert_true(back.practice_challenge)
	var old := s.to_dict()
	old.erase("practice_challenge")
	var fresh := Settings.new()
	fresh.from_dict(old)
	assert_false(fresh.practice_challenge)


# --- the pause menu's form ---

func test_the_pause_menu_has_its_practice_form_and_goes_back() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	menu.set_practice("Range", true, 14)
	assert_true(menu.is_practice())
	assert_eq(menu.subtitle_text(), "Practice · Range · timed challenge · best 14")
	assert_true(menu.challenge_button().visible)
	assert_eq(menu.leave_button().text, "LEAVE PRACTICE")
	assert_true(menu.challenge_on())
	menu.set_practice("Range", false, 14)
	assert_eq(menu.subtitle_text(), "Practice · Range", "no challenge, no best")
	menu.set_match("Depot", "Elimination", 1, 5)
	assert_false(menu.is_practice())
	assert_false(menu.challenge_button().visible)
	assert_eq(menu.leave_button().text, "QUIT MATCH")


# --- the readout, then the challenge, then the pause switch (one session, in this order) ---

func test_the_readout_starts_with_how_the_range_works() -> void:
	assert_eq(session.hud().range_readout().lines()[0], "THE RANGE")


func test_the_readout_names_a_target_a_landing_or_a_flight_out() -> void:
	var readout := session.hud().range_readout()
	var e := _event(GameEvent.Kind.TARGET_HIT)
	e.target = _target("Steel", 30.0)
	_tick()
	var lines := readout.lines()
	assert_eq(lines[0], "LAST BB")
	assert_eq(lines[1], "Steel 30 m")
	e = _event(GameEvent.Kind.BB_IMPACT)
	e.position = Vector3(1.0, 0.0, -34.2)
	_tick()
	assert_eq(readout.lines()[1], "Missed landed 34 m downrange")
	e = _event(GameEvent.Kind.BB_LOST)
	e.position = Vector3(40.0, 2.0, -20.0)
	_tick()
	assert_eq(readout.lines()[1], "Flew out of bounds")
	assert_false(readout.lines()[2].is_empty(), "with what to try")


func test_a_lost_bb_inside_the_walls_counts_as_landed_and_others_shots_are_ignored() -> void:
	var readout := session.hud().range_readout()
	var e := _event(GameEvent.Kind.BB_LOST)
	e.position = Vector3(1.0, 3.0, -50.0)
	_tick()
	assert_eq(readout.last().kind, HudRangeReadout.Kind.LANDED)
	assert_eq(readout.last().landed, 50)
	e = _event(GameEvent.Kind.TARGET_HIT)
	e.actor = 7
	e.target = _target("Steel", 30.0)
	_tick()
	assert_eq(readout.last().kind, HudRangeReadout.Kind.LANDED, "someone else's hit changes nothing")


func test_a_target_hit_leaves_no_hit_marker() -> void:
	var before := session.hud().find_children("*", "HitMarker", true, false).size()
	var e := _event(GameEvent.Kind.TARGET_HIT)
	e.target = _target("Steel", 30.0)
	_tick()
	assert_eq(session.hud().find_children("*", "HitMarker", true, false).size(), before)


# --- the challenge ---

func test_the_challenge_hud_shows_ready_countdown_go_time_and_the_result() -> void:
	var hud := session.hud()
	var c := hud.range_challenge()
	var state := session.state
	state.challenge.best = 14
	session.set_challenge(true)
	hud.update(state, 1.0, 0.016)
	assert_string_contains(c.hint_text(), "Shoot START to begin")
	assert_string_contains(c.hint_text(), "14")
	assert_false(c.bar_visible())
	state.challenge.phase = RangeChallenge.Phase.COUNTDOWN
	var e := _event(GameEvent.Kind.CHALLENGE)
	e.value = RangeChallenge.Cue.COUNT
	e.value2 = 2
	_tick()
	hud.update(state, 1.0, 0.016)
	assert_eq(c.banner_text(), "2")
	assert_eq(c.hint_text(), "")
	state.challenge.phase = RangeChallenge.Phase.RUNNING
	state.challenge.clock = 42.0
	state.challenge.hits = 5
	e = _event(GameEvent.Kind.CHALLENGE)
	e.value = RangeChallenge.Cue.GO
	_tick()
	hud.update(state, 1.0, 0.016)
	assert_eq(c.banner_text(), "GO!")
	assert_true(c.bar_visible())
	assert_eq(c.bar_texts(), PackedStringArray(["5", "0:42", "14"]))
	hud.update(state, 1.0, HudRangeChallenge.GO_TIME + 0.1)
	assert_eq(c.banner_text(), "", "GO! goes after its time")
	var run := RangeChallenge.Run.new()
	run.hits = 15
	run.shots = 31
	run.missed = 3
	run.best = true
	state.challenge.phase = RangeChallenge.Phase.READY
	state.challenge.last = run
	e = _event(GameEvent.Kind.CHALLENGE)
	e.value = RangeChallenge.Cue.TIME
	_tick()
	hud.update(state, 1.0, 0.016)
	assert_eq(c.banner_text(), "TIME! 15 31 3 NEW BEST")
	run.best = false
	run.helped = true
	e = _event(GameEvent.Kind.CHALLENGE)
	e.value = RangeChallenge.Cue.TIME
	_tick()
	hud.update(state, 1.0, 0.016)
	assert_string_contains(c.banner_text(), "NOT KEPT")
	hud.update(state, 1.0, HudRangeChallenge.RESULT_TIME + 0.1)
	assert_eq(c.banner_text(), "")
	assert_string_contains(c.hint_text(), "Shoot START", "the START line returns")


func test_switching_the_challenge_off_clears_its_display() -> void:
	var c := session.hud().range_challenge()
	session.set_challenge(true)
	session.hud().update(session.state, 1.0, 0.016)
	session.set_challenge(false)
	session.hud().update(session.state, 1.0, 0.016)
	assert_eq(c.hint_text(), "")
	assert_false(c.bar_visible())
	assert_eq(c.banner_text(), "")


func test_the_switch_on_the_pause_menu_turns_the_challenge_on_and_saves_it_only_when_it_counts() -> void:
	session._pause.challenge_toggled.emit(true)
	assert_ne(session.state.challenge.phase, RangeChallenge.Phase.OFF)
	assert_true(session.settings.practice_challenge)
	assert_false(FileAccess.file_exists(SETTINGS_PATH), "a session that doesn't count never writes the file")
	session.counts = true
	session._pause.challenge_toggled.emit(false)
	assert_eq(session.state.challenge.phase, RangeChallenge.Phase.OFF)
	assert_false(session.settings.practice_challenge)
	session._pause.challenge_toggled.emit(true)
	var saved := Settings.new()
	saved.load_file(SETTINGS_PATH)
	assert_true(saved.practice_challenge, "written to the settings file")
	session.counts = false
