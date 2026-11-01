extends GutTest
## What got you and skipping the round (WG1; concept `out.png`): the card from HitFacts once your hit is called (the
## side and distance the shot came from, held angle, time in view, moving, the bot's note) as the setting says (Auto:
## Hard bots only); out, hold Jump to skip the rest of the round at speed with the HUD hidden, or Skip to next round in
## the pause menu; the line you were hit in stays in the feed until the round ends.

const K := GameEvent.Kind

var session: PlaySession = null


func after_each() -> void:
	Input.action_release(&"fire")
	get_tree().paused = false


## A press of the left mouse button (Fire's default).
static func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func _facts(shooter_at: Vector3, yaw: float) -> HitFacts:
	var victim := Character.new(0, 0)
	victim.yaw = yaw
	var shooter := Character.new(3, 1, shooter_at)
	var f := HitFacts.new()
	f.record(1.0, victim, shooter, false, true, true, 0.4, 1.0)
	return f


func _session(setting: Settings.WhatGotYou, difficulty: StringName = &"easy") -> PlaySession:
	var s := PlaySession.new()
	s.bots_active = false
	s.difficulty = difficulty
	s.settings = Settings.new()
	s.settings.what_got_you = setting
	add_child_autofree(s)
	return s


## The bot playing character 3 hits you, as the simulation would report it.
func _hit_you() -> void:
	var state := session.state
	state.events.clear()
	var e := state.events.add(K.CHARACTER_HIT)
	e.actor = 3
	e.target = PlaySession.PLAYER_ID
	session._after_tick()
	state.events.clear()


# --- the card's words ---

func test_the_side_reads_from_where_you_faced() -> void:
	var left := _facts(Vector3(-18.0, 0.0, 0.0), 0.0)
	assert_eq(WhatGotYouCard.from_of(left), WhatGotYouCard.From.LEFT)
	assert_eq(WhatGotYouCard.from_words(left), "From your left, 18 m away")
	assert_eq(WhatGotYouCard.from_of(_facts(Vector3(10.0, 0.0, 0.0), 0.0)), WhatGotYouCard.From.RIGHT)
	assert_eq(WhatGotYouCard.from_of(_facts(Vector3(0.0, 0.0, -10.0), 0.0)), WhatGotYouCard.From.FRONT)
	assert_eq(WhatGotYouCard.from_of(_facts(Vector3(0.0, 0.0, 10.0), 0.0)), WhatGotYouCard.From.BEHIND)
	assert_eq(WhatGotYouCard.from_of(_facts(Vector3(-10.0, 0.0, 0.0), PI * 0.5)), WhatGotYouCard.From.FRONT,
			"turned to face -X, the shooter there is in front")
	assert_almost_eq(WhatGotYouCard.dial_point(left), Vector2.LEFT, Vector2(1e-5, 1e-5))


func test_the_note_leads_with_the_bot_in_its_colour() -> void:
	var text := WhatGotYouCard.note_bbcode("Rook anchors: holds one spot [late].", Color("ff8a2a"))
	assert_eq(text, "[b][color=#ff8a2a]Rook anchors:[/color][/b] holds one spot [lb]late].")


func test_a_card_lists_only_what_is_known() -> void:
	var f := _facts(Vector3(-18.0, 0.0, 0.0), 0.0)
	var card := WhatGotYouCard.new(f, "Rook", Color.ORANGE, "Rook anchors: holds.")
	add_child_autofree(card)
	var words: Array[String] = []
	for l in card.find_children("*", "Label", true, false):
		words.append((l as Label).text)
	assert_has(words, "Rook was holding the angle")
	assert_has(words, "0.4 s")
	assert_has(words, "Standing still")
	f.held_known = false
	f.in_view = -1.0
	var unknown := WhatGotYouCard.new(f, "Rook", Color.ORANGE, "")
	add_child_autofree(unknown)
	var rows := 0
	for l in unknown.find_children("*", "Label", true, false):
		if (l as Label).text in ["Rook was holding the angle", "You were in Rook's view for"]:
			rows += 1
	assert_eq(rows, 0, "a teammate's or bounced BB: neither is known")
	assert_eq(unknown.find_children("*", "RichTextLabel", true, false).size(), 0, "no note, no line")


# --- the line you were hit in ---

func test_the_line_you_were_hit_in_stays_until_the_round_ends() -> void:
	var feed := HitFeed.new()
	feed.setup(3, 6.0, 1.0)
	feed.add(3, 0, 0.0, true)
	feed.add(4, 1, 1.0)
	feed.prune(30.0)
	assert_eq(feed.count(), 1)
	assert_eq(feed.line(0).victim, 0, "yours stays")
	assert_eq(feed.alpha(0, 30.0), 1.0, "and never fades")
	for i in 4:
		feed.add(4, 1, 31.0 + i)
	assert_eq(feed.count(), 3)
	var kept := 0
	for i in feed.count():
		if feed.line(i).victim == 0:
			kept += 1
	assert_eq(kept, 1, "a full feed drops others first")
	feed.release_kept()
	feed.prune(100.0)
	assert_eq(feed.count(), 0)


# --- in a match ---

func test_the_card_shows_as_the_setting_says() -> void:
	session = _session(Settings.WhatGotYou.AUTO)
	await wait_physics_frames(2)
	_hit_you()
	assert_null(session.hud().what_got_you(), "Auto: not against Easy bots")
	session = _session(Settings.WhatGotYou.ON)
	await wait_physics_frames(2)
	_hit_you()
	assert_not_null(session.hud().what_got_you(), "On: always")
	var state := session.state
	state.events.clear()
	state.events.add(K.ROUND_START).value = 2
	session.hud().on_tick(state)
	state.events.clear()
	assert_null(session.hud().what_got_you(), "gone when the next round starts")


func test_auto_shows_the_card_against_pro_bots_and_off_never() -> void:
	session = _session(Settings.WhatGotYou.AUTO, &"hard")
	await wait_physics_frames(2)
	_hit_you()
	assert_not_null(session.hud().what_got_you())
	session = _session(Settings.WhatGotYou.OFF, &"hard")
	await wait_physics_frames(2)
	_hit_you()
	assert_null(session.hud().what_got_you())


func test_out_a_click_skips_the_round_with_the_hud_hidden() -> void:
	session = _session(Settings.WhatGotYou.OFF)
	await wait_physics_frames(2)
	assert_false(session.can_skip(), "not while you are in play")
	session.player.status = Character.Status.OUT
	assert_true(session.can_skip())
	session._follow_skip()
	assert_true(session.hud().skip_hint_shown())
	session._input.active = true
	session._follow_skip()
	session._unhandled_input(_click())
	assert_true(session.skipping())
	assert_false(session.hud().visible, "the HUD hides")
	assert_false(session.hud().skip_hint_shown())
	var state := session.state
	state.events.clear()
	state.events.add(K.ROUND_OVER).value = 1
	session._after_tick()
	state.events.clear()
	assert_false(session.skipping(), "the round ended")
	assert_true(session.hud().visible)
	session._input.active = false
	session.player.status = Character.Status.ALIVE


func test_the_trigger_held_through_the_hit_does_not_skip_until_pressed_again() -> void:
	session = _session(Settings.WhatGotYou.OFF)
	await wait_physics_frames(2)
	session._input.active = true
	Input.action_press(&"fire")
	session.player.status = Character.Status.OUT
	session._follow_skip()
	session._unhandled_input(_click())
	assert_false(session.skipping(), "held from before you were out")
	Input.action_release(&"fire")
	session._follow_skip()
	session._unhandled_input(_click())
	assert_true(session.skipping(), "a fresh press skips")
	session._stop_skip()
	session._input.active = false
	session.player.status = Character.Status.ALIVE


func test_the_pause_menu_offers_skip_only_while_you_are_out() -> void:
	session = _session(Settings.WhatGotYou.OFF)
	await wait_physics_frames(2)
	var menu := session.find_child("PauseMenu", true, false) as PauseMenu
	session._open_pause()
	assert_false(menu.can_skip())
	session._resume()
	session.player.status = Character.Status.OUT
	session._open_pause()
	assert_true(menu.can_skip())
	menu.skipped.emit()
	assert_true(session.skipping())
	assert_false(get_tree().paused)
	session.player.status = Character.Status.ALIVE
