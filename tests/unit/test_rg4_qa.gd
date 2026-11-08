extends GutTest
## RG4 QA: what the worker's tests leave out. The Match page's picks across the Range and back, the real challenge
## timeline (START shot, countdown, run, Time) through the session's own tick, a best kept or not kept, the saved
## switch in an old, odd or reset settings file, and the start and leave round trip from the entry scene.

const MAIN := preload("res://game/main.tscn")
const TICK := PlaySession.TICK
## The cut-down run, in seconds.
const RUN_TIME := 6.0

var _paths: PackedStringArray = PackedStringArray()
## One practice session for the challenge tests (building it is the slow part), put back to a clean range by `_fresh`.
var _shared: PlaySession = null


func before_all() -> void:
	_shared = PlaySession.new()
	_shared.practice = true
	_shared.map_id = "range"
	_shared.settings = Settings.new()
	add_child(_shared)
	await wait_physics_frames(2)
	# It never ticks by itself: the tests step its challenge and its HUD by hand. A run is cut to a few seconds.
	_shared._running = false
	_shared._tuning.targets = _shared._tuning.targets.duplicate() as RangeConfig
	_shared._tuning.targets.challenge_run_time = RUN_TIME


func after_all() -> void:
	_shared.free()


func after_each() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for p in _paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_paths.clear()


func _temp(stem: String) -> String:
	var p := "user://test_rg4_qa_%s.save" % stem
	_paths.append(p)
	return p


## The shared session with a clean challenge (off, no best, no last run) and records of its own, as the range opens.
func _fresh(counts: bool) -> PlaySession:
	var s := _shared
	s.set_challenge(false)
	s.hud().update(s.state, 1.0, TICK)
	var ch := s.state.challenge
	ch.best = 0
	ch.last = null
	ch.helped = false
	ch.hits = 0
	ch.shots = 0
	ch.missed = 0
	s.state.events.clear()
	s.counts = counts
	s.settings_path = _temp("settings")
	s.records = Records.new()
	s.records_path = _temp("records")
	return s


## One simulation tick of the range as the session takes it: the events of `hits` (target ids the player hit, one
## SHOT each) go in, the challenge steps, and the tick's events reach the session and the HUD.
func _step(s: PlaySession, hits: Array[int] = [], cheating: bool = false) -> void:
	var st := s.state
	st.events.clear()
	for id in hits:
		var shot := st.events.add(GameEvent.Kind.SHOT)
		shot.actor = PlaySession.PLAYER_ID
		var hit := st.events.add(GameEvent.Kind.TARGET_HIT)
		hit.actor = PlaySession.PLAYER_ID
		hit.target = id
		hit.value = st.targets[id].kind
	st.challenge.step(st.targets, st.events, s._tuning.targets, TICK, st.rng, cheating)
	s._after_tick()
	s.hud().update(st, 1.0, TICK)


func _start_plate(s: PlaySession) -> int:
	for t in s.state.targets:
		if t.start:
			return t.id
	return -1


func _a_lit_target(s: PlaySession) -> int:
	for t in s.state.targets:
		if t.lit > 0.0:
			return t.id
	return -1


## Plays a whole run: START, the countdown, `hit_count` lit targets hit one a tick from the run's start, then the clock
## out. Returns the banner texts seen, in order, without repeats.
func _play_run(s: PlaySession, hit_count: int, cheating: bool = false) -> PackedStringArray:
	var c := s.hud().range_challenge()
	var seen := PackedStringArray()
	_step(s, [_start_plate(s)] as Array[int], cheating)
	var guard := 0
	var hit_left := hit_count
	while s.state.challenge.phase != RangeChallenge.Phase.READY or guard == 0:
		guard += 1
		if guard > 60 * 20:
			break
		var hits: Array[int] = []
		if s.state.challenge.phase == RangeChallenge.Phase.RUNNING and hit_left > 0:
			var lit := _a_lit_target(s)
			if lit >= 0:
				hits.append(lit)
				hit_left -= 1
		_step(s, hits, cheating)
		var words := c.banner_text()
		if not words.is_empty() and (seen.is_empty() or seen[seen.size() - 1] != words):
			seen.append(words)
	return seen


# --- the Match page ---

func test_the_range_and_back_to_a_field_keeps_team_bots_rules_and_mode() -> void:
	var picks := MatchPicks.new()
	var page := MatchPage.new(picks, Settings.new())
	add_child_autofree(page)
	page.mode_card("attack_defend").pressed.emit()
	page.team_card(PlaySession.TEAM_BETA).pressed.emit()
	page.bot_button("hard").pressed.emit()
	picks.rules = MatchOptions.RULES_CUSTOM
	assert_eq(picks.mode, "attack_defend", "set up")
	page.map_card("range").pressed.emit()
	assert_eq(picks.mode, MatchOptions.MODE_PRACTICE)
	assert_eq(picks.team, PlaySession.TEAM_BETA, "the range leaves your team alone")
	assert_eq(picks.bots, "hard", "and the bots' level")
	assert_eq(picks.rules, MatchOptions.RULES_CUSTOM, "and the rule set")
	page.map_card("depot").pressed.emit()
	assert_eq(picks.team, PlaySession.TEAM_BETA)
	assert_eq(picks.bots, "hard")
	assert_eq(picks.rules, MatchOptions.RULES_CUSTOM)
	assert_eq(picks.mode, "attack_defend", "the mode picked before the Range comes back with the field")
	assert_false(page.rules_box().is_unused())
	assert_false(page.bots_box().is_unused())


func test_the_field_mode_comes_back_in_every_order_of_picks() -> void:
	var picks := MatchPicks.new()
	var page := MatchPage.new(picks, Settings.new())
	add_child_autofree(page)
	# The Range picked first on a fresh page, then a field: the default mode (BP8).
	page.map_card("range").pressed.emit()
	page.map_card("depot").pressed.emit()
	assert_eq(picks.mode, "attack_defend")
	# A mode changed on the field after coming back is the one that returns next.
	page.mode_card("attack_defend").pressed.emit()
	page.map_card("range").pressed.emit()
	page.map_card("depot").pressed.emit()
	assert_eq(picks.mode, "attack_defend")
	page.mode_card("elimination").pressed.emit()
	page.map_card("range").pressed.emit()
	page.map_card("depot").pressed.emit()
	assert_eq(picks.mode, "elimination", "the newer pick wins over the older")
	# A field with no pole cannot host Attack / Defend: Elimination, and the remembered mode is not forced.
	page.mode_card("attack_defend").pressed.emit()
	page.map_card("range").pressed.emit()
	page._poles["depot"] = false
	page.map_card("depot").pressed.emit()
	assert_eq(picks.mode, "elimination", "no pole: Attack / Defend is not offered")
	assert_false(page.mode_card("practice").is_picked())
	page.map_card("range").pressed.emit()
	page._poles["depot"] = true
	page.map_card("depot").pressed.emit()
	assert_eq(picks.mode, "elimination", "the pole-less field's mode is what was last picked there")


func test_the_range_card_and_summary_name_the_range_and_no_bots_no_score() -> void:
	var page := MatchPage.new(MatchPicks.new(), Settings.new())
	add_child_autofree(page)
	page.map_card("range").pressed.emit()
	assert_eq(page.summary_text(), "Range · Practice · No bots, no score")
	assert_false(page.mode_card("practice").disabled)
	assert_true(page.mode_card("elimination").disabled)
	assert_true(page.mode_card("attack_defend").disabled)


# --- the settings file ---

func test_the_challenge_switch_falls_back_to_off_on_an_odd_value_and_a_reset() -> void:
	for odd: Variant in ["yes", 1, null, [true]]:
		var s := Settings.new()
		var data := s.to_dict()
		data["practice_challenge"] = odd
		s.from_dict(data)
		assert_false(s.practice_challenge, "a %s is not a switch" % type_string(typeof(odd)))
	var on := Settings.new()
	on.practice_challenge = true
	var path := _temp("reset")
	on.save(path)
	var again := Settings.new()
	again.load_file(path)
	assert_true(again.practice_challenge, "kept in the file")
	again.reset_save(path)
	assert_false(again.practice_challenge, "a reset of the save turns it off")


func test_an_older_settings_file_without_the_switch_loads_with_the_rest_intact() -> void:
	var old := Settings.new()
	old.fov = 95.0
	var data := old.to_dict()
	data.erase("practice_challenge")
	var path := _temp("old")
	SaveFile.write(path, Settings.KIND, Settings.VERSION, data)
	var loaded := Settings.new()
	loaded.practice_challenge = true
	loaded.load_file(path)
	assert_false(loaded.practice_challenge, "off when the file has no switch")
	assert_eq(loaded.fov, 95.0)
	assert_eq(loaded.load_message, "", "an older file is no warning")


# --- the challenge, through the session's own tick ---

func test_a_whole_challenge_run_shows_ready_countdown_go_the_bar_and_the_result() -> void:
	var s := _fresh(true)
	s.state.challenge.best = 3
	s.set_challenge(true)
	var c := s.hud().range_challenge()
	s.hud().update(s.state, 1.0, TICK)
	assert_string_contains(c.hint_text(), "Shoot START to begin")
	assert_false(c.bar_visible())
	assert_false(s.hud().range_readout().visible, "the challenge's display takes the readout's place")
	var seen := _play_run(s, 5)
	assert_eq(seen[0], "3")
	assert_eq(seen[1], "2")
	assert_eq(seen[2], "1")
	assert_eq(seen[3], "GO!")
	assert_string_contains(seen[4], "TIME! 5")
	assert_string_contains(seen[4], "NEW BEST")
	assert_eq(s.state.challenge.best, 5)
	assert_eq(s.records.challenge_best("range"), 5, "a new best is kept")
	assert_true(s.records.results.is_empty(), "practice is no match: no win or loss recorded")


func test_a_run_helped_by_a_dev_setting_says_not_kept_and_keeps_nothing() -> void:
	var s := _fresh(true)
	s.set_challenge(true)
	var seen := _play_run(s, 4, true)
	assert_string_contains(seen[seen.size() - 1], "NOT KEPT")
	assert_eq(s.records.challenge_best("range"), 0, "never kept")
	assert_false(s.records.dirty, "and no write to the records")
	assert_false(FileAccess.file_exists(s.records_path))
	assert_eq(s.state.challenge.best, 0, "the bar's best does not move either")


func test_a_run_that_does_not_beat_the_best_shows_no_tag_and_keeps_the_best() -> void:
	var s := _fresh(true)
	s.records.best_challenge["range"] = 9
	s.state.challenge.best = 9
	s.set_challenge(true)
	var seen := _play_run(s, 2)
	var last := seen[seen.size() - 1]
	assert_string_contains(last, "TIME! 2")
	assert_false(last.contains("NEW BEST") or last.contains("NOT KEPT"), "a plain run: no tag")
	assert_eq(s.records.challenge_best("range"), 9)
	assert_eq(s.hud().range_challenge().bar_texts()[2], "9")


func test_a_session_that_does_not_count_never_writes_the_records() -> void:
	var s := _fresh(false)
	s.set_challenge(true)
	_play_run(s, 3)
	assert_eq(s.records.challenge_best("range"), 0)
	assert_false(FileAccess.file_exists(s.records_path))


func test_the_start_plate_goes_while_the_run_counts_down_and_returns_after_time() -> void:
	var s := _fresh(false)
	s.set_challenge(true)
	var plate := s.state.targets[_start_plate(s)]
	assert_false(plate.hidden, "READY: the plate stands")
	_step(s, [plate.id] as Array[int])
	assert_eq(s.state.challenge.phase, RangeChallenge.Phase.COUNTDOWN)
	assert_true(plate.hidden, "gone through the countdown")
	var c := s.hud().range_challenge()
	assert_eq(c.banner_text(), "3")
	assert_true(c.bar_visible())
	assert_eq(c.bar_texts()[0], "0", "hits read 0 through the countdown")
	assert_eq(c.bar_texts()[1], "1:00", "and the clock the run's whole length")
	for i in 60 * 20:
		if s.state.challenge.phase == RangeChallenge.Phase.READY:
			break
		_step(s)
	assert_false(plate.hidden, "back for another go")
	assert_eq(c.banner_kind(), HudRangeChallenge.Banner.TIME)


func test_go_goes_after_its_time_and_the_bar_counts_the_run_down() -> void:
	var s := _fresh(false)
	s.set_challenge(true)
	var c := s.hud().range_challenge()
	_step(s, [_start_plate(s)] as Array[int])
	for i in 60 * 3 + 2:
		_step(s)
	assert_eq(s.state.challenge.phase, RangeChallenge.Phase.RUNNING)
	assert_eq(c.banner_text(), "GO!")
	for i in ceili(HudRangeChallenge.GO_TIME / TICK) + 2:
		_step(s)
	assert_eq(c.banner_text(), "", "GO! is up for its short time only")
	assert_true(c.bar_visible())
	assert_eq(c.bar_texts()[1], HudStyle.clock_text(ceili(s.state.challenge.clock)))


func test_the_result_stays_its_time_with_the_bar_then_the_start_line_returns() -> void:
	var s := _fresh(false)
	s.set_challenge(true)
	_play_run(s, 1)
	var c := s.hud().range_challenge()
	assert_true(c.bar_visible(), "the bar stays with the result")
	assert_eq(c.hint_text(), "", "no START line over the result")
	for i in ceili(HudRangeChallenge.RESULT_TIME / TICK) + 2:
		_step(s)
	assert_eq(c.banner_text(), "")
	assert_false(c.bar_visible())
	assert_string_contains(c.hint_text(), "Shoot START")


func test_a_second_run_clears_the_first_runs_tag() -> void:
	var s := _fresh(true)
	s.set_challenge(true)
	var first := _play_run(s, 3)
	assert_string_contains(first[first.size() - 1], "NEW BEST")
	var second := _play_run(s, 1)
	var last := second[second.size() - 1]
	assert_string_contains(last, "TIME! 1")
	assert_false(last.contains("NEW BEST"), "last run's tag does not stay")


func test_switching_off_mid_run_drops_the_run_and_shows_the_readout_again() -> void:
	var s := _fresh(true)
	s.set_challenge(true)
	_step(s, [_start_plate(s)] as Array[int])
	for i in 60 * 4:
		_step(s)
	assert_eq(s.state.challenge.phase, RangeChallenge.Phase.RUNNING)
	s._pause.challenge_toggled.emit(false)
	_step(s)
	var c := s.hud().range_challenge()
	assert_eq(s.state.challenge.phase, RangeChallenge.Phase.OFF)
	assert_false(c.bar_visible())
	assert_eq(c.banner_text(), "")
	assert_eq(c.hint_text(), "")
	assert_true(s.hud().range_readout().visible, "the readout is back")
	assert_eq(s.records.challenge_best("range"), 0, "a dropped run scores nothing")
	assert_false(s.hud().has_node("RangeLane/RangeReadout/HitMarker"))


func test_pausing_mid_run_stops_the_clock_and_resuming_goes_on() -> void:
	var s := _fresh(false)
	s.set_challenge(true)
	_step(s, [_start_plate(s)] as Array[int])
	for i in 60 * 4:
		_step(s)
	s._running = true
	var before := s.state.challenge.clock
	s._open_pause()
	assert_true(get_tree().paused)
	assert_true(s._pause.is_practice())
	assert_eq(s._pause.subtitle_text(), "Practice · Range · timed challenge")
	await wait_physics_frames(5)
	assert_eq(s.state.challenge.clock, before, "the run waits")
	s._resume()
	assert_false(get_tree().paused)
	await wait_physics_frames(5)
	assert_lt(s.state.challenge.clock, before, "and goes on after")
	s._running = false


# --- start practice and leave, from the entry scene ---

func test_start_practice_opens_the_range_and_leaving_comes_back_to_the_match_page() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._picks.map_id = "range"
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._picks.team = PlaySession.TEAM_BETA
	main._picks.bots = "hard"
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	main._start_play()
	assert_true(main._play.practice, "PRACTICE plays the range")
	assert_eq(main._play.map_id, "range")
	assert_eq(main._play.mode, MatchOptions.MODE_PRACTICE)
	assert_true(main._play.counts, "a player's practice counts (the best is kept)")
	await wait_for_signal(main._play.started, 20.0)
	assert_null(main._menus, "no menu nodes live during practice")
	assert_not_null(main._play.hud().range_readout())
	main._play.state.challenge.set_on(true, main._play.state.targets, main._play._tuning.targets, main._play.state.rng)
	main._play.state.challenge.phase = RangeChallenge.Phase.COUNTDOWN
	main._play._pause.left.emit()
	assert_null(main._play, "the session is gone")
	await wait_process_frames(3)
	assert_true(main._menus.visible, "back on the menus")
	var page: MatchPage = main._menus.match_page()
	assert_eq(main._menus.page_tab(), NavRail.Tab.MATCH)
	assert_true(main._picks.map_id == "range" and main._picks.mode == MatchOptions.MODE_PRACTICE, "Practice still picked")
	assert_eq(main._picks.team, PlaySession.TEAM_BETA, "team and bots untouched")
	assert_eq(main._picks.bots, "hard")
	assert_eq(page.play_button().text, "PRACTICE")
	assert_true(page.map_card("range").is_picked())
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), nodes_before, "no node left behind")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	assert_false(get_tree().paused)
	main.free()
