extends GutTest
## QA for WG1 (What got you and skipping the round): the edges of the skip (the round or match ending while skipping,
## the pause menu, autopilot, a rebound Fire; since MC1 played out at once on a fresh press), the card for a
## teammate's, a bounced or your own BB and its freeing on a new match, the kept feed line under a busy feed, and the
## setting's save, load and screen.

const K := GameEvent.Kind

var session: PlaySession = null


func after_each() -> void:
	Input.action_release(&"fire")
	InputMap.load_from_project_settings()
	get_tree().paused = false


func _session(setting: Settings.WhatGotYou = Settings.WhatGotYou.ON) -> PlaySession:
	var s := PlaySession.new()
	s.bots_active = false
	s.difficulty = &"easy"
	s.settings = Settings.new()
	s.settings.what_got_you = setting
	add_child_autofree(s)
	return s


## One simulation tick's worth of events through the session, as the simulation would report them.
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


func _labels(card: Control) -> Array[String]:
	var words: Array[String] = []
	for l in card.find_children("*", "Label", true, false):
		words.append((l as Label).text)
	return words


# --- skipping ---

func test_the_skipping_note_never_draws_over_the_pause_menu() -> void:
	session = _session()
	await wait_physics_frames(2)
	session.player.status = Character.Status.OUT
	session.start_skip()
	assert_true(session.skipping())
	session._open_pause()
	var note: Label = session._skip_note
	var pause: PauseMenu = session._pause
	var layer := note.get_parent()
	assert_eq(layer.get_parent(), pause.get_parent(), "both in the session's interface layer")
	var drawn_over := note.is_visible_in_tree() and layer.get_index() > pause.get_index()
	assert_false(drawn_over, "\"Skipping the round\" shows on top of the pause menu (and its settings screen)")
	assert_false(pause.can_skip(), "already skipping: no Skip to next round")
	session._resume()
	session._stop_skip()
	session.player.status = Character.Status.ALIVE


func test_the_hint_names_fire_as_bound_after_a_rebind_from_the_pause_menu() -> void:
	session = _session()
	await wait_physics_frames(2)
	session.player.status = Character.Status.OUT
	session._follow_skip()
	var hud := session.hud()
	assert_true(hud.skip_hint_shown())
	var key: Label = hud._skip_key
	assert_eq(key.text, KeyNames.of_action(&"fire").to_upper())
	var before := key.text
	# Paused, Settings > Controls rebinds Fire (KeyBindingList applies it to the InputMap at once), then Resume.
	session._open_pause()
	InputMap.action_erase_events(&"fire")
	InputMap.action_add_event(&"fire", KeyBindings.event_of(KEY_J))
	session._resume()
	session._follow_skip()
	assert_ne(KeyNames.of_action(&"fire").to_upper(), before)
	assert_eq(key.text, KeyNames.of_action(&"fire").to_upper(), "the hint still names the old key")
	session.player.status = Character.Status.ALIVE


func test_the_last_player_out_ending_the_match_stops_the_skip_and_brings_the_hud_back() -> void:
	session = _session()
	await wait_physics_frames(2)
	session.counts = false
	session.player.status = Character.Status.OUT
	session.start_skip()
	assert_true(session.skipping())
	session.state.round_state.phase = RoundState.Phase.MATCH_OVER
	_tick([K.ROUND_OVER, K.MATCH_OVER], -1, -1, 1)
	assert_false(session.skipping())
	assert_true(session.hud().visible, "the HUD is back for the round's table")
	assert_false(session._skip_note.visible)
	assert_true(session.hud().holds_results(), "the round's table is due as usual")
	assert_eq(session._rematch_left, session._play.rematch_delay, "the rematch is due as usual")
	session._input.active = true
	session._follow_skip()
	session._unhandled_input(_click())
	assert_false(session.skipping(), "no skip once the round is over")
	assert_false(session.hud().skip_hint_shown())
	session._input.active = false
	session.player.status = Character.Status.ALIVE


func test_skipping_plays_the_round_out_at_once_then_holds_the_next_for_a_click() -> void:
	session = _session()
	await wait_physics_frames(2)
	session.player.status = Character.Status.OUT
	# Two seconds left: a skip plays them out within a few frames, whatever the Dev game speed.
	session.state.cheats.game_speed = 0.5
	session.state.round_state.clock = 2.0
	session.start_skip()
	assert_true(session._skip_cover.visible, "a plain cover: none of it is shown")
	assert_true(session.get_viewport().disable_3d, "nor drawn")
	assert_string_contains(session._skip_note.text, "0:02", "the clock it plays down")
	assert_false(session.hud().visible)
	var frames := 0
	var ticks := session.ticks()
	while session.skipping() and frames < 600:
		session._physics_process(0.0)
		frames += 1
	assert_false(session.skipping(), "played out")
	assert_gt(session.ticks() - ticks, frames * 2, "many ticks a frame, not real time nor the Dev game speed")
	assert_false(session.state.round_state.is_live())
	assert_true(session.state.round_state.hold_next, "the next round waits")
	assert_false(session._skip_cover.visible)
	assert_false(session.get_viewport().disable_3d, "the field drawn again")
	assert_true(session.hud().visible, "the HUD is back for the round's table")
	session.state.cheats.game_speed = 1.0
	session.player.status = Character.Status.ALIVE


func test_autopilot_never_offers_the_skip() -> void:
	session = _session()
	await wait_physics_frames(2)
	session.autopilot = true
	session.player.status = Character.Status.OUT
	assert_false(session.can_skip())
	session._follow_skip()
	assert_false(session.hud().skip_hint_shown())
	session.start_skip()
	assert_false(session.skipping())
	session.autopilot = false
	session.player.status = Character.Status.ALIVE


func test_a_trigger_held_through_the_hit_does_not_skip_and_a_fresh_press_does() -> void:
	session = _session()
	await wait_physics_frames(2)
	session._input.active = true
	Input.action_press(&"fire")
	session.player.status = Character.Status.OUT
	session._follow_skip()
	session._unhandled_input(_click())
	assert_false(session.skipping(), "held since before you could skip: not armed")
	Input.action_release(&"fire")
	session._follow_skip()
	session._unhandled_input(_click())
	assert_true(session.skipping(), "a fresh press skips")
	session._stop_skip()
	session._input.active = false
	session.player.status = Character.Status.ALIVE


## A press of the left mouse button (Fire's default).
static func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


# --- the card ---

func test_a_teammates_or_a_bounced_bb_shows_the_card_and_your_own_does_not() -> void:
	session = _session(Settings.WhatGotYou.ON)
	await wait_physics_frames(2)
	var mate := -1
	for c in session.state.characters:
		if c.team == session.player.team and c.id != PlaySession.PLAYER_ID:
			mate = c.id
			break
	if mate >= 0:
		_tick([K.CHARACTER_HIT], mate, PlaySession.PLAYER_ID)
		var card := session.hud().what_got_you()
		assert_not_null(card, "a teammate's BB")
		if card != null:
			assert_false(_labels(card).has(tr("WGY_HELD") % session._bots.name_of(mate)), "not known for a mate")
	var foe := -1
	for c in session.state.characters:
		if c.team != session.player.team:
			foe = c.id
			break
	session.state.time += 1.0
	_tick([K.CHARACTER_HIT], foe, PlaySession.PLAYER_ID, 1)
	var bounced := session.hud().what_got_you()
	assert_not_null(bounced)
	if bounced != null:
		assert_has(_labels(bounced), tr("WGY_BOUNCED"))
	await wait_process_frames(1)
	session.hud().hide_what_got_you()
	session.state.time += 1.0
	_tick([K.CHARACTER_HIT], PlaySession.PLAYER_ID, PlaySession.PLAYER_ID)
	assert_null(session.hud().what_got_you(), "your own BB: no card")


func test_the_card_and_the_kept_line_go_when_a_new_match_starts_with_no_orphans() -> void:
	session = _session(Settings.WhatGotYou.ON)
	await wait_physics_frames(2)
	var foe := -1
	for c in session.state.characters:
		if c.team != session.player.team:
			foe = c.id
			break
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_tick([K.CHARACTER_HIT], foe, PlaySession.PLAYER_ID)
	var card := session.hud().what_got_you()
	assert_not_null(card)
	var feed: HitFeed = session.hud()._hits
	# Your line, wherever a teammate's callout about the hit put it.
	var yours := false
	for i in feed.count():
		if not feed.line(i).call and feed.line(i).victim == PlaySession.PLAYER_ID:
			yours = feed.line(i).keep
	assert_true(yours, "your line is kept")
	session.state.round_state.draws = 0
	_tick([K.ROUND_START], -1, -1, 1)
	assert_null(session.hud().what_got_you())
	await wait_process_frames(2)
	assert_false(is_instance_valid(card), "freed")
	for i in feed.count():
		assert_false(feed.line(i).keep)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans)


# --- the feed ---

func test_a_busy_feed_never_grows_past_its_size_nor_loses_your_line() -> void:
	var feed := HitFeed.new()
	feed.setup(6, 6.0, 1.0)
	feed.add(1, 2, 0.0)
	feed.add(3, 0, 0.5, true)
	var t := 1.0
	for i in 40:
		feed.add(4 + i % 3, 7, t)
		if i % 5 == 0:
			feed.prune(t)
		t += 0.4
		assert_true(feed.count() <= 6)
		var yours := 0
		for j in feed.count():
			if feed.line(j).victim == 0:
				yours += 1
		assert_eq(yours, 1, "your line after %d more hits" % (i + 1))
	for j in range(1, feed.count()):
		if feed.line(j).victim != 0 and feed.line(j - 1).victim != 0:
			assert_true(feed.line(j - 1).time >= feed.line(j).time, "the others newest first")
	feed.release_kept()
	assert_lt(feed.alpha(feed.count() - 1, t), 1.0, "released, it fades as any other")
	feed.prune(t)
	for j in feed.count():
		assert_ne(feed.line(j).victim, 0, "and goes with its age")


func test_a_cleared_feed_keeps_nothing_kept() -> void:
	var feed := HitFeed.new()
	feed.setup(3, 6.0, 1.0)
	feed.add(3, 0, 0.0, true)
	feed.clear()
	for i in 5:
		feed.add(4, 1, 10.0 + i)
	feed.prune(100.0)
	assert_eq(feed.count(), 0, "no stale kept slot survives a clear")


# --- the setting ---

func test_the_setting_saves_loads_and_falls_back_to_auto() -> void:
	var s := Settings.new()
	s.what_got_you = Settings.WhatGotYou.OFF
	var back := Settings.new()
	back.from_dict(s.to_dict())
	assert_eq(back.what_got_you, Settings.WhatGotYou.OFF)
	var old := s.to_dict()
	old.erase("what_got_you")
	back.from_dict(old)
	assert_eq(back.what_got_you, Settings.WhatGotYou.AUTO, "an older save")
	for junk: Variant in ["on", 7, -1, NAN, true, null]:
		old["what_got_you"] = junk
		back.what_got_you = Settings.WhatGotYou.OFF
		back.from_dict(old)
		assert_eq(back.what_got_you, Settings.WhatGotYou.AUTO, "junk %s" % str(junk))
	old["what_got_you"] = 1.0
	back.from_dict(old)
	assert_eq(back.what_got_you, Settings.WhatGotYou.ON, "a float from JSON")


func test_the_settings_screen_maps_its_options_to_the_setting() -> void:
	var s := Settings.new(PlayTuning.new())
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = "user://test-wg1-qa-settings.save"
	add_child_autofree(screen)
	s.what_got_you = Settings.WhatGotYou.OFF
	screen.open()
	var choice: MenuChoice = screen._hud_page._what_got_you
	assert_eq(choice.get_child_count(), Settings.WhatGotYou.size())
	assert_eq(choice.selected(), Settings.WhatGotYou.OFF)
	assert_eq(choice.button(Settings.WhatGotYou.AUTO).text, tr("SETTINGS_AUTO").to_upper())
	assert_eq(choice.button(Settings.WhatGotYou.ON).text, tr("SETTINGS_ON").to_upper())
	assert_eq(choice.button(Settings.WhatGotYou.OFF).text, tr("SETTINGS_OFF").to_upper())
	choice.button(Settings.WhatGotYou.ON).pressed.emit()
	assert_eq(s.what_got_you, Settings.WhatGotYou.ON)
	DirAccess.remove_absolute("user://test-wg1-qa-settings.save")
