extends GutTest
## The match summary (SM1; concept `summary.png`): the WON / LOST stamp with the score, everyone's match numbers, the
## records for this difficulty and mode with NEW RECORD (accuracy from 30 BBs), What got you for each hit on you, the
## next Pro tip, and the next match starting on its own or on a click.

const K := GameEvent.Kind

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


## The bot playing character 3 hits you in the round in play, as the simulation would report it.
func _hit_you() -> void:
	_tick([K.CHARACTER_HIT], 3, PlaySession.PLAYER_ID)


## The match ends with `winner` taking it, the last round's table clicked away.
func _end_match(winner: int) -> void:
	session.state.round_state.score[winner] = 5
	session.state.round_state.phase = RoundState.Phase.MATCH_OVER
	_tick([K.ROUND_OVER, K.MATCH_OVER], -1, -1, winner)
	session._move_on()
	session.hud().update(session.state, 1.0, 0.0)


func _entry(shooter: String, held: bool, note: String = "") -> SummaryHits.Entry:
	var e := SummaryHits.Entry.new()
	e.shooter = shooter
	e.note = note
	e.facts.held = held
	e.facts.held_known = true
	return e


# --- the records ---

func test_accuracy_counts_from_30_bbs_and_a_new_best_keeps_the_one_before() -> void:
	var r := Records.new()
	var m := Records.Result.new()
	m.hits = 9
	m.bbs_fired = 29
	assert_false(r.add(m).best_accuracy, "29 BBs are too few")
	m.bbs_fired = 30
	var first := r.add(m)
	assert_true(first.best_accuracy)
	assert_eq(first.was_accuracy, -1.0, "no best before")
	m.hits = 12
	var second := r.add(m)
	assert_true(second.best_accuracy)
	assert_almost_eq(second.was_accuracy, 0.3, 1e-5)


func test_the_records_panel_tags_a_new_record_with_the_best_before() -> void:
	var r := Records.new()
	r.best_accuracy = 0.09
	r.streak = 2
	r.best_streak = 4
	var news := Records.News.new()
	news.best_accuracy = true
	news.was_accuracy = 0.07
	var panel := SummaryRecords.new()
	add_child_autofree(panel)
	panel.fill(r, PackedInt32Array([5, 6]), news, "Your records · Hard Elimination")
	assert_eq(panel.values(), PackedStringArray(["5 won · 6 lost", "9% NEW RECORD was 7%", "2 best 4"]))


func test_a_match_out_of_the_records_says_so_and_no_best_yet_says_from_how_many_bbs() -> void:
	var panel := SummaryRecords.new()
	add_child_autofree(panel)
	panel.fill(Records.new(), PackedInt32Array([0, 0]), null, "Your records · Easy Elimination")
	assert_eq(panel.values()[1], "– counts from 30 BBs")
	var words: Array[String] = []
	for l in panel.find_children("*", "Label", true, false):
		words.append((l as Label).text)
	assert_has(words, "Not counted this match")


# --- what got you ---

func test_each_hit_reads_its_side_distance_and_held_angle_or_time_in_view() -> void:
	var f := HitFacts.new()
	var victim := Character.new(0, 0)
	f.record(1.0, victim, Character.new(3, 1, Vector3(-18.0, 0.0, 0.0)), false, true, true, 0.4, 1.0)
	assert_eq(SummaryHits.hit_bbcode(f),
			"From your left, 18 m · [color=#%s]holding the angle[/color]" % GameTheme.ACCENT.to_html(false))
	f.record(1.0, victim, Character.new(3, 1, Vector3(0.0, 0.0, 9.0)), true, false, false, 1.6, 1.0)
	assert_eq(SummaryHits.hit_bbcode(f), "From behind, 9 m · seen for 1.6 s · off a bounce")


func test_the_closing_line_names_who_got_you_most_with_their_note() -> void:
	var hits: Array[SummaryHits.Entry] = [_entry("Rook", true, "Rook anchors: holds one spot."), _entry("Magpie", false),
			_entry("Rook", true, "Rook anchors: holds one spot.")]
	var panel := SummaryHits.new()
	add_child_autofree(panel)
	for e in hits:
		panel.add(1, e.facts, e.shooter, e.colour, e.note)
	panel.fill()
	assert_eq(panel.closing_text(), "Rook got you twice, both times holding the angle. Rook anchors: holds one spot.")
	hits.append(_entry("Rook", false, "Rook anchors: holds one spot."))
	assert_string_starts_with(SummaryHits.closing_bbcode(hits), "[color=#ffffff]Rook[/color] got you 3 times.")
	var once: Array[SummaryHits.Entry] = [_entry("Rook", true, "Rook anchors: x."), _entry("Dash", false, "")]
	assert_eq(SummaryHits.closing_bbcode(once), "", "nobody twice: the last shooter's note, here none")


func test_only_the_latest_hits_are_listed_with_the_rest_counted() -> void:
	var panel := SummaryHits.new()
	add_child_autofree(panel)
	for i in SummaryHits.SHOWN + 2:
		panel.add(i + 1, HitFacts.new(), "Bot %d" % i, Color.WHITE, "")
	panel.fill()
	var words: Array[String] = []
	for l in panel.find_children("*", "Label", true, false):
		words.append((l as Label).text)
	assert_has(words, "2 earlier")
	assert_has(words, "ROUND %d" % (SummaryHits.SHOWN + 2))
	assert_does_not_have(words, "ROUND 2")


# --- in play ---

func test_the_summary_follows_the_last_rounds_table_with_everyones_match_numbers() -> void:
	session = _session(&"hard")
	await wait_physics_frames(2)
	session.counts = false
	_hit_you()
	_tick([K.ROUND_START], -1, -1, 2)
	_hit_you()
	session.state.round_state.score[0] = 2
	session.state.round_state.phase = RoundState.Phase.MATCH_OVER
	_tick([K.ROUND_OVER, K.MATCH_OVER], -1, -1, 1)
	var hud := session.hud()
	hud.update(session.state, 1.0, 0.0)
	assert_false(hud.summary_up(), "the last round's table first")
	assert_eq(hud.banner_text(), "LOST / THE MATCH · ALPHA 2 – 0 BETA · DEPOT · HARD BOTS")
	session._move_on()
	hud.update(session.state, 1.0, 0.0)
	assert_true(hud.summary_up())
	var summary := hud.summary()
	assert_eq(summary.table().title(), "THE MATCH")
	assert_eq(summary.table().lines().size(), session.state.characters.size(), "a line per player")
	assert_string_starts_with(summary.table().lines()[0], "You | 0 | 2 | ", "you first: no hits, hit twice")
	assert_eq(summary.hits().entries().size(), 2)
	assert_eq(summary.hits().entries()[0].number, 1)
	assert_true(summary.hits().visible, "Auto against Hard bots")
	assert_eq(summary.tip_text(), tr(HudScoreboard.tip_for(session.state.round_state.number + 1)))
	assert_eq(summary.foot_text(), "A NEW MATCH STARTS SHORTLY · CLICK TO START NOW")
	assert_false(hud._replica.visible, "the replica panel makes way")
	assert_false(hud.score().is_visible_in_tree(), "the score bar makes way")
	assert_false(hud.feed().visible, "the hit feed makes way")
	assert_null(hud.what_got_you(), "the last card makes way")


func test_against_normal_bots_auto_leaves_out_what_got_you_and_the_tip() -> void:
	session = _session(&"easy")
	await wait_physics_frames(2)
	session.counts = false
	_hit_you()
	_end_match(0)
	var summary := session.hud().summary()
	assert_true(session.hud().summary_up())
	assert_eq(session.hud().banner_text().get_slice(" / ", 0), "WON")
	assert_false(summary.hits().visible)
	assert_eq(summary.tip_text(), "")
	assert_false(summary.records().visible, "no records for a match that isn't counted")


func test_a_click_starts_the_next_match_and_it_starts_on_its_own_too() -> void:
	session = _session(&"easy")
	await wait_physics_frames(2)
	session.counts = false
	_end_match(0)
	assert_eq(session._rematch_left, session._play.rematch_delay)
	session._start_now()
	assert_eq(session._rematch_left, 0.0, "the next physics tick starts the match")
	_tick([K.ROUND_START], -1, -1, 1)
	session.hud().update(session.state, 1.0, 0.0)
	assert_false(session.hud().summary_up(), "gone when the next match starts")
	assert_true(session.hud()._replica.visible)
	assert_true(session.hud().score().is_visible_in_tree(), "the score bar is back")
	assert_true(session.hud().feed().visible)
	assert_eq(session.hud().summary().hits().entries().size(), 0, "a new match forgets the hits")
	_end_match(1)
	session._process(session._play.rematch_delay + 0.1)
	assert_eq(session._rematch_left, 0.0, "the wait ran out")
