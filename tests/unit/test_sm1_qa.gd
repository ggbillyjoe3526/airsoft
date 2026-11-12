extends GutTest
## QA for SM1 (the match summary): a drawn round 1 replayed, the pause menu, a click on the last round's table, the
## setting changed mid-match, BBCode in names, the right column on a 1080p screen, freed rows on a rematch,
## HUD.update with the summary up, the records save with the new threshold, and the Attack / Defend stamp.

const K := GameEvent.Kind
const PLAYER := PlaySession.PLAYER_ID

var session: PlaySession = null


func _session(difficulty: StringName, setting: Settings.WhatGotYou = Settings.WhatGotYou.AUTO) -> PlaySession:
	var s := PlaySession.new()
	s.bots_active = false
	s.difficulty = difficulty
	s.settings = Settings.new()
	s.settings.what_got_you = setting
	add_child_autofree(s)
	return s


func _tick(kinds: Array[GameEvent.Kind], actor: int = -1, target: int = -1, value: int = 0) -> void:
	var state := session.state
	state.events.clear()
	for kind in kinds:
		var e := state.events.add(kind)
		e.actor = actor
		e.target = target
		e.value = value
	session._after_tick()
	state.events.clear()


func _hit_you(shooter: int = 3) -> void:
	session.state.time += 0.5
	_tick([K.CHARACTER_HIT], shooter, PLAYER)


## The match ends with `winner` taking it; the last round's table is left up.
func _end_match_table_up(winner: int) -> void:
	session.state.round_state.score[winner] = 5
	session.state.round_state.phase = RoundState.Phase.MATCH_OVER
	_tick([K.ROUND_OVER, K.MATCH_OVER], -1, -1, winner)
	session.hud().update(session.state, 1.0, 0.0)


func _end_match(winner: int) -> void:
	_end_match_table_up(winner)
	session._move_on()
	session.hud().update(session.state, 1.0, 0.0)


func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func _count_nodes(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count_nodes(c)
	return total


# --- the hits on you across rounds and matches ---

func test_a_drawn_round_one_replayed_keeps_the_hits_on_you() -> void:
	session = _session(&"hard")
	await wait_physics_frames(2)
	session.counts = false
	_hit_you()
	session.state.round_state.draws = 1
	_tick([K.ROUND_START], -1, -1, 1)
	assert_eq(session.hud().summary().hits().entries().size(), 1, "round 1 replayed after a draw keeps its hit")
	session.state.round_state.draws = 0
	_tick([K.ROUND_START], -1, -1, 1)
	assert_eq(session.hud().summary().hits().entries().size(), 0, "a new match forgets them")


func test_the_setting_changed_mid_match_lists_every_hit_with_the_setting_at_the_end() -> void:
	session = _session(&"easy", Settings.WhatGotYou.OFF)
	await wait_physics_frames(2)
	session.counts = false
	_hit_you()
	session.settings.what_got_you = Settings.WhatGotYou.ON
	_hit_you()
	_end_match(1)
	var hits := session.hud().summary().hits()
	assert_true(hits.visible, "On at the match's end")
	assert_eq(hits.entries().size(), 2, "the hit taken while it was Off is kept too")


func test_a_match_with_no_hits_on_you_says_nobody_got_you() -> void:
	session = _session(&"hard")
	await wait_physics_frames(2)
	session.counts = false
	_end_match(0)
	assert_eq(session.hud().summary().hits().closing_text(), tr("SUM_NO_HITS"))


# --- clicks, pause and the rematch ---

func test_a_click_on_the_last_rounds_table_moves_on_without_starting_the_match() -> void:
	session = _session(&"easy")
	await wait_physics_frames(2)
	session.counts = false
	_end_match_table_up(0)
	# The table shows once table_delay of simulation time has passed.
	session.state.time += 2.5
	session.hud().update(session.state, 1.0, 0.0)
	assert_true(session.hud().round_result().is_up(), "the last round's table is up")
	session._unhandled_input(_click())
	session.hud().update(session.state, 1.0, 0.0)
	assert_true(session.hud().summary_up(), "the click makes way for the summary")
	assert_eq(session._rematch_left, session._play.rematch_delay, "and does not start the next match")
	session._unhandled_input(_click())
	assert_eq(session._rematch_left, 0.0, "a second click starts it")


func test_the_pause_menu_over_the_summary_holds_the_wait_and_resume_does_not_start_the_match() -> void:
	session = _session(&"easy")
	await wait_physics_frames(2)
	session.counts = false
	_end_match(0)
	session._open_pause()
	session._unhandled_input(_click())
	assert_eq(session._rematch_left, session._play.rematch_delay, "a click under the pause menu starts nothing")
	session._resume()
	assert_eq(session._rematch_left, session._play.rematch_delay, "Resume starts nothing")
	assert_true(session.hud().summary_up())


func test_the_banner_stays_up_with_the_summary() -> void:
	session = _session(&"easy")
	await wait_physics_frames(2)
	session.counts = false
	_end_match(0)
	session.hud().update(session.state, 1.0, 100.0)
	assert_true(session.hud()._banner.visible, "the stamp stays while the summary is up")
	assert_string_starts_with(session.hud().banner_text(), "WON")


func test_a_click_on_the_summary_holds_fire_into_the_next_match() -> void:
	session = _session(&"easy")
	await wait_physics_frames(2)
	session.counts = false
	_end_match(0)
	session._unhandled_input(_click())
	assert_true(session._input._fire_held_back, "the click that starts the match is not a shot")


func test_a_skip_stops_at_the_match_end_and_the_hud_comes_back_for_the_summary() -> void:
	session = _session(&"easy")
	await wait_physics_frames(2)
	session.counts = false
	session._skipping = true
	session._hud.visible = false
	_end_match(0)
	assert_false(session.skipping())
	assert_true(session.hud().visible)
	assert_true(session.hud().summary_up())


# --- bbcode and translated strings ---

func test_bbcode_in_a_bot_name_and_note_shows_as_typed() -> void:
	var panel := SummaryHits.new()
	add_child_autofree(panel)
	for i in 3:
		var f := HitFacts.new()
		f.held = true
		panel.add(i + 1, f, "[b]Ro%k", Color.WHITE, "[b]Ro%k anchors: [i]holds[/i].")
	panel.fill()
	assert_eq(panel.closing_text(),
			"[b]Ro%k got you 3 times, every time holding the angle. [b]Ro%k anchors: [i]holds[/i].")


func test_every_new_string_formats_with_its_arguments() -> void:
	assert_eq(tr("SUM_STAMP_SUB") % ["Alpha", 5, 3, "Beta"], "The match · Alpha 5 – 3 Beta")
	assert_eq(tr("SUM_MATCH_TAIL") % ["Depot", "Hard"], "Depot · Hard bots")
	assert_eq(tr("SUM_RECORDS") % ["Hard", "Elimination"], "Your records · Hard Elimination")
	assert_eq(tr("SUM_EARLIER_HITS") % 2, "2 earlier")
	assert_eq(tr("SUM_WAS") % "7%", "was 7%")


# --- layout at 1080p ---

## Lost 4–5 against Hard bots, hit in 7 of the 9 rounds (Magpie three times, from cover): "1 earlier", six lines,
## Magpie's closing line with her note, and the second tip; `counted` false: the records say the match stays out.
func _fill_a_long_summary(counted: bool) -> Rect2:
	session = _session(&"hard")
	await wait_physics_frames(2)
	session.counts = false
	var hud := session.hud()
	var note := "Magpie plays it careful: walks quietly, clears each corner and watches where you ducked out of sight."
	var shooters: Array[String] = ["Rook", "Dash", "Magpie", "Rook", "Magpie", "Dash", "Magpie"]
	for i in shooters.size():
		var f := HitFacts.new()
		f.distance = 14.0
		f.held = shooters[i] == "Magpie"
		f.in_view = 0.8
		hud.add_hit_on_you(i + 1, f, shooters[i], Color.ORANGE, note.replace("Magpie", shooters[i]))
	session.state.round_state.number = 1
	_end_match(1)
	hud.summary().set_records(Records.new(), PackedInt32Array([12, 14]), Records.News.new() if counted else null,
			"Your records · Hard Elimination")
	assert_eq(hud.summary().tip_text(), tr("PRO_TIP_2"))
	hud.size = Vector2(1920.0, 1080.0)
	for i in 4:
		await wait_process_frames(1)
	var side := hud.summary()._side.get_global_rect()
	assert_false(side.intersects(hud.summary()._foot.get_global_rect()), "clear of the foot line")
	gut.p("right column %s in %s" % [side, hud.size])
	return side


func test_the_right_column_stays_on_a_1080p_screen_in_a_long_counted_match() -> void:
	var side: Rect2 = await _fill_a_long_summary(true)
	assert_true(side.end.y <= session.hud().size.y, "the right column (to %.0f) runs off the screen" % side.end.y)


func test_the_right_column_stays_on_a_1080p_screen_when_the_match_stays_out_of_the_records() -> void:
	var side: Rect2 = await _fill_a_long_summary(false)
	assert_true(side.end.y <= session.hud().size.y, "the right column (to %.0f) runs off the screen" % side.end.y)


# --- freed nodes and per-frame cost ---

func test_a_rematch_refills_the_summary_without_piling_up_nodes() -> void:
	session = _session(&"hard")
	await wait_physics_frames(2)
	session.counts = false
	var summary := session.hud().summary()
	var counts: Array[int] = []
	for m in 3:
		_tick([K.ROUND_START], -1, -1, 1)
		_hit_you()
		_hit_you(4)
		_end_match(m % 2)
		summary.set_records(Records.new(), PackedInt32Array([m, 0]), Records.News.new(), "Your records")
		await wait_process_frames(2)
		counts.append(_count_nodes(summary))
	assert_eq(counts[2], counts[1], "the same match gives the same nodes, the old ones freed")
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), 0.0, "no orphans left by fill()")


func test_hud_update_with_the_summary_up_builds_nothing_per_frame() -> void:
	session = _session(&"hard")
	await wait_physics_frames(2)
	session.counts = false
	_hit_you()
	_end_match(0)
	var hud := session.hud()
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 120:
		hud.update(session.state, 1.0, 1.0 / 60.0)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before)


# --- the records ---

func test_a_saved_best_from_fewer_than_30_bbs_still_loads_and_saves_unchanged() -> void:
	var r := Records.new()
	r.best_accuracy = 0.25
	r.streak = 3
	r.best_streak = 4
	var back := Records.new()
	assert_eq(back.from_dict(r.to_dict()).size(), 0, "no warnings")
	assert_almost_eq(back.best_accuracy, 0.25, 1e-6)
	var m := Records.Result.new()
	m.difficulty = &"hard"
	m.mode = MatchOptions.MODE_ELIMINATION
	m.hits = 20
	m.bbs_fired = 25
	assert_false(back.add(m).best_accuracy, "25 BBs: out of the accuracy record, even at 80%")
	assert_almost_eq(back.best_accuracy, 0.25, 1e-6)


func test_attack_defend_stamps_the_match_with_your_team_first_and_shows_the_summary() -> void:
	session = PlaySession.new()
	session.mode = MatchOptions.MODE_ATTACK_DEFEND
	session.bots_active = false
	session.settings = Settings.new()
	add_child_autofree(session)
	await wait_physics_frames(2)
	session.counts = false
	session.state.round_state.score[session.player.team] = 4
	_end_match(1 - session.player.team)
	assert_true(session.hud().summary_up())
	var you := tr(session._play.teams.names[session.player.team]).to_upper()
	var them := tr(session._play.teams.names[1 - session.player.team]).to_upper()
	assert_eq(session.hud().banner_text().get_slice(" / ", 0), "LOST")
	assert_string_contains(session.hud().banner_text(), "%s 4 – 5 %s" % [you, them])
	assert_eq(session.hud().summary().table().lines().size(), session.state.characters.size())


# --- attempt 2: the score bar and feed make way; the not-counted note beside the heading ---

func test_the_score_bar_and_feed_make_way_for_the_summary_and_come_back_on_the_next_match() -> void:
	session = _session(&"easy")
	await wait_physics_frames(2)
	session.counts = false
	var hud := session.hud()
	_end_match_table_up(0)
	assert_true(hud._top.visible and hud.feed().visible, "up while the last round's table holds the results")
	session._move_on()
	hud.update(session.state, 1.0, 0.0)
	assert_false(hud._top.visible, "the score bar makes way")
	assert_false(hud.feed().visible, "the feed makes way")
	session._start_now()
	_tick([K.ROUND_START], -1, -1, 1)
	hud.update(session.state, 1.0, 0.0)
	assert_true(hud._top.visible, "the score bar is back in the next match")
	assert_true(hud.feed().visible, "the feed is back in the next match")
	assert_true(hud._bottom.visible and hud._replica.visible)


func test_the_longest_heading_with_the_not_counted_note_stays_on_the_screen() -> void:
	session = _session(&"easy")
	await wait_physics_frames(2)
	session.counts = false
	_end_match(0)
	var hud := session.hud()
	hud.summary().set_records(Records.new(), PackedInt32Array([1, 2]), null,
			tr("SUM_RECORDS") % [tr("BOT_NORMAL"), tr("MODE_ATTACK_DEFEND")])
	hud.size = Vector2(1920.0, 1080.0)
	for i in 4:
		await wait_process_frames(1)
	var side := hud.summary()._side.get_global_rect()
	gut.p("records %s side %s" % [hud.summary().records().get_global_rect(), side])
	assert_true(side.end.x <= hud.size.x, "the column (to %.0f) stays on the screen" % side.end.x)
	var words: Array[String] = []
	for l in hud.summary().records().find_children("*", "Label", true, false):
		words.append((l as Label).text)
	assert_has(words, tr("SUM_NOT_COUNTED"))
